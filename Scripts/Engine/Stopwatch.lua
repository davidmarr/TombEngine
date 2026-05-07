-----<style>table.function_list td.name {min-width: 400px;}</style>
--- Frame-based stopwatch that counts up. It updates once per frame at 30 FPS, so time changes in steps of 1/30 second (about 0.03s). Stopwatches are updated automatically every frame. A stopwatch is ticking when it is active and not paused.
--
-- Require the module before using Stopwatch in a script:
--	local Stopwatch = require("Engine.Stopwatch")
--
-- Example usage:
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
-- Stopwatch state lives in LevelVars for save/load persistence. This alias is
-- rebound in Reload() because the module is evaluated again after loading a save.
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
local MIN_FRAME_SECONDS = math.floor(FRAME_TIME * 100) / 100
local DEFAULT_COLOR = Color(255, 255, 255, 255)
local DEFAULT_PAUSED_COLOR = Color(255, 255, 0, 255)
local DEFAULT_POSITION = Vec2(PercentToScreen(50, 90))
local COMPARISON_OPS =
{
    [0] = function(a, b) return a == b end,   -- 0: equal
    [1] = function(a, b) return a ~= b end,   -- 1: not equal
    [2] = function(a, b) return a < b end,    -- 2: less than
    [3] = function(a, b) return a <= b end,   -- 3: less than or equal
    [4] = function(a, b) return a > b end,    -- 4: greater than
    [5] = function(a, b) return a >= b end,   -- 5: greater than or equal
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
local sort = table.sort
local unpack = table.unpack
local setmetatable = setmetatable

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

Stopwatch.Operators = {
    EQUAL = 0,
    NOT_EQUAL = 1,
    LESS = 2,
    LESS_EQUAL = 3,
    GREATER = 4,
    GREATER_EQUAL = 5,
}

local function Round2Decimal(second)
	return floor(second * 100 + 0.5) / 100
end

local function SecondsToFrames(seconds)
    return floor(Round2Decimal(seconds) * FPS + 0.5)
end

local function SecondsToTime(seconds)
    return Time(Round2Decimal(seconds) * FPS)
end

local function FramesToSeconds(frames)
    return floor(frames / FPS * 100) / 100
end

local CheckOperator = function(operator)
	if not TableHasValue(Stopwatch.Operators, operator) then
		return nil
	end
    return COMPARISON_OPS[operator]
end

local function CloneArray(values)
    local clone = {}
    for i = 1, #values do
        clone[i] = values[i]
    end
    return clone
end

local function CloneShallowTable(values)
    local clone = {}
    for key, value in pairs(values) do
        clone[key] = value
    end
    return clone
end

local function CloneTimeTrigger(triggerData)
    local clone = {
        at = triggerData.at,
        func = triggerData.func,
    }
    if not IsNull(triggerData.args) then
        clone.args = CloneShallowTable(triggerData.args)
    end
    return clone
end

local function CloneTimeTriggers(timeTriggers)
    local clone = {}
    for i = 1, #timeTriggers do
        clone[i] = CloneTimeTrigger(timeTriggers[i])
    end
    return clone
end

local function NormalizeTimeFormat(timeFormat, warningMessage)
    if IsNull(timeFormat) then
        return DEFAULT_TIME_FORMAT
    end

    local normalizedTimeFormat = CheckTimeFormat(timeFormat, warningMessage)
    if normalizedTimeFormat == false and timeFormat ~= false then
        return DEFAULT_TIME_FORMAT
    end
    return normalizedTimeFormat
end

local function ValidatePositiveIndex(index, itemCount, invalidIndexMessage, logLevel)
    if not IsNumber(index) or index < 1 or index ~= floor(index) or index > itemCount then
        LogMessage(invalidIndexMessage, logLevel)
        return false
    end
    return true
end

local function GetLapDeltaFrames(laps, index)
    local prevFrames = index > 1 and laps[index - 1]:GetFrameCount() or 0
    return laps[index]:GetFrameCount() - prevFrames
end

local function ValidateFrameSeconds(seconds, invalidValueMessage, tooSmallMessage, logLevel)
    if not IsNumber(seconds) or seconds <= 0 then
        LogMessage(invalidValueMessage, logLevel)
        return nil
    end

    local roundedSeconds = Round2Decimal(seconds)
    if roundedSeconds < MIN_FRAME_SECONDS then
        LogMessage(tooSmallMessage, logLevel)
        return nil
    end

    local frames = floor(roundedSeconds * FPS + 0.5)
    if frames < 1 then
        LogMessage(tooSmallMessage, logLevel)
        return nil
    end

    return frames
end

local function ValidateArrayTable(values, invalidArrayMessage, nilValueMessage, logLevel)
    if not IsTable(values) then
        LogMessage(invalidArrayMessage, logLevel)
        return nil
    end

    local valueCount = 0
    for key in pairs(values) do
        if not IsNumber(key) or key < 1 or key ~= floor(key) then
            LogMessage(invalidArrayMessage, logLevel)
            return nil
        end
        valueCount = valueCount + 1
    end

    for i = 1, valueCount do
        if IsNull(values[i]) then
            LogMessage(nilValueMessage, logLevel)
            return nil
        end
    end

    return valueCount
end

local function NormalizeTimeTriggerData(triggerData, messagePrefix, logLevel)
    if not IsTable(triggerData) then
        LogMessage(messagePrefix .. "must be a table.", logLevel)
        return nil
    end

    if not ValidateFrameSeconds(
        triggerData.at,
        messagePrefix .. "field 'at' must be a positive number.",
        messagePrefix .. "field 'at' is too small. Minimum is " .. MIN_FRAME_SECONDS .. "s (1 frame at 30 FPS).",
        logLevel
    ) then
        return nil
    end
    if not IsLevelFunc(triggerData.func) then
        LogMessage(messagePrefix .. "field 'func' must be a LevelFunc.", logLevel)
        return nil
    end
    if not IsNull(triggerData.args) then
        if not ValidateArrayTable(
            triggerData.args,
            messagePrefix .. "field 'args' must be an array table with consecutive numeric indices starting at 1.",
            messagePrefix .. "field 'args' must not contain nil values.",
            logLevel
        ) then
            return nil
        end
    end

    local normalizedTrigger = {
        at = Round2Decimal(triggerData.at),
        func = triggerData.func,
    }
    if not IsNull(triggerData.args) then
        normalizedTrigger.args = CloneShallowTable(triggerData.args)
    end
    return normalizedTrigger
end

local function NormalizeTimeTriggerList(timeTriggers, invalidListMessage, itemMessagePrefix, itemMessageSuffix, logLevel)
    if IsNull(timeTriggers) then
        return {}
    end
    local triggerCount = ValidateArrayTable(timeTriggers, invalidListMessage, invalidListMessage, logLevel)
    if not triggerCount then
        return nil
    end

    local normalizedTriggers = {}
    for i = 1, triggerCount do
        local normalizedTrigger = NormalizeTimeTriggerData(
            timeTriggers[i],
            itemMessagePrefix .. "[" .. i .. "]" .. itemMessageSuffix .. " ",
            logLevel
        )
        if not normalizedTrigger then
            return nil
        end
        normalizedTriggers[i] = normalizedTrigger
    end
    return normalizedTriggers
end

local function DefaultIfNil(value, defaultValue)
    if IsNull(value) then
        return defaultValue
    end
    return value
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
    if IsNull(optionsTable) then
        return CloneArray(DEFAULT_TEXT_OPTIONS)
    end
    if not IsTable(optionsTable) then
        LogMessage(warning1Message, logLevelWarning)
        return CloneArray(DEFAULT_TEXT_OPTIONS)
    end

    local normalizedOptions = CloneArray(optionsTable)
    for i = #normalizedOptions, 1, -1 do
        local option = normalizedOptions[i]
        if not IsEnumValue(option, DisplayStringOption, false) then
            LogMessage(warning2Message, logLevelWarning)
            return CloneArray(DEFAULT_TEXT_OPTIONS)
        end
        -- Remove vertical bottom option if present, as it is not compatible with stopwatch display
        if option == DisplayStringOption.VERTICAL_BOTTOM then
            remove(normalizedOptions, i)
        end
    end
    -- Ensure VERTICAL_CENTER is always present
    if not TableHasValue(normalizedOptions, DisplayStringOption.VERTICAL_CENTER) then
        insert(normalizedOptions, DisplayStringOption.VERTICAL_CENTER)
    end
    return normalizedOptions
end

local function CreateStopwatchProxy(name)
    return setmetatable({name = name}, Stopwatch)
end

local function FireCallback(s, callbackType, proxy)
    local fn = s.callbacks[callbackType]
    if fn then
        fn(proxy)
    end
end

local function EnsureStopwatchProxy(proxy, name)
    if not proxy then
        proxy = CreateStopwatchProxy(name)
    end
    return proxy
end

local FlushPendingStopCallback = function(stopwatch, name, proxy)
    -- Stop() may be called from inside a scheduled callback. In that case the
    -- stopwatch must become inactive immediately, but OnStop must be delayed until
    -- the outer scheduled callback finishes so callback ordering stays predictable
    -- and non-reentrant.
    if stopwatch.pendingStopCallback then
        stopwatch.pendingStopCallback = false
        FireCallback(stopwatch, "OnStop", EnsureStopwatchProxy(proxy, name))
    end
end

local function FireTimeTriggerCallback(triggerData, proxy)
    local args = triggerData.args
    if args then
        triggerData.func(proxy, unpack(args))
    else
        triggerData.func(proxy)
    end
end

local function IsScheduledCallbackRunning(stopwatch)
    return stopwatch.scheduledCallbackDepth and stopwatch.scheduledCallbackDepth > 0
end

local function InterruptScheduledDispatch(stopwatch)
    if IsScheduledCallbackRunning(stopwatch) then
        stopwatch.scheduledDispatchInterrupted = true
    end
end

local function InvalidateScheduledState(stopwatch)
    if IsScheduledCallbackRunning(stopwatch) then
        stopwatch.scheduledStateInvalidated = true
        stopwatch.scheduledDispatchInterrupted = true
    end
end

local function BeginScheduledCallbackDispatch(stopwatch)
    stopwatch.scheduledCallbackDepth = (stopwatch.scheduledCallbackDepth or 0) + 1
end

local function EndScheduledCallbackDispatch(stopwatch, name, proxy)
    stopwatch.scheduledCallbackDepth = stopwatch.scheduledCallbackDepth - 1
    if stopwatch.scheduledCallbackDepth == 0 then
        FlushPendingStopCallback(stopwatch, name, proxy)
    end
end


local function RealignIntervalCount(stopwatch)
    -- Interval callbacks are catch-up based on how many thresholds have been crossed.
    -- When elapsed time or interval length changes manually, we rebase the counter to
    -- the current frame count so missed intervals are not replayed retroactively.
    if stopwatch.intervalFrames then
        local frames = stopwatch.elapsedTime:GetFrameCount()
        stopwatch.lastIntervalCount = floor(frames / stopwatch.intervalFrames)
    else
        stopwatch.lastIntervalCount = 0
    end
end

local function ApplyIntervalFrames(stopwatch, frames)
    stopwatch.intervalFrames = frames
    RealignIntervalCount(stopwatch)
end

local function CompileTimeTriggers(timeTriggers)
    local compiledTriggers = {}
    for i = 1, #timeTriggers do
        local triggerData = timeTriggers[i]
        compiledTriggers[i] = {
            frame = SecondsToFrames(triggerData.at),
            func = triggerData.func,
            args = triggerData.args,
            publicIndex = i,
        }
    end
    sort(compiledTriggers, function(left, right)
        if left.frame == right.frame then
            return left.publicIndex < right.publicIndex
        end
        return left.frame < right.frame
    end)
    return compiledTriggers
end

local function RealignTimeTriggerCursor(stopwatch)
    local compiledTriggers = stopwatch.compiledTimeTriggers or {}
    local currentFrame = stopwatch.elapsedTime:GetFrameCount()
    local nextTriggerIndex = 1
    while nextTriggerIndex <= #compiledTriggers and compiledTriggers[nextTriggerIndex].frame <= currentFrame do
        nextTriggerIndex = nextTriggerIndex + 1
    end
    stopwatch.nextTimeTriggerIndex = nextTriggerIndex
end

local function RebuildTimeTriggers(stopwatch)
    -- Public/persisted trigger data stays in stopwatch.timeTriggers. Runtime code uses
    -- a compiled frame cache plus a cursor rebuilt from the current elapsed time.
    local timeTriggers = stopwatch.timeTriggers or {}
    stopwatch.timeTriggers = timeTriggers
    stopwatch.compiledTimeTriggers = CompileTimeTriggers(timeTriggers)
    RealignTimeTriggerCursor(stopwatch)
end

local function SyncDisplayText(stopwatch, name)
    local ds = stopwatchStrings[name]
    if ds then
        ds:SetKey(GenerateTimeFormattedString(stopwatch.elapsedTime, stopwatch.timeFormat))
        stopwatch.lastRenderedFrameCount = stopwatch.elapsedTime:GetFrameCount()
    end
end

local function GetStopwatchOrWarn(name, callerName)
    local stopwatch = stopwatches[name]
    if stopwatch then
        return stopwatch
    end
    LogMessage("Warning in Stopwatch:" .. callerName .. "(): stopwatch '" .. name .. "' no longer exists.", logLevelWarning)
    return nil
end

----
-- Key concepts.
-- @section keyConcepts

---
-- Time values and frame precision.
-- @summaryonly
-- @note FramePrecision "Frame precision"
--
-- Stopwatch is frame-based and updates at 30 FPS. Time arguments are written in seconds.
-- Values are rounded to 2 decimal places before validation and conversion to game frames.
-- After rounding, timing values such as `maxTime`, `intervalTime`, and time trigger `at`
-- must be at least `0.03` seconds, which is 1 frame at 30 FPS.
--
-- Examples:
--
-- - `0.03` is valid and means 1 frame.
-- - `0.029` is valid because it rounds to `0.03`.
-- - `0.02` is rejected because it remains below `0.03`.

---
-- Laps and splits.
-- @summaryonly
-- @note LapsAndSplits "Laps and splits"
--
-- A lap is a recorded checkpoint on the stopwatch timeline.
-- From each recorded lap, Stopwatch exposes two related values:
--
-- - `lap time`: the duration of that segment only, measured from the previous lap (or from start if this is the first lap).
-- - `split time`: the cumulative elapsed time from start to that lap.
--
-- Timeline diagram:
--
--    Start --- 2s --- Lap1 --- 3s --- Lap2 --- 2s --- Lap3
--    Lap Time:         2s              3s              2s
--    Split Time:       2s              5s              7s
--
-- Use @{Stopwatch:Lap} to record a lap.
--
-- Use @{Stopwatch:GetLapTime}, @{Stopwatch:GetLapTimeInSeconds}, and @{Stopwatch:GetLapTimeFormatted} for per-segment values.
--
-- Use @{Stopwatch:GetSplitTime}, @{Stopwatch:GetSplitTimeInSeconds}, and @{Stopwatch:GetSplitTimeFormatted} for cumulative values from start.
--
-- Use @{Stopwatch:GetLapCount} to count recorded laps and @{Stopwatch:ClearLaps} to clear them without resetting elapsed time.

---
-- Callbacks overview.
-- @summaryonly
-- @note Callbacks
--
-- A callback in this module is a function that Stopwatch calls for you when a specific event happens. The stopwatch is passed as the first argument, so the callback can read or change it.
--
-- The callback names used below, such as `ON_START` and `ON_INTERVAL`, are the constants listed in @{Stopwatch.CallbackTypes}.
--
-- You can assign callbacks when creating a stopwatch through @{StopwatchData}, or later with @{Stopwatch:SetCallback}.
--
-- Most callbacks are immediate: they run when the related stopwatch method actually causes that event.
--
-- `ON_INTERVAL` and `ON_MAX_TIME` are the exceptions. They are checked automatically while the stopwatch is active and not paused. `ON_INTERVAL` also needs a valid interval configured through `intervalTime` or @{Stopwatch:SetIntervalTime}.
--
-- Time triggers are a separate feature and are documented in @{TimeTriggers|Time triggers}. For the exact same-frame order between `ON_INTERVAL`, time triggers, and `ON_MAX_TIME`, see @{CallbackTriggerOrder|Callback and trigger order}. For rules on how callback functions must be defined, see @{LevelFuncsRules|LevelFuncs rules}.
--
-- <br>General rules:
--
-- - `ON_START`, `ON_RESUME`, `ON_PAUSE`, `ON_STOP`, `ON_RESET`, and `ON_LAP` are tied to their corresponding stopwatch methods.
--
-- - When `ON_RESET` is called, elapsed time is already zero, laps are already cleared, and the stopwatch is inactive and unpaused.
-- - When `ON_STOP` or `ON_MAX_TIME` is called, the stopwatch has already been marked inactive and unpaused.

---
-- Time triggers overview.
-- @summaryonly
-- @note TimeTriggers "Time triggers"
-- 
-- A time trigger is a one-shot event that runs a callback when the stopwatch reaches a specific time.
--
-- Each trigger stores:
--
-- - an `at` time
-- - a callback function
-- - optional extra arguments passed after the stopwatch argument
--
-- If extra arguments are used, they must be stored as an array table with consecutive numeric indices starting at 1, and they must not contain `nil` values.
-- 
-- The `at` value is rounded to 2 decimal places and then converted to the nearest frame at 30 FPS. In other words, time triggers work on the game's frame grid, not with exact floating-point timing.
-- 
-- Time trigger callbacks follow the same authoring rules described in @{LevelFuncsRules|LevelFuncs rules}.
-- 
-- Time triggers are checked automatically while the stopwatch is active and not paused. For ordering relative to `ON_INTERVAL` and `ON_MAX_TIME`, see @{CallbackTriggerOrder|Callback and trigger order}.
-- 
-- If more than one timeTrigger falls on the same frame, they are called in the same order they appear in `timeTriggers`.
-- 
-- Time triggers fire once on the current timeline. If elapsed time is moved backwards, or the stopwatch is restarted from zero with `Stopwatch:Start(true)` or @{Stopwatch:Reset}, future timeTriggers are armed again from that new time.
-- 
-- If elapsed time is moved forward, past timeTriggers are not replayed; the next future trigger is recalculated from the new time.
-- 

---
-- LevelFuncs rules.
-- @summaryonly
-- @note LevelFuncsRules "LevelFuncs rules"
--
-- Stopwatch callbacks and time trigger functions must be functions stored in `LevelFuncs`.
-- Do not pass a local anonymous function directly.
--
-- Define the LevelFuncs function before assigning it to a stopwatch through `Stopwatch.Create`,
-- `Stopwatch:SetCallback`, or a time trigger. If it is assigned before it exists, the value passed
-- to Stopwatch is `nil` and the callback will not be registered.
--
-- **Bad**: `LevelFuncs.OnRaceTimerLap` is `nil` at this point.
--
--    Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnRaceTimerLap)
--
--    LevelFuncs.OnRaceTimerLap = function(stopwatch)
--        TEN.Util.PrintLog("Lap " .. stopwatch:GetLapCount(), TEN.Util.LogLevel.INFO)
--    end
--
-- **Good**: define the function first, then assign it.
--    LevelFuncs.OnRaceTimerLap = function(stopwatch)
--        TEN.Util.PrintLog("Lap " .. stopwatch:GetLapCount(), TEN.Util.LogLevel.INFO)
--    end
--
--    Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnRaceTimerLap)

---
-- Callback and trigger order.
-- @summaryonly
-- @note CallbackTriggerOrder "Callback and trigger order"
--
-- While the stopwatch is active and not paused, Stopwatch checks its scheduled events automatically.
--
-- If everything happens on the same frame, the order is:
--
--    time ---->
--    [frame update] -> [ON_INTERVAL] -> [timeTrigger 1] -> [timeTrigger 2] -> [ON_MAX_TIME]
--
-- If more than one timeTrigger is due on that frame, they run in the order they appear in `timeTriggers`.
--
-- @{Stopwatch:Stop} does not force an extra `ON_INTERVAL` callback.
--
-- If @{Stopwatch:Stop} is called on a frame where an interval is also due, `ON_INTERVAL` runs only if that frame had already been checked before @{Stopwatch:Stop} was called.
--
-- If @{Stopwatch:Stop} is called inside `ON_INTERVAL` or inside a timeTrigger callback, the current callback finishes first. Then `ON_STOP` is called, and the rest of that frame's scheduled work is skipped.
--
--    time ---->
--    [same frame] -> [current callback finishes] -> [ON_STOP] -> [rest skipped]
--
-- If a scheduled callback changes elapsed time or changes the time trigger setup during that same update, the remaining scheduled callbacks for that frame are skipped.
--
-- Reaching `maxTime` stops the stopwatch and calls `ON_MAX_TIME`, but it does not also call `ON_STOP`.

---
-- Save/load behavior.
-- @summaryonly
-- @note Persistence "Save/load behavior"
--
-- Stopwatch state is stored in `LevelVars`, so elapsed time, active state, laps, callbacks, intervals, and time triggers are preserved by save/load.
-- Display strings are recreated automatically after loading.

----
-- Functions
-- @section functions

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
--     timeFormat = { seconds = true, centiseconds = true },
--     position = TEN.Vec2(90, 10),
--     scale = 1.5,
--     color = TEN.Color(0, 255, 0, 255),
--     pausedColor = TEN.Color(255, 0, 0, 255),
--     textOptions = options,
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
        InvalidateScheduledState(stopwatches[stopwatchData.name])
        local ds = stopwatchStrings[stopwatchData.name]
        if ds then
            HideString(ds)
        end
        stopwatchStrings[stopwatchData.name] = nil
    end
    -- Stopwatch objects are name-only proxies, so overwriting by name replaces the
    -- stored table instead of mutating the previous one in place.
    stopwatches[stopwatchData.name] = {}
    local stopwatchEntry = stopwatches[stopwatchData.name]
    local name = stopwatchData.name

    -- check timeFormat
    local timeFormat = stopwatchData.timeFormat or false
        stopwatchEntry.timeFormat = CheckTimeFormat(timeFormat, "Warning in Stopwatch.Create(): wrong value for timeFormat, timeFormat for '" .. name .. "' stopwatch will be set to false")


    -- check maxTime
    if IsNull(stopwatchData.maxTime) then
        stopwatchEntry.maxTime = nil
    else
        local invalidValueMessage = CreateWarningPrefix .. "wrong value for maxTime for '" .. name .. "', it must be a positive number."
        local tooSmallMessage = CreateWarningPrefix .. "maxTime too small for '" .. name .. "'. Minimum is " .. MIN_FRAME_SECONDS .. "s (1 frame at 30 FPS)."
        local frames = ValidateFrameSeconds(stopwatchData.maxTime, invalidValueMessage, tooSmallMessage, logLevelWarning)
        if frames then
            stopwatchEntry.maxTime = Time(frames)
        else
            stopwatchEntry.maxTime = nil
        end
    end

    -- check position
        stopwatchEntry.position = validate(stopwatchData.position, IsVec2(stopwatchData.position), DEFAULT_POSITION, "wrong position for '" .. name .. "', set to default")
    if stopwatchEntry.position ~= DEFAULT_POSITION then
        stopwatchEntry.position = Vec2(PercentToScreen(stopwatchData.position.x, stopwatchData.position.y))
    end

    -- check scale
        stopwatchEntry.scale = validate(stopwatchData.scale, IsNumber(stopwatchData.scale) and stopwatchData.scale > 0, 1, "wrong scale for '" .. name .. "', set to 1")

    -- check color
        stopwatchEntry.color = validate(stopwatchData.color, IsColor(stopwatchData.color), DEFAULT_COLOR, "wrong color for '" .. name .. "', set to default")

    -- check pausedColor
        stopwatchEntry.pausedColor = validate(stopwatchData.pausedColor, IsColor(stopwatchData.pausedColor), DEFAULT_PAUSED_COLOR, "wrong pausedColor for '" .. name .. "', set to default")

    -- check textOptions
        local warning1Message = CreateWarningPrefix .. "textOptions must be a table. Stopwatch '" .. name .. "' will use default textOptions."
        local warning2Message = CreateWarningPrefix .. "all values in textOptions must be of type TEN.Strings.DisplayStringOption. Stopwatch '" .. name .. "' will use default textOptions."
    local textOptions = CheckTextOptions(stopwatchData.textOptions, warning1Message, warning2Message)
    stopwatchEntry.textOptions = textOptions

    -- Persisted/public stopwatch state.
    stopwatchEntry.elapsedTime = ZERO
    stopwatchEntry.active = false
    stopwatchEntry.paused = false
    stopwatchEntry.laps = {}
    stopwatchEntry.callbacks = {}
    stopwatchEntry.intervalFrames = nil
    stopwatchEntry.lastIntervalCount = 0
    stopwatchEntry.timeTriggers = {}

    -- Runtime-only bookkeeping rebuilt from the persisted state when needed.
    stopwatchEntry.lastRenderedFrameCount = nil
    stopwatchEntry.pendingStopCallback = false
    stopwatchEntry.scheduledCallbackDepth = 0
    stopwatchEntry.scheduledDispatchInterrupted = false
    stopwatchEntry.scheduledStateInvalidated = false

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
        local invalidValueMessage = CreateWarningPrefix .. "wrong value for intervalTime in '" .. name .. "', it must be a positive number."
        local tooSmallMessage = CreateWarningPrefix .. "intervalTime too small for '" .. name .. "'. Minimum is " .. MIN_FRAME_SECONDS .. "s (1 frame at 30 FPS)."
        local frames = ValidateFrameSeconds(stopwatchData.intervalTime, invalidValueMessage, tooSmallMessage, logLevelWarning)
        if frames then
            ApplyIntervalFrames(stopwatchEntry, frames)
        end
    end

    local timeTriggers = NormalizeTimeTriggerList(
        stopwatchData.timeTriggers,
        CreateWarningPrefix .. "timeTriggers for '" .. name .. "' must be an array table.",
        CreateWarningPrefix .. "timeTriggers",
        " for '" .. name .. "'",
        logLevelWarning
    )
    if timeTriggers then
        stopwatchEntry.timeTriggers = timeTriggers
    end
    RebuildTimeTriggers(stopwatchEntry)

    if stopwatchEntry.timeFormat then
        local initText = GenerateTimeFormattedString(ZERO, stopwatchEntry.timeFormat)
        stopwatchStrings[name] = DisplayString(initText, stopwatchEntry.position, stopwatchEntry.scale, DEFAULT_COLOR, false, stopwatchEntry.textOptions)
        stopwatchEntry.lastRenderedFrameCount = ZERO:GetFrameCount()
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
            InvalidateScheduledState(stopwatches[name])
            stopwatches[name] = nil
            local ds = stopwatchStrings[name]
            if ds then
                HideString(ds)
            end
            stopwatchStrings[name] = nil
        else
            LogMessage("Warning in Stopwatch.Delete(): no stopwatch found with name '" .. tostring(name) .. "'.", logLevelWarning)
        end
    end
end

--- Get a stopwatch by name.
-- @tparam string name The name of the stopwatch to retrieve.
-- @treturn[1] Stopwatch The stopwatch object if found
-- @treturn[2] nil If no stopwatch with the given name exists, with a warning message logged to the console.
-- @usage
-- local myStopwatch = Stopwatch.Get("MyStopwatch")
Stopwatch.Get = function(name)
    local errorPrefix = "in Stopwatch.Get(): "
    if not IsString(name) then
        return LogMessage("Error " .. errorPrefix .. "name must be a string.", logLevelError)
    end
    if not stopwatches[name] then
        return LogMessage("Warning " .. errorPrefix .. "no stopwatch found with name '" .. tostring(name) .. "'.", logLevelWarning)
    end
    return CreateStopwatchProxy(name)
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
-- The list of all methods for Stopwatch objects.
-- @type Stopwatch
-- Main method groups in this class:
--
-- - State changes: @{Stopwatch:Start}, @{Stopwatch:Pause}, @{Stopwatch:Stop}, @{Stopwatch:Reset}.
--
-- - State queries: @{Stopwatch:IsActive}, @{Stopwatch:IsPaused}, @{Stopwatch:IsTicking}.
--
-- - Time and limits: elapsed time, maxTime, and comparison helpers.
--
-- - Display and styling: position, scale, colors, and text options.
--
-- - Laps and splits.
--
-- - Callbacks and interval configuration.
--
-- - Absolute time triggers.
--
-- Use @{Stopwatch.Get} before calling methods when the stopwatch may not exist.
-- @usage
--	-- Examples of some methods
-- Stopwatch.Get("MyStopwatch"):Start()
-- Stopwatch.Get("MyStopwatch"):Pause()
-- Stopwatch.Get("MyStopwatch"):Stop()

--- Start or resume the stopwatch.
-- If `reset` is true, elapsed time, laps, interval scheduling, and future timeTriggers are rebuilt from zero before starting.
-- @tparam[opt=false] bool reset If true, resets the stopwatch to zero before starting. If false or not provided, the stopwatch will continue from its current time.
-- @usage
-- -- Example 1: Start the stopwatch
-- Stopwatch.Get("MyStopwatch"):Start()
--
-- -- Example 2: Start the stopwatch and reset its time to zero
-- Stopwatch.Get("MyStopwatch"):Start(true)
function Stopwatch:Start(reset)
    local stopwatch = GetStopwatchOrWarn(self.name, "Start")
    if not stopwatch then
        return
    end
    local wasActive = stopwatch.active
    local wasPaused = stopwatch.paused
    if IsNull(reset) then
        reset = false
    elseif not IsBoolean(reset) then
        LogMessage("Warning in Stopwatch:Start(): wrong value (" .. tostring(reset) .. ") for reset parameter, it should be a boolean. Defaulting to false.", logLevelWarning)
        reset = false
    end
    if reset then
        stopwatch.elapsedTime = ZERO
        stopwatch.laps = {}
        stopwatch.lastIntervalCount = 0
        RebuildTimeTriggers(stopwatch)
    end
    -- Starting again clears any deferred OnStop left behind by Stop() inside a
    -- scheduled callback.
    stopwatch.pendingStopCallback = false
    stopwatch.active = true
    stopwatch.paused = false
    local proxy = CreateStopwatchProxy(self.name)
    if not wasActive or reset then
        FireCallback(stopwatch, "OnStart", proxy)
    elseif wasPaused then
        FireCallback(stopwatch, "OnResume", proxy)
    end
end

--- Pause the stopwatch if it is active.
-- Calling this on an inactive or already paused stopwatch has no effect.
-- @usage
-- Stopwatch.Get("MyStopwatch"):Pause()
function Stopwatch:Pause()
    local stopwatch = GetStopwatchOrWarn(self.name, "Pause")
    if not stopwatch then
        return
    end
    if stopwatch.active and not stopwatch.paused then
        InterruptScheduledDispatch(stopwatch)
        stopwatch.paused = true
        FireCallback(stopwatch, "OnPause", CreateStopwatchProxy(self.name))
    end
end

--- Stop the stopwatch.
-- If the stopwatch is active, this calls `ON_STOP` from @{Stopwatch.CallbackTypes} after the stopwatch has already been marked as stopped.
-- For same-frame ordering and overlap with other callbacks, see @{Callbacks|Callbacks overview}.
-- @tparam[opt=nil] float displayTime If provided, the stopwatch display will remain visible for this many seconds after stopping. Must be a positive number. If not provided or nil, the display is hidden immediately.
-- @usage
-- -- Example 1: Stop the stopwatch and hide the display immediately
-- Stopwatch.Get("MyStopwatch"):Stop()
--
-- -- Example 2: Stop the stopwatch and keep the display visible for 2 seconds
-- Stopwatch.Get("MyStopwatch"):Stop(2.0)
function Stopwatch:Stop(displayTime)
    local stopwatch = GetStopwatchOrWarn(self.name, "Stop")
    if not stopwatch then
        return
    end
    local wasActive = stopwatch.active
    stopwatch.active = false
    stopwatch.paused = false
    if wasActive then
        local proxy = CreateStopwatchProxy(self.name)
        -- If Stop() happens during a scheduled callback, firing OnStop immediately
        -- would make the callback sequence re-entrant. We mark the stopwatch as
        -- stopped now and flush OnStop once the outer scheduled callback unwinds.
        if IsScheduledCallbackRunning(stopwatch) then
            InterruptScheduledDispatch(stopwatch)
            stopwatch.pendingStopCallback = true
        else
            FireCallback(stopwatch, "OnStop", proxy)
        end
    end
    local ds = stopwatchStrings[self.name]
    if ds then
        if displayTime ~= nil then
            if not IsNumber(displayTime) or displayTime <= 0 then
                LogMessage("Warning in Stopwatch:Stop(): wrong value (" .. tostring(displayTime) .. ") for displayTime, the stopwatch display will be hidden immediately.", logLevelWarning)
                HideString(ds)
            else
                if stopwatch.timeFormat then
                    SyncDisplayText(stopwatch, self.name)
                    ds:SetColor(stopwatch.color)
                end
                ShowString(ds, displayTime, false)
            end
        else
            HideString(ds)
        end
    end
end

--- Reset the stopwatch to zero and stop it.
--
-- If `ON_RESET` is configured, it is called after elapsed time, laps, active state, and display state have been reset.
-- @usage
-- Stopwatch.Get("MyStopwatch"):Reset()
function Stopwatch:Reset()
    local stopwatch = GetStopwatchOrWarn(self.name, "Reset")
    if not stopwatch then
        return
    end
    InvalidateScheduledState(stopwatch)
    stopwatch.elapsedTime = ZERO
    stopwatch.active = false
    stopwatch.paused = false
    stopwatch.laps = {}
    stopwatch.lastIntervalCount = 0
    RebuildTimeTriggers(stopwatch)
    stopwatch.lastRenderedFrameCount = ZERO:GetFrameCount()
    stopwatch.pendingStopCallback = false
    local ds = stopwatchStrings[self.name]
    if ds then
        HideString(ds)
    end
    FireCallback(stopwatch, "OnReset", CreateStopwatchProxy(self.name))
end

--- Check if the stopwatch is active.
-- @treturn bool True if the stopwatch is active, false otherwise.
-- @usage
-- Example: Activate a post-process effect only if the stopwatch is active
-- if Stopwatch.Get("MyStopwatch"):IsActive() then
--     TEN.View.SetPostProcessMode(TEN.View.PostProcessMode.EXCLUSION)
-- end
function Stopwatch:IsActive()
    local stopwatch = GetStopwatchOrWarn(self.name, "IsActive")
    return stopwatch and stopwatch.active or false
end

--- Check if the stopwatch is in paused state.
-- @treturn bool True if the stopwatch is paused, false otherwise.
-- @usage
-- local isPaused = Stopwatch.Get("MyStopwatch"):IsPaused()
function Stopwatch:IsPaused()
    local stopwatch = GetStopwatchOrWarn(self.name, "IsPaused")
    return stopwatch and stopwatch.paused or false
end

--- Check if the stopwatch is currently ticking.
-- Returns `true` if the stopwatch is active and not paused.
-- @treturn bool True if the stopwatch is ticking, false otherwise.
function Stopwatch:IsTicking()
    local stopwatch = GetStopwatchOrWarn(self.name, "IsTicking")
    return stopwatch and stopwatch.active and not stopwatch.paused or false
end

--- Get the elapsed time of the stopwatch.
-- @treturn Time The elapsed time of the stopwatch in game frames.
-- @usage
-- local elapsedTime = Stopwatch.Get("MyStopwatch"):GetElapsedTime()
function Stopwatch:GetElapsedTime()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetElapsedTime")
    if stopwatch then
        return stopwatch.elapsedTime
    end
    return nil
end

--- Get the elapsed time of the stopwatch in seconds.
-- @treturn float The elapsed time of the stopwatch in seconds.
-- @usage
-- local elapsedTimeInSeconds = Stopwatch.Get("MyStopwatch"):GetElapsedTimeInSeconds()
function Stopwatch:GetElapsedTimeInSeconds()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetElapsedTimeInSeconds")
    if stopwatch then
        return FramesToSeconds(stopwatch.elapsedTime:GetFrameCount())
    end
    return nil
end

--- Get the elapsed time of the stopwatch formatted as a string.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use for the time string. Omit it or pass `nil` to use the default format. Pass `false` to return an empty string. Invalid values log a warning and also use the default format. See `timeFormat` for details.<br>
-- @treturn string The formatted time string.
-- @usage
-- local timeFormat = { minutes = true, seconds = true}
-- local elapsedTimeFormatted = Stopwatch.Get("MyStopwatch"):GetElapsedTimeFormatted(timeFormat)
function Stopwatch:GetElapsedTimeFormatted(timeFormat)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetElapsedTimeFormatted")
    if stopwatch then
        timeFormat = NormalizeTimeFormat(timeFormat, "Warning in Stopwatch:GetElapsedTimeFormatted(): wrong value for timeFormat, default format will be used.")
        return GenerateTimeFormattedString(stopwatch.elapsedTime, timeFormat)
    end
    return nil
end

--- Set the elapsed time of the stopwatch.
-- @tparam float newTime The new time for the stopwatch in seconds with 2 decimal places<br>
-- Negative values are not allowed; 0 is allowed. Time stays frame-based: the input is rounded to 2 decimal places before conversion to game frames. See @{FramePrecision|Time values and frame precision}.
-- If an `ON_INTERVAL` callback from @{Stopwatch.CallbackTypes} is configured, the next interval callback is recalculated from the new elapsed time.
-- The next due timeTrigger is also recalculated from the new elapsed time. Past triggers are not replayed immediately; moving time backwards re-arms future triggers from the new position.
-- @usage
-- Stopwatch.Get("MyStopwatch"):SetElapsedTime(30.5) -- Set time to 30.5 seconds
function Stopwatch:SetElapsedTime(newTime)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetElapsedTime")
    if not stopwatch then
        return
    end
    if not IsNumber(newTime) or newTime < 0 then
        LogMessage("Error in Stopwatch:SetElapsedTime(): wrong value (" .. tostring(newTime) .. ") for newTime, it must be a non-negative number.", logLevelError)
    else
        InvalidateScheduledState(stopwatch)
        stopwatch.elapsedTime = SecondsToTime(newTime)
        -- Manual time jumps must immediately rebase interval scheduling and, if shown,
        -- refresh the display without waiting for the next frame.
        RealignIntervalCount(stopwatch)
        RealignTimeTriggerCursor(stopwatch)
        if stopwatch.timeFormat then
            SyncDisplayText(stopwatch, self.name)
        end
    end
end

--- Check if the elapsed time of the stopwatch meets a specific condition.
--
-- Use this method instead of manual elapsed-time comparisons to avoid rounding and frame-conversion errors.
-- @tparam Operators operator The comparison operator to use.
--
-- Use one of the values from `Stopwatch.Operators`, for example `Stopwatch.Operators.EQUAL` or `Stopwatch.Operators.GREATER_EQUAL`.
-- @tparam float seconds The value in seconds to compare.<br>
-- No negative values allowed. The comparison uses the same frame-based conversion described in @{FramePrecision|Time values and frame precision}.<br>
-- For continuous checks, call this from the *OnLoop* event and only while the stopwatch is active @{Stopwatch.IsActive}.
-- @treturn bool True if the condition is met, false otherwise.
-- @usage
-- -- Example1: Alternative method to create a sequence of events based on stopwatch time
-- LevelFuncs.OnLoop = function() -- this LevelFuncs is already present in your level script
--     local stopwatch = Stopwatch.Get("MyStopwatch")
--     if stopwatch:IsActive() then
--         if stopwatch:IfElapsedTimeIs(Stopwatch.Operators.EQUAL, 2.0) then -- If elapsed time is equal to 2.0 seconds
--             -- Do something
--         end
--         if stopwatch:IfElapsedTimeIs(Stopwatch.Operators.EQUAL, 4.0) then -- If elapsed time is equal to 4.0 seconds
--             -- Do something else
--         end
--         if stopwatch:IfElapsedTimeIs(Stopwatch.Operators.EQUAL, 6.0) then -- If elapsed time is equal to 6.0 seconds
--             -- Do another thing
--         end
--     end
-- end
--
-- -- Example2: Using callbacks
-- LevelFuncs.MySequenceOfEvents = function()
--     local stopwatch = Stopwatch.Get("MyStopwatch")
--     if stopwatch:IsActive() then
--         if stopwatch:IfElapsedTimeIs(Stopwatch.Operators.EQUAL, 3.0) then -- If elapsed time is equal to 3.0 seconds
--             -- Do something
--         end
--         if stopwatch:IfElapsedTimeIs(Stopwatch.Operators.EQUAL, 5.0) then -- If elapsed time is equal to 5.0 seconds
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
    local stopwatch = GetStopwatchOrWarn(self.name, "IfElapsedTimeIs")
    if not stopwatch then
        return false
    end
    local time = SecondsToTime(seconds)
    return op(stopwatch.elapsedTime, time)
end

--- Get the maximum time of the stopwatch.
-- @treturn[1] Time The maximum time of the stopwatch in game frames
-- @treturn[2] nil If no maximum time is set.
-- @usage
-- local maxTime = Stopwatch.Get("MyStopwatch"):GetMaxTime()
function Stopwatch:GetMaxTime()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetMaxTime")
    if stopwatch then
        return stopwatch.maxTime
    end
    return nil
end

--- Get the maximum time of the stopwatch in seconds.
-- @treturn[1] float The maximum time of the stopwatch in seconds.
-- @treturn[2] nil If no maximum time is set.
-- @usage
-- local maxTimeInSeconds = Stopwatch.Get("MyStopwatch"):GetMaxTimeInSeconds()
function Stopwatch:GetMaxTimeInSeconds()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetMaxTimeInSeconds")
    if not stopwatch then
        return nil
    end
    local maxTime = stopwatch.maxTime
    if maxTime then
        return FramesToSeconds(maxTime:GetFrameCount())
    end
    return nil
end

--- Get the maximum time of the stopwatch formatted as a string.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = false}] table|bool timeFormat The format to use for the time string. Omit it or pass `nil` to use the default format. Pass `false` to return an empty string. Invalid values log a warning and also use the default format. See `timeFormat` for details.<br>
-- @treturn[1] string The formatted maximum time string.
-- @treturn[2] nil If no maximum time is set.
-- @usage
-- local timeFormat = { minutes = true, seconds = true}
-- local maxTimeFormatted = Stopwatch.Get("MyStopwatch"):GetMaxTimeFormatted(timeFormat)
function Stopwatch:GetMaxTimeFormatted(timeFormat)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetMaxTimeFormatted")
    if not stopwatch then
        return nil
    end
    timeFormat = NormalizeTimeFormat(timeFormat, "Warning in Stopwatch:GetMaxTimeFormatted(): wrong value for timeFormat, default format will be used.")
    local maxTime = stopwatch.maxTime
    if maxTime then
        return GenerateTimeFormattedString(maxTime, timeFormat)
    end
    return nil
end

--- Set the maximum time for the stopwatch.
-- @tparam[opt=nil] float maxTime The maximum time for the stopwatch in seconds with 2 decimal places. If set, the stopwatch will automatically stop when this time is reached. Pass nil to remove the limit. Values must be positive. They are rounded to 2 decimal places first; after rounding, they must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}.
-- @usage
-- Stopwatch.Get("MyStopwatch"):SetMaxTime(60) -- Set max time to 60 seconds
--
-- -- Example: Remove max time limit
-- Stopwatch.Get("MyStopwatch"):SetMaxTime()
function Stopwatch:SetMaxTime(maxTime)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetMaxTime")
    if not stopwatch then
        return
    end
    if IsNull(maxTime) then
        InvalidateScheduledState(stopwatch)
        stopwatch.maxTime = nil
    else
        local invalidValueMessage = "Error in Stopwatch:SetMaxTime(): wrong value (" .. tostring(maxTime) .. ") for maxTime, it must be a positive number or nil."
        local tooSmallMessage = "Error in Stopwatch:SetMaxTime(): maxTime too small for '" .. self.name .. "'. Minimum is " .. MIN_FRAME_SECONDS .. "s (1 frame at 30 FPS)."
        local frames = ValidateFrameSeconds(maxTime, invalidValueMessage, tooSmallMessage, logLevelError)
        if frames then
            InvalidateScheduledState(stopwatch)
            stopwatch.maxTime = Time(frames)
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
    local stopwatch = GetStopwatchOrWarn(self.name, "HasMaxTime")
    return stopwatch and stopwatch.maxTime ~= nil or false
end

--- Check if the stopwatch maximum time meets a specific condition.
-- Use this method instead of manual maxTime comparisons to avoid rounding and frame-conversion errors.
-- @tparam Operators operator The type of comparison.
--
-- Use one of the values from `Stopwatch.Operators`, for example `Stopwatch.Operators.LESS` or `Stopwatch.Operators.GREATER_EQUAL`.
-- @tparam float seconds The value in seconds to compare.<br>
-- No negative values allowed. The comparison uses the same frame-based conversion described in @{FramePrecision|Time values and frame precision}.<br>
-- Check @{Stopwatch.HasMaxTime} before calling this method if the stopwatch may not have a maxTime.
-- @treturn bool True if the condition is met, false otherwise.
-- @usage
-- -- Check if the max time is less than 60 seconds
-- if Stopwatch.Get("MyStopwatch"):HasMaxTime() and Stopwatch.Get("MyStopwatch"):IfMaxTimeIs(Stopwatch.Operators.LESS, 60) then
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
    local stopwatch = GetStopwatchOrWarn(self.name, "IfMaxTimeIs")
    if not stopwatch then
        return false
    end
    if not stopwatch.maxTime then
        LogMessage("Warning in Stopwatch:IfMaxTimeIs(): no maxTime set for '" .. self.name .. "' stopwatch", logLevelWarning)
        return false
    end
    local time = SecondsToTime(seconds)
    return op(stopwatch.maxTime, time)
end

--- Get the position of the stopwatch on screen.
-- @treturn Vec2 The position of the stopwatch in percentage (0 to 100).
-- @usage
-- local position = Stopwatch.Get("MyStopwatch"):GetPosition()
function Stopwatch:GetPosition()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetPosition")
    if stopwatch then
        local position = stopwatch.position
        return Vec2(ScreenToPercent(position.x, position.y))
    end
    return nil
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
    x = DefaultIfNil(x, 50)
    y = DefaultIfNil(y, 90)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetPosition")
    if not stopwatch then
        return
    end
    if not IsNumber(x) or not IsNumber(y) then
        LogMessage("Error in Stopwatch:SetPosition(): x and y must be numbers.", logLevelError)
    else
        local newPos = Vec2(PercentToScreen(x, y))
        stopwatch.position = newPos
        local ds = stopwatchStrings[self.name]
        if ds then
            ds:SetPosition(newPos)
        end
    end
end

--- Get the scale of the stopwatch display.
-- @treturn float The scale factor.
-- @usage
-- local scale = Stopwatch.Get("MyStopwatch"):GetScale()
function Stopwatch:GetScale()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetScale")
    if stopwatch then
        return stopwatch.scale
    end
    return nil
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
    scale = DefaultIfNil(scale, 1)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetScale")
    if not stopwatch then
        return
    end
    if not IsNumber(scale) or scale <= 0 then
        LogMessage("Error in Stopwatch:SetScale(): scale must be a positive number.", logLevelError)
    else
        stopwatch.scale = scale
        local ds = stopwatchStrings[self.name]
        if ds then
            ds:SetScale(scale)
        end
    end
end

--- Get the color of the stopwatch display.
-- @treturn Color The color of the stopwatch display.
-- @usage
-- local color = Stopwatch.Get("MyStopwatch"):GetColor()
function Stopwatch:GetColor()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetColor")
    if stopwatch then
        return stopwatch.color
    end
    return nil
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
    color = DefaultIfNil(color, DEFAULT_COLOR)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetColor")
    if not stopwatch then
        return
    end
    if not IsColor(color) then
        LogMessage("Error in Stopwatch:SetColor(): color must be a Color object.", logLevelError)
    else
        stopwatch.color = color
    end
end

--- Get the color of the stopwatch display when paused.
-- @treturn Color The color of the stopwatch display when paused.
-- @usage
-- local pausedColor = Stopwatch.Get("MyStopwatch"):GetPausedColor()
function Stopwatch:GetPausedColor()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetPausedColor")
    if stopwatch then
        return stopwatch.pausedColor
    end
    return nil
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
    color = DefaultIfNil(color, DEFAULT_PAUSED_COLOR)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetPausedColor")
    if not stopwatch then
        return
    end
    if not IsColor(color) then
        LogMessage("Error in Stopwatch:SetPausedColor(): color must be a Color object.", logLevelError)
        return
    end
    stopwatch.pausedColor = color
end

--- Get the text options used by the stopwatch display.
-- Returns a copy of the current options table, so changing it does not affect the stopwatch until you pass it to @{Stopwatch:SetTextOptions}.
-- @treturn table A table containing values from @{Strings.DisplayStringOption}.
-- @usage
-- local textOptions = Stopwatch.Get("MyStopwatch"):GetTextOptions()
function Stopwatch:GetTextOptions()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetTextOptions")
    if stopwatch then
        local textOptions = stopwatch.textOptions or DEFAULT_TEXT_OPTIONS
        return CloneArray(textOptions)
    end
    return nil
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
    local stopwatch = GetStopwatchOrWarn(self.name, "SetTextOptions")
    if not stopwatch then
        return
    end
    local warning1Message = "Warning in Stopwatch:SetTextOptions(): optionsTable must be a table. Stopwatch '" .. self.name .. "' will use default textOptions."
    local warning2Message = "Warning in Stopwatch:SetTextOptions(): all values in optionsTable must be of type TEN.Strings.DisplayStringOption. Stopwatch '" .. self.name .. "' will use default textOptions."
    local newOptions = CheckTextOptions(optionsTable, warning1Message, warning2Message)
    stopwatch.textOptions = newOptions
    local ds = stopwatchStrings[self.name]
    if ds then
        ds:SetFlags(newOptions)
    end
end

--- Record a lap and return the delta time of the completed segment.
-- Stores the current elapsed time as a split internally. The returned delta is the time elapsed since
-- the previous @{Stopwatch:Lap} call, or since @{Stopwatch:Start} if this is the first lap.
-- Can be called while the stopwatch is active, even if paused.
-- See @{Stopwatch.LapsAndSplits|Laps and splits} in Key concepts.
-- @treturn[1] Time The delta time of the completed lap segment.
-- @treturn[2] nil If the stopwatch is not active, with a warning logged to the console.
-- @usage
-- -- Record a lap at each checkpoint and immediately print the segment time
-- LevelFuncs.OnCheckpoint = function()
--     local sw = Stopwatch.Get("RaceTimer")
--     local lapIndex = sw:GetLapCount() + 1
--     sw:Lap()
--     local fmt = { seconds = true, centiseconds = true }
--     TEN.Util.PrintLog("Checkpoint " .. lapIndex .. ": " .. sw:GetLapTimeFormatted(lapIndex, fmt), TEN.Util.LogLevel.INFO)
-- end
function Stopwatch:Lap()
    local stopwatch = GetStopwatchOrWarn(self.name, "Lap")
    if not stopwatch then
        return nil
    end
    if not stopwatch.active then
        LogMessage("Warning in Stopwatch:Lap(): stopwatch '" .. self.name .. "' is not active.", logLevelWarning)
        return nil
    end
    insert(stopwatch.laps, stopwatch.elapsedTime)
    local lapIndex   = #stopwatch.laps
    local delta      = Time(GetLapDeltaFrames(stopwatch.laps, lapIndex))
    FireCallback(stopwatch, "OnLap", CreateStopwatchProxy(self.name))
    return delta
end

--- Get the number of recorded laps.
-- @treturn int The number of laps recorded so far.
-- @usage
-- local count = Stopwatch.Get("RaceTimer"):GetLapCount()
function Stopwatch:GetLapCount()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetLapCount")
    if stopwatch then
        return #stopwatch.laps
    end
    return nil
end

--- Get the delta time of a specific lap as a Time object.
-- The delta is the time elapsed during that lap segment (from the previous lap to this one, or from start for lap 1).
-- See @{Stopwatch.LapsAndSplits|Laps and splits} in Key concepts.
-- @tparam int index The 1-based lap index.
-- @treturn[1] Time The delta time of the specified lap.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local lapTime = Stopwatch.Get("RaceTimer"):GetLapTime(2)
function Stopwatch:GetLapTime(index)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetLapTime")
    if not stopwatch then
        return nil
    end
    local laps = stopwatch.laps
    if not ValidatePositiveIndex(index, #laps, "Error in Stopwatch:GetLapTime(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError) then
        return nil
    end
    return Time(GetLapDeltaFrames(laps, index))
end

--- Get the delta time of a specific lap in seconds.
-- See @{Stopwatch.LapsAndSplits|Laps and splits} in Key concepts.
-- @tparam int index The 1-based lap index.
-- @treturn[1] float The delta time of the specified lap in seconds.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local lapSec = Stopwatch.Get("RaceTimer"):GetLapTimeInSeconds(2)
function Stopwatch:GetLapTimeInSeconds(index)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetLapTimeInSeconds")
    if not stopwatch then
        return nil
    end
    local laps = stopwatch.laps
    if not ValidatePositiveIndex(index, #laps, "Error in Stopwatch:GetLapTimeInSeconds(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError) then
        return nil
    end
    return FramesToSeconds(GetLapDeltaFrames(laps, index))
end

--- Get the delta time of a specific lap formatted as a string.
-- See @{Stopwatch.LapsAndSplits|Laps and splits} in Key concepts.
-- @tparam int index The 1-based lap index.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use. Omit it or pass `nil` to use the default format. Pass `false` to return an empty string. Invalid values log a warning and also use the default format. See `timeFormat` for details.
-- @treturn[1] string The formatted delta time of the specified lap.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local fmt = { seconds = true, centiseconds = true }
-- local lapStr = Stopwatch.Get("RaceTimer"):GetLapTimeFormatted(2, fmt)
function Stopwatch:GetLapTimeFormatted(index, timeFormat)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetLapTimeFormatted")
    if not stopwatch then
        return nil
    end
    local laps = stopwatch.laps
    if not ValidatePositiveIndex(index, #laps, "Error in Stopwatch:GetLapTimeFormatted(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError) then
        return nil
    end
    timeFormat = NormalizeTimeFormat(timeFormat, "Warning in Stopwatch:GetLapTimeFormatted(): wrong value for timeFormat, default format will be used.")
    return GenerateTimeFormattedString(Time(GetLapDeltaFrames(laps, index)), timeFormat)
end

--- Get the cumulative split time at a specific lap as a Time object.
-- The split time is the total elapsed time from the start of the stopwatch to the moment @{Stopwatch:Lap} was called for that lap.
-- Use @{Stopwatch:GetLapTime} for the segment duration, and this method when you need the absolute time at a given checkpoint.
-- See @{Stopwatch.LapsAndSplits|Laps and splits} in Key concepts.
-- @tparam int index The 1-based lap index.
-- @treturn[1] Time The cumulative split time at the specified lap.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local split = Stopwatch.Get("RaceTimer"):GetSplitTime(2)
function Stopwatch:GetSplitTime(index)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetSplitTime")
    if not stopwatch then
        return nil
    end
    local laps = stopwatch.laps
    if not ValidatePositiveIndex(index, #laps, "Error in Stopwatch:GetSplitTime(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError) then
        return nil
    end
    return laps[index]
end

--- Get the cumulative split time at a specific lap in seconds.
-- See @{Stopwatch.LapsAndSplits|Laps and splits} in Key concepts.
-- @tparam int index The 1-based lap index.
-- @treturn[1] float The cumulative split time at the specified lap in seconds.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local splitSec = Stopwatch.Get("RaceTimer"):GetSplitTimeInSeconds(2)
function Stopwatch:GetSplitTimeInSeconds(index)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetSplitTimeInSeconds")
    if not stopwatch then
        return nil
    end
    local laps = stopwatch.laps
    if not ValidatePositiveIndex(index, #laps, "Error in Stopwatch:GetSplitTimeInSeconds(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError) then
        return nil
    end
    return FramesToSeconds(laps[index]:GetFrameCount())
end

--- Get the cumulative split time at a specific lap formatted as a string.
-- See @{Stopwatch.LapsAndSplits|Laps and splits} in Key concepts.
-- @tparam int index The 1-based lap index.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use. Omit it or pass `nil` to use the default format. Pass `false` to return an empty string. Invalid values log a warning and also use the default format. See `timeFormat` for details.
-- @treturn[1] string The formatted cumulative split time at the specified lap.
-- @treturn[2] nil If the index is invalid, with an error logged to the console.
-- @usage
-- local splitStr = Stopwatch.Get("RaceTimer"):GetSplitTimeFormatted(2)
function Stopwatch:GetSplitTimeFormatted(index, timeFormat)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetSplitTimeFormatted")
    if not stopwatch then
        return nil
    end
    local laps = stopwatch.laps
    if not ValidatePositiveIndex(index, #laps, "Error in Stopwatch:GetSplitTimeFormatted(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (lap count: " .. tostring(#laps) .. ").", logLevelError) then
        return nil
    end
    timeFormat = NormalizeTimeFormat(timeFormat, "Warning in Stopwatch:GetSplitTimeFormatted(): wrong value for timeFormat, default format will be used.")
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
    local stopwatch = GetStopwatchOrWarn(self.name, "GetAllLapTimes")
    if not stopwatch then
        return nil
    end
    local laps   = stopwatch.laps
    local result = {}
    for i = 1, #laps do
        result[i] = Time(GetLapDeltaFrames(laps, i))
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
    local stopwatch = GetStopwatchOrWarn(self.name, "GetAllLapTimesInSeconds")
    if not stopwatch then
        return nil
    end
    local laps   = stopwatch.laps
    local result = {}
    for i = 1, #laps do
        result[i] = FramesToSeconds(GetLapDeltaFrames(laps, i))
    end
    return result
end

--- Get all lap delta times as an array of formatted strings.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use for each string. Omit it or pass `nil` to use the default format. Pass `false` to return an empty string for each lap. Invalid values log a warning and also use the default format. See `timeFormat` for details.
-- @treturn table An array of strings, one per recorded lap. Returns an empty table if no laps have been recorded.
-- @usage
-- local fmt        = { seconds = true, centiseconds = true }
-- local lapStrings = Stopwatch.Get("RaceTimer"):GetAllLapTimesFormatted(fmt)
-- for i, s in ipairs(lapStrings) do
--     TEN.Util.PrintLog("Lap " .. i .. ": " .. s, TEN.Util.LogLevel.INFO)
-- end
function Stopwatch:GetAllLapTimesFormatted(timeFormat)
    local stopwatch = GetStopwatchOrWarn(self.name, "GetAllLapTimesFormatted")
    if not stopwatch then
        return nil
    end
    timeFormat = NormalizeTimeFormat(timeFormat, "Warning in Stopwatch:GetAllLapTimesFormatted(): wrong value for timeFormat, default format will be used.")
    local laps   = stopwatch.laps
    local result = {}
    for i = 1, #laps do
        result[i] = GenerateTimeFormattedString(Time(GetLapDeltaFrames(laps, i)), timeFormat)
    end
    return result
end

--- Clear all recorded laps. Does not affect the elapsed time or the active state of the stopwatch.
-- @usage
-- Stopwatch.Get("RaceTimer"):ClearLaps()
function Stopwatch:ClearLaps()
    local stopwatch = GetStopwatchOrWarn(self.name, "ClearLaps")
    if not stopwatch then
        return
    end
    stopwatch.laps = {}
end

--- Set a callback function for a specific event.
-- The callback must be a `LevelFuncs` function. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts.
-- Each callback receives the stopwatch as its first argument, so it can use the public Stopwatch methods.
-- For `ON_INTERVAL` in @{Stopwatch.CallbackTypes}, you can optionally pass the interval time in seconds as the third argument. If you omit it, the current interval is kept. If no interval is currently configured, the callback is stored but remains inactive until you set one with @{Stopwatch:SetIntervalTime}. If you pass `intervalTime`, it is rounded to 2 decimal places first; after rounding, it must be at least `0.03` seconds (1 frame at 30 FPS), otherwise the `ON_INTERVAL` callback is not changed. See @{FramePrecision|Time values and frame precision}.
-- For callback ordering and same-frame overlap rules, see @{Callbacks|Callbacks overview}.
-- @tparam CallbackTypes callbackType The callback type.
-- @tparam function func A `LevelFuncs` function. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Signature: `function(stopwatch)`.
-- @tparam[opt=nil] float intervalTime Only for `ON_INTERVAL`: the interval in seconds. It is rounded to 2 decimal places first; after rounding, it must be at least `0.03` seconds (1 frame at 30 FPS). If invalid, the `ON_INTERVAL` callback is not changed. Ignored for all other callback types.
-- @usage
-- LevelFuncs.OnLapRecorded = function(sw)
--     TEN.Util.PrintLog("Lap " .. sw:GetLapCount() .. ": " .. sw:GetLapTimeFormatted(sw:GetLapCount()), TEN.Util.LogLevel.INFO)
-- end
-- Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnLapRecorded)
--
-- -- ON_INTERVAL: callback called every second
-- LevelFuncs.OnTick = function(sw)
--     TEN.Util.PrintLog("Elapsed: " .. sw:GetElapsedTimeInSeconds() .. "s", TEN.Util.LogLevel.INFO)
-- end
-- Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_INTERVAL, LevelFuncs.OnTick, 1.0)
--
-- -- ON_INTERVAL: callback called every frame (~0.03s)
-- Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_INTERVAL, LevelFuncs.OnTick, 0.03)
function Stopwatch:SetCallback(callbackType, func, intervalTime)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetCallback")
    if not stopwatch then
        return
    end
    if not TableHasValue(Stopwatch.CallbackTypes, callbackType) then
        LogMessage("Error in Stopwatch:SetCallback(): invalid callbackType for '" .. self.name .. "'. Use a Stopwatch.CallbackTypes constant.", logLevelError)
        return
    end
    if not IsLevelFunc(func) then
        LogMessage("Error in Stopwatch:SetCallback(): func must be a LevelFunc for '" .. self.name .. "'.", logLevelError)
        return
    end
    local intervalFrames = nil
    if callbackType == Stopwatch.CallbackTypes.ON_INTERVAL and not IsNull(intervalTime) then
        local invalidValueMessage = "Warning in Stopwatch:SetCallback(): wrong value (" .. tostring(intervalTime) .. ") for intervalTime in '" .. self.name .. "', it must be a positive number. ON_INTERVAL callback will not be changed."
        local tooSmallMessage = "Warning in Stopwatch:SetCallback(): intervalTime too small for '" .. self.name .. "'. Minimum is " .. MIN_FRAME_SECONDS .. "s (1 frame at 30 FPS). ON_INTERVAL callback will not be changed."
        intervalFrames = ValidateFrameSeconds(intervalTime, invalidValueMessage, tooSmallMessage, logLevelWarning)
        if not intervalFrames then
            return
        end
    end
    -- ON_INTERVAL updates are atomic: an invalid new interval leaves the previous
    -- callback and schedule untouched instead of half-updating them.
    stopwatch.callbacks[callbackType] = func
    if callbackType == Stopwatch.CallbackTypes.ON_INTERVAL and intervalFrames then
        InvalidateScheduledState(stopwatch)
        ApplyIntervalFrames(stopwatch, intervalFrames)
    end
end

--- Remove a callback function for a specific event.
-- For `ON_INTERVAL` in @{Stopwatch.CallbackTypes}, only the callback function is removed; the interval time is kept.
-- Use @{Stopwatch:SetIntervalTime} with no arguments to remove both the interval time and the callback.
-- @tparam CallbackTypes callbackType The callback type.
-- @usage
-- Stopwatch.Get("RaceTimer"):RemoveCallback(Stopwatch.CallbackTypes.ON_LAP)
function Stopwatch:RemoveCallback(callbackType)
    local stopwatch = GetStopwatchOrWarn(self.name, "RemoveCallback")
    if not stopwatch then
        return
    end
    if not TableHasValue(Stopwatch.CallbackTypes, callbackType) then
        LogMessage("Error in Stopwatch:RemoveCallback(): invalid callbackType for '" .. self.name .. "'. Use a Stopwatch.CallbackTypes constant.", logLevelError)
        return
    end
    stopwatch.callbacks[callbackType] = nil
end

--- Get the current interval time for `ON_INTERVAL` in @{Stopwatch.CallbackTypes}.
-- @treturn[1] float The interval time in seconds.
-- @treturn[2] nil If no interval is configured.
-- @usage
-- local interval = Stopwatch.Get("RaceTimer"):GetIntervalTime()
function Stopwatch:GetIntervalTime()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetIntervalTime")
    if not stopwatch then
        return nil
    end
    local frames = stopwatch.intervalFrames
    if frames then
        return FramesToSeconds(frames)
    end
    return nil
end

--- Set the interval time for `ON_INTERVAL` in @{Stopwatch.CallbackTypes}.
-- Omit the argument or pass nil to remove the interval time and the `ON_INTERVAL` callback together.
-- Changing the interval recalculates the next callback from the current elapsed time. Interval callbacks that would have happened in the past are not replayed.
-- @tparam[opt] float seconds The interval in seconds. Must be positive. It is rounded to 2 decimal places first; after rounding, it must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}.
-- @usage
-- -- Callback called every 5 seconds
-- Stopwatch.Get("RaceTimer"):SetIntervalTime(5.0)
--
-- -- Remove interval and its callback
-- Stopwatch.Get("RaceTimer"):SetIntervalTime()
function Stopwatch:SetIntervalTime(seconds)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetIntervalTime")
    if not stopwatch then
        return
    end
    if IsNull(seconds) then
        -- Removing the schedule also removes OnInterval; a dormant interval callback
        -- without a schedule tends to be misleading during debugging.
        InvalidateScheduledState(stopwatch)
        stopwatch.intervalFrames = nil
        stopwatch.lastIntervalCount = 0
        stopwatch.callbacks["OnInterval"] = nil
    else
        local invalidValueMessage = "Warning in Stopwatch:SetIntervalTime(): wrong value (" .. tostring(seconds) .. ") for seconds, it must be a positive number."
        local tooSmallMessage = "Warning in Stopwatch:SetIntervalTime(): interval too small for '" .. self.name .. "'. Minimum is " .. MIN_FRAME_SECONDS .. "s (1 frame at 30 FPS)."
        local frames = ValidateFrameSeconds(seconds, invalidValueMessage, tooSmallMessage, logLevelWarning)
        if frames then
            InvalidateScheduledState(stopwatch)
            ApplyIntervalFrames(stopwatch, frames)
        end
    end
end

--- Add a new absolute time trigger to the stopwatch.
-- The trigger is appended to the public trigger list. The runtime ordering is rebuilt immediately from the current elapsed time.
-- If another trigger already exists at the same normalized time, or resolves to the same frame, both triggers are kept. Due triggers on the same frame fire in public order, so the newly added trigger runs after existing ones for that frame.
-- If the new trigger resolves to the current frame or a past frame, it is stored but not fired retroactively.
-- For ordering and overlap rules, see @{TimeTriggers|Time triggers overview}.
-- @tparam float seconds The trigger time in seconds. It is rounded to 2 decimal places first; after rounding, it must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}.
-- @tparam function func A `LevelFuncs` function. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Signature: `function(stopwatch, ...)`.
-- @param ... Optional positional extra arguments stored with the trigger and passed to the callback when it fires. `nil` values are not allowed.
-- @usage
-- Stopwatch.Get("RaceTimer"):AddTimeTrigger(5.0, LevelFuncs.OpenDoor)
-- Stopwatch.Get("RaceTimer"):AddTimeTrigger(10.0, LevelFuncs.PlayVoiceLine, "Keep going!")
function Stopwatch:AddTimeTrigger(seconds, func, ...)
    local stopwatch = GetStopwatchOrWarn(self.name, "AddTimeTrigger")
    if not stopwatch then
        return
    end
    local triggerData = {
        at = seconds,
        func = func,
    }
    local argCount = select("#", ...)
    if argCount > 0 then
        local args = {}
        for i = 1, argCount do
            local value = select(i, ...)
            if IsNull(value) then
                LogMessage("Error in Stopwatch:AddTimeTrigger(): args must not contain nil values for '" .. self.name .. "'.", logLevelError)
                return
            end
            args[i] = value
        end
        triggerData.args = args
    end

    local normalizedTrigger = NormalizeTimeTriggerData(
        triggerData,
        "Error in Stopwatch:AddTimeTrigger(): triggerData for '" .. self.name .. "' ",
        logLevelError
    )
    if not normalizedTrigger then
        return
    end

    InvalidateScheduledState(stopwatch)
    insert(stopwatch.timeTriggers, normalizedTrigger)
    RebuildTimeTriggers(stopwatch)
end

--- Replace the entire time trigger list.
-- Validation is atomic: if one trigger is invalid, the existing list is left unchanged.
-- If multiple entries resolve to the same frame, they are all kept and fire in list order.
-- Each trigger's `at` value is normalized as described in @{TimeTriggerData}.
-- @tparam table triggers An array of @{TimeTriggerData} entries.
-- @usage
-- Stopwatch.Get("RaceTimer"):SetTimeTriggers({
--     { at = 3.0, func = LevelFuncs.SpawnWave },
--     { at = 6.5, func = LevelFuncs.ShowHint, args = { "Second wave incoming" } },
-- })
function Stopwatch:SetTimeTriggers(triggers)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetTimeTriggers")
    if not stopwatch then
        return
    end
    local normalizedTriggers = NormalizeTimeTriggerList(
        triggers,
        "Error in Stopwatch:SetTimeTriggers(): timeTriggers must be an array table for '" .. self.name .. "'.",
        "Error in Stopwatch:SetTimeTriggers(): timeTriggers",
        " for '" .. self.name .. "'",
        logLevelError
    )
    if not normalizedTriggers then
        return
    end

    InvalidateScheduledState(stopwatch)
    stopwatch.timeTriggers = normalizedTriggers
    RebuildTimeTriggers(stopwatch)
end

--- Get a copy of the current time trigger list in public order.
-- Editing the returned outer table or any top-level trigger entry does not affect the stopwatch until you pass data back through @{Stopwatch:SetTimeTriggers} or @{Stopwatch:SetTimeTrigger}.
-- Returned trigger entries and their `args` array tables are shallow copies. Nested tables inside `args` remain shared references.
-- Returned `at` values are the normalized public values stored by the stopwatch, rounded to 2 decimal places.
-- @treturn table An array of @{TimeTriggerData} entries.
-- @usage
-- local triggers = Stopwatch.Get("RaceTimer"):GetTimeTriggers()
function Stopwatch:GetTimeTriggers()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetTimeTriggers")
    if stopwatch then
        return CloneTimeTriggers(stopwatch.timeTriggers or {})
    end
    return nil
end

--- Replace one time trigger by public index.
-- Validation is atomic: on invalid input the existing trigger is left unchanged.
-- Replacing one entry with a time already used elsewhere is allowed; if multiple triggers resolve to the same frame, they fire in public order.
-- @tparam int index The 1-based trigger index in the public list.
-- @tparam TimeTriggerData triggerData The new trigger data. The `at` field is normalized as described in @{TimeTriggerData}.
-- @usage
-- Stopwatch.Get("RaceTimer"):SetTimeTrigger(2, { at = 8.0, func = LevelFuncs.PlayAlarm })
function Stopwatch:SetTimeTrigger(index, triggerData)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetTimeTrigger")
    if not stopwatch then
        return
    end
    local triggerCount = #stopwatch.timeTriggers
    if not ValidatePositiveIndex(index, triggerCount, "Error in Stopwatch:SetTimeTrigger(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (trigger count: " .. tostring(triggerCount) .. ").", logLevelError) then
        return
    end

    local normalizedTrigger = NormalizeTimeTriggerData(
        triggerData,
        "Error in Stopwatch:SetTimeTrigger(): triggerData for '" .. self.name .. "' ",
        logLevelError
    )
    if not normalizedTrigger then
        return
    end

    InvalidateScheduledState(stopwatch)
    stopwatch.timeTriggers[index] = normalizedTrigger
    RebuildTimeTriggers(stopwatch)
end

--- Remove one time trigger by public index.
-- @tparam int index The 1-based trigger index in the public list.
-- @usage
-- Stopwatch.Get("RaceTimer"):RemoveTimeTrigger(1)
function Stopwatch:RemoveTimeTrigger(index)
    local stopwatch = GetStopwatchOrWarn(self.name, "RemoveTimeTrigger")
    if not stopwatch then
        return
    end
    local triggerCount = #stopwatch.timeTriggers
    if not ValidatePositiveIndex(index, triggerCount, "Error in Stopwatch:RemoveTimeTrigger(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (trigger count: " .. tostring(triggerCount) .. ").", logLevelError) then
        return
    end

    InvalidateScheduledState(stopwatch)
    remove(stopwatch.timeTriggers, index)
    RebuildTimeTriggers(stopwatch)
end

--- Remove all time triggers from the stopwatch.
-- @usage
-- Stopwatch.Get("RaceTimer"):ClearTimeTriggers()
function Stopwatch:ClearTimeTriggers()
    local stopwatch = GetStopwatchOrWarn(self.name, "ClearTimeTriggers")
    if not stopwatch then
        return
    end
    InvalidateScheduledState(stopwatch)
    stopwatch.timeTriggers = {}
    RebuildTimeTriggers(stopwatch)
end

LevelFuncs.Engine.Stopwatch.IncrementTime = function()
    -- Time advancement stays separate so UpdateAll() can derive callbacks and display
    -- effects once per loop from a stable frame state.
    for _, s in pairs(stopwatches) do
        if s.active and not s.paused then
            s.elapsedTime = s.elapsedTime + 1
        end
    end
end

LevelFuncs.Engine.Stopwatch.UpdateAll = function()
    -- Per-frame reconciliation: derive interval callbacks, display refresh, and
    -- maxTime termination from the current frame state.
    for name, s in pairs(stopwatches) do
        if s.active then
            local proxy = nil

            s.scheduledDispatchInterrupted = false
            s.scheduledStateInvalidated = false

            -- Scheduled callbacks are processed in timeline order: interval first,
            -- then absolute time triggers, and maxTime is decided from the final
            -- stopwatch state that remains after those callbacks finish.
            if s.intervalFrames and not s.paused then
                local frames = s.elapsedTime:GetFrameCount()
                local currentCount = floor(frames / s.intervalFrames)
                local lastCount = s.lastIntervalCount or 0
                if currentCount > lastCount then
                    local fn = s.callbacks["OnInterval"]
                    if fn then
                        BeginScheduledCallbackDispatch(s)
                        for _ = lastCount + 1, currentCount do
                            proxy = EnsureStopwatchProxy(proxy, name)
                            fn(proxy)
                            if s.scheduledDispatchInterrupted or stopwatches[name] ~= s or not s.active or s.paused then
                                break
                            end
                        end
                        EndScheduledCallbackDispatch(s, name, proxy)
                    end
                    if not s.scheduledStateInvalidated then
                        -- The interval counter is updated even when no callback is set
                        -- so that later callback assignment starts from the current
                        -- schedule instead of replaying old thresholds.
                        s.lastIntervalCount = currentCount
                    end
                end
            end

            if not s.scheduledDispatchInterrupted and s.active and not s.paused then
                local compiledTriggers = s.compiledTimeTriggers
                local nextTriggerIndex = s.nextTimeTriggerIndex or 1
                local currentFrame = s.elapsedTime:GetFrameCount()
                if nextTriggerIndex <= #compiledTriggers and compiledTriggers[nextTriggerIndex].frame <= currentFrame then
                    -- Keep trigger dispatch marked as active so Delete() and
                    -- Create()-overwrite can invalidate the remaining same-frame work.
                    BeginScheduledCallbackDispatch(s)
                    while nextTriggerIndex <= #compiledTriggers do
                        local triggerData = compiledTriggers[nextTriggerIndex]
                        if triggerData.frame > currentFrame then
                            break
                        end

                        -- Consume the current trigger before invoking it. If the
                        -- callback mutates the stopwatch timeline, the mutating method
                        -- will immediately rebuild the runtime cursor as needed.
                        nextTriggerIndex = nextTriggerIndex + 1
                        s.nextTimeTriggerIndex = nextTriggerIndex

                        proxy = EnsureStopwatchProxy(proxy, name)
                        FireTimeTriggerCallback(triggerData, proxy)
                        if s.scheduledDispatchInterrupted or stopwatches[name] ~= s or not s.active or s.paused then
                            break
                        end
                    end
                    EndScheduledCallbackDispatch(s, name, proxy)
                end
            end

            local instanceAlive = stopwatches[name] == s
            local reachedMaxTime = instanceAlive and not s.scheduledDispatchInterrupted and s.active and s.maxTime and s.elapsedTime >= s.maxTime

            if instanceAlive and s.timeFormat and (s.active or reachedMaxTime) then
                local ds = stopwatchStrings[name]
                if ds then
                    local frameCount = s.elapsedTime:GetFrameCount()
                    if s.lastRenderedFrameCount ~= frameCount then
                        ds:SetKey(GenerateTimeFormattedString(s.elapsedTime, s.timeFormat))
                        s.lastRenderedFrameCount = frameCount
                    end
                    ds:SetColor(s.paused and s.pausedColor or s.color)
                    ShowString(ds, reachedMaxTime and 1 or FRAME_TIME, false)
                end
            end
            if reachedMaxTime then
                -- maxTime is a hard stop with its own callback. It intentionally does
                -- not cascade into OnStop; that distinction is part of the API contract.
                s.active = false
                s.paused = false
                proxy = EnsureStopwatchProxy(proxy, name)
                FireCallback(s, "OnMaxTime", proxy)
            end
        end
    end
end

LevelFuncs.Engine.Stopwatch.Reload = function()
    stopwatches = LevelVars.Engine.Stopwatch.stopwatches
    stopwatchStrings = {}
    for name, s in pairs(stopwatches) do
        -- These flags are runtime-only bookkeeping. They must not survive loads,
        -- because resuming inside a half-finished callback would be invalid.
        s.pendingStopCallback = false
        s.scheduledCallbackDepth = 0
        s.scheduledDispatchInterrupted = false
        s.scheduledStateInvalidated = false
        if not IsTable(s.timeTriggers) then
            s.timeTriggers = {}
        end
        RebuildTimeTriggers(s)
        local warning1Message = "Warning in Stopwatch.Reload(): textOptions for '" .. name .. "' must be a table. Default textOptions will be used."
        local warning2Message = "Warning in Stopwatch.Reload(): all values in textOptions for '" .. name .. "' must be of type TEN.Strings.DisplayStringOption. Default textOptions will be used."
        local textOptions = CheckTextOptions(s.textOptions, warning1Message, warning2Message)
        s.textOptions = textOptions
        if s.timeFormat then
            -- DisplayString handles are not serializable, so Reload() recreates them
            -- from the persisted stopwatch state.
            local text = GenerateTimeFormattedString(s.elapsedTime, s.timeFormat)
            local color = s.paused and s.pausedColor or s.color
            stopwatchStrings[name] = DisplayString(text, s.position, s.scale, color, false, s.textOptions)
            s.lastRenderedFrameCount = s.elapsedTime:GetFrameCount()
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
-- @tfield[opt=false] table|bool timeFormat Controls the on-screen time display. Set to false to disable the display. See `timeFormat` for details.
-- @tfield[opt=nil] float maxTime The maximum time for the stopwatch in seconds with 2 decimal places. If set, the stopwatch will automatically stop when this time is reached. Values must be positive. They are rounded to 2 decimal places first; after rounding, they must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}.
-- @tfield[opt=Vec2(50&#44; 90)] Vec2 position The position in percentage on screen where the stopwatch will be displayed.
-- @tfield[opt=1] float scale The scale of the stopwatch display. Must be a positive number.
-- @tfield[opt=Color(255&#44; 255&#44; 255&#44; 255)] Color color The color of the displayed stopwatch when it is active.
-- @tfield[opt=Color(255&#44; 255&#44; 0&#44; 255)] Color pausedColor The color of the displayed stopwatch when it is paused.
-- @tfield[opt=<br>{<br>TEN.Strings.DisplayStringOption.CENTER&#44;<br> TEN.Strings.DisplayStringOption.SHADOW&#44;<br> TEN.Strings.DisplayStringOption.VERTICAL_CENTER<br>}] table textOptions A table containing values from @{Strings.DisplayStringOption} to set the text options. Vertical center option is always added automatically if not present.<br>
-- @tfield[opt=nil] function onStart Callback called when the stopwatch is started. Must be a `LevelFuncs` function reference. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Equivalent to calling @{Stopwatch:SetCallback} with `ON_START` from @{Stopwatch.CallbackTypes} after creation.<br>
-- @tfield[opt=nil] function onResume Callback called when the stopwatch is resumed after a pause. Must be a `LevelFuncs` function reference. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Equivalent to calling @{Stopwatch:SetCallback} with `ON_RESUME` from @{Stopwatch.CallbackTypes} after creation.<br>
-- @tfield[opt=nil] function onPause Callback called when the stopwatch is paused. Must be a `LevelFuncs` function reference. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Equivalent to calling @{Stopwatch:SetCallback} with `ON_PAUSE` from @{Stopwatch.CallbackTypes} after creation.<br>
-- @tfield[opt=nil] function onStop Callback called when @{Stopwatch:Stop} stops an active stopwatch. Must be a `LevelFuncs` function reference. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Equivalent to calling @{Stopwatch:SetCallback} with `ON_STOP` from @{Stopwatch.CallbackTypes} after creation. For overlap behavior with other callbacks, see @{Callbacks|Callbacks overview}.<br>
-- @tfield[opt=nil] function onReset Callback called after the stopwatch is reset to zero, stopped, and its laps are cleared. Must be a `LevelFuncs` function reference. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Equivalent to calling @{Stopwatch:SetCallback} with `ON_RESET` from @{Stopwatch.CallbackTypes} after creation.<br>
-- @tfield[opt=nil] function onLap Callback called when a lap is recorded. Must be a `LevelFuncs` function reference. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Equivalent to calling @{Stopwatch:SetCallback} with `ON_LAP` from @{Stopwatch.CallbackTypes} after creation.<br>
-- @tfield[opt=nil] function onMaxTime Callback called when the stopwatch reaches its configured maxTime and automatically stops. Must be a `LevelFuncs` function reference. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Equivalent to calling @{Stopwatch:SetCallback} with `ON_MAX_TIME` from @{Stopwatch.CallbackTypes} after creation. For overlap behavior with onInterval and onStop, see @{Callbacks|Callbacks overview}.<br>
-- @tfield[opt=nil] function onInterval Callback called repeatedly at a fixed interval while the stopwatch is ticking. Must be a `LevelFuncs` function reference. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Requires a valid `intervalTime`; if `intervalTime` is missing or invalid, the callback is stored but is not called until a valid interval is configured via @{Stopwatch:SetIntervalTime}. For same-frame interactions with onStop and onMaxTime, see @{Callbacks|Callbacks overview}.<br>
-- @tfield[opt=nil] float intervalTime The firing interval in seconds for the `onInterval` callback. Values must be positive. They are rounded to 2 decimal places first; after rounding, they must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}. Has no effect without `onInterval`; however, the interval is stored and will be used as soon as a callback is assigned via @{Stopwatch:SetCallback}.<br>
-- @tfield[opt=nil] table timeTriggers An array of @{TimeTriggerData} entries. These define absolute one-shot cue points on the stopwatch timeline and are stored in public order. Validation is atomic during creation: if one entry is invalid, the whole list is ignored and the stopwatch starts with no timeTriggers. See @{TimeTriggers|Time triggers overview}, @{FramePrecision|Time values and frame precision}, and @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts.<br>

---
-- Time format configuration for displaying the stopwatch time.
-- @table timeFormat
--
-- You can display hours, minutes, seconds, and centiseconds. Like in Timer, the format can be a table or a boolean.
-- In formatted getter methods, omitting the argument or passing `nil` uses that method's documented default format. Passing `false` returns an empty string. Invalid values log a warning and fall back to that method's documented default format.
-- For more information see the <a href="Timer.html#timerFormat">Time format</a> section in the Timer documentation.
-- <h3>Timer format examples:</h3>
-- <pre><span class="comment">-- hours:mins:secs.centisecond</span>
-- <span class="keyword">local</span> myTimeFormat = {hours = <span class="keyword">true</span>, minutes = <span class="keyword">true</span>, seconds = <span class="keyword">true</span>, centiseconds = <span class="keyword">true</span>}
-- <br><span class="comment">-- mins:secs</span>
-- <span class="keyword">local</span> myTimeFormat1 = {minutes = <span class="keyword">true</span>, seconds = <span class="keyword">true</span>}</pre>

---
-- Constants for operators in @{Stopwatch:IfElapsedTimeIs} or @{Stopwatch:IfMaxTimeIs}.
--
-- Use them as `Stopwatch.Operators.EQUAL`, `Stopwatch.Operators.LESS`, etc.
-- @table Operators
-- @tfield 0 EQUAL Equal operator.
-- @tfield 1 NOT_EQUAL Not equal operator.
-- @tfield 2 LESS Less than operator.
-- @tfield 3 LESS_EQUAL Less than or equal operator.
-- @tfield 4 GREATER Greater than operator.
-- @tfield 5 GREATER_EQUAL Greater than or equal operator.

---
-- Constants for the available callback types in @{Stopwatch:SetCallback}.
-- @table CallbackTypes
-- @tfield "OnLap" ON_LAP Callback called when a lap is recorded via @{Stopwatch:Lap}.
-- @tfield "OnStart" ON_START Callback called when the stopwatch is started via @{Stopwatch:Start}.
-- @tfield "OnPause" ON_PAUSE Callback called when the stopwatch is paused via @{Stopwatch:Pause}.
-- @tfield "OnResume" ON_RESUME Callback called when the stopwatch is resumed via @{Stopwatch:Start} after being paused.
-- @tfield "OnReset" ON_RESET Callback called after @{Stopwatch:Reset} resets elapsed time to zero, clears laps, and stops the stopwatch.
-- @tfield "OnStop" ON_STOP Callback called when the stopwatch is stopped via @{Stopwatch:Stop}. The stopwatch is already stopped when the callback is called, so you do not need to stop it manually inside the callback. For overlap behavior with other callbacks, see @{Callbacks|Callbacks overview}.
-- @tfield "OnMaxTime" ON_MAX_TIME Callback called when the stopwatch reaches the configured maxTime and automatically stops. The stopwatch is already stopped when the callback is called, so you do not need to stop it manually inside the callback. For overlap behavior with `ON_INTERVAL` and `ON_STOP`, see @{Callbacks|Callbacks overview}.
-- @tfield "OnInterval" ON_INTERVAL Callback called repeatedly at the configured interval while the stopwatch is ticking. The interval is configured via @{Stopwatch:SetIntervalTime} or @{Stopwatch:SetCallback}. For same-frame interactions with `ON_STOP` and `ON_MAX_TIME`, see @{Callbacks|Callbacks overview}.

---
-- Data for one stopwatch time trigger.
-- @table TimeTriggerData
-- @tfield float at Trigger time in seconds. The value is rounded to 2 decimal places first; after rounding, it must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}.
-- @tfield function func Callback function defined in `LevelFuncs`. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Signature: `function(stopwatch, ...)`.
-- @tfield[opt=nil] table args Optional array table of extra arguments stored with the trigger and passed after the stopwatch argument when the trigger fires. It must use consecutive numeric indices starting at 1 and must not contain `nil` values.

----
-- Basic examples
-- @section basicExamples
-- Short examples showing common Stopwatch tasks with minimal setup.

---
-- Simple start and stop.
-- @moduleexample BasicStartStop
-- Create a stopwatch, start it from a LevelFunc, and stop it later.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- Stopwatch.Create({ name = "MyStopwatch" })
--
-- LevelFuncs.StartMyStopwatch = function()
--     Stopwatch.Get("MyStopwatch"):Start(true)
-- end
--
-- LevelFuncs.StopMyStopwatch = function()
--     Stopwatch.Get("MyStopwatch"):Stop()
-- end

---
-- Pause, resume, and reset.
-- @moduleexample BasicPauseResume
-- Pause the stopwatch without losing elapsed time, resume it later, or reset it to zero.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- Stopwatch.Create({ name = "SessionTimer" })
--
-- LevelFuncs.StartSessionTimer = function()
--     Stopwatch.Get("SessionTimer"):Start()
-- end
--
-- LevelFuncs.PauseSessionTimer = function()
--     Stopwatch.Get("SessionTimer"):Pause()
-- end
--
-- LevelFuncs.ResumeSessionTimer = function()
--     Stopwatch.Get("SessionTimer"):Start()
-- end
--
-- LevelFuncs.ResetSessionTimer = function()
--     Stopwatch.Get("SessionTimer"):Reset()
-- end

---
-- Read elapsed time.
-- @moduleexample BasicReadTime
-- Read the current elapsed time in seconds or as a formatted string.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- Stopwatch.Create({
--     name       = "DisplayTimer",
--     timeFormat = { minutes = true, seconds = true, centiseconds = true },
-- })
--
-- LevelFuncs.PrintDisplayTimer = function()
--     local sw = Stopwatch.Get("DisplayTimer")
--     TEN.Util.PrintLog("Seconds: " .. sw:GetElapsedTimeInSeconds(), TEN.Util.LogLevel.INFO)
--     TEN.Util.PrintLog("Formatted: " .. sw:GetElapsedTimeFormatted(), TEN.Util.LogLevel.INFO)
-- end

---
-- Record laps and splits.
-- @moduleexample BasicLaps
-- Record laps at checkpoints and read both segment times and cumulative split times.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- Stopwatch.Create({ name = "RaceTimer" })
--
-- LevelFuncs.OnCheckpoint = function()
--     local sw = Stopwatch.Get("RaceTimer")
--     sw:Lap()
--     local i = sw:GetLapCount()
--     TEN.Util.PrintLog("Lap " .. i .. ": " .. sw:GetLapTimeFormatted(i), TEN.Util.LogLevel.INFO)
--     TEN.Util.PrintLog("Split " .. i .. ": " .. sw:GetSplitTimeFormatted(i), TEN.Util.LogLevel.INFO)
-- end

---
-- Use maxTime for a timed challenge.
-- @moduleexample BasicMaxTime
-- Stop the stopwatch automatically after a fixed time limit.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- Stopwatch.Create({
--     name       = "ChallengeTimer",
--     maxTime    = 30.0,
--     timeFormat = { seconds = true, centiseconds = true },
-- })
--
-- LevelFuncs.StartChallenge = function()
--     Stopwatch.Get("ChallengeTimer"):Start(true)
-- end

----
-- Advanced examples
-- @section examples
-- Gameplay-oriented examples showing only a few of the patterns possible with Stopwatch.
-- Use them as starting points for custom scripting, callbacks, and other frame-based behaviors.

---
-- Race with checkpoints.
-- @moduleexample Scenario1
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
-- -- Trigger this via a volume at each checkpoint
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
--         TEN.Util.PrintLog("Checkpoint " .. i .. " - segment: " .. seg .. "  split: " .. split, TEN.Util.LogLevel.INFO)
--     end
--     TEN.Util.PrintLog("Total: " .. sw:GetElapsedTimeFormatted(fmt), TEN.Util.LogLevel.INFO)
-- end

---
-- Timed puzzle with best-time record.
-- @moduleexample Scenario2
-- The player can retry a puzzle;
-- each attempt is timed and compared to the personal best stored in LevelVars.
-- A maxTime of 60 seconds automatically stops the stopwatch if the player runs out of time.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
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
-- @moduleexample Scenario3
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

---
-- Callback-driven timed challenge.
-- @moduleexample Scenario4
-- Assign callbacks directly in @{Stopwatch.Create} when the stopwatch behavior is known up front.
-- Use interval and maxTime callbacks to drive announcements and failure conditions without polling in OnLoop.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- LevelFuncs.OnChallengeInterval = function(sw)
--     TEN.Util.PrintLog("Time: " .. sw:GetElapsedTimeFormatted({ seconds = true, centiseconds = true }), TEN.Util.LogLevel.INFO)
-- end
--
-- LevelFuncs.OnChallengeTimeOver = function(sw)
--     TEN.Util.PrintLog("Time over at " .. sw:GetElapsedTimeFormatted({ seconds = true, centiseconds = true }), TEN.Util.LogLevel.INFO)
-- end
--
-- Stopwatch.Create({
--     name         = "ChallengeTimer",
--     timeFormat   = { seconds = true, centiseconds = true },
--     maxTime      = 30.0,
--     onInterval   = LevelFuncs.OnChallengeInterval,
--     intervalTime = 5.0,
--     onMaxTime    = LevelFuncs.OnChallengeTimeOver,
-- })
--
-- LevelFuncs.StartChallenge = function()
--     Stopwatch.Get("ChallengeTimer"):Start(true)
-- end

---
-- Hold a camera for a fixed duration.
-- @moduleexample Scenario5
-- @{Objects.Camera:Play|Camera:Play} only affects the current frame.
-- Use @{Stopwatch:SetCallback} when the stopwatch already exists and you want to attach or replace behavior later.
-- Here, `ON_INTERVAL` runs every `0.03` seconds (1 frame at 30 FPS) to keep replaying the camera for a fixed duration.
-- This pattern also works for other frame-based effects that must be refreshed continuously for a short time.
-- @usage
-- local Stopwatch = require("Engine.Stopwatch")
--
-- Stopwatch.Create({
--     name    = "CameraHoldTimer",
--     maxTime = 3.0,
-- })
--
-- LevelFuncs.PlayCamera1Frame = function(stopwatch)
--     TEN.Objects.GetCameraByName("camera1"):Play()
-- end
--
-- LevelFuncs.OnCameraSequenceFinished = function(stopwatch)
--     TEN.Util.PrintLog("Camera sequence finished.", TEN.Util.LogLevel.INFO)
-- end
--
-- LevelFuncs.PlayCamera1ForThreeSeconds = function()
--     local sw = Stopwatch.Get("CameraHoldTimer")
--     sw:SetCallback(Stopwatch.CallbackTypes.ON_INTERVAL, LevelFuncs.PlayCamera1Frame, 0.03)
--     sw:SetCallback(Stopwatch.CallbackTypes.ON_MAX_TIME, LevelFuncs.OnCameraSequenceFinished)
--     sw:Start(true)
-- end
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOOP, LevelFuncs.Engine.Stopwatch.IncrementTime)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POST_LOOP, LevelFuncs.Engine.Stopwatch.UpdateAll)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOAD, LevelFuncs.Engine.Stopwatch.Reload)

return Stopwatch