-----<style>table.function_list td.name {min-width: 370px;}</style>
--- Lua support functions to simplify operations in scripts. To use, include the module with:
---	local LuaUtil = require("Engine.LuaUtil")
--- @luautil LuaUtil

local Type= require("Engine.Type")
local LuaUtil = {}
local operators = {
    function(a, b) return a == b end,
    function(a, b) return a ~= b end,
    function(a, b) return a < b end,
    function(a, b) return a <= b end,
    function(a, b) return a > b end,
    function(a, b) return a >= b end,
}
local validKeys = {hours = true, minutes = true, seconds = true, deciseconds = true}

-- Helper function for ping-pong calculation on a single component
local function pingPongComponent(t, length)
    if length == 0 then return 0 end
    t = t % (length * 2)
    return t > length and (length * 2 - t) or t
end

-- Helper function for type checking and interpolation
local function interpolateValues(a, b, clampedT, functionName)
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
local function hueToRgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
    return p
end

-- Helper function to validate time format
LuaUtil.CheckTimeFormat = function (timerFormat, errorText)
	errorText = errorText and Type.IsString(errorText) and errorText or false
	if Type.IsTable(timerFormat) then
		for k, v in pairs(timerFormat) do
			if not validKeys[k] or type(v) ~= "boolean" then
				if errorText then
					TEN.Util.PrintLog(errorText, TEN.Util.LogLevel.WARNING)
				end
				return false
			end
		end
		return timerFormat
	elseif Type.IsBoolean(timerFormat) then
		return timerFormat and {seconds = true} or timerFormat
	end
    if errorText then
        TEN.Util.PrintLog(errorText, TEN.Util.LogLevel.WARNING)
    end
	return false
end

--- Generate a formatted time string based on the provided time and format.
-- @tparam Time time The Time object containing hours, minutes, seconds, and centiseconds
-- @tparam table format A table specifying which time components to include (hours, minutes, seconds, deciseconds).
-- @tparam[opt=false] string|bool error An optional error message to log if the format is invalid.
-- @treturn string The formatted time string.
-- @usage
-- -- Example 1: Basic usage
-- local time = TEN.Time({01, 30, 45, 50})
-- local format = { hours = true, minutes = true, seconds = true, deciseconds = true }
-- local formattedString = LuaUtil.GenerateTimeFormattedString(time, format)
-- print(formattedString) -- Output: "01:30:45.5"
--
-- -- Example 2: Without hours
-- local format = { minutes = true, seconds = true, deciseconds = true }
-- local formattedString = LuaUtil.GenerateTimeFormattedString(time, format)
-- print(formattedString) -- Output: "90:45.5"
LuaUtil.GenerateTimeFormattedString = function (time, format, error)
    error = Type.IsString(error) and error or false
    format = LuaUtil.CheckTimeFormat(format)

	if not Type.IsTime(time) then
		if error then
			TEN.Util.PrintLog(error, TEN.Util.LogLevel.ERROR)
		end
		return "00:00:00.0"
	end
	if not format then
		if error then
			TEN.Util.PrintLog(error, TEN.Util.LogLevel.ERROR)
		end
		return "00:00:00.0"
	else
		local result = {}
		local index = 1
		if format.hours then
        	result[index] = string.format("%02d", time.h)
        	index = index + 1
    	end
    	if format.minutes then
        	result[index] = string.format("%02d", format.hours and time.m or (time.m + (60 * time.h)))
        	index = index + 1
    	end
    	if format.seconds then
        	result[index] = string.format("%02d", format.minutes and time.s or (time.s + (60 * time.m)))
        	index = index + 1
    	end
		local formattedString = table.concat(result, ":")

    	if format.deciseconds then
        	local deciseconds = math.floor(time.c / 10)
			return (index == 1) and tostring(deciseconds) or formattedString .. "." .. deciseconds
    	end
    	return formattedString
	end
end

--- Comparison and validation functions.
-- Utilities for comparing values and checking ranges.
-- @section comparison

--- Compare two values based on the specified operator.
-- @tparam mixed operand The first value to compare.
-- @tparam mixed reference The second value to compare against.
-- @tparam number operator The comparison operator<br>(0: equal, 1: not equal, 2: less than, 3: less than or equal, 4: greater than, 5: greater than or equal).
-- @treturn bool The result of the comparison.
LuaUtil.CompareValues = function(operand, reference, operator)
	if operator < 0 or operator > 5 then
		TEN.Util.PrintLog("Invalid operator for comparison", TEN.Util.LogLevel.ERROR)
		return false
	end
    operand = operand == true and 1 or operand == false and 0 or operand
    reference = reference == true and 1 or reference == false and 0 or reference
    return operators[operator + 1] and operators[operator + 1](operand, reference) or false
end

--- Check if a value is within a range (inclusive).
-- @tparam number value The value to check.
-- @tparam number min Minimum value.
-- @tparam number max Maximum value.
-- @treturn bool True if value is within range.
LuaUtil.InRange = function(value, min, max)
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
-- @treturn tbl A table containing the split substrings.
-- @usage
-- local str = "apple,banana,cherry"
-- local result = LuaUtil.SplitString(str, ",")
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
LuaUtil.SecondsToFrames = function(seconds, fps)
    fps = fps or 30
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
LuaUtil.FramesToSeconds = function(frames, fps)
    fps = fps or 30
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

        r = hueToRgb(p, q, hNorm + 1/3)
        g = hueToRgb(p, q, hNorm)
        b = hueToRgb(p, q, hNorm - 1/3)
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
LuaUtil.Clamp = function(value, min, max)
    if not (Type.IsNumber(value) and Type.IsNumber(min) and Type.IsNumber(max)) then
        TEN.Util.PrintLog("Error in LuaUtil.Clamp: parameters must be numbers.", TEN.Util.LogLevel.ERROR)
        return value
    end
    return math.max(min, math.min(max, value))
end

--- Ping-pong a value between 0 and length (useful for animations).
-- Supports numbers, Vec2, Vec3, Rotation, and Color types.
-- Both parameters must be of the same type.
-- @tparam number|Vec2|Vec3|Rotation|Color t The value to ping-pong.
-- @tparam number|Vec2|Vec3|Rotation|Color length The maximum value (same type as t).
-- @treturn number|Vec2|Vec3|Rotation|Color|nil The ping-ponged value, or nil on error.
-- @usage
-- -- Example with number:
-- local timer = 150
-- local value = LuaUtil.PingPong(timer, 100) -- Result: 50 (goes 0->100->50)
--
-- -- Example with Vec2 for 2D position oscillation:
-- local timer = 0
-- function OnLoop()
--     timer = timer + 1
--     local maxOffset = TEN.Vec2(100, 50)
--     local offset = LuaUtil.PingPong(TEN.Vec2(timer, timer), maxOffset)
--     -- offset.x oscillates between 0-100, offset.y between 0-50
--     myObject:SetPosition2D(offset)
-- end
--
-- -- Example with Vec3 for 3D position oscillation:
-- local timer = 0
-- function OnLoop()
--     timer = timer + 1
--     local maxOffset = TEN.Vec3(50, 100, 75)
--     local offset = LuaUtil.PingPong(
--         TEN.Vec3(timer, timer * 0.5, timer * 2),
--         maxOffset
--     )
--     -- Each component oscillates independently
--     myObject:SetPosition(originalPos + offset)
-- end
--
-- -- Example with Rotation for oscillating rotation:
-- local rotTimer = 0
-- function OnLoop()
--     rotTimer = rotTimer + 2
--     local maxRot = TEN.Rotation(30, 45, 15)
--     local rot = LuaUtil.PingPong(
--         TEN.Rotation(rotTimer, rotTimer * 0.5, rotTimer),
--         maxRot
--     )
--     -- Rotates back and forth on each axis
--     myObject:SetRotation(rot)
-- end
--
-- -- Example with Color for pulsing effect:
-- local colorTimer = 0
-- function OnLoop()
--     colorTimer = colorTimer + 5
--     local maxColor = TEN.Color(255, 128, 64, 200)
--     local color = LuaUtil.PingPong(
--         TEN.Color(colorTimer, colorTimer, colorTimer, 255),
--         maxColor
--     )
--     -- Each color component pulses independently
--     SetObjectColor(myObject, color)
-- end
--
-- -- Example combining with Lerp for smooth color transition:
-- local timer = 0
-- function OnLoop()
--     timer = timer + 1
--     local t = LuaUtil.PingPong(timer, 100) / 100 -- Normalize to 0-1
--     local color = LuaUtil.Lerp(
--         TEN.Color(255, 0, 0, 255),   -- Red
--         TEN.Color(0, 0, 255, 255),   -- Blue
--         t
--     )
--     SetObjectColor(myObject, color)
-- end
LuaUtil.PingPong = function(t, length)
    -- Type checking
    local isNumber = Type.IsNumber(t) and Type.IsNumber(length)
    local isVec2 = Type.IsVec2(t) and Type.IsVec2(length)
    local isVec3 = Type.IsVec3(t) and Type.IsVec3(length)
    local isRotation = Type.IsRotation(t) and Type.IsRotation(length)
    local isColor = Type.IsColor(t) and Type.IsColor(length)

    if not (isNumber or isVec2 or isVec3 or isRotation or isColor) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPong: parameters must be both numbers, Vec2, Vec3, Rotation, or Color.", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Handle number case
    if isNumber then
        return pingPongComponent(t, length)
    end

    -- Handle Vec2 case
    if isVec2 then
        return TEN.Vec2(
            pingPongComponent(t.x, length.x),
            pingPongComponent(t.y, length.y)
        )
    end

    -- Handle Vec3 case
    if isVec3 then
        return TEN.Vec3(
            pingPongComponent(t.x, length.x),
            pingPongComponent(t.y, length.y),
            pingPongComponent(t.z, length.z)
        )
    end

    -- Handle Rotation case
    if isRotation then
        return TEN.Rotation(
            pingPongComponent(t.x, length.x),
            pingPongComponent(t.y, length.y),
            pingPongComponent(t.z, length.z)
        )
    end

    -- Handle Color case
    if isColor then
        return TEN.Color(
            math.floor(pingPongComponent(t.r, length.r)),
            math.floor(pingPongComponent(t.g, length.g)),
            math.floor(pingPongComponent(t.b, length.b)),
            math.floor(pingPongComponent(t.a, length.a))
        )
    end

    return nil
end

--- Ping-pong a value between min and max (useful for animations with custom range).
-- Supports numbers, Vec2, Vec3, Rotation, and Color types.
-- All parameters must be of the same type.
-- @tparam number|Vec2|Vec3|Rotation|Color t The value to ping-pong.
-- @tparam number|Vec2|Vec3|Rotation|Color min The minimum value (same type as t).
-- @tparam number|Vec2|Vec3|Rotation|Color max The maximum value (same type as t).
-- @treturn number|Vec2|Vec3|Rotation|Color|nil The ping-ponged value, or nil on error.
-- @usage
-- -- Example with number for light intensity:
-- local timer = 0
-- function OnLoop()
--     timer = timer + 1
--     local intensity = LuaUtil.PingPongRange(timer, 0.3, 1.0) -- Oscillates between 0.3 and 1.0
--     myLight:SetIntensity(intensity)
-- end
--
-- -- Example with Vec3 for platform movement:
-- local timer = 0
-- local basePos = TEN.Vec3(1000, 500, 2000)
-- function OnLoop()
--     timer = timer + 2
--     local minPos = TEN.Vec3(-512, 0, -256)
--     local maxPos = TEN.Vec3(512, 200, 256)
--     local offset = LuaUtil.PingPongRange(
--         TEN.Vec3(timer, timer, timer),
--         minPos,
--         maxPos
--     )
--     platform:SetPosition(basePos + offset)
-- end
--
-- -- Example with Rotation for door swing:
-- local rotTimer = 0
-- function OnLoop()
--     rotTimer = rotTimer + 1
--     local minRot = TEN.Rotation(0, 0, 0)
--     local maxRot = TEN.Rotation(0, 90, 0) -- 90 degrees on Y axis
--     local rot = LuaUtil.PingPongRange(
--         TEN.Rotation(0, rotTimer, 0),
--         minRot,
--         maxRot
--     )
--     door:SetRotation(rot)
-- end
--
-- -- Example with Color for pulsing alpha:
-- local colorTimer = 0
-- function OnLoop()
--     colorTimer = colorTimer + 5
--     local minColor = TEN.Color(255, 100, 50, 128) -- Semi-transparent
--     local maxColor = TEN.Color(255, 100, 50, 255) -- Fully opaque
--     local color = LuaUtil.PingPongRange(
--         TEN.Color(255, 100, 50, colorTimer),
--         minColor,
--         maxColor
--     )
--     sprite:SetColor(color)
-- end
LuaUtil.PingPongRange = function(t, min, max)
    -- Type checking
    local isNumber = Type.IsNumber(t) and Type.IsNumber(min) and Type.IsNumber(max)
    local isVec2 = Type.IsVec2(t) and Type.IsVec2(min) and Type.IsVec2(max)
    local isVec3 = Type.IsVec3(t) and Type.IsVec3(min) and Type.IsVec3(max)
    local isRotation = Type.IsRotation(t) and Type.IsRotation(min) and Type.IsRotation(max)
    local isColor = Type.IsColor(t) and Type.IsColor(min) and Type.IsColor(max)

    if not (isNumber or isVec2 or isVec3 or isRotation or isColor) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPongRange: parameters must be same type (number, Vec2, Vec3, Rotation, or Color).", TEN.Util.LogLevel.ERROR)
        return nil
    end

    -- Handle number case
    if isNumber then
        local range = max - min
        return min + pingPongComponent(t, range)
    end

    -- Calculate range for vector types
    local range = isVec2 and TEN.Vec2(max.x - min.x, max.y - min.y)
                or isVec3 and TEN.Vec3(max.x - min.x, max.y - min.y, max.z - min.z)
                or isRotation and TEN.Rotation(max.x - min.x, max.y - min.y, max.z - min.z)
                or TEN.Color(max.r - min.r, max.g - min.g, max.b - min.b, max.a - min.a)
    
    -- Apply ping-pong on range
    local result = LuaUtil.PingPong(t, range)
    
    -- Add minimum offset to result
    if isVec2 then
        return TEN.Vec2(result.x + min.x, result.y + min.y)
    elseif isVec3 then
        return TEN.Vec3(result.x + min.x, result.y + min.y, result.z + min.z)
    elseif isRotation then
        return TEN.Rotation(result.x + min.x, result.y + min.y, result.z + min.z)
    else  -- Color
        return TEN.Color(
            math.floor(result.r + min.r),
            math.floor(result.g + min.g),
            math.floor(result.b + min.b),
            math.floor(result.a + min.a)
        )
    end
end

--- Smoothly oscillate between min and max using sinusoidal interpolation.
-- Creates smooth, natural-looking animations using a sine wave pattern.
-- Supports numbers, Vec2, Vec3, Rotation, and Color types.
-- @tparam number t Time value (in frames or seconds).
-- @tparam number|Vec2|Vec3|Rotation|Color min Minimum value.
-- @tparam number|Vec2|Vec3|Rotation|Color max Maximum value (same type as min).
-- @tparam[opt=1.0] number frequency Oscillation frequency in Hz (cycles per time unit).
-- @treturn number|Vec2|Vec3|Rotation|Color|nil The smoothly oscillated value, or nil on error.
-- @usage
-- -- Example with number for flickering torch light (8 Hz):
-- local timer = 0
-- function OnLoop()
--     timer = timer + 0.033 -- ~30 FPS
--     local intensity = LuaUtil.PingPongSmooth(timer, 0.6, 1.0, 8.0)
--     torch:SetIntensity(intensity)
-- end
--
-- -- Example with Vec3 for floating platform (0.5 Hz = 2 seconds per cycle):
-- local timer = 0
-- local basePos = TEN.Vec3(1000, 500, 2000)
-- function OnLoop()
--     timer = timer + 0.033
--     local minOffset = TEN.Vec3(0, -512, 0)
--     local maxOffset = TEN.Vec3(0, 512, 0)
--     local offset = LuaUtil.PingPongSmooth(timer, minOffset, maxOffset, 0.5)
--     platform:SetPosition(basePos + offset)
-- end
--
-- -- Example with Rotation for pendulum swing (0.3 Hz):
-- local timer = 0
-- function OnLoop()
--     timer = timer + 0.033
--     local minRot = TEN.Rotation(0, -30, 0)
--     local maxRot = TEN.Rotation(0, 30, 0)
--     local rot = LuaUtil.PingPongSmooth(timer, minRot, maxRot, 0.3)
--     pendulum:SetRotation(rot)
-- end
--
-- -- Example with Color for rainbow effect (0.2 Hz = 5 seconds per cycle):
-- local timer = 0
-- function OnLoop()
--     timer = timer + 0.033
--     local color1 = TEN.Color(255, 0, 0, 255)   -- Red
--     local color2 = TEN.Color(0, 0, 255, 255)   -- Blue
--     local color = LuaUtil.PingPongSmooth(timer, color1, color2, 0.2)
--     sprite:SetColor(color)
-- end
--
-- -- Example combining with HSL for color cycling:
-- local hueTimer = 0
-- function OnLoop()
--     hueTimer = hueTimer + 0.033
--     local hue = LuaUtil.PingPongSmooth(hueTimer, 0, 360, 0.2)
--     local color = LuaUtil.HSLtoColor(hue, 1.0, 0.5, 1.0)
--     light:SetColor(color)
-- end
--
-- -- Example for character breathing animation (0.3 Hz):
-- local breathTimer = 0
-- local baseScale = 1.0
-- function OnLoop()
--     breathTimer = breathTimer + 0.033
--     local scale = LuaUtil.PingPongSmooth(breathTimer, 0.95, 1.05, 0.3)
--     character:SetScale(baseScale * scale)
-- end
LuaUtil.PingPongSmooth = function(t, min, max, frequency)
    frequency = frequency or 1.0
    
    -- Validate numeric parameters
    if not Type.IsNumber(t) or not Type.IsNumber(frequency) then
        TEN.Util.PrintLog("Error in LuaUtil.PingPongSmooth: t and frequency must be numbers.", TEN.Util.LogLevel.ERROR)
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

    -- Calculate normalized interpolation factor using sine wave
    -- sin(t * frequency * 2π) produces a wave that oscillates between -1 and 1
    -- We convert it to range [0, 1] by adding 1 and dividing by 2
    local sinValue = math.sin(t * frequency * math.pi * 2)
    local normalizedT = (sinValue + 1) / 2

    -- Use Lerp to interpolate smoothly between min and max
    return LuaUtil.Lerp(min, max, normalizedT)
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
    return interpolateValues(a, b, clampedT, "LuaUtil.Lerp")
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
    return interpolateValues(a, b, clampedT, "LuaUtil.Smoothstep")
end

--- Table functions.
-- Utilities for working with Lua tables.
-- @section table

--- Get the number of elements in a table (works for non-sequential tables).
-- @tparam table tbl The table to count.
-- @treturn int The number of elements.
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
-- local hasBanana = LuaUtil.TableHasValue(tbl, "banana") -- Result: true
-- local hasGrape = Utility.TableHasValue(tbl, "grape") -- Result: false
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