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
local concat = table.concat
local format = string.format

Util.ShortenTENCalls = function()
	print("Util.ShortenTENCalls is deprecated; its functionality is now performed automatically by TombEngine.")
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
	local result = {}
	local index = 1
	if timerFormat.hours then
		result[index] = format("%02d", time.h)
		index = index + 1
	end
	if timerFormat.minutes then
		result[index] = format("%02d", timerFormat.hours and time.m or (time.m + (60 * time.h)))
		index = index + 1
	end
	if timerFormat.seconds then
		local aggregatedSeconds = time.s
		if not timerFormat.minutes then
			aggregatedSeconds = aggregatedSeconds + (60 * time.m)
			if not timerFormat.hours then
				aggregatedSeconds = aggregatedSeconds + (3600 * time.h)
			end
		end
		result[index] = format("%02d", aggregatedSeconds)
		index = index + 1
	end
	local formattedString = concat(result, ":")

	-- Check if timerFormat.deciseconds exists for backward compatibility, but prefer timerFormat.centiseconds if it exists
	-- The visual difference with the previous version is 2 decimal places instead of 1.
	-- Before: 5.0
	-- After: 5.00
	if timerFormat.centiseconds or timerFormat.deciseconds then
		local c = format("%02d", time.c)
		return (index == 1) and c or formattedString .. "." .. c
	end
	return formattedString
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

return Util