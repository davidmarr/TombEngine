--- Utility functions for various common tasks.<br>To use the functions within the scripts, the module must be called:
-- local Utl = require("Engine.Utility")
-- @luautil Utility

local Utility = {}
local Type= require("Engine.Type")

--- Convert a Vec2 in pixel coordinates to percent display coordinates.
-- @tparam Vec2 vec2Screen The Vec2 in pixel coordinates.
-- @treturn Vec2 The Vec2 in percent display coordinates.
-- @usage
-- local screenPos = TEN.Vec2(400, 300)
-- local percentPos = Utl.Vec2ScreenToPercent(screenPos)
Utility.Vec2ScreenToPercent = function (vec2Screen)
    if not Type.IsVec2(vec2Screen) then
        TEN.Util.PrintLog("Error in Utility.Vec2ScreenToPercent: input is not a Vec2.", TEN.Util.LogLevel.ERROR)
        return TEN.Vec2(0, 0)
    end
    return TEN.Vec2(TEN.Util.ScreenToPercent(vec2Screen.x, vec2Screen.y))
end

--- Convert a Vec2 in percent display coordinates to pixel coordinates.
-- @tparam Vec2 vec2Percent The Vec2 in percent display coordinates.
-- @treturn Vec2 The Vec2 in pixel coordinates.
-- @usage
-- local percentPos = TEN.Vec2(50, 50)
-- local screenPos = Utl.Vec2PercentToScreen(percentPos)
Utility.Vec2PercentToScreen = function (vec2Percent)
    if not Type.IsVec2(vec2Percent) then
        TEN.Util.PrintLog("Error in Utility.Vec2PercentToScreen: input is not a Vec2.", TEN.Util.LogLevel.ERROR)
        return TEN.Vec2(0, 0)
    end
    return TEN.Vec2(TEN.Util.PercentToScreen(vec2Percent.x, vec2Percent.y))
end

--- Check if a table contains a specific value.
-- @tparam tbl The table to check.
-- @tparam any val The value to search for.
-- @treturn bool True if the value is found, false otherwise.
-- @usage
-- -- Example whith associative table:
-- local tbl = { apple = 1, banana = 2, cherry = 3 }
-- local hasBanana = Utl.TableHasValue(tbl, "banana") -- Result: true
-- local hasGrape = Utl.TableHasValue(tbl, "grape") -- Result: false
--
-- -- Example whith array table:
-- local tbl = { "apple", "banana", "cherry" }
-- local hasBanana = Utl.TableHasValue(tbl, "banana") -- Result: true
-- local hasGrape = Utl.TableHasValue(tbl, "grape") -- Result: false
Utility.TableHasValue = function (tbl, val)
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
-- @tparam tbl The table to check.
-- @tparam any key The key to search for.
-- @treturn bool True if the key is found, false otherwise.
-- @usage
-- -- Example whith associative table:
-- local tbl = { apple = 1, banana = 2, cherry = 3 }
-- local hasBananaKey = Utl.TableHasKey(tbl, "banana") -- Result: true
-- local hasGrapeKey = Utl.TableHasKey(tbl, "grape") -- Result: false
--
-- -- Example whith array table:
-- local tbl = { "apple", "banana", "cherry" }
-- local hasBananaKey = Utl.TableHasKey(tbl, 2) -- Result: true
-- local hasGrapeKey = Utl.TableHasKey(tbl, 4) -- Result: false
Utility.TableHasKey = function (tbl, key)
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

--- Split a string into a table using a specified delimiter.
-- @tparam string inputStr The string to split.
-- @tparam string delimiter The delimiter to use for splitting.
-- @treturn tbl A table containing the split substrings.
-- @usage
-- local str = "apple,banana,cherry"
-- local result = Utl.SplitString(str, ",")
Utility.SplitString = function(inputStr, delimiter)
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
-- local smooth = Utl.Smoothstep(0, 10, 5) -- Result: 0.5
--
-- -- Example with Colors:
-- local color1 = TEN.Color(255, 0, 0, 255) -- Red
-- local color2 = TEN.Color(0, 0, 255, 255) -- Blue
-- local smoothColor = Utl.Smoothstep(color1, color2, 0.5) -- Result: Purple (127, 0, 127, 255)
--
-- -- Example with Rotations:
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(90, 180, 45)
-- local smoothRot = Utl.Smoothstep(rot1, rot2, 0.5)
--
-- -- Example with Vec2:
-- local vec1 = TEN.Vec2(0, 0)
-- local vec2 = TEN.Vec2(100, 100)
-- local smoothVec2 = Utl.Smoothstep(vec1, vec2, 0.5)
--
-- -- Example with Vec3:
-- local vec3_1 = TEN.Vec3(0, 0, 0)
-- local vec3_2 = TEN.Vec3(100, 100, 100)
-- local smoothVec3 = Utl.Smoothstep(vec3_1, vec3_2, 0.5)
Utility.Smoothstep = function (edge0, edge1, x)
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
-- local interpolated = Utl.Lerp(0, 10, 0.5) -- Result: 5
--
-- -- Example with Colors:
-- local color1 = TEN.Color(255, 0, 0, 255)    -- Red
-- local color2 = TEN.Color(0, 0, 255, 255)    -- Blue
-- local interpolatedColor = Utl.Lerp(color1, color2, 0.5) -- Result: Purple (127, 0, 127, 255)
--
-- -- Example with Rotations:
-- local rot1 = TEN.Rotation(0, 0, 0)
-- local rot2 = TEN.Rotation(90, 180, 45)
-- local interpolatedRot = Utl.Lerp(rot1, rot2, 0.5)
--
-- -- Example with Vec2:
-- local vec1 = TEN.Vec2(100, 200)
-- local vec2 = TEN.Vec2(300, 400)
-- local interpolatedVec2 = Utl.Lerp(vec1, vec2, 0.5) -- Result: Vec2(200, 300)
--
-- -- Example with Vec3:
-- local vec3_1 = TEN.Vec3(100, 200, 300)
-- local vec3_2 = TEN.Vec3(200, 400, 600)
-- local interpolatedVec3 = Utl.Lerp(vec3_1, vec3_2, 0.5) -- Result: Vec3(150, 300, 450)
Utility.Lerp = function(a, b, t)
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

return Utility