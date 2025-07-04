-- ldignore
local Util = {}
local Type= require("Engine.Type")

Util.ShortenTENCalls = function()
	print("Util.ShortenTENCalls is deprecated; its functionality is now performed automatically by TombEngine.")
end

-- Check if the time format is correct.
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

-- Generate a formatted string from a time.
Util.GenerateTimeFormattedString = function (time, timerFormat, errorFormat)
    errorFormat = Type.IsString(errorFormat) and errorFormat or false
    timerFormat = Util.CheckTimeFormat(timerFormat)

	if not timerFormat then
		if errorFormat then
			TEN.Util.PrintLog(errorFormat, TEN.Util.LogLevel.ERROR)
		end
		return "Error"
	else
		local result = {}
		local index = 1
		if timerFormat.hours then
        	result[index] = string.format("%02d", time.h)
        	index = index + 1
    	end
    	if timerFormat.minutes then
        	result[index] = string.format("%02d", timerFormat.hours and time.m or (time.m + (60 * time.h)))
        	index = index + 1
    	end
    	if timerFormat.seconds then
        	result[index] = string.format("%02d", timerFormat.minutes and time.s or (time.s + (60 * time.m)))
        	index = index + 1
    	end
		local formattedString = table.concat(result, ":")

    	if timerFormat.deciseconds then
        	local deciseconds = math.floor(time.c / 10)
			return (index == 1) and deciseconds or formattedString .. "." .. deciseconds
    	end
    	return formattedString
	end
end

-- Compare two values.
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

return Util