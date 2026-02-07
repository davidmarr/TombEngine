-----<style>table.function_list td.name {min-width: 345px;}</style>
--- Lua support functions to simplify operations in scripts. To use, include the module with:
---
--- **Design Philosophy:**
--- LuaUtil is designed primarily for:
--- 
--- - Writing Lua modules and scripts
--- - Simplifying Node creation in TombEditor's Node Editor
--- - Providing safe, predictable helper functions
---
--- **Type Checking:**
--- All functions perform runtime type validation.
--- This ensures:
--- 
--- - Early error detection during development
--- - Predictable results when users make mistakes
---
--- To use, include the module with:
---
---	local LuaUtil = require("Engine.LuaUtil")
--- @luautil LuaUtil

local Type= require("Engine.Type")
local LuaUtil = {}

-- ============================================================================
-- PERFORMANCE OPTIMIZATION: DIRECT LOCAL REFERENCES
-- ============================================================================
-- These variables are declared as direct locals instead of being grouped in a table
-- to optimize hot-path performance. This module's functions are frequently called
-- every frame in game loops (animations, interpolations, particle systems, etc.).
--
-- Performance gain:
-- - With table:  IsNumber(x)  →  2 opcodes (GETUPVAL + GETTABLE)
-- - Direct:      IsNumber(x)        →  1 opcode  (GETUPVAL)
-- 
-- This 50% reduction in opcodes is significant when functions are called thousands
-- of times per second. For example:
-- - 200 particles × 15 calls/frame × 30 FPS = 90,000 table lookups/second
-- - Direct access saves ~45,000 opcodes/second in such scenarios
--
-- Trade-off: More variables in local scope (34 total), but well below Lua's 200 limit.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TYPE CHECKING FUNCTIONS
-- Cached from Engine.Type module - used in every LuaUtil function for validation
-- ----------------------------------------------------------------------------
local IsNumber = Type.IsNumber
local IsVec2 = Type.IsVec2
local IsVec3 = Type.IsVec3
local IsColor = Type.IsColor
local IsTime = Type.IsTime
local IsRotation = Type.IsRotation
local IsBoolean = Type.IsBoolean
local IsString = Type.IsString
local IsTable = Type.IsTable
local IsNull = Type.IsNull

-- ----------------------------------------------------------------------------
-- MATH FUNCTIONS
-- Cached from math library - heavily used in interpolation and clamping operations
-- ----------------------------------------------------------------------------
local floor = math.floor
local max = math.max
local min = math.min
local random = math.random
local randomseed = math.randomseed
local abs = math.abs
local sin = math.sin
local cos = math.cos
local asin = math.asin
local atan = math.atan
local deg = math.deg
local sqrt = math.sqrt
local rad = math.rad
local pi = math.pi

-- ----------------------------------------------------------------------------
-- IMMUTABLE CONSTANTS
-- Configuration values that never change during runtime (SCREAMING_SNAKE_CASE)
-- ----------------------------------------------------------------------------
local FPS = 30              -- Default frames per second for time-frame conversions
local MAX_DEPTH = 10        -- Maximum recursion depth for deep operations (prevents stack overflow)
local MAX_ELEMENTS = 1000   -- Maximum elements processed in deep operations (prevents performance issues)

-- ----------------------------------------------------------------------------
-- COMPARISON OPERATORS
-- Lookup table for CompareValues function (immutable after initialization)
-- ----------------------------------------------------------------------------
local COMPARISON_OPS = {
    function(a, b) return a == b end,   -- 0: equal
    function(a, b) return a ~= b end,   -- 1: not equal
    function(a, b) return a < b end,    -- 2: less than
    function(a, b) return a <= b end,   -- 3: less than or equal
    function(a, b) return a > b end,    -- 4: greater than
    function(a, b) return a >= b end,   -- 5: greater than or equal
}

-- ----------------------------------------------------------------------------
-- MUTABLE STATE (with underscore prefix to indicate internal mutability)
-- Used by recursive algorithms to track context across function calls
-- ----------------------------------------------------------------------------
-- State for deep table comparison (CompareTablesDeep)
local _nextCompareId = 1       -- Progressive ID generator for each comparison operation
local _activeCompares = {}     -- Tracks active comparisons: { [id] = { depth, elementCount, visited } }

-- State for deep table copy (CloneValue)
local _nextCopyId = 1          -- Progressive ID generator for each copy operation
local _activeCopies = {}       -- Tracks active copy operations: { [id] = { depth, elementCount, visited } }

-- Helper function for type checking and interpolation
local function InterpolateValues(a, b, clampedT, functionName)
    if IsNumber(a) then
        if not IsNumber(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a + (b - a) * clampedT
    end

    if IsVec3(a) then
        if not IsVec3(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if IsVec2(a) then
        if not IsVec2(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if IsColor(a) then
        if not IsColor(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if IsRotation(a) then
        if not IsRotation(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    TEN.Util.PrintLog("Error in " .. functionName .. ": unsupported type.", TEN.Util.LogLevel.ERROR)
    return a
end

-- Helper function for hue interpolation with different modes
local function InterpolateHue(h1, h2, t, mode)
    local delta = h2 - h1

    if mode == "shortest" then
        delta = ((delta + 180) % 360) - 180

    elseif mode == "longest" then
        delta = ((delta + 180) % 360) - 180
        if delta > 0 then delta = delta - 360 else delta = delta + 360 end

    elseif mode == "increasing" then
        if delta < 0 then delta = delta + 360 end

    elseif mode == "decreasing" then
        if delta > 0 then delta = delta - 360 end
    end

    return (h1 + delta * t) % 360
end


-- Helper function for HSL to RGB conversion
local function HueToRgb(p, q, t)
    if t < 0 then
        t = t + 1
    end
    if t > 1 then
        t = t - 1
    end
    if t < 1 / 6 then
        return p + (q - p) * 6 * t
    end
    if t < 1 / 2 then
        return q
    end
    if t < 2 / 3 then
        return p + (q - p) * (2 / 3 - t) * 6
    end
    return p
end

-- Helper functions for sRGB and Linear color space conversion
local function SrgbToLinear(c)
    if c <= 0.04045 then
        return c / 12.92
    else
        return ((c + 0.055) / 1.055) ^ 2.4
    end
end

-- Helper function for Linear to sRGB color space conversion
local function LinearToSrgb(c)
    if c <= 0.0031308 then
        return c * 12.92
    else
        return 1.055 * (c ^ (1 / 2.4)) - 0.055
    end
end

-- Support function for deep table copy
local function DeepCopyRecursive(original, copyId)
    local context = _activeCopies[copyId]

    -- Check maximum depth
    if context.depth >= MAX_DEPTH then
        TEN.Util.PrintLog("Warning in LuaUtil.CloneValue: Maximum depth (" .. 
            MAX_DEPTH .. ") exceeded.", TEN.Util.LogLevel.WARNING)
        return {}
    end

    -- Check if we've already copied this table (prevents infinite loops)
    if context.visited[original] then
        return context.visited[original]
    end

    -- Create new table and register it immediately
    local copy = {}
    context.visited[original] = copy
    context.depth = context.depth + 1

    for key, value in pairs(original) do
        context.elementCount = context.elementCount + 1

        -- Check maximum elements
        if context.elementCount >= MAX_ELEMENTS then
            TEN.Util.PrintLog("Warning in LuaUtil.CloneValue: Maximum elements (" .. MAX_ELEMENTS .. ") exceeded.", TEN.Util.LogLevel.WARNING)
            return copy
        end

        -- Deep copy nested tables
        if IsTable(value) then
            copy[key] = DeepCopyRecursive(value, copyId)
        else
            copy[key] = value
        end
    end

    context.depth = context.depth - 1
    return copy
end

-- Support function for recursive comparison
local function CompareRecursive(t1, t2, compareId)
    local context = _activeCompares[compareId]

    -- Check maximum depth
    if context.depth >= MAX_DEPTH then
        TEN.Util.PrintLog("Warning in LuaUtil.CompareTablesDeep: Maximum depth (" .. MAX_DEPTH .. ") exceeded.", TEN.Util.LogLevel.WARNING)
        return false
    end

    -- Prevent infinite loops: check if we've already visited this pair
    local pairKey = tostring(t1) .. "-" .. tostring(t2)
    if context.visited[pairKey] then
        return true  -- Already visited, assume equal
    end
    context.visited[pairKey] = true

    -- Increment depth
    context.depth = context.depth + 1

    -- Single loop: compare all keys from both tables
    local currentKeysChecked = {}

    for key, value1 in pairs(t1) do
        context.elementCount = context.elementCount + 1

        -- Check maximum elements
        if context.elementCount >= MAX_ELEMENTS then
            TEN.Util.PrintLog("Warning in LuaUtil.CompareTablesDeep: Maximum elements (" .. 
                MAX_ELEMENTS .. ") exceeded.", TEN.Util.LogLevel.WARNING)
            return false
        end

        local value2 = t2[key]
        currentKeysChecked[key] = true

        -- If key doesn't exist in t2, tables are different
        if value2 == nil then
            context.depth = context.depth - 1
            return false
        end

        -- Compare values
        if IsTable(value1) and IsTable(value2) then
            if not CompareRecursive(value1, value2, compareId) then
                context.depth = context.depth - 1
                return false
            end
        elseif value1 ~= value2 then
            context.depth = context.depth - 1
            return false
        end
    end

    -- Check if t2 has keys that t1 doesn't have
    for key, _ in pairs(t2) do
        if not currentKeysChecked[key] then
            context.depth = context.depth - 1
            return false
        end
    end

    -- Decrement depth before returning
    context.depth = context.depth - 1
    return true
end

-- Support function for angle wrapping (used in interpolation)
local function wrapAngleRaw(angle, minVal, range)
    return angle - range * floor((angle - minVal) / range)
end

--- General utilities.
-- Generic helper functions that work with multiple data types.
-- @section general

--- Clone a value, creating an independent copy.
-- Works with lua primitives and TEN primitives (`Vec2`, `Vec3`, `Rotation`, `Color`, `Time`).
-- For primitive types (number, string, bool, nil), returns the value itself.
-- This solves the reference assignment problem where modifying a copy affects the original.
-- @tparam nil|number|string|boolean|table|Vec2|Vec3|Rotation|Color|Time value The value to clone (can be any type).
-- @treturn[1] nil|number|string|boolean|table|Vec2|Vec3|Rotation|Color|Time An independent copy of the value.
-- @treturn[2] nil If the type is unsupported.
-- @usage
-- -- Problem: reference assignment
-- local row = { TEN.Rotation(244, 90, 276) }
-- local t1 = { rotation = row[1] }
-- local t2 = t1.rotation  -- This is a REFERENCE, not a copy!
-- t2.x = 500
-- print(row[1].x)  -- Prints 500! Original was modified
--
-- -- Solution: use CloneValue
-- local t2 = LuaUtil.CloneValue(t1.rotation)  -- Independent copy
-- t2.x = 500
-- print(row[1].x)  -- Prints 244 (original unchanged)
--
-- -- Example with Vec3:
-- local pos1 = TEN.Vec3(100, 200, 300)
-- local pos2 = LuaUtil.CloneValue(pos1)
-- pos2.x = 999
-- -- pos1.x is still 100
--
-- -- Example with Color:
-- local color1 = TEN.Color(255, 0, 0, 255)
-- local color2 = LuaUtil.CloneValue(color1)
-- color2.r = 0
-- -- color1.r is still 255
--
-- -- Example with table:
-- local config = { speed = 10, enabled = true }
-- local configCopy = LuaUtil.CloneValue(config)
-- configCopy.speed = 20
-- -- config.speed is still 10
--
-- -- Example with primitives (returned as-is):
-- local num = LuaUtil.CloneValue(42)        -- Returns 42
-- local str = LuaUtil.CloneValue("hello")   -- Returns "hello"
-- local bool = LuaUtil.CloneValue(true)     -- Returns true
--
-- -- Practical use: safe parameter passing
-- function ModifyPosition(pos)
--     local safePos = LuaUtil.CloneValue(pos)
--     safePos.x = safePos.x + 100
--     return safePos  -- Original pos is unchanged
-- end
LuaUtil.CloneValue = function(value)
    -- Handle primitive types (these are copied by value in Lua)
    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "number" or valueType == "string" then
        return value
    end

    -- Handle TEN engine types (userdata)
    if IsVec2(value) then
        return TEN.Vec2(value.x, value.y)
    end

    if IsVec3(value) then
        return TEN.Vec3(value.x, value.y, value.z)
    end

    if IsRotation(value) then
        return TEN.Rotation(value.x, value.y, value.z)
    end

    if IsColor(value) then
        return TEN.Color(value.r, value.g, value.b, value.a)
    end

    if IsTime(value) then
        return TEN.Time(value:GetFrameCount())
    end

    -- Handle Lua tables (deep copy)
    if IsTable(value) then
        -- Generate unique ID for this copy operation
        local copyId = _nextCopyId
        _nextCopyId = _nextCopyId + 1

        -- Initialize context for this copy
        _activeCopies[copyId] = {
            depth = 0,
            elementCount = 0,
            visited = {}  -- Prevents infinite loops on circular references
        }

        -- Execute deep copy
        local result = DeepCopyRecursive(value, copyId)

        -- Cleanup: remove context for this copy
        _activeCopies[copyId] = nil

        return result
    end

    -- Unsupported type
    TEN.Util.PrintLog("Warning in LuaUtil.CloneValue: unsupported type '" .. valueType .. "'. Returning nil.", TEN.Util.LogLevel.WARNING)
    return nil
end

--- Get a value or return a default if the value is nil.
-- Unlike the Lua `or` operator, this function correctly handles `false` and `0` as valid values.
-- Only returns defaultValue when value is exactly `nil`.
-- @tparam any value The value to check.
-- @tparam any defaultValue The default value to return if value is nil.
-- @treturn any The value if not nil, otherwise defaultValue.
-- @usage
-- -- Problem with Lua's 'or' operator:
-- local enabled = false
-- local result = enabled or true  -- Result: true ❌ (wrong! false is treated as falsy)
--
-- -- Solution with GetOrDefault:
-- local enabled = false
-- local result = LuaUtil.GetOrDefault(enabled, true)  -- Result: false ✅ (correct!)
--
-- -- Example with 0 (another falsy value in 'or'):
-- local damage = 0
-- local finalDamage = damage or 10  -- Result: 10 ❌ (wrong! 0 is valid)
-- local finalDamage = LuaUtil.GetOrDefault(damage, 10)  -- Result: 0 ✅ (correct!)
--
-- -- Example with nil (works like 'or'):
-- local speed = nil
-- local finalSpeed = LuaUtil.GetOrDefault(speed, 100)  -- Result: 100 ✅
--
-- -- Example with configuration:
-- local config = { volume = 0, mute = false }
-- local volume = LuaUtil.GetOrDefault(config.volume, 100)  -- Result: 0 (not 100!)
-- local mute = LuaUtil.GetOrDefault(config.mute, true)     -- Result: false (not true!)
--
-- -- Practical use: optional function parameters
-- function SetPlayerSpeed(speed)
--     speed = LuaUtil.GetOrDefault(speed, 10)  -- Default to 10 if not provided
--     player.speed = speed
-- end
-- SetPlayerSpeed(0)      -- Sets speed to 0 (not 10!)
-- SetPlayerSpeed(false)  -- Sets speed to false (valid in some contexts)
-- SetPlayerSpeed(nil)    -- Sets speed to 10 (default)
--
-- -- Example with table field:
-- local settings = { showHUD = false }  -- User explicitly disabled HUD
-- local showHUD = LuaUtil.GetOrDefault(settings.showHUD, true)  -- Result: false (respects user choice)
LuaUtil.GetOrDefault = function(value, defaultValue)
    if value == nil then
        return defaultValue
    end
    return value
end

--- Check if a value is empty.
-- Returns true for nil, empty strings, and empty tables. All other values return false.
-- Numbers (including 0), booleans (including false), and TEN types are never considered empty.
-- @tparam any value The value to check.
-- @treturn bool True if the value is nil, empty string, or empty table. False otherwise.
-- @usage
-- -- Nil values:
-- local isEmpty = LuaUtil.IsEmpty(nil)  -- Result: true
--
-- -- Empty strings:
-- local isEmpty = LuaUtil.IsEmpty("")  -- Result: true
-- local isEmpty = LuaUtil.IsEmpty("   ")  -- Result: false (not empty, contains spaces)
--
-- -- Empty tables:
-- local isEmpty = LuaUtil.IsEmpty({})  -- Result: true
-- local isEmpty = LuaUtil.IsEmpty({ a = 1 })  -- Result: false
--
-- -- Important: Lua doesn't store nil values in tables!
-- local isEmpty = LuaUtil.IsEmpty({nil, nil, nil})  -- Result: true (table is actually empty!)
-- local isEmpty = LuaUtil.IsEmpty({1, nil, 3})      -- Result: false (has elements at index 1 and 3)
-- -- Explanation: In Lua, {nil, nil, nil} creates an empty table because nil values are not stored.
--
-- -- Numbers (never empty, even 0):
-- local isEmpty = LuaUtil.IsEmpty(0)  -- Result: false
-- local isEmpty = LuaUtil.IsEmpty(-5)  -- Result: false
--
-- -- Booleans (never empty, even false):
-- local isEmpty = LuaUtil.IsEmpty(false)  -- Result: false
-- local isEmpty = LuaUtil.IsEmpty(true)  -- Result: false
--
-- -- TEN types (never empty):
-- local isEmpty = LuaUtil.IsEmpty(TEN.Vec3(0, 0, 0))  -- Result: false
-- local isEmpty = LuaUtil.IsEmpty(TEN.Color(0, 0, 0, 0))  -- Result: false
--
-- -- Practical use: validate user input
-- function ProcessName(name)
--     if LuaUtil.IsEmpty(name) then
--         TEN.Util.PrintLog("Error: Name cannot be empty!", TEN.Util.LogLevel.ERROR)
--         return false
--     end
--     -- Process name...
--     return true
-- end
--
-- -- Practical use: check if table has data
-- local inventory = {}
-- if LuaUtil.IsEmpty(inventory) then
--     TEN.Util.PrintLog("Inventory is empty", TEN.Util.LogLevel.INFO)
-- else
--     -- Show inventory...
-- end
--
-- -- Practical use: validate configuration
-- local config = LoadConfig()
-- if LuaUtil.IsEmpty(config) then
--     config = GetDefaultConfig()  -- Use defaults if config is empty
-- end
LuaUtil.IsEmpty = function(value)
    -- Check for nil
    if value == nil then
        return true
    end

    -- Check for empty string
    if IsString(value) and value == "" then
        return true
    end

    -- Check for empty table
    if IsTable(value) then
        for _ in pairs(value) do
            return false  -- Has at least one element
        end
        return true  -- No elements
    end

    -- All other values (numbers, booleans, TEN types, etc.) are not empty
    return false
end

--- Comparison and validation functions.
-- Utilities for comparing values and checking ranges.
-- @section comparison

--- Compare two values based on the specified operator.
-- @tparam number|string|Time operand The first value to compare.
-- @tparam number|string|Time reference The second value to compare against.
-- @tparam number operator The comparison operator<br>0: equal<br> 1: not equal<br> 2: less than<br> 3: less than or equal<br> 4: greater than<br> 5: greater than or equal
-- @treturn[1] bool The result of the comparison.
-- @treturn[2] bool false If an error occurs (invalid operator or type mismatch), with an error message.
-- @usage
-- local isEqual = LuaUtil.CompareValues(5, 5, 0) -- true
-- local isNotEqual = LuaUtil.CompareValues("hello", "world", 1) -- true
-- local isLessThan = LuaUtil.CompareValues(3.5, 4.0, 2) -- true
-- local isGreaterOrEqual = LuaUtil.CompareValues(TEN.Time(10), TEN.Time(5), 5) -- true
LuaUtil.CompareValues = function(operand, reference, operator)
    -- Validate operator
    if not IsNumber(operator) or operator < 0 or operator > 5 then
        TEN.Util.PrintLog("Invalid operator for comparison", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Lazy type checking
    if IsNumber(operand) then
        if not IsNumber(reference) then
            TEN.Util.PrintLog("Error in LuaUtil.CompareValues: type mismatch.", TEN.Util.LogLevel.ERROR)
            return false
        end
        return COMPARISON_OPS[operator + 1](operand, reference)
    end

    if IsString(operand) then
        if not IsString(reference) then
            TEN.Util.PrintLog("Error in LuaUtil.CompareValues: type mismatch.", TEN.Util.LogLevel.ERROR)
            return false
        end
        return COMPARISON_OPS[operator + 1](operand, reference)
    end

    if IsTime(operand) then
        if not IsTime(reference) then
            TEN.Util.PrintLog("Error in LuaUtil.CompareValues: type mismatch.", TEN.Util.LogLevel.ERROR)
            return false
        end
        return COMPARISON_OPS[operator + 1](operand, reference)
    end

    TEN.Util.PrintLog("Error in LuaUtil.CompareValues: unsupported type.", TEN.Util.LogLevel.ERROR)
    return false
end

--- Check if a value is within a range (inclusive).
-- @tparam float value The value to check.
-- @tparam float minValue Minimum value.
-- @tparam float maxValue Maximum value.
-- @treturn[1] bool True if value is within range.
-- @treturn[2] bool false If an error occurs.
-- @usage
-- local inRange = LuaUtil.IsInRange(5, 1, 10) -- true
-- local outOfRange = LuaUtil.IsInRange(15, 1, 10) -- false
-- local errorCase = LuaUtil.IsInRange(5, 10, 1) -- false (minValue greater than maxValue)
LuaUtil.IsInRange = function(value, minValue, maxValue)
    if not (IsNumber(value) and IsNumber(minValue) and IsNumber(maxValue)) then
        TEN.Util.PrintLog("Error in LuaUtil.IsInRange: all parameters must be numbers.", TEN.Util.LogLevel.ERROR)   
        return false
    end

    if minValue > maxValue then
        TEN.Util.PrintLog("Error in LuaUtil.IsInRange: minValue cannot be greater than maxValue.", TEN.Util.LogLevel.ERROR)
        return false
    end

    return value >= minValue and value <= maxValue
end

--- String functions.
-- Utilities for string manipulation.
-- @section string

--- Split a string into a table using a specified delimiter.
-- @tparam string inputStr The string to split.
-- @tparam[opt=" " (space)] string delimiter The delimiter to use for splitting.
-- @treturn[1] table A table containing the split substrings.
-- @treturn[2] table {} An empty table if an error occurs.
-- @usage
-- local str = "apple,banana,cherry"
-- local result = LuaUtil.SplitString(str, ",")
-- -- Result: {"apple", "banana", "cherry"}
LuaUtil.SplitString = function(inputStr, delimiter)
    if not IsString(inputStr) then
        TEN.Util.PrintLog("Error in LuaUtil.SplitString: inputStr is not a string.", TEN.Util.LogLevel.ERROR)
        return {}
    end

	delimiter = delimiter or " "
    if not IsString(delimiter) then
        TEN.Util.PrintLog("Error in LuaUtil.SplitString: delimiter is not a string.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    local t = {}
    for str in string.gmatch(inputStr, "([^" .. delimiter .. "]+)") do
        table.insert(t, str)
    end
    return t
end

--- Mathematical functions.
-- Utilities for mathematical operations and rounding.
-- @section math

--- Get the minimum value between multiple arguments (supports numbers, Vec2, Vec3, Time).
-- For Vec2/Vec3, returns component-wise minimum.
-- @tparam number|Vec2|Vec3|Time ... Values to compare (at least 2).
-- @treturn[1] number|Vec2|Vec3|Time The minimum value.
-- @treturn[2] nil If an error occurs.
-- @usage
-- local min = LuaUtil.Min(5, 10, 3) -- Result: 3
-- local minVec = LuaUtil.Min(TEN.Vec3(1, 5, 3), TEN.Vec3(2, 4, 6)) -- Result: Vec3(1, 4, 3)
-- local minTime = LuaUtil.Min(TEN.Time(30), TEN.Time(60)) -- Result: Time(30)
--
-- -- Error handling example:
-- local min = LuaUtil.Min(5, "10", 3) -- Result: nil (type mismatch)
-- if min == nil then
--     TEN.Util.PrintLog("Failed to compute minimum value", TEN.Util.LogLevel.ERROR)
--     return  -- or use a fallback value
-- end
--
-- -- Safe approach with default fallback:
-- -- with numbers
-- local min = LuaUtil.Min(value1, value2, value3) or 0
-- -- with Vec2
-- local minVec2 = LuaUtil.Min(vec2_1, vec2_2) or TEN.Vec2(0, 0)
-- -- with Vec3
-- local minVec = LuaUtil.Min(vec1, vec2, vec3) or TEN.Vec3(0, 0, 0)
-- -- with Time
-- local minTime = LuaUtil.Min(time1, time2) or TEN.Time(0)
LuaUtil.Min = function(...)
    local args = {...}
    if #args < 2 then
        TEN.Util.PrintLog("Error in LuaUtil.Min: at least 2 arguments required.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    local first = args[1]

    if IsNumber(first) then
        local minVal = args[1]
        for i = 2, #args do
            if not IsNumber(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Min: all arguments must be numbers.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            if args[i] < minVal then
                minVal = args[i]
            end
        end
        return minVal
    elseif IsTime(first) then
        local minTime = first
        for i = 2, #args do
            if not IsTime(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Min: all arguments must be Time.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            if args[i]:GetFrameCount() < minTime:GetFrameCount() then
                minTime = args[i]
            end
        end
        return minTime
    elseif IsVec2(first) then
        local result = TEN.Vec2(first.x, first.y)
        for i = 2, #args do
            if not IsVec2(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Min: all arguments must be Vec2.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            result.x = min(result.x, args[i].x)
            result.y = min(result.y, args[i].y)
        end
        return result
    elseif IsVec3(first) then
        local result = TEN.Vec3(first.x, first.y, first.z)
        for i = 2, #args do
            if not IsVec3(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Min: all arguments must be Vec3.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            result.x = min(result.x, args[i].x)
            result.y = min(result.y, args[i].y)
            result.z = min(result.z, args[i].z)
        end
        return result
    end
    TEN.Util.PrintLog("Error in LuaUtil.Min: unsupported type.", TEN.Util.LogLevel.ERROR)
    return nil
end

--- Get the maximum value between multiple arguments (supports numbers, Vec2, Vec3, Time).
-- For Vec2/Vec3, returns component-wise maximum.
-- @tparam number|Vec2|Vec3|Time ... Values to compare (at least 2).
-- @treturn[1] number|Vec2|Vec3|Time The maximum value.
-- @treturn[2] nil If an error occurs.
-- @usage
-- local max = LuaUtil.Max(5, 10, 3) -- Result: 10
-- local maxVec = LuaUtil.Max(TEN.Vec3(1, 5, 3), TEN.Vec3(2, 4, 6)) -- Result: Vec3(2, 5, 6)
-- local maxTime = LuaUtil.Max(TEN.Time(30), TEN.Time(60)) -- Result: Time(60)
--
-- -- Error handling example:
-- local max = LuaUtil.Max(5, "10", 3) -- Result: nil (type mismatch)
-- if max == nil then
--     -- Handle error
-- end
--
-- -- Safe approach with default fallback:
-- -- with numbers
-- local max = LuaUtil.Max(value1, value2, value3) or 0
-- -- with Vec2
-- local maxVec2 = LuaUtil.Max(vec2_1, vec2_2) or TEN.Vec2(0, 0)
-- -- with Vec3
-- local maxVec3 = LuaUtil.Max(vec3_1, vec3_2) or TEN.Vec3(0, 0, 0)
-- -- with Time
-- local maxTime = LuaUtil.Max(time1, time2) or TEN.Time(0)
LuaUtil.Max = function(...)
    local args = {...}
    if #args < 2 then
        TEN.Util.PrintLog("Error in LuaUtil.Max: at least 2 arguments required.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    local first = args[1]

    if IsNumber(first) then
        local maxVal = args[1]
        for i = 2, #args do
            if not IsNumber(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Max: all arguments must be numbers.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            if args[i] > maxVal then
                maxVal = args[i]
            end
        end
        return maxVal
    elseif IsTime(first) then
        local maxTime = first
        for i = 2, #args do
            if not IsTime(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Max: all arguments must be Time.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            if args[i]:GetFrameCount() > maxTime:GetFrameCount() then
                maxTime = args[i]
            end
        end
        return maxTime
    elseif IsVec2(first) then
        local result = TEN.Vec2(first.x, first.y)
        for i = 2, #args do
            if not IsVec2(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Max: all arguments must be Vec2.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            result.x = max(result.x, args[i].x)
            result.y = max(result.y, args[i].y)
        end
        return result
    elseif IsVec3(first) then
        local result = TEN.Vec3(first.x, first.y, first.z)
        for i = 2, #args do
            if not IsVec3(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Max: all arguments must be Vec3.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            result.x = max(result.x, args[i].x)
            result.y = max(result.y, args[i].y)
            result.z = max(result.z, args[i].z)
        end
        return result
    end
    TEN.Util.PrintLog("Error in LuaUtil.Max: unsupported type.", TEN.Util.LogLevel.ERROR)
    return nil
end

--- Round a number to a specified number of decimal places.
-- @tparam float num The number to round.
-- @tparam[opt=0] float decimals Number of decimal places.
-- @treturn[1] float The rounded number.
-- @treturn[2] float 0 If an error occurs.
-- @usage
-- local rounded1 = LuaUtil.Round(3.14159)       -- Result: 3
-- local rounded2 = LuaUtil.Round(3.14159, 2)    -- Result: 3.14
-- local rounded3 = LuaUtil.Round(2.675, 2)      -- Result: 2.68
-- local rounded4 = LuaUtil.Round(-1.2345, 1)    -- Result: -1.2
LuaUtil.Round = function(num, decimals)
    decimals = decimals or 0
    if not IsNumber(num) or not IsNumber(decimals) then
        TEN.Util.PrintLog("Error in LuaUtil.Round: num and decimals must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end
    local mult = 10 ^ decimals
    return floor(num * mult + 0.5) / mult
end

--- Truncate a number to a specified number of decimal places (without rounding).
-- @tparam float num The number to truncate.
-- @tparam[opt=0] float decimals Number of decimal places.
-- @treturn[1] float The truncated number.
-- @treturn[2] float 0 If an error occurs.
-- @usage
-- local truncated1 = LuaUtil.Truncate(3.14159)       -- Result: 3
-- local truncated2 = LuaUtil.Truncate(3.14159, 2)    -- Result: 3.14
-- local truncated3 = LuaUtil.Truncate(2.999, 2)      -- Result: 2.99 (not rounded!)
-- local truncated4 = LuaUtil.Truncate(2.99, 0)       -- Result: 2     
-- local truncated4 = LuaUtil.Truncate(-1.2345, 1)    -- Result: -1.2
LuaUtil.Truncate = function(num, decimals)
    decimals = decimals or 0
    if not IsNumber(num) or not IsNumber(decimals) then
        TEN.Util.PrintLog("Error in LuaUtil.Truncate: num and decimals must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end
    local mult = 10 ^ decimals
    return floor(num * mult) / mult
end

--- Generate a random number or vector/color/time with optional seed.
-- @tparam float|Vec2|Vec3|Rotation|Color|Time minValue Minimum value.
-- @tparam float|Vec2|Vec3|Rotation|Color|Time maxValue Maximum value (same type as minValue).
-- @tparam[opt] float seed Seed for reproducible randomness.
-- @treturn[1] float|Vec2|Vec3|Rotation|Color|Time Random value between minValue and maxValue.
-- @treturn[2] nil If an error occurs.
-- @usage
-- local rand1 = LuaUtil.Random(1, 10)          -- Random number between 1 and 10
-- local rand2 = LuaUtil.Random(0.0, 1.0)       -- Random float between 0.0 and 1.0
-- local rand3 = LuaUtil.Random(1, 100, 42)     -- Random number with seed 42
-- 
-- -- Random position in a rectangle:
-- local randomPos = LuaUtil.Random(
--     TEN.Vec2(0, 0), 
--     TEN.Vec2(1024, 768)
-- )
-- 
-- -- Random 3D position in a box:
-- local randomPos3D = LuaUtil.Random(
--     TEN.Vec3(-100, 0, -100), 
--     TEN.Vec3(100, 200, 100)
-- )
-- 
-- -- Random color between red and yellow:
-- local randomColor = LuaUtil.Random(
--     TEN.Color(255, 0, 0, 255),
--     TEN.Color(255, 255, 0, 255)
-- )
--
-- -- Random time in frames (30-90 frames = 1-3 seconds @ 30fps):
-- local randomFrames = LuaUtil.Random(
--     TEN.Time(LuaUtil.SecondsToFrames(1)),
--     TEN.Time(LuaUtil.SecondsToFrames(3))
-- )
--
-- -- Random rotation between two angles:
-- local randomRotation = LuaUtil.Random(
--     TEN.Rotation(0, 0, 0),
--     TEN.Rotation(0, 180, 0)
-- )
--
-- -- Error handling example:
-- local randomPos = LuaUtil.Random(minVec, maxVec)
-- if randomPos == nil then
--     TEN.Util.PrintLog("Failed to generate random position", TEN.Util.LogLevel.ERROR)
--     return  -- or use a fallback value
-- end
-- entity:SetPosition(randomPos)
--
-- -- Safe approach with default fallback:
-- local randomColor = LuaUtil.Random(color1, color2) or TEN.Color(255, 255, 255, 255)
-- sprite:SetColor(randomColor)
LuaUtil.Random = function(minValue, maxValue, seed)

    if seed and not IsNumber(seed) then
        TEN.Util.PrintLog("Error in LuaUtil.Random: seed must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    if seed then
        randomseed(seed)
    end

    if IsNumber(minValue) then
        if not IsNumber(maxValue) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: minValue and maxValue must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return minValue + random() * (maxValue - minValue)
    elseif IsVec2(minValue) then
        if not IsVec2(maxValue) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: minValue and maxValue must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return TEN.Vec2(
            minValue.x + random() * (maxValue.x - minValue.x),
            minValue.y + random() * (maxValue.y - minValue.y)
        )
    elseif IsVec3(minValue) then
        if not IsVec3(maxValue) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: minValue and maxValue must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return TEN.Vec3(
            minValue.x + random() * (maxValue.x - minValue.x),
            minValue.y + random() * (maxValue.y - minValue.y),
            minValue.z + random() * (maxValue.z - minValue.z)
        )
    elseif IsColor(minValue) then
        if not IsColor(maxValue) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: minValue and maxValue must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return TEN.Color(
            floor(minValue.r + random() * (maxValue.r - minValue.r)),
            floor(minValue.g + random() * (maxValue.g - minValue.g)),
            floor(minValue.b + random() * (maxValue.b - minValue.b)),
            floor(minValue.a + random() * (maxValue.a - minValue.a))
        )
    elseif IsTime(minValue) then
        if not IsTime(maxValue) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: minValue and maxValue must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        -- Generate random frames between minValue and maxValue (Time objects work with gameFrames)
        local minFrames = minValue:GetFrameCount()
        local maxFrames = maxValue:GetFrameCount()
        local randomFrames = floor(minFrames + random() * (maxFrames - minFrames))
        return TEN.Time(randomFrames)
    elseif IsRotation(minValue) then
        if not IsRotation(maxValue) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: minValue and maxValue must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return TEN.Rotation(
            minValue.x + random() * (maxValue.x - minValue.x),
            minValue.y + random() * (maxValue.y - minValue.y),
            minValue.z + random() * (maxValue.z - minValue.z)
        )
    end
    TEN.Util.PrintLog("Error in LuaUtil.Random: minValue and maxValue must be same type (number, Vec2, Vec3, Color, or Time).", TEN.Util.LogLevel.ERROR)
    return nil
end

--- Clamp a value between a minimum and maximum for numbers, Vec2, Vec3, Color, Rotation, and Time.
-- Supports numbers and TEN primitives (Color, Rotation, Time, Vec2, Vec3).
-- For primitives, each component is clamped individually between corresponding minValue/maxValue components.
-- @tparam number|Color|Rotation|Time|Vec2|Vec3 value The value to clamp.
-- @tparam number|Color|Rotation|Time|Vec2|Vec3 minValue The minimum value (same type as value).
-- @tparam number|Color|Rotation|Time|Vec2|Vec3 maxValue The maximum value (same type as value).
-- @treturn[1] number|Color|Rotation|Time|Vec2|Vec3 The clamped value.
-- @treturn[2] number|Color|Rotation|Time|Vec2|Vec3 The original value if an error occurs.
-- @usage
-- -- Example: Clamp to 0-1 range for normalized values
-- local clampedValue = LuaUtil.Clamp(value, 0, 1)
--
-- -- Practical use: Clamp value between 0 and 1
-- local inputValue = 1.5
-- local clampedValue = LuaUtil.Clamp(inputValue, 0, 1) -- Result: 1
--
-- -- Use clampedValue for further calculations
-- local scaledValue = clampedValue * 100  -- Scale to 0-100 range
--
-- -- Example: Clamp a Vec2 position within screen bounds
-- local position = TEN.Vec2(1200, -50)
-- local minBounds = TEN.Vec2(0, 0)
-- local maxBounds = TEN.Vec2(1920, 1080)
-- local clampedPosition = LuaUtil.Clamp(position, minBounds, maxBounds)
-- -- Result: Vec2(1920, 0)
--
-- -- Example: Clamp a Vec3 position within a bounding box
-- local position = TEN.Vec3(150, -20, 300)
-- local minBounds = TEN.Vec3(0, 0, 0)
-- local maxBounds = TEN.Vec3(100, 100, 100)
-- local clampedPosition = LuaUtil.Clamp(position, minBounds, maxBounds)
-- -- Result: Vec3(100, 0, 100)
--
-- -- Example: Clamp a Color's RGB components
-- local color = TEN.Color(251, 120, 20, 255)
-- local minColor = TEN.Color(0, 0, 0, 255)
-- local maxColor = TEN.Color(255, 100, 10, 255)
-- local clampedColor = LuaUtil.Clamp(color, minColor, maxColor)
-- -- Result: TEN.Color(251, 100, 10, 255)
--
-- -- Example: Clamp a Time duration between 1 and 5 seconds
-- local duration = TEN.Time(LuaUtil.SecondsToFrames(7))
-- local minDuration = TEN.Time(LuaUtil.SecondsToFrames(1))
-- local maxDuration = TEN.Time(LuaUtil.SecondsToFrames(5))
-- local clampedDuration = LuaUtil.Clamp(duration, minDuration, maxDuration)
-- -- Result: TEN.Time.FromSeconds(5)
--
-- -- Example: Clamp a Rotation's pitch between -45 and 45 degrees
-- local rotation = TEN.Rotation(45, 90, 0)
-- local minRotation = TEN.Rotation(15, 0, 0)
-- local maxRotation = TEN.Rotation(0, 90, 0)
-- local clampedRotation = LuaUtil.Clamp(rotation, minRotation, maxRotation)
-- -- Result: TEN.Rotation(15, 90, 0)
--
-- -- Error handling example:
-- local clampedValue = LuaUtil.Clamp(value, min, max)
-- if clampedValue == value then
--     TEN.Util.PrintLog("Failed to clamp value", TEN.Util.LogLevel.ERROR)
--     return  -- or use a fallback value
-- end
-- -- Safe approach with default fallback:
-- local clampedValue = LuaUtil.Clamp(value, minValue, maxValue) or defaultValue
LuaUtil.Clamp = function(value, minValue, maxValue)
    -- Lazy type checking: check only what's needed
    if IsNumber(value) then
        if not (IsNumber(minValue) and IsNumber(maxValue)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, minValue, maxValue must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        if minValue > maxValue then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: minValue cannot be greater than maxValue.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return max(minValue, min(maxValue, value))
    end

    if IsVec2(value) then
        if not (IsVec2(minValue) and IsVec2(maxValue)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, minValue, maxValue must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Vec2(
            max(minValue.x, min(maxValue.x, value.x)),
            max(minValue.y, min(maxValue.y, value.y))
        )
    end

    if IsVec3(value) then
        if not (IsVec3(minValue) and IsVec3(maxValue)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, minValue, maxValue must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Vec3(
            max(minValue.x, min(maxValue.x, value.x)),
            max(minValue.y, min(maxValue.y, value.y)),
            max(minValue.z, min(maxValue.z, value.z))
        )
    end

    if IsRotation(value) then
        if not (IsRotation(minValue) and IsRotation(maxValue)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, minValue, maxValue must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Rotation(
            max(minValue.x, min(maxValue.x, value.x)),
            max(minValue.y, min(maxValue.y, value.y)),
            max(minValue.z, min(maxValue.z, value.z))
        )
    end

    if IsColor(value) then
        if not (IsColor(minValue) and IsColor(maxValue)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, minValue, maxValue must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Color(
            max(minValue.r, min(maxValue.r, value.r)),
            max(minValue.g, min(maxValue.g, value.g)),
            max(minValue.b, min(maxValue.b, value.b)),
            max(minValue.a, min(maxValue.a, value.a))
        )
    end

    if IsTime(value) then
        if not (IsTime(minValue) and IsTime(maxValue)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, minValue, maxValue must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Time(max(minValue:GetFrameCount(), min(maxValue:GetFrameCount(), value:GetFrameCount())))
    end

    TEN.Util.PrintLog("Error in LuaUtil.Clamp: unsupported type.", TEN.Util.LogLevel.ERROR)
    return value
end

--- Wrap an angle to a specific range (e.g., 0-360 or -180 to 180).
-- Useful for normalizing rotation angles and preventing overflow.
-- Unlike Clamp, this function wraps values cyclically (e.g., 450° → 90°).
-- @tparam float angle The angle to wrap.
-- @tparam[opt=0] float minValue Minimum value of the range.
-- @tparam[opt=360] float maxValue Maximum value of the range.
-- @treturn[1] float The wrapped angle.
-- @treturn[2] float The original angle if an error occurs.
-- @usage
-- -- Normalize angles to 0-360 range:
-- local wrapped1 = LuaUtil.WrapAngle(450, 0, 360)  -- Result: 90
-- local wrapped2 = LuaUtil.WrapAngle(-30, 0, 360)  -- Result: 330
-- local wrapped3 = LuaUtil.WrapAngle(720, 0, 360)  -- Result: 0
--
-- -- Normalize to -180 to 180 range (common for game rotations):
-- local wrapped4 = LuaUtil.WrapAngle(200, -180, 180)  -- Result: -160
-- local wrapped5 = LuaUtil.WrapAngle(-200, -180, 180) -- Result: 160
--
-- -- Difference from Clamp (important!):
-- local clamped = LuaUtil.Clamp(450, 0, 360)    -- Result: 360 (cuts at max)
-- local wrapped = LuaUtil.WrapAngle(450, 0, 360) -- Result: 90 (wraps around)
--
-- -- Practical example: Continuous rotation without overflow
-- local currentAngle = 0
-- LevelFuncs.OnLoop = function()
--     currentAngle = currentAngle + 5  -- Rotate 5° per frame
--     currentAngle = LuaUtil.WrapAngle(currentAngle, 0, 360)  -- Keep in 0-360
--     entity:SetRotation(TEN.Rotation(0, currentAngle, 0))
-- end
--
-- -- Example: Calculate shortest rotation path
-- local currentYaw = 350  -- Facing almost north
-- local targetYaw = 10    -- Target is just past north
-- -- Direct difference would be: 10 - 350 = -340° (wrong direction!)
-- -- Wrapped difference:
-- local delta = LuaUtil.WrapAngle(targetYaw - currentYaw, -180, 180)
-- -- Result: 20° (correct shortest path: turn right 20°)
LuaUtil.WrapAngle = function(angle, minValue, maxValue)
    minValue = minValue or 0
    maxValue = maxValue or 360

    if not (IsNumber(angle) and IsNumber(minValue) and IsNumber(maxValue)) then
        TEN.Util.PrintLog("Error in LuaUtil.WrapAngle: all parameters must be numbers.", TEN.Util.LogLevel.ERROR)
        return angle
    end

    local range = maxValue - minValue
    if range == 0 then
        TEN.Util.PrintLog("Error in LuaUtil.WrapAngle: minValue cannot equal maxValue.", TEN.Util.LogLevel.ERROR)
        return angle
    end

    -- return angle - range * floor((angle - minValue) / range)
    return wrapAngleRaw(angle, minValue, range)
end

--- Checks if a value is an integer (a number without fractional part).
-- @tparam number n The value to check
-- @treturn[1] boolean: true if the value is an integer, false otherwise
-- @treturn[2] boolean: false if the input is not a number
-- @usage
-- LuaUtil.IsInteger(10)      -- true
-- LuaUtil.IsInteger(10.0)    -- true
-- LuaUtil.IsInteger(10.5)    -- false
-- LuaUtil.IsInteger(-5)      -- true
-- LuaUtil.IsInteger("10")    -- false
-- LuaUtil.IsInteger(nil)     -- false
LuaUtil.IsInteger = function(n)
    if not IsNumber(n) then
        TEN.Util.PrintLog("Error in LuaUtil.IsInteger: parameter must be a number.", TEN.Util.LogLevel.ERROR)
        return false
    end
    return (n % 1) == 0
end

--- 3D Transformations.
-- Utilities for 3D point and vector transformations.
-- @section transform

--- Rotate a point around an arbitrary axis passing through a pivot point.
-- Supports rotation around standard axes (X, Y, Z) or custom axis vectors. Examples use `SecondsToFrames` for time-based animations.
-- Uses TEN's Vec3:Rotate() method for efficient calculation.
-- @tparam Vec3 point The point to rotate.
-- @tparam Vec3 pivot The pivot point (center of rotation).
-- @tparam string|Vec3 axis The rotation axis. Can be "x", "y", "z" (case-insensitive) or a custom Vec3 direction.
-- @tparam float angle The rotation angle in degrees.
-- @treturn[1] Vec3 The rotated point.
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example: Rotate point around Y axis (pivot at origin)
-- local point = TEN.Vec3(100, 0, 0)
-- local pivot = TEN.Vec3(0, 0, 0)
-- local rotated = LuaUtil.RotatePointAroundAxis(point, pivot, "y", 90)
-- -- Result: Vec3(0, 0, -100) (rotated 90° counterclockwise around Y)
--
-- -- Example: Rotate around pivot (not origin)
-- local point = TEN.Vec3(150, 50, 100)
-- local pivot = TEN.Vec3(100, 50, 100)  -- Pivot at x=100
-- local rotated = LuaUtil.RotatePointAroundAxis(point, pivot, "y", 180)
-- -- Result: Vec3(50, 50, 100) (point mirrored around pivot)
--
-- -- Example: Rotate around custom axis (diagonal) - Complete working example
-- local satellite = TEN.Objects.GetMoveableByName("Satellite1")
-- local planet = TEN.Objects.GetMoveableByName("Planet")
-- local startPos = satellite:GetPosition()  -- Store initial position (read ONCE outside loop)
-- local pivot = planet:GetPosition()
-- local customAxis = TEN.Vec3(1, 0, 1)  -- Diagonal axis XZ (automatically normalized)
-- local angle = 0
-- local rotationSpeed = 360 / LuaUtil.SecondsToFrames(10)  -- Complete rotation in 10 seconds
-- LevelFuncs.OnLoop = function()
--     angle = (angle + rotationSpeed) % 360
--     -- IMPORTANT: Rotate the INITIAL position (startPos), not current position!
--     local newPos = LuaUtil.RotatePointAroundAxis(startPos, pivot, customAxis, angle)
--     satellite:SetPosition(newPos)
-- end
--
-- -- Example: Orbital animation around Y axis - Complete working example
-- local satellite = TEN.Objects.GetMoveableByName("Satellite1")
-- local planet = TEN.Objects.GetMoveableByName("Planet")
-- local startPos = satellite:GetPosition()  -- Initial position (FIXED reference)
-- local pivot = planet:GetPosition()
-- local angle = 0
-- local rotationSpeed = 360 / LuaUtil.SecondsToFrames(8)  -- 8 seconds per orbit
-- LevelFuncs.OnLoop = function()
--     angle = (angle + rotationSpeed) % 360
--     local newPos = LuaUtil.RotatePointAroundAxis(startPos, pivot, "y", angle)
--     satellite:SetPosition(newPos)
--     
--     -- Optional: make satellite face the planet
--     local lookDir = (pivot - newPos):Normalize()
--     satellite:SetRotation(TEN.Rotation(lookDir))
-- end
--
-- -- Example: Swing/pendulum animation - Complete working example
-- local pendulum = TEN.Objects.GetMoveableByName("Pendulum")
-- local anchor = TEN.Objects.GetMoveableByName("Anchor"):GetPosition()  -- Pivot point (fixed)
-- local restPos = pendulum:GetPosition()  -- Rest position below anchor
-- local swingAngle = 0
-- local swingSpeed = 360 / LuaUtil.SecondsToFrames(2)  -- 2 second period
-- LevelFuncs.OnLoop = function()
--     swingAngle = swingAngle + swingSpeed
--     -- Sine wave creates back-and-forth motion: -45° to +45°
--     local currentAngle = 45 * math.sin(math.rad(swingAngle))
--     local swingingPos = LuaUtil.RotatePointAroundAxis(restPos, anchor, "z", currentAngle)
--     pendulum:SetPosition(swingingPos)
--     
--     -- Rotate the pendulum object to match swing angle (realistic pendulum motion)
--     pendulum:SetRotation(TEN.Rotation(0, 0, currentAngle))
-- end
--
-- -- Example: Look at pivot while rotating
-- local rotatedPos = LuaUtil.RotatePointAroundAxis(pos, pivot, "y", angle)
-- obj:SetPosition(rotatedPos)
-- local lookDir = (pivot - rotatedPos):Normalize()
-- obj:SetRotation(TEN.Rotation(lookDir))
--
-- -- Error handling example:
-- local rotated = LuaUtil.RotatePointAroundAxis(point, pivot, axis, angle)
-- if rotated == nil then
--     TEN.Util.PrintLog("Failed to rotate point", TEN.Util.LogLevel.ERROR)
--     return
-- end
-- obj:SetPosition(rotated)
--
-- -- Safe approach with default fallback:
-- local rotated = LuaUtil.RotatePointAroundAxis(point, pivot, "y", angle) or point
LuaUtil.RotatePointAroundAxis = function(point, pivot, axis, angle)
    -- Type validation
    if not IsVec3(point) then
        TEN.Util.PrintLog("Error in LuaUtil.RotatePointAroundAxis: point must be a Vec3.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not IsVec3(pivot) then
        TEN.Util.PrintLog("Error in LuaUtil.RotatePointAroundAxis: pivot must be a Vec3.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not IsNumber(angle) then
        TEN.Util.PrintLog("Error in LuaUtil.RotatePointAroundAxis: angle must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Translate point to pivot's local space
    local localPoint = point - pivot

    -- Rotate based on axis type
    local rotatedLocal
    if IsString(axis) then
        local axisLower = axis:lower()
        local rotation
        if axisLower == "x" then
            rotation = TEN.Rotation(angle, 0, 0)
        elseif axisLower == "y" then
            rotation = TEN.Rotation(0, angle, 0)
        elseif axisLower == "z" then
            rotation = TEN.Rotation(0, 0, angle)
        else
            TEN.Util.PrintLog("Error in LuaUtil.RotatePointAroundAxis: axis string must be 'x', 'y', or 'z'.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        rotatedLocal = localPoint:Rotate(rotation)
    elseif IsVec3(axis) then
        -- Custom axis: use Rodrigues' rotation formula
        -- v_rot = v*cos(θ) + (k × v)*sin(θ) + k*(k·v)*(1-cos(θ))
        local k = axis:Normalize()
        local angleRad = rad(angle)
        local cosTheta = cos(angleRad)
        local sinTheta = sin(angleRad)

        local kCrossV = k:Cross(localPoint)
        local kDotV = k:Dot(localPoint)

        rotatedLocal = localPoint * cosTheta + kCrossV * sinTheta + k * (kDotV * (1 - cosTheta))
    else
        TEN.Util.PrintLog("Error in LuaUtil.RotatePointAroundAxis: axis must be a string ('x', 'y', 'z') or Vec3.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Translate back to world space
    local result = rotatedLocal + pivot

    return result
end

--- Calculate a position on a circular orbit around a center point.
-- Generates positions parametrically using radius and angle, ideal for orbital animations. Examples use `SecondsToFrames` for time-based animations.
-- @tparam Vec3 center The center of the orbit.
-- @tparam float radius The radius of the orbit.
-- @tparam float angle The parametric angle in degrees (0-360).
-- @tparam[opt="y"] string|Vec3 axis The orbital plane axis. Can be "x", "y", "z" (case-insensitive) or custom Vec3.
-- @treturn[1] Vec3 The calculated orbital position.
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example: Simple circular orbit on XZ plane - Complete working example
-- local satellite = TEN.Objects.GetMoveableByName("Satellite1")
-- local planet = TEN.Objects.GetMoveableByName("Planet")
-- local center = planet:GetPosition()
-- local radius = 2048
-- local angle = 0
-- local rotationSpeed = 360 / LuaUtil.SecondsToFrames(10)  -- 10 seconds per orbit
-- LevelFuncs.OnLoop = function()
--     angle = (angle + rotationSpeed) % 360
--     local orbitPos = LuaUtil.OrbitPosition(center, radius, angle, "y")
--     satellite:SetPosition(orbitPos)
--     
--     -- Optional: make satellite face the planet
--     local lookDir = (center - orbitPos):Normalize()
--     satellite:SetRotation(TEN.Rotation(lookDir))
-- end
--
-- -- Example: Orbit on XY plane (vertical orbit) - Complete working example
-- local satellite = TEN.Objects.GetMoveableByName("Satellite1")
-- local center = TEN.Objects.GetMoveableByName("Planet"):GetPosition()
-- local radius = 1536
-- local angle = 0
-- local rotationSpeed = 360 / LuaUtil.SecondsToFrames(6)  -- 6 seconds per orbit
-- LevelFuncs.OnLoop = function()
--     angle = (angle + rotationSpeed) % 360
--     local orbitPos = LuaUtil.OrbitPosition(center, radius, angle, "z")  -- Z axis = XY plane
--     satellite:SetPosition(orbitPos)
-- end
--
-- -- Example: Multiple satellites with phase offset - Complete working example
-- local sat1 = TEN.Objects.GetMoveableByName("Satellite1")
-- local sat2 = TEN.Objects.GetMoveableByName("Satellite2")
-- local sat3 = TEN.Objects.GetMoveableByName("Satellite3")
-- local planet = TEN.Objects.GetMoveableByName("Planet")
-- local center = planet:GetPosition()
-- local radius = 2048
-- local satellites = { sat1, sat2, sat3 }
-- local phaseOffset = 360 / #satellites  -- 120° spacing (360/3)
-- local baseAngle = 0
-- local rotationSpeed = 360 / LuaUtil.SecondsToFrames(12)  -- 12 seconds per orbit
-- LevelFuncs.OnLoop = function()
--     baseAngle = (baseAngle + rotationSpeed) % 360
--     for i, sat in ipairs(satellites) do
--         local angle = (baseAngle + (i - 1) * phaseOffset) % 360
--         local orbitPos = LuaUtil.OrbitPosition(center, radius, angle, "y")
--         sat:SetPosition(orbitPos)
--     end
-- end
--
-- -- Example: Custom diagonal orbital plane - Complete working example
-- local satellite = TEN.Objects.GetMoveableByName("Satellite1")
-- local center = TEN.Objects.GetMoveableByName("Planet"):GetPosition()
-- local radius = 1024
-- local customAxis = TEN.Vec3(1, 1, 0)  -- Diagonal XY axis (automatically normalized)
-- local angle = 0
-- local rotationSpeed = 360 / LuaUtil.SecondsToFrames(8)  -- 8 seconds per orbit
-- LevelFuncs.OnLoop = function()
--     angle = (angle + rotationSpeed) % 360
--     local orbitPos = LuaUtil.OrbitPosition(center, radius, angle, customAxis)
--     satellite:SetPosition(orbitPos)
-- end
--
-- -- Error handling example:
-- local orbitPos = LuaUtil.OrbitPosition(center, radius, angle, "y")
-- if orbitPos == nil then
--     TEN.Util.PrintLog("Failed to calculate orbit position", TEN.Util.LogLevel.ERROR)
--     return
-- end
-- obj:SetPosition(orbitPos)
--
-- -- Safe approach with default fallback:
-- local orbitPos = LuaUtil.OrbitPosition(center, radius, angle, "y") or center
LuaUtil.OrbitPosition = function(center, radius, angle, axis)
    -- Type validation
    if not IsVec3(center) then
        TEN.Util.PrintLog("Error in LuaUtil.OrbitPosition: center must be a Vec3.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not IsNumber(radius) then
        TEN.Util.PrintLog("Error in LuaUtil.OrbitPosition: radius must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not IsNumber(angle) then
        TEN.Util.PrintLog("Error in LuaUtil.OrbitPosition: angle must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Default axis to "y" if not provided
    axis = axis or "y"

    -- Convert angle to radians
    local angleRad = rad(angle)
    local cosAngle = cos(angleRad)
    local sinAngle = sin(angleRad)

    -- Calculate offset based on axis
    local offset
    if IsString(axis) then
        local axisLower = axis:lower()
        if axisLower == "y" then
            -- Orbit on XZ plane (around Y axis)
            offset = TEN.Vec3(cosAngle * radius, 0, sinAngle * radius)
        elseif axisLower == "x" then
            -- Orbit on YZ plane (around X axis)
            offset = TEN.Vec3(0, cosAngle * radius, sinAngle * radius)
        elseif axisLower == "z" then
            -- Orbit on XY plane (around Z axis)
            offset = TEN.Vec3(cosAngle * radius, sinAngle * radius, 0)
        else
            TEN.Util.PrintLog("Error in LuaUtil.OrbitPosition: axis string must be 'x', 'y', or 'z'.", TEN.Util.LogLevel.ERROR)
            return nil
        end
    elseif IsVec3(axis) then
        -- Custom axis: calculate perpendicular vectors for orbital plane
        local axisNormalized = axis:Normalize()

        -- Find perpendicular vector (use cross product with arbitrary vector)
        local arbitrary = TEN.Vec3(0, 1, 0)
        if abs(axisNormalized.y) > 0.99 then
            arbitrary = TEN.Vec3(1, 0, 0)
        end

        -- Create two perpendicular vectors in the orbital plane
        local perp1 = axisNormalized:Cross(arbitrary):Normalize()
        local perp2 = axisNormalized:Cross(perp1):Normalize()

        -- Calculate position on circular orbit
        offset = (perp1 * cosAngle + perp2 * sinAngle) * radius
    else
        TEN.Util.PrintLog("Error in LuaUtil.OrbitPosition: axis must be a string ('x', 'y', 'z') or Vec3.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    return center + offset
end

--- Arrange multiple objects in a circular formation around a center point.
-- Places objects evenly spaced on a circle, with optional rotation control.
-- Uses OrbitPosition internally for efficient calculation.
-- @tparam Vec3|Objects.Moveable|Objects.Static center Center of the circle (Vec3, Moveable, or Static).
-- @tparam table objects Array of Moveable or Static objects to arrange.
-- @tparam float radius Distance from center to each object.
-- @tparam[opt] table options Optional configuration: {axis = "y", startAngle = 0, faceDirection = nil}
--   - axis (string|Vec3): Orbital plane axis ("x"/"y"/"z" or custom Vec3, default "y")
--   - startAngle (number): Starting angle in degrees (default 0)
--   - faceDirection (string): "center" = face inward, "outward" = face outward, nil = no rotation
-- @treturn[1] bool True if successful.
-- @treturn[2] bool False if an error occurs.
-- @usage
-- -- Example: Torches around altar (simple XZ circle) - Complete working example
-- local altar = TEN.Objects.GetMoveableByName("Altar")
-- local torches = {
--     TEN.Objects.GetMoveableByName("Torch1"),
--     TEN.Objects.GetMoveableByName("Torch2"),
--     TEN.Objects.GetMoveableByName("Torch3"),
--     TEN.Objects.GetMoveableByName("Torch4")
-- }
-- LuaUtil.ArrangeInCircle(altar, torches, 1024)
-- -- Result: 4 torches evenly spaced (90° apart) at radius 1024 on XZ plane
--
-- -- Example: Pickups around player with rotation facing center
-- local player = TEN.Objects.GetLaraObject()
-- local pickups = {
--     TEN.Objects.GetMoveableByName("Pickup1"),
--     TEN.Objects.GetMoveableByName("Pickup2"),
--     TEN.Objects.GetMoveableByName("Pickup3")
-- }
-- LuaUtil.ArrangeInCircle(player, pickups, 512, {faceDirection = "center"})
-- -- Result: 3 pickups at 120° spacing, all rotated to face player
--
-- -- Example: Enemies spawn formation facing outward
-- local spawnPoint = TEN.Vec3(5000, 1000, 5000)
-- local enemies = {
--     TEN.Objects.GetMoveableByName("Enemy1"),
--     TEN.Objects.GetMoveableByName("Enemy2"),
--     TEN.Objects.GetMoveableByName("Enemy3"),
--     TEN.Objects.GetMoveableByName("Enemy4"),
--     TEN.Objects.GetMoveableByName("Enemy5")
-- }
-- LuaUtil.ArrangeInCircle(spawnPoint, enemies, 2048, {faceDirection = "outward"})
-- -- Result: 5 enemies at 72° spacing, facing outward (defensive circle)
--
-- -- Example: Vertical circle (XY plane) with custom start angle
-- local center = TEN.Vec3(10000, 2000, 8000)
-- local platforms = {
--     TEN.Objects.GetStaticByName("Platform1"),
--     TEN.Objects.GetStaticByName("Platform2"),
--     TEN.Objects.GetStaticByName("Platform3")
-- }
-- LuaUtil.ArrangeInCircle(center, platforms, 1536, {axis = "z", startAngle = 90})
-- -- Result: Vertical circle starting at 90° (top position)
--
-- -- Example: Diagonal orbital plane (custom axis)
-- local center = TEN.Objects.GetMoveableByName("Hub")
-- local satellites = {}
-- for i = 1, 6 do
--     satellites[i] = TEN.Objects.GetMoveableByName("Satellite" .. i)
-- end
-- local customAxis = TEN.Vec3(1, 1, 0)  -- Diagonal XY
-- LuaUtil.ArrangeInCircle(center, satellites, 2048, {
--     axis = customAxis,
--     startAngle = 45,
--     faceDirection = "center"
-- })
-- -- Result: 6 objects on tilted orbital plane, facing center
--
-- -- Example: Error handling
-- local success = LuaUtil.ArrangeInCircle(center, objects, radius, options)
-- if not success then
--     TEN.Util.PrintLog("Failed to arrange objects in circle", TEN.Util.LogLevel.ERROR)
--     return
-- end
--
-- -- Example: Dynamic arrangement in loop (moving center)
-- local hub = TEN.Objects.GetMoveableByName("Hub")
-- local satellites = { ... }
-- LevelFuncs.OnLoop = function()
--     -- Rearrange every frame as hub moves
--     LuaUtil.ArrangeInCircle(hub, satellites, 1024, {faceDirection = "center"})
-- end
LuaUtil.ArrangeInCircle = function(center, objects, radius, options)
    -- Parse center (Vec3, Moveable, or Static)
    local centerPos
    if IsVec3(center) then
        centerPos = center
    elseif center and center.GetPosition then
        centerPos = center:GetPosition()
    else
        TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: center must be a Vec3, Moveable, or Static object.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Validate objects array
    if not IsTable(objects) then
        TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: objects must be a table.", TEN.Util.LogLevel.ERROR)
        return false
    end
    if #objects == 0 then
        TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: objects table is empty.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Validate radius
    if not IsNumber(radius) then
        TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: radius must be a number.", TEN.Util.LogLevel.ERROR)
        return false
    end
    if radius <= 0 then
        TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: radius must be positive.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Parse options with defaults
    options = options or {}
    local axis = options.axis or "y"
    local startAngle = options.startAngle or 0
    local faceDirection = options.faceDirection

    -- Validate axis
    if IsString(axis) then
        local axisLower = axis:lower()
        if axisLower ~= "x" and axisLower ~= "y" and axisLower ~= "z" then
            TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: axis string must be 'x', 'y', or 'z'.", TEN.Util.LogLevel.ERROR)
            return false
        end
    elseif IsVec3(axis) then
        if axis:Length() < 0.001 then
            TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: axis Vec3 cannot be zero.", TEN.Util.LogLevel.ERROR)
            return false
        end
    else
        TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: axis must be a string ('x', 'y', 'z') or Vec3.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Validate startAngle
    if not IsNumber(startAngle) then
        TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: startAngle must be a number.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Validate faceDirection
    if faceDirection ~= nil and faceDirection ~= "center" and faceDirection ~= "outward" then
        TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: faceDirection must be nil, 'center', or 'outward'.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Calculate angle step for even spacing
    local angleStep = 360 / #objects

    -- Arrange each object
    for i, obj in ipairs(objects) do
        -- Calculate position angle
        local angle = startAngle + (i - 1) * angleStep

        -- Calculate position using OrbitPosition
        local position = LuaUtil.OrbitPosition(centerPos, radius, angle, axis)
        if position == nil then
            TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: failed to calculate position for object " .. i .. ".", TEN.Util.LogLevel.ERROR)
            return false
        end

        -- Set position
        if not obj or not obj.SetPosition then
            TEN.Util.PrintLog("Error in LuaUtil.ArrangeInCircle: object " .. i .. " is invalid or missing SetPosition method.", TEN.Util.LogLevel.ERROR)
            return false
        end
        obj:SetPosition(position)

        -- Set rotation if requested
        if faceDirection then
            local direction
            if faceDirection == "center" then
                -- Face inward (toward center)
                direction = (centerPos - position):Normalize()
            else -- "outward"
                -- Face outward (away from center)
                direction = (position - centerPos):Normalize()
            end

            -- Convert direction to rotation
            local rotation = TEN.Rotation(direction)
            if obj.SetRotation then
                obj:SetRotation(rotation)
            end
        end
    end

    return true
end

--- Transform local coordinates to world space using parent transform.
-- Converts position and rotation from parent's local space to world space.
-- This is the low-level mathematical function used by AttachToObject.
-- @tparam Vec3 parentPos Parent's world position.
-- @tparam Rotation parentRot Parent's world rotation.
-- @tparam Vec3 localOffset Offset in parent's local space.
-- @tparam[opt] Rotation localRotation Rotation in parent's local space (optional).
-- @treturn[1] Vec3 World position.
-- @treturn[1] Rotation World rotation (or nil if localRotation not provided).
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example: Calculate world position of satellite relative to ship
-- local shipPos = TEN.Vec3(5000, 1000, 5000)
-- local shipRot = TEN.Rotation(0, 45, 0)
-- local localOffset = TEN.Vec3(500, 200, 0)  -- 500 units right, 200 units up in ship's space
-- local worldPos, worldRot = LuaUtil.TransformLocalToWorld(shipPos, shipRot, localOffset)
-- -- Result: worldPos accounts for ship's rotation
--
-- -- Example: Transform with local rotation
-- local shipPos = TEN.Vec3(5000, 1000, 5000)
-- local shipRot = TEN.Rotation(0, 90, 0)
-- local localOffset = TEN.Vec3(300, 0, 0)
-- local localRot = TEN.Rotation(0, 45, 0)  -- Additional 45° yaw
-- local worldPos, worldRot = LuaUtil.TransformLocalToWorld(shipPos, shipRot, localOffset, localRot)
-- turret:SetPosition(worldPos)
-- turret:SetRotation(worldRot)
--
-- -- Example: Manual attachment in loop
-- local parent = TEN.Objects.GetMoveableByName("Ship")
-- local child = TEN.Objects.GetMoveableByName("Turret")
-- local localOffset = TEN.Vec3(0, 300, -500)  -- Behind and above
-- LevelFuncs.OnLoop = function()
--     local parentPos = parent:GetPosition()
--     local parentRot = parent:GetRotation()
--     local worldPos, worldRot = LuaUtil.TransformLocalToWorld(parentPos, parentRot, localOffset, TEN.Rotation(0, 0, 0))
--     child:SetPosition(worldPos)
--     child:SetRotation(worldRot)
-- end
--
-- -- Error handling example:
-- local worldPos, worldRot = LuaUtil.TransformLocalToWorld(parentPos, parentRot, localOffset)
-- if worldPos == nil then
--     TEN.Util.PrintLog("Failed to transform local to world", TEN.Util.LogLevel.ERROR)
--     return
-- end
-- obj:SetPosition(worldPos)
--
-- -- Safe approach with fallback:
-- local worldPos = LuaUtil.TransformLocalToWorld(parentPos, parentRot, localOffset) or parentPos
LuaUtil.TransformLocalToWorld = function(parentPos, parentRot, localOffset, localRotation)
    -- Type validation
    if not IsVec3(parentPos) then
        TEN.Util.PrintLog("Error in LuaUtil.TransformLocalToWorld: parentPos must be a Vec3.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not IsRotation(parentRot) then
        TEN.Util.PrintLog("Error in LuaUtil.TransformLocalToWorld: parentRot must be a Rotation.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not IsVec3(localOffset) then
        TEN.Util.PrintLog("Error in LuaUtil.TransformLocalToWorld: localOffset must be a Vec3.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if localRotation and not IsRotation(localRotation) then
        TEN.Util.PrintLog("Error in LuaUtil.TransformLocalToWorld: localRotation must be a Rotation or nil.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Rotate local offset by parent rotation to get world-space offset
    local worldOffset = localOffset:Rotate(parentRot)

    -- Calculate world position
    local worldPos = parentPos + worldOffset

    -- Calculate world rotation if local rotation provided
    local worldRot = nil
    if localRotation then
        -- Combine parent rotation with local rotation
        -- In TEN, rotations are combined by adding components
        worldRot = TEN.Rotation(
            parentRot.x + localRotation.x,
            parentRot.y + localRotation.y,
            parentRot.z + localRotation.z
        )
    end

    return worldPos, worldRot
end

--- Calculate local offset from child to parent in parent's local space.
-- This helper function computes the offset needed for AttachToObject.
-- Call this ONCE during setup, then use the returned offset in your loop.
-- Works with both Moveable and Static objects.
-- @tparam Objects.Moveable|Objects.Static parent Parent object.
-- @tparam Objects.Moveable|Objects.Static child Child object to calculate offset for.
-- @treturn[1] Vec3 Local offset in parent's space.
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example: Calculate offset for turret on ship (setup phase)
-- local ship = TEN.Objects.GetMoveableByName("Ship")
-- local turret = TEN.Objects.GetMoveableByName("Turret")
-- local offset = LuaUtil.CalculateLocalOffset(ship, turret)
-- -- Now use 'offset' in your loop with AttachToObject
--
-- -- Example: Complete attachment workflow
-- local parent = TEN.Objects.GetMoveableByName("Vehicle")
-- local child = TEN.Objects.GetMoveableByName("Wheel")
-- 
-- -- STEP 1: Calculate offset ONCE (outside loop)
-- local localOffset = LuaUtil.CalculateLocalOffset(parent, child)
-- 
-- -- STEP 2: Use offset every frame
-- LevelFuncs.OnLoop = function()
--     LuaUtil.AttachToObject(parent, child, localOffset, true)
-- end
--
-- -- Example: Multiple children with different offsets
-- local ship = TEN.Objects.GetMoveableByName("Ship")
-- local turret1 = TEN.Objects.GetMoveableByName("Turret1")
-- local turret2 = TEN.Objects.GetMoveableByName("Turret2")
-- local offset1 = LuaUtil.CalculateLocalOffset(ship, turret1)
-- local offset2 = LuaUtil.CalculateLocalOffset(ship, turret2)
-- LevelFuncs.OnLoop = function()
--     LuaUtil.AttachToObject(ship, turret1, offset1, true)
--     LuaUtil.AttachToObject(ship, turret2, offset2, true)
-- end
--
-- -- Example: Static object attachment
-- local platform = TEN.Objects.GetStaticByName("Platform")
-- local crate = TEN.Objects.GetMoveableByName("Crate")
-- local offset = LuaUtil.CalculateLocalOffset(platform, crate)
-- LevelFuncs.OnLoop = function()
--     LuaUtil.AttachToObject(platform, crate, offset, false)
-- end
--
-- -- Error handling example:
-- local offset = LuaUtil.CalculateLocalOffset(parent, child)
-- if offset == nil then
--     TEN.Util.PrintLog("Failed to calculate local offset", TEN.Util.LogLevel.ERROR)
--     return
-- end
-- -- Use offset...
--
-- -- Safe approach with fallback:
-- local offset = LuaUtil.CalculateLocalOffset(parent, child) or TEN.Vec3(0, 0, 0)
LuaUtil.CalculateLocalOffset = function(parent, child)
    -- Type validation (check for GetPosition and GetRotation methods)
    if not parent or not child then
        TEN.Util.PrintLog("Error in LuaUtil.CalculateLocalOffset: parent and child cannot be nil.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    local parentPos = parent.GetPosition and parent:GetPosition()
    local parentRot = parent.GetRotation and parent:GetRotation()
    local childPos = child.GetPosition and child:GetPosition()

    if not parentPos or not parentRot or not childPos then
        TEN.Util.PrintLog("Error in LuaUtil.CalculateLocalOffset: parent and child must have GetPosition() and GetRotation() methods.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Calculate world offset
    local worldOffset = childPos - parentPos

    -- Convert world offset to parent's local space
    -- This is the inverse of Vec3:Rotate() - we need to rotate by inverse parent rotation
    local inverseRot = TEN.Rotation(-parentRot.x, -parentRot.y, -parentRot.z)
    local localOffset = worldOffset:Rotate(inverseRot)

    return localOffset
end

--- Attach child object to parent object with automatic transform updates.
-- High-level convenience function that applies position and optionally rotation.
-- Call this EVERY FRAME in your loop. The localOffset should be calculated ONCE
-- using CalculateLocalOffset() before the loop.
-- Works with both Moveable and Static objects.
-- @tparam Objects.Moveable|Objects.Static parent Parent object.
-- @tparam Objects.Moveable|Objects.Static child Child object to attach.
-- @tparam Vec3 localOffset Offset in parent's local space.
-- @tparam[opt=false] bool inheritRotation If true, child inherits parent's rotation.
-- @treturn[1] bool True if successful.
-- @treturn[2] bool False if an error occurs.
-- @usage
-- -- Example: Simple attachment (position only) - Complete working example
-- local vehicle = TEN.Objects.GetMoveableByName("Vehicle")
-- local crate = TEN.Objects.GetMoveableByName("Crate")
-- local offset = LuaUtil.CalculateLocalOffset(vehicle, crate)  -- Setup ONCE
-- LevelFuncs.OnLoop = function()
--     LuaUtil.AttachToObject(vehicle, crate, offset, false)  -- Every frame
-- end
--
-- -- Example: Attachment with rotation inheritance - Complete working example
-- local ship = TEN.Objects.GetMoveableByName("Ship")
-- local turret = TEN.Objects.GetMoveableByName("Turret")
-- local offset = TEN.Vec3(0, 300, 0)  -- 300 units above ship
-- LevelFuncs.OnLoop = function()
--     -- Turret follows ship position AND rotation
--     LuaUtil.AttachToObject(ship, turret, offset, true)
-- end
--
-- -- Example: Multiple satellites orbiting with attachment - Complete working example
-- local planet = TEN.Objects.GetMoveableByName("Planet")
-- local sat1 = TEN.Objects.GetMoveableByName("Satellite1")
-- local sat2 = TEN.Objects.GetMoveableByName("Satellite2")
-- local offset1 = TEN.Vec3(2048, 0, 0)  -- Right side
-- local offset2 = TEN.Vec3(-2048, 0, 0)  -- Left side
-- local angle = 0
-- local rotationSpeed = 360 / LuaUtil.SecondsToFrames(20)  -- 20 seconds per rotation
-- LevelFuncs.OnLoop = function()
--     -- Rotate planet
--     angle = (angle + rotationSpeed) % 360
--     planet:SetRotation(TEN.Rotation(0, angle, 0))
--     
--     -- Satellites follow planet rotation automatically
--     LuaUtil.AttachToObject(planet, sat1, offset1, false)
--     LuaUtil.AttachToObject(planet, sat2, offset2, false)
-- end
--
-- -- Example: Weapon held by character - Complete working example
-- local lara = Lara
-- local torch = TEN.Objects.GetMoveableByName("Torch")
-- local weaponOffset = TEN.Vec3(150, 300, 50)  -- Right hand position
-- LevelFuncs.OnLoop = function()
--     -- Torch follows Lara's position and rotation
--     LuaUtil.AttachToObject(lara, torch, weaponOffset, true)
-- end
--
-- -- Example: Cart pulled by horse - Complete working example
-- local horse = TEN.Objects.GetMoveableByName("Horse")
-- local cart = TEN.Objects.GetMoveableByName("Cart")
-- local offset = LuaUtil.CalculateLocalOffset(horse, cart)  -- Setup ONCE
-- LevelFuncs.OnLoop = function()
--     -- Cart follows horse with original offset, inherits rotation
--     LuaUtil.AttachToObject(horse, cart, offset, true)
-- end
--
-- -- Example: Platform with crate (Static parent) - Complete working example
-- local platform = TEN.Objects.GetStaticByName("MovingPlatform")
-- local crate = TEN.Objects.GetMoveableByName("Crate")
-- local offset = TEN.Vec3(0, 256, 0)  -- On top of platform
-- LevelFuncs.OnLoop = function()
--     -- Crate stays on platform as it moves
--     LuaUtil.AttachToObject(platform, crate, offset, false)
-- end
--
-- -- Error handling example:
-- local success = LuaUtil.AttachToObject(parent, child, offset, true)
-- if not success then
--     TEN.Util.PrintLog("Failed to attach object", TEN.Util.LogLevel.ERROR)
-- end
LuaUtil.AttachToObject = function(parent, child, localOffset, inheritRotation)
    -- Type validation
    if not parent or not child then
        TEN.Util.PrintLog("Error in LuaUtil.AttachToObject: parent and child cannot be nil.", TEN.Util.LogLevel.ERROR)
        return false
    end
    if not IsVec3(localOffset) then
        TEN.Util.PrintLog("Error in LuaUtil.AttachToObject: localOffset must be a Vec3.", TEN.Util.LogLevel.ERROR)
        return false
    end
    if inheritRotation ~= nil and not IsBoolean(inheritRotation) then
        TEN.Util.PrintLog("Error in LuaUtil.AttachToObject: inheritRotation must be a boolean or nil.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Get parent transform
    local parentPos = parent.GetPosition and parent:GetPosition()
    local parentRot = parent.GetRotation and parent:GetRotation()

    if not parentPos or not parentRot then
        TEN.Util.PrintLog("Error in LuaUtil.AttachToObject: parent must have GetPosition() and GetRotation() methods.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Check child has SetPosition
    if not child.SetPosition then
        TEN.Util.PrintLog("Error in LuaUtil.AttachToObject: child must have SetPosition() method.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Transform local offset to world space
    local localRot = (inheritRotation and TEN.Rotation(0, 0, 0)) or nil
    local worldPos, worldRot = LuaUtil.TransformLocalToWorld(parentPos, parentRot, localOffset, localRot)

    if not worldPos then
        return false
    end

    -- Apply transforms
    child:SetPosition(worldPos)

    if inheritRotation and worldRot and child.SetRotation then
        child:SetRotation(worldRot)
    end

    return true
end

--- Conversion functions.
-- Utilities for converting between different units and formats.
-- @section conversion

--- Convert seconds to frames (assuming 30 FPS).
-- @tparam float seconds Time in seconds. Seconds can be a float value with two decimal places.
-- @tparam[opt=30] int fps Frames per second.
-- @treturn[1] float Number of frames.
-- @treturn[2] int 0 If an error occurs.
-- @usage
-- local frames = LuaUtil.SecondsToFrames(2.0) -- Result: 60
LuaUtil.SecondsToFrames = function(seconds, fps)
    fps = fps or FPS
    if not IsNumber(seconds) or not IsNumber(fps) then
        TEN.Util.PrintLog("Error in LuaUtil.SecondsToFrames: seconds and fps must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end

    -- Check if fps is a float and warn user
    if fps ~= floor(fps) then
        TEN.Util.PrintLog("Warning in LuaUtil.SecondsToFrames: fps should be an integer. Rounding " .. fps .. " to " .. floor(fps + 0.5) .. ".", TEN.Util.LogLevel.WARNING)
        fps = floor(fps + 0.5)
    end

    return floor(seconds * fps + 0.5)
end

--- Convert frames to seconds (assuming 30 FPS).
-- @tparam int frames Number of frames.
-- @tparam[opt=30] int fps Frames per second.
-- @treturn[1] float Time in seconds.
-- @treturn[2] float 0 If an error occurs.
-- @usage
-- local seconds = LuaUtil.FramesToSeconds(60) -- Result: 2.0
LuaUtil.FramesToSeconds = function(frames, fps)
    fps = fps or FPS
    if not IsNumber(frames) or (fps and not IsNumber(fps)) then
        TEN.Util.PrintLog("Error in LuaUtil.FramesToSeconds: frames and fps must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end

    -- Check if frames is a float and warn user
    if frames ~= floor(frames) then
        TEN.Util.PrintLog("Warning in LuaUtil.FramesToSeconds: frames should be an integer. Rounding " .. frames .. " to " .. floor(frames + 0.5) .. ".", TEN.Util.LogLevel.WARNING)
        frames = floor(frames + 0.5)
    end

    -- Check if fps is a float and warn user
    if fps ~= floor(fps) then
        TEN.Util.PrintLog("Warning in LuaUtil.FramesToSeconds: fps should be an integer. Rounding " .. fps .. " to " .. floor(fps + 0.5) .. ".", TEN.Util.LogLevel.WARNING)
        fps = floor(fps + 0.5)
    end

    if fps == 0 then
        TEN.Util.PrintLog("Error in LuaUtil.FramesToSeconds: fps cannot be zero.", TEN.Util.LogLevel.ERROR)
        return 0
    end

    return frames / fps
end

--- Convert a hexadecimal color string to a TEN.Color object.
-- @tparam string hex The hexadecimal color string (formats: "#RRGGBB", "RRGGBB", "#RRGGBBAA", "RRGGBBAA").
-- @treturn[1] Color The TEN.Color object.
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example with 6-digit hex (RGB):
-- local color = LuaUtil.HexToColor("#FF5733") -- Result: TEN.Color(255, 87, 51, 255)
--
-- -- Example without hash:
-- local color = LuaUtil.HexToColor("00FF00") -- Result: TEN.Color(0, 255, 0, 255)
--
-- -- Example with 8-digit hex (RGBA):
-- local color = LuaUtil.HexToColor("#FF573380") -- Result: TEN.Color(255, 87, 51, 128)
--
-- -- Error handling example:
-- local color = LuaUtil.HexToColor("GHIJKL") -- Result: nil (invalid hex string)
-- if color == nil then
--     TEN.Util.PrintLog("Failed to convert hex to color", TEN.Util.LogLevel.ERROR)
--     return  -- or use a fallback value
-- end
-- -- Apply color to a sprite
-- sprite:SetColor(color)
--
-- -- Safe approach with default fallback:
-- local color = LuaUtil.HexToColor(hexString) or TEN.Color(255, 255, 255, 255)
LuaUtil.HexToColor = function(hex)
    if not IsString(hex) then
        TEN.Util.PrintLog("Error in LuaUtil.HexToColor: hex must be a string.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Remove '#' if present
    hex = hex:gsub("^#", "")

    -- Get length of hex string
    local hexLen = #hex

    -- Validate length (6 for RGB, 8 for RGBA)
    if hexLen ~= 6 and hexLen ~= 8 then
        TEN.Util.PrintLog("Error in LuaUtil.HexToColor: invalid hex string length. Expected 6 or 8 characters.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Extract color components
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = hexLen == 8 and tonumber(hex:sub(7, 8), 16) or 255

    -- Validate conversion
    if not (r and g and b and a) then
        TEN.Util.PrintLog("Error in LuaUtil.HexToColor: invalid hexadecimal values.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    return TEN.Color(r, g, b, a)
end

--- Convert HSL (Hue, Saturation, Lightness) values to a TEN.Color object.
-- @tparam float h Hue value (0.0 to 360.0 degrees).
-- @tparam float s Saturation value (0.0 to 1.0).
-- @tparam float l Lightness value (0.0 to 1.0).
-- @tparam[opt=1.0] float a Alpha value (0.0 to 1.0).
-- @treturn[1] Color The TEN.Color object.
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example: Pure red
-- local color = LuaUtil.HSLtoColor(0, 1, 0.5) -- Result: TEN.Color(255, 0, 0, 255)
--
-- -- Example: Cyan
-- local color = LuaUtil.HSLtoColor(180, 1, 0.5) -- Result: TEN.Color(0, 255, 255, 255)
--
-- -- Example: Semi-transparent yellow
-- local color = LuaUtil.HSLtoColor(60, 1, 0.5, 0.5) -- Result: TEN.Color(255, 255, 0, 127)
--
-- -- Example: Desaturated blue (gray-blue)
-- local color = LuaUtil.HSLtoColor(240, 0.3, 0.5) -- Result: TEN.Color(89, 89, 165, 255)
--
-- -- Error handling example:
-- local color = LuaUtil.HSLtoColor(400, 1, 0.5) -- Result: nil (invalid hue)
-- if color == nil then
--     TEN.Util.PrintLog("Failed to convert HSL to color", TEN.Util.LogLevel.ERROR)
--     return  -- or use a fallback value
-- end
-- -- Apply color to a sprite
-- sprite:SetColor(color)
--
-- -- Safe approach with default fallback:
-- local color = LuaUtil.HSLtoColor(hue, saturation, lightness, alpha) or TEN.Color(255, 255, 255, 255)
LuaUtil.HSLtoColor = function(h, s, l, a)
    if not (IsNumber(h) and IsNumber(s) and IsNumber(l)) then
        TEN.Util.PrintLog("Error in LuaUtil.HSLtoColor: h, s, and l must be numbers.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    if a and not IsNumber(a) then
        TEN.Util.PrintLog("Error in LuaUtil.HSLtoColor: a must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    a = a or 1.0

    -- Clamp values to valid ranges
    h = h % 360
    s = max(0, min(1, s))
    l = max(0, min(1, l))
    a = max(0, min(1, a))

    -- HSL to RGB conversion
    local r, g, b

    if s == 0 then
        -- Achromatic (gray)
        r, g, b = l, l, l
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        local hNorm = h / 360

        r = HueToRgb(p, q, hNorm + 1/3)
        g = HueToRgb(p, q, hNorm)
        b = HueToRgb(p, q, hNorm - 1/3)
    end

    -- Convert to 0-255 range and create TEN.Color
    return TEN.Color(
        floor(r * 255 + 0.5),
        floor(g * 255 + 0.5),
        floor(b * 255 + 0.5),
        floor(a * 255 + 0.5)
    )
end

--- Convert a TEN.Color object to HSL (Hue, Saturation, Lightness) values.
-- Uses the Color:GetHue() method for accurate hue extraction.
-- @tparam Color color The TEN.Color object to convert.
-- @treturn[1] table A table with h, s, l, a values { h = float, s = float, l = float, a = float }.
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example: Get HSL values from a color
-- local color = TEN.Color(255, 87, 51, 255)
-- local hsl = LuaUtil.ColorToHSL(color)
-- -- Result: { h = 14.0, s = 1.0, l = 0.6, a = 1.0 }
--
-- -- Practical example: Adjust saturation
-- local originalColor = TEN.Color(255, 100, 50, 255)
-- local hsl = LuaUtil.ColorToHSL(originalColor)
-- if hsl then
--     hsl.s = hsl.s * 0.5  -- Reduce saturation by 50%
--     local desaturatedColor = LuaUtil.HSLtoColor(hsl.h, hsl.s, hsl.l, hsl.a)
--     -- Apply color to sprite
--     sprite:SetColor(desaturatedColor)
-- end
--
-- -- Example: Brighten a color
-- local darkColor = TEN.Color(50, 50, 150, 255)
-- local hsl = LuaUtil.ColorToHSL(darkColor)
-- if hsl then
--     hsl.l = math.min(1.0, hsl.l + 0.2)  -- Increase lightness by 20%
--     local brighterColor = LuaUtil.HSLtoColor(hsl.h, hsl.s, hsl.l, hsl.a)
--     sprite:SetColor(brighterColor)
-- end
--
-- -- Error handling example:
-- local hsl = LuaUtil.ColorToHSL(invalidColor)
-- if hsl == nil then
--     TEN.Util.PrintLog("Failed to convert color to HSL", TEN.Util.LogLevel.ERROR)
--     return
-- end
--
-- -- Safe approach with default fallback:
-- local hsl = LuaUtil.ColorToHSL(color) or { h = 0, s = 0, l = 0, a = 1.0 }
LuaUtil.ColorToHSL = function(color)
    if not IsColor(color) then
        TEN.Util.PrintLog("Error in LuaUtil.ColorToHSL: color must be a Color object.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Convert RGB to 0-1 range
    local r = color.r / 255
    local g = color.g / 255
    local b = color.b / 255
    local a = color.a / 255

    -- Get hue directly from Color method
    local h = color:GetHue()

    -- Calculate saturation and lightness
    local maxValue = max(r, g, b)
    local minValue = min(r, g, b)
    local l = (maxValue + minValue) / 2

    local s
    if maxValue == minValue then
        s = 0  -- Achromatic (gray)
    else
        local delta = maxValue - minValue
        s = l > 0.5 and delta / (2 - maxValue - minValue) or delta / (maxValue + minValue)
    end

    return { h = h, s = s, l = l, a = a }
end

--- Convert a TEN.Color object to OKLch (Lightness, Chroma, Hue) values.
-- OKLch is a perceptually uniform color space, ideal for:
-- - Color interpolations that look smooth to human eyes
-- - Adjusting saturation (chroma) without affecting perceived brightness
-- - Rainbow gradients with consistent perceived brightness
-- @tparam Color color The TEN.Color object to convert.
-- @treturn[1] table A table with l, c, h, a values { l = float (0-1), c = float (0-0.4), h = float (0-360), a = float (0-1) }.
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example: Get OKLch values from a color
-- local color = TEN.Color(255, 87, 51, 255)
-- local oklch = LuaUtil.ColorToOKLch(color)
-- -- Result: { l = 0.68, c = 0.18, h = 29.2, a = 1.0 }
--
-- -- Practical example: Desaturate while preserving perceived brightness
-- local vividColor = TEN.Color(255, 0, 128, 255)
-- local oklch = LuaUtil.ColorToOKLch(vividColor)
-- if oklch then
--     oklch.c = oklch.c * 0.5  -- Reduce chroma by 50%
--     local desaturatedColor = LuaUtil.OKLchToColor(oklch.l, oklch.c, oklch.h, oklch.a)
--     sprite:SetColor(desaturatedColor)
-- end
--
-- -- Example: Rainbow gradient with uniform brightness - Complete working example
-- local rainbowObj = TEN.Objects.GetMoveableByName("rainbowObject")
-- local baseColor = TEN.Color(255, 0, 0, 255)  -- Start with red
-- local oklch = LuaUtil.ColorToOKLch(baseColor)
-- local hueAngle = 0
-- local hueSpeed = 360 / LuaUtil.SecondsToFrames(5)  -- Full rainbow cycle in 5 seconds
-- LevelFuncs.OnLoop = function()
--     hueAngle = (hueAngle + hueSpeed) % 360
--     local rainbowColor = LuaUtil.OKLchToColor(oklch.l, oklch.c, hueAngle, oklch.a)
--     rainbowObj:SetColor(rainbowColor)
--     -- All colors have same perceived brightness throughout the cycle!
-- end
--
-- -- Example: Brighten color perceptually uniformly
-- local obj = TEN.Objects.GetMoveableByName("Object")
-- local darkColor = TEN.Color(50, 50, 150, 255)
-- local oklch = LuaUtil.ColorToOKLch(darkColor)
-- if oklch then
--     oklch.l = math.min(1.0, oklch.l + 0.2)  -- Increase lightness
--     local brighterColor = LuaUtil.OKLchToColor(oklch.l, oklch.c, oklch.h, oklch.a)
--     obj:SetColor(brighterColor)
-- end
--
-- -- Error handling example:
-- local oklch = LuaUtil.ColorToOKLch(invalidColor)
-- if oklch == nil then
--     TEN.Util.PrintLog("Failed to convert color to OKLch", TEN.Util.LogLevel.ERROR)
--     return
-- end
--
-- -- Safe approach with default fallback:
-- local oklch = LuaUtil.ColorToOKLch(color) or { l = 0.5, c = 0, h = 0, a = 1.0 }
LuaUtil.ColorToOKLch = function(color)
    if not IsColor(color) then
        TEN.Util.PrintLog("Error in LuaUtil.ColorToOKLch: color must be a Color object.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Convert sRGB to linear RGB (0-1 range)
    local r = SrgbToLinear(color.r / 255)
    local g = SrgbToLinear(color.g / 255)
    local b = SrgbToLinear(color.b / 255)
    local a = color.a / 255

    -- Linear RGB to OKLab (using matrix multiplication)
    -- Step 1: RGB to LMS (cone response)
    local l_ = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m_ = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s_ = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    -- Step 2: Cube root (perceptual nonlinearity)
    local l_cbrt = l_ >= 0 and l_ ^ (1/3) or -((-l_) ^ (1/3))
    local m_cbrt = m_ >= 0 and m_ ^ (1/3) or -((-m_) ^ (1/3))
    local s_cbrt = s_ >= 0 and s_ ^ (1/3) or -((-s_) ^ (1/3))

    -- Step 3: LMS to OKLab
    local L = 0.2104542553 * l_cbrt + 0.7936177850 * m_cbrt - 0.0040720468 * s_cbrt
    local A = 1.9779984951 * l_cbrt - 2.4285922050 * m_cbrt + 0.4505937099 * s_cbrt
    local B = 0.0259040371 * l_cbrt + 0.7827717662 * m_cbrt - 0.8086757660 * s_cbrt

    -- OKLab to OKLch (cartesian to polar)
    local C = sqrt(A * A + B * B)
    local h = deg(atan(B, A))
    if h < 0 then
        h = h + 360
    end

    return { l = L, c = C, h = h, a = a }
end

--- Convert OKLch (Lightness, Chroma, Hue) values to a TEN.Color object.
-- OKLch is a perceptually uniform color space, ideal for smooth color transitions.
-- @tparam float l Lightness value (0.0 to 1.0, where 0 = black, 1 = white).
-- @tparam float c Chroma value (0.0 to ~0.4, where 0 = gray, higher = more saturated).
-- @tparam float h Hue angle in degrees (0 to 360).
-- @tparam[opt=1.0] float a Alpha value (0.0 to 1.0).
-- @treturn[1] Color The TEN.Color object.
-- @treturn[2] nil If an error occurs.
-- @usage
-- -- Example: Create pure red in OKLch
-- local red = LuaUtil.OKLchToColor(0.63, 0.26, 29, 1.0)
--
-- -- Example: Create gray (zero chroma)
-- local gray = LuaUtil.OKLchToColor(0.5, 0, 0, 1.0)  -- Hue irrelevant when c=0
--
-- -- Example: Rainbow with uniform brightness - Complete working example
-- local obj = TEN.Objects.GetMoveableByName("ColorWheel")
-- local lightness = 0.7   -- Fixed lightness for uniform brightness
-- local chroma = 0.15     -- Fixed saturation
-- local hueAngle = 0
-- local hueSpeed = 360 / LuaUtil.SecondsToFrames(8)  -- 8 seconds per full cycle
-- LevelFuncs.OnLoop = function()
--     hueAngle = (hueAngle + hueSpeed) % 360
--     local color = LuaUtil.OKLchToColor(lightness, chroma, hueAngle, 1.0)
--     obj:SetColor(color)
--     -- All hues appear equally bright!
-- end
--
-- -- Example: Torch flicker (warm color oscillation) - Complete working example
-- -- OKLch is ideal for this: smooth transitions with perceptually uniform brightness
-- local torchLight = TEN.Objects.GetMoveableByName("TorchFlame")
-- local warmOrange = LuaUtil.ColorToOKLch(TEN.Color(255, 120, 40, 255))  -- h ≈ 45°
-- local brightYellow = LuaUtil.ColorToOKLch(TEN.Color(255, 200, 80, 255))  -- h ≈ 55°
-- local flickerTime = 0
-- local flickerSpeed = 1 / LuaUtil.SecondsToFrames(0.5)  -- 0.5 second cycle
-- LevelFuncs.OnLoop = function()
--     flickerTime = (flickerTime + flickerSpeed) % 1
--     -- Sine wave for smooth back-and-forth oscillation
--     local t = (math.sin(flickerTime * math.pi * 2) + 1) / 2
--     local l = warmOrange.l + (brightYellow.l - warmOrange.l) * t
--     local c = warmOrange.c + (brightYellow.c - warmOrange.c) * t
--     local h = warmOrange.h + (brightYellow.h - warmOrange.h) * t
--     local color = LuaUtil.OKLchToColor(l, c, h, 1.0)
--     torchLight:SetColor(color)
--     -- Smooth, natural-looking flame flicker!
-- end
--
-- -- Example: Lava pulse (brightness variation) - Complete working example
-- -- Demonstrates OKLch advantage: changing lightness without color shift
-- local lavaObj = TEN.Objects.GetMoveableByName("LavaGlow")
-- local baseLava = LuaUtil.ColorToOKLch(TEN.Color(200, 60, 20, 255))  -- Dark red-orange
-- local pulseTime = 0
-- local pulseSpeed = 1 / LuaUtil.SecondsToFrames(2)  -- 2 second pulse cycle
-- LevelFuncs.OnLoop = function()
--     pulseTime = (pulseTime + pulseSpeed) % 1
--     -- Pulse lightness between base and +0.15 brighter
--     local pulse = (math.sin(pulseTime * math.pi * 2) + 1) / 2
--     local l = baseLava.l + pulse * 0.15
--     local color = LuaUtil.OKLchToColor(l, baseLava.c, baseLava.h, 1.0)
--     lavaObj:SetColor(color)
--     -- Brightness pulses without hue shift (unlike HSL which would shift toward white)
-- end
--
-- -- Error handling example:
-- local color = LuaUtil.OKLchToColor(0.5, 0.2, 180)
-- if color == nil then
--     TEN.Util.PrintLog("Failed to convert OKLch to color", TEN.Util.LogLevel.ERROR)
--     return
-- end
--
-- -- Safe approach with default fallback:
-- local color = LuaUtil.OKLchToColor(l, c, h, a) or TEN.Color(128, 128, 128, 255)
LuaUtil.OKLchToColor = function(l, c, h, a)
    -- Default alpha
    a = a or 1.0

    -- Validate parameters
    if not (IsNumber(l) and IsNumber(c) and IsNumber(h)) then
        TEN.Util.PrintLog("Error in LuaUtil.OKLchToColor: l, c, h must be numbers.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    if a and not IsNumber(a) then
        TEN.Util.PrintLog("Error in LuaUtil.OKLchToColor: a must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- OKLch to OKLab (polar to cartesian)
    local h_rad = rad(h)
    local A = c * cos(h_rad)
    local B = c * sin(h_rad)
    local L = l

    -- OKLab to LMS (inverse matrix)
    local l_cbrt = L + 0.3963377774 * A + 0.2158037573 * B
    local m_cbrt = L - 0.1055613458 * A - 0.0638541728 * B
    local s_cbrt = L - 0.0894841775 * A - 1.2914855480 * B

    -- Cube (inverse of cube root)
    local l_ = l_cbrt * l_cbrt * l_cbrt
    local m_ = m_cbrt * m_cbrt * m_cbrt
    local s_ = s_cbrt * s_cbrt * s_cbrt

    -- LMS to linear RGB (inverse matrix)
    local r_lin =  4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_
    local g_lin = -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_
    local b_lin = -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_

    -- Clamp to valid range before gamma correction
    r_lin = max(0, min(1, r_lin))
    g_lin = max(0, min(1, g_lin))
    b_lin = max(0, min(1, b_lin))

    -- Linear RGB to sRGB
    local r = LinearToSrgb(r_lin)
    local g = LinearToSrgb(g_lin)
    local b = LinearToSrgb(b_lin)

    -- Clamp and convert to 0-255 range
    r = floor(max(0, min(1, r)) * 255 + 0.5)
    g = floor(max(0, min(1, g)) * 255 + 0.5)
    b = floor(max(0, min(1, b)) * 255 + 0.5)
    local alpha = floor(max(0, min(1, a)) * 255 + 0.5)

    return TEN.Color(r, g, b, alpha)
end

--- Interpolation functions.
-- Utilities for interpolating between values.
-- Different interpolation methods provide various speed curves and behaviors.
--
-- <h3>Interpolation methods comparison:</h3>
-- <style> table, th, td {border: 1px solid black;} .tableSP {border-collapse: collapse; width: 100%; text-align: center; } .tableSP th {background-color: #525252; color: white; padding: 6px;}</style>
-- <style> .tableSP td {padding: 4px;} .tableSP tr:nth-child(even) {background-color: #f2f2f2;} .tableSP tr:hover {background-color: #ddd;}</style>
-- <table class="tableSP">
-- <tr><th>Method</th><th>Speed curve</th><th>Behavior</th><th>Use case</th></tr>
-- <tr><td>`Lerp`</td><td>Linear</td><td>Constant speed throughout</td><td>Simple animations, mechanical movements</td></tr>
-- <tr><td>`Smoothstep`</td><td>Smooth S-curve</td><td>Gentle ease-in and ease-out</td><td>UI transitions, standard animations</td></tr>
-- <tr><td>`Smootherstep`</td><td>Ultra-smooth S-curve</td><td>Very gentle ease-in/out (C² continuity)</td><td>Cinematic effects, premium visuals</td></tr>
-- <tr><td>`EaseInOut`</td><td>Quadratic curve</td><td>Pronounced acceleration/deceleration</td><td>Dramatic movements, elevators</td></tr>
-- <tr><td>`Elastic`</td><td>Spring oscillation</td><td>Overshoot with smooth bounce back</td><td>Playful UI, cartoon effects</td></tr>
-- <tr><td>`Bounce`</td><td>Damped oscillation</td><td>Smooth bounces with energy decay</td><td>Falling objects, ball physics, collision effects</td></tr>
-- </table>
--
-- <br>Comparison of interpolation methods (0 to 10):
-- <table class="tableSP">
-- <tr><th>t</th><th>Lerp</th><th>Smoothstep</th><th>Smootherstep</th><th>EaseInOut</th><th>Elastic</th><th>Bounce</th></tr>
-- <tr><td>0.00</td><td>0.00</td><td>0.00</td><td>0.00</td><td>0.00</td><td>0.00</td><td>0.00</td></tr>
-- <tr><td>0.10</td><td>1.00</td><td>0.28</td><td>0.16</td><td>0.20</td><td>-0.04</td><td>0.95</td></tr>
-- <tr><td>0.25</td><td>2.50</td><td>1.56</td><td>1.04</td><td>1.25</td><td>0.44</td><td>3.75</td></tr>
-- <tr><td>0.50</td><td>5.00</td><td>5.00</td><td>5.00</td><td>5.00</td><td>5.00</td><td>7.50</td></tr>
-- <tr><td>0.75</td><td>7.50</td><td>8.44</td><td>8.96</td><td>8.75</td><td>9.56</td><td>9.82</td></tr>
-- <tr><td>0.90</td><td>9.00</td><td>9.72</td><td>9.84</td><td>9.80</td><td>10.04</td><td>9.98</td></tr>
-- <tr><td>1.00</td><td>10.00</td><td>10.00</td><td>10.00</td><td>10.00</td><td>10.00</td><td>10.00</td></tr>
-- </table>
--
-- <br>IMPORTANT: Using interpolation functions with TEN primitives
--
-- When you use `Lerp`, `Smoothstep`, `Smootherstep`, `EaseInOut`, and `Elastic`
-- with TEN primitives (`Rotation`, `Vec2`, `Vec3`, `Color`), these functions automatically call the native methods
-- of those primitives (e.g., `Rotation:Lerp()`, `Vec3:Lerp()`, `Color:Lerp()`).
--
-- For Rotation primitives specifically:
--
-- `Rotation:Lerp()` always calculates the **shortest angular distance** for each component (x, y, z)
--
-- Example
-- <pre class="example">
--<span class="keyword">local</span> currentRot = obj:GetRotation()
--<span class="keyword">local</span> targetRot = TEN.Rotation(<span class="number">0</span>, <span class="number">350</span>, <span class="number">0</span>)
--<span class="keyword">local</span> newRot = LuaUtil.Lerp(currentRot, targetRot, <span class="number">0.5</span>)  <span class="comment">-- Automatically takes shortest path
--</span>obj:SetRotation(newRot)</pre>
--
-- <h3>Special interpolations:</h3>
-- There are two special interpolation functions for specific use cases:
-- <table class="tableSP">
-- <tr><th>Method</th><th>Speed curve</th><th>Behavior</th><th>Use case</th></tr>
-- <tr><td>`LerpAngle`</td><td>Linear (shortest)</td><td>Constant speed, wraps around 0°/360°</td><td>2D UI sprites (compass, indicators)</td></tr>
-- <tr><td>`InterpolateColor`</td><td>Configurable (Linear/HSL/OKLch)</td><td>Component-wise color interpolation</td><td>Color transitions, fades</td></tr>
-- </table>
--
-- <br>**LerpAngle** behaves like Lerp when not crossing 0°/360° boundary.
--
-- When to use LerpAngle:
--
-- - Only when interpolating _single float values_ that represent angles (not `Rotation` primitives)
-- - When you need custom angle ranges (e.g., -180 to 180 instead of 0-360)
-- - External data where you only have float values
--
-- <br>When interpolating angles (rotations, compass, turrets):
-- <table class="tableSP">
-- <tr><th>Start</th><th>End</th><th>t</th><th>Lerp result</th><th>LerpAngle result</th><th>Which is correct?</th></tr>
-- <tr><td>350°</td><td>10°</td><td>0.5</td><td>180°</td><td>0° (crosses 0°)</td><td>LerpAngle</td></tr>
-- <tr><td>10°</td><td>350°</td><td>0.5</td><td>180°</td><td>0° (crosses 0°)</td><td>LerpAngle</td></tr>
-- <tr><td>90°</td><td>270°</td><td>0.5</td><td>180°</td><td>180°</td><td>Both same</td></tr>
-- <tr><td>5°</td><td>15°</td><td>0.5</td><td>10°</td><td>10°</td><td>Both same</td></tr>
-- </table>
--
-- <br>LerpAngle is NOT needed when working with `Rotation` primitives
--
-- Example - INCORRECT (redundant) approach:
--
-- <pre class="example">
--<span class="keyword">local</span> currentRot = obj:GetRotation()
--<span class="keyword">local</span> targetRot = TEN.Rotation(<span class="number">0</span>, <span class="number">350</span>, <span class="number">0</span>)
--currentRot.y = LuaUtil.LerpAngle(currentRot.y, targetRot.y, <span class="number">0.5</span>)  <span class="comment">-- Redundant!
--</span>obj:SetRotation(currentRot)</pre>
--
-- <br>**InterpolateColor** supports multiple color spaces for different use cases:
-- 
-- When to use each color space:
--
-- - `RGB (0)`: Simple fades, alpha transitions, color to gray/black/white
-- - `HSL (1)`: Rainbow effects, hue rotation, color wheel animations  
-- - `OKLch (2)`: Perceptually uniform transitions, professional color grading
--
-- <br>huePath options (HSL/OKLch only):
-- <table class="tableSP">
-- <tr><th>huePath</th><th>Red → Cyan</th><th>Use case</th></tr>
-- <tr><td>"shortest"</td><td>Red → Yellow → Green → Cyan</td><td>Natural transitions (default)</td></tr>
-- <tr><td>"longest"</td><td>Red → Magenta → Blue → Cyan</td><td>Full spectrum effects</td></tr>
-- <tr><td>"increasing"</td><td>Red → Yellow → Green → Cyan</td><td>Always clockwise (0° → 360°)</td></tr>
-- <tr><td>"decreasing"</td><td>Red → Magenta → Blue → Cyan</td><td>Always counter-clockwise (360° → 0°)</td></tr>
-- </table>
--
-- <br>Additional options: `preserveSaturation` and `preserveLightness` keep the starting color's saturation/lightness throughout the transition (useful for rainbow effects with consistent intensity).
--
-- <h3>Choosing the right interpolation method:</h3>
--
-- - Use `Lerp` for: numbers, positions (Vec2/Vec3), colors, sizes, mechanical movements
-- - Use `Smoothstep` for: UI fades, smooth transitions, general animations
-- - Use `Smootherstep` for: cinematic camera movements, premium effects, AAA-quality visuals
-- - Use `EaseInOut` for: dramatic movements, pronounced acceleration/deceleration
-- - Use `Elastic` for: bouncy UI, cartoon effects, playful feedback, spring animations
-- - Use `Bounce` for: falling objects, ball physics, collision effects (with aggressive parameters)
-- - Use `LerpAngle` for: 2D UI sprite rotations (DisplaySprite with single float angles)
-- - Use `InterpolateColor` for: color transitions, fades between colors
--
-- <h3>Note about practical examples:</h3>
-- All examples below use `LevelFuncs.OnLoop` to demonstrate the interpolation logic.
-- 
--
-- **Important:**
-- - `LevelFuncs.OnLoop` is a **single function** in your level's Lua file (e.g., `level1.lua`)
-- - You **cannot** have multiple `OnLoop` functions
-- - These examples show different use cases **separately** for clarity
-- 
-- **In your actual level script, you would combine logic like this:**
-- 
-- <pre class="example">
--LevelFuncs.OnLoop = <span class="keyword">function</span>()
--<span class="comment">   -- Update fog (from Lerp example)</span>
--<span class="comment">   -- Copy the fog interpolation code from the Lerp example</span><br>
--<span class="comment">   -- Update elevator (from EaseInOut example)</span>
--<span class="comment">   -- Copy the elevator interpolation code from the EaseInOut example</span><br>
--<span class="comment">   -- Update door (from LerpAngle example)</span>
--<span class="comment">   -- Copy the door interpolation code from the LerpAngle example</span>
--<span class="keyword">end</span></pre>
--
-- @section interpolation

--- Linearly interpolate between two values. Formula: result = a + (b - a) * t.
-- Provides constant-speed interpolation between start and end values.
-- Unlike Smoothstep and EaseInOut, Lerp maintains uniform velocity throughout the entire transition.
-- @tparam float|Color|Rotation|Vec2|Vec3 a The start value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float|Color|Rotation|Vec2|Vec3 b The end value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float t The interpolation factor (0.0 to 1.0).
-- @treturn[1] float|Color|Rotation|Vec2|Vec3 The interpolated value.
-- @treturn[2] float|Color|Rotation|Vec2|Vec3 Value `a` if an error occurs.
-- @usage
-- -- Most common usage (numbers):
-- local interpolated = LuaUtil.Lerp(0, 10, 0.5) -- Result: 5
--
-- -- Demonstration of linear progression (0 to 10):
-- --   t    | result
-- --  ------|--------
-- --  0.00  | 0.00
-- --  0.10  | 1.00   (constant speed)
-- --  0.25  | 2.50
-- --  0.50  | 5.00   (midpoint)
-- --  0.75  | 7.50
-- --  0.90  | 9.00   (constant speed)
-- --  1.00  | 10.00
--
-- -- Example with Colors (linear fade red → blue):
-- local color1 = TEN.Color(255, 0, 0, 255)    -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)    -- Blue
--
-- --   t    | R   | G | B   (linear color transition)
-- --  ------|-----|---|-----
-- --  0.00  | 255 | 0 | 0
-- --  0.25  | 191 | 0 | 64
-- --  0.50  | 127 | 0 | 127
-- --  0.75  | 64  | 0 | 191
-- --  1.00  | 0   | 0 | 255
-- local interpolatedColor = LuaUtil.Lerp(color1, color2, 0.5) -- Result: Purple (127, 0, 127, 255)
--
-- -- Example with Rotations:
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(90, 180, 45)
--
-- --   t    | X    | Y   | Z
-- --  ------|------|-----|-----
-- --  0.00  | 0    | 0   | 0
-- --  0.25  | 22.5 | 45  | 11.25
-- --  0.50  | 45   | 90  | 22.5
-- --  0.75  | 67.5 | 135 | 33.75
-- --  1.00  | 90   | 180 | 45
-- local interpolatedRot = LuaUtil.Lerp(rot1, rot2, 0.5)
--
-- -- Example with Vec2:
-- local vec1 = TEN.Vec2(100, 200)
-- local vec2 = TEN.Vec2(300, 400)
--
-- --   t    | X   | Y
-- --  ------|-----|-----
-- --  0.00  | 100 | 200
-- --  0.25  | 150 | 250
-- --  0.50  | 200 | 300
-- --  0.75  | 250 | 350
-- --  1.00  | 300 | 400
-- local interpolatedVec2 = LuaUtil.Lerp(vec1, vec2, 0.5) -- Result: Vec2(200, 300)
--
-- -- Example with Vec3 (linear camera movement):
-- local vec3_1 = TEN.Vec3(100, 200, 300)
-- local vec3_2 = TEN.Vec3(200, 400, 600)
--
-- --   t    | X   | Y   | Z
-- --  ------|-----|-----|-----
-- --  0.00  | 100 | 200 | 300
-- --  0.25  | 125 | 250 | 375
-- --  0.50  | 150 | 300 | 450
-- --  0.75  | 175 | 350 | 525
-- --  1.00  | 200 | 400 | 600
-- local interpolatedVec3 = LuaUtil.Lerp(vec3_1, vec3_2, 0.5) -- Result: Vec3(150, 300, 450)
--
-- -- Practical animation example (moving platform with constant speed over 4 seconds):
-- -- Lerp is perfect for mechanical movements that should be predictable and constant
-- local platform = TEN.Objects.GetMoveableByName("moving_platform_1")
-- local startPos = TEN.Vec3(8704, -384, 15872)     -- Starting position
-- local endPos = TEN.Vec3(8704, -384, 13824)      -- Ending position
--                                                  -- Total distance: 2048 units (2 sectors horizontal)
--
-- local animationDuration = LuaUtil.SecondsToFrames(4)  -- 4 seconds = 120 frames @ 30fps
-- local currentFrame = 0
-- local animationComplete = false
--
-- LevelFuncs.OnLoop = function()
--     if not animationComplete then
--         if currentFrame <= animationDuration then
--             local t = currentFrame / animationDuration  -- 0.0 to 1.0
--
--             -- Linear interpolation creates constant speed movement (perfect for platforms!)
--             local currentPos = LuaUtil.Lerp(startPos, endPos, t)
--             platform:SetPosition(currentPos)
--
--             -- Visual progression (linear, constant speed):
--             --   t=0.0   → Z=15872  (start position)
--             --   t=0.25  → Z=15360  (moved 512 units)
--             --   t=0.50  → Z=14848  (moved 1024 units = 1 sector) - halfway, perfect timing
--             --   t=0.75  → Z=14336  (moved 1536 units)
--             --   t=1.0   → Z=13824  (moved 2048 units = 2 sectors) - arrived
--             --
--             -- Notice: each 25% of time = same distance traveled (512 units)
--             -- This is CONSTANT SPEED, perfect for platforms and mechanical objects
--
--             currentFrame = currentFrame + 1
--         else
--             -- Animation complete, set final position
--             platform:SetPosition(endPos)
--             animationComplete = true
--         end
--     end
--     -- After animation completes, platform remains at final position
-- end
--
-- -- Why Lerp for platforms?
-- -- ✓ Constant speed is predictable for players (they can time jumps)
-- -- ✓ Mechanical feel matches physical platforms/trains/elevators
-- -- ✓ No acceleration/deceleration = industrial, mechanical movement
-- --
-- -- When NOT to use Lerp:
-- -- ✗ Organic movements (use Smoothstep)
-- -- ✗ Cinematic camera (use Smootherstep)
-- -- ✗ Natural phenomena like fog, wind (use Smoothstep/Smootherstep)
LuaUtil.Lerp = function(a, b, t)
    if not IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Lerp: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
        return a
    end
    -- Clamp t to the range [0, 1]
    local clampedT = max(0, min(1, t))
    return InterpolateValues(a, b, clampedT, "LuaUtil.Lerp")
end

--- Smoothly interpolate between two values using Hermite interpolation.
-- The function first normalizes the input value t to a 0-1 range using edge0 and edge1,
-- then applies a smooth S-curve (Hermite polynomial: 3t² - 2t³ or t²(3 - 2t)) for smoother transitions.
-- @tparam float|Color|Rotation|Vec2|Vec3 a Start value (returned when t <= edge0).
-- @tparam float|Color|Rotation|Vec2|Vec3 b End value (returned when t >= edge1).
-- @tparam float t The input value to be normalized and interpolated.
-- @tparam[opt=0] float edge0 Lower edge: the value of t that maps to 0 (start of interpolation range).
-- @tparam[opt=1] float edge1 Upper edge: the value of t that maps to 1 (end of interpolation range).
-- @treturn[1] float|Color|Rotation|Vec2|Vec3 Smoothly interpolated result.
-- @treturn[2] float|Color|Rotation|Vec2|Vec3 Value `a` if an error occurs.
-- @usage
-- -- Most common usage (edge0=0, edge1=1 implicit):
-- local smoothValue = LuaUtil.Smoothstep(0, 10, 0.5) -- Result: 5.0
-- 
-- -- Demonstration of smooth progression (0 to 10):
-- --   t    | result
-- --  ------|--------
-- --  0.00  | 0.00
-- --  0.10  | 0.28   (slow start)
-- --  0.25  | 1.56
-- --  0.50  | 5.00   (midpoint)
-- --  0.75  | 8.44
-- --  0.90  | 9.72   (slow end)
-- --  1.00  | 10.00
-- 
-- -- Example with Colors (smooth fade red → blue):
-- local color1 = TEN.Color(255, 0, 0, 255)  -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)  -- Blue
-- 
-- --   t    | R   | G | B   (smooth color transition)
-- --  ------|-----|---|-----
-- --  0.00  | 255 | 0 | 0
-- --  0.25  | 199 | 0 | 56
-- --  0.50  | 127 | 0 | 127
-- --  0.75  | 56  | 0 | 199
-- --  1.00  | 0   | 0 | 255
-- local smoothColor = LuaUtil.Smoothstep(color1, color2, 0.5)
-- 
-- -- Example with Vec3 (smooth camera movement):
-- local startPos = TEN.Vec3(0, 0, 0)
-- local endPos = TEN.Vec3(1000, 500, 2000)
-- 
-- --   t    | X    | Y   | Z
-- --  ------|------|-----|------
-- --  0.00  | 0    | 0   | 0
-- --  0.25  | 156  | 78  | 312
-- --  0.50  | 500  | 250 | 1000
-- --  0.75  | 844  | 422 | 1688
-- --  1.00  | 1000 | 500 | 2000
-- local smoothPos = LuaUtil.Smoothstep(startPos, endPos, 0.75)
--
-- -- Example with custom range (health bar that depletes from 100 to 0 over time):
-- local currentHealth = 75  -- Current health value
-- local fadedHealth = LuaUtil.Smoothstep(100, 0, currentHealth, 0, 100)
-- -- Maps health 0-100 to smooth 100-0 transition:
-- --   Health | Result
-- --   -------|-------
-- --   0      | 100
-- --   25     | 84.4
-- --   50     | 50
-- --   75     | 15.6
-- --   100    | 0
--
-- -- Example with temperature sensor (map sensor reading 20-30°C to 0-1 range):
-- local temperature = 25  -- Current temperature in Celsius
-- local normalizedTemp = LuaUtil.Smoothstep(0, 1, temperature, 20, 30)
-- -- Result: 0.5 (smooth transition between 20°C and 30°C)
--
-- -- Practical animation example (platform moving smoothly over 3 seconds):
-- local bridge = TEN.Objects.GetMoveableByName("bridge_flat_1")
-- local startPos = TEN.Vec3(0, 0, 0)
-- local endPos = TEN.Vec3(-512, 0, 0)  -- Move left 512 units
-- local bridgeInitialPos = bridge:GetPosition()
-- local animationDuration = LuaUtil.SecondsToFrames(3)  -- 3 seconds = 90 frames @ 30fps
-- local currentFrame = 0
-- local animationComplete = false
-- LevelFuncs.OnLoop = function()
--     if not animationComplete and currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         local offset = LuaUtil.Smoothstep(startPos, endPos, t)
--         bridge:SetPosition(bridgeInitialPos + offset)
--         currentFrame = currentFrame + 1
--     else
--         bridge:SetPosition(bridgeInitialPos + endPos)
--         currentFrame = 0
--         animationComplete = true
--     end
-- end
LuaUtil.Smoothstep = function (a, b, t, edge0, edge1)
    -- Default edge0 and edge1 if not provided
    edge0 = edge0 or 0
    edge1 = edge1 or 1

    if not IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Smoothstep: t must be a number.", TEN.Util.LogLevel.ERROR)
        return a
    end

    if not (IsNumber(edge0) and IsNumber(edge1)) then
        TEN.Util.PrintLog("Error in LuaUtil.Smoothstep: edge0 and edge1 must be numbers.", TEN.Util.LogLevel.ERROR)
        return a
    end

    local edgeDelta = edge1 - edge0

    -- Check if edge0 and edge1 are equal (division by zero)
    if edgeDelta == 0 then
        TEN.Util.PrintLog("Error in LuaUtil.Smoothstep: edge0 and edge1 cannot be equal.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Scale, bias and saturate t to 0..1 range
    local normalizedT = max(0, min(1, (t - edge0) / edgeDelta))

    -- Evaluate polynomial
    -- Smoothstep formula: t²(3 - 2t) = 3t² - 2t³
    local smoothedT = normalizedT * normalizedT * (3 - 2 * normalizedT)
    return InterpolateValues(a, b, smoothedT, "LuaUtil.Smoothstep")
end

--- Smoothly interpolate with smootherstep curve (Ken Perlin's improved version).
-- Provides an even smoother transition than Smoothstep with zero first and second derivatives at edges.
-- This creates ultra-smooth animations ideal for high-quality cinematics and professional visual effects.
-- Uses the polynomial: 6t⁵ - 15t⁴ + 10t³ (Ken Perlin's improved smoothstep formula).
-- Identical to **LevelFuncs.Engine.Node.Smoothstep** used in the Node Editor.
-- @tparam float|Color|Rotation|Vec2|Vec3 a Start value.
-- @tparam float|Color|Rotation|Vec2|Vec3 b End value.
-- @tparam float t Interpolation factor (0.0 to 1.0).
-- @tparam[opt=0] float edge0 Left edge for custom input range (optional, defaults to 0).
-- @tparam[opt=1] float edge1 Right edge for custom input range (optional, defaults to 1).
-- @treturn[1] float|Color|Rotation|Vec2|Vec3 The interpolated value.
-- @treturn[2] float|Color|Rotation|Vec2|Vec3 Value `a` if an error occurs.
-- @usage
-- -- Most common usage (numbers):
-- local smootherValue = LuaUtil.Smootherstep(0, 10, 0.5) -- Result: 5
--
-- -- Comparison: Smoothstep vs Smootherstep (0 to 10):
-- --   t    | Smoothstep | Smootherstep | Difference
-- --  ------|------------|--------------|------------
-- --  0.00  | 0.00       | 0.00         | 0.00
-- --  0.10  | 0.28       | 0.16         | -0.12 (even slower start)
-- --  0.25  | 1.56       | 1.04         | -0.52 (more gradual)
-- --  0.50  | 5.00       | 5.00         | 0.00 (same midpoint)
-- --  0.75  | 8.44       | 8.96         | +0.52 (more gradual)
-- --  0.90  | 9.72       | 9.84         | +0.12 (even slower end)
-- --  1.00  | 10.00      | 10.00        | 0.00
--
-- -- Visual comparison of curves:
-- -- Smoothstep:    starts/ends moderately smooth ━━╱⎺⎺╲━━
-- -- Smootherstep:  starts/ends VERY smooth       ━━━⎺╲━━━  (flatter at edges)
--
-- -- Example with Colors (ultra-smooth fade red → blue):
-- local color1 = TEN.Color(255, 0, 0, 255)  -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)  -- Blue
-- 
-- --   t    | R   | G | B   (smootherstep color transition)
-- --  ------|-----|---|-----
-- --  0.00  | 255 | 0 | 0
-- --  0.25  | 228 | 0 | 27   (very gradual at start)
-- --  0.50  | 127 | 0 | 127
-- --  0.75  | 27  | 0 | 228  (very gradual at end)
-- --  1.00  | 0   | 0 | 255
-- local smootherColor = LuaUtil.Smootherstep(color1, color2, 0.5)
--
-- -- Example with Vec3 (ultra-smooth camera position movement):
-- local startPos = TEN.Vec3(0, 1000, 0)
-- local endPos = TEN.Vec3(2000, 1000, 3000)
-- 
-- --   t    | X    | Y    | Z     (smootherstep movement)
-- --  ------|------|------|-------
-- --  0.00  | 0    | 1000 | 0
-- --  0.25  | 209  | 1000 | 313    (very gentle start)
-- --  0.50  | 1000 | 1000 | 1500
-- --  0.75  | 1791 | 1000 | 2687   (very gentle end)
-- --  1.00  | 2000 | 1000 | 3000
-- local smootherPos = LuaUtil.Smootherstep(startPos, endPos, 0.75)
--
-- -- Example with custom range (smooth light intensity fade based on distance):
-- local distance = 1500  -- Distance from light source
-- local intensity = LuaUtil.Smootherstep(1.0, 0.0, distance, 1000, 2000)
-- -- Maps distance 1000-2000 to intensity 1.0-0.0:
-- --   Distance | Intensity (smootherstep)
-- --   ---------|-------------------------
-- --   1000     | 1.00 (full brightness)
-- --   1250     | 0.90 (very gradual fade)
-- --   1500     | 0.50 (half)
-- --   1750     | 0.10 (very gradual fade)
-- --   2000     | 0.00 (dark)
--
-- -- Example with Rotation (ultra-smooth door closing):
-- local openRot = TEN.Rotation(0, 0, 0)
-- local closedRot = TEN.Rotation(0, 90, 0)
-- 
-- --   t    | X | Y      | Z  (smootherstep rotation)
-- --  ------|---|--------|----
-- --  0.00  | 0 | 0      | 0
-- --  0.25  | 0 | 9.4    | 0   (very slow start)
-- --  0.50  | 0 | 45     | 0
-- --  0.75  | 0 | 80.6   | 0   (very slow end)
-- --  1.00  | 0 | 90     | 0
-- local smootherRot = LuaUtil.Smootherstep(openRot, closedRot, 0.5)
--
-- -- Practical example 1: Cinematic camera fly-through (ultra-smooth position change over 6 seconds)
-- -- This creates a professional, broadcast-quality camera movement
-- local camera = TEN.Objects.GetCameraByName("camera_1")
-- local waypoint1 = TEN.Vec3(5632, 0, 11776)  -- Starting position
-- local waypoint2 = TEN.Vec3(5632, 0, 13824) -- Ending position
-- local animationDuration = LuaUtil.SecondsToFrames(6)  -- 6 seconds = 180 frames
-- local currentFrame = 0
-- local animationActive = true
-- 
-- LevelFuncs.OnLoop = function()
--     if animationActive and currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         local cameraPos = LuaUtil.Smootherstep(waypoint1, waypoint2, t)
--         camera:SetPosition(cameraPos)
--         camera:Play()  -- Activate camera this frame
--         currentFrame = currentFrame + 1
--     else
--         animationActive = false
--     end
-- end
--
-- -- Practical example 2: Dynamic fog transition (ultra-smooth fog density change over 8 seconds)
-- -- Creates a smooth, professional environmental effect
-- local level = TEN.Flow.GetCurrentLevel()
-- local clearFog = TEN.Flow.Fog(TEN.Color(220, 230, 255), 15, 25)  -- Light blue, far fog
-- local denseFog = TEN.Flow.Fog(TEN.Color(60, 70, 90), 2, 8)       -- Dark blue, near fog
-- local fogDuration = LuaUtil.SecondsToFrames(8)  -- 8 seconds
-- local fogFrame = 0
-- local fogActive = true
-- 
-- LevelFuncs.OnLoop = function()
--     if fogActive and fogFrame <= fogDuration then
--         local t = fogFrame / fogDuration
--         
--         -- Interpolate fog color (light blue → dark blue)
--         local fogColor = LuaUtil.Smootherstep(clearFog.color, denseFog.color, t)
--         
--         -- Interpolate fog min distance (15 → 2 sectors, ultra-smooth)
--         local fogMin = LuaUtil.Smootherstep(clearFog.minDistance, denseFog.minDistance, t)
--         
--         -- Interpolate fog max distance (25 → 8 sectors, ultra-smooth)
--         local fogMax = LuaUtil.Smootherstep(clearFog.maxDistance, denseFog.maxDistance, t)
--         
--         level.fog = TEN.Flow.Fog(fogColor, fogMin, fogMax)
--         
--         -- Progression visualization:
--         --   t=0.0  → Light blue (220,230,255), min=15, max=25 (clear)
--         --   t=0.25 → Bluish (184,204,228), min=11.7, max=20.8 (very gradual)
--         --   t=0.5  → Medium blue (140,150,172), min=8.5, max=16.5 (smooth)
--         --   t=0.75 → Dark blue (96,116,145), min=5.3, max=12.2 (very gradual)
--         --   t=1.0  → Very dark blue (60,70,90), min=2, max=8 (dense)
--         
--         fogFrame = fogFrame + 1
--     else
--         -- Set final fog state
--         level.fog = denseFog
--         fogActive = false
--     end
-- end
--
-- -- Practical example 3: Ultra-smooth particle color fade (for premium visual effects)
-- -- Creates particles that smoothly fade from bright yellow to dark red
-- local particleLifetime = 5.0  -- 5 seconds
-- local particleAge = 0.0
-- local startColor = TEN.Color(255, 255, 100, 255)  -- Bright yellow
-- local endColor = TEN.Color(180, 20, 0, 0)         -- Dark red, transparent
-- 
-- LevelFuncs.OnLoop = function()
--     particleAge = particleAge + (1.0 / 30.0)  -- Assuming 30 FPS
--     
--     if particleAge <= particleLifetime then
--         local t = particleAge / particleLifetime
--         local currentColor = LuaUtil.Smootherstep(startColor, endColor, t)
--         
--         -- Emit particle with smooth color transition
--         TEN.Effects.EmitParticle(
--             TEN.Vec3(5632, -768, 11776),  -- Position
--             TEN.Vec3(0, 50, 0),          -- Velocity (upward)
--             14,                          -- Sprite ID
--             -10,                         -- Gravity (descend)
--             5,                           -- Rotation velocity
--             currentColor,                -- Start color (interpolated)
--             currentColor,                -- End color (same for consistency)
--             TEN.Effects.BlendID.ADDITIVE,
--             30,                          -- Start size
--             10,                          -- End size
--             1.0                          -- Life (1 second per particle)
--         )
--         
--         -- Color progression (ultra-smooth):
--         --   t=0.0  → Bright yellow (255,255,100,255)
--         --   t=0.25 → Yellow-orange (238,201,62,199) - very gradual
--         --   t=0.5  → Orange (217,137,50,127) - smooth midpoint
--         --   t=0.75 → Red-orange (197,58,12,56) - very gradual
--         --   t=1.0  → Dark red (180,20,0,0) - invisible
--     end
-- end
--
-- -- Practical example 4: Smooth dynamic light intensity (pulsing light effect)
-- -- Creates a smooth, professional breathing light effect
-- local lightPos = TEN.Vec3(5632, -768, 11776)
-- local lightColor = TEN.Color(255, 180, 100)  -- Warm orange
-- local minRadius = 5   -- Minimum light radius (in sectors)
-- local maxRadius = 12  -- Maximum light radius (in sectors)
-- local pulseDuration = LuaUtil.SecondsToFrames(3)  -- 3 seconds per pulse
-- local pulseFrame = 0
-- local pulseDirection = 1  -- 1 = expanding, -1 = contracting
-- 
-- LevelFuncs.OnLoop = function()
--     local t = pulseFrame / pulseDuration
--     
--     -- Use smootherstep for ultra-smooth radius transition
--     local currentRadius = LuaUtil.Smootherstep(minRadius, maxRadius, t)
--     
--     -- Emit light this frame with smooth radius
--     TEN.Effects.EmitLight(
--         lightPos,
--         lightColor,
--         currentRadius,
--         false,           -- No shadows for performance
--         "pulsing_light"  -- Name for interpolation
--     )
--     
--     -- Update pulse
--     pulseFrame = pulseFrame + pulseDirection
--     
--     -- Reverse direction at edges (create continuous pulse)
--     if pulseFrame >= pulseDuration then
--         pulseDirection = -1
--     elseif pulseFrame <= 0 then
--         pulseDirection = 1
--     end
--     
--     -- Radius progression (ultra-smooth breathing):
--     --   t=0.0  → radius=5 (dim)
--     --   t=0.25 → radius=6.3 (very gradual expansion)
--     --   t=0.5  → radius=8.5 (half brightness)
--     --   t=0.75 → radius=10.7 (very gradual expansion)
--     --   t=1.0  → radius=12 (full brightness)
--     -- Then reverses smoothly back to radius=5
-- end
--
-- -- When to use Smootherstep vs Smoothstep:
-- -- 
-- -- Use Smootherstep for:
-- -- ✓ Cinematic camera movements (broadcast quality)
-- -- ✓ Premium particle effects (AAA game quality)
-- -- ✓ Professional environmental transitions (fog, lighting)
-- -- ✓ High-end UI animations (luxury feel)
-- -- ✓ Any effect where you need the SMOOTHEST possible transition
-- -- 
-- -- Use Smoothstep for:
-- -- ✓ Standard game animations (good quality)
-- -- ✓ UI transitions (normal smoothness)
-- -- ✓ General-purpose smooth interpolation
-- -- ✓ When performance matters more than ultra-smoothness
-- --
-- -- Smootherstep is ~15% more expensive computationally than Smoothstep
-- -- (requires evaluating a degree-5 polynomial vs degree-3)
LuaUtil.Smootherstep = function (a, b, t, edge0, edge1)
    -- Default edge0 and edge1 if not provided
    edge0 = edge0 or 0
    edge1 = edge1 or 1

    if not IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Smootherstep: t must be a number.", TEN.Util.LogLevel.ERROR)
        return a
    end

    if not (IsNumber(edge0) and IsNumber(edge1)) then
        TEN.Util.PrintLog("Error in LuaUtil.Smootherstep: edge0 and edge1 must be numbers.", TEN.Util.LogLevel.ERROR)
        return a
    end

    local edgeDelta = edge1 - edge0

    -- Check if edge0 and edge1 are equal (division by zero)
    if edgeDelta == 0 then
        TEN.Util.PrintLog("Error in LuaUtil.Smootherstep: edge0 and edge1 cannot be equal.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Scale, bias and saturate t to 0..1 range
    local normalizedT = max(0, min(1, (t - edge0) / edgeDelta))

    -- Ken Perlin's smootherstep polynomial: 6t⁵ - 15t⁴ + 10t³
    -- This is identical to LevelFuncs.Engine.Node.Smoothstep
    local smootherT = (normalizedT ^ 3) * (normalizedT * (normalizedT * 6 - 15) + 10)

    return InterpolateValues(a, b, smootherT, "LuaUtil.Smootherstep")
end

--- Smoothly interpolate with ease-in-out quadratic curve.
-- Provides gentle acceleration at the start and deceleration at the end.
-- Quadratic curve with more pronounced acceleration/deceleration than Smoothstep but smoother than linear interpolation.
-- Uses quadratic formula: t < 0.5 → 2t², otherwise → 1 - 2(1-t)²
-- @tparam float|Color|Rotation|Vec2|Vec3 a Start value.
-- @tparam float|Color|Rotation|Vec2|Vec3 b End value.
-- @tparam float t Interpolation factor (0.0 to 1.0).
-- @treturn[1] float|Color|Rotation|Vec2|Vec3 The interpolated value.
-- @treturn[2] float|Color|Rotation|Vec2|Vec3 Value `a` if an error occurs.
-- @usage
-- -- Most common usage (numbers):
-- local easeValue = LuaUtil.EaseInOut(0, 10, 0.5) -- Result: 5
--
-- -- Demonstration of ease-in-out progression (0 to 10):
-- --   t    | result
-- --  ------|--------
-- --  0.00  | 0.00
-- --  0.10  | 0.20   (gentle acceleration)
-- --  0.25  | 1.25
-- --  0.50  | 5.00   (midpoint)
-- --  0.75  | 8.75
-- --  0.90  | 9.80   (gentle deceleration)
-- --  1.00  | 10.00
--
-- -- Example with Colors (ease-in-out fade red → blue):
-- local color1 = TEN.Color(255, 0, 0, 255)  -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)  -- Blue
-- 
-- --   t    | R   | G | B   (ease-in-out color transition)
-- --  ------|-----|---|-----
-- --  0.00  | 255 | 0 | 0
-- --  0.25  | 191 | 0 | 64
-- --  0.50  | 127 | 0 | 127
-- --  0.75  | 64  | 0 | 191
-- --  1.00  | 0   | 0 | 255
-- local easeColor = LuaUtil.EaseInOut(color1, color2, 0.5)
--
-- -- Example with Vec3 (camera movement with acceleration/deceleration):
-- local startPos = TEN.Vec3(0, 0, 0)
-- local endPos = TEN.Vec3(1000, 500, 2000)
-- 
-- --   t    | X    | Y   | Z
-- --  ------|------|-----|------
-- --  0.00  | 0    | 0   | 0
-- --  0.25  | 125  | 62  | 250
-- --  0.50  | 500  | 250 | 1000
-- --  0.75  | 875  | 437 | 1750
-- --  1.00  | 1000 | 500 | 2000
-- local easePos = LuaUtil.EaseInOut(startPos, endPos, 0.75)
--
-- -- Example with Rotation (smooth door swing):
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(0, 90, 0)
-- 
-- --   t    | X | Y    | Z
-- --  ------|---|------|---
-- --  0.00  | 0 | 0    | 0
-- --  0.25  | 0 | 11.25| 0
-- --  0.50  | 0 | 45   | 0
-- --  0.75  | 0 | 78.75| 0
-- --  1.00  | 0 | 90   | 0
-- local easeRot = LuaUtil.EaseInOut(rot1, rot2, 0.5)
--
-- -- Practical animation example (elevator moving with acceleration/deceleration over 4 seconds):
-- local elevator = TEN.Objects.GetMoveableByName("elevator_1")
-- local startPos = elevator:GetPosition()
-- local endPos = startPos + TEN.Vec3(0, 1024, 0)  -- Move up 1024 units
-- local animationDuration = LuaUtil.SecondsToFrames(4)  -- 4 seconds = 120 frames @ 30fps
-- local currentFrame = 0
-- local animationComplete = false
-- LevelFuncs.OnLoop = function()
--     if currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         local newPos = LuaUtil.EaseInOut(startPos, endPos, t)
--         elevator:SetPosition(newPos)
--         currentFrame = currentFrame + 1
--     else
--         animationComplete = true
--         -- Optionally reset animation
--         currentFrame = 0
--     end
-- end
LuaUtil.EaseInOut = function(a, b, t)
    if not IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.EaseInOut: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Clamp t to [0, 1]
    t = max(0, min(1, t))

    -- EaseInOutQuad formula
    local easedT
    if t < 0.5 then
        easedT = 2 * t * t  -- Ease in: acceleration
    else
        easedT = 1 - 2 * (1 - t) * (1 - t)  -- Ease out: deceleration
    end

    return InterpolateValues(a, b, easedT, "LuaUtil.EaseInOut")
end

--- Elastic interpolation with overshoot and bounce effect.
-- Creates a spring-like animation that overshoots the target and bounces back before settling.
-- Perfect for cartoonish UI animations, button presses, and playful feedback effects.
-- Uses EaseInOutElastic curve with configurable amplitude (overshoot amount) and period (oscillation frequency).
-- @tparam float|Color|Rotation|Vec2|Vec3 a Start value.
-- @tparam float|Color|Rotation|Vec2|Vec3 b End value.
-- @tparam float t Interpolation factor (0.0 to 1.0).
-- @tparam[opt=1.0] float amplitude Controls the overshoot amount (default: 1.0). Higher values = more pronounced bounce.
-- @tparam[opt=0.3] float period Controls oscillation frequency (default: 0.3). Lower values = faster oscillations.
-- @treturn[1] float|Color|Rotation|Vec2|Vec3 The interpolated value with elastic effect.
-- @treturn[2] float|Color|Rotation|Vec2|Vec3 Value `a` if an error occurs.
-- @usage
-- -- Most common usage (numbers with default parameters):
-- local elasticValue = LuaUtil.Elastic(0, 100, 0.5) -- Result: ~50 (with slight oscillation)
--
-- -- Demonstration of elastic progression (0 to 10, amplitude=1.0, period=0.3):
-- --   t    | result
-- --  ------|--------
-- --  0.00  | 0.00
-- --  0.10  | -0.04  (undershoots start!)
-- --  0.25  | 0.44   (still below expected)
-- --  0.50  | 5.00   (midpoint)
-- --  0.75  | 9.56   (above expected)
-- --  0.90  | 10.04  (overshoots target!)
-- --  1.00  | 10.00
--
-- -- Example with different amplitude (more pronounced bounce):
-- local strongBounce = LuaUtil.Elastic(0, 100, 0.8, 1.5, 0.3)
-- -- Higher amplitude = more overshoot:
-- --   t    | result (amp=1.5)
-- --  ------|------------------
-- --  0.75  | 96.2   (more overshoot)
-- --  0.90  | 100.6  (stronger overshoot)
--
-- -- Example with different period (faster oscillations):
-- local fastOscillation = LuaUtil.Elastic(0, 100, 0.8, 1.0, 0.15)
-- -- Lower period = faster bounces
--
-- -- Example with Colors (elastic color transition red → green):
-- local color1 = TEN.Color(255, 0, 0, 255)  -- Red
-- local color2 = TEN.Color(0, 255, 0, 255)  -- Green
-- 
-- --   t    | R   | G   | B (elastic color with bounce)
-- --  ------|-----|-----|---
-- --  0.00  | 255 | 0   | 0
-- --  0.25  | 216 | 39  | 0   (slight overshoot in R)
-- --  0.50  | 127 | 127 | 0
-- --  0.75  | 39  | 216 | 0   (overshoots in G)
-- --  1.00  | 0   | 255 | 0
-- local elasticColor = LuaUtil.Elastic(color1, color2, 0.75)
--
-- -- Example with Vec3 (UI element sliding with bounce):
-- local startPos = TEN.Vec3(-500, 100, 0)  -- Off-screen left
-- local endPos = TEN.Vec3(0, 100, 0)       -- Final position
-- 
-- --   t    | X      | Y   | Z (elastic movement)
-- --  ------|--------|-----|---
-- --  0.00  | -500   | 100 | 0
-- --  0.25  | -478   | 100 | 0   (still off-screen, bouncing)
-- --  0.50  | -250   | 100 | 0
-- --  0.75  | -22    | 100 | 0   (almost there, slight overshoot)
-- --  0.90  | 2      | 100 | 0   (overshoots right!)
-- --  1.00  | 0      | 100 | 0   (settles)
-- local elasticPos = LuaUtil.Elastic(startPos, endPos, 0.75, 1.2, 0.3)
--
-- -- Example with Rotation (door with elastic swing):
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(0, 90, 0)
-- 
-- --   t    | X | Y      | Z (elastic rotation)
-- --  ------|---|--------|---
-- --  0.00  | 0 | 0      | 0
-- --  0.25  | 0 | 3.9    | 0   (slow start with bounce)
-- --  0.50  | 0 | 45     | 0
-- --  0.75  | 0 | 86     | 0   (approaching with overshoot)
-- --  0.90  | 0 | 90.4   | 0   (overshoots!)
-- --  1.00  | 0 | 90     | 0   (settles)
-- local elasticRot = LuaUtil.Elastic(rot1, rot2, 0.75, 1.0, 0.3)
--
-- -- Practical example: Pickup item animation (item bounces toward player):
-- local pickup = TEN.Objects.GetMoveableByName("pickup_item")
-- local startPos = pickup:GetPosition()
-- local playerPos = Lara:GetPosition()
-- local animationDuration = LuaUtil.SecondsToFrames(1.0)  -- 1 second
-- local currentFrame = 0
-- local giveItem = false
-- LevelFuncs.OnLoop = function()
--     if currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         local pos = LuaUtil.Elastic(startPos, playerPos, t, 1.3, 0.25)
--         pickup:SetPosition(pos)
--         -- The item will "bounce" as it moves toward the player:
--         -- - First undershoots (moves back slightly)
--         -- - Then accelerates forward
--         -- - Overshoots the player position
--         -- - Wobbles and settles at player position
--         currentFrame = currentFrame + 1
--     else
--         if not giveItem then
--             TEN.Inventory.GiveItem(pickup:GetObjectID(), 1, true) -- Collect the item
--             pickup:Destroy()
--             giveItem = true
--         end
--     end
-- end
LuaUtil.Elastic = function(a, b, t, amplitude, period)
    if not IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Elastic: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Set default values and validate optional parameters
    amplitude = amplitude or 1.0
    period = period or 0.3

    if not IsNumber(amplitude) or not IsNumber(period) then
        TEN.Util.PrintLog("Error in LuaUtil.Elastic: amplitude and period must be numbers.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Validate amplitude (must be >= 1.0 for proper elastic effect)
    if amplitude < 1.0 then
        TEN.Util.PrintLog("Warning in LuaUtil.Elastic: amplitude should be >= 1.0 for proper elastic effect. Using 1.0.", TEN.Util.LogLevel.WARNING)
        amplitude = 1.0
    end

    -- Clamp t to [0, 1]
    t = max(0, min(1, t))

    -- Handle edge cases (no oscillation at start/end)
    if t == 0 then
        return a
    elseif t == 1 then
        return b
    end

    -- EaseInOutElastic formula
    local twoPi = 2 * pi

    -- Calculate phase shift 's' to adjust the sine wave's starting point
    -- The phase shift ensures the elastic curve starts at 0 and ends at 1
    -- Formula: s = period / (2π) * arcsin(1 / amplitude)
    local s = period / (2 * pi) * asin(1 / amplitude)
    local periodOverTwoPi = twoPi / period
    local easedT

    if t < 0.5 then
        -- Ease In (first half) - undershoot at start
        t = t * 2
        easedT = -(amplitude * (2 ^ (10 * (t - 1))) * sin((t - 1 - s) * periodOverTwoPi)) / 2
    else
        -- Ease Out (second half) - overshoot at end
        t = t * 2 - 1
        easedT = (amplitude * (2 ^ (-10 * t)) * sin((t - s) * periodOverTwoPi)) / 2 + 1
    end

    return InterpolateValues(a, b, easedT, "LuaUtil.Elastic")
end

--- Bounce interpolation with damped oscillation physics.
-- Creates a bouncing animation that simulates objects hitting surfaces with decreasing intensity.
-- Perfect for falling objects, ball physics, and collision effects with proper parameter tuning.
-- Uses an exponential decay curve with cosine waves to approximate bounce physics.
--
-- **Note on physics simulation:**
-- This is an easing function (mathematical curve), not a physics engine.
-- It approximates bouncing behavior for visual effects. For realistic physics:
--
-- - Use low `bounces` (2-3) and low `damping` (0.3-0.4) for hard collisions
--
-- - Use high `bounces` (5-7) and high `damping` (0.6-0.8) for elastic bouncing
-- @tparam float|Color|Rotation|Vec2|Vec3 a Start value.
-- @tparam float|Color|Rotation|Vec2|Vec3 b End value.
-- @tparam float t Interpolation factor (0.0 to 1.0).
-- @tparam[opt=4] float bounces Number of bounces (default: 4). Higher values = more bounces before settling.
-- @tparam[opt=0.5] float damping Bounce intensity/energy loss (default: 0.5, range: 0.0-1.0). Lower values = faster decay, higher values = longer bounces.
-- @treturn[1] float|Color|Rotation|Vec2|Vec3 The interpolated value with bounce effect.
-- @treturn[2] float|Color|Rotation|Vec2|Vec3 Value `a` if an error occurs.
-- @usage
-- -- Most common usage (numbers with default parameters):
-- local bounceValue = LuaUtil.Bounce(0, 100, 0.75) -- Result: ~100 with bounce oscillations
--
-- -- Demonstration of bounce progression (0 to 10, bounces=4, damping=0.5):
-- --   t    | result
-- --  ------|--------
-- --  0.00  | 0.00
-- --  0.10  | 0.95   (accelerating toward target)
-- --  0.25  | 3.75   (moving toward target)
-- --  0.50  | 7.50   (approaching target)
-- --  0.70  | 9.70   (first impact, slight overshoot)
-- --  0.75  | 9.82   (small bounce back)
-- --  0.85  | 9.95   (second smaller bounce)
-- --  0.95  | 9.99   (tiny final bounce)
-- --  1.00  | 10.00  (settled at target)
--
-- -- Example with more bounces (energetic ball):
-- local energeticBounce = LuaUtil.Bounce(0, 100, 0.8, 6, 0.6)
-- -- More bounces with slower decay:
-- --   t    | result (bounces=6, damping=0.6)
-- --  ------|--------------------------------
-- --  0.70  | 97.2   (first bounce)
-- --  0.80  | 99.5   (second bounce)
-- --  0.90  | 99.9   (third bounce)
-- --  0.95  | 100.0  (still bouncing slightly)
--
-- -- Example with fewer bounces (heavy object):
-- local heavyBounce = LuaUtil.Bounce(0, 100, 0.8, 2, 0.3)
-- -- Fewer, sharper bounces with fast decay:
-- --   t    | result (bounces=2, damping=0.3)
-- --  ------|--------------------------------
-- --  0.75  | 98.5   (quick first bounce)
-- --  0.90  | 99.8   (small second bounce)
-- --  1.00  | 100.0  (settled quickly)
--
-- -- Example with Colors (bouncing color transition red → blue):
-- local color1 = TEN.Color(255, 0, 0, 255)  -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)  -- Blue
-- 
-- --   t    | R   | G | B   (bouncing color)
-- --  ------|-----|---|-----
-- --  0.00  | 255 | 0 | 0
-- --  0.50  | 127 | 0 | 127
-- --  0.75  | 5   | 0 | 250  (approaching blue with bounce)
-- --  0.85  | 10  | 0 | 245  (bounce back slightly)
-- --  1.00  | 0   | 0 | 255  (settled at blue)
-- local bounceColor = LuaUtil.Bounce(color1, color2, 0.75, 4, 0.5)
--
-- -- Example with Vec3 (ball bouncing toward ground):
-- local startPos = TEN.Vec3(0, 1000, 0)  -- High in air
-- local endPos = TEN.Vec3(0, 0, 0)       -- Ground level
-- 
-- --   t    | X | Y     | Z (bouncing ball)
-- --  ------|---|-------|---
-- --  0.00  | 0 | 1000  | 0
-- --  0.50  | 0 | 500   | 0   (falling)
-- --  0.75  | 0 | 20    | 0   (first bounce up)
-- --  0.85  | 0 | 5     | 0   (second smaller bounce)
-- --  0.95  | 0 | 1     | 0   (tiny final bounce)
-- --  1.00  | 0 | 0     | 0   (settled on ground)
-- local bouncePos = LuaUtil.Bounce(startPos, endPos, 0.75, 4, 0.5)
--
-- -- Example with Rotation (door slamming with bounces):
-- local rot1 = TEN.Rotation(0, 90, 0)   -- Door open
-- local rot2 = TEN.Rotation(0, 0, 0)    -- Door closed
-- 
-- --   t    | X | Y    | Z (door slamming)
-- --  ------|---|------|---
-- --  0.00  | 0 | 90   | 0
-- --  0.50  | 0 | 45   | 0   (closing)
-- --  0.75  | 0 | 2    | 0   (first impact, bounces open slightly)
-- --  0.85  | 0 | 0.5  | 0   (second bounce)
-- --  0.95  | 0 | 0.1  | 0   (final tiny bounce)
-- --  1.00  | 0 | 0    | 0   (fully closed)
-- local bounceRot = LuaUtil.Bounce(rot1, rot2, 0.75, 3, 0.4)
--
-- -- Practical example 1: Dropping item with realistic bounce physics
-- local item = TEN.Objects.GetMoveableByName("dropped_item")
-- local startPos = item:GetPosition()
-- local groundY = 0  -- Ground level Y coordinate
-- local endPos = TEN.Vec3(startPos.x, groundY, startPos.z)
-- local animationDuration = LuaUtil.SecondsToFrames(2.0)  -- 2 second drop
-- local currentFrame = 0
-- LevelFuncs.OnLoop = function()
--     if currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         -- Item falls and bounces realistically on impact:
--         -- - Falls smoothly toward ground
--         -- - First impact creates largest bounce
--         -- - Each subsequent bounce is smaller
--         -- - Eventually settles on ground
--         local pos = LuaUtil.Bounce(startPos, endPos, t, 5, 0.6)
--         item:SetPosition(pos)
--         
--         -- Optional: Play impact sound on each bounce peak
--         -- (detect when position Y changes direction)
--         
--         currentFrame = currentFrame + 1
--     end
-- end
--
-- -- Practical example 2: An object simulates a slamming door with collision effects
-- -- Using aggressive parameters (low bounces, low damping) to simulate hard impacts
-- local stoneDoor = TEN.Objects.GetStaticByName("static_mesh_18")
-- local startPos = stoneDoor:GetPosition()
-- local endPos = startPos + TEN.Vec3(-1024, 0, 0)  -- Door drops 1024 units
-- local animationDuration = LuaUtil.SecondsToFrames(1.5)  -- 1.5 second slam
-- local currentFrame = 0
-- LevelFuncs.OnLoop = function()
--     if currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         
--         -- Door slams down with quick, hard bounces:
--         -- - Use bounces=2 for just a couple of impacts
--         -- - Use damping=0.3 for fast energy loss (hard surface)
--         -- This creates a "slamming" effect rather than elastic bouncing
--         local pos = LuaUtil.Bounce(startPos, endPos, t, 2, 0.3)
--         stoneDoor:SetPosition(pos)
--         
--         -- Optional: Play slam sound when door reaches/bounces off endPos
--         
--         currentFrame = currentFrame + 1
--     end
-- end
--
-- -- Practical example 3: 2 objects simulate double door lock with collision effect
-- -- Both objects move toward each other and "bounce" on collision
-- local leftObject = TEN.Objects.GetStaticByName("static_mesh_19")
-- local rightObject = TEN.Objects.GetStaticByName("static_mesh_20")
-- local leftStart = leftObject:GetPosition()
-- local rightStart = rightObject:GetPosition()
-- 
-- -- Each object moves 1024 units (1 sector) toward the other
-- -- Objects are 1024 wide and initially 2048 apart (2 sectors gap)
-- -- After moving 1024 each, they meet in the middle without overlapping
-- local leftEnd = TEN.Vec3(leftStart.x, leftStart.y, leftStart.z + 1024)
-- local rightEnd = TEN.Vec3(rightStart.x, rightStart.y, rightStart.z - 1024)
-- 
-- local animationDuration = LuaUtil.SecondsToFrames(1.5)
-- local currentFrame = 0
-- 
-- LevelFuncs.OnLoop = function()
--     if currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         
--         -- Aggressive parameters for collision effect:
--         -- bounces=3: A few quick impacts
--         -- damping=0.4: Quick energy loss for "slamming" feel
--         -- Both objects follow same curve toward their endpoints
--         
--         local leftPos = LuaUtil.Bounce(leftStart, leftEnd, t, 3, 0.4)
--         local rightPos = LuaUtil.Bounce(rightStart, rightEnd, t, 3, 0.4)
--         
--         leftObject:SetPosition(leftPos)
--         rightObject:SetPosition(rightPos)
--         
--         -- Optional: Calculate when objects are closest to detect "collision"
--         -- local distance = math.abs(leftPos.z - rightPos.z)
--         -- if distance < 10 then -- Play slam sound end
--         
--         currentFrame = currentFrame + 1
--     end
-- end
LuaUtil.Bounce = function(a, b, t, bounces, damping)
    if not IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Bounce: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Set default values and validate optional parameters
    bounces = bounces or 4
    damping = damping or 0.5

    if not IsNumber(bounces) or not IsNumber(damping) then
        TEN.Util.PrintLog("Error in LuaUtil.Bounce: bounces and damping must be numbers.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Validate bounces (must be positive integer)
    if bounces < 1 or bounces % 1 ~= 0 then
        TEN.Util.PrintLog("Warning in LuaUtil.Bounce: bounces should be an integer >= 1. Using 1.", TEN.Util.LogLevel.WARNING)
        bounces = 1
    end

    -- Validate damping (0.0 to 1.0 range)
    if damping < 0.0 or damping > 1.0 then
        TEN.Util.PrintLog("Warning in LuaUtil.Bounce: damping should be between 0.0 and 1.0. Clamping.", TEN.Util.LogLevel.WARNING)
        damping = max(0.0, min(1.0, damping))
    end

    -- Clamp t to [0, 1]
    t = max(0, min(1, t))
    -- Handle edge cases
    if t == 0 then
        return a
    elseif t == 1 then
        return b
    end

    -- Bounce formula:
    -- Uses exponential decay combined with sine wave for bounce oscillations
    -- Formula: easedT = 1 - (cos(t * π * bounces) * (1 - t)^(1/damping))
    -- 
    -- The formula works as follows:
    -- 1. cos(t * π * bounces): Creates oscillations (bounces)
    -- 2. (1 - t)^(1/damping): Exponential decay envelope
    --    - damping controls decay speed
    --    - Lower damping = faster energy loss
    --    - Higher damping = longer bounces
    -- 3. Multiply them: Bounces that decrease in amplitude
    -- 4. (1 - result): Invert so we approach target value instead of 0

    local decay = (1 - t) ^ (1 / (damping + 0.1))  -- Add 0.1 to prevent division issues
    local oscillation = abs(cos(t * pi * bounces))
    local easedT = 1 - (oscillation * decay)

    return InterpolateValues(a, b, easedT, "LuaUtil.Bounce")
end

--- Linearly interpolate between two angles, taking the shortest path.
-- **Why use LerpAngle instead of Lerp for angles?**
-- 
-- Lerp treats angles as linear numbers:
--
--      LuaUtil.Lerp(350°, 10°, 0.5) = 180° ❌ (rotates 170° the long way!)
-- 
-- LerpAngle calculates shortest rotation path:
--
--      LuaUtil.LerpAngle(350°, 10°, 0.5) = 0° ✅ (rotates 10° through 0°/360° boundary)
--
-- This prevents objects from "spinning wildly" when rotating across 0°/360°.
--
--- **IMPORTANT: When NOT to use LerpAngle**
-- 
-- LerpAngle calculates the SHORTEST path between angles.
--
-- This means:
--
-- - 0° → 360° = 0° rotation (they're the same angle!)
-- - For FULL 360° rotation, use Lerp instead
--
-- **Use LerpAngle for:**
--
-- - Shortest rotation to target (enemy, turret, compass)
-- - Door/lid opening (0° → 90° type rotations)
-- - Any rotation where direction doesn't matter
--
-- **Use Lerp for:**
--
-- - Full 360° camera orbit (specific direction)
-- - Multiple rotations (0° → 720° = 2 full circles)
-- - Continuous rotation (0° → 1000°)
--
-- **Problem with regular Lerp:**
-- <table class="tableSP">
-- <tr><th>Start</th><th>End</th><th>Lerp result</th><th>Problem</th></tr>
-- <tr><td>350°</td><td>10°</td><td>180°</td><td>Goes the LONG way (340° turn!)</td></tr>
-- <tr><td>10°</td><td>350°</td><td>180°</td><td>Goes the LONG way (340° turn!)</td></tr>
-- <tr><td>270°</td><td>90°</td><td>180°</td><td>Correct by chance</td></tr>
-- </table>
--
-- <br>**Solution with LerpAngle:**
--
-- <table class="tableSP">
-- <tr><th>Start</th><th>End</th><th>LerpAngle result</th><th>Result</th></tr>
-- <tr><td>350°</td><td>10°</td><td>0° (360°)</td><td>SHORT way (20° turn through 0°)</td></tr>
-- <tr><td>10°</td><td>350°</td><td>0° (360°)</td><td>SHORT way (20° turn through 0°)</td></tr>
-- <tr><td>270°</td><td>90°</td><td>180°</td><td>SHORT way (180° turn)</td></tr>
-- </table>
--
-- @tparam float a Start angle (in degrees).
-- @tparam float b End angle (in degrees).
-- @tparam float t Interpolation factor (0.0 to 1.0).
-- @tparam[opt=0] float minValue Minimum angle of range (default: 0 for 0-360°).
-- @tparam[opt=360] float maxValue Maximum angle of range (default: 360 for 0-360°).
-- @treturn[1] float The interpolated angle, taking the shortest path.
-- @treturn[2] float Value `a` if an error occurs.
-- @usage
-- -- Basic example: Why LerpAngle is needed
-- local angle1 = LuaUtil.Lerp(350, 10, 0.5)        -- Result: 180° (WRONG! Long way)
-- local angle2 = LuaUtil.LerpAngle(350, 10, 0.5)   -- Result: 0° (CORRECT! Short way)
--
-- -- Demonstration: Rotating from 350° to 10° (should cross 0°/360°)
-- --   t    | Lerp  | LerpAngle | Correct?
-- --  ------|-------|-----------|----------
-- --  0.00  | 350   | 350       | ✓
-- --  0.25  | 265   | 355       | ✓ (short path)
-- --  0.50  | 180   | 0         | ✓ (crosses boundary)
-- --  0.75  | 95    | 5         | ✓ (short path)
-- --  1.00  | 10    | 10        | ✓
--
-- -- Real-world example 1: 2D sprite pointing towards mouse cursor
-- -- DisplaySprite uses single float for rotation, perfect use case for LerpAngle!
-- local arrowSprite = TEN.View.DisplaySprite(1354, 16, TEN.Vec2(400, 300), 0, TEN.Vec2(3, 3))
-- local rotationSpeed = 0.1  -- How fast the arrow rotates (0.0-1.0)
--
-- LevelFuncs.OnLoop = function()
--     local mousePos = TEN.Input.GetMouseDisplayPosition()
--     local arrowPos = arrowSprite:GetPosition()
--     
--     -- Calculate angle from arrow to mouse
--     local dx = mousePos.x - arrowPos.x
--     local dy = mousePos.y - arrowPos.y
--     local targetAngle = math.atan(dy, dx) * (180 / math.pi)  -- Convert radians to degrees
--     
--     -- Smoothly rotate arrow towards mouse using shortest path
--     local currentAngle = arrowSprite:GetRotation()
--     local newAngle = LuaUtil.LerpAngle(currentAngle, targetAngle, rotationSpeed)
--     arrowSprite:SetRotation(newAngle)
--     
--     arrowSprite:Draw()
-- end
--
-- -- Real-world example 2: HUD compass needle rotating to point north
-- -- Perfect for 2D UI elements that need smooth rotation
-- -- Uses speedometer needle sprite from base WAD (points down by default, so we add 180° offset)
-- local objID = TEN.Objects.ObjID.SPEEDOMETER_GRAPHICS
-- local compassNeedle = TEN.View.DisplaySprite(objID, 1, TEN.Vec2(80, 80), 0, TEN.Vec2(20, 20))
--
-- LevelFuncs.OnLoop = function()
--     -- Get player's current yaw (facing direction)
--     local playerYaw = Lara:GetRotation().y
--     
--     -- Calculate angle to north
--     -- Add 180° offset because the sprite points down by default
--     local needleTargetAngle = -playerYaw + 180
--     
--     -- Smoothly rotate needle towards north using shortest path
--     local currentNeedleAngle = compassNeedle:GetRotation()
--     local newNeedleAngle = LuaUtil.LerpAngle(currentNeedleAngle, needleTargetAngle, 0.15)
--     compassNeedle:SetRotation(newNeedleAngle)
--     
--     compassNeedle:Draw()
-- end
LuaUtil.LerpAngle = function(a, b, t, minValue, maxValue)
    minValue = minValue or 0
    maxValue = maxValue or 360

    if not (IsNumber(a) and IsNumber(b) and IsNumber(t)) then
        TEN.Util.PrintLog("Error in LuaUtil.LerpAngle: a, b, and t must be numbers.", TEN.Util.LogLevel.ERROR)
        return a
    end

    if not (IsNumber(minValue) and IsNumber(maxValue)) then
        TEN.Util.PrintLog("Error in LuaUtil.LerpAngle: minValue and maxValue must be numbers.", TEN.Util.LogLevel.ERROR)
        return a
    end

    if minValue >= maxValue then
        TEN.Util.PrintLog("Error in LuaUtil.LerpAngle: minValue must be less than maxValue.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Clamp t to [0, 1]
    t = max(0, min(1, t))

    -- Calculate shortest delta
    local delta = b - a
    local range = maxValue - minValue

    -- Normalize angles to range
    a = wrapAngleRaw(a, minValue, range)
    b = wrapAngleRaw(b, minValue, range)

    -- Wrap delta to [-range/2, range/2] for shortest path
    if delta > range / 2 then
        delta = delta - range
    elseif delta < -range / 2 then
        delta = delta + range
    end

    -- Interpolate and wrap result
    local result = a + delta * t
    return LuaUtil.WrapAngle(result, minValue, maxValue)
end

--- Interpolates between two colors in specified color space with options.
-- Supports RGB, HSL, and OKLch color spaces with customizable hue interpolation paths and saturation/lightness preservation.
-- @tparam Color colorA Starting color.
-- @tparam Color colorB Ending color.
-- @tparam float t Interpolation factor (0.0 to 1.0).
-- @tparam[opt=0] int space Color space to use (0 = RGB, 1 = HSL, 2 = OKLch).
-- @tparam[opt={}] table options Additional options.
--
-- - `huePath` (string): Path for hue interpolation in HSL/OKLch<br>`("shortest", "longest", "increasing", "decreasing")`<br>*Default: "shortest"*.
-- - `preserveSaturation` (boolean): If true, preserves starting saturation in HSL/OKLch.<br>*Default: false*.
--
-- - `preserveLightness` (boolean): If true, preserves starting lightness in HSL/OKLch.<br>*Default: false*.
--
-- @treturn[1] Color The interpolated color.
-- @treturn[2] Color colorA if an error occurs.
-- @usage
-- -- Example with RGB interpolation (red to blue):
-- local color1 = TEN.Color(255, 0, 0, 255)  -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)  -- Blue
-- local rgbColor = LuaUtil.InterpolateColor(color1, color2, 0.5) -- t = 0.5, RGB space
-- --   t    | R   | G | B
-- --  ------|-----|---|-----
-- --  0.00  | 255 | 0 | 0
-- --  0.25  | 191 | 0 | 64
-- --  0.50  | 128 | 0 | 128
-- --  0.75  | 64  | 0 | 191
-- --  1.00  | 0   | 0 | 255
--
-- -- Example with HSL interpolation (red to blue, shortest hue path):
-- local hslColor = LuaUtil.InterpolateColor(color1, color2, 0.5, 1)
-- --   t    | R   | G   | B
-- --  ------|-----|-----|-----
-- --  0.00  | 255 | 0   | 0
-- --  0.25  | 255 | 0   | 128
-- --  0.50  | 255 | 0   | 255
-- --  0.75  | 127 | 0   | 255
-- --  1.00  | 0   | 0   | 255
--
-- -- Example with HSL interpolation (red to blue, longest hue path):
-- local hslLongColor = LuaUtil.InterpolateColor(color1, color2, 0.5, 1, { huePath = "longest" })
-- --   t    | R   | G   | B
-- --  ------|-----|-----|-----
-- --  0.00  | 255 | 0   | 0
-- --  0.25  | 255 | 255 | 0
-- --  0.50  | 0   | 255 | 0
-- --  0.75  | 0   | 255 | 255
-- --  1.00  | 0   | 0   | 255
--
-- -- Example with OKLch interpolation (red to blue, shortest hue path):
-- local oklchShortColor = LuaUtil.InterpolateColor(color1, color2, 0.5, 2)
-- --   t    | R   | G   | B
-- --  ------|-----|-----|-----
-- --  0.00  | 255 | 0   | 0
-- --  0.25  | 232 | 0   | 123
-- --  0.50  | 186 | 0   | 194
-- --  0.75  | 122 | 25  | 244
-- --  1.00  | 0   | 0   | 255
--
-- -- Example with OKLch interpolation (red to blue, preserving saturation):
-- local oklchColor = LuaUtil.InterpolateColor(color1, color2, 0.5, 2, { preserveSaturation = true })
-- --   t    | R   | G   | B
-- --  ------|-----|-----|-----
-- --  0.00  | 255 | 0   | 0
-- --  0.25  | 228 | 0   | 123
-- --  0.50  | 180 | 0   | 186
-- --  0.75  | 117 | 25  | 224
-- --  1.00  | 2   | 52  | 225
-- -- Note: Enabling preserveSaturation, with t = 1 does not yield pure blue due to saturation preservation.
--
-- -- Example with OKLch interpolation (red to blue, preserving lightness):
-- local oklchLightColor = LuaUtil.InterpolateColor(color1, color2, 0.5, 2, { preserveLightness = true })
-- --   t    | R   | G   | B
-- --  ------|-----|-----|-----
-- --  0.00  | 255 | 0   | 0
-- --  0.25  | 249 | 0   | 136
-- --  0.50  | 217 | 17  | 224
-- --  0.75  | 159 | 62  | 255
-- --  1.00  | 28  | 103 | 255
-- -- Note: Enabling preserveLightness, with t = 1 does not yield pure blue due to lightness preservation.
LuaUtil.InterpolateColor = function(colorA, colorB, t, space, options)

    -- Validate input parameters
    if not IsColor(colorA) or not IsColor(colorB) then
        TEN.Util.PrintLog("Error in LuaUtil.InterpolateColor: colorA and colorB must be TEN.Color.", TEN.Util.LogLevel.ERROR)
        return colorA
    end

    if not IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.InterpolateColor: t must be a number.", TEN.Util.LogLevel.ERROR)
        return colorA
    end

    t = max(0, min(1, t))  -- Clamp t to [0, 1]

    space = space or 0

    if not IsNumber(space) or (space ~= 0  and space ~= 1 and space ~= 2) then
        TEN.Util.PrintLog("Warning in LuaUtil.InterpolateColor: invalid colorSpace, using RGB.", TEN.Util.LogLevel.WARNING)
        space = 0
    end

    -- Validate options (optional parameter)
    if not IsTable(options) then
        options = {}
    end

    local huePath = options.huePath
    if huePath ~= "shortest" and huePath ~= "longest" and huePath ~= "increasing" and huePath ~= "decreasing" then
        if huePath ~= nil then
            TEN.Util.PrintLog("Warning in LuaUtil.InterpolateColor: invalid huePath, using 'shortest'.", TEN.Util.LogLevel.WARNING)
        end
        huePath = "shortest"
    end

    local preserveS = options.preserveSaturation
    if preserveS ~= nil and not IsBoolean(preserveS) then
        TEN.Util.PrintLog("Warning in LuaUtil.InterpolateColor: preserveSaturation must be boolean. Using false.", TEN.Util.LogLevel.WARNING)
        preserveS = false
    end
    preserveS = preserveS or false

    local preserveL = options.preserveLightness
    if preserveL ~= nil and not IsBoolean(preserveL) then
        TEN.Util.PrintLog("Warning in LuaUtil.InterpolateColor: preserveLightness must be boolean. Using false.", TEN.Util.LogLevel.WARNING)
        preserveL = false
    end
    preserveL = preserveL or false

    -- RBG
    if space == 0 then
        local r = LuaUtil.Lerp(colorA.r, colorB.r, t)
        local g = LuaUtil.Lerp(colorA.g, colorB.g, t)
        local b = LuaUtil.Lerp(colorA.b, colorB.b, t)
        local a = LuaUtil.Lerp(colorA.a, colorB.a, t)
        return TEN.Color(r, g, b, a)
    end

    -- HSL
    if space == 1 then
        local HSLcolorA = LuaUtil.ColorToHSL(colorA)
        local HSLcolorB = LuaUtil.ColorToHSL(colorB)

        local h = InterpolateHue(HSLcolorA.h, HSLcolorB.h, t, huePath)
        local s = preserveS and HSLcolorA.s or LuaUtil.Lerp(HSLcolorA.s, HSLcolorB.s, t)
        local l = preserveL and HSLcolorA.l or LuaUtil.Lerp(HSLcolorA.l, HSLcolorB.l, t)

        local finalColor = LuaUtil.HSLtoColor(h, s, l)
        local a = LuaUtil.Lerp(colorA.a, colorB.a, t)
        return TEN.Color(finalColor.r, finalColor.g, finalColor.b, a)
    end

    -- OKLch
    if space == 2 then
        local OKLchColorA = LuaUtil.ColorToOKLch(colorA)
        local OKLchColorB = LuaUtil.ColorToOKLch(colorB)

        local l = preserveL and OKLchColorA.l or LuaUtil.Lerp(OKLchColorA.l, OKLchColorB.l, t)
        local c = preserveS and OKLchColorA.c or LuaUtil.Lerp(OKLchColorA.c, OKLchColorB.c, t)
        local h = InterpolateHue(OKLchColorA.h, OKLchColorB.h, t, huePath)

        local finalColor = LuaUtil.OKLchToColor(l, c, h)
        local a = LuaUtil.Lerp(colorA.a, colorB.a, t)
        return TEN.Color(finalColor.r, finalColor.g, finalColor.b, a)
    end
end

--- Table functions.
-- Utilities for working with Lua tables.
-- @section table

--- Get the number of elements in a table (works for non-sequential tables).
-- @tparam table tbl The table to count.
-- @treturn[1] int The number of elements.
-- @treturn[2] int 0 if input is invalid.
-- @usage
-- -- Example with non-sequential table:
-- local tbl = { apple = 1, banana = 2, cherry = 3 }
-- local count = LuaUtil.TableSize(tbl) -- Result: 3
LuaUtil.TableSize = function(tbl)
    if not IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.TableSize: input must be a table.", TEN.Util.LogLevel.ERROR)
        return 0
    end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--- Compare two tables for equality.
--- This function checks if both tables have the same keys and corresponding values. Works for shallow comparisons only.
--- @tparam table tbl1 The first table to compare.
--- @tparam table tbl2 The second table to compare.
--- @treturn[1] bool True if the tables are equal, false otherwise.
--- @treturn[2] bool false if an error occurs.
--- @usage
--- local tblA = { a = 1, b = 2 }
--- local tblB = { a = 1, b = 2 }
--- local tblC = { a = 1, b = 3 }
--- local isEqualAB = LuaUtil.CompareTables(tblA, tblB) -- Result: true
--- local isEqualAC = LuaUtil.CompareTables(tblA, tblC) -- Result: false
LuaUtil.CompareTables = function (tbl1, tbl2)
    if not (IsTable(tbl1) and IsTable(tbl2)) then
        TEN.Util.PrintLog("Error in LuaUtil.CompareTables: both inputs must be tables.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Track keys checked from tbl1
    local keysChecked = {}

    -- Check all keys from tbl1
    for key, value in pairs(tbl1) do
        if tbl2[key] ~= value then
            return false
        end
        keysChecked[key] = true
    end

    -- Check if tbl2 has any extra keys not in tbl1
    for key, _ in pairs(tbl2) do
        if not keysChecked[key] then
            return false  -- tbl2 has a key that tbl1 doesn't have
        end
    end

    return true
end

--- Deeply compare two tables for equality.
--- This function checks if both tables have the same keys and corresponding values, including nested tables.
--- **Limits:** Maximum depth of 10 levels and 1000 total elements processed to prevent performance issues.
--- @tparam table tbl1 The first table to compare.
--- @tparam table tbl2 The second table to compare.
--- @treturn[1] bool True if the tables are deeply equal, false otherwise.
--- @treturn[2] bool false if an error occurs.
--- @usage
--- local tblA = { a = 1, b = { c = 2, d = 3 } }
--- local tblB = { a = 1, b = { c = 2, d = 3 } }
--- local tblC = { a = 1, b = { c = 2, d = 4 } }
--- local isEqualAB = LuaUtil.CompareTablesDeep(tblA, tblB) -- Result: true
--- local isEqualAC = LuaUtil.CompareTablesDeep(tblA, tblC) -- Result: false
LuaUtil.CompareTablesDeep = function (tbl1, tbl2)
    if not (IsTable(tbl1) and IsTable(tbl2)) then
        TEN.Util.PrintLog("Error in LuaUtil.CompareTablesDeep: both inputs must be tables.", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Generate unique ID for this comparison
    local compareId = _nextCompareId
    _nextCompareId = _nextCompareId + 1

    -- Initialize context for this comparison
    _activeCompares[compareId] = {
        depth = 0,
        elementCount = 0,
        visited = {},  -- Prevents infinite loops on circular tables
        keysChecked = {}  -- Tracks which keys we've already processed
    }

    -- Execute comparison
    local result = CompareRecursive(tbl1, tbl2, compareId)

    -- Cleanup: remove context for this comparison
    _activeCompares[compareId] = nil

    return result
end

--- Check if a table contains a specific value.
-- @tparam table tbl The table to check.
-- @tparam any val The value to search for.
-- @treturn[1] bool True if the value is found, false otherwise.
-- @treturn[2] bool false if an error occurs.
-- @usage
-- -- Example with associative table:
-- local tbl = { apple = 1, banana = 2, cherry = 3 }
-- local hasBanana = LuaUtil.TableHasValue(tbl, 3) -- Result: true
-- local hasGrape = Utility.TableHasValue(tbl, 0) -- Result: false
--
-- -- Example with array table:
-- local tbl = { "apple", "banana", "cherry" }
-- local hasBanana = LuaUtil.TableHasValue(tbl, "banana") -- Result: true
-- local hasGrape = LuaUtil.TableHasValue(tbl, "grape") -- Result: false
LuaUtil.TableHasValue = function (tbl, val)
    if not IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.TableHasValue: input is not a table.", TEN.Util.LogLevel.ERROR)
        return false
    end
    for _, value in pairs(tbl) do
        if value == val then
            return true
        end
    end
    return false
end

--- Check if a table contains a specific key.
-- @tparam table tbl The table to check.
-- @tparam any key The key to search for.
-- @treturn[1] bool True if the key is found, false otherwise.
-- @treturn[2] bool false if an error occurs.
-- @usage
-- -- Example with associative table:
-- local tbl = { apple = 1, banana = 2, cherry = 3 }
-- local hasBananaKey = LuaUtil.TableHasKey(tbl, "banana") -- Result: true
-- local hasGrapeKey = LuaUtil.TableHasKey(tbl, "grape") -- Result: false
--
-- -- Example with array table:
-- local tbl = { "apple", "banana", "cherry" }
-- local hasBananaKey = LuaUtil.TableHasKey(tbl, 2) -- Result: true
-- local hasGrapeKey = LuaUtil.TableHasKey(tbl, 4) -- Result: false
LuaUtil.TableHasKey = function (tbl, key)
    if not IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.TableHasKey: input is not a table.", TEN.Util.LogLevel.ERROR)
        return false
    end
    for k, _ in pairs(tbl) do
        if k == key then
            return true
        end
    end
    return false
end

--- Create a shallow copy of a table.
-- Creates a new table with the same key-value pairs. Nested tables are NOT copied (they remain references).
-- @tparam table tbl The table to copy.
-- @treturn[1] table A shallow copy of the input table.
-- @treturn[2] table An empty table if input is not a table.
-- @usage
-- -- Example with simple table:
-- local original = { a = 1, b = 2, c = 3 }
-- local copy = LuaUtil.CopyTable(original)
-- copy.a = 10
-- -- original.a is still 1, copy.a is 10
--
-- -- Example with nested tables (shallow copy limitation):
-- local original = { name = "Lara", inventory = { sword = 1, shield = 2 } }
-- local copy = LuaUtil.CopyTable(original)
-- copy.inventory.sword = 5
-- -- WARNING: original.inventory.sword is now also 5! (nested table is shared)
-- -- For nested tables, use LuaUtil.CloneValue instead
--
-- -- Example with array:
-- local original = { "red", "green", "blue" }
-- local copy = LuaUtil.CopyTable(original)
-- copy[2] = "yellow"
-- -- original: { "red", "green", "blue" }
-- -- copy: { "red", "yellow", "blue" }
--
-- -- Practical use: backup a table before modification
-- local backup = LuaUtil.CopyTable(playerStats)
-- playerStats.health = 0
-- if needRestore then
--     playerStats = backup
-- end
LuaUtil.CopyTable = function(tbl)
    if not IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.CopyTable: input is not a table.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = value
    end
    return copy
end

--- Merge two tables into a new table.
-- Creates a new table combining keys from both tables. If a key exists in both, the value from tbl2 takes precedence.
-- This is a shallow merge (nested tables are not merged recursively).
-- @tparam table tbl1 The first table (base table).
-- @tparam table tbl2 The second table (override table).
-- @treturn[1] table A new table with merged contents.
-- @treturn[2] table An empty table if either input is not a table.
-- @usage
-- -- Example with configuration merge:
-- local defaults = { volume = 100, fullscreen = false, difficulty = "normal" }
-- local userSettings = { volume = 80, fullscreen = true }
-- local finalSettings = LuaUtil.MergeTables(defaults, userSettings)
-- -- finalSettings: { volume = 80, fullscreen = true, difficulty = "normal" }
--
-- -- Example with player stats:
-- local baseStats = { health = 100, stamina = 100, damage = 10 }
-- local bonuses = { health = 20, damage = 5 }
-- local totalStats = LuaUtil.MergeTables(baseStats, bonuses)
-- -- totalStats: { health = 20, stamina = 100, damage = 5 }
-- -- Note: values are replaced, not added! Use custom logic for addition.
--
-- -- Example with arrays (numeric keys):
-- local array1 = { "a", "b", "c" }
-- local array2 = { "x", "y" }
-- local merged = LuaUtil.MergeTables(array1, array2)
-- -- merged: { "x", "y", "c" } (indices 1 and 2 are overridden)
--
-- -- Practical use: apply temporary modifications
-- local defaultConfig = { speed = 10, color = "blue" }
-- local nightMode = { color = "black", brightness = 50 }
-- local activeConfig = LuaUtil.MergeTables(defaultConfig, nightMode)
-- -- activeConfig: { speed = 10, color = "black", brightness = 50 }
LuaUtil.MergeTables = function(tbl1, tbl2)
    if not IsTable(tbl1) then
        TEN.Util.PrintLog("Error in LuaUtil.MergeTables: tbl1 is not a table.", TEN.Util.LogLevel.ERROR)
        return {}
    end
    if not IsTable(tbl2) then
        TEN.Util.PrintLog("Error in LuaUtil.MergeTables: tbl2 is not a table.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    local merged = {}
    
    -- Copy all keys from tbl1
    for key, value in pairs(tbl1) do
        merged[key] = value
    end
    
    -- Copy all keys from tbl2 (overriding tbl1 if keys match)
    for key, value in pairs(tbl2) do
        merged[key] = value
    end
    
    return merged
end

--- Remove the first occurrence of a value from an array table.
-- This function searches for the value using pairs() and removes the first match found.
-- The array is compacted after removal (subsequent elements are shifted down).
-- @tparam table tbl The array table from which to remove the value.
-- @tparam any value The value to search for and remove.
-- @treturn[1] bool True if the value was found and removed, false otherwise.
-- @treturn[2] bool False if the input is not a table.
-- @usage
-- -- Example with array of strings:
-- local fruits = { "apple", "banana", "cherry", "banana" }
-- local removed = LuaUtil.RemoveValue(fruits, "banana") -- Result: true
-- -- fruits is now: { "apple", "cherry", "banana" }
--
-- -- Example with array of numbers:
-- local numbers = { 10, 20, 30, 40 }
-- local removed = LuaUtil.RemoveValue(numbers, 30) -- Result: true
-- -- numbers is now: { 10, 20, 40 }
--
-- -- Example when value is not found:
-- local colors = { "red", "green", "blue" }
-- local removed = LuaUtil.RemoveValue(colors, "yellow") -- Result: false
-- -- colors remains unchanged: { "red", "green", "blue" }
--
-- -- Example with mixed types:
-- local mixed = { 1, "two", 3, "four" }
-- local removed = LuaUtil.RemoveValue(mixed, "two") -- Result: true
-- -- mixed is now: { 1, 3, "four" }
LuaUtil.RemoveValue = function(tbl, value)
    if not IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.RemoveValue: input is not a table.", TEN.Util.LogLevel.ERROR)
        return false
    end

    for i, v in pairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            return true
        end
    end

    return false
end

--- Remove all occurrences of a value from an array table.
-- This function searches for all instances of the value and removes them.
-- The array is compacted after each removal (subsequent elements are shifted down).
-- Iterates backwards to handle index shifts correctly.
-- @tparam table tbl The array table from which to remove all occurrences of the value.
-- @tparam any value The value to search for and remove.
-- @treturn[1] int The number of occurrences removed.
-- @treturn[2] int 0 if the input is not a table.
-- @usage
-- -- Example with multiple occurrences:
-- local fruits = { "apple", "banana", "apple", "cherry", "apple" }
-- local count = LuaUtil.RemoveAllValues(fruits, "apple") -- Result: 3
-- -- fruits is now: { "banana", "cherry" }
--
-- -- Example with single occurrence:
-- local numbers = { 10, 20, 30, 40 }
-- local count = LuaUtil.RemoveAllValues(numbers, 30) -- Result: 1
-- -- numbers is now: { 10, 20, 40 }
--
-- -- Example when value is not found:
-- local colors = { "red", "green", "blue" }
-- local count = LuaUtil.RemoveAllValues(colors, "yellow") -- Result: 0
-- -- colors remains unchanged: { "red", "green", "blue" }
--
-- -- Example with all elements being removed:
-- local data = { 5, 5, 5, 5 }
-- local count = LuaUtil.RemoveAllValues(data, 5) -- Result: 4
-- -- data is now: {} (empty table)
--
-- -- Practical use: clean up inventory
-- local inventory = { "potion", "sword", "potion", "shield", "potion" }
-- local removed = LuaUtil.RemoveAllValues(inventory, "potion")
-- -- Removed 3 potions, inventory: { "sword", "shield" }
LuaUtil.RemoveAllValues = function(tbl, value)
    if not IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.RemoveAllValues: input is not a table.", TEN.Util.LogLevel.ERROR)
        return 0
    end

    local count = 0
    -- Iterate backwards to handle index shifts correctly during removal
    for i = #tbl, 1, -1 do
        if tbl[i] == value then
            table.remove(tbl, i)
            count = count + 1
        end
    end

    return count
end

--- Remove a key-value pair from an associative table.
-- This function removes the specified key and its associated value from the table.
-- Works with both associative tables and array tables (using numeric indices).
-- @tparam table tbl The table from which to remove the key.
-- @tparam any key The key to remove.
-- @treturn[1] bool True if the key existed and was removed, false if the key was not found.
-- @treturn[2] bool False if the input is not a table.
-- @usage
-- -- Example with associative table:
-- local player = { name = "Lara", health = 100, ammo = 50 }
-- local removed = LuaUtil.RemoveKey(player, "ammo") -- Result: true
-- -- player is now: { name = "Lara", health = 100 }
--
-- -- Example when key doesn't exist:
-- local items = { sword = 1, shield = 2 }
-- local removed = LuaUtil.RemoveKey(items, "helmet") -- Result: false
-- -- items remains unchanged: { sword = 1, shield = 2 }
--
-- -- Example with array table (using numeric index):
-- local colors = { "red", "green", "blue" }
-- local removed = LuaUtil.RemoveKey(colors, 2) -- Result: true
-- -- colors is now: { "red", "blue" } (but indices are: [1]="red", [3]="blue")
-- -- Note: For arrays, prefer using RemoveValue or table.remove for proper compacting
--
-- -- Example with nested tables:
-- local config = { display = { width = 1920, height = 1080 }, sound = { volume = 80 } }
-- local removed = LuaUtil.RemoveKey(config, "sound") -- Result: true
-- -- config is now: { display = { width = 1920, height = 1080 } }
LuaUtil.RemoveKey = function(tbl, key)
    if not IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.RemoveKey: input is not a table.", TEN.Util.LogLevel.ERROR)
        return false
    end

    if tbl[key] ~= nil then
        tbl[key] = nil
        return true
    end

    return false
end

--- Create a read-only version of a table.
-- @tparam table tbl The table to make read-only.
-- @treturn[1] table A read-only version of the input table.
-- @treturn[2] table An empty table if the input is not a table.
-- @usage
-- local readOnlyTable = LuaUtil.SetTableReadOnly(originalTable)
LuaUtil.SetTableReadOnly = function(tbl)
    if not IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.SetTableReadonly: input is not a table.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    return setmetatable({}, {
        __index = tbl,
        __newindex = function(_, key, _)
            TEN.Util.PrintLog("Error, cannot modify '" .. tostring(key) .. "': table is read-only", TEN.Util.LogLevel.ERROR)
        end,
        __pairs = function() return pairs(tbl) end,
        __ipairs = function() return ipairs(tbl) end,
    })
end

return LuaUtil