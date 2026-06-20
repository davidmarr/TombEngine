-----<style>table.function_list td.name {min-width: 400px;}</style>
--- Frame-based stopwatch that counts up. It updates once per frame at 30 FPS, so time changes in steps of 1/30 second (about 0.03s). Stopwatches are updated automatically every frame. A stopwatch is ticking when it is active and not paused. Stopwatch state is stored in `LevelVars`, so elapsed time, active state, laps, callbacks, interval triggers, and time triggers are preserved by save/load. Display strings are recreated automatically after loading.
--
-- Require the module before using Stopwatch in a script:
--      local Stopwatch = require("Engine.Stopwatch")
--
-- Example usage:
--      -- Without timeFormat, the stopwatch runs silently in the background with no on-screen display.
--      -- Add timeFormat to make it visible.
--      Stopwatch.Create({
--          name       = "MyStopwatch",
--          timeFormat = { seconds = true, centiseconds = true }
--      })
--
--      -- Create LevelFuncs to start, pause and stop the stopwatch
--      LevelFuncs.StartMyStopwatch = function()
--          Stopwatch.Get("MyStopwatch"):Start()
--      end
--      LevelFuncs.PauseMyStopwatch = function()
--          Stopwatch.Get("MyStopwatch"):Pause()
--      end
--      LevelFuncs.StopMyStopwatch = function()
--          Stopwatch.Get("MyStopwatch"):Stop()
--      end
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
local LogMessage          = TEN.Util.PrintLog
local logLevelError       = TEN.Util.LogLevel.ERROR
local logLevelWarning     = TEN.Util.LogLevel.WARNING
local PercentToScreen     = TEN.Util.PercentToScreen
local DisplayString       = TEN.Strings.DisplayString
local ShowString          = TEN.Strings.ShowString
local HideString          = TEN.Strings.HideString
local DisplayStringOption = TEN.Strings.DisplayStringOption
local Time                = TEN.Time
local Vec2                = TEN.Vec2
local Color               = TEN.Color

local ZERO = Time()
local DEFAULT_TEXT_OPTIONS = {DisplayStringOption.CENTER, DisplayStringOption.SHADOW, DisplayStringOption.VERTICAL_CENTER}
local DEFAULT_TIME_FORMAT = {minutes = true, seconds = true, centiseconds = true}
local FPS = 30
local FRAME_TIME = 1 / FPS
local MIN_FRAME_SECONDS = math.floor(FRAME_TIME * 100) / 100
local DEFAULT_COLOR = Color(255, 255, 255, 255)
local DEFAULT_PAUSED_COLOR = Color(255, 255, 0, 255)
local DEFAULT_POSITION = Vec2(50, 90)
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
    { field = "onStart",   key = "OnStart"   },
    { field = "onResume",  key = "OnResume"  },
    { field = "onPause",   key = "OnPause"   },
    { field = "onStop",    key = "OnStop"    },
    { field = "onReset",   key = "OnReset"   },
    { field = "onLap",     key = "OnLap"     },
    { field = "onMaxTime", key = "OnMaxTime" },
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
local CheckTimeFormat                     = Utility.CheckTimeFormat
local GenerateTimeFormattedString = Utility.GenerateTimeFormattedString
local TableHasValue                           = Utility.TableHasValue

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

local function ExportPublicTimeTriggerCallback(triggerData)
    if IsNull(triggerData.args) or #triggerData.args == 0 then
        return triggerData.func
    end

    local callbackSpec = { triggerData.func }
    local args = triggerData.args
    for i = 1, #args do
        callbackSpec[i + 1] = args[i]
    end
    return callbackSpec
end

-- Exports a flat seconds/callback list from an internal trigger array.
-- timeField selects the time value to read from each entry ("at" for time triggers, "period" for interval triggers).
local function ExportPublicTriggerList(triggers, timeField)
    local exported = {}
    local exportIndex = 1
    for i = 1, #triggers do
        local t = triggers[i]
        exported[exportIndex] = t[timeField]
        exported[exportIndex + 1] = ExportPublicTimeTriggerCallback(t)
        exportIndex = exportIndex + 2
    end
    return exported
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

local function GetValidatedLap(laps, stopwatchName, callerName, index)
    local lapCount = #laps
    local invalidIndexMessage = "Error in Stopwatch:" .. callerName .. "(): invalid index (" .. tostring(index) .. ") for '" .. stopwatchName .. "' stopwatch (lap count: " .. tostring(lapCount) .. ")."
    if not ValidatePositiveIndex(index, lapCount, invalidIndexMessage, logLevelError) then
        return nil, nil
    end
    return laps, laps[index]
end

local function ExportLapDeltas(laps, converter)
    local result = {}
    for i = 1, #laps do
        result[i] = converter(GetLapDeltaFrames(laps, i))
    end
    return result
end

local function ExportFormattedLapDeltas(laps, timeFormat)
    local result = {}
    for i = 1, #laps do
        local deltaTime = Time(GetLapDeltaFrames(laps, i))
        result[i] = GenerateTimeFormattedString(deltaTime, timeFormat)
    end
    return result
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
    local maxIndex = 0
    for key in pairs(values) do
        if not IsNumber(key) or key < 1 or key ~= floor(key) then
            LogMessage(invalidArrayMessage, logLevel)
            return nil
        end
        valueCount = valueCount + 1
        if key > maxIndex then
            maxIndex = key
        end
    end

    if maxIndex ~= valueCount then
        LogMessage(nilValueMessage, logLevel)
        return nil
    end

    return valueCount
end

local function CollectTimeTriggerArgs(stopwatchName, callerName, ...)
    local argCount = select("#", ...)
    if argCount == 0 then
        return true, nil
    end

    local args = {}
    for i = 1, argCount do
        local value = select(i, ...)
        if IsNull(value) then
            LogMessage("Error in Stopwatch:" .. callerName .. "(): args must not contain nil values for '" .. stopwatchName .. "'.", logLevelError)
            return false, nil
        end
        args[i] = value
    end

    return true, args
end

local function NormalizePublicTimeTriggerCallback(callbackSpec, messagePrefix, logLevel)
    if IsLevelFunc(callbackSpec) then
        return callbackSpec, nil
    end

    local invalidCallbackMessage = messagePrefix .. "callback must be a LevelFunc or an array table whose first value is a LevelFunc."
    local callbackValueCount = ValidateArrayTable(
        callbackSpec,
        invalidCallbackMessage,
        messagePrefix .. "callback table must not contain nil values.",
        logLevel
    )
    if not callbackValueCount then
        return nil
    end
    if callbackValueCount == 0 or not IsLevelFunc(callbackSpec[1]) then
        LogMessage(messagePrefix .. "callback table must start with a LevelFunc.", logLevel)
        return nil
    end

    local func = callbackSpec[1]
    if callbackValueCount == 1 then
        LogMessage(messagePrefix .. "callback table must include at least one extra argument; use the LevelFunc directly when no extra arguments are needed.", logLevel)
        return nil
    end

    local args = {}
    for i = 2, callbackValueCount do
        args[i - 1] = callbackSpec[i]
    end
    return func, args
end

local function NormalizeTimeTriggerData(triggerData, messagePrefix, logLevel)
    if not IsTable(triggerData) then
        LogMessage(messagePrefix .. "must be a table.", logLevel)
        return nil
    end

    if not ValidateFrameSeconds(
        triggerData.at,
        messagePrefix .. "seconds must be a positive number.",
        messagePrefix .. "seconds value is too small. Minimum is " .. MIN_FRAME_SECONDS .. "s (1 frame at 30 FPS).",
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

local function NormalizeTimeTriggerFromParts(stopwatchName, callerName, seconds, func, ...)
    local argsOk, args = CollectTimeTriggerArgs(stopwatchName, callerName, ...)
    if not argsOk then
        return nil
    end

    local triggerData = {
        at = seconds,
        func = func,
    }
    if args then
        triggerData.args = args
    end

    return NormalizeTimeTriggerData(
        triggerData,
        "Error in Stopwatch:" .. callerName .. "(): triggerData for '" .. stopwatchName .. "' ",
        logLevelError
    )
end

local function NormalizeTimeTriggerList(timeTriggers, invalidListMessage, holeListMessage, incompletePairMessage, itemMessagePrefix, itemMessageSuffix, logLevel)
    if IsNull(timeTriggers) then
        return {}
    end
    local valueCount = ValidateArrayTable(timeTriggers, invalidListMessage, holeListMessage, logLevel)
    if not valueCount then
        return nil
    end
    if valueCount % 2 ~= 0 then
        LogMessage(incompletePairMessage, logLevel)
        return nil
    end

    local normalizedTriggers = {}
    local triggerCount = valueCount / 2
    for i = 1, triggerCount do
        local valueIndex = (i - 1) * 2 + 1
        local messagePrefix = itemMessagePrefix .. "[" .. i .. "]" .. itemMessageSuffix .. " "
        local func, args = NormalizePublicTimeTriggerCallback(
            timeTriggers[valueIndex + 1],
            messagePrefix,
            logLevel
        )
        if not func then
            return nil
        end

        local triggerData = {
            at = timeTriggers[valueIndex],
            func = func,
        }
        if not IsNull(args) then
            triggerData.args = args
        end

        local normalizedTrigger = NormalizeTimeTriggerData(
            triggerData,
            messagePrefix,
            logLevel
        )
        if not normalizedTrigger then
            return nil
        end
        normalizedTriggers[i] = normalizedTrigger
    end
    return normalizedTriggers
end

-- Normalizes a flat seconds/callback list into interval trigger entries.
-- Reuses time trigger normalization and renames 'at' to 'period'; each entry
-- also receives a lastCount field initialized to 0.
local function NormalizeIntervalTriggerList(triggerList, invalidListMessage, holeListMessage, incompletePairMessage, itemMessagePrefix, itemMessageSuffix, logLevel)
    local normalized = NormalizeTimeTriggerList(
        triggerList,
        invalidListMessage,
        holeListMessage,
        incompletePairMessage,
        itemMessagePrefix,
        itemMessageSuffix,
        logLevel
    )
    if not normalized then
        return nil
    end
    for i = 1, #normalized do
        local t = normalized[i]
        t.period = t.at
        t.at = nil
        t.lastCount = 0
    end
    return normalized
end

-- Normalizes a single interval trigger from positional arguments (seconds, func, ...).
local function NormalizeIntervalTriggerFromParts(stopwatchName, callerName, seconds, func, ...)
    local normalized = NormalizeTimeTriggerFromParts(stopwatchName, callerName, seconds, func, ...)
    if not normalized then
        return nil
    end
    normalized.period = normalized.at
    normalized.at = nil
    normalized.lastCount = 0
    return normalized
end

local function DefaultIfNil(value, defaultValue)
    if IsNull(value) then
        return defaultValue
    end
    return value
end

local function ResolveOrDefault(value, isValid, defaultValue, warningMsg)
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

-- Single dispatch helper for any { func, args } data object (event callbacks,
-- time triggers, and interval triggers all share this storage shape).
local function FireCallbackData(cbData, proxy)
    if cbData.args then
        cbData.func(proxy, unpack(cbData.args))
    else
        cbData.func(proxy)
    end
end

-- Fires a named event callback stored in s.callbacks[callbackType].
local function FireCallback(s, callbackType, proxy)
    local cbData = s.callbacks[callbackType]
    if cbData then
        FireCallbackData(cbData, proxy)
    end
end

local function EnsureStopwatchProxy(proxy, name)
    if not proxy then
        proxy = CreateStopwatchProxy(name)
    end
    return proxy
end

-- Logs a warning for each time trigger whose time exceeds maxTimeFrames.
-- Triggers beyond maxTime are stored but will not fire unless maxTime is extended.
local function WarnTimeTriggersBeyondMaxTime(triggers, maxTimeFrames, callerPrefix, stopwatchName)
    for _, trigger in ipairs(triggers) do
        if SecondsToFrames(trigger.at) > maxTimeFrames then
            LogMessage(callerPrefix .. "time trigger at " .. trigger.at .. "s for '" .. stopwatchName .. "' exceeds maxTime and will not fire unless maxTime is extended.", logLevelWarning)
        end
    end
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

local function ClearScheduledDispatchFlags(stopwatch)
    stopwatch.scheduledDispatchInterrupted = false
    stopwatch.scheduledStateInvalidated = false
end

local function ResetScheduledRuntimeState(stopwatch)
    stopwatch.pendingStopCallback = false
    stopwatch.scheduledCallbackDepth = 0
    ClearScheduledDispatchFlags(stopwatch)
end

local function ShouldAbortScheduledDispatch(stopwatch, name)
    return stopwatch.scheduledDispatchInterrupted or
        stopwatches[name] ~= stopwatch or
        not stopwatch.active or
        stopwatch.paused
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

-- Rebuilds the compiled interval trigger cache and recalculates each trigger's
-- lastCount from the current elapsed time so missed intervals are not replayed.
local function CompileIntervalTriggers(intervalTriggers)
    local compiled = {}
    for i = 1, #intervalTriggers do
        local t = intervalTriggers[i]
        compiled[i] = {
            periodFrames = SecondsToFrames(t.period),
            trigger = t,
        }
    end
    return compiled
end

local function RealignIntervalCounts(stopwatch)
    -- When elapsed time or the trigger list changes, rebase each interval counter
    -- to the current frame so past thresholds are not replayed retroactively.
    local frames = stopwatch.elapsedTime:GetFrameCount()
    local triggers = stopwatch.intervalTriggers
    if not triggers then return end
    for i = 1, #triggers do
        local t = triggers[i]
        local periodFrames = SecondsToFrames(t.period)
        t.lastCount = floor(frames / periodFrames)
    end
end

local function RebuildIntervalTriggers(stopwatch)
    local intervalTriggers = stopwatch.intervalTriggers or {}
    stopwatch.intervalTriggers = intervalTriggers
    stopwatch.compiledIntervalTriggers = CompileIntervalTriggers(intervalTriggers)
    RealignIntervalCounts(stopwatch)
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
-- After rounding, timing values such as `maxTime`, interval trigger periods, and time trigger `at`
-- must be at least `0.03` seconds, which is 1 frame at 30 FPS.
--
-- Examples:
--
-- - `0.03` is valid and means 1 frame.
-- - `0.029` is valid because it rounds to `0.03`.
-- - `0.02` is rejected because it remains below `0.03`.

---
-- Identity and lifetime.
-- @summaryonly
-- @note IdentityAndLifetime "Identity and lifetime"
--
-- @{Stopwatch.Create} and @{Stopwatch.Get} return a lightweight stopwatch object identified only by name.
-- The actual stopwatch state (elapsed time, laps, callbacks, and so on) is stored separately and
-- looked up by name every time you call a method.
--
-- The stopwatch object passed to callbacks, time triggers, and interval triggers works the same way.
--
-- What this means in practice:
--
-- - Calling @{Stopwatch.Get} twice with the same name gives you two objects that both control the same stopwatch. Either one works.
-- - Do not store your own data on the stopwatch object. Stopwatch does not use or save it.
--
-- If you call @{Stopwatch.Create} with a name that is already in use, the existing
-- stopwatch is replaced by a new one. Any object you already have for that name will
-- automatically control the new stopwatch on its next method call.
--
-- If you call @{Stopwatch.Delete}, any object you already have for that name becomes
-- stale. Calling methods on that old object is safe: Stopwatch logs a warning,
-- state-changing methods do nothing, and query methods return false or nil depending
-- on the method.
-- Use @{Stopwatch.IfExists} if you need to check whether a stopwatch still exists before using it.
--
-- If @{Stopwatch.Delete} or @{Stopwatch.Create} (overwrite) is called during a callback,
-- time trigger, or interval trigger, any remaining callbacks and triggers scheduled for
-- that stopwatch on the same frame are skipped. See @{CallbackTriggerOrder|Callback and trigger order}.

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
-- Use @{Stopwatch:GetAllLapTimes}, @{Stopwatch:GetAllLapTimesInSeconds}, and @{Stopwatch:GetAllLapTimesFormatted} to retrieve all lap delta times at once.
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
-- The callback names used below, such as `ON_START` and `ON_LAP`, are the constants listed in @{Stopwatch.CallbackTypes}.
--
-- You can assign callbacks when creating a stopwatch through @{StopwatchData}, or later with @{Stopwatch:SetCallback}.
--
-- Each callback can be assigned with or without extra arguments.
--
-- Without extra arguments, pass the `LevelFuncs` function directly:
--
--    onLap = LevelFuncs.MyFunc — called as MyFunc(stopwatch)
--
-- <br>With extra arguments, pass a table whose first value is the `LevelFuncs` function and whose
--   remaining values are passed after the stopwatch:
--
--    onLap = { LevelFuncs.MyFunc, "Checkpoint", 3 } — called as MyFunc(stopwatch, "Checkpoint", 3)
--
-- <br>The same rule applies to @{Stopwatch:SetCallback}: pass the function first, then any extra arguments as positional parameters:
--
--    Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.MyFunc, "Checkpoint", 3)
--
-- Most callbacks are immediate: they run when the related stopwatch method actually causes that event.
--
-- `ON_MAX_TIME` is the exception: it is checked automatically while the stopwatch is active and not paused.
--
-- Interval triggers are a separate repeating-callback feature and are documented in @{IntervalTriggers|Interval triggers}. For the exact same-frame order between interval triggers, time triggers, and `ON_MAX_TIME`, see @{CallbackTriggerOrder|Callback and trigger order}. For rules on how callback functions must be defined, see @{LevelFuncsRules|LevelFuncs rules}.
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
-- Time triggers are written as pairs inside a list:
--
-- - `seconds, LevelFuncs.MyFunc`
--
-- or
--
-- - `seconds, { LevelFuncs.MyFunc, arg1, arg2, ... }`
--
-- In other words:
--
-- - if the callback needs no extra arguments, write the _function directly_;
-- - if the callback needs extra arguments, write a _table whose first value is the function and the following values are its arguments_.
--
-- <br>Please note:
--
-- - Write complete pairs, one after another, with no values left out.
-- - A callback table must contain at least one extra argument; do not write `{ LevelFuncs.MyFunc }`.
-- - For restrictions on extra arguments (including `nil`), see @{LevelFuncsRules|LevelFuncs rules}.
--
-- Each _seconds, callback_ pair counts as one trigger in the list.
--
-- In the example, `1.00, LevelFuncs.Step1` is _trigger 1_, `2.50, { LevelFuncs.Step2, "Door Open" }` is _trigger 2_, and `4.00, { LevelFuncs.Step3, "Wave", 2 }` is _trigger 3_.
--
--    Stopwatch.Create({
--        name = "sequenceTimer",
--        timeTriggers = {
--            1.00, LevelFuncs.Step1,                    -- trigger 1
--            2.50, { LevelFuncs.Step2, "Door opened" }, -- trigger 2
--            4.00, { LevelFuncs.Step3, "Wave", 2 }      -- trigger 3
--        }
--    })
--
-- Common mistakes:
--
--    -- incomplete pair.
--    Stopwatch.Create({
--        name = "sequenceTimer",
--        timeTriggers = {
--            1.00, LevelFuncs.Step1,
--            2.50
--        }
--    })
--    
--    -- when using a table, the first value must be the callback function.
--    Stopwatch.Create({
--        name = "sequenceTimer",
--        timeTriggers = {
--            1.00, { "Door opened", LevelFuncs.Step1 }
--        }
--    })
--    
--    -- callback table without extra arguments. Use LevelFuncs.Step1 directly instead.
--    Stopwatch.Create({
--        name = "sequenceTimer",
--        timeTriggers = {
--            1.00, { LevelFuncs.Step1 }
--        }
--    })
--    
--    -- nil extra argument.
--    Stopwatch.Create({
--        name = "sequenceTimer",
--        timeTriggers = {
--            1.00, { LevelFuncs.Step1, nil, "Door opened" }
--        }
--    })
--
-- Each trigger time is rounded to 2 decimal places and then converted to the nearest frame at 30 FPS. In other words, time triggers work on the game's frame grid, not with exact floating-point timing.
--
-- Time trigger callbacks follow the same authoring rules described in @{LevelFuncsRules|LevelFuncs rules}.
--
-- Time triggers are checked automatically while the stopwatch is active and not paused. For ordering relative to interval triggers and `ON_MAX_TIME`, see @{CallbackTriggerOrder|Callback and trigger order}.
--
-- If more than one trigger falls on the same frame, they are called in the same order they appear in the list.
--
-- `Stopwatch:GetTimeTriggers()` returns the current triggers in the same compact format, normalized and in listed order.
--
-- If a trigger is beyond the current `maxTime`, it is kept but it will not run unless that time becomes reachable.
--
-- Time triggers fire once on the current timeline. If elapsed time is moved backwards, or the stopwatch is restarted from zero with `Stopwatch:Start(true)` or @{Stopwatch:Reset}, future time triggers are armed again from that new time.
--
-- If elapsed time is moved forward, past time triggers are not replayed; the next future trigger is recalculated from the new time.

---
-- Interval triggers overview.
-- @summaryonly
-- @note IntervalTriggers "Interval triggers"
--
-- An interval trigger is a repeating event: its callback is called every time the stopwatch
-- advances by a configured number of seconds. Unlike time triggers, which fire once at a fixed
-- absolute time, interval triggers keep firing for as long as the stopwatch is ticking.
--
-- Multiple interval triggers can be registered on the same stopwatch, each with its own period
-- and callback. They are defined as pairs inside a list, using the same format as time triggers:
--
-- - `seconds, LevelFuncs.MyFunc`
--
-- or
--
-- - `seconds, { LevelFuncs.MyFunc, arg1, arg2, ... }`
--
-- In other words:
--
-- - if the callback needs no extra arguments, write the _function directly_;
-- - if the callback needs extra arguments, write a _table whose first value is the function and the following values are its arguments_.
--
-- <br>Please note:
--
-- - Write complete pairs, one after another, with no values left out.
-- - A callback table must contain at least one extra argument; do not write `{ LevelFuncs.MyFunc }`.
-- - For restrictions on extra arguments (including `nil`), see @{LevelFuncsRules|LevelFuncs rules}.
--
-- Each _seconds, callback_ pair counts as one interval trigger in the list. The first value
-- of each pair is the period (how often the trigger fires, not an absolute time).
--
--    Stopwatch.Create({
--        name = "raceTimer",
--        intervalTriggers = {
--            0.03, LevelFuncs.UpdateHUD,            -- trigger 1: fires every frame while ticking
--            1.00, LevelFuncs.LogElapsed,           -- trigger 2: fires every second
--            0.50, { LevelFuncs.PlaySound, "beep" } -- trigger 3: fires every 0.5 seconds
--        }
--    })
--
-- Each period is rounded to 2 decimal places and converted to the nearest frame at 30 FPS.
-- After rounding, the minimum period is `0.03` seconds (1 frame). See @{FramePrecision|Frame precision}.
--
-- <br>**When to use interval triggers vs LevelFuncs.OnLoop**
--
-- Use interval triggers when a function needs to repeat on a fixed schedule _while the stopwatch is
-- active and ticking_. They are tied to the stopwatch lifetime: they stop when the stopwatch stops,
-- pause when it pauses, and rebase automatically when elapsed time changes.
--
-- `LevelFuncs.OnLoop` runs every frame unconditionally, regardless of any stopwatch state. If a
-- function has no connection to a specific running stopwatch, use `OnLoop` instead.
--
-- A period of `0.03` is appropriate when per-frame execution is needed _for the duration of the
-- stopwatch only_. If the same function should also run when the stopwatch is stopped or paused,
-- register it with `OnLoop` directly.
--
-- <br>Interval trigger callbacks follow the same authoring rules described in @{LevelFuncsRules|LevelFuncs rules}.
--
-- Interval triggers are checked automatically while the stopwatch is active and not paused.
-- Each trigger is tracked independently: two triggers with different periods advance their own
-- counters and do not affect each other.
--
-- On the same frame, interval triggers fire in their listed order before any time triggers.
-- For same-frame ordering and rules about modifying the trigger list from inside an interval trigger callback, see @{CallbackTriggerOrder|Callback and trigger order}.
--
-- If elapsed time is moved manually (via @{Stopwatch:SetElapsedTime}, @{Stopwatch:Start} with reset,
-- or @{Stopwatch:Reset}), all interval counters are rebased from the new elapsed time so that
-- past thresholds are not replayed retroactively.

---
-- LevelFuncs rules.
-- @summaryonly
-- @note LevelFuncsRules "LevelFuncs rules"
--
-- Stopwatch callbacks, time trigger functions, and interval trigger functions must be functions stored in `LevelFuncs`.
-- Do not pass a local anonymous function directly.
--
-- Define the LevelFuncs function before assigning it to a stopwatch through `Stopwatch.Create`,
-- `Stopwatch:SetCallback`, a time trigger, or an interval trigger. If it is assigned before it exists,
-- the value passed to Stopwatch is `nil` and the callback will not be registered.
--
-- <br>**Function signature**
--
-- Every function called by Stopwatch always receives **the stopwatch itself** as its **first argument**,
-- so you can call any of its methods directly from inside the function.
-- If extra arguments were registered (via the `{ LevelFunc, arg1, arg2, ... }` table syntax or
-- via `SetCallback`'s varargs), they are passed **after** the stopwatch, in the same order they were registered.
--
-- Without extra arguments:
--
--    LevelFuncs.OnLap = function(stopwatch)
--        TEN.Util.PrintLog("Laps: " .. stopwatch:GetLapCount(), TEN.Util.LogLevel.INFO)
--    end
--    Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnLap)
--
-- With extra arguments (the stopwatch is still always first):
--
--    LevelFuncs.OnLap = function(stopwatch, zone, number)
--        TEN.Util.PrintLog("Reached " .. zone .. " #" .. number, TEN.Util.LogLevel.INFO)
--    end
--    Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnLap, "finish", 3)
--    -- called as: LevelFuncs.OnLap(stopwatch, "finish", 3)
--
-- The same rule applies to time triggers and interval triggers:
--
--    LevelFuncs.OnWave = function(stopwatch, waveNumber)
--        TEN.Util.PrintLog("Wave " .. waveNumber, TEN.Util.LogLevel.INFO)
--    end
--    Stopwatch.Get("RaceTimer"):AddTimeTrigger(5.0, LevelFuncs.OnWave, 2)
--    -- called as: LevelFuncs.OnWave(stopwatch, 2)
--
-- <br>**Extra arguments and nil**
--
-- Extra arguments cannot be `nil`. If you need to pass an optional value, use a placeholder
-- (such as an empty string `""` or the number `0`) and handle it inside the function.
--
-- In a callback table, gaps between arguments are also not allowed. Note that Lua silently
-- drops trailing `nil` values before Stopwatch can see them, so they will not be registered.
--
-- <br>**Definition order**
--
-- **Bad**: `LevelFuncs.OnRaceTimerLap` has not been defined yet at this point.
--
--    Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnRaceTimerLap)
--
--    LevelFuncs.OnRaceTimerLap = function(stopwatch)
--        TEN.Util.PrintLog("Lap " .. stopwatch:GetLapCount(), TEN.Util.LogLevel.INFO)
--    end
--
-- **Good**: define the function first, then assign it.
--
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
-- _Same-frame order:_<br>While a stopwatch is active and not paused, Stopwatch checks its scheduled events automatically.
--
-- If everything happens on the same frame, the order is:
--
--    time ---->
--    [frame update] -> [intervalTrigger 1] -> [intervalTrigger 2] -> [timeTrigger 1] -> [timeTrigger 2] -> [ON_MAX_TIME]
--
-- Interval triggers fire in their listed order. If more than one time trigger is due on that frame, they run in the order they appear in `timeTriggers`.
--
-- <br>_Stop() behavior:_<br>`Stopwatch:Stop` does not force an extra interval trigger callback.
--
-- If <code>Stopwatch:Stop</code> is called on a frame where an interval trigger is also due, it runs only if that frame had already been checked before <code>Stopwatch:Stop</code> was called.
--
-- If <code>Stopwatch:Stop</code> is called inside an interval trigger or inside a timeTrigger callback, the current callback finishes first. Then `ON_STOP` is called, and the rest of that frame's scheduled work is skipped.
--
--    time ---->
--    [same frame] -> [current callback finishes] -> [ON_STOP] -> [rest skipped]
--
-- <br>_Modifying triggers from inside a callback:_<br>If a scheduled callback changes the
-- stopwatch timeline, or modifies the interval trigger list or time trigger
-- list (for example by calling @{Stopwatch:AddIntervalTrigger},
-- @{Stopwatch:SetIntervalTriggers}, @{Stopwatch:SetElapsedTime}, or
-- @{Stopwatch:SetTimeTriggers}), the current callback still finishes normally,
-- but the rest of that frame's scheduled work — remaining interval triggers,
-- time triggers, and `ON_MAX_TIME` — is skipped.
--
--    time ---->
--    [intervalTrigger A fires] -> [A adds/removes a trigger] -> [A finishes] -> [rest skipped]
--
-- <br>_More than one stopwatch:_<br>The order shown above applies to scheduled work inside one stopwatch.
-- If two different stopwatches have callbacks or triggers due on the same frame, the order in which those stopwatches are processed is not guaranteed.
-- Do not write code that depends on one stopwatch running its events before another on the same frame.
--
-- <br>_Reaching maxTime:_<br>Reaching `maxTime` stops the stopwatch and calls `ON_MAX_TIME`, but it does not also call `ON_STOP`.

----
-- Functions
-- @section functions

--- Create (but do not start) a new stopwatch.
-- See @{IdentityAndLifetime|Identity and lifetime} in Key concepts for details.
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
-- -- Example 3: creation of a stopwatch with callbacks and interval triggers
-- LevelFuncs.OnLapRecorded = function(sw)
--     TEN.Util.PrintLog("Lap " .. sw:GetLapCount(), TEN.Util.LogLevel.INFO)
-- end
-- LevelFuncs.OnTick = function(sw)
--     TEN.Util.PrintLog("Elapsed: " .. sw:GetElapsedTimeInSeconds() .. "s", TEN.Util.LogLevel.INFO)
-- end
-- LevelFuncs.OnBeep = function(sw, sound)
--     TEN.Util.PrintLog(sound, TEN.Util.LogLevel.INFO)
-- end
-- Stopwatch.Create({
--     name            = "RaceTimer",
--     timeFormat      = { minutes = true, seconds = true, centiseconds = true },
--     onLap           = LevelFuncs.OnLapRecorded,
--     intervalTriggers = {
--         1.00, LevelFuncs.OnTick,
--         0.50, { LevelFuncs.OnBeep, "beep" },
--     },
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
    stopwatchEntry.position = ResolveOrDefault(stopwatchData.position, IsVec2(stopwatchData.position), DEFAULT_POSITION, "wrong position for '" .. name .. "', set to default")

    -- check scale
    stopwatchEntry.scale = ResolveOrDefault(stopwatchData.scale, IsNumber(stopwatchData.scale) and stopwatchData.scale > 0, 1, "wrong scale for '" .. name .. "', set to 1")

    -- check color
    stopwatchEntry.color = ResolveOrDefault(stopwatchData.color, IsColor(stopwatchData.color), DEFAULT_COLOR, "wrong color for '" .. name .. "', set to default")

    -- check pausedColor
    stopwatchEntry.pausedColor = ResolveOrDefault(stopwatchData.pausedColor, IsColor(stopwatchData.pausedColor), DEFAULT_PAUSED_COLOR, "wrong pausedColor for '" .. name .. "', set to default")

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
    stopwatchEntry.intervalTriggers = {}
    stopwatchEntry.timeTriggers = {}

    -- Runtime-only bookkeeping rebuilt from the persisted state when needed.
    stopwatchEntry.lastRenderedFrameCount = nil
    ResetScheduledRuntimeState(stopwatchEntry)

    -- assign callbacks from stopwatchData fields.
    -- Each field accepts either a bare LevelFunc (no extra args) or a table
    -- { LevelFunc, arg1, arg2, ... } (with extra args passed to the callback).
    for _, cb in ipairs(CALLBACKFIELDS) do
        local cbSpec = stopwatchData[cb.field]
        if not IsNull(cbSpec) then
            local func, args = NormalizePublicTimeTriggerCallback(
                cbSpec,
                CreateWarningPrefix .. "wrong value for " .. cb.field .. " in '" .. name .. "': ",
                logLevelWarning
            )
            if func then
                local cbData = { func = func }
                if args then
                    cbData.args = args
                end
                stopwatchEntry.callbacks[cb.key] = cbData
            end
        end
    end

    -- assign interval triggers from stopwatchData
    local intervalTriggers = NormalizeIntervalTriggerList(
        stopwatchData.intervalTriggers,
        CreateWarningPrefix .. "intervalTriggers for '" .. name .. "' must be an array table.",
        CreateWarningPrefix .. "intervalTriggers for '" .. name .. "' must not contain holes; indices must be consecutive starting at 1.",
        CreateWarningPrefix .. "intervalTriggers for '" .. name .. "' must contain complete seconds/callback pairs.",
        CreateWarningPrefix .. "intervalTriggers",
        " for '" .. name .. "'",
        logLevelWarning
    )
    if intervalTriggers then
        stopwatchEntry.intervalTriggers = intervalTriggers
    end
    RebuildIntervalTriggers(stopwatchEntry)

    local timeTriggers = NormalizeTimeTriggerList(
        stopwatchData.timeTriggers,
        CreateWarningPrefix .. "timeTriggers for '" .. name .. "' must be an array table.",
        CreateWarningPrefix .. "timeTriggers for '" .. name .. "' must not contain holes; indices must be consecutive starting at 1.",
        CreateWarningPrefix .. "timeTriggers for '" .. name .. "' must contain complete seconds/callback pairs.",
        CreateWarningPrefix .. "timeTriggers",
        " for '" .. name .. "'",
        logLevelWarning
    )
    if timeTriggers then
        stopwatchEntry.timeTriggers = timeTriggers
    end
    RebuildTimeTriggers(stopwatchEntry)
    if stopwatchEntry.maxTime then
        WarnTimeTriggersBeyondMaxTime(stopwatchEntry.timeTriggers, stopwatchEntry.maxTime:GetFrameCount(), CreateWarningPrefix, name)
    end

    if stopwatchEntry.timeFormat then
        local initText = GenerateTimeFormattedString(ZERO, stopwatchEntry.timeFormat)
        stopwatchStrings[name] = DisplayString(initText, PercentToScreen(stopwatchEntry.position), stopwatchEntry.scale, DEFAULT_COLOR, false, stopwatchEntry.textOptions)
        stopwatchEntry.lastRenderedFrameCount = ZERO:GetFrameCount()
    end

    return setmetatable(self, Stopwatch)
end

--- Delete a stopwatch by name.
-- See @{IdentityAndLifetime|Identity and lifetime} in Key concepts for details.
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
-- See @{IdentityAndLifetime|Identity and lifetime} in Key concepts for details.
-- @tparam string name The name of the stopwatch to retrieve.
-- @treturn[1] Stopwatch The stopwatch object if found
-- @treturn[2] nil If no stopwatch with the given name exists, with a warning message logged to the console.
-- @usage
-- local myStopwatch = Stopwatch.Get("MyStopwatch")
Stopwatch.Get = function(name)
    local errorPrefix = "in Stopwatch.Get(): "
    if not IsString(name) then
        LogMessage("Error " .. errorPrefix .. "name must be a string.", logLevelError)
        return nil
    end
    if not stopwatches[name] then
        LogMessage("Warning " .. errorPrefix .. "no stopwatch found with name '" .. tostring(name) .. "'.", logLevelWarning)
        return nil
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
-- - Callbacks.
--
-- - Interval triggers.
--
-- - Absolute time triggers.
--
-- Use @{Stopwatch.Get} before calling methods when the stopwatch may not exist.
-- @usage
--      -- Examples of some methods
-- Stopwatch.Get("MyStopwatch"):Start()
-- Stopwatch.Get("MyStopwatch"):Pause()
-- Stopwatch.Get("MyStopwatch"):Stop()

--- Start or resume the stopwatch.
-- @tparam[opt=false] bool reset<br>
-- If `true`, resets elapsed time to zero, clears laps, rebases all interval trigger counters, and rebuilds future timeTriggers before starting.
--
-- If `false` or not provided, the stopwatch will continue from its current time.<br>
-- @usage
-- -- Example 1: Start the stopwatch
-- Stopwatch.Get("MyStopwatch"):Start()
--
-- -- Example 2: Start the stopwatch and reset elapsed time and laps
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
        RebuildIntervalTriggers(stopwatch)
        RebuildTimeTriggers(stopwatch)
        InvalidateScheduledState(stopwatch)
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
    if ds and wasActive then
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

--- Reset the stopwatch to zero and stop it. Laps are cleared, all interval trigger counters are rebased from zero, and future timeTriggers are rebuilt from zero.
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
    RebuildIntervalTriggers(stopwatch)
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
-- @usage
-- if Stopwatch.Get("MyStopwatch"):IsTicking() then
--     -- Do something that should only happen while the stopwatch is ticking
-- end
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
-- All interval trigger counters are recalculated from the new elapsed time so that past thresholds are not replayed.
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
        RealignIntervalCounts(stopwatch)
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
-- @tparam[opt={minutes = true&#44; seconds = true&#44; centiseconds = true}] table|bool timeFormat The format to use for the time string. Omit it or pass `nil` to use the default format. Pass `false` to return an empty string. Invalid values log a warning and also use the default format. See `timeFormat` for details.<br>
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
            WarnTimeTriggersBeyondMaxTime(stopwatch.timeTriggers or {}, frames, "Warning in Stopwatch:SetMaxTime(): ", self.name)
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
        return Vec2(position.x, position.y)
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
        local newPos = Vec2(x, y)
        stopwatch.position = newPos
        local ds = stopwatchStrings[self.name]
        if ds then
            ds:SetPosition(PercentToScreen(newPos))
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
    local laps = GetValidatedLap(stopwatch.laps, self.name, "GetLapTime", index)
    if not laps then
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
    local laps = GetValidatedLap(stopwatch.laps, self.name, "GetLapTimeInSeconds", index)
    if not laps then
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
    local laps = GetValidatedLap(stopwatch.laps, self.name, "GetLapTimeFormatted", index)
    if not laps then
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
    local _, lap = GetValidatedLap(stopwatch.laps, self.name, "GetSplitTime", index)
    if not lap then
        return nil
    end
    return lap
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
    local _, lap = GetValidatedLap(stopwatch.laps, self.name, "GetSplitTimeInSeconds", index)
    if not lap then
        return nil
    end
    return FramesToSeconds(lap:GetFrameCount())
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
    local _, lap = GetValidatedLap(stopwatch.laps, self.name, "GetSplitTimeFormatted", index)
    if not lap then
        return nil
    end
    timeFormat = NormalizeTimeFormat(timeFormat, "Warning in Stopwatch:GetSplitTimeFormatted(): wrong value for timeFormat, default format will be used.")
    return GenerateTimeFormattedString(lap, timeFormat)
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
    return ExportLapDeltas(stopwatch.laps, Time)
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
    return ExportLapDeltas(stopwatch.laps, FramesToSeconds)
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
    return ExportFormattedLapDeltas(stopwatch.laps, timeFormat)
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
-- Each callback receives the stopwatch as its first argument. Any extra arguments passed here are forwarded
-- after the stopwatch each time the callback fires.
-- For callback ordering and same-frame overlap rules, see @{Callbacks|Callbacks overview}.
-- @tparam CallbackTypes callbackType The callback type. Use a constant from @{Stopwatch.CallbackTypes}.
-- @tparam function func A `LevelFuncs` function. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Signature: `function(stopwatch, ...)`.
-- @param ... Optional extra arguments stored with the callback and passed after the stopwatch each time it fires. `nil` values are not allowed.
-- @usage
-- LevelFuncs.OnLapRecorded = function(sw)
--     TEN.Util.PrintLog("Lap " .. sw:GetLapCount(), TEN.Util.LogLevel.INFO)
-- end
-- Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnLapRecorded)
--
-- -- With extra arguments forwarded to the callback
-- LevelFuncs.OnCheckpoint = function(sw, zone, number)
--     TEN.Util.PrintLog("Reached " .. zone .. " checkpoint " .. number, TEN.Util.LogLevel.INFO)
-- end
-- Stopwatch.Get("RaceTimer"):SetCallback(Stopwatch.CallbackTypes.ON_LAP, LevelFuncs.OnCheckpoint, "finish", 3)
function Stopwatch:SetCallback(callbackType, func, ...)
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
    local argsOk, args = CollectTimeTriggerArgs(self.name, "SetCallback", ...)
    if not argsOk then
        return
    end
    local cbData = { func = func }
    if args then
        cbData.args = args
    end
    stopwatch.callbacks[callbackType] = cbData
end

--- Remove a callback function for a specific event.
-- @tparam CallbackTypes callbackType The callback type. Use a constant from @{Stopwatch.CallbackTypes}.
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

--- Replace the entire interval trigger list.
-- Validation is atomic: if any entry is invalid, the existing list is left unchanged.
-- Pass one compact list in the same format described in @{IntervalTriggers|Interval triggers overview}: `seconds, callback, seconds, callback, ...`.
-- Each callback entry can be either a `LevelFuncs` function or a table whose first value is the `LevelFuncs` function and whose remaining values are the extra arguments passed when the trigger fires.
-- Callback tables must contain at least one extra argument and cannot contain `nil` values.
-- Passing an empty table clears the list.
-- All interval counters are rebased from the current elapsed time after the list is replaced.
-- @tparam table triggers A compact list of `seconds, callback` pairs.
-- @usage
-- Stopwatch.Get("RaceTimer"):SetIntervalTriggers({
--     0.03, LevelFuncs.UpdateHUD,
--     1.00, { LevelFuncs.LogElapsed, "race" },
-- })
function Stopwatch:SetIntervalTriggers(triggers)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetIntervalTriggers")
    if not stopwatch then
        return
    end
    local normalized = NormalizeIntervalTriggerList(
        triggers,
        "Error in Stopwatch:SetIntervalTriggers(): intervalTriggers must be an array table for '" .. self.name .. "'.",
        "Error in Stopwatch:SetIntervalTriggers(): intervalTriggers for '" .. self.name .. "' must not contain holes; indices must be consecutive starting at 1.",
        "Error in Stopwatch:SetIntervalTriggers(): intervalTriggers for '" .. self.name .. "' must contain complete seconds/callback pairs.",
        "Error in Stopwatch:SetIntervalTriggers(): intervalTriggers",
        " for '" .. self.name .. "'",
        logLevelError
    )
    if not normalized then
        return
    end
    InvalidateScheduledState(stopwatch)
    stopwatch.intervalTriggers = normalized
    RebuildIntervalTriggers(stopwatch)
end

--- Get a copy of the current interval trigger list in listed order.
-- The returned value uses the same compact format described in @{IntervalTriggers|Interval triggers overview}: `seconds, callback, seconds, callback, ...`.
-- If a trigger has no extra arguments, its callback is returned as the bare `LevelFuncs` function. If it has extra arguments, its callback is returned as a table whose first value is the `LevelFuncs` function followed by the stored arguments.
-- Editing the returned table or any returned callback table does not affect the stopwatch until you pass data back through @{Stopwatch:SetIntervalTriggers}.
-- Returned callback tables are shallow copies. Nested tables inside the stored extra arguments remain shared references.
-- Returned periods are the normalized values stored by the stopwatch, rounded to 2 decimal places.
-- @treturn table A compact list of `seconds, callback` pairs in listed order.
-- @usage
-- local triggers = Stopwatch.Get("RaceTimer"):GetIntervalTriggers()
function Stopwatch:GetIntervalTriggers()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetIntervalTriggers")
    if stopwatch then
        return ExportPublicTriggerList(stopwatch.intervalTriggers or {}, "period")
    end
    return nil
end

--- Add a new interval trigger to the stopwatch.
-- The trigger is appended to the list. The interval counter for the new trigger is initialized from the current elapsed time so it does not fire retroactively.
-- The callback shape matches @{Stopwatch:SetIntervalTriggers}: pass the `LevelFuncs` function first, followed by any optional positional extra arguments.
-- For ordering and overlap rules, see @{IntervalTriggers|Interval triggers overview}.
-- @tparam float seconds The period in seconds. It is rounded to 2 decimal places first; after rounding, it must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}.
-- @tparam function func A `LevelFuncs` function. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Signature: `function(stopwatch, ...)`.
-- @param ... Optional positional extra arguments stored with the trigger and passed to the callback when it fires. `nil` values are not allowed.
-- @usage
-- Stopwatch.Get("RaceTimer"):AddIntervalTrigger(1.0, LevelFuncs.LogElapsed)
-- Stopwatch.Get("RaceTimer"):AddIntervalTrigger(0.5, LevelFuncs.PlayBeep, "high")
function Stopwatch:AddIntervalTrigger(seconds, func, ...)
    local stopwatch = GetStopwatchOrWarn(self.name, "AddIntervalTrigger")
    if not stopwatch then
        return
    end
    local normalized = NormalizeIntervalTriggerFromParts(self.name, "AddIntervalTrigger", seconds, func, ...)
    if not normalized then
        return
    end
    InvalidateScheduledState(stopwatch)
    insert(stopwatch.intervalTriggers, normalized)
    RebuildIntervalTriggers(stopwatch)
end

--- Replace one interval trigger by index.
-- Validation is atomic: on invalid input the existing trigger is left unchanged.
-- Pass the period first, then the `LevelFuncs` function, then any optional positional extra arguments.
-- The replaced trigger's counter is rebased from the current elapsed time.
-- @tparam int index The 1-based trigger index in the list.
-- @tparam float seconds The new period in seconds. It is rounded to 2 decimal places first; after rounding, it must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}.
-- @tparam function func A `LevelFuncs` function. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Signature: `function(stopwatch, ...)`.
-- @param ... Optional positional extra arguments stored with the trigger and passed to the callback when it fires. `nil` values are not allowed.
-- @usage
-- -- Replace trigger 2 with a new 2-second period and callback
-- Stopwatch.Get("RaceTimer"):SetIntervalTrigger(2, 2.0, LevelFuncs.SlowLog)
-- -- Replace trigger 1, keeping the same period but changing the callback and adding an argument
-- Stopwatch.Get("RaceTimer"):SetIntervalTrigger(1, 0.03, LevelFuncs.UpdateHUD, "fast")
function Stopwatch:SetIntervalTrigger(index, seconds, func, ...)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetIntervalTrigger")
    if not stopwatch then
        return
    end
    local triggerCount = #stopwatch.intervalTriggers
    if not ValidatePositiveIndex(index, triggerCount, "Error in Stopwatch:SetIntervalTrigger(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' (interval trigger count: " .. tostring(triggerCount) .. ").", logLevelError) then
        return
    end
    local normalized = NormalizeIntervalTriggerFromParts(self.name, "SetIntervalTrigger", seconds, func, ...)
    if not normalized then
        return
    end
    InvalidateScheduledState(stopwatch)
    stopwatch.intervalTriggers[index] = normalized
    RebuildIntervalTriggers(stopwatch)
end

--- Remove one interval trigger by index.
-- @tparam int index The 1-based trigger index in the list.
-- @usage
-- Stopwatch.Get("RaceTimer"):RemoveIntervalTrigger(2)
function Stopwatch:RemoveIntervalTrigger(index)
    local stopwatch = GetStopwatchOrWarn(self.name, "RemoveIntervalTrigger")
    if not stopwatch then
        return
    end
    local triggerCount = #stopwatch.intervalTriggers
    if not ValidatePositiveIndex(index, triggerCount, "Error in Stopwatch:RemoveIntervalTrigger(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' (interval trigger count: " .. tostring(triggerCount) .. ").", logLevelError) then
        return
    end
    InvalidateScheduledState(stopwatch)
    remove(stopwatch.intervalTriggers, index)
    RebuildIntervalTriggers(stopwatch)
end

--- Remove all interval triggers from the stopwatch.
-- @usage
-- Stopwatch.Get("RaceTimer"):ClearIntervalTriggers()
function Stopwatch:ClearIntervalTriggers()
    local stopwatch = GetStopwatchOrWarn(self.name, "ClearIntervalTriggers")
    if not stopwatch then
        return
    end
    InvalidateScheduledState(stopwatch)
    stopwatch.intervalTriggers = {}
    RebuildIntervalTriggers(stopwatch)
end

--- Add a new absolute time trigger to the stopwatch.
-- The trigger is appended to the public trigger list. The runtime ordering is rebuilt immediately from the current elapsed time.
-- If another trigger already exists at the same normalized time, or resolves to the same frame, both triggers are kept. Due triggers on the same frame fire in public order, so the newly added trigger runs after existing ones for that frame.
-- If the new trigger resolves to the current frame or a past frame, it is stored but not fired retroactively.
-- The callback shape matches @{Stopwatch:SetTimeTrigger}: pass the `LevelFuncs` function first, followed by any optional positional extra arguments.
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

    local normalizedTrigger = NormalizeTimeTriggerFromParts(
        self.name,
        "AddTimeTrigger",
        seconds,
        func,
        ...
    )
    if not normalizedTrigger then
        return
    end

    InvalidateScheduledState(stopwatch)
    insert(stopwatch.timeTriggers, normalizedTrigger)
    RebuildTimeTriggers(stopwatch)
    if stopwatch.maxTime then
        WarnTimeTriggersBeyondMaxTime({ normalizedTrigger }, stopwatch.maxTime:GetFrameCount(), "Warning in Stopwatch:AddTimeTrigger(): ", self.name)
    end
end

--- Replace the entire time trigger list.
-- Validation is atomic: if one trigger is invalid, the existing list is left unchanged.
-- Pass one compact public list in the same format described in @{TimeTriggers|Time triggers overview}: `seconds, callback, seconds, callback, ...`.
-- Each callback entry can be either a `LevelFuncs` function or a table whose first value is the `LevelFuncs` function and whose remaining values are the extra arguments passed when the trigger fires.
-- Callback tables must contain at least one extra argument and cannot contain `nil` values.
-- If multiple entries resolve to the same frame, they are all kept and fire in list order.
-- Passing an empty table clears the list.
-- @tparam table triggers A compact list of `seconds, callback` pairs.
-- @usage
-- Stopwatch.Get("RaceTimer"):SetTimeTriggers({
--     3.0, LevelFuncs.SpawnWave,                            -- trigger 1
--     6.5, { LevelFuncs.ShowHint, "Second wave incoming" }, -- trigger 2
-- })
function Stopwatch:SetTimeTriggers(triggers)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetTimeTriggers")
    if not stopwatch then
        return
    end
    local normalizedTriggers = NormalizeTimeTriggerList(
        triggers,
        "Error in Stopwatch:SetTimeTriggers(): timeTriggers must be an array table for '" .. self.name .. "'.",
        "Error in Stopwatch:SetTimeTriggers(): timeTriggers for '" .. self.name .. "' must not contain holes; indices must be consecutive starting at 1.",
        "Error in Stopwatch:SetTimeTriggers(): timeTriggers for '" .. self.name .. "' must contain complete seconds/callback pairs.",
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
    if stopwatch.maxTime then
        WarnTimeTriggersBeyondMaxTime(normalizedTriggers, stopwatch.maxTime:GetFrameCount(), "Warning in Stopwatch:SetTimeTriggers(): ", self.name)
    end
end

--- Get a copy of the current time trigger list in public order.
-- The returned value uses the same compact public format described in @{TimeTriggers|Time triggers overview}: `seconds, callback, seconds, callback, ...`.
-- If a trigger has no extra arguments, its callback is returned as the bare `LevelFuncs` function. If it has extra arguments, its callback is returned as a table whose first value is the `LevelFuncs` function followed by the stored arguments.
-- Editing the returned table or any returned callback table does not affect the stopwatch until you pass data back through @{Stopwatch:SetTimeTriggers}.
-- Returned callback tables are shallow copies. Nested tables inside the stored extra arguments remain shared references.
-- Returned times are the normalized public values stored by the stopwatch, rounded to 2 decimal places.
-- @treturn table A compact list of `seconds, callback` pairs in listed order.
-- @usage
-- local triggers = Stopwatch.Get("RaceTimer"):GetTimeTriggers()
function Stopwatch:GetTimeTriggers()
    local stopwatch = GetStopwatchOrWarn(self.name, "GetTimeTriggers")
    if stopwatch then
        return ExportPublicTriggerList(stopwatch.timeTriggers or {}, "at")
    end
    return nil
end

--- Replace one time trigger by public index.
-- Validation is atomic: on invalid input the existing trigger is left unchanged.
-- Pass the trigger time first, then the `LevelFuncs` function, then any optional positional extra arguments.
-- This matches @{Stopwatch:AddTimeTrigger}. To replace the whole list at once, use @{Stopwatch:SetTimeTriggers}.
-- Replacing one entry with a time already used elsewhere is allowed; if multiple triggers resolve to the same frame, they fire in public order.
-- @tparam int index The 1-based trigger index in the public list. Each complete `seconds, callback` pair counts as one trigger.
-- @tparam float seconds The new trigger time in seconds. It is rounded to 2 decimal places first; after rounding, it must be at least `0.03` seconds (1 frame at 30 FPS). See @{FramePrecision|Time values and frame precision}.
-- @tparam function func A `LevelFuncs` function. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts. Signature: `function(stopwatch, ...)`.
-- @tparam[opt] any ... Positional extra arguments stored with the trigger and passed to the callback when it fires. `nil` values are not allowed.
-- @usage
-- Stopwatch.Get("RaceTimer"):SetTimeTriggers({
--     1.00, LevelFuncs.Step1,                    -- trigger 1
--     2.50, { LevelFuncs.Step2, "Door opened" }, -- trigger 2
--     4.00, { LevelFuncs.Step3, "Wave", 2 },     -- trigger 3
-- })
-- -- Replaces trigger 2.
-- Stopwatch.Get("RaceTimer"):SetTimeTrigger(2, 8.0, LevelFuncs.PlayAlarm)
--
-- -- Replaces trigger 3 with a new callback and extra arguments, but the same trigger time.
-- Stopwatch.Get("RaceTimer"):SetTimeTrigger(3, 4.00, LevelFuncs.ShowHint, "Last lap")
function Stopwatch:SetTimeTrigger(index, seconds, func, ...)
    local stopwatch = GetStopwatchOrWarn(self.name, "SetTimeTrigger")
    if not stopwatch then
        return
    end
    local triggerCount = #stopwatch.timeTriggers
    if not ValidatePositiveIndex(index, triggerCount, "Error in Stopwatch:SetTimeTrigger(): invalid index (" .. tostring(index) .. ") for '" .. self.name .. "' stopwatch (trigger count: " .. tostring(triggerCount) .. ").", logLevelError) then
        return
    end

    local normalizedTrigger = NormalizeTimeTriggerFromParts(
        self.name,
        "SetTimeTrigger",
        seconds,
        func,
        ...
    )
    if not normalizedTrigger then
        return
    end

    InvalidateScheduledState(stopwatch)
    stopwatch.timeTriggers[index] = normalizedTrigger
    RebuildTimeTriggers(stopwatch)
    if stopwatch.maxTime then
        WarnTimeTriggersBeyondMaxTime({ normalizedTrigger }, stopwatch.maxTime:GetFrameCount(), "Warning in Stopwatch:SetTimeTrigger(): ", self.name)
    end
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
    -- Per-frame reconciliation: derive interval trigger callbacks, time trigger callbacks,
    -- display refresh, and maxTime termination from the current frame state.
    for name, s in pairs(stopwatches) do
        local ds = nil
        if s.timeFormat then
            ds = stopwatchStrings[name]
            if ds then
                ds:SetPosition(PercentToScreen(s.position))
            end
        end

        if s.active then
            local proxy = nil

            ClearScheduledDispatchFlags(s)

            -- Scheduled callbacks are processed in timeline order: interval triggers first,
            -- then absolute time triggers, and maxTime is decided from the final
            -- stopwatch state that remains after those callbacks finish.
            if not s.paused and s.compiledIntervalTriggers and #s.compiledIntervalTriggers > 0 then
                local frames = s.elapsedTime:GetFrameCount()
                -- Pre-check: only enter the dispatch block if at least one trigger is due.
                local anyDue = false
                for _, compiled in ipairs(s.compiledIntervalTriggers) do
                    if floor(frames / compiled.periodFrames) > (compiled.trigger.lastCount or 0) then
                        anyDue = true
                        break
                    end
                end
                if anyDue then
                    BeginScheduledCallbackDispatch(s)
                    for _, compiled in ipairs(s.compiledIntervalTriggers) do
                        local trigger = compiled.trigger
                        local currentCount = floor(frames / compiled.periodFrames)
                        local lastCount = trigger.lastCount or 0
                        if currentCount > lastCount then
                            for _ = lastCount + 1, currentCount do
                                proxy = EnsureStopwatchProxy(proxy, name)
                                FireCallbackData(trigger, proxy)
                                if ShouldAbortScheduledDispatch(s, name) then
                                    break
                                end
                            end
                            if not s.scheduledStateInvalidated then
                                trigger.lastCount = currentCount
                            end
                        end
                        if ShouldAbortScheduledDispatch(s, name) then
                            break
                        end
                    end
                    EndScheduledCallbackDispatch(s, name, proxy)
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
                        FireCallbackData(triggerData, proxy)
                        if ShouldAbortScheduledDispatch(s, name) then
                            break
                        end
                    end
                    EndScheduledCallbackDispatch(s, name, proxy)
                end
            end

            local instanceAlive = stopwatches[name] == s
            local reachedMaxTime = instanceAlive and not s.scheduledDispatchInterrupted and s.active and not s.paused and s.maxTime and s.elapsedTime >= s.maxTime

            if instanceAlive and s.timeFormat and (s.active or reachedMaxTime) then
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
        ResetScheduledRuntimeState(s)
        if not IsTable(s.intervalTriggers) then
            s.intervalTriggers = {}
        end
        -- Rebuild compiled interval cache; RealignIntervalCounts recalculates
        -- each lastCount from the persisted elapsedTime so intervals resume correctly.
        RebuildIntervalTriggers(s)
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
            stopwatchStrings[name] = DisplayString(text, PercentToScreen(s.position), s.scale, color, false, s.textOptions)
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
-- @tfield[opt=nil] function|table onStart Callback called when the stopwatch is started. Pass a `LevelFuncs` function directly, or a table `{ LevelFuncs.Func, arg1, ... }` to forward extra arguments. See @{Stopwatch.LevelFuncsRules|LevelFuncs rules} and @{Callbacks|Callbacks overview} in Key concepts. Equivalent to calling @{Stopwatch:SetCallback} with `ON_START` after creation.<br>
-- @tfield[opt=nil] function|table onResume Callback called when the stopwatch is resumed after a pause. Pass a `LevelFuncs` function directly, or a table `{ LevelFuncs.Func, arg1, ... }` to forward extra arguments. Equivalent to calling @{Stopwatch:SetCallback} with `ON_RESUME` after creation.<br>
-- @tfield[opt=nil] function|table onPause Callback called when the stopwatch is paused. Pass a `LevelFuncs` function directly, or a table `{ LevelFuncs.Func, arg1, ... }` to forward extra arguments. Equivalent to calling @{Stopwatch:SetCallback} with `ON_PAUSE` after creation.<br>
-- @tfield[opt=nil] function|table onStop Callback called when @{Stopwatch:Stop} stops an active stopwatch. Pass a `LevelFuncs` function directly, or a table `{ LevelFuncs.Func, arg1, ... }` to forward extra arguments. Equivalent to calling @{Stopwatch:SetCallback} with `ON_STOP` after creation. For overlap behavior with other callbacks, see @{Callbacks|Callbacks overview}.<br>
-- @tfield[opt=nil] function|table onReset Callback called after the stopwatch is reset to zero, stopped, and its laps are cleared. Pass a `LevelFuncs` function directly, or a table `{ LevelFuncs.Func, arg1, ... }` to forward extra arguments. Equivalent to calling @{Stopwatch:SetCallback} with `ON_RESET` after creation.<br>
-- @tfield[opt=nil] function|table onLap Callback called when a lap is recorded. Pass a `LevelFuncs` function directly, or a table `{ LevelFuncs.Func, arg1, ... }` to forward extra arguments. Equivalent to calling @{Stopwatch:SetCallback} with `ON_LAP` after creation.<br>
-- @tfield[opt=nil] function|table onMaxTime Callback called when the stopwatch reaches its configured maxTime and automatically stops. Pass a `LevelFuncs` function directly, or a table `{ LevelFuncs.Func, arg1, ... }` to forward extra arguments. Equivalent to calling @{Stopwatch:SetCallback} with `ON_MAX_TIME` after creation. For overlap behavior with interval triggers and onStop, see @{Callbacks|Callbacks overview}.<br>
-- @tfield[opt=nil] table intervalTriggers A compact list of `seconds, callback` pairs defining repeating interval triggers: `seconds, callback, seconds, callback, ...`. Each callback can be either a `LevelFuncs` function or a table whose first value is the `LevelFuncs` function and whose remaining values are the extra arguments passed when the trigger fires. Callback tables must contain at least one extra argument and cannot contain `nil` values. Each `seconds` value is the period (how often the trigger repeats). Validation is atomic during creation: if the list is invalid, the whole field is ignored and the stopwatch starts with no interval triggers. See @{IntervalTriggers|Interval triggers overview}, @{FramePrecision|Time values and frame precision}, and @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts.<br>
-- @tfield[opt=nil] table timeTriggers A compact list of `seconds, callback` pairs: `seconds, callback, seconds, callback, ...`. Each callback can be either a `LevelFuncs` function or a table whose first value is the `LevelFuncs` function and whose remaining values are the extra arguments passed when the trigger fires. Callback tables must contain at least one extra argument and cannot contain `nil` values. These define absolute one-shot cue points on the stopwatch timeline and are stored in public order. Validation is atomic during creation: if the list is invalid, the whole field is ignored and the stopwatch starts with no timeTriggers. See @{TimeTriggers|Time triggers overview}, @{FramePrecision|Time values and frame precision}, and @{Stopwatch.LevelFuncsRules|LevelFuncs rules} in Key concepts.<br>

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
-- @tfield "OnMaxTime" ON_MAX_TIME Callback called when the stopwatch reaches the configured maxTime and automatically stops. The stopwatch is already stopped when the callback is called, so you do not need to stop it manually inside the callback. For overlap behavior with interval triggers and `ON_STOP`, see @{Callbacks|Callbacks overview}.

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOOP, LevelFuncs.Engine.Stopwatch.IncrementTime)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POST_LOOP, LevelFuncs.Engine.Stopwatch.UpdateAll)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOAD, LevelFuncs.Engine.Stopwatch.Reload)

return Stopwatch