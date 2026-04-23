-----<style>table.function_list td.name {min-width: 395px;} .section-header.has-description {border-top: 1px solid #ccc; padding-top: 1em;}</style>
--- Basic frame-based stopwatch that perform countup. It updates at 30 FPS (one tick per frame), so time is quantized to 1/30s (0.03s) precision. Stopwatches are updated automatically at every frame before OnLoop event.<br>To use Stopwatch inside scripts you need to call the module:
--	local Stopwatch = require("Engine.Stopwatch")
--
-- Example usage:
--	local Stopwatch = require("Engine.Stopwatch")
--
--	-- Create simple stopwatch
--	Stopwatch.Create({ name = "MyStopwatch" })
--
--	-- Create LevelFuncs to start, pause and stop the stopwatch
--	LevelFuncs.StartMyStopwatch = function()
--        Stopwatch.Get("MyStopwatch"):Start()
--	end
--	LevelFuncs.PauseMyStopwatch = function()
--        Stopwatch.Get("MyStopwatch"):Pause()
--	end
--	LevelFuncs.StopMyStopwatch = function()
--        Stopwatch.Get("MyStopwatch"):Stop()
--	end
-- @luautil Stopwatch

local Type = require("Engine.Type")
local Utility = require("Engine.Util")

local Stopwatch = {}
Stopwatch.__index = Stopwatch
LevelFuncs.Engine.Stopwatch = {}
LevelVars.Engine.Stopwatch = { stopwatches = {} }
local stopwatches = LevelVars.Engine.Stopwatch.stopwatches
local stopwatchStrings = {} -- DisplayString objects, not serializable in LevelVars

-- Utility functions and enums from TEN 
local LogMessage		  = TEN.Util.PrintLog
local logLevelError		  = TEN.Util.LogLevel.ERROR
local logLevelWarning	  = TEN.Util.LogLevel.WARNING
local PercentToScreen	  = TEN.Util.PercentToScreen
local ScreenToPercent	  = TEN.Util.ScreenToPercent
local DisplayString		  = TEN.Strings.DisplayString
local ShowString		  = TEN.Strings.ShowString
local HideString		  = TEN.Strings.HideString
local DisplayStringOption = TEN.Strings.DisplayStringOption
local Time				  = TEN.Time
local Vec2				  = TEN.Vec2
local Color				  = TEN.Color

local ZERO = Time()
local DEFAULT_TEXT_OPTIONS = {DisplayStringOption.CENTER, DisplayStringOption.SHADOW, DisplayStringOption.VERTICAL_CENTER}
local DEFAULT_TIME_FORMAT = {minutes = true, seconds = true, centiseconds = true}
local FPS = 30
local FRAME_TIME = 1 / FPS
local DEFAULT_COLOR = Color(255, 255, 255, 255)
local DEFAULT_PAUSED_COLOR = Color(255, 255, 0, 255)
local DEFAULT_POSITION = Vec2(PercentToScreen(50, 90))
local COMPARISON_OPS =
{
    function(a, b) return a == b end,   -- 0: equal
    function(a, b) return a ~= b end,   -- 1: not equal
    function(a, b) return a < b end,    -- 2: less than
    function(a, b) return a <= b end,   -- 3: less than or equal
    function(a, b) return a > b end,    -- 4: greater than
    function(a, b) return a >= b end,   -- 5: greater than or equal
}
local CALLBACKFIELDS = {
    { field = "onStart",    key = "OnStart"    },
    { field = "onResume",   key = "OnResume"   },
    { field = "onPause",    key = "OnPause"    },
    { field = "onStop",     key = "OnStop"     },
    { field = "onReset",    key = "OnReset"    },
    { field = "onLap",      key = "OnLap"      },
    { field = "onMaxTime",  key = "OnMaxTime"  },
    { field = "onInterval", key = "OnInterval" },
}
local CreateErrorPrefix = "Error in Stopwatch.Create(): "
local CreateWarningPrefix = "Warning in Stopwatch.Create(): "
local floor = math.floor
local pairs = pairs
local remove = table.remove
local insert = table.insert

-- Utility functions from Engine.Util that are used in this module
local CheckTimeFormat 			  = Utility.CheckTimeFormat
local GenerateTimeFormattedString = Utility.GenerateTimeFormattedString
local TableHasValue			      = Utility.TableHasValue

-- Type checking functions from Engine.Type that are used in this module
local IsVec2 = Type.IsVec2
local IsNumber = Type.IsNumber
local IsColor = Type.IsColor
local IsEnumValue = Type.IsEnumValue
local IsBoolean = Type.IsBoolean
local IsString = Type.IsString
local IsTable = Type.IsTable
local IsNull = Type.IsNull
local IsLevelFunc = Type.IsLevelFunc
local IsFunction = Type.IsFunction

Stopwatch.CallbackTypes = {
    ON_LAP      = "OnLap",
    ON_RESET    = "OnReset",
    ON_START    = "OnStart",
    ON_RESUME   = "OnResume",
    ON_PAUSE    = "OnPause",
    ON_STOP     = "OnStop",
    ON_MAX_TIME = "OnMaxTime",
    ON_INTERVAL = "OnInterval",
}

local function Round2Decimal(second)
	return floor(second * 100 + 0.5) / 100
end

local CheckOperator = function(operator)
	if not IsNumber(operator) then
		return nil
	end
    local op = COMPARISON_OPS[operator + 1]
    return IsFunction(op) and op or nil
end

local function validate(value, isValid, defaultValue, warningMsg)
    if IsNull(value) then
        return defaultValue
    end
    if isValid then
        return value
    end

    LogMessage(CreateWarningPrefix .. warningMsg, logLevelWarning)
    return defaultValue
end

local CheckTextOptions = function(optionsTable, warning1Message, warning2Message)
    optionsTable = optionsTable or DEFAULT_TEXT_OPTIONS
    if optionsTable ~= DEFAULT_TEXT_OPTIONS then
        if IsTable(optionsTable) then
            for i, option in pairs(optionsTable) do
                if not IsEnumValue(option, DisplayStringOption, false) then
                    LogMessage(warning2Message, logLevelWarning)
                    return DEFAULT_TEXT_OPTIONS
                end
                -- Remove vertical bottom option if present, as it is not compatible with stopwatch display
                if option == DisplayStringOption.VERTICAL_BOTTOM then
                    remove(optionsTable, i)
                end
            end
            -- Ensure VERTICAL_CENTER is always present
            if not TableHasValue(optionsTable, DisplayStringOption.VERTICAL_CENTER) then
                insert(optionsTable, DisplayStringOption.VERTICAL_CENTER)
            end
            return optionsTable
        else
            LogMessage(warning1Message, logLevelWarning)
            return DEFAULT_TEXT_OPTIONS
        end
    end
    return optionsTable
end

local function FireCallback(s, callbackType, proxy)
    local fn = s.callbacks[callbackType]
    if fn then fn(proxy) end
end

--- Create (but do not start) a new stopwatch.
-- @tparam StopwatchData stopwatchData A table containing the parameters for the stopwatch.
-- @treturn[1] Stopwatch The created stopwatch in its idle state, not yet started.
-- @treturn[2] nil If the stopwatch creation failed due to invalid parameters, with an error message logged to the console.
-- @usage
-- -- Example 1: simple creation of a stopwatch
-- local myStopwatch = Stopwatch.Create({ name = "MyStopwatch" })
-- 
-- -- Example 2: creation of a stopwatch with custom parameters
-- local options = {
--     TEN.Strings.DisplayStringOption.RIGHT,
--     TEN.Strings.DisplayStringOption.SHADOW,
--     TEN.Strings.DisplayStringOption.VERTICAL_CENTER
-- }
-- local myStopwatch = Stopwatch.Create({
--     name = "RaceTimer",
--     timerFormat = { seconds = true, centiseconds = true },
--     position = TEN.Vec2(90, 10),
--     scale = 1.5,
--     color = TEN.Color(0, 255, 0, 255),
--     pausedColor = TEN.Color(255, 0, 0, 255),
--     stringOption = options,
-- })
--
-- -- Example 3: creation of a stopwatch with callbacks assigned at creation time
-- LevelFuncs.OnLapRecorded = function(sw)
--     TEN.Util.PrintLog("Lap " .. sw:GetLapCount(), TEN.Util.LogLevel.INFO)
-- end
-- LevelFuncs.OnTick = function(sw)
--     TEN.Util.PrintLog("Elapsed: " .. sw:GetElapsedTimeInSeconds() .. "s", TEN.Util.LogLevel.INFO)
-- end
-- Stopwatch.Create({
--     name         = "RaceTimer",
--     timeFormat   = { minutes = true, seconds = true, centiseconds = true },
--     onLap        = LevelFuncs.OnLapRecorded,
--     onInterval   = LevelFuncs.OnTick,
--     intervalTime = 1.0,
-- })
Stopwatch.Create = function(stopwatchData)
    if not IsTable(stopwatchData) then
        LogMessage(CreateErrorPrefix .. "stopwatchData must be a table.", logLevelError)
        return nil
    end
    if not IsString(stopwatchData.name) then
        LogMessage(CreateErrorPrefix .. "stopwatchData.name must be a string.", logLevelError)
        return nil
    end
    local self = { name = stopwatchData.name }
    if stopwatches[stopwatchData.name] then
        LogMessage(CreateWarningPrefix .. "a stopwatch with name '" .. stopwatchData.name .. "' already exists; overwriting it with a new one...", logLevelWarning)
        stopwatchStrings[stopwatchData.name] = nil
    end
    stopwatches[stopwatchData.name] = {}
    local stopwatchEntry = stopwatches[stopwatchData.name]
    local name = stopwatchData.name

    -- check timeFormat
    local timeFormat = stopwatchData.timeFormat or false
    stopwatchEntry.timeFormat = CheckTimeFormat(timeFormat, "Warning in Stopwatch.Create(): wrong value for timeFormat, timeFormat for '".. name .."' stopwatch will be set to false")


    -- check maxTime
    if IsNumber(stopwatchData.maxTime) and stopwatchData.maxTime >= 0 then
        stopwatchEntry.maxTime = Time(Round2Decimal(stopwatchData.maxTime) * FPS)
    else
        if stopwatchData.maxTime ~= nil then
            LogMessage(CreateWarningPrefix .. "wrong value for maxTime for '".. name .."'", logLevelWarning)
        end
        stopwatchEntry.maxTime = nil
    end

    -- check position
    stopwatchEntry.position = validate(stopwatchData.position, IsVec2(stopwatchData.position), DEFAULT_POSITION, "wrong position for '".. name .."', set to default")
    if stopwatchEntry.position ~= DEFAULT_POSITION then
        stopwatchEntry.position = Vec2(PercentToScreen(stopwatchData.position.x, stopwatchData.position.y))
    end

    -- check scale
    stopwatchEntry.scale = validate(stopwatchData.scale, IsNumber(stopwatchData.scale) and stopwatchData.scale > 0, 1, "wrong scale for '".. name .."', set to 1")

    -- check color
    stopwatchEntry.color = validate(stopwatchData.color, IsColor(stopwatchData.color), DEFAULT_COLOR, "wrong color for '".. name .."', set to default")

    -- check pausedColor
    stopwatchEntry.pausedColor = validate(stopwatchData.pausedColor, IsColor(stopwatchData.pausedColor), DEFAULT_PAUSED_COLOR, "wrong pausedColor for '".. name .."', set to default")

    -- check stringOption
    local warning1Message = CreateWarningPrefix .. "stringOption must be a table. Stopwatch '".. name .."' will use default stringOption."
    local warning2Message = CreateWarningPrefix .. "all values in stringOption must be of type TEN.Strings.DisplayStringOption. Stopwatch '".. name .."' will use default stringOption."
    stopwatchEntry.stringOption = CheckTextOptions(stopwatchData.stringOption, warning1Message, warning2Message)

    stopwatchEntry.elapsedTime = ZERO
    stopwatchEntry.active = false
    stopwatchEntry.paused = false
    stopwatchEntry.laps = {}
    stopwatchEntry.callbacks = {}
    stopwatchEntry.intervalFrames = nil
    stopwatchEntry.lastIntervalCount = 0

    -- assign callbacks from stopwatchData fields
    for _, cb in ipairs(CALLBACKFIELDS) do
        local fn = stopwatchData[cb.field]
        if not IsNull(fn) then
            if IsLevelFunc(fn) then
                stopwatchEntry.callbacks[cb.key] = fn
            else
                LogMessage(CreateWarningPrefix .. "wrong value for " .. cb.field .. " in '" .. name .. "', it must be a LevelFunc. Callback will be ignored.", logLevelWarning)
            end
        end
    end
    if not IsNull(stopwatchData.intervalTime) then
        if not IsNumber(stopwatchData.intervalTime) or stopwatchData.intervalTime <= 0 then
            LogMessage(CreateWarningPrefix .. "wrong value for intervalTime in '" .. name .. "', it must be a positive number.", logLevelWarning)
        else
            local frames = floor(Round2Decimal(stopwatchData.intervalTime) * FPS + 0.5)
            if frames < 1 then
                LogMessage(CreateWarningPrefix .. "intervalTime too small for '" .. name .. "' (rounds to 0 frames). Minimum is " .. FRAME_TIME .. "s (1 frame at 30 FPS).", logLevelWarning)
            else
                stopwatchEntry.intervalFrames = frames
            end
        end
    end

    if stopwatchEntry.timeFormat then
        local initText = GenerateTimeFormattedString(ZERO, stopwatchEntry.timeFormat)
        stopwatchStrings[name] = DisplayString(initText, stopwatchEntry.position, stopwatchEntry.scale, DEFAULT_COLOR, false, stopwatchEntry.stringOption)
    end

    return setmetatable(self, Stopwatch)
end

--- Delete a stopwatch by name.
-- @tparam string name The name of the stopwatch to delete.
-- @usage
-- Stopwatch.Delete("MyStopwatch")
Stopwatch.Delete = function(name)
    if not IsString(name) then
        LogMessage("Error in Stopwatch.Delete(): name must be a string.", logLevelError)
    else
        if stopwatches[name] then
            stopwatches[name] = nil
            local ds = stopwatchStrings[name]
            if ds then HideString(ds) end
            stopwatchStrings[name] = nil
        else
            LogMessage("Warning in Stopwatch.Delete(): no stopwatch found with name '" .. tostring(name) .. "'.", logLevelWarning)
        end
    end
end

--- Get a stopwatch by name.
-- @tparam string name The name of the stopwatch to retrieve.
-- @treturn Stopwatch The stopwatch object if found, or stopwatch object with an error field set to true if not found.
-- @usage
-- local myStopwatch = Stopwatch.Get("MyStopwatch")
Stopwatch.Get = function(name)
    local errorPrefix = "in Stopwatch.Get(): "
    local self = {}
    if not IsString(name) then
        return LogMessage("Error " .. errorPrefix .. "name must be a string.", logLevelError)
    end
    if not stopwatches[name] then
        return LogMessage("Warning " .. errorPrefix .. "no stopwatch found with name '" .. tostring(name) .. "'.", logLevelWarning)
    end
    return setmetatable({ name = name }, Stopwatch)
end

--- Check if a stopwatch exists by name.
-- @tparam string name The name of the stopwatch to check.
-- @treturn bool True if the stopwatch exists, false otherwise.
-- @usage
-- -- Example1: Check if a stopwatch exists before using it
-- if Stopwatch.IfExists("MyStopwatch") then
--     local myStopwatch = Stopwatch.Get("MyStopwatch")
-- end
--
-- -- Example2: Check if a stopwatch exists before creating it
-- if not Stopwatch.IfExists("MyStopwatch") then
--     local myStopwatch = Stopwatch.Create({ name = "MyStopwatch" })
-- end
Stopwatch.IfExists = function(name)
    if not IsString(name) then
        LogMessage("Error in Stopwatch.IfExists(): name must be a string.", logLevelError)
        return false
    end
    return stopwatches[name] and true or false
end

----
-- The list of all methods for Stopwatch objects. We suggest that you always use the @{Stopwatch.Get} function to use the methods of the Timer object to prevent errors or unexpected behavior
-- @type Stopwatch
-- @usage
--	-- Examples of some methods
-- Stopwatch.Get("MyStopwatch"):Start()
-- Stopwatch.Get("MyStopwatch"):Pause()
-- Stopwatch.Get("MyStopwatch"):Stop()

--- Start or resume the stopwatch.
-- @tparam[opt=false] bool reset If true, resets the stopwatch to zero before starting. If false or not provided, the stopwatch will continue from its current time.
-- @usage
-- -- Example 1: Start the stopwatch
-- Stopwatch.Get("MyStopwatch"):Start()
--
-- -- Example 2: Start the stopwatch and reset its time to zero
-- Stopwatch.Get("MyStopwatch"):Start(true)
function Stopwatch:Start(reset)
    local stopwatch = stopwatches[self.name]
    local wasActive = stopwatch.active
    local wasPaused = stopwatch.paused
    if reset then
        stopwatch.elapsedTime = ZERO
        stopwatch.laps = {}
        stopwatch.lastIntervalCount = 0
    end
    stopwatch.active = true
    stopwatch.paused = false
    local proxy = setmetatable({name = self.name}, Stopwatch)
    if not wasActive or reset then
        FireCallback(stopwatch, "OnStart", proxy)
    elseif wasPaused then
        FireCallback(stopwatch, "OnResume", proxy)
    end
end

--- Pause the stopwatch.
-- @usage
-- Stopwatch.Get("MyStopwatch"):Pause()
function Stopwatch:Pause()
    local stopwatch = stopwatches[self.name]
    if not stopwatch.paused then
        stopwatch.paused = true
        FireCallback(stopwatch, "OnPause", setmetatable({name = self.name}, Stopwatch))
    end
end

--- Stop the stopwatch.
-- @tparam[opt=nil] float displayTime If provided, the stopwatch display will remain visible for this many seconds after stopping. Must be a positive number. If not provided or nil, the display is hidden immediately.
-- @usage
-- -- Example 1: Stop the stopwatch and hide the display immediately
-- Stopwatch.Get("MyStopwatch"):Stop()
--
-- -- Example 2: Stop the stopwatch and keep the display visible for 2 seconds
-- Stopwatch.Get("MyStopwatch"):Stop(2.0)
function Stopwatch:Stop(displayTime)
    local stopwatch = stopwatches[self.name]
    if stopwatch.active then
        FireCallback(stopwatch, "OnStop", setmetatable({name = self.name}, Stopwatch))
    end
    stopwatch.active = false
    stopwatch.paused = false
    local ds = stopwatchStrings[self.name]
    if ds then
        if displayTime ~= nil then
            if not IsNumber(displayTime) or displayTime <= 0 then
                LogMessage("Warning in Stopwatch:Stop(): wrong value (" .. tostring(displayTime) .. ") for displayTime, the stopwatch display will be hidden immediately.", logLevelWarning)
                HideString(ds)
            else
                local s = stopwatches[self.name]
                if s.timeFormat then
                    ds:SetKey(GenerateTimeFormattedString(s.elapsedTime, s.timeFormat))
                    ds:SetColor(s.color)
                end
                ShowString(ds, displayTime, false)
            end
        else
            HideString(ds)
        end
    end
end

--- Reset the stopwatch to zero and stop it.
-- @usage
-- Stopwatch.Get("MyStopwatch"):Reset()
function Stopwatch:Reset()
    local stopwatch = stopwatches[self.name]
    FireCallback(stopwatch, "OnReset", setmetatable({name = self.name}, Stopwatch))
    stopwatch.elapsedTime = ZERO
    stopwatch.active = false
    stopwatch.paused = false
    stopwatch.laps = {}
    stopwatch.lastIntervalCount = 0
    local ds = stopwatchStrings[self.name]
    if ds then HideString(ds) end
end

--- Get the elapsed time of the stopwatch.
-- @treturn Time The elapsed time of the stopwatch in game frames.
-- @usage
-- local elapsedTime = Stopwatch.Get("MyStopwatch"):GetElapsedTime()
function Stopwatch:GetElapsedTime()
    return stopwatches[self.name].elapsedTime
end

--- Get the elapsed time of the stopwatch in seconds.
-- @treturn float The elapsed time of the stopwatch in seconds.
-- @usage
-- local elapsedTimeInSeconds = Stopwatch.Get("MyStopwatch"):GetElapsedTimeInSeconds()
function Stopwatch:GetElapsedTimeInSeconds()
    local elapsedTime = stopwatches[self.name].elapsedTime
    local frames = elapsedTime:GetFrameCount()
    local seconds = floor(frames / FPS * 100) / 100
    return seconds
end

--- Get the elapsed time of the stopwatch formatted as a string.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use for the time string. See `timeFormat` for details.<br>
-- @treturn string The formatted time string.
-- @usage
-- local timeFormat = { minutes = true, seconds = true}
-- local elapsedTimeFormatted = Stopwatch.Get("MyStopwatch"):GetElapsedTimeFormatted(timeFormat)
function Stopwatch:GetElapsedTimeFormatted(timeFormat)
    timeFormat = timeFormat or DEFAULT_TIME_FORMAT
    if timeFormat ~= DEFAULT_TIME_FORMAT then
        timeFormat = CheckTimeFormat(timeFormat, "Warning in Stopwatch:GetElapsedTimeFormatted(): wrong value for timeFormat, default format will be used.")
    end
    local stopwatch = stopwatches[self.name]
    return GenerateTimeFormattedString(stopwatch.elapsedTime, timeFormat)
end

--- Set the elapsed time of the stopwatch.
-- @tparam float newTime The new time for the stopwatch in seconds with 2 decimal places<br>
-- No negative values allowed. Values ​​are rounded to 2 decimal places and converted to 30 FPS game frames and rounded to the nearest frame.
-- @usage
-- Stopwatch.Get("MyStopwatch"):SetElapsedTime(30.5) -- Set time to 30.5 seconds
function Stopwatch:SetElapsedTime(newTime)
    if not IsNumber(newTime) or newTime < 0 then
        LogMessage("Error in Stopwatch:SetElapsedTime(): wrong value (" .. tostring(newTime) .. ") for newTime, it must be a non-negative number.", logLevelError)
    else
        local stopwatch = stopwatches[self.name]
        stopwatch.elapsedTime = Time(Round2Decimal(newTime) * FPS)
    end
end

--- Check if the elapsed time of the stopwatch meets a specific condition.
--
-- It's recommended to use the IfElapsedTimeIs method to have error-free comparisons.
-- @tparam int operator The type of comparison.<br>
-- 0 : If the elapsed time is equal to the value<br>
-- 1 : If the elapsed time is different from the value<br>
-- 2 : If the elapsed time is less the value<br>
-- 3 : If the elapsed time is less or equal to the value<br>
-- 4 : If the elapsed time is greater the value<br>
-- 5 : If the elapsed time is greater or equal to the value
-- @tparam float seconds The value in seconds to compare.<br>
-- No negative values allowed. Values are converted to 30 FPS game frames and rounded to the nearest frame.<br>
-- Please note: to have continuous control, the elapsed time must be controlled within the *OnLoop* event and only when the stopwatch is active @{Stopwatch.IsActive}.
-- @treturn bool True if the condition is met, false otherwise.
-- @usage
-- -- Example1: Alternative method to create a sequence of events based on stopwatch time
-- LevelFuncs.OnLoop = function() -- this LevelFuncs is already present in your level script
--     local stopwatch = Stopwatch.Get("MyStopwatch")
--     if stopwatch:IsActive() then
--         if stopwatch:IfElapsedTimeIs(0, 2.0) then -- If elapsed time is equal to 2.0 seconds
--             -- Do something
--         end
--         if stopwatch:IfElapsedTimeIs(0, 4.0) then -- If elapsed time is equal to 4.0 seconds
--             -- Do something else
--         end
--         if stopwatch:IfElapsedTimeIs(0, 6.0) then -- If elapsed time is equal to 6.0 seconds
--             -- Do another thing
--         end
--     end
-- end
--
-- -- Example2: Using callbacks
-- LevelFuncs.MySequenceOfEvents = function()
--     local stopwatch = Stopwatch.Get("MyStopwatch")
--     if stopwatch:IsActive() then
--         if stopwatch:IfElapsedTimeIs(0, 3.0) then -- If elapsed time is equal to 3.0 seconds
--             -- Do something
--         end
--         if stopwatch:IfElapsedTimeIs(0, 5.0) then -- If elapsed time is equal to 5.0 seconds
--             -- Do something else
--         end
--     end
-- end
-- TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POST_LOOP, LevelFuncs.MySequenceOfEvents)
function Stopwatch:IfElapsedTimeIs(operator, seconds)
    local op = CheckOperator(operator)
    if not op then
        LogMessage("Error in Stopwatch:IfElapsedTimeIs(): invalid operator for '" .. self.name .. "' stopwatch", logLevelError)
        return false
    end
    if not IsNumber(seconds) or seconds < 0 then
        LogMessage("Error in Stopwatch:IfElapsedTimeIs(): wrong value (" .. tostring(seconds) .. ") for seconds in '" .. self.name .. "' stopwatch", logLevelError)
        return false
    end
    local stopwatch = stopwatches[self.name]
    local time = Time(Round2Decimal(seconds) * FPS)
    return op(stopwatch.elapsedTime, time)
end

--- Get the maximum time of the stopwatch.
-- @treturn[1] Time The maximum time of the stopwatch in game frames
-- @treturn[2] nil If no maximum time is set.
-- @usage
-- local maxTime = Stopwatch.Get("MyStopwatch"):GetMaxTime()
function Stopwatch:GetMaxTime()
    return stopwatches[self.name].maxTime
end

--- Get the maximum time of the stopwatch in seconds.
-- @treturn[1] float The maximum time of the stopwatch in seconds.
-- @treturn[2] nil If no maximum time is set.
-- @usage
-- local maxTimeInSeconds = Stopwatch.Get("MyStopwatch"):GetMaxTimeInSeconds()
function Stopwatch:GetMaxTimeInSeconds()
    local maxTime = stopwatches[self.name].maxTime
    if maxTime then
        local frames = maxTime:GetFrameCount()
        local seconds = floor(frames / FPS * 100) / 100
        return seconds
    end
    return nil
end

--- Get the maximum time of the stopwatch formatted as a string.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = false}] table|bool timeFormat The format to use for the time string. See `timeFormat` for details.<br>
-- @treturn[1] string The formatted maximum time string.
-- @treturn[2] nil If no maximum time is set.
-- @usage
-- local timeFormat = { minutes = true, seconds = true}
-- local maxTimeFormatted = Stopwatch.Get("MyStopwatch"):GetMaxTimeFormatted(timeFormat)
function Stopwatch:GetMaxTimeFormatted(timeFormat)
    timeFormat = timeFormat or DEFAULT_TIME_FORMAT
    if timeFormat ~= DEFAULT_TIME_FORMAT then
        timeFormat = CheckTimeFormat(timeFormat, "Warning in Stopwatch:GetMaxTimeFormatted(): wrong value for timeFormat, default format will be used.")
    end
    local maxTime = stopwatches[self.name].maxTime
    if maxTime then
        return GenerateTimeFormattedString(maxTime, timeFormat)
    end
    return nil
end

--- Set the maximum time for the stopwatch.
-- @tparam float maxTime The maximum time for the stopwatch in seconds with 2 decimal places. If set, the stopwatch will automatically stop when this time is reached. No negative values allowed. Values ​​are rounded to 2 decimal places and converted to 30 FPS game frames and rounded to the nearest frame.
-- @usage
-- Stopwatch.Get("MyStopwatch"):SetMaxTime(60) -- Set max time to 60 seconds
--
-- -- Example: Remove max time limit
-- Stopwatch.Get("MyStopwatch"):SetMaxTime()
function Stopwatch:SetMaxTime(maxTime)
    if IsNull(maxTime) then
        stopwatches[self.name].maxTime = nil
    else
        if not IsNumber(maxTime) or maxTime < 0 then
            LogMessage("Error in Stopwatch:SetMaxTime(): wrong value (" .. tostring(maxTime) .. ") for maxTime, it must be a non-negative number.", logLevelError)
        else
            stopwatches[self.name].maxTime = Time(Round2Decimal(maxTime) * FPS)
        end
    end
end

--- Check if the stopwatch has a maximum time set.
-- @treturn bool True if the stopwatch has a maximum time set, false otherwise.
-- @usage
-- if Stopwatch.Get("MyStopwatch"):HasMaxTime() then
--     -- Do something if max time is set
-- else
--     -- Do something else if no max time is set
-- end
function Stopwatch:HasMaxTime()
    return stopwatches[self.name].maxTime ~= nil
end

--- Check if the elapsed time of the stopwatch meets a specific condition in relation to the maximum time.
-- It's recommended to use the IfMaxTimeIs method to have error-free comparisons.
-- @tparam int operator The type of comparison.<br>
-- 0 : If the max time is equal to the value<br>
-- 1 : If the max time is different from the value<br>
-- 2 : If the max time is less the value<br>
-- 3 : If the max time is less or equal to the value<br>
-- 4 : If the max time is greater the value<br>
-- 5 : If the max time is greater or equal to the value
-- @tparam float seconds The value in seconds to compare.<br>
-- No negative values allowed. Values are converted to 30 FPS game frames and rounded to the nearest frame.<br>
-- Please note: Use the @{Stopwatch.HasMaxTime} method to check if a max time is set before using this method to prevent errors.
-- @treturn bool True if the condition is met, false otherwise.
-- @usage
-- -- Check if the max time is less than 60 seconds
-- if Stopwatch.Get("MyStopwatch"):HasMaxTime() and Stopwatch.Get("MyStopwatch"):IfMaxTimeIs(2, 60) then
--     -- Do something if max time is less than 60 seconds
-- end
function Stopwatch:IfMaxTimeIs(operator, seconds)
    local op = CheckOperator(operator)
    if not op then
        LogMessage("Error in Stopwatch:IfMaxTimeIs(): invalid operator for '" .. self.name .. "' stopwatch", logLevelError)
        return false
    end
    if not IsNumber(seconds) or seconds < 0 then
        LogMessage("Error in Stopwatch:IfMaxTimeIs(): wrong value (" .. tostring(seconds) .. ") for seconds in '" .. self.name .. "' stopwatch", logLevelError)
        return false
    end
    local stopwatch = stopwatches[self.name]
    if not stopwatch.maxTime then
        LogMessage("Warning in Stopwatch:IfMaxTimeIs(): no maxTime set for '" .. self.name .. "' stopwatch", logLevelWarning)
        return false
    end
    local time = Time(Round2Decimal(seconds) * FPS)
    return op(stopwatch.maxTime, time)
end

--- Get the position of the stopwatch on screen.
-- @treturn Vec2 The position of the stopwatch in percentage (0 to 100).
-- @usage
-- local position = Stopwatch.Get("MyStopwatch"):GetPosition()
function Stopwatch:GetPosition()
    local position = stopwatches[self.name].position
    return Vec2(ScreenToPercent(position.x, position.y))
end

--- Sets the position of the stopwatch on screen.
-- @tparam[opt=50] float x The X position in percentage (0 to 100).
-- @tparam[opt=90] float y The Y position in percentage (0 to 100).
-- @usage
-- -- Example: Set position to (75%, 10%)
-- Stopwatch.Get("MyStopwatch"):SetPosition(75, 10)
--
-- -- Example: Set position to default (50%, 90%)
-- Stopwatch.Get("MyStopwatch"):SetPosition()
function Stopwatch:SetPosition(x, y)
    x = x or 50
    y = y or 90
    if not IsNumber(x) or not IsNumber(y) then
        LogMessage("Error in Stopwatch:SetPosition(): x and y must be numbers.", logLevelError)
    else
        local newPos = Vec2(PercentToScreen(x, y))
        stopwatches[self.name].position = newPos
        local ds = stopwatchStrings[self.name]
        if ds then ds:SetPosition(newPos) end
    end
end

--- Get the scale of the stopwatch display.
-- @treturn float The scale factor.
-- @usage
-- local scale = Stopwatch.Get("MyStopwatch"):GetScale()
function Stopwatch:GetScale()
    return stopwatches[self.name].scale
end

--- Sets the scale of the stopwatch display.
-- @tparam[opt=1] float scale The scale factor (must be a positive number).
-- @usage
-- -- Example: Set scale to 2.0
-- Stopwatch.Get("MyStopwatch"):SetScale(2)
--
-- -- Example: Set scale to default (1.0)
-- Stopwatch.Get("MyStopwatch"):SetScale()
function Stopwatch:SetScale(scale)
    scale = scale or 1
    if not IsNumber(scale) or scale <= 0 then
        LogMessage("Error in Stopwatch:SetScale(): scale must be a positive number.", logLevelError)
    else
        stopwatches[self.name].scale = scale
        local ds = stopwatchStrings[self.name]
        if ds then ds:SetScale(scale) end
    end
end

--- Get the color of the stopwatch display.
-- @treturn Color The color of the stopwatch display.
-- @usage
-- local color = Stopwatch.Get("MyStopwatch"):GetColor()
function Stopwatch:GetColor()
    return stopwatches[self.name].color
end

--- Sets the color of the stopwatch display.
-- @tparam[opt=Color(255&#44; 255&#44; 255&#44; 255)] Color color The new color for the stopwatch display.
-- @usage
-- -- Example: Set color to red
-- Stopwatch.Get("MyStopwatch"):SetColor(TEN.Color(255, 0, 0, 255))
--
-- -- Example: Set color to default (white)
-- Stopwatch.Get("MyStopwatch"):SetColor()
function Stopwatch:SetColor(color)
    color = color or DEFAULT_COLOR
    if not IsColor(color) then
        LogMessage("Error in Stopwatch:SetColor(): color must be a Color object.", logLevelError)
    else
        stopwatches[self.name].color = color
    end
end

--- Sets the color of the stopwatch display when paused.
-- @tparam[opt=Color(255&#44; 255&#44; 0&#44; 255)] Color color The new color for the stopwatch display when paused.
-- @usage
-- -- Example: Set paused color to blue
-- Stopwatch.Get("MyStopwatch"):SetPausedColor(TEN.Color(0, 0, 255, 128))
--
-- -- Example: Set paused color to default (yellow)
-- Stopwatch.Get("MyStopwatch"):SetPausedColor()
function Stopwatch:SetPausedColor(color)
    color = color or DEFAULT_PAUSED_COLOR
    if not IsColor(color) then
        LogMessage("Error in Stopwatch:SetPausedColor(): color must be a Color object.", logLevelError)
        return
    end
    stopwatches[self.name].pausedColor = color
end

--- Get the color of the stopwatch display when paused.
-- @treturn Color The color of the stopwatch display when paused.
-- @usage
-- local pausedColor = Stopwatch.Get("MyStopwatch"):GetPausedColor()
function Stopwatch:GetPausedColor()
    return stopwatches[self.name].pausedColor
end

--- Sets the text options for the stopwatch display. Vertical center option is always added automatically if not present.
-- @tparam[opt=<br>{<br>TEN.Strings.DisplayStringOption.CENTER&#44;<br> TEN.Strings.DisplayStringOption.SHADOW&#44;<br> TEN.Strings.DisplayStringOption.VERTICAL_CENTER<br>}] table optionsTable A table containing values from @{Strings.DisplayStringOption} to set the text options.<br>
-- @usage
-- -- Example: Set text options to center and blink
-- local options = { TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.BLINK }
-- Stopwatch.Get("MyStopwatch"):SetTextOptions(options)
--
-- -- Example: Set text options to default (center, shadow, vertical center)
-- Stopwatch.Get("MyStopwatch"):SetTextOptions()
function Stopwatch:SetTextOptions(optionsTable)
    local warning1Message = "Warning in Stopwatch:SetTextOption(): optionsTable must be a table. Stopwatch '".. self.name .."' will use default stringOption."
    local warning2Message = "Warning in Stopwatch:SetTextOption(): all values in optionsTable must be of type TEN.Strings.DisplayStringOption. Stopwatch '".. self.name .."' will use default stringOption."
    local newOptions = CheckTextOptions(optionsTable, warning1Message, warning2Message)
    stopwatches[self.name].stringOption = newOptions
    local ds = stopwatchStrings[self.name]
    if ds then ds:SetFlags(newOptions) end
end

--- Check if the stopwatch is in paused state.
-- @treturn bool True if the stopwatch is paused, false otherwise.
-- @usage
-- local isPaused = Stopwatch.Get("MyStopwatch"):IsPaused()
function Stopwatch:IsPaused()
    return stopwatches[self.name].paused
end

--- Check if the stopwatch is active.
-- @treturn bool True if the stopwatch is active, false otherwise.
-- @usage
-- Example: Activate a post-process effect only if the stopwatch is active
-- if Stopwatch.Get("MyStopwatch"):IsActive() then
--     TEN.View.SetPostProcessMode(TEN.View.PostProcessMode.EXCLUSION)
-- end
function Stopwatch:IsActive()
    return stopwatches[self.name].active
end

--- Check if the stopwatch is active.
-- Returns `true` only if the stopwatch is ticking, i.e., it is active and not paused.
-- @treturn bool True if the stopwatch is ticking, false otherwise.
function Stopwatch:IsTicking()
    local stopwatch = stopwatches[self.name]
    return stopwatch.active and not stopwatch.paused
end

--- Record a lap and return the delta time of the completed segment.
-- Stores the current elapsed time as a split internally. The returned delta is the time elapsed since
-- the previous @{Stopwatch:Lap} call, or since @{Stopwatch:Start} if this is the first lap.
-- Can be called while the stopwatch is active, even if paused.
-- @treturn[1] Time The delta time of the completed lap segment.
-- @treturn[2] nil If the stopwatch is not active, with a warning logged to the console.
-- @usage
-- -- Record a lap at each checkpoint and immediately print the segment time
-- LevelFuncs.OnCheckpoint = function()
--     local sw       = Stopwatch.Get("RaceTimer")
--     local lapIndex = sw:GetLapCount() + 1
--     sw:Lap()
--     local fmt = { seconds = true, centiseconds = true }
--     TEN.Util.PrintLog("Checkpoint " .. lapIndex .. ": " .. sw:GetLapTimeFormatted(lapIndex, fmt), TEN.Util.LogLevel.INFO)
-- end
function Stopwatch:Lap()
    local stopwatch = stopwatches[self.name]
    if not stopwatch.active then
        LogMessage("Warning in Stopwatch:Lap(): stopwatch '" .. self.name .. "' is not active.", logLevelWarning)
        return nil
    end
    insert(stopwatch.laps, stopwatch.elapsedTime)
    local lapIndex   = #stopwatch.laps
    local prevFrames = lapIndex > 1 and stopwatch.laps[lapIndex - 1]:GetFrameCount() or 0
    local delta      = Time(stopwatch.elapsedTime:GetFrameCount() - prevFrames)
    FireCallback(stopwatch, "OnLap", setmetatable({name = self.name}, Stopwatch))
    return delta
end

--- Get the number of recorded laps.
-- @treturn int The number of laps recorded so far.
-- @usage
-- local count = Stopwatch.Get("RaceTimer"):GetLapCount()
function Stopwatch:GetLapCount()
    return #stopwatches[self.name].laps
end

--- Get the delta time of a specific lap as a Time object.
-- The delta is the time elapsed during that lap segment (from the previous lap to this one, or from start for lap 1).
-- @tparam int index The 1-based lap index.
-- @treturn[1] Time The delta time of the specified lap.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local lapTime = Stopwatch.Get("RaceTimer"):GetLapTime(2)
function Stopwatch:GetLapTime(index)
    local laps = stopwatches[self.name].laps
    if not IsNumber(index) or index < 1 or index ~= floor(index) or index > #laps then
        LogMessage("Error in Stopwatch:GetLapTime(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError)
        return nil
    end
    local prevFrames = index > 1 and laps[index - 1]:GetFrameCount() or 0
    return Time(laps[index]:GetFrameCount() - prevFrames)
end

--- Get the delta time of a specific lap in seconds.
-- @tparam int index The 1-based lap index.
-- @treturn[1] float The delta time of the specified lap in seconds.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local lapSec = Stopwatch.Get("RaceTimer"):GetLapTimeInSeconds(2)
function Stopwatch:GetLapTimeInSeconds(index)
    local laps = stopwatches[self.name].laps
    if not IsNumber(index) or index < 1 or index ~= floor(index) or index > #laps then
        LogMessage("Error in Stopwatch:GetLapTimeInSeconds(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError)
        return nil
    end
    local prevFrames = index > 1 and laps[index - 1]:GetFrameCount() or 0
    return floor((laps[index]:GetFrameCount() - prevFrames) / FPS * 100) / 100
end

--- Get the delta time of a specific lap formatted as a string.
-- @tparam int index The 1-based lap index.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use. See `timeFormat` for details.
-- @treturn[1] string The formatted delta time of the specified lap.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local fmt    = { seconds = true, centiseconds = true }
-- local lapStr = Stopwatch.Get("RaceTimer"):GetLapTimeFormatted(2, fmt)
function Stopwatch:GetLapTimeFormatted(index, timeFormat)
    local laps = stopwatches[self.name].laps
    if not IsNumber(index) or index < 1 or index ~= floor(index) or index > #laps then
        LogMessage("Error in Stopwatch:GetLapTimeFormatted(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError)
        return nil
    end
    timeFormat = timeFormat or DEFAULT_TIME_FORMAT
    if timeFormat ~= DEFAULT_TIME_FORMAT then
        timeFormat = CheckTimeFormat(timeFormat, "Warning in Stopwatch:GetLapTimeFormatted(): wrong value for timeFormat, default format will be used.")
    end
    local prevFrames = index > 1 and laps[index - 1]:GetFrameCount() or 0
    return GenerateTimeFormattedString(Time(laps[index]:GetFrameCount() - prevFrames), timeFormat)
end

--- Get the cumulative split time at a specific lap as a Time object.
-- The split time is the total elapsed time from the start of the stopwatch to the moment @{Stopwatch:Lap} was called for that lap.
-- Use @{Stopwatch:GetLapTime} for the segment duration, and this method when you need the absolute time at a given checkpoint.
-- @tparam int index The 1-based lap index.
-- @treturn[1] Time The cumulative split time at the specified lap.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local split = Stopwatch.Get("RaceTimer"):GetSplitTime(2)
function Stopwatch:GetSplitTime(index)
    local laps = stopwatches[self.name].laps
    if not IsNumber(index) or index < 1 or index ~= floor(index) or index > #laps then
        LogMessage("Error in Stopwatch:GetSplitTime(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError)
        return nil
    end
    return laps[index]
end

--- Get the cumulative split time at a specific lap in seconds.
-- @tparam int index The 1-based lap index.
-- @treturn[1] float The cumulative split time at the specified lap in seconds.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local splitSec = Stopwatch.Get("RaceTimer"):GetSplitTimeInSeconds(2)
function Stopwatch:GetSplitTimeInSeconds(index)
    local laps = stopwatches[self.name].laps
    if not IsNumber(index) or index < 1 or index ~= floor(index) or index > #laps then
        LogMessage("Error in Stopwatch:GetSplitTimeInSeconds(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError)
        return nil
    end
    return floor(laps[index]:GetFrameCount() / FPS * 100) / 100
end

--- Get the cumulative split time at a specific lap formatted as a string.
-- @tparam int index The 1-based lap index.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use. See `timeFormat` for details.
-- @treturn[1] string The formatted cumulative split time at the specified lap.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local splitStr = Stopwatch.Get("RaceTimer"):GetSplitTimeFormatted(2)
function Stopwatch:GetSplitTimeFormatted(index, timeFormat)
    local laps = stopwatches[self.name].laps
    if not IsNumber(index) or index < 1 or index ~= floor(index) or index > #laps then
        LogMessage("Error in Stopwatch:GetSplitTimeFormatted(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError)
        return nil
    end
    timeFormat = timeFormat or DEFAULT_TIME_FORMAT
    if timeFormat ~= DEFAULT_TIME_FORMAT then
        timeFormat = CheckTimeFormat(timeFormat, "Warning in Stopwatch:GetSplitTimeFormatted(): wrong value for timeFormat, default format will be used.")
    end
    return GenerateTimeFormattedString(laps[index], timeFormat)
end

--- Get all lap delta times as an array of Time objects.
-- @treturn table An array of @{Time} objects, one per recorded lap (delta per segment). Returns an empty table if no laps have been recorded.
-- @usage
-- local lapTimes = Stopwatch.Get("RaceTimer"):GetAllLapTimes()
-- for i, t in ipairs(lapTimes) do
--     TEN.Util.PrintLog("Lap " .. i .. ": " .. t:GetFrameCount() .. " frames", TEN.Util.LogLevel.INFO)
-- end
function Stopwatch:GetAllLapTimes()
    local laps   = stopwatches[self.name].laps
    local result = {}
    for i = 1, #laps do
        local prevFrames = i > 1 and laps[i - 1]:GetFrameCount() or 0
        result[i] = Time(laps[i]:GetFrameCount() - prevFrames)
    end
    return result
end

--- Get all lap delta times as an array of floats in seconds.
-- @treturn table An array of floats (seconds), one per recorded lap. Returns an empty table if no laps have been recorded.
-- @usage
-- local lapSeconds = Stopwatch.Get("RaceTimer"):GetAllLapTimesInSeconds()
-- for i, s in ipairs(lapSeconds) do
--     TEN.Util.PrintLog("Lap " .. i .. ": " .. s .. "s", TEN.Util.LogLevel.INFO)
-- end
function Stopwatch:GetAllLapTimesInSeconds()
    local laps   = stopwatches[self.name].laps
    local result = {}
    for i = 1, #laps do
        local prevFrames = i > 1 and laps[i - 1]:GetFrameCount() or 0
        result[i] = floor((laps[i]:GetFrameCount() - prevFrames) / FPS * 100) / 100
    end
    return result
end

--- Get all lap delta times as an array of formatted strings.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use for each string. See `timeFormat` for details.
-- @treturn table An array of strings, one per recorded lap. Returns an empty table if no laps have been recorded.
-- @usage
-- local fmt        = { seconds = true, centiseconds = true }
-- local lapStrings = Stopwatch.Get("RaceTimer"):GetAllLapTimesFormatted(fmt)
-- for i, s in ipairs(lapStrings) do
--     TEN.Util.PrintLog("Lap " .. i .. ": " .. s, TEN.Util.LogLevel.INFO)
-- end
function Stopwatch:GetAllLapTimesFormatted(timeFormat)
    timeFormat = timeFormat or DEFAULT_TIME_FORMAT
    if timeFormat ~= DEFAULT_TIME_FORMAT then
        timeFormat = CheckTimeFormat(timeFormat, "Warning in Stopwatch:GetAllLapTimesFormatted(): wrong value for timeFormat, default format will be used.")
    end
    local laps   = stopwatches[self.name].laps
    local result = {}
    for i = 1, #laps do
        local prevFrames = i > 1 and laps[i - 1]:GetFrameCount() or 0
        result[i] = GenerateTimeFormattedString(Time(laps[i]:GetFrameCount() - prevFrames), timeFormat)
    end
    return result
end

--- Clear all recorded laps. Does not affect the elapsed time or the active state of the stopwatch.
-- @usage
-- Stopwatch.Get("RaceTimer"):ClearLaps()
function Stopwatch:ClearLaps()
    stopwatches[self.name].laps = {}
end

--- Set a callback function for a specific event.
-- The callback must be defined inside the LevelFuncs hierarchy. All callbacks receive the stopwatch proxy as the first argument, allowing full access to all Get methods and state manipulation.
-- For @{Stopwatch.CallbackTypes}.ON_INTERVAL an optional interval time in seconds can be specified as the third argument; if omitted, the currently configured interval is preserved.
-- @tparam CallbackTypes callbackType The event type.
-- @tparam function func A function defined in the `LevelFuncs` hierarchy. Signature: `function(stopwatch)`.
-- @tparam[opt=nil] float intervalTime Only for ON_INTERVAL: the firing interval in seconds (minimum ~0.03s = 1 frame). Ignored for all other callback types.
-- @usage
-- LevelFuncs.OnLapRecorded = function(sw)
--     TEN.Util.PrintLog("Lap " .. sw:GetLapCount() .. ": " .. sw:GetLapTimeFormatted(sw:GetLapCount()), TEN.Util.LogLevel.INFO)
-- end
-- Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnLapRecorded)
--
-- -- ON_INTERVAL: fires every second
-- LevelFuncs.OnTick = function(sw)
--     TEN.Util.PrintLog("Elapsed: " .. sw:GetElapsedTimeInSeconds() .. "s", TEN.Util.LogLevel.INFO)
-- end
-- Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_INTERVAL, LevelFuncs.OnTick, 1.0)
--
-- -- ON_INTERVAL: fires every frame (~0.03s)
-- Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_INTERVAL, LevelFuncs.OnTick, 0.03)
function Stopwatch:SetCallback(callbackType, func, intervalTime)
    if not TableHasValue(Stopwatch.CallbackTypes, callbackType) then
        LogMessage("Error in Stopwatch:SetCallback(): invalid callbackType for '" .. self.name .. "'. Use a Stopwatch.CallbackTypes constant.", logLevelError)
        return
    end
    if not IsLevelFunc(func) then
        LogMessage("Error in Stopwatch:SetCallback(): func must be a LevelFunc for '" .. self.name .. "'.", logLevelError)
        return
    end
    local stopwatch = stopwatches[self.name]
    stopwatch.callbacks[callbackType] = func
    if callbackType == Stopwatch.CallbackTypes.ON_INTERVAL and not IsNull(intervalTime) then
        self:SetIntervalTime(intervalTime)
    end
end

--- Remove a callback function for a specific event.
-- For @{Stopwatch.CallbackTypes}.ON_INTERVAL only the function is removed; the interval time is preserved.
-- Use @{Stopwatch:SetIntervalTime} with no arguments to remove the interval time and its callback together.
-- @tparam CallbackTypes callbackType The event type.
-- @usage
-- Stopwatch.Get("RaceTimer"):RemoveCallback(Stopwatch.CallbackTypes.ON_LAP)
function Stopwatch:RemoveCallback(callbackType)
    if not TableHasValue(Stopwatch.CallbackTypes, callbackType) then
        LogMessage("Error in Stopwatch:RemoveCallback(): invalid callbackType for '" .. self.name .. "'. Use a Stopwatch.CallbackTypes constant.", logLevelError)
        return
    end
    local stopwatch = stopwatches[self.name]
    stopwatch.callbacks[callbackType] = nil
end

--- Set the interval time for the @{Stopwatch.CallbackTypes}.ON_INTERVAL callback.
-- Call with no arguments (or nil) to remove the interval time and the ON_INTERVAL callback together.
-- @tparam[opt] float seconds The interval in seconds. Must be positive. The minimum effective value is one frame (~0.03s at 30 FPS); smaller values are rejected with a warning.
-- @usage
-- -- Fire every 5 seconds
-- Stopwatch.Get("RaceTimer"):SetIntervalTime(5.0)
--
-- -- Remove interval and its callback
-- Stopwatch.Get("RaceTimer"):SetIntervalTime()
function Stopwatch:SetIntervalTime(seconds)
    local stopwatch = stopwatches[self.name]
    if IsNull(seconds) then
        stopwatch.intervalFrames = nil
        stopwatch.lastIntervalCount = 0
        stopwatch.callbacks["OnInterval"] = nil
    elseif not IsNumber(seconds) or seconds <= 0 then
        LogMessage("Warning in Stopwatch:SetIntervalTime(): wrong value (" .. tostring(seconds) .. ") for seconds, it must be a positive number.", logLevelWarning)
    else
        local frames = floor(Round2Decimal(seconds) * FPS + 0.5)
        if frames < 1 then
            LogMessage("Warning in Stopwatch:SetIntervalTime(): interval too small (rounds to 0 frames). Minimum is " .. FRAME_TIME .. "s (1 frame at 30 FPS).", logLevelWarning)
            return
        end
        stopwatch.intervalFrames = frames
    end
end

--- Get the current interval time for the @{Stopwatch.CallbackTypes}.ON_INTERVAL callback.
-- @treturn[1] float The interval time in seconds.
-- @treturn[2] nil If no interval is configured.
-- @usage
-- local interval = Stopwatch.Get("RaceTimer"):GetIntervalTime()
function Stopwatch:GetIntervalTime()
    local frames = stopwatches[self.name].intervalFrames
    if frames then
        return floor(frames / FPS * 100) / 100
    end
    return nil
end

LevelFuncs.Engine.Stopwatch.IncrementTime = function()
    for _, s in pairs(stopwatches) do
        if s.active and not s.paused then
            s.elapsedTime = s.elapsedTime + 1
        end
    end
end

LevelFuncs.Engine.Stopwatch.UpdateAll = function()
    for name, s in pairs(stopwatches) do
        if s.active then
            local reachedMaxTime = s.maxTime and s.elapsedTime >= s.maxTime
            -- fire OnInterval (only when ticking, not paused)
            if s.intervalFrames and not s.paused then
                local frames = s.elapsedTime:GetFrameCount()
                local currentCount = floor(frames / s.intervalFrames)
                local lastCount = s.lastIntervalCount or 0
                if currentCount > lastCount then
                    local proxy = setmetatable({name = name}, Stopwatch)
                    local fn = s.callbacks["OnInterval"]
                    if fn then
                        for _ = lastCount + 1, currentCount do
                            fn(proxy)
                        end
                    end
                    s.lastIntervalCount = currentCount
                end
            end
            if s.timeFormat then
                local ds = stopwatchStrings[name]
                ds:SetKey(GenerateTimeFormattedString(s.elapsedTime, s.timeFormat))
                ds:SetColor(s.paused and s.pausedColor or s.color)
                ShowString(ds, reachedMaxTime and 1 or FRAME_TIME, false)
            end
            if reachedMaxTime then
                FireCallback(s, "OnMaxTime", setmetatable({name = name}, Stopwatch))
                s.active = false
                s.paused = false
            end
        end
    end
end

LevelFuncs.Engine.Stopwatch.Reload = function()
    stopwatches = LevelVars.Engine.Stopwatch.stopwatches
    stopwatchStrings = {}
    for name, s in pairs(stopwatches) do
        if s.timeFormat then
            local text = GenerateTimeFormattedString(s.elapsedTime, s.timeFormat)
            local color = s.paused and s.pausedColor or s.color
            stopwatchStrings[name] = DisplayString(text, s.position, s.scale, color, false, s.stringOption)
        end
    end
end

----
-- Tables
-- @section tables

---
-- Table setup for creating Stopwatch.
-- @table StopwatchData
-- @tfield string name The name of the stopwatch.
-- @tfield[opt=false] table|bool timeFormat Sets the time display. See `timeFormat` for details.
-- @tfield[opt=nil] maxTime The maximum time for the stopwatch in seconds with 2 decimal places. If set, the stopwatch will automatically stop when this time is reached. No negative values allowed. Values ​​are rounded to 2 decimal places and converted to 30 FPS game frames and rounded to the nearest frame.
-- @tfield[opt=Vec2(50&#44; 90)] Vec2 position The position in percentage on screen where the stopwatch will be displayed.
-- @tfield[opt=1] float scale The scale of the stopwatch display. Must be a positive number.
-- @tfield[opt=Color(255&#44; 255&#44; 255&#44; 255)] Color color The color of the displayed stopwatch when it is active.
-- @tfield[opt=Color(255&#44; 255&#44; 0&#44; 255)] Color pausedColor The color of the displayed stopwatch when it is not active.
-- @tfield[opt=<br>{<br>TEN.Strings.DisplayStringOption.CENTER&#44;<br> TEN.Strings.DisplayStringOption.SHADOW&#44;<br> TEN.Strings.DisplayStringOption.VERTICAL_CENTER<br>}] table stringOption A table containing values from @{Strings.DisplayStringOption} to set the text options. Vertical center option is always added automatically if not present.<br>
-- @tfield[opt=nil] function onStart Callback fired when the stopwatch is started. Must be a LevelFuncs function reference. Equivalent to calling @{Stopwatch:SetCallback} with @{Stopwatch.CallbackTypes}.ON_START after creation.
-- @tfield[opt=nil] function onResume Callback fired when the stopwatch is resumed after a pause. Must be a LevelFuncs function reference. Equivalent to calling @{Stopwatch:SetCallback} with @{Stopwatch.CallbackTypes}.ON_RESUME after creation.
-- @tfield[opt=nil] function onPause Callback fired when the stopwatch is paused. Must be a LevelFuncs function reference. Equivalent to calling @{Stopwatch:SetCallback} with @{Stopwatch.CallbackTypes}.ON_PAUSE after creation.
-- @tfield[opt=nil] function onStop Callback fired when the stopwatch is stopped. Must be a LevelFuncs function reference. Equivalent to calling @{Stopwatch:SetCallback} with @{Stopwatch.CallbackTypes}.ON_STOP after creation.
-- @tfield[opt=nil] function onReset Callback fired when the stopwatch is reset. Must be a LevelFuncs function reference. Equivalent to calling @{Stopwatch:SetCallback} with @{Stopwatch.CallbackTypes}.ON_RESET after creation.
-- @tfield[opt=nil] function onLap Callback fired when a lap is recorded. Must be a LevelFuncs function reference. Equivalent to calling @{Stopwatch:SetCallback} with @{Stopwatch.CallbackTypes}.ON_LAP after creation.
-- @tfield[opt=nil] function onMaxTime Callback fired when the stopwatch reaches its configured maxTime. Must be a LevelFuncs function reference. Equivalent to calling @{Stopwatch:SetCallback} with @{Stopwatch.CallbackTypes}.ON_MAX_TIME after creation.
-- @tfield[opt=nil] function onInterval Callback fired repeatedly at a fixed interval while the stopwatch is ticking (not paused). Must be a LevelFuncs function reference. Requires `intervalTime` to also be set; without it the callback is stored but never fires until an interval is configured via @{Stopwatch:SetIntervalTime}.
-- @tfield[opt=nil] float intervalTime The firing interval in seconds for the `onInterval` callback. Must be a positive number; the minimum effective value is one frame (~0.03s at 30 FPS). Has no effect without `onInterval`; however, the interval is stored and will be used as soon as a callback is assigned via @{Stopwatch:SetCallback}.

---
-- Time format configuration for displaying the stopwatch time.
-- @table timeFormat
-- You can display hours, minutes, seconds, and centiseconds; the format can be a table or a Boolean, just like in Timer.
--
-- For more information see the <a href="Timer.html#timerFormat">Time format</a> section in the Timer documentation.
-- <h3>Timer format examples:</h3>
-- <pre><span class="comment">-- hours:mins:secs.centisecond</span>
-- <span class="keyword">local</span> myTimeFormat = {hours = <span class="keyword">true</span>, minutes = <span class="keyword">true</span>, seconds = <span class="keyword">true</span>, centiseconds = <span class="keyword">true</span>}
-- <br><span class="comment">-- mins:secs</span>
-- <span class="keyword">local</span> myTimeFormat1 = {minutes = <span class="keyword">true</span>, seconds = <span class="keyword">true</span>}</pre>

---
-- Costants for the available callback types in @{Stopwatch:SetCallback}.
-- @table CallbackTypes
-- @tfield "OnLap" ON_LAP Called when a lap is recorded via @{Stopwatch:Lap}.
-- @tfield "OnStart" ON_START Called when the stopwatch is started via @{Stopwatch:Start}.
-- @tfield "OnPause" ON_PAUSE Called when the stopwatch is paused via @{Stopwatch:Pause}.
-- @tfield "OnResume" ON_RESUME Called when the stopwatch is resumed via @{Stopwatch:Start} after being paused.
-- @tfield "OnReset" ON_RESET Called when the stopwatch is reset via @{Stopwatch:Reset}.
-- @tfield "OnStop" ON_STOP Called when the stopwatch is stopped via @{Stopwatch:Stop} or automatically when maxTime is reached (if configured). The stopwatch is already stopped when the callback is fired, so you don't need to stop it manually inside the callback.
-- @tfield "OnMaxTime" ON_MAX_TIME Called when the stopwatch reaches the configured maxTime and automatically stops. The stopwatch is already stopped when the callback is fired, so you don't need to stop it manually inside the callback.
-- @tfield "OnInterval" ON_INTERVAL Called repeatedly at a specified interval while the stopwatch is active and ticking (not paused). The interval is configured via @{Stopwatch:SetIntervalTime} or @{Stopwatch:SetCallback}.
-- 

----
-- Advanced usage
-- @section examples
-- Advanced usage examples showing how to combine multiple Stopwatch features in real scenarios.

---
-- Race with checkpoints.
-- @table Scenario1
-- Record a lap at each checkpoint; at the finish line
-- display the segment time (delta) and the cumulative split for each checkpoint, plus the total.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- Stopwatch.Create({
--     name       = "RaceTimer",
--     timeFormat = { minutes = true, seconds = true, centiseconds = true },
--     position   = TEN.Vec2(50, 5),
-- })
--
-- LevelFuncs.OnRaceStart = function()
--     Stopwatch.Get("RaceTimer"):Start(true)
-- end
--
-- -- Trigger this via a volume or flipeffect at each checkpoint
-- LevelFuncs.OnCheckpoint = function()
--     Stopwatch.Get("RaceTimer"):Lap()
-- end
--
-- LevelFuncs.OnFinish = function()
--     local sw  = Stopwatch.Get("RaceTimer")
--     local fmt = { seconds = true, centiseconds = true }
--     sw:Stop(5.0)
--     for i = 1, sw:GetLapCount() do
--         local seg   = sw:GetLapTimeFormatted(i, fmt)
--         local split = sw:GetSplitTimeFormatted(i, fmt)
--         TEN.Util.PrintLog("Checkpoint " .. i .. " — segment: " .. seg .. "  split: " .. split, TEN.Util.LogLevel.INFO)
--     end
--     TEN.Util.PrintLog("Total: " .. sw:GetElapsedTimeFormatted(fmt), TEN.Util.LogLevel.INFO)
-- end

---
-- Timed puzzle with best-time record.
-- @table Scenario2
-- The player can retry a puzzle;
-- each attempt is timed and compared to the personal best stored in LevelVars.
-- A maxTime of 60 seconds automatically stops the stopwatch if the player runs out of time.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- LevelVars.puzzleBestTime = nil
-- Stopwatch.Create({ name = "PuzzleTimer", maxTime = 60.0 })
--
-- LevelFuncs.OnPuzzleStart = function()
--     Stopwatch.Get("PuzzleTimer"):Start(true)
-- end
--
-- LevelFuncs.OnPuzzleSolved = function()
--     local sw      = Stopwatch.Get("PuzzleTimer")
--     local elapsed = sw:GetElapsedTimeInSeconds()
--     sw:Stop(3.0)
--     if not LevelVars.puzzleBestTime or elapsed < LevelVars.puzzleBestTime then
--         LevelVars.puzzleBestTime = elapsed
--         TEN.Util.PrintLog("New best: " .. elapsed .. "s!", TEN.Util.LogLevel.INFO)
--     else
--         TEN.Util.PrintLog("Time: " .. elapsed .. "s  (best: " .. LevelVars.puzzleBestTime .. "s)", TEN.Util.LogLevel.INFO)
--     end
-- end

---
-- Speedrun with gold splits.
-- @table Scenario3
-- Compare each segment against known reference
-- (gold) times to tell the player whether they are ahead or behind on each segment.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- -- Reference gold times in seconds, one per segment
-- local goldSplits = { 12.50, 8.20, 15.00, 6.80 }
--
-- Stopwatch.Create({
--     name       = "SpeedrunTimer",
--     timeFormat = { minutes = true, seconds = true, centiseconds = true },
-- })
--
-- LevelFuncs.OnRunStart = function()
--     Stopwatch.Get("SpeedrunTimer"):Start(true)
-- end
--
-- LevelFuncs.OnSegmentEnd = function()
--     local sw   = Stopwatch.Get("SpeedrunTimer")
--     sw:Lap()
--     local i    = sw:GetLapCount()
--     local lap  = sw:GetLapTimeInSeconds(i)
--     local gold = goldSplits[i]
--     if gold then
--         if lap <= gold then
--             TEN.Util.PrintLog("Segment " .. i .. ": " .. lap .. "s  GOLD! (ref: " .. gold .. "s)", TEN.Util.LogLevel.INFO)
--         else
--             local behind = string.format("%.2f", lap - gold)
--             TEN.Util.PrintLog("Segment " .. i .. ": " .. lap .. "s  (+" .. behind .. "s behind gold)", TEN.Util.LogLevel.INFO)
--         end
--     end
-- end
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOOP, LevelFuncs.Engine.Stopwatch.IncrementTime)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POST_LOOP, LevelFuncs.Engine.Stopwatch.UpdateAll)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOAD, LevelFuncs.Engine.Stopwatch.Reload)

return Stopwatch