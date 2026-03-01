-- ldignore

-- Internal functions specific to modules. These are not intended for end users. These functions are not documented in the API reference.

local Util = {}
local Type = require("Engine.Type")
-- For backward compatibility, deciseconds is still accepted, but centiseconds is preferred. Both keys will work, but if both are present, centiseconds will be used.
local VALID_KEYS = { hours = true, minutes = true, seconds = true, deciseconds = true, centiseconds = true }
local LogMessage  = TEN.Util.PrintLog
local logLevelWarning = TEN.Util.LogLevel.WARNING
local IsString = Type.IsString
local IsTable = Type.IsTable
local IsBoolean = Type.IsBoolean

Util.ShortenTENCalls = function()
	print("Util.ShortenTENCalls is deprecated; its functionality is now performed automatically by TombEngine.")
end

local function pad2(n)
    return (n < 10) and ("0" .. n) or tostring(n)
end

-- Check if the time format is correct.
-- Used by: Timer.lua
Util.CheckTimeFormat = function(timerFormat, errorText)
	errorText = errorText and IsString(errorText) and errorText or false
	if IsTable(timerFormat) then
		for k, v in pairs(timerFormat) do
			if not VALID_KEYS[k] or not IsBoolean(v) then
				if errorText then
					LogMessage(errorText, logLevelWarning)
				end
				return false
			end
		end
		return timerFormat
	elseif IsBoolean(timerFormat) then
		return timerFormat and { seconds = true } or timerFormat
	end
	if errorText then
		LogMessage(errorText, logLevelWarning)
	end
	return false
end

-- Generate a formatted string from a time.
-- Used by: Timer.lua
Util.GenerateTimeFormattedString = function(time, timerFormat)
    if not timerFormat then
        return ""
    end

    local h = time.h
	local m = time.m
    local out = ""

    if timerFormat.hours then
        out = pad2(h)
    end

    if timerFormat.minutes then
		local agretedMinutes = timerFormat.hours and m or (m + (60 * h))
		out = (out == "" and pad2(agretedMinutes)) or (out .. ":" .. pad2(agretedMinutes))
	end

    if timerFormat.seconds then
		local aggregatedSeconds = time.s
		if not timerFormat.minutes then
			aggregatedSeconds = aggregatedSeconds + (60 * m)
			if not timerFormat.hours then
				aggregatedSeconds = aggregatedSeconds + (3600 * h)
			end
		end
        out = (out == "" and pad2(aggregatedSeconds)) or (out .. ":" .. pad2(aggregatedSeconds))
    end

	-- Check if timerFormat.deciseconds exists for backward compatibility, but prefer timerFormat.centiseconds if it exists
	-- The visual difference with the previous version is 2 decimal places instead of 1.
	-- Before: 5.0
	-- After: 5.00
	if timerFormat.centiseconds or timerFormat.deciseconds then
        out = (out == "" and pad2(time.c)) or (out .. "." .. pad2(time.c))
    end

    return out
end

-- Check if table has particular value.
-- Used by: Timer.lua
Util.TableHasValue = function(tbl, val)
	for _, value in pairs(tbl) do
		if value == val then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------

local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs
local sin = math.sin
local cos = math.cos
local asin = math.asin
local atan = math.atan
local deg = math.deg
local sqrt = math.sqrt
local rad = math.rad
local pi = math.pi
local Color = TEN.Color
local logLevelEnums = TEN.Util.LogLevel
local logLevelError  = logLevelEnums.ERROR

local IsNumber = Type.IsNumber
local IsVec2 = Type.IsVec2
local IsVec3 = Type.IsVec3
local IsColor = Type.IsColor
local IsTime = Type.IsTime
local IsRotation = Type.IsRotation
local IsEnumValue = Type.IsEnumValue


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

-- Support function to get the maximum positive integer index in a table.
-- Used by array-like operations that must work with sparse tables.
-- Used by: StringUtils.lua,
Util.GetMaxNumericIndex = function(tbl)
    local maxIndex = 0
    for key, _ in next, tbl do
        if type(key) == "number" and key > 0 and floor(key) == key and key > maxIndex then
            maxIndex = key
        end
    end
    return maxIndex
end

-- Support function for angle wrapping (used in interpolation)
-- Used by: MathUtils.lua
Util.WrapAngleRaw = function(angle, minVal, range)
    return angle - range * floor((angle - minVal) / range)
end



-- Support function for HSL to Color conversion (no type checking, used internally)
-- Takes h, s, l, a as separate parameters to avoid table allocation
-- Returns a Color object directly
Util.HSLtoColorRaw = function(h, s, l, a)
    local r, g, b
    a = a or 1  -- Default alpha to 1 if not provided

    if s == 0 then
        r, g, b = l, l, l  -- Achromatic (gray)
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        local hk = h / 360
        r = HueToRgb(p, q, hk + 1/3)
        g = HueToRgb(p, q, hk)
        b = HueToRgb(p, q, hk - 1/3)
    end

    -- Round to nearest integer and convert to 0-255 range
    return Color(
        floor(r * 255 + 0.5),
        floor(g * 255 + 0.5),
        floor(b * 255 + 0.5),
        floor(a * 255 + 0.5)
    )
end

-- Support function for Color to HSL conversion (no type checking, used internally)
-- Returns h, s, l as multiple values (no table allocation)
Util.ColorToHSLRaw = function(color)
    local r = color.r / 255
    local g = color.g / 255
    local b = color.b / 255

    local h = color:GetHue()

    local maxValue = max(r, g, b)
    local minValue = min(r, g, b)
    local l = (maxValue + minValue) / 2

    local s
    if maxValue == minValue then
        s = 0
    else
        local delta = maxValue - minValue
        s = l > 0.5 and delta / (2 - maxValue - minValue) or delta / (maxValue + minValue)
    end

    return h, s, l
end

-- Support function for Color to OKLch conversion (no type checking, used internally)
-- Returns L, C, h as multiple values (no table allocation)
Util.ColorToOKLchRaw = function(color)
    local r = SrgbToLinear(color.r / 255)
    local g = SrgbToLinear(color.g / 255)
    local b = SrgbToLinear(color.b / 255)

    local l_ = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m_ = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s_ = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    local l_cbrt = l_ >= 0 and l_ ^ (1/3) or -((-l_) ^ (1/3))
    local m_cbrt = m_ >= 0 and m_ ^ (1/3) or -((-m_) ^ (1/3))
    local s_cbrt = s_ >= 0 and s_ ^ (1/3) or -((-s_) ^ (1/3))

    local L = 0.2104542553 * l_cbrt + 0.7936177850 * m_cbrt - 0.0040720468 * s_cbrt
    local A = 1.9779984951 * l_cbrt - 2.4285922050 * m_cbrt + 0.4505937099 * s_cbrt
    local B = 0.0259040371 * l_cbrt + 0.7827717662 * m_cbrt - 0.8086757660 * s_cbrt

    local C = sqrt(A * A + B * B)
    local h = deg(atan(B, A))
    if h < 0 then
        h = h + 360
    end

    return L, C, h
end

-- Support function for OKLch to Color conversion (no type checking, used internally)
-- Takes L, C, h, a as separate parameters to avoid table allocation
-- Returns a Color object directly
Util.OKLchToColorRaw = function(L, C, h, a)

    -- Convert back to OKLab
    local hRad = rad(h)
    local A = C * cos(hRad)
    local B = C * sin(hRad)
    a = a or 1  -- Default alpha to 1 if not provided

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
    r = floor(r * 255 + 0.5)
    g = floor(g * 255 + 0.5)
    b = floor(b * 255 + 0.5)
    local alpha = floor(max(0, min(1, a)) * 255 + 0.5)

    return Color(r, g, b, alpha)
end

-- Helper function for type checking and interpolation
Util.InterpolateValues = function(a, b, clampedT, functionName)
    if IsNumber(a) then
        if not IsNumber(b) then
            LogMessage("Error in " .. functionName .. ": type mismatch.", logLevelError)
            return a
        end
        return a + (b - a) * clampedT
    end

    if IsVec3(a) then
        if not IsVec3(b) then
            LogMessage("Error in " .. functionName .. ": type mismatch.", logLevelError)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if IsVec2(a) then
        if not IsVec2(b) then
            LogMessage("Error in " .. functionName .. ": type mismatch.", logLevelError)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if IsColor(a) then
        if not IsColor(b) then
            LogMessage("Error in " .. functionName .. ": type mismatch.", logLevelError)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    if IsRotation(a) then
        if not IsRotation(b) then
            LogMessage("Error in " .. functionName .. ": type mismatch.", logLevelError)
            return a
        end
        return a:Lerp(b, clampedT)
    end

    LogMessage("Error in " .. functionName .. ": unsupported type.", logLevelError)
    return a
end

return Util