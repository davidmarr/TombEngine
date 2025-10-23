-----<style>table.function_list td.name {min-width: 395px;} .section-header.has-description {border-top: 1px solid #ccc; padding-top: 1em;}</style>
--- Basic stopwatches that perform countup. Timers are updated automatically at every frame before OnLoop event.<br>To use Timer inside scripts you need to call the module:
--	local Stopwatch = require("Engine.Stopwatch")
-- @luautil Stopwatch

local Type = require("Engine.Type")
local Utility = require("Engine.Util")

local zero = TEN.Time()
local Stopwatch = {}
Stopwatch.__index = Stopwatch
LevelFuncs.Engine.Stopwatch = {}
LevelVars.Engine.Stopwatch = {}
LevelVars.Engine.Stopwatch = { stopwatches = {} }

--- Create (but do not start) a new stopwatch.
-- @tparam StopwatchData stopwatchData A table containing the parameters for the stopwatch.
-- @treturn Stopwatch|nil The created stopwatch object, or nil on failure.
-- @usage
-- -- Example 1: simple creation of a stopwatch
-- local myStopwatch = Stopwatch.Create({ name = "MyStopwatch" })
-- 
-- -- Example 2: creation of a stopwatch with custom parameters
-- local myStopwatch = Stopwatch.Create({
--     name = "RaceTimer",
--     timerFormat = { minutes = true, seconds = true, deciseconds = true },
--     position = TEN.Vec2(100, 50),
--     scale = 1.5,
--     color = TEN.Color(0, 255, 0, 255),
--     pausedColor = TEN.Color(255, 0, 0, 255),
--     startTime = 10
-- })
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
    stopwatchEntry.position = Type.IsVec2(stopwatchData.position) and TEN.Vec2(TEN.Util.PercentToScreen(stopwatchData.position.x, stopwatchData.position.y)) or TEN.Vec2(TEN.Util.PercentToScreen(50, 90))
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
    stopwatchEntry.startTime = Type.IsNumber(stopwatchData.startTime) and TEN.Time((math.floor(stopwatchData.startTime * 10) / 10)  * 30) or zero
    if not Type.IsNumber(stopwatchEntry.startTime) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for startTime, startTime for '".. stopwatchData.name .."' timer will be set to 0", TEN.Util.LogLevel.WARNING)
    end
    stopwatchEntry.stringOption = {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.VERTICAL_CENTER}
    stopwatchEntry.currentTime = stopwatchEntry.startTime
    stopwatchEntry.active = false
    stopwatchEntry.paused = true
    stopwatchEntry.stop = false
    
    stopwatchEntry.realtime = stopwatchEntry.startTime
    stopwatchEntry.skipFirstTick = true
    stopwatchEntry.hasTicked = true

    return setmetatable(self, Stopwatch)
end

--- Delete a stopwatch by name.
-- @tparam string name The name of the stopwatch to delete.
-- @usage
-- Stopwatch.Delete("MyStopwatch")
Stopwatch.Delete = function(name)
    LevelVars.Engine.Stopwatch.stopwatches[name] = nil
end

--- Get a stopwatch by name.
-- @tparam string name The name of the stopwatch to retrieve.
-- @treturn Stopwatch|table The stopwatch object if found, or a table with an error field set to true if not found.
-- @usage
-- local myStopwatch = Stopwatch.Get("MyStopwatch")
Stopwatch.Get = function(name)
    local errorPrefix = "in Stopwatch.Get(): "
    local self = {}
    if not Type.IsString(name) then
        TEN.Util.PrintLog("Error " .. errorPrefix .. "name must be a string.", TEN.Util.LogLevel.ERROR)
        self.error = true
    elseif not LevelVars.Engine.Stopwatch.stopwatches[name] then
        TEN.Util.PrintLog("Warning " .. errorPrefix .. "no stopwatch found with name '" .. tostring(name) .. "'.", TEN.Util.LogLevel.WARNING)
        self.error = true
    else
        self.name = name
    end
    return setmetatable(self, Stopwatch)
end

--- Check if a stopwatch exists by name.
-- @tparam string name The name of the stopwatch to check.
-- @treturn bool True if the stopwatch exists, false otherwise.
-- @usage
-- local if Stopwatch.IfExists("MyStopwatch") then
--     local myStopwatch = Stopwatch.Get("MyStopwatch")
-- end
Stopwatch.IfExists = function(name)
    if not Type.IsString(name) then
        TEN.Util.PrintLog("Error in Stopwatch.IfExists(): name must be a string.", TEN.Util.LogLevel.ERROR)
        return false
    end
    return LevelVars.Engine.Stopwatch.stopwatches[name] and true or false
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


----
-- The list of all methods for Stopwatch objects. We suggest that you always use the Stopwatch.Get() function to use the methods of the Timer object to prevent errors or unexpected behavior
-- @type StopwatchMethods
-- @usage
--	-- Examples of some methods
-- Stopwatch.Get("MyStopwatch"):Start()
-- Stopwatch.Get("MyStopwatch"):Pause()
-- Stopwatch.Get("MyStopwatch"):Stop()


--- Start or resume the stopwatch.
-- @tparam[opt=false] bool reset If true, resets the stopwatch to startTime value.
-- @usage
-- -- Example 1: Start the stopwatch
-- Stopwatch.Get("MyStopwatch"):Start()
--
-- -- Example 2: Start the stopwatch and reset its time to the starting time
-- Stopwatch.Get("MyStopwatch"):Start(true)
function Stopwatch:Start(reset)
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:Start(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
        stopwatchEntry.currentTime = reset and stopwatchEntry.startTime or stopwatchEntry.currentTime
        stopwatchEntry.active = true
        stopwatchEntry.paused = false
        stopwatchEntry.stop = false
    end
end

--- Pause the stopwatch.
-- @usage
-- Stopwatch.Get("MyStopwatch"):Pause()
function Stopwatch:Pause()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:Pause(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
        stopwatchEntry.paused = true
    end
end

--- Stop the stopwatch.
-- @usage
-- Stopwatch.Get("MyStopwatch"):Stop()
function Stopwatch:Stop()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:Stop(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
        stopwatchEntry.stop = true
    end
end

LevelFuncs.Engine.Stopwatch.IncrementTime = function()
    for _, s in pairs(LevelVars.Engine.Stopwatch.stopwatches) do
        if s.active and not s.paused then
            if s.skipFirstTick then
                s.skipFirstTick = false
            else
                s.realtime = s.realtime + 1
                s.hasTicked = (s.realtime.c % 10 == 0)
                if s.hasTicked then
                    s.currentTime = s.currentTime + 3
                end
            end
        end
    end
end

LevelFuncs.Engine.Stopwatch.UpdateAll = function()
    for _, s in pairs(LevelVars.Engine.Stopwatch.stopwatches) do
        if s.active then
            if s.timerFormat then
                print(tostring(s.stop))
                local textTimer = Utility.GenerateTimeFormattedString(s.currentTime, s.timerFormat)
                local displayTime = TEN.Strings.DisplayString(textTimer, s.position, s.scale, s.color, false, s.stringOption)
                displayTime:SetColor((not s.paused or s.stop) and s.color or s.pausedColor)
                TEN.Strings.ShowString(displayTime, s.stop and 1 or 1/30)
                if s.stop then
                    s.active = false
                    s.paused = true
                    s.skipFirstTick = true
                end
            end
        end
    end
end

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.Stopwatch.IncrementTime)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POSTLOOP, LevelFuncs.Engine.Stopwatch.UpdateAll)

return Stopwatch