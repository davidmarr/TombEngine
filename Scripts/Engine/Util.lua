-----<style>table.function_list td.name {min-width: 395px;}</style>
--- Util - This module is a collection of help functions. To use the functions within the scripts, the module must be called:
--	local Utility = require("Engine.Util")
-- @luautil Utility

local Type= require("Engine.Type")
local Util = {}

Util.ShortenTENCalls = function()
	print("Util.ShortenTENCalls is deprecated; its functionality is now performed automatically by TombEngine.")
end

Util.CheckTimeFormat = function (timerFormat, errorText)
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
-- local formattedString = Utility.GenerateTimeFormattedString(time, format)
-- print(formattedString) -- Output: "01:30:45.5"
--
-- -- Example 2: Without hours
-- local format = { minutes = true, seconds = true, deciseconds = true }
-- local formattedString = Utility.GenerateTimeFormattedString(time, format)
-- print(formattedString) -- Output: "90:45.5"
Util.GenerateTimeFormattedString = function (time, format, error)
    error = Type.IsString(error) and error or false
    format = Util.CheckTimeFormat(format)

	if not Type.IsTime(time) then
		if error then
			TEN.Util.PrintLog(error, TEN.Util.LogLevel.ERROR)
		end
		return "Error"
	end
	if not format then
		if error then
			TEN.Util.PrintLog(error, TEN.Util.LogLevel.ERROR)
		end
		return "Error"
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
			return (index == 1) and tostring(deciseconds) or tostring(formattedString .. "." .. deciseconds)
    	end
    	return formattedString
	end
end

local operators = {
    function(a, b) return a == b end,
    function(a, b) return a ~= b end,
    function(a, b) return a < b end,
    function(a, b) return a <= b end,
    function(a, b) return a > b end,
    function(a, b) return a >= b end,
}
Util.CompareValue = function(operand, reference, operator)
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
-- local hasBanana = Utility.TableHasValue(tbl, "banana") -- Result: true
-- local hasGrape = Utility.TableHasValue(tbl, "grape") -- Result: false
--
-- -- Example with array table:
-- local tbl = { "apple", "banana", "cherry" }
-- local hasBanana = Utility.TableHasValue(tbl, "banana") -- Result: true
-- local hasGrape = Utility.TableHasValue(tbl, "grape") -- Result: false
Util.TableHasValue = function (tbl, val)
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
-- local hasBananaKey = Utility.TableHasKey(tbl, "banana") -- Result: true
-- local hasGrapeKey = Utility.TableHasKey(tbl, "grape") -- Result: false
--
-- -- Example with array table:
-- local tbl = { "apple", "banana", "cherry" }
-- local hasBananaKey = Utility.TableHasKey(tbl, 2) -- Result: true
-- local hasGrapeKey = Utility.TableHasKey(tbl, 4) -- Result: false
Util.TableHasKey = function (tbl, key)
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
-- local readOnlyTable = Utility.TableReadonly(originalTable)
Util.TableReadonly = function(tbl)
    if not Type.IsTable(tbl) then
        TEN.Util.PrintLog("Error in Utility.TableReadonly: input is not a table.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    return setmetatable({}, {
        __index = tbl,
        __newindex = function(_, key, _)
            TEN.Util.PrintLog("Error, cannot modify '" .. tostring(key) .. "': table is read-only", TEN.Util.LogLevel.ERROR)
        end,
        __len = function() return #tbl end,
        __pairs = function() return pairs(tbl) end,
        __ipairs = function() return ipairs(tbl) end
    })
end

--- Split a string into a table using a specified delimiter.
-- @tparam string inputStr The string to split.
-- @tparam string delimiter The delimiter to use for splitting.
-- @treturn tbl A table containing the split substrings.
-- @usage
-- local str = "apple,banana,cherry"
-- local result = Utility.SplitString(str, ",")
Util.SplitString = function(inputStr, delimiter)
    if not Type.IsString(inputStr) then
        TEN.Util.PrintLog("Error in Utility.SplitString: inputStr is not a string.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    if not Type.IsString(delimiter) then
        TEN.Util.PrintLog("Error in Utility.SplitString: delimiter is not a string.", TEN.Util.LogLevel.ERROR)
        return {}
    end

    local t = {}
    for str in string.gmatch(inputStr, "([^" .. delimiter .. "]+)") do
        table.insert(t, str)
    end
    return t
end

--- Smoothstep interpolation between two edges.
-- @tparam float|Color|Rotation|Vec2|Vec3 edge0 The lower edge (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float|Color|Rotation|Vec2|Vec3 edge1 The upper edge (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float x The interpolation factor.
-- @treturn float|Color|Rotation|Vec2|Vec3 The interpolated value (number, Color, Rotation, Vec2, or Vec3).
-- @usage
-- -- Example with numbers:
-- local smooth = Utility.Smoothstep(0, 10, 5) -- Result: 0.5
--
-- -- Example with Colors:
-- local color1 = TEN.Color(255, 0, 0, 255) -- Red
-- local color2 = TEN.Color(0, 0, 255, 255) -- Blue
-- local smoothColor = Utility.Smoothstep(color1, color2, 0.5) -- Result: Purple (127, 0, 127, 255)
--
-- -- Example with Rotations:
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(90, 180, 45)
-- local smoothRot = Utility.Smoothstep(rot1, rot2, 0.5)
--
-- -- Example with Vec2:
-- local vec1 = TEN.Vec2(0, 0)
-- local vec2 = TEN.Vec2(100, 100)
-- local smoothVec2 = Utility.Smoothstep(vec1, vec2, 0.5)
--
-- -- Example with Vec3:
-- local vec3_1 = TEN.Vec3(0, 0, 0)
-- local vec3_2 = TEN.Vec3(100, 100, 100)
-- local smoothVec3 = Utility.Smoothstep(vec3_1, vec3_2, 0.5)
Util.Smoothstep = function (edge0, edge1, x)
    -- Check if working with Colors
    local isColor = Type.IsColor(edge0) and Type.IsColor(edge1)
    -- Check if working with Rotations
    local isRotation = Type.IsRotation(edge0) and Type.IsRotation(edge1)
    -- Check if working with Vec2
    local isVec2 = Type.IsVec2(edge0) and Type.IsVec2(edge1)
    -- Check if working with Vec3
    local isVec3 = Type.IsVec3(edge0) and Type.IsVec3(edge1)
    
    if isColor then
        if not Type.IsNumber(x) then
            TEN.Util.PrintLog("Error in Utility.Smoothstep: interpolation factor x is not a number.", TEN.Util.LogLevel.ERROR)
            return TEN.Color(0, 0, 0, 0)
        end
        
        -- Scale and clamp x to 0..1 range
        local t = math.max(0, math.min(1, x))
        -- Evaluate polynomial
        t = t * t * (3 - 2 * t)
        
        -- Interpolate each color component
        local r = edge0.r + (edge1.r - edge0.r) * t
        local g = edge0.g + (edge1.g - edge0.g) * t
        local b = edge0.b + (edge1.b - edge0.b) * t
        local a = edge0.a + (edge1.a - edge0.a) * t
        
        return TEN.Color(
            math.floor(r + 0.5),
            math.floor(g + 0.5),
            math.floor(b + 0.5),
            math.floor(a + 0.5)
        )
    elseif isRotation then
        if not Type.IsNumber(x) then
            TEN.Util.PrintLog("Error in Utility.Smoothstep: interpolation factor x is not a number.", TEN.Util.LogLevel.ERROR)
            return TEN.Rotation(0, 0, 0)
        end
        
        -- Scale and clamp x to 0..1 range
        local t = math.max(0, math.min(1, x))
        -- Evaluate polynomial
        t = t * t * (3 - 2 * t)
        
        -- Use native Rotation:Lerp with smoothstep factor
        return edge0:Lerp(edge1, t)
    elseif isVec2 then
        if not Type.IsNumber(x) then
            TEN.Util.PrintLog("Error in Utility.Smoothstep: interpolation factor x is not a number.", TEN.Util.LogLevel.ERROR)
            return TEN.Vec2(0, 0)
        end
        
        -- Scale and clamp x to 0..1 range
        local t = math.max(0, math.min(1, x))
        -- Evaluate polynomial
        t = t * t * (3 - 2 * t)
        
        -- Use native Vec2:Lerp with smoothstep factor
        return edge0:Lerp(edge1, t)
    elseif isVec3 then
        if not Type.IsNumber(x) then
            TEN.Util.PrintLog("Error in Utility.Smoothstep: interpolation factor x is not a number.", TEN.Util.LogLevel.ERROR)
            return TEN.Vec3(0, 0, 0)
        end
        
        -- Scale and clamp x to 0..1 range
        local t = math.max(0, math.min(1, x))
        -- Evaluate polynomial
        t = t * t * (3 - 2 * t)
        
        -- Use native Vec3:Lerp with smoothstep factor
        return edge0:Lerp(edge1, t)
    elseif Type.IsNumber(edge0) and Type.IsNumber(edge1) and Type.IsNumber(x) then
        -- Original number interpolation
        -- Scale, and clamp x to 0..1 range
        local t = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
        -- Evaluate polynomial
        return t * t * (3 - 2 * t)
    else
        TEN.Util.PrintLog("Error in Utility.Smoothstep: arguments must be either all numbers or edge0/edge1 must be Colors/Rotations/Vec2/Vec3 with x as number.", TEN.Util.LogLevel.ERROR)
        return 0
    end
end

--- Linearly interpolate between two values.
-- @tparam float|Color|Rotation|Vec2|Vec3 a The start value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float|Color|Rotation|Vec2|Vec3 b The end value (number, Color, Rotation, Vec2, or Vec3).
-- @tparam float t The interpolation factor (0.0 to 1.0).
-- @treturn float|Color|Rotation|Vec2|Vec3 The interpolated value (number, Color, Rotation, Vec2, or Vec3).
-- @usage
-- -- Example with numbers:
-- local interpolated = Utility.Lerp(0, 10, 0.5) -- Result: 5
--
-- -- Example with Colors:
-- local color1 = TEN.Color(255, 0, 0, 255)    -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)    -- Blue
-- local interpolatedColor = Utility.Lerp(color1, color2, 0.5) -- Result: Purple (127, 0, 127, 255)
--
-- -- Example with Rotations:
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(90, 180, 45)
-- local interpolatedRot = Utility.Lerp(rot1, rot2, 0.5)
--
-- -- Example with Vec2:
-- local vec1 = TEN.Vec2(100, 200)
-- local vec2 = TEN.Vec2(300, 400)
-- local interpolatedVec2 = Utility.Lerp(vec1, vec2, 0.5) -- Result: Vec2(200, 300)
--
-- -- Example with Vec3:
-- local vec3_1 = TEN.Vec3(100, 200, 300)
-- local vec3_2 = TEN.Vec3(200, 400, 600)
-- local interpolatedVec3 = Utility.Lerp(vec3_1, vec3_2, 0.5) -- Result: Vec3(150, 300, 450)
Util.Lerp = function(a, b, t)
    -- Check if working with Colors
    local isColor = Type.IsColor(a) and Type.IsColor(b)
    -- Check if working with Rotations
    local isRotation = Type.IsRotation(a) and Type.IsRotation(b)
    -- Check if working with Vec2
    local isVec2 = Type.IsVec2(a) and Type.IsVec2(b)
    -- Check if working with Vec3
    local isVec3 = Type.IsVec3(a) and Type.IsVec3(b)
    
    if isColor then
        if not Type.IsNumber(t) then
            TEN.Util.PrintLog("Error in Utility.Lerp: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
            return TEN.Color(0, 0, 0, 0)
        end
        
        -- Clamp t to 0..1 range
        local clampedT = math.max(0, math.min(1, t))
        
        -- Interpolate each color component
        local r = a.r + (b.r - a.r) * clampedT
        local g = a.g + (b.g - a.g) * clampedT
        local bComp = a.b + (b.b - a.b) * clampedT
        local alpha = a.a + (b.a - a.a) * clampedT
        
        return TEN.Color(
            math.floor(r + 0.5),
            math.floor(g + 0.5),
            math.floor(bComp + 0.5),
            math.floor(alpha + 0.5)
        )
    elseif isRotation then
        if not Type.IsNumber(t) then
            TEN.Util.PrintLog("Error in Utility.Lerp: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
            return TEN.Rotation(0, 0, 0)
        end
        
        -- Clamp t to 0..1 range
        local clampedT = math.max(0, math.min(1, t))
        
        -- Use native Rotation:Lerp method
        return a:Lerp(b, clampedT)
    elseif isVec2 then
        if not Type.IsNumber(t) then
            TEN.Util.PrintLog("Error in Utility.Lerp: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
            return TEN.Vec2(0, 0)
        end
        
        -- Clamp t to 0..1 range
        local clampedT = math.max(0, math.min(1, t))
        
        -- Use native Vec2:Lerp method
        return a:Lerp(b, clampedT)
    elseif isVec3 then
        if not Type.IsNumber(t) then
            TEN.Util.PrintLog("Error in Utility.Lerp: interpolation factor t is not a number.", TEN.Util.LogLevel.ERROR)
            return TEN.Vec3(0, 0, 0)
        end
        
        -- Clamp t to 0..1 range
        local clampedT = math.max(0, math.min(1, t))
        
        -- Use native Vec3:Lerp method
        return a:Lerp(b, clampedT)
    elseif Type.IsNumber(a) and Type.IsNumber(b) and Type.IsNumber(t) then
        -- Original number interpolation
        return a + (b - a) * t
    else
        TEN.Util.PrintLog("Error in Utility.Lerp: arguments must be either all numbers or a/b must be Colors/Rotations/Vec2/Vec3 with t as number.", TEN.Util.LogLevel.ERROR)
        return 0
    end
end

return Util