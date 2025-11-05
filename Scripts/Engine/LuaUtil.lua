-----<style>table.function_list td.name {min-width: 395px;}</style>
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

LuaUtil.CheckTimeFormat = function (timerFormat, errorText)
	errorText = errorText and Type.IsString(errorText) and errorText or false
	if Type.IsTable(timerFormat) then
		local validKeys = {hours = true, minutes = true, seconds = true, deciseconds = true}
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

--- Compare two values based on the specified operator.
-- @tparam mixed operand The first value to compare.
-- @tparam mixed reference The second value to compare against.
-- @tparam number operator The comparison operator<br>(0: equal, 1: not equal, 2: less than, 3: less than or equal, 4: greater than, 5: greater than or equal).
-- @treturn bool The result of the comparison.
LuaUtil.CompareValue = function(operand, reference, operator)
	if operator < 0 or operator > 5 then
		TEN.Util.PrintLog("Invalid operator for comparison", TEN.Util.LogLevel.ERROR)
		return false
	end
    operand = operand == true and 1 or operand == false and 0 or operand
    reference = reference == true and 1 or reference == false and 0 or reference
    return operators[operator + 1] and operators[operator + 1](operand, reference) or false
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
-- @treturn table A read-only version of the input table.
-- @usage
-- local readOnlyTable = LuaUtil.TableReadonly(originalTable)
LuaUtil.TableReadonly = function(tbl)
    if not Type.IsTable(tbl) then
        TEN.Util.PrintLog("Error in LuaUtil.TableReadonly: input is not a table.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    return setmetatable({}, {
        __index = tbl,
        __newindex = function(_, key, _)
            TEN.Util.PrintLog("Error, cannot modify '" .. tostring(key) .. "': table is read-only", TEN.Util.LogLevel.ERROR)
        end,
        __len = function() return #tbl end,
        __pairs = function() return pairs(tbl) end,
        __ipairs = function() return ipairs(tbl) end,
    })
end

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

--- Linearly interpolate between two values. Formula: result = a + (b - a) * t
-- @tparam float|Color|Rotation|Vec2|Vec3 a The start value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float|Color|Rotation|Vec2|Vec3 b The end value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float t The interpolation factor (0.0 to 1.0).
-- @treturn float|Color|Rotation|Vec2|Vec3 The interpolated value (number, Color, Rotation, Vec2, or Vec3).
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
	local error = false
	if not Type.IsNumber(t) then
		TEN.Util.PrintLog("Error in LuaUtil.Lerp: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
		error = true
	end
    -- Check if working with Colors
    local isColor = Type.IsColor(a) and Type.IsColor(b)
    -- Check if working with Rotations
    local isRotation = Type.IsRotation(a) and Type.IsRotation(b)
    -- Check if working with Vec2
    local isVec2 = Type.IsVec2(a) and Type.IsVec2(b)
    -- Check if working with Vec3
    local isVec3 = Type.IsVec3(a) and Type.IsVec3(b)

    if isColor then
        if error then
            return TEN.Color(0, 0, 0, 0)
        end
        local clampedT = math.max(0, math.min(1, t))
        -- Interpolate each color component
		return a:Lerp(b, clampedT)

    elseif isRotation then
        if error then
            return TEN.Rotation(0, 0, 0)
        end
        local clampedT = math.max(0, math.min(1, t))
        return a:Lerp(b, clampedT)

    elseif isVec2 then
        if error then
            return TEN.Vec2(0, 0)
        end
        local clampedT = math.max(0, math.min(1, t))
        return a:Lerp(b, clampedT)

    elseif isVec3 then
        if error then
            return TEN.Vec3(0, 0, 0)
        end
        local clampedT = math.max(0, math.min(1, t))
        return a:Lerp(b, clampedT)

    elseif Type.IsNumber(a) and Type.IsNumber(b) and Type.IsNumber(t) then
		local clampedT = math.max(0, math.min(1, t))
        return a + (b - a) * clampedT

    else
        TEN.Util.PrintLog("Error in Utility.Lerp: arguments must be either all numbers or a/b must be Colors/Rotations/Vec2/Vec3 with t as number.", TEN.Util.LogLevel.ERROR)
        return 0
    end
end

return LuaUtil