--- Basic stopwatches that perform countup. Timers are updated automatically at every frame before OnLoop event.<br>To use Timer inside scripts you need to call the module:
--	local Stopwatch = require("Engine.Stopwatch")
-- @luautil Stopwatch

local Type = require("Engine.Type")
local Utility = require("Engine.Util")

local Stopwatch = {}
Stopwatch.__index = Stopwatch
LevelFuncs.Engine.Stopwatch = {}
LevelVars.Engine.Stopwatch = {}
LevelVars.Engine.Stopwatch = { stopwatches = {} }

--- Create (but do not start) a new stopwatch.
-- @tparam StopwatchData stopwatchData A table containing the parameters for the stopwatch.
-- @treturn Stopwatch|nil The created stopwatch object, or nil on failure.
-- @usage local myStopwatch = Stopwatch.Create({ name = "MyStopwatch" })
Stopwatch.Create = function(stopwatchData)
    local errorPrefix = "Error in Stopwatch.Create(): "
    local warningPrefix = "Warning in Stopwatch.Create(): "
    if not Type.IsTable(stopwatchData) then
        TEN.Util.PrintLog(errorPrefix .. "stopwatchData must be a table.", LogLevel.ERROR)
        return nil
    end
    if not Type.IsString(stopwatchData.name) then
        TEN.Util.PrintLog(errorPrefix .. "stopwatchData.name must be a string.", LogLevel.ERROR)
        return nil
    end
    local self = { name = stopwatchData.name }
    if LevelVars.Engine.Stopwatch.stopwatches[stopwatchData.name] then
        TEN.Util.PrintLog(warningPrefix .. "a stopwatch with name '" .. stopwatchData.name .. "' already exists; overwriting it with a new one...", TEN.Util.LogLevel.WARNING)
    end
    LevelVars.Engine.Stopwatch.stopwatches[stopwatchData.name] = {}
    local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[stopwatchData.name]
    -- stopwatchEntry.name = stopwatchData.name
    local timerFormat = stopwatchData.timerFormat or false
    stopwatchEntry.timerFormat = Utility.CheckTimeFormat(timerFormat, "Warning in Stopwatch.Create(): wrong value for timerFormat, timerFormat for '".. stopwatchData.name .."' timer will be set to false")
    stopwatchEntry.position = Type.IsVec2(stopwatchData.position) and stopwatchData.position or TEN.Vec2(50, 90)
    if not Type.IsVec2(stopwatchEntry.position) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for position, position for '".. stopwatchData.name .."' timer will be set to Vec2(50, 90)", TEN.Util.LogLevel.WARNING)
    end
    stopwatchEntry.scale = Type.IsNumber(stopwatchData.scale) and stopwatchData.scale or 1
    if not Type.IsNumber(stopwatchEntry.scale) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for scale, scale for '".. stopwatchData.name .."' timer will be set to 1", TEN.Util.LogLevel.WARNING)
    end
    stopwatchEntry.color = Type.IsColor(stopwatchData.color) and stopwatchData.color or TEN.Color(255, 255, 255, 255)
    if not Type.IsColor(stopwatchEntry.color) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for color, color for '".. stopwatchData.name .."' timer will be set to Color(255, 255, 255, 255)", TEN.Util.LogLevel.WARNING)
    end
    stopwatchEntry.pausedColor = Type.IsColor(stopwatchData.pausedColor) and stopwatchData.pausedColor or TEN.Color(255, 255, 0, 255)
    if not Type.IsColor(stopwatchEntry.pausedColor) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for pausedColor, pausedColor for '".. stopwatchData.name .."' timer will be set to Color(255, 255, 0, 255)", TEN.Util.LogLevel.WARNING)
    end
    stopwatchEntry.startTime = Type.IsNumber(stopwatchData.startTime) and stopwatchData.startTime or 0
    if not Type.IsNumber(stopwatchEntry.startTime) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for startTime, startTime for '".. stopwatchData.name .."' timer will be set to 0", TEN.Util.LogLevel.WARNING)
    end
    stopwatchEntry.currentTime = 0
    stopwatchEntry.active = false
    stopwatchEntry.paused = true
    stopwatchEntry.skipFirstTick = true
    stopwatchEntry.hasTicked = true
    stopwatchEntry.stringOption = {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.VERTICAL_CENTER}

    return setmetatable(self, Stopwatch)
end
---
-- Table setup for creating Stopwatch.
-- @table StopwatchData
-- @tfield string name The name of the stopwatch.
-- @tfield[opt=false] table|bool timerFormat Sets the time display. See <a href="Timer.html#timerFormat">Timer format</a> for details.
-- @tfield[opt=Vec2(50&#44; 90)] Vec2 position The position on screen where the stopwatch will be displayed.
-- @tfield[opt=1] float scale The scale of the stopwatch display.
-- @tfield[opt=Color(255&#44; 255&#44; 255&#44; 255)] Color color The color of the displayed stopwatch when it is active.
-- @tfield[opt=Color(255&#44; 255&#44; 0&#44; 255)] Color pausedColor The color of the displayed stopwatch when it is not active.
-- @tfield[opt=0] float startTime The time (in seconds) from which the stopwatch will start counting up.

return Stopwatch