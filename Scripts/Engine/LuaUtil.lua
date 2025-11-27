-----<style>table.function_list td.name {min-width: 345px;}</style>
--- Lua support functions to simplify operations in scripts. To use, include the module with:
---	local LuaUtil = require("Engine.LuaUtil")
--- @luautil LuaUtil

local Type= require("Engine.Type")
local LuaUtil = {}


LevelVars.Engine.LuaUtil = {}
LevelVars.Engine.LuaUtil.FPS = 30

LevelVars.Engine.LuaUtil.operators = {
    function(a, b) return a == b end,
    function(a, b) return a ~= b end,
    function(a, b) return a < b end,
    function(a, b) return a <= b end,
    function(a, b) return a > b end,
    function(a, b) return a >= b end,
}

LevelFuncs.Engine.LuaUtil = {}

-- Helper function for ping-pong calculation on a single component
LevelFuncs.Engine.LuaUtil.PingPongComponent = function(t, length)
    if length == 0 then return 0 end
    t = t % (length * 2)
    return t > length and (length * 2 - t) or t
end

-- Helper function for type checking and interpolation
LevelFuncs.Engine.LuaUtil.InterpolateValues = function(a, b, clampedT, functionName)
    local isColor = Type.IsColor(a) and Type.IsColor(b)
    local isRotation = Type.IsRotation(a) and Type.IsRotation(b)
    local isVec2 = Type.IsVec2(a) and Type.IsVec2(b)
    local isVec3 = Type.IsVec3(a) and Type.IsVec3(b)
    local isNumber = Type.IsNumber(a) and Type.IsNumber(b)

    if isNumber then
        return a + (b - a) * clampedT
    elseif isColor or isRotation or isVec2 or isVec3 then
        return a:Lerp(b, clampedT)
    else
        TEN.Util.PrintLog("Error in " .. functionName .. ": a/b must be Numbers/Colors/Rotations/Vec2/Vec3.", TEN.Util.LogLevel.ERROR)
        return nil
    end
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

--- Comparison and validation functions.
-- Utilities for comparing values and checking ranges.
-- @section comparison

--- Compare two values based on the specified operator.
-- @tparam number|string|Time operand The first value to compare.
-- @tparam number|string|Time reference The second value to compare against.
-- @tparam number operator The comparison operator<br>(0: equal, 1: not equal, 2: less than, 3: less than or equal, 4: greater than, 5: greater than or equal).
-- @treturn bool The result of the comparison.
-- @usage
-- local isEqual = LuaUtil.CompareValues(5, 5, 0) -- true
-- local isNotEqual = LuaUtil.CompareValues("hello", "world", 1) -- true
-- local isLessThan = LuaUtil.CompareValues(3.5, 4.0, 2) -- true
-- local isGreaterOrEqual = LuaUtil.CompareValues(TEN.Time(10), TEN.Time(5), 5) -- true
LuaUtil.CompareValues = function(operand, reference, operator)

    -- Validate operator
    if not Type.IsNumber(operator) or operator < 0 or operator > 5 then
        TEN.Util.PrintLog("Invalid operator for comparison", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Type checking
    local isNumber = Type.IsNumber(operand) and Type.IsNumber(reference)
    local isString = Type.IsString(operand) and Type.IsString(reference)
    local isTime = Type.IsTime(operand) and Type.IsTime(reference)

    -- Type mismatch error
    if not (isNumber or isString or isTime) then
        TEN.Util.PrintLog("Error in LuaUtil.CompareValues: operand and reference must be of the same type (number, string, Time).", TEN.Util.LogLevel.ERROR)
        return false
    end

    -- Convert booleans to numbers for comparison
    operand = operand == true and 1 or operand == false and 0 or operand
    reference = reference == true and 1 or reference == false and 0 or reference

    return LevelVars.Engine.LuaUtil.operators[operator + 1] and LevelVars.Engine.LuaUtil.operators[operator + 1](operand, reference) or false
end

--- Check if a value is within a range (inclusive).
-- @tparam number value The value to check.
-- @tparam number min Minimum value.
-- @tparam number max Maximum value.
-- @treturn bool True if value is within range.
-- @usage
-- local inRange = LuaUtil.InRange(5, 1, 10) -- true
-- local outOfRange = LuaUtil.InRange(15, 1, 10) -- false
LuaUtil.InRange = function(value, min, max)
    if min > max then
        TEN.Util.PrintLog("Error in LuaUtil.InRange: min cannot be greater than max.", TEN.Util.LogLevel.ERROR)
        return false
    end
    if not (Type.IsNumber(value) and Type.IsNumber(min) and Type.IsNumber(max)) then
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
-- @treturn table A table containing the split substrings.
-- @usage
-- local str = "apple,banana,cherry"
-- local result = LuaUtil.SplitString(str, ",")
-- -- Result: {"apple", "banana", "cherry"}
LuaUtil.SplitString = function(inputStr, delimiter)
    if not Type.IsString(inputStr) then
        TEN.Util.PrintLog("Error in LuaUtil.SplitString: inputStr is not a string.", TEN.Util.LogLevel.ERROR)
        return {}
    end

	delimiter = delimiter or " "
    if not Type.IsString(delimiter) then
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
-- @tparam float seconds Time in seconds.
-- @tparam[opt=30] float fps Frames per second.
-- @treturn float Number of frames.
-- @usage
-- local frames = LuaUtil.SecondsToFrames(2.0) -- Result: 60
LuaUtil.SecondsToFrames = function(seconds, fps)
    fps = fps or LevelVars.Engine.LuaUtil.FPS
    if not Type.IsNumber(seconds) or not Type.IsNumber(fps) then
        TEN.Util.PrintLog("Error in LuaUtil.SecondsToFrames: seconds and fps must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end
    return math.floor(seconds * fps)
end

--- Convert frames to seconds (assuming 30 FPS).
-- @tparam float frames Number of frames.
-- @tparam[opt=30] int fps Frames per second.
-- @treturn float Time in seconds.
-- @usage
-- local seconds = LuaUtil.FramesToSeconds(60) -- Result: 2.0
LuaUtil.FramesToSeconds = function(frames, fps)
    fps = fps or LevelVars.Engine.LuaUtil.FPS
    if not Type.IsNumber(frames) or (fps and not Type.IsNumber(fps)) then
        TEN.Util.PrintLog("Error in LuaUtil.FramesToSeconds: frames and fps must be numbers.", TEN.Util.LogLevel.ERROR)
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
LuaUtil.HexToColor = function(hex)
    if not Type.IsString(hex) then
        TEN.Util.PrintLog("Error in LuaUtil.HexToColor: hex must be a string.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Remove '#' if present
    hex = hex:gsub("#", "")

    -- Validate length (6 for RGB, 8 for RGBA)
    if #hex ~= 6 and #hex ~= 8 then
        TEN.Util.PrintLog("Error in LuaUtil.HexToColor: invalid hex string length. Expected 6 or 8 characters.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Extract color components
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = #hex == 8 and tonumber(hex:sub(7, 8), 16) or 255

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
LuaUtil.HSLtoColor = function(h, s, l, a)
    if not (Type.IsNumber(h) and Type.IsNumber(s) and Type.IsNumber(l)) then
        TEN.Util.PrintLog("Error in LuaUtil.HSLtoColor: h, s, and l must be numbers.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    if a and not Type.IsNumber(a) then
        TEN.Util.PrintLog("Error in LuaUtil.HSLtoColor: a must be a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    a = a or 1.0

    -- Clamp values to valid ranges
    h = h % 360
    s = math.max(0, math.min(1, s))
    l = math.max(0, math.min(1, l))
    a = math.max(0, math.min(1, a))

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
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5),
        math.floor(a * 255 + 0.5)
    )
end

--- Mathematical functions.
-- Utilities for mathematical operations and rounding.
-- @section math

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
    if not Type.IsNumber(num) or not Type.IsNumber(decimals) then
        TEN.Util.PrintLog("Error in LuaUtil.Round: num and decimals must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

--- Generate a random number with optional seed.
-- @tparam float min Minimum value.
-- @tparam float max Maximum value.
-- @tparam[opt] float seed Optional seed for reproducible randomness.
-- @treturn float Random number between min and max.
-- @usage
-- local rand1 = LuaUtil.Random(1, 10)          -- Random number between 1 and 10
-- local rand2 = LuaUtil.Random(0.0, 1.0)       -- Random float between 0.0 and 1.0
-- local rand3 = LuaUtil.Random(1, 100, 42)    -- Random number between 1 and 100 with seed 42
LuaUtil.Random = function(min, max, seed)
    if not (Type.IsNumber(min) and Type.IsNumber(max)) or (seed and not Type.IsNumber(seed)) then
        TEN.Util.PrintLog("Error in LuaUtil.Random: min, max and seed must be numbers.", TEN.Util.LogLevel.ERROR)
        return 0
    end
    if seed then
        math.randomseed(seed)
    end
    return min + math.random() * (max - min)
end

--- Clamp a value between a minimum and maximum.
-- @tparam number value The value to clamp.
-- @tparam number min The minimum value.
-- @tparam number max The maximum value.
-- @treturn number The clamped value.
-- @usage
-- -- Example: Clamp to 0-1 range for normalized values
-- local clampedValue = LuaUtil.Clamp(value, 0, 1)
--
-- -- Practical use: Clamp value between 0 and 1
-- local inputValue = 1.5
-- local clampedValue = LuaUtil.Clamp(inputValue, 0, 1) -- Result: 1
LuaUtil.Clamp = function(value, min, max)
    if not (Type.IsNumber(value) and Type.IsNumber(min) and Type.IsNumber(max)) then
        TEN.Util.PrintLog("Error in LuaUtil.Clamp: parameters must be numbers.", TEN.Util.LogLevel.ERROR)
        return value
    end
    return math.max(min, math.min(max, value))
end

--- Ping-pong animation that oscillates from 0 to length over a specified period.
-- Returns a value that oscillates smoothly between 0 and the specified length.
-- Supports numbers, Vec2, Vec3, Rotation, and Color types.
-- 
-- **Important Note:**
-- This function must be called **every frame** to update the animation value.
-- Use it within a repeating function in your level's Lua script, such as:<ul>
-- <li>`LevelFuncs.OnLoop` for animations during normal gameplay</li>
-- <li>`LevelFuncs.OnFreeze` for animations during freeze mode</li>
-- <li>Or register a callback (see @{Logic.AddCallback} for details) with:</li>
-- <ul>
--   <li>`CallbackPoint.PRE_LOOP` or `POST_LOOP` for gameplay animations</li>
--   <li>`CallbackPoint.PRE_FREEZE` or `POST_FREEZE` for freeze mode animations</li>
-- </ul></ul>
-- @tparam string|number key Unique identifier for this animation timer. Different keys create independent animations.
-- @tparam number|Vec2|Vec3|Rotation|Color length The maximum value (oscillates from 0 to this value).
-- @tparam number period Time in seconds for a complete cycle (0→length→0).
-- @treturn number|Vec2|Vec3|Rotation|Color|nil The ping-ponged value, or nil on error.
-- @usage
-- -- Simple number oscillation:
-- LevelFuncs.OnLoop = function()
--     local intensity = LuaUtil.PingPong("torch", 1.0, 2.0) -- Oscillates 0→1→0 every 2 seconds
--     torch:SetIntensity(intensity)
-- end
--
-- -- Multiple independent animations:
-- LevelFuncs.OnLoop = function()
--     local redIntensity = LuaUtil.PingPong("red", 255, 1.0)
--     local blueIntensity = LuaUtil.PingPong("blue", 255, 2.0)
--     light:SetColor(TEN.Color(redIntensity, 0, blueIntensity, 255))
-- end
--
-- -- Vec3 for platform movement:
-- local basePos = TEN.Vec3(1000, 500, 2000)
-- LevelFuncs.OnLoop = function()
--     local offset = LuaUtil.PingPong("platform", TEN.Vec3(0, 512, 0), 3.0)
--     platform:SetPosition(basePos + offset)
-- end
--
-- -- Rotation for door swing (0-90 degrees on Y axis):
-- LevelFuncs.OnLoop = function()
--     local rot = LuaUtil.PingPong("door", TEN.Rotation(0, 90, 0), 4.0)
--     door:SetRotation(rot)
-- end
--
-- -- Color for pulsing alpha:
-- LevelFuncs.OnLoop = function()
--     local color = LuaUtil.PingPong("sprite_alpha", TEN.Color(255, 255, 255, 255), 1.5)
--     sprite:SetColor(color)
-- end
--
-- -- Rotation for full 360° spin:
-- LevelFuncs.OnLoop = function()
--     local rot = LuaUtil.PingPong("spinner", TEN.Rotation(0, 360, 0), 5.0)
--     object:SetRotation(rot)
-- end
LuaUtil.PingPong = function(key, length, period)
    -- Validate key parameter
    if not (Type.IsString(key) or Type.IsNumber(key)) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPong: key must be a string or number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Type checking for length
    local isNumber = Type.IsNumber(length)
    local isVec2 = Type.IsVec2(length)
    local isVec3 = Type.IsVec3(length)
    local isRotation = Type.IsRotation(length)
    local isColor = Type.IsColor(length)

    if not (isNumber or isVec2 or isVec3 or isRotation or isColor) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPong: length must be a number, Vec2, Vec3, Rotation, or Color.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Validate period parameter
    if not Type.IsNumber(period) or period <= 0 then
        TEN.Util.PrintLog("Error in LuaUtil.PingPong: period must be a positive number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Initialize timer storage if not exists
    if not LevelVars.Engine.LuaUtil.PingPongTimers then
        LevelVars.Engine.LuaUtil.PingPongTimers = {}
    end

    -- Calculate frames per cycle
    local framesPerCycle = LuaUtil.Round(period, 1) * LevelVars.Engine.LuaUtil.FPS

    -- Initialize or update timer for this key
    if not LevelVars.Engine.LuaUtil.PingPongTimers[key] then
        LevelVars.Engine.LuaUtil.PingPongTimers[key] = 0
    end

    -- Get current timer and increment
    local timer = LevelVars.Engine.LuaUtil.PingPongTimers[key]
    
    -- Keep timer in reasonable range by using modulo
    -- Timer cycles from 0 to framesPerCycle-1
    LevelVars.Engine.LuaUtil.PingPongTimers[key] = (timer + 1) % framesPerCycle

    -- Calculate scaled value based on type
    if isNumber then
        local scale = (length * 2) / framesPerCycle
        local t = timer * scale
        return LevelFuncs.Engine.LuaUtil.PingPongComponent(t, length)
    end

    if isVec2 then
        local scaleX = (length.x * 2) / framesPerCycle
        local scaleY = (length.y * 2) / framesPerCycle
        return TEN.Vec2(
            LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleX, length.x),
            LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleY, length.y)
        )
    end

    if isVec3 then
        local scaleX = (length.x * 2) / framesPerCycle
        local scaleY = (length.y * 2) / framesPerCycle
        local scaleZ = (length.z * 2) / framesPerCycle
        return TEN.Vec3(
            LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleX, length.x),
            LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleY, length.y),
            LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleZ, length.z)
        )
    end

    if isRotation then
        -- Rotation components range: 0-360 degrees
        local scaleX = (length.x * 2) / framesPerCycle
        local scaleY = (length.y * 2) / framesPerCycle
        local scaleZ = (length.z * 2) / framesPerCycle
        return TEN.Rotation(
            LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleX, length.x),
            LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleY, length.y),
            LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleZ, length.z)
        )
    end

    if isColor then
        -- Color components range: 0-255
        local scaleR = (length.r * 2) / framesPerCycle
        local scaleG = (length.g * 2) / framesPerCycle
        local scaleB = (length.b * 2) / framesPerCycle
        local scaleA = (length.a * 2) / framesPerCycle
        return TEN.Color(
            math.floor(LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleR, length.r)),
            math.floor(LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleG, length.g)),
            math.floor(LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleB, length.b)),
            math.floor(LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleA, length.a))
        )
    end

    return nil
end

--- Ping-pong animation that oscillates between min and max over a specified period.
-- Returns a value that oscillates smoothly between min and max.
-- Supports numbers, Vec2, Vec3, Rotation, and Color types.
-- @tparam string|number key Unique identifier for this animation timer. Different keys create independent animations.
-- @tparam number|Vec2|Vec3|Rotation|Color min The minimum value (oscillates from this value).
-- @tparam number|Vec2|Vec3|Rotation|Color max The maximum value (oscillates to this value, same type as min).
-- @tparam number period Time in seconds for a complete cycle (min→max→min).
-- @treturn number|Vec2|Vec3|Rotation|Color|nil The ping-ponged value, or nil on error.
-- @usage
-- -- Simple number oscillation between custom range:
-- LevelFuncs.OnLoop = function()
--     local intensity = LuaUtil.PingPongRange("torch", 0.3, 1.0, 2.0) -- Oscillates 0.3→1.0→0.3 every 2 seconds
--     torch:SetIntensity(intensity)
-- end
--
-- -- Multiple independent animations:
-- LevelFuncs.OnLoop = function()
--     local red = LuaUtil.PingPongRange("red", 100, 255, 1.0)
--     local blue = LuaUtil.PingPongRange("blue", 50, 200, 2.0)
--     light:SetColor(TEN.Color(red, 0, blue, 255))
-- end
--
-- -- Vec3 for platform movement between two positions:
-- local basePos = TEN.Vec3(1000, 500, 2000)
-- LevelFuncs.OnLoop = function()
--     local offset = LuaUtil.PingPongRange("platform", TEN.Vec3(0, -256, 0), TEN.Vec3(0, 256, 0), 3.0)
--     platform:SetPosition(basePos + offset)
-- end
--
-- -- Rotation for pendulum swing (-30° to +30° on Y axis):
-- LevelFuncs.OnLoop = function()
--     local rot = LuaUtil.PingPongRange("pendulum", TEN.Rotation(0, -30, 0), TEN.Rotation(0, 30, 0), 4.0)
--     pendulum:SetRotation(rot)
-- end
--
-- -- Color for pulsing between semi-transparent and fully opaque:
-- LevelFuncs.OnLoop = function()
--     local color = LuaUtil.PingPongRange("sprite_fade", 
--         TEN.Color(255, 255, 255, 128), 
--         TEN.Color(255, 255, 255, 255), 
--         1.5)
--     sprite:SetColor(color)
-- end
LuaUtil.PingPongRange = function(key, min, max, period)
    -- Validate key parameter
    if not (Type.IsString(key) or Type.IsNumber(key)) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPongRange: key must be a string or number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Type checking for min and max
    local isNumber = Type.IsNumber(min) and Type.IsNumber(max)
    local isVec2 = Type.IsVec2(min) and Type.IsVec2(max)
    local isVec3 = Type.IsVec3(min) and Type.IsVec3(max)
    local isRotation = Type.IsRotation(min) and Type.IsRotation(max)
    local isColor = Type.IsColor(min) and Type.IsColor(max)

    if not (isNumber or isVec2 or isVec3 or isRotation or isColor) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPongRange: min and max must be same type (number, Vec2, Vec3, Rotation, or Color).", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Validate period parameter
    if not Type.IsNumber(period) or period <= 0 then
        TEN.Util.PrintLog("Error in LuaUtil.PingPongRange: period must be a positive number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Initialize timer storage if not exists
    if not LevelVars.Engine.LuaUtil.PingPongRangeTimers then
        LevelVars.Engine.LuaUtil.PingPongRangeTimers = {}
    end

    -- Calculate frames per cycle
    local framesPerCycle = LuaUtil.Round(period, 1) * LevelVars.Engine.LuaUtil.FPS

    -- Initialize or update timer for this key
    if not LevelVars.Engine.LuaUtil.PingPongRangeTimers[key] then
        LevelVars.Engine.LuaUtil.PingPongRangeTimers[key] = 0
    end

    -- Get current timer and increment
    local timer = LevelVars.Engine.LuaUtil.PingPongRangeTimers[key]
    
    -- Keep timer in reasonable range by using modulo
    LevelVars.Engine.LuaUtil.PingPongRangeTimers[key] = (timer + 1) % framesPerCycle

    -- Calculate scaled value based on type
    if isNumber then
        local range = max - min
        local scale = (range * 2) / framesPerCycle
        local t = timer * scale
        return min + LevelFuncs.Engine.LuaUtil.PingPongComponent(t, range)
    end

    if isVec2 then
        local rangeX = max.x - min.x
        local rangeY = max.y - min.y
        local scaleX = (rangeX * 2) / framesPerCycle
        local scaleY = (rangeY * 2) / framesPerCycle
        return TEN.Vec2(
            min.x + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleX, rangeX),
            min.y + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleY, rangeY)
        )
    end

    if isVec3 then
        local rangeX = max.x - min.x
        local rangeY = max.y - min.y
        local rangeZ = max.z - min.z
        local scaleX = (rangeX * 2) / framesPerCycle
        local scaleY = (rangeY * 2) / framesPerCycle
        local scaleZ = (rangeZ * 2) / framesPerCycle
        return TEN.Vec3(
            min.x + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleX, rangeX),
            min.y + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleY, rangeY),
            min.z + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleZ, rangeZ)
        )
    end

    if isRotation then
        local rangeX = max.x - min.x
        local rangeY = max.y - min.y
        local rangeZ = max.z - min.z
        local scaleX = (rangeX * 2) / framesPerCycle
        local scaleY = (rangeY * 2) / framesPerCycle
        local scaleZ = (rangeZ * 2) / framesPerCycle
        return TEN.Rotation(
            min.x + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleX, rangeX),
            min.y + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleY, rangeY),
            min.z + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleZ, rangeZ)
        )
    end

    if isColor then
        local rangeR = max.r - min.r
        local rangeG = max.g - min.g
        local rangeB = max.b - min.b
        local rangeA = max.a - min.a
        local scaleR = (rangeR * 2) / framesPerCycle
        local scaleG = (rangeG * 2) / framesPerCycle
        local scaleB = (rangeB * 2) / framesPerCycle
        local scaleA = (rangeA * 2) / framesPerCycle
        return TEN.Color(
            math.floor(min.r + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleR, rangeR)),
            math.floor(min.g + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleG, rangeG)),
            math.floor(min.b + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleB, rangeB)),
            math.floor(min.a + LevelFuncs.Engine.LuaUtil.PingPongComponent(timer * scaleA, rangeA))
        )
    end

    return nil
end

--- Smoothly oscillate between min and max using Smoothstep interpolation.
-- Creates very smooth, natural-looking animations with gradual acceleration/deceleration.
-- Uses Hermite interpolation (Smoothstep) for smoother transitions than sine wave.
-- Supports numbers, Vec2, Vec3, Rotation, and Color types.
-- @tparam string|number key Unique identifier for this animation timer. Different keys create independent animations.
-- @tparam number|Vec2|Vec3|Rotation|Color min Minimum value.
-- @tparam number|Vec2|Vec3|Rotation|Color max Maximum value (same type as min).
-- @tparam number period Time in seconds for a complete cycle (min→max→min).
-- @treturn number|Vec2|Vec3|Rotation|Color|nil The smoothly oscillated value, or nil on error.
-- @usage
-- -- Simple number oscillation with smooth acceleration:
-- LevelFuncs.OnLoop = function()
--     local intensity = LuaUtil.PingPongSmooth("torch", 0.3, 1.0, 2.0) -- Smoothly oscillates every 2 seconds
--     torch:SetIntensity(intensity)
-- end
--
-- -- Platform movement with natural motion:
-- local basePos = TEN.Vec3(1000, 500, 2000)
-- LevelFuncs.OnLoop = function()
--     local offset = LuaUtil.PingPongSmooth("platform", TEN.Vec3(0, -256, 0), TEN.Vec3(0, 256, 0), 4.0)
--     platform:SetPosition(basePos + offset)
-- end
--
-- -- Door opening/closing with smooth motion:
-- LevelFuncs.OnLoop = function()
--     local rot = LuaUtil.PingPongSmooth("door", TEN.Rotation(0, 0, 0), TEN.Rotation(0, 90, 0), 3.0)
--     door:SetRotation(rot)
-- end
--
-- -- Color pulsing with gradual transitions:
-- LevelFuncs.OnLoop = function()
--     local color = LuaUtil.PingPongSmooth("glow", 
--         TEN.Color(255, 100, 0, 128), 
--         TEN.Color(255, 200, 0, 255), 
--         2.5)
--     sprite:SetColor(color)
-- end
--
-- -- Full 360° spin with smooth acceleration:
-- LevelFuncs.OnLoop = function()
--     local rot = LuaUtil.PingPongSmooth("spinner", TEN.Rotation(0, 0, 0), TEN.Rotation(0, 360, 0), 5.0)
--     object:SetRotation(rot)
-- end
LuaUtil.PingPongSmooth = function(key, min, max, period)
    -- Validate key parameter
    if not (Type.IsString(key) or Type.IsNumber(key)) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPongSmooth: key must be a string or number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Type checking for min and max
    local isNumber = Type.IsNumber(min) and Type.IsNumber(max)
    local isVec2 = Type.IsVec2(min) and Type.IsVec2(max)
    local isVec3 = Type.IsVec3(min) and Type.IsVec3(max)
    local isRotation = Type.IsRotation(min) and Type.IsRotation(max)
    local isColor = Type.IsColor(min) and Type.IsColor(max)

    if not (isNumber or isVec2 or isVec3 or isRotation or isColor) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPongSmooth: min and max must be same type (number, Vec2, Vec3, Rotation, or Color).", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Validate period parameter
    if not Type.IsNumber(period) or period <= 0 then
        TEN.Util.PrintLog("Error in LuaUtil.PingPongSmooth: period must be a positive number.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Initialize timer storage if not exists
    if not LevelVars.Engine.LuaUtil.PingPongSmoothTimers then
        LevelVars.Engine.LuaUtil.PingPongSmoothTimers = {}
    end

    -- Calculate frames per cycle
    local framesPerCycle = LuaUtil.Round(period, 1) * LevelVars.Engine.LuaUtil.FPS

    -- Initialize or update timer for this key
    if not LevelVars.Engine.LuaUtil.PingPongSmoothTimers[key] then
        LevelVars.Engine.LuaUtil.PingPongSmoothTimers[key] = 0
    end

    -- Get current timer and increment
    local timer = LevelVars.Engine.LuaUtil.PingPongSmoothTimers[key]
    
    -- Keep timer in reasonable range by using modulo
    LevelVars.Engine.LuaUtil.PingPongSmoothTimers[key] = (timer + 1) % framesPerCycle

    -- Normalize timer to 0-1 range
    local normalizedTime = timer / framesPerCycle

    -- Create ping-pong effect: 0→1→0
    -- First half (0 to 0.5): goes from 0 to 1
    -- Second half (0.5 to 1): goes from 1 to 0
    local t
    if normalizedTime <= 0.5 then
        -- First half: map 0-0.5 to 0-1
        t = normalizedTime * 2
    else
        -- Second half: map 0.5-1 to 1-0
        t = (1 - normalizedTime) * 2
    end

    -- Apply Smoothstep interpolation (Hermite polynomial: 3t² - 2t³)
    local smoothT = t * t * (3 - 2 * t)

    -- Interpolate based on type
    if isNumber then
        return min + (max - min) * smoothT
    elseif isVec2 then
        return TEN.Vec2(
            min.x + (max.x - min.x) * smoothT,
            min.y + (max.y - min.y) * smoothT
        )
    elseif isVec3 then
        return TEN.Vec3(
            min.x + (max.x - min.x) * smoothT,
            min.y + (max.y - min.y) * smoothT,
            min.z + (max.z - min.z) * smoothT
        )
    elseif isRotation then
        return TEN.Rotation(
            min.x + (max.x - min.x) * smoothT,
            min.y + (max.y - min.y) * smoothT,
            min.z + (max.z - min.z) * smoothT
        )
    elseif isColor then
        return TEN.Color(
            math.floor(min.r + (max.r - min.r) * smoothT),
            math.floor(min.g + (max.g - min.g) * smoothT),
            math.floor(min.b + (max.b - min.b) * smoothT),
            math.floor(min.a + (max.a - min.a) * smoothT)
        )
    end

    return nil
end

--- Interpolation functions.
-- Utilities for interpolating between values.
-- @section interpolation

--- Linearly interpolate between two values. Formula: result = a + (b - a) * t
-- @tparam float|Color|Rotation|Vec2|Vec3 a The start value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float|Color|Rotation|Vec2|Vec3 b The end value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float t The interpolation factor (0.0 to 1.0).
-- @treturn float|Color|Rotation|Vec2|Vec3|nil The interpolated value (number, Color, Rotation, Vec2, or Vec3). Returns nil on error.
-- @usage
-- -- Example with numbers:
-- local interpolated = LuaUtil.Lerp(0, 10, 0.5) -- Result: 5
--
-- -- Example with Colors:
-- local color1 = TEN.Color(255, 0, 0, 255)    -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)    -- Blue
-- local interpolatedColor = LuaUtil.Lerp(color1, color2, 0.5) -- Result: Purple (127, 0, 127, 255)
--
-- -- Example with Rotations:
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(90, 180, 45)
-- local interpolatedRot = LuaUtil.Lerp(rot1, rot2, 0.5)
--
-- -- Example with Vec2:
-- local vec1 = TEN.Vec2(100, 200)
-- local vec2 = TEN.Vec2(300, 400)
-- local interpolatedVec2 = LuaUtil.Lerp(vec1, vec2, 0.5) -- Result: Vec2(200, 300)
--
-- -- Example with Vec3:
-- local vec3_1 = TEN.Vec3(100, 200, 300)
-- local vec3_2 = TEN.Vec3(200, 400, 600)
-- local interpolatedVec3 = LuaUtil.Lerp(vec3_1, vec3_2, 0.5) -- Result: Vec3(150, 300, 450)
LuaUtil.Lerp = function(a, b, t)
    if not Type.IsNumber(t) then
        TEN.Util.PrintLog("Error in LuaUtil.Lerp: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    -- Clamp t to the range [0, 1]
    local clampedT = math.max(0, math.min(1, t))
    return LevelFuncs.Engine.LuaUtil.InterpolateValues(a, b, clampedT, "LuaUtil.Lerp")
end

--- Smoothly interpolate between two values using Hermite interpolation.
-- The function first normalizes the input value x to a 0-1 range using edge0 and edge1,
-- then applies a smooth S-curve (Hermite polynomial: 3t² - 2t³ or t²(3 - 2t)) for smoother transitions.
-- @tparam float|Color|Rotation|Vec2|Vec3 a Start value (returned when x <= edge0).
-- @tparam float|Color|Rotation|Vec2|Vec3 b End value (returned when x >= edge1).
-- @tparam float edge0 Lower edge: the value of x that maps to 0 (start of interpolation range).
-- @tparam float edge1 Upper edge: the value of x that maps to 1 (end of interpolation range).
-- @tparam float x The input value to be normalized and interpolated.
-- @treturn float|Color|Rotation|Vec2|Vec3|nil Smoothly interpolated result. Returns nil on error.
-- @usage
-- -- Example with numbers (normalized 0-1 range):
-- local smoothValue = LuaUtil.Smoothstep(0, 10, 0, 1, 0.5) -- t=0.5, result: 5
--
-- -- Example with numbers (custom range):
-- -- When x = 5, it's exactly halfway between edge0 (0) and edge1 (10)
-- local smoothValue = LuaUtil.Smoothstep(0, 10, 0, 10, 5) -- Result: 5
--
-- -- Interpolate from 100 to 200 when x goes from 0 to 100
-- local result = LuaUtil.Smoothstep(100, 200, 0, 100, 50) -- x=50 is halfway, result ≈ 150
--
-- -- Example with Colors (normalized 0-1 range):
-- local color1 = TEN.Color(255, 0, 0, 255)    -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)    -- Blue
-- local smoothColor = LuaUtil.Smoothstep(color1, color2, 0, 1, 0.5) -- Result: Purple (127, 0, 127, 255)
--
-- -- Example with Colors (custom range):
-- -- Smoothly transition from red to blue as x goes from 0 to 10
-- local smoothColor = LuaUtil.Smoothstep(color1, color2, 0, 10, 5) -- Result: Purple (127, 0, 127, 255)
--
-- -- Example with Rotations (normalized 0-1 range):
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(90, 180, 45)
-- local smoothRot = LuaUtil.Smoothstep(rot1, rot2, 0, 1, 0.5)
--
-- -- Example with Rotations (custom range):
-- -- Smoothly rotate as x progresses from 0 to 10
-- local smoothRot = LuaUtil.Smoothstep(rot1, rot2, 0, 10, 5)
--
-- -- Example with Vec2 (normalized 0-1 range):
-- local vec1 = TEN.Vec2(100, 200)
-- local vec2 = TEN.Vec2(300, 400)
-- local smoothVec2 = LuaUtil.Smoothstep(vec1, vec2, 0, 1, 0.5) -- Result: Vec2(200, 300)
--
-- -- Example with Vec2 (custom range):
-- -- Smoothly move position as x goes from 0 to 10
-- local smoothVec2 = LuaUtil.Smoothstep(vec1, vec2, 0, 10, 5) -- Result: Vec2(200, 300)
--
-- -- Example with Vec3 (normalized 0-1 range):
-- local vec3_1 = TEN.Vec3(100, 200, 300)
-- local vec3_2 = TEN.Vec3(200, 400, 600)
-- local smoothVec3 = LuaUtil.Smoothstep(vec3_1, vec3_2, 0, 1, 0.5) -- Result: Vec3(150, 300, 450)
--
-- -- Example with Vec3 (custom range):
-- -- Smoothly interpolate 3D position as x increases from 0 to 10
-- local smoothVec3 = LuaUtil.Smoothstep(vec3_1, vec3_2, 0, 10, 5) -- Result: Vec3(150, 300, 450)
LuaUtil.Smoothstep = function (a, b, edge0, edge1, x)
    if not (Type.IsNumber(edge0) and Type.IsNumber(edge1) and Type.IsNumber(x)) then
        TEN.Util.PrintLog("Error in LuaUtil.Smoothstep: edge0, edge1, and x must be numbers.", TEN.Util.LogLevel.ERROR)
        return nil
    end
    -- Scale, bias and saturate x to 0..1 range
    local t = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    -- Evaluate polynomial
    local clampedT = t * t * (3 - 2 * t)
    return LevelFuncs.Engine.LuaUtil.InterpolateValues(a, b, clampedT, "LuaUtil.Smoothstep")
end

--- Table functions.
-- Utilities for working with Lua tables.
-- @section table

--- Get the number of elements in a table (works for non-sequential tables).
-- @tparam table tbl The table to count.
-- @treturn int The number of elements.
-- @usage
-- local tbl = { apple = 1, banana = 2, cherry = 3 }
-- local count = LuaUtil.TableCount(tbl) -- Result: 3
LuaUtil.TableCount = function(tbl)
    if not Type.IsTable(tbl) then
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
--- @treturn bool True if the tables are equal, false otherwise.
--- @usage
--- local tblA = { a = 1, b = 2 }
--- local tblB = { a = 1, b = 2 }
--- local tblC = { a = 1, b = 3 }
--- local isEqualAB = LuaUtil.CompareTables(tblA, tblB) -- Result: true
--- local isEqualAC = LuaUtil.CompareTables(tblA, tblC) -- Result: false
LuaUtil.CompareTables = function (tbl1, tbl2)
    if not (Type.IsTable(tbl1) and Type.IsTable(tbl2)) then
        return false
    end

    for key, value in pairs(tbl1) do
        if tbl2[key] ~= value then
            return false
        end
    end

    for key, value in pairs(tbl2) do
        if tbl1[key] ~= value then
            return false
        end
    end

    return true
end

--- Deeply compare two tables for equality.
--- This function checks if both tables have the same keys and corresponding values, including nested tables.
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
    if not (Type.IsTable(tbl1) and Type.IsTable(tbl2)) then
        return false
    end

    for key, value in pairs(tbl1) do
        if Type.IsTable(value) and Type.IsTable(tbl2[key]) then
            if not LuaUtil.CompareTablesDeep(value, tbl2[key]) then
                return false
            end
        elseif tbl2[key] ~= value then
            return false
        end
    end

    for key, value in pairs(tbl2) do
        if Type.IsTable(value) and Type.IsTable(tbl1[key]) then
            if not LuaUtil.CompareTablesDeep(value, tbl1[key]) then
                return false
            end
        elseif tbl1[key] ~= value then
            return false
        end
    end

    return true
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
    if not Type.IsTable(tbl) then
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
    if not Type.IsTable(tbl) then
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
-- local readOnlyTable = LuaUtil.TableReadonly(originalTable)
LuaUtil.SetTableReadonly = function(tbl)
    if not Type.IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.TableReadonly: input is not a table.", TEN.Util.LogLevel.ERROR)
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