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

LevelVars.Engine.LuaUtil = {}

-- Default frames per second for time-frame conversions
LevelVars.Engine.LuaUtil.FPS = 30

-- Cache for type checking functions and math functions
LevelVars.Engine.LuaUtil.Cache = {
    -- Type checking functions
    IsNumber = Type.IsNumber,
    IsVec2 = Type.IsVec2,
    IsVec3 = Type.IsVec3,
    IsColor = Type.IsColor,
    IsTime = Type.IsTime,
    IsRotation = Type.IsRotation,
    IsBoolean = Type.IsBoolean,
    IsString = Type.IsString,
    IsTable = Type.IsTable,

    -- Math functions (risparmia table lookup)
    floor = math.floor,
    max = math.max,
    min = math.min,
    random = math.random,
    randomseed = math.randomseed,
    abs = math.abs,
    sin = math.sin,
    asin = math.asin,
    pi = math.pi
}

-- Local reference to type cache for performance
local C = LevelVars.Engine.LuaUtil.Cache

-- Helper table for comparison operators
LevelVars.Engine.LuaUtil.operators = {
    function(a, b) return a == b end,
    function(a, b) return a ~= b end,
    function(a, b) return a < b end,
    function(a, b) return a <= b end,
    function(a, b) return a > b end,
    function(a, b) return a >= b end,
}

-- Settings for deep table comparison
LevelVars.Engine.LuaUtil.CompareDeep = {
    MAX_DEPTH = 10,        -- Maximum nesting depth (prevents stack overflow)
    MAX_ELEMENTS = 1000,   -- Maximum total elements processed (prevents performance issues)
    nextId = 1,            -- Progressive ID for each comparison
    activeCompares = {}    -- Tracks active comparisons: { [id] = { depth, elementCount, visited } }
}

LevelFuncs.Engine.LuaUtil = {}

-- Helper function for type checking and interpolation
LevelFuncs.Engine.LuaUtil.InterpolateValues = function(a, b, clampedT, functionName)
    if C.IsNumber(a) then
        if not C.IsNumber(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a + (b - a) * clampedT
    end

    if C.IsVec3(a) then
        if not C.IsVec3(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if C.IsVec2(a) then
        if not C.IsVec2(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if C.IsColor(a) then
        if not C.IsColor(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if C.IsRotation(a) then
        if not C.IsRotation(b) then
            TEN.Util.PrintLog("Error in " .. functionName .. ": type mismatch.", TEN.Util.LogLevel.ERROR)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    TEN.Util.PrintLog("Error in " .. functionName .. ": unsupported type.", TEN.Util.LogLevel.ERROR)
    return a
end

-- Helper function for HSL to RGB conversion
LevelFuncs.Engine.LuaUtil.HueToRgb = function(p, q, t)
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

-- Support function for recursive comparison
LevelFuncs.Engine.LuaUtil.CompareRecursive = function(t1, t2, compareId)
    local context = LevelVars.Engine.LuaUtil.CompareDeep.activeCompares[compareId]

    -- Check maximum depth
    if context.depth >= LevelVars.Engine.LuaUtil.CompareDeep.MAX_DEPTH then
        TEN.Util.PrintLog("Warning in LuaUtil.CompareTablesDeep: Maximum depth (" .. 
            LevelVars.Engine.LuaUtil.CompareDeep.MAX_DEPTH .. ") exceeded.", TEN.Util.LogLevel.WARNING)
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
        if context.elementCount >= LevelVars.Engine.LuaUtil.CompareDeep.MAX_ELEMENTS then
            TEN.Util.PrintLog("Warning in LuaUtil.CompareTablesDeep: Maximum elements (" .. 
                LevelVars.Engine.LuaUtil.CompareDeep.MAX_ELEMENTS .. ") exceeded.", TEN.Util.LogLevel.WARNING)
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
        if C.IsTable(value1) and C.IsTable(value2) then
            if not LevelFuncs.Engine.LuaUtil.CompareRecursive(value1, value2, compareId) then
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

--- Comparison and validation functions.
-- Utilities for comparing values and checking ranges.
-- @section comparison

--- Compare two values based on the specified operator.
-- @tparam number|string|Time operand The first value to compare.
-- @tparam number|string|Time reference The second value to compare against.
-- @tparam number operator The comparison operator<br>(0: equal, 1: not equal, 2: less than, 3: less than or equal, 4: greater than, 5: greater than or equal).
-- @treturn bool The result of the comparison. If an error occurs, returns false.
-- @usage
-- local isEqual = LuaUtil.CompareValues(5, 5, 0) -- true
-- local isNotEqual = LuaUtil.CompareValues("hello", "world", 1) -- true
-- local isLessThan = LuaUtil.CompareValues(3.5, 4.0, 2) -- true
-- local isGreaterOrEqual = LuaUtil.CompareValues(TEN.Time(10), TEN.Time(5), 5) -- true
LuaUtil.CompareValues = function(operand, reference, operator)
    -- Validate operator
    if not C.IsNumber(operator) or operator < 0 or operator > 5 then
        TEN.Util.PrintLog("Invalid operator for comparison", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Lazy type checking
    if C.IsNumber(operand) then
        if not C.IsNumber(reference) then
            TEN.Util.PrintLog("Error in LuaUtil.CompareValues: type mismatch.", TEN.Util.LogLevel.ERROR)
            return false
        end
        return LevelVars.Engine.LuaUtil.operators[operator + 1](operand, reference)
    end

    if C.IsString(operand) then
        if not C.IsString(reference) then
            TEN.Util.PrintLog("Error in LuaUtil.CompareValues: type mismatch.", TEN.Util.LogLevel.ERROR)
            return false
        end
        return LevelVars.Engine.LuaUtil.operators[operator + 1](operand, reference)
    end

    if C.IsTime(operand) then
        if not C.IsTime(reference) then
            TEN.Util.PrintLog("Error in LuaUtil.CompareValues: type mismatch.", TEN.Util.LogLevel.ERROR)
            return false
        end
        return LevelVars.Engine.LuaUtil.operators[operator + 1](operand, reference)
    end

    TEN.Util.PrintLog("Error in LuaUtil.CompareValues: unsupported type.", TEN.Util.LogLevel.ERROR)
    return false
end

--- Check if a value is within a range (inclusive).
-- @tparam number value The value to check.
-- @tparam number min Minimum value.
-- @tparam number max Maximum value.
-- @treturn bool True if value is within range. If an error occurs, returns false.
-- @usage
-- local inRange = LuaUtil.InRange(5, 1, 10) -- true
-- local outOfRange = LuaUtil.InRange(15, 1, 10) -- false
-- local errorCase = LuaUtil.InRange(5, 10, 1) -- false (min greater than max)
LuaUtil.InRange = function(value, min, max)
    if not (C.IsNumber(value) and C.IsNumber(min) and C.IsNumber(max)) then
        TEN.Util.PrintLog("Error in LuaUtil.InRange: all parameters must be numbers.", TEN.Util.LogLevel.ERROR)   
        return false
    end

    if min > max then
        TEN.Util.PrintLog("Error in LuaUtil.InRange: min cannot be greater than max.", TEN.Util.LogLevel.ERROR)
        return false
    end

    return value >= min and value <= max
end

--- String functions.
-- Utilities for string manipulation.
-- @section string

--- Split a string into a table using a specified delimiter.
-- @tparam string inputStr The string to split.
-- @tparam[opt=" " (space)] string delimiter The delimiter to use for splitting.
-- @treturn table A table containing the split substrings. If an error occurs, returns an empty table.
-- @usage
-- local str = "apple,banana,cherry"
-- local result = LuaUtil.SplitString(str, ",")
-- -- Result: {"apple", "banana", "cherry"}
LuaUtil.SplitString = function(inputStr, delimiter)
    if not C.IsString(inputStr) then
        TEN.Util.PrintLog("Error in LuaUtil.SplitString: inputStr is not a string.", TEN.Util.LogLevel.ERROR)
        return {}
    end

	delimiter = delimiter or " "
    if not C.IsString(delimiter) then
        TEN.Util.PrintLog("Error in LuaUtil.SplitString: delimiter is not a string.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    local t = {}
    for str in string.gmatch(inputStr, "([^" .. delimiter .. "]+)") do
        table.insert(t, str)
    end
    return t
end

--- Conversion functions.
-- Utilities for converting between different units and formats.
-- @section conversion

--- Convert seconds to frames (assuming 30 FPS).
-- @tparam float seconds Time in seconds. Seconds can be a float value with two decimal places.
-- @tparam[opt=30] int fps Frames per second.
-- @treturn float Number of frames. If an error occurs, returns 0.
-- @usage
-- local frames = LuaUtil.SecondsToFrames(2.0) -- Result: 60
LuaUtil.SecondsToFrames = function(seconds, fps)
    fps = fps or LevelVars.Engine.LuaUtil.FPS
    if not C.IsNumber(seconds) or not C.IsNumber(fps) then
        TEN.Util.PrintLog("Error in LuaUtil.SecondsToFrames: seconds and fps must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end

    -- Check if fps is a float and warn user
    if fps ~= C.floor(fps) then
        TEN.Util.PrintLog("Warning in LuaUtil.SecondsToFrames: fps should be an integer. Rounding " .. fps .. " to " .. C.floor(fps + 0.5) .. ".", TEN.Util.LogLevel.WARNING)
        fps = C.floor(fps + 0.5)
    end

    return C.floor(seconds * fps + 0.5)
end

--- Convert frames to seconds (assuming 30 FPS).
-- @tparam int frames Number of frames.
-- @tparam[opt=30] int fps Frames per second.
-- @treturn float Time in seconds. If an error occurs, returns 0.
-- @usage
-- local seconds = LuaUtil.FramesToSeconds(60) -- Result: 2.0
LuaUtil.FramesToSeconds = function(frames, fps)
    fps = fps or LevelVars.Engine.LuaUtil.FPS
    if not C.IsNumber(frames) or (fps and not C.IsNumber(fps)) then
        TEN.Util.PrintLog("Error in LuaUtil.FramesToSeconds: frames and fps must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end

    -- Check if frames is a float and warn user
    if frames ~= C.floor(frames) then
        TEN.Util.PrintLog("Warning in LuaUtil.FramesToSeconds: frames should be an integer. Rounding " .. frames .. " to " .. C.floor(frames + 0.5) .. ".", TEN.Util.LogLevel.WARNING)
        frames = C.floor(frames + 0.5)
    end

    -- Check if fps is a float and warn user
    if fps ~= C.floor(fps) then
        TEN.Util.PrintLog("Warning in LuaUtil.FramesToSeconds: fps should be an integer. Rounding " .. fps .. " to " .. C.floor(fps + 0.5) .. ".", TEN.Util.LogLevel.WARNING)
        fps = C.floor(fps + 0.5)
    end

    if fps == 0 then
        TEN.Util.PrintLog("Error in LuaUtil.FramesToSeconds: fps cannot be zero.", TEN.Util.LogLevel.ERROR)
        return 0
    end

    return frames / fps
end

--- Convert a hexadecimal color string to a TEN.Color object.
-- @tparam string hex The hexadecimal color string (formats: "#RRGGBB", "RRGGBB", "#RRGGBBAA", "RRGGBBAA").
-- @treturn Color|nil The TEN.Color object, or nil on error.
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
-- sprite:SetColor(color)
--
-- -- Safe approach with default fallback:
-- local color = LuaUtil.HexToColor(hexString) or TEN.Color(255, 255, 255, 255)
LuaUtil.HexToColor = function(hex)
    if not C.IsString(hex) then
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
-- @treturn Color|nil The TEN.Color object, or nil on error.
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
-- sprite:SetColor(color)
--
-- -- Safe approach with default fallback:
-- local color = LuaUtil.HSLtoColor(hue, saturation, lightness, alpha) or TEN.Color(255, 255, 255, 255)
LuaUtil.HSLtoColor = function(h, s, l, a)
    if not (C.IsNumber(h) and C.IsNumber(s) and C.IsNumber(l)) then
        TEN.Util.PrintLog("Error in LuaUtil.HSLtoColor: h, s, and l must be numbers.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    if a and not C.IsNumber(a) then
        TEN.Util.PrintLog("Error in LuaUtil.HSLtoColor: a must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    a = a or 1.0

    -- Clamp values to valid ranges
    h = h % 360
    s = C.max(0, C.min(1, s))
    l = C.max(0, C.min(1, l))
    a = C.max(0, C.min(1, a))

    -- HSL to RGB conversion
    local r, g, b

    if s == 0 then
        -- Achromatic (gray)
        r, g, b = l, l, l
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        local hNorm = h / 360

        r = LevelFuncs.Engine.LuaUtil.HueToRgb(p, q, hNorm + 1/3)
        g = LevelFuncs.Engine.LuaUtil.HueToRgb(p, q, hNorm)
        b = LevelFuncs.Engine.LuaUtil.HueToRgb(p, q, hNorm - 1/3)
    end

    -- Convert to 0-255 range and create TEN.Color
    return TEN.Color(
        C.floor(r * 255 + 0.5),
        C.floor(g * 255 + 0.5),
        C.floor(b * 255 + 0.5),
        C.floor(a * 255 + 0.5)
    )
end

--- Convert a TEN.Color object to HSL (Hue, Saturation, Lightness) values.
-- Uses the Color:GetHue() method for accurate hue extraction.
-- @tparam Color color The TEN.Color object to convert.
-- @treturn table|nil A table with h, s, l, a values, or nil on error.
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
LuaUtil.ColorToHSL = function(color)
    if not C.IsColor(color) then
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
    local max = C.max(r, g, b)
    local min = C.min(r, g, b)
    local l = (max + min) / 2

    local s
    if max == min then
        s = 0  -- Achromatic (gray)
    else
        local delta = max - min
        s = l > 0.5 and delta / (2 - max - min) or delta / (max + min)
    end

    return { h = h, s = s, l = l, a = a }
end

--- Invert the RGB components of a color (255 - component).
-- Creates a negative/opposite color effect by inverting red, green, and blue channels.
-- Optionally preserves the original alpha channel.
-- @tparam Color color The color to invert.
-- @tparam[opt=false] bool keepAlpha If true, preserves the original alpha value.
-- @treturn Color|nil The inverted color, or nil on error.
-- @usage
-- -- Example: Simple color inversion
-- local red = TEN.Color(255, 0, 0, 255)
-- local cyan = LuaUtil.InvertColor(red)  
-- -- Result: TEN.Color(0, 255, 255, 0)
--
-- -- Example: Invert while keeping alpha
-- local semiRed = TEN.Color(255, 0, 0, 128)
-- local semiCyan = LuaUtil.InvertColor(semiRed, true)
-- -- Result: TEN.Color(0, 255, 255, 128)
--
-- -- Practical example: Create negative effect on sprite
-- local originalColor = sprite:GetColor()
-- local negativeColor = LuaUtil.InvertColor(originalColor, true)  -- Keep transparency
-- sprite:SetColor(negativeColor)
--
-- -- Example: Toggle between normal and inverted
-- local isInverted = false
-- local baseColor = TEN.Color(100, 150, 200, 255)
-- LevelFuncs.OnLoop = function()
--     if isInverted then
--         sprite:SetColor(LuaUtil.InvertColor(baseColor, true))
--     else
--         sprite:SetColor(baseColor)
--     end
-- end
--
-- -- Error handling example:
-- local inverted = LuaUtil.InvertColor(color, true)
-- if inverted == nil then
--     TEN.Util.PrintLog("Failed to invert color", TEN.Util.LogLevel.ERROR)
--     return
-- end
-- sprite:SetColor(inverted)
--
-- -- Safe approach with default fallback:
-- local invertedColor = LuaUtil.InvertColor(color, true) or TEN.Color(255, 255, 255, 255)
LuaUtil.InvertColor = function(color, keepAlpha)
    if not C.IsColor(color) then
        TEN.Util.PrintLog("Error in LuaUtil.InvertColor: color must be a Color object.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Handle keepAlpha: use default if nil/not provided, warn if wrong type
    if keepAlpha ~= nil and not C.IsBoolean(keepAlpha) then
        TEN.Util.PrintLog("Warning in LuaUtil.InvertColor: keepAlpha must be a boolean. Using default value (false).", TEN.Util.LogLevel.WARNING)
        keepAlpha = false
    else
        keepAlpha = keepAlpha or false
    end

    local inverted = color:Invert()
    
    if keepAlpha then
        inverted.a = color.a
    end

    return inverted
end

--- Mathematical functions.
-- Utilities for mathematical operations and rounding.
-- @section math

--- Get the minimum value between multiple arguments (supports numbers, Vec2, Vec3, Time).
-- For Vec2/Vec3, returns component-wise minimum.
-- @tparam number|Vec2|Vec3|Time ... Values to compare (at least 2).
-- @treturn number|Vec2|Vec3|Time|nil The minimum value, or nil on error.
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

    if C.IsNumber(first) then
        local minVal = args[1]
        for i = 2, #args do
            if not C.IsNumber(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Min: all arguments must be numbers.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            if args[i] < minVal then
                minVal = args[i]
            end
        end
        return minVal
    elseif C.IsTime(first) then
        local minTime = first
        for i = 2, #args do
            if not C.IsTime(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Min: all arguments must be Time.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            if args[i]:GetFrameCount() < minTime:GetFrameCount() then
                minTime = args[i]
            end
        end
        return minTime
    elseif C.IsVec2(first) then
        local result = TEN.Vec2(first.x, first.y)
        for i = 2, #args do
            if not C.IsVec2(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Min: all arguments must be Vec2.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            result.x = C.min(result.x, args[i].x)
            result.y = C.min(result.y, args[i].y)
        end
        return result
    elseif C.IsVec3(first) then
        local result = TEN.Vec3(first.x, first.y, first.z)
        for i = 2, #args do
            if not C.IsVec3(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Min: all arguments must be Vec3.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            result.x = C.min(result.x, args[i].x)
            result.y = C.min(result.y, args[i].y)
            result.z = C.min(result.z, args[i].z)
        end
        return result
    end
    TEN.Util.PrintLog("Error in LuaUtil.Min: unsupported type.", TEN.Util.LogLevel.ERROR)
    return nil
end

--- Get the maximum value between multiple arguments (supports numbers, Vec2, Vec3, Time).
-- For Vec2/Vec3, returns component-wise maximum.
-- @tparam number|Vec2|Vec3|Time ... Values to compare (at least 2).
-- @treturn number|Vec2|Vec3|Time|nil The maximum value, or nil on error.
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

    if C.IsNumber(first) then
        local maxVal = args[1]
        for i = 2, #args do
            if not C.IsNumber(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Max: all arguments must be numbers.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            if args[i] > maxVal then
                maxVal = args[i]
            end
        end
        return maxVal
    elseif C.IsTime(first) then
        local maxTime = first
        for i = 2, #args do
            if not C.IsTime(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Max: all arguments must be Time.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            if args[i]:GetFrameCount() > maxTime:GetFrameCount() then
                maxTime = args[i]
            end
        end
        return maxTime
    elseif C.IsVec2(first) then
        local result = TEN.Vec2(first.x, first.y)
        for i = 2, #args do
            if not C.IsVec2(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Max: all arguments must be Vec2.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            result.x = C.max(result.x, args[i].x)
            result.y = C.max(result.y, args[i].y)
        end
        return result
    elseif C.IsVec3(first) then
        local result = TEN.Vec3(first.x, first.y, first.z)
        for i = 2, #args do
            if not C.IsVec3(args[i]) then
                TEN.Util.PrintLog("Error in LuaUtil.Max: all arguments must be Vec3.", TEN.Util.LogLevel.ERROR)
                return nil
            end
            result.x = C.max(result.x, args[i].x)
            result.y = C.max(result.y, args[i].y)
            result.z = C.max(result.z, args[i].z)
        end
        return result
    end
    TEN.Util.PrintLog("Error in LuaUtil.Max: unsupported type.", TEN.Util.LogLevel.ERROR)
    return nil
end

--- Round a number to a specified number of decimal places.
-- @tparam float num The number to round.
-- @tparam[opt=0] float decimals Number of decimal places.
-- @treturn float The rounded number.
-- @usage
-- local rounded1 = LuaUtil.Round(3.14159)       -- Result: 3
-- local rounded2 = LuaUtil.Round(3.14159, 2)    -- Result: 3.14
-- local rounded3 = LuaUtil.Round(2.675, 2)      -- Result: 2.68
-- local rounded4 = LuaUtil.Round(-1.2345, 1)    -- Result: -1.2
LuaUtil.Round = function(num, decimals)
    decimals = decimals or 0
    if not C.IsNumber(num) or not C.IsNumber(decimals) then
        TEN.Util.PrintLog("Error in LuaUtil.Round: num and decimals must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end
    local mult = 10 ^ decimals
    return C.floor(num * mult + 0.5) / mult
end

--- Truncate a number to a specified number of decimal places (without rounding).
-- @tparam float num The number to truncate.
-- @tparam[opt=0] float decimals Number of decimal places.
-- @treturn float The truncated number.
-- @usage
-- local truncated1 = LuaUtil.Truncate(3.14159)       -- Result: 3
-- local truncated2 = LuaUtil.Truncate(3.14159, 2)    -- Result: 3.14
-- local truncated3 = LuaUtil.Truncate(2.999, 2)      -- Result: 2.99 (not rounded!)
-- local truncated4 = LuaUtil.Truncate(2.99, 0)       -- Result: 2     
-- local truncated4 = LuaUtil.Truncate(-1.2345, 1)    -- Result: -1.2
LuaUtil.Truncate = function(num, decimals)
    decimals = decimals or 0
    if not C.IsNumber(num) or not C.IsNumber(decimals) then
        TEN.Util.PrintLog("Error in LuaUtil.Truncate: num and decimals must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end
    local mult = 10 ^ decimals
    return C.floor(num * mult) / mult
end

--- Generate a random number or vector/color/time with optional seed.
-- @tparam float|Vec2|Vec3|Rotation|Color|Time min Minimum value.
-- @tparam float|Vec2|Vec3|Rotation|Color|Time max Maximum value (same type as min).
-- @tparam[opt] float seed Seed for reproducible randomness.
-- @treturn float|Vec2|Vec3|Rotation|Color|Time|nil Random value between min and max, or nil on error.
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
-- -- Random time duration between 1 and 3 seconds:
-- local randomDelay = LuaUtil.Random(
--     TEN.Time.FromSeconds(1),
--     TEN.Time.FromSeconds(3)
-- )
--
-- -- Random time in frames (30-90 frames = 1-3 seconds @ 30fps):
-- local randomFrames = LuaUtil.Random(
--     TEN.Time(LuaUtil.SecondsToFrames(5)),
--     TEN.Time(LuaUtil.SecondsToFrames(3.2))
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
LuaUtil.Random = function(min, max, seed)

    if seed and not C.IsNumber(seed) then
        TEN.Util.PrintLog("Error in LuaUtil.Random: seed must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    if seed then
        C.randomseed(seed)
    end

    if C.IsNumber(min) then
        if not C.IsNumber(max) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: min and max must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return min + C.random() * (max - min)
    elseif C.IsVec2(min) then
        if not C.IsVec2(max) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: min and max must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return TEN.Vec2(
            min.x + C.random() * (max.x - min.x),
            min.y + C.random() * (max.y - min.y)
        )
    elseif C.IsVec3(min) then
        if not C.IsVec3(max) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: min and max must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return TEN.Vec3(
            min.x + C.random() * (max.x - min.x),
            min.y + C.random() * (max.y - min.y),
            min.z + C.random() * (max.z - min.z)
        )
    elseif C.IsColor(min) then
        if not C.IsColor(max) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: min and max must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return TEN.Color(
            C.floor(min.r + C.random() * (max.r - min.r)),
            C.floor(min.g + C.random() * (max.g - min.g)),
            C.floor(min.b + C.random() * (max.b - min.b)),
            C.floor(min.a + C.random() * (max.a - min.a))
        )
    elseif C.IsTime(min) then
        if not C.IsTime(max) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: min and max must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        -- Generate random frames between min and max (Time objects work with gameFrames)
        local minFrames = min:GetFrameCount()
        local maxFrames = max:GetFrameCount()
        local randomFrames = C.floor(minFrames + C.random() * (maxFrames - minFrames))
        return TEN.Time(randomFrames)
    elseif C.IsRotation(min) then
        if not C.IsRotation(max) then
            TEN.Util.PrintLog("Error in LuaUtil.Random: min and max must be the same type.", TEN.Util.LogLevel.ERROR)
            return nil
        end
        return TEN.Rotation(
            min.x + C.random() * (max.x - min.x),
            min.y + C.random() * (max.y - min.y),
            min.z + C.random() * (max.z - min.z)
        )
    end
    TEN.Util.PrintLog("Error in LuaUtil.Random: min and max must be same type (number, Vec2, Vec3, Color, or Time).", TEN.Util.LogLevel.ERROR)
    return nil
end

--- Clamp a value between a minimum and maximum for numbers, Vec2, Vec3, Color, Rotation, and Time.
-- Supports numbers and TEN primitives (Color, Rotation, Time, Vec2, Vec3).
-- For primitives, each component is clamped individually between corresponding min/max components.
-- @tparam number|Color|Rotation|Time|Vec2|Vec3 value The value to clamp.
-- @tparam number|Color|Rotation|Time|Vec2|Vec3 min The minimum value (same type as value).
-- @tparam number|Color|Rotation|Time|Vec2|Vec3 max The maximum value (same type as value).
-- @treturn number|Color|Rotation|Time|Vec2|Vec3 The clamped value. If an error occurs, returns the original value.
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
-- local clampedValue = LuaUtil.Clamp(value, min, max) or defaultValue
LuaUtil.Clamp = function(value, min, max)
    -- Lazy type checking: check only what's needed
    if C.IsNumber(value) then
        if not (C.IsNumber(min) and C.IsNumber(max)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, min, max must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        if min > max then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: min cannot be greater than max.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return C.max(min, C.min(max, value))
    end

    if C.IsVec2(value) then
        if not (C.IsVec2(min) and C.IsVec2(max)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, min, max must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Vec2(
            C.max(min.x, C.min(max.x, value.x)),
            C.max(min.y, C.min(max.y, value.y))
        )
    end

    if C.IsVec3(value) then
        if not (C.IsVec3(min) and C.IsVec3(max)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, min, max must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Vec3(
            C.max(min.x, C.min(max.x, value.x)),
            C.max(min.y, C.min(max.y, value.y)),
            C.max(min.z, C.min(max.z, value.z))
        )
    end

    if C.IsRotation(value) then
        if not (C.IsRotation(min) and C.IsRotation(max)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, min, max must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Rotation(
            C.max(min.x, C.min(max.x, value.x)),
            C.max(min.y, C.min(max.y, value.y)),
            C.max(min.z, C.min(max.z, value.z))
        )
    end

    if C.IsColor(value) then
        if not (C.IsColor(min) and C.IsColor(max)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, min, max must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Color(
            C.max(min.r, C.min(max.r, value.r)),
            C.max(min.g, C.min(max.g, value.g)),
            C.max(min.b, C.min(max.b, value.b)),
            C.max(min.a, C.min(max.a, value.a))
        )
    end

    if C.IsTime(value) then
        if not (C.IsTime(min) and C.IsTime(max)) then
            TEN.Util.PrintLog("Error in LuaUtil.Clamp: value, min, max must be same type.", TEN.Util.LogLevel.ERROR)
            return value
        end
        return TEN.Time(C.max(min:GetFrameCount(), C.min(max:GetFrameCount(), value:GetFrameCount())))
    end

    TEN.Util.PrintLog("Error in LuaUtil.Clamp: unsupported type.", TEN.Util.LogLevel.ERROR)
    return value
end

--- Wrap an angle to a specific range (e.g., 0-360 or -180 to 180).
-- Useful for normalizing rotation angles and preventing overflow.
-- Unlike Clamp, this function wraps values cyclically (e.g., 450° → 90°).
-- @tparam float angle The angle to wrap.
-- @tparam[opt=0] float min Minimum value of the range.
-- @tparam[opt=360] float max Maximum value of the range.
-- @treturn float The wrapped angle. If an error occurs, returns the original angle.
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
LuaUtil.WrapAngle = function(angle, min, max)
    min = min or 0
    max = max or 360

    if not (C.IsNumber(angle) and C.IsNumber(min) and C.IsNumber(max)) then
        TEN.Util.PrintLog("Error in LuaUtil.WrapAngle: all parameters must be numbers.", TEN.Util.LogLevel.ERROR)
        return angle
    end

    local range = max - min
    if range == 0 then
        TEN.Util.PrintLog("Error in LuaUtil.WrapAngle: min cannot equal max.", TEN.Util.LogLevel.ERROR)
        return angle
    end

    return angle - range * C.floor((angle - min) / range)
end

--- Interpolation functions.
-- Utilities for interpolating between values.
-- Different interpolation methods provide various speed curves and behaviors.
--     | Speed      | Type curve         | Behavior                             |
--     |------------|--------------------|--------------------------------------|
--     | Lerp       | Linear progression | constant speed                       |
--     | Smoothstep | Smooth S-curve     | gentle ease-in and ease-out          |
--     | EaseInOut  | Quadratic curve    | pronounced acceleration/deceleration |
--     | Elastic    | Spring oscillation | overshoot with bounce effect         |
--
-- **Comparison of interpolation methods (0 to 10):**
--     | t      | Lerp  | Smoothstep | EaseInOut | Elastic |
--     |--------|-------|------------|-----------|---------|
--     | 0.00   | 0.00  | 0.00       | 0.00      | 0.00    |
--     | 0.10   | 1.00  | 0.28       | 0.20      | -0.04   |
--     | 0.25   | 2.50  | 1.56       | 1.25      | 0.44    |
--     | 0.50   | 5.00  | 5.00       | 5.00      | 5.00    |
--     | 0.75   | 7.50  | 8.44       | 8.75      | 9.56    |
--     | 0.90   | 9.00  | 9.72       | 9.80      | 10.04   |
--     | 1.00   | 10.00 | 10.00      | 10.00     | 10.00   |
--
-- @section interpolation

--- Linearly interpolate between two values. Formula: result = a + (b - a) * t.
-- Provides constant-speed interpolation between start and end values.
-- Unlike Smoothstep and EaseInOut, Lerp maintains uniform velocity throughout the entire transition.
-- @tparam float|Color|Rotation|Vec2|Vec3 a The start value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float|Color|Rotation|Vec2|Vec3 b The end value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float t The interpolation factor (0.0 to 1.0).
-- @treturn float|Color|Rotation|Vec2|Vec3 The interpolated value. If an error occurs, returns value `a`.
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
-- -- Practical animation example (door opening at constant speed over 2 seconds):
-- local customDoor = TEN.Objects.GetMoveableByName("door_1")
-- local animationDuration = LuaUtil.SecondsToFrames(2)  -- 2 seconds = 60 frames @ 30fps
-- local currentFrame = 0
-- LevelFuncs.OnLoop = function()
--     if currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         local angle = LuaUtil.Lerp(0, 90, t)  -- 0° to 90° with constant speed
--         customDoor:SetRotation(TEN.Rotation(0, angle, 0))
--         currentFrame = currentFrame + 1
--     else
--         currentFrame = 0  -- Reset for looping animation
--     end
-- end
LuaUtil.Lerp = function(a, b, t)
    if not C.IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Lerp: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
        return a
    end
    -- Clamp t to the range [0, 1]
    local clampedT = C.max(0, C.min(1, t))
    return LevelFuncs.Engine.LuaUtil.InterpolateValues(a, b, clampedT, "LuaUtil.Lerp")
end

--- Smoothly interpolate between two values using Hermite interpolation.
-- The function first normalizes the input value t to a 0-1 range using edge0 and edge1,
-- then applies a smooth S-curve (Hermite polynomial: 3t² - 2t³ or t²(3 - 2t)) for smoother transitions.
-- @tparam float|Color|Rotation|Vec2|Vec3 a Start value (returned when t <= edge0).
-- @tparam float|Color|Rotation|Vec2|Vec3 b End value (returned when t >= edge1).
-- @tparam float t The input value to be normalized and interpolated.
-- @tparam[opt=0] float edge0 Lower edge: the value of t that maps to 0 (start of interpolation range).
-- @tparam[opt=1] float edge1 Upper edge: the value of t that maps to 1 (end of interpolation range).
-- @treturn float|Color|Rotation|Vec2|Vec3 Smoothly interpolated result. If an error occurs, returns value `a`.
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
-- -- Example with distance-based fog (fade in fog between 1000-5000 units):
-- local distance = 3000  -- Distance from camera
-- local fogIntensity = LuaUtil.Smoothstep(0, 1, distance, 1000, 5000)
-- -- Result: ~0.64 (smooth fade-in as distance increases)
-- -- Apply to fog color:
-- local fogColor = LuaUtil.Smoothstep(
--     TEN.Color(255, 255, 255, 0),    -- No fog (transparent)
--     TEN.Color(128, 128, 128, 255),  -- Full fog (gray)
--     distance, 1000, 5000
-- )
--
-- -- Practical animation example (platform moving smoothly over 3 seconds):
-- local bridge = TEN.Objects.GetMoveableByName("bridge_flat_1")
-- local startPos = TEN.Vec3(0, 0, 0)
-- local endPos = TEN.Vec3(-512, 0, 0)  -- Move left 512 units
-- local bridgeInitialPos = bridge:GetPosition()
-- local animationDuration = LuaUtil.SecondsToFrames(3)  -- 3 seconds = 90 frames @ 30fps
-- local currentFrame = 0
-- LevelFuncs.OnLoop = function()
--     if currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         local offset = LuaUtil.Smoothstep(startPos, endPos, t)
--         bridge:SetPosition(bridgeInitialPos + offset)
--         currentFrame = currentFrame + 1
--     else
--         currentFrame = 0  -- Reset for looping animation
--     end
-- end
LuaUtil.Smoothstep = function (a, b, t, edge0, edge1)
    -- Default edge0 and edge1 if not provided
    edge0 = edge0 or 0
    edge1 = edge1 or 1

    if not C.IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Smoothstep: t must be a number.", TEN.Util.LogLevel.ERROR)
        return a
    end

    if not (C.IsNumber(edge0) and C.IsNumber(edge1)) then
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
    local normalizedT = C.max(0, C.min(1, (t - edge0) / edgeDelta))

    -- Evaluate polynomial
    local smoothedT = normalizedT * normalizedT * (3 - 2 * normalizedT)
    return LevelFuncs.Engine.LuaUtil.InterpolateValues(a, b, smoothedT, "LuaUtil.Smoothstep")
end

--- Smoothly interpolate with ease-in-out quadratic curve.
-- Provides gentle acceleration at the start and deceleration at the end.
-- Quadratic curve with pronounced than Smoothstep but smoother than linear interpolation.
-- Uses quadratic formula: t < 0.5 → 2t², otherwise → 1 - 2(1-t)²
-- @tparam float|Color|Rotation|Vec2|Vec3 a Start value.
-- @tparam float|Color|Rotation|Vec2|Vec3 b End value.
-- @tparam float t Interpolation factor (0.0 to 1.0).
-- @treturn float|Color|Rotation|Vec2|Vec3 The interpolated value. If an error occurs, returns value `a`.
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
-- LevelFuncs.OnLoop = function()
--     if currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         local newPos = LuaUtil.EaseInOut(startPos, endPos, t)
--         elevator:SetPosition(newPos)
--         currentFrame = currentFrame + 1
--     else
--         currentFrame = 0  -- Reset for looping animation
--     end
-- end
LuaUtil.EaseInOut = function(a, b, t)
    if not C.IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.EaseInOut: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Clamp t to [0, 1]
    t = C.max(0, C.min(1, t))

    -- EaseInOutQuad formula
    local easedT
    if t < 0.5 then
        easedT = 2 * t * t  -- Ease in: accelerazione
    else
        easedT = 1 - 2 * (1 - t) * (1 - t)  -- Ease out: decelerazione
    end

    return LevelFuncs.Engine.LuaUtil.InterpolateValues(a, b, easedT, "LuaUtil.EaseInOut")
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
-- @treturn float|Color|Rotation|Vec2|Vec3 The interpolated value with elastic effect. If an error occurs, returns value `a`.
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
-- -- Practical animation example (button press with elastic scale over 0.5 seconds):
-- local button = TEN.Objects.GetMoveableByName("ui_button_1")
-- local normalScale = TEN.Vec3(1, 1, 1)
-- local pressedScale = TEN.Vec3(1.2, 1.2, 1.2)
-- local animationDuration = LuaUtil.SecondsToFrames(0.5)  -- 0.5 seconds = 15 frames @ 30fps
-- local currentFrame = 0
-- local isPressed = false
-- LevelFuncs.OnLoop = function()
--     if isPressed and currentFrame <= animationDuration then
--         local t = currentFrame / animationDuration
--         local scale = LuaUtil.Elastic(normalScale, pressedScale, t, 1.5, 0.2)
--         -- t=0.0  → Vec3(1.0, 1.0, 1.0)     (normal)
--         -- t=0.3  → Vec3(0.97, 0.97, 0.97)  (shrinks slightly!)
--         -- t=0.5  → Vec3(1.1, 1.1, 1.1)     (halfway)
--         -- t=0.7  → Vec3(1.23, 1.23, 1.23)  (overshoots!)
--         -- t=0.9  → Vec3(1.19, 1.19, 1.19)  (wobbles)
--         -- t=1.0  → Vec3(1.2, 1.2, 1.2)     (settles)
--         button:SetScale(scale)
--         currentFrame = currentFrame + 1
--     elseif currentFrame > animationDuration then
--         currentFrame = 0
--         isPressed = false
--     end
-- end
--
-- -- Practical example: Pickup item animation (item bounces toward player):
-- local pickup = TEN.Objects.GetMoveableByName("pickup_item")
-- local startPos = pickup:GetPosition()
-- local playerPos = Lara:GetPosition()
-- local animationDuration = LuaUtil.SecondsToFrames(1.0)  -- 1 second
-- local currentFrame = 0
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
--         pickup:Disable()  -- Collect the item
--         currentFrame = 0
--     end
-- end
LuaUtil.Elastic = function(a, b, t, amplitude, period)
    if not C.IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Elastic: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Set default values and validate optional parameters
    amplitude = amplitude or 1.0
    period = period or 0.3

    if not C.IsNumber(amplitude) or not C.IsNumber(period) then
        TEN.Util.PrintLog("Error in LuaUtil.Elastic: amplitude and period must be numbers.", TEN.Util.LogLevel.ERROR)
        return a
    end

    -- Validate amplitude (must be >= 1.0 for proper elastic effect)
    if amplitude < 1.0 then
        TEN.Util.PrintLog("Warning in LuaUtil.Elastic: amplitude should be >= 1.0 for proper elastic effect. Using 1.0.", TEN.Util.LogLevel.WARNING)
        amplitude = 1.0
    end

    -- Clamp t to [0, 1]
    t = C.max(0, C.min(1, t))

    -- Handle edge cases (no oscillation at start/end)
    if t == 0 then
        return a
    elseif t == 1 then
        return b
    end

    -- EaseInOutElastic formula
    local twoPi = 2 * C.pi

    -- Calculate phase shift 's' to adjust the sine wave's starting point
    -- The phase shift ensures the elastic curve starts at 0 and ends at 1
    -- Formula: s = period / (2π) * arcsin(1 / amplitude)
    local s = period / (2 * C.pi) * C.asin(1 / amplitude)
    local periodOverTwoPi = twoPi / period
    local easedT

    if t < 0.5 then
        -- Ease In (first half) - undershoot at start
        t = t * 2
        easedT = -(amplitude * (2 ^ (10 * (t - 1))) * C.sin((t - 1 - s) * periodOverTwoPi)) / 2
    else
        -- Ease Out (second half) - overshoot at end
        t = t * 2 - 1
        easedT = (amplitude * (2 ^ (-10 * t)) * C.sin((t - s) * periodOverTwoPi)) / 2 + 1
    end

    return LevelFuncs.Engine.LuaUtil.InterpolateValues(a, b, easedT, "LuaUtil.Elastic")
end

--- Table functions.
-- Utilities for working with Lua tables.
-- @section table

--- Get the number of elements in a table (works for non-sequential tables).
-- @tparam table tbl The table to count.
-- @treturn int The number of elements.
-- @usage
-- -- Example with non-sequential table:
-- local tbl = { apple = 1, banana = 2, cherry = 3 }
-- local count = LuaUtil.TableCount(tbl) -- Result: 3
LuaUtil.TableCount = function(tbl)
    if not C.IsTable(tbl) then
        return 0
    end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--- Check if a table is empty (has no elements).
-- More efficient than TableCount(tbl) == 0 because it stops at the first element.
-- @tparam table tbl The table to check.
-- @treturn bool True if the table is empty, false otherwise.
-- @usage
-- local emptyTable = {}
-- local nonEmptyTable = { a = 1 }
--
-- local isEmpty1 = LuaUtil.TableIsEmpty(emptyTable)    -- Result: true
-- local isEmpty2 = LuaUtil.TableIsEmpty(nonEmptyTable) -- Result: false
--
-- -- Practical example: Check if player has items
-- if not LuaUtil.TableIsEmpty(playerInventory) then
--     TEN.Util.PrintLog("Player has items!", TEN.Util.LogLevel.INFO)
-- end
LuaUtil.TableIsEmpty = function(tbl)
    if not C.IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.TableIsEmpty: input must be a table.", TEN.Util.LogLevel.ERROR)
        return true  -- Consider non-table as "empty"
    end

    -- More efficient check for emptiness
    for _ in pairs(tbl) do
        return false  -- Has at least 1 element
    end
    return true  -- No elements found
end

--- Compare two tables for equality.
--- This function checks if both tables have the same keys and corresponding values. Works for shallow comparisons only.
--- @tparam table tbl1 The first table to compare.
--- @tparam table tbl2 The second table to compare.
--- @treturn bool True if the tables are equal, false otherwise.
--- @usage
--- local tblA = { a = 1, b = 2 }
--- local tblB = { a = 1, b = 2 }
--- local tblC = { a = 1, b = 3 }
--- local isEqualAB = LuaUtil.CompareTables(tblA, tblB) -- Result: true
--- local isEqualAC = LuaUtil.CompareTables(tblA, tblC) -- Result: false
LuaUtil.CompareTables = function (tbl1, tbl2)
    if not (C.IsTable(tbl1) and C.IsTable(tbl2)) then
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
--- @treturn bool True if the tables are deeply equal, false otherwise.
--- @usage
--- local tblA = { a = 1, b = { c = 2, d = 3 } }
--- local tblB = { a = 1, b = { c = 2, d = 3 } }
--- local tblC = { a = 1, b = { c = 2, d = 4 } }
--- local isEqualAB = LuaUtil.CompareTablesDeep(tblA, tblB) -- Result: true
--- local isEqualAC = LuaUtil.CompareTablesDeep(tblA, tblC) -- Result: false
LuaUtil.CompareTablesDeep = function (tbl1, tbl2)
    if not (C.IsTable(tbl1) and C.IsTable(tbl2)) then
        return false
    end

    -- Generate unique ID for this comparison
    local compareId = LevelVars.Engine.LuaUtil.CompareDeep.nextId
    LevelVars.Engine.LuaUtil.CompareDeep.nextId = LevelVars.Engine.LuaUtil.CompareDeep.nextId + 1

    -- Initialize context for this comparison
    LevelVars.Engine.LuaUtil.CompareDeep.activeCompares[compareId] = {
        depth = 0,
        elementCount = 0,
        visited = {},  -- Prevents infinite loops on circular tables
        keysChecked = {}  -- Tracks which keys we've already processed
    }

    -- Execute comparison
    local result = LevelFuncs.Engine.LuaUtil.CompareRecursive(tbl1, tbl2, compareId)

    -- Cleanup: remove context for this comparison
    LevelVars.Engine.LuaUtil.CompareDeep.activeCompares[compareId] = nil

    return result
end

--- Check if a table contains a specific value.
-- @tparam table tbl The table to check.
-- @tparam any val The value to search for.
-- @treturn bool True if the value is found, false otherwise.
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
    if not C.IsTable(tbl) then
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
-- @treturn bool True if the key is found, false otherwise.
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
    if not C.IsTable(tbl) then
        return false
    end
    for k, _ in pairs(tbl) do
        if k == key then
            return true
        end
    end
    return false
end

--- Create a read-only version of a table.
-- @tparam table tbl The table to make read-only.
-- @treturn table A read-only version of the input table. If the input is not a table, returns an empty table.
-- @usage
-- local readOnlyTable = LuaUtil.SetTableReadonly(originalTable)
LuaUtil.SetTableReadonly = function(tbl)
    if not C.IsTable(tbl) then
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