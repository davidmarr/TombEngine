-----<style>table.function_list td.name {min-width: 395px;} .section-header.has-description {border-top: 1px solid #ccc; padding-top: 1em;}</style>
--- Basic stopwatches that perform countup. Timers are updated automatically at every frame before OnLoop event.<br>To use Timer inside scripts you need to call the module:
--	local Stopwatch = require("Engine.Stopwatch")
-- @luautil Stopwatch

local Type = require("Engine.Type")
local Utility = require("Engine.Util")
local Utl = require("Engine.Utility")

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
-- @treturn Stopwatch The stopwatch object if found, or stopwatch object with an error field set to true if not found.
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

--- Get the current time of the stopwatch.
-- @treturn Time The current time of the stopwatch.
-- @usage
-- local currentTime = Stopwatch.Get("MyStopwatch"):GetCurrentTime()
function Stopwatch:GetCurrentTime()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:GetCurrentTime(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return zero
    else
        return LevelVars.Engine.Stopwatch.stopwatches[self.name].currentTime
    end
end

--- Get the current time of the stopwatch in seconds.
-- @treturn float The current time of the stopwatch in seconds.
-- @usage
-- local currentTimeInSeconds = Stopwatch.Get("MyStopwatch"):GetCurrentTimeInSeconds()
function Stopwatch:GetCurrentTimeInSeconds()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:GetCurrentTimeInSeconds(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return 0
    else
        local currentTime = LevelVars.Engine.Stopwatch.stopwatches[self.name].currentTime
        local seconds = currentTime.s + 60 * currentTime.m + math.floor(currentTime.c / 10) * 0.1
        return seconds
    end
end

--- Get the current time of the stopwatch formatted as a string.
-- @tparam[opt=false] table|bool timerFormat The format to use for the time string. See <a href="Timer.html#timerFormat">Timer format</a> for details. If not provided, the stopwatch's timerFormat will be used.
-- @treturn string The formatted time string.
function Stopwatch:GetCurrentTimeFormatted(timerFormat)
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:GetCurrentTimeFormatted(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return "00:00.0"
    else
        local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
        local format = timerFormat or stopwatchEntry.timerFormat
        local errorMessage = "Warning in Stopwatch:GetCurrentTimeFormatted(): wrong value for timerFormat, default format will be used."
        return Utility.GenerateTimeFormattedString(stopwatchEntry.currentTime, format, errorMessage)
    end
end

--- Set the current time of the stopwatch.
-- @tparam float newTime The new time to set (in seconds).
-- @usage
-- Stopwatch.Get("MyStopwatch"):SetCurrentTime(30.5) -- Set time to 30.5 seconds
function Stopwatch:SetCurrentTime(newTime)
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:SetCurrentTime(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        if not Type.IsNumber(newTime) then
            TEN.Util.PrintLog("Error in Stopwatch:SetCurrentTime(): newTime must be a number.", TEN.Util.LogLevel.ERROR)
            return
        end
        local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
        stopwatchEntry.currentTime = TEN.Time((math.floor(newTime * 10) / 10)  * 30)
        stopwatchEntry.realtime = stopwatchEntry.currentTime
        stopwatchEntry.hasTicked = true
    end
end

--- Check if the current time of the stopwatch meets a specific condition.
-- @tparam int operator The type of comparison.<br>
-- 0 : If the remaining time is equal to the value<br>
-- 1 : If the remaining time is different from the value<br>
-- 2 : If the remaining time is less the value<br>
-- 3 : If the remaining time is less or equal to the value<br>
-- 4 : If the remaining time is greater the value<br>
-- 5 : If the remaining time is greater or equal to the value
-- @tparam float seconds The value in seconds to compare.<br>
-- Values with only 1 tenth of a second (0.1) are accepted, example: 1.5 - 6.0 - 9.9 - 123.6. No negative values allowed!<br>
-- Please note: to have continuous control, the remaining time must be controlled within the *OnLoop* event and only when the stopwatch is active @{Stopwatch.IsActive}.
function Stopwatch:IfCurrentTimeIs(operator, seconds)
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:IfCurrentTimeIs(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return false
    else
        if not Type.IsNumber(operator) or operator < 0 or operator > 5 then
            TEN.Util.PrintLog("Error in Stopwatch:IfCurrentTimeIs(): operator must be a number between 0 and 5.", TEN.Util.LogLevel.ERROR)
            return false
        end
        if not Type.IsNumber(seconds) or seconds < 0 then
            TEN.Util.PrintLog("Error in Stopwatch:IfCurrentTimeIs(): seconds must be a positive number.", TEN.Util.LogLevel.ERROR)
            return false
        end
        local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
        local secondsRounded = math.floor(seconds * 10) / 10
        local time = TEN.Time(secondsRounded * 30)
        if stopwatchEntry.hasTicked then
            return Utility.CompareValues(stopwatchEntry.currentTime, time, operator)
        end
    end
end

--- Get the position of the stopwatch on screen.
-- @treturn Vec2 The position of the stopwatch in percentage (0 to 100).
-- @usage
-- local position = Stopwatch.Get("MyStopwatch"):GetPosition()
function Stopwatch:GetPosition()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:GetPosition(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return TEN.Vec2(0, 0)
    else
        local position = LevelVars.Engine.Stopwatch.stopwatches[self.name].position
        return TEN.Vec2(TEN.Util.ScreenToPercent(position.x, position.y))
    end
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
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:SetPosition(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        x = x or 50
        y = y or 90
        if not Type.IsNumber(x) or not Type.IsNumber(y) then
            TEN.Util.PrintLog("Error in Stopwatch:SetPosition(): x and y must be numbers.", TEN.Util.LogLevel.ERROR)
            return
        end
        LevelVars.Engine.Stopwatch.stopwatches[self.name].position = TEN.Vec2(TEN.Util.PercentToScreen(x, y))
    end
end

--- Get the scale of the stopwatch display.
-- @treturn float The scale factor.
-- @usage
-- local scale = Stopwatch.Get("MyStopwatch"):GetScale()
function Stopwatch:GetScale()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:GetScale(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return 1
    else
        return LevelVars.Engine.Stopwatch.stopwatches[self.name].scale
    end
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
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:SetScale(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        scale = scale or 1
        if not Type.IsNumber(scale) or scale <= 0 then
            TEN.Util.PrintLog("Error in Stopwatch:SetScale(): scale must be a positive number.", TEN.Util.LogLevel.ERROR)
            return
        end
        LevelVars.Engine.Stopwatch.stopwatches[self.name].scale = scale
    end
end

--- Get the color of the stopwatch display.
-- @treturn Color The color of the stopwatch display.
-- @usage
-- local color = Stopwatch.Get("MyStopwatch"):GetColor()
function Stopwatch:GetColor()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:GetColor(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return TEN.Color(255, 255, 255, 255)
    else
        return LevelVars.Engine.Stopwatch.stopwatches[self.name].color
    end
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
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:SetColor(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        color = color or TEN.Color(255, 255, 255, 255)
        if not Type.IsColor(color) then
            TEN.Util.PrintLog("Error in Stopwatch:SetColor(): color must be a Color object.", TEN.Util.LogLevel.ERROR)
            return
        end
        LevelVars.Engine.Stopwatch.stopwatches[self.name].color = color
    end
end

--- Sets the color of the stopwatch display when paused.
-- @tparam[opt=Color(255&#44; 255&#44; 0, 255)] Color color The new color for the stopwatch display when paused.
-- @usage
-- -- Example: Set paused color to blue
-- Stopwatch.Get("MyStopwatch"):SetPausedColor(TEN.Color(0, 0, 255, 255))
--
-- -- Example: Set paused color to default (yellow)
-- Stopwatch.Get("MyStopwatch"):SetPausedColor()
function Stopwatch:SetPausedColor(color)
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:SetPausedColor(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        color = color or TEN.Color(255, 255, 255, 255)
        if not Type.IsColor(color) then
            TEN.Util.PrintLog("Error in Stopwatch:SetPausedColor(): color must be a Color object.", TEN.Util.LogLevel.ERROR)
            return
        end
        LevelVars.Engine.Stopwatch.stopwatches[self.name].pausedColor = color
    end
end

--- Sets the text options for the stopwatch display.
-- @tparam table optionsTable A table containing values from @{TEN.Strings.DisplayStringOption} to set the text options.
-- @usage
-- -- Example: Set text options to center and blink
-- Stopwatch.Get("MyStopwatch"):SetTextOptions({ TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.BLINK })
--
-- -- Example: Set text options to default (center, shadow, vertical center)
-- Stopwatch.Get("MyStopwatch"):SetTextOptions()
function Stopwatch:SetTextOptions(optionsTable)
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:SetTextOption(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        optionsTable = optionsTable or {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.VERTICAL_CENTER}
        if not Type.IsTable(optionsTable) then
            TEN.Util.PrintLog("Error in Stopwatch:SetTextOption(): optionsTable must be a table.", TEN.Util.LogLevel.ERROR)
            return
        else
            for _, option in ipairs(optionsTable) do
                if not Type.IsEnumValue(option, TEN.Strings.DisplayStringOption, false) then
                    TEN.Util.PrintLog("Error in Stopwatch:SetTextOption(): all values in optionsTable must be of type TEN.Strings.DisplayStringOption.", TEN.Util.LogLevel.ERROR)
                    return
                end
            end
        end
        -- if not Utl.TableHasValue(optionsTable, TEN.Strings.DisplayStringOption.VERTICAL_CENTER) then
        --     table.insert(optionsTable, TEN.Strings.DisplayStringOption.VERTICAL_CENTER)
        -- end
        LevelVars.Engine.Stopwatch.stopwatches[self.name].stringOption = optionsTable
    end
end

--- Check if the stopwatch is in paused state.
-- @treturn bool True if the stopwatch is paused, false otherwise.
-- @usage
-- local isPaused = Stopwatch.Get("MyStopwatch"):IsPaused()
function Stopwatch:IsPaused()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:IsPaused(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return false
    end
    return LevelVars.Engine.Stopwatch.stopwatches[self.name].paused
end

--- Check if the stopwatch is active.
-- @treturn bool True if the stopwatch is active, false otherwise.
-- @usage
-- local isActive = Stopwatch.Get("MyStopwatch"):IsActive()
function Stopwatch:IsActive()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:IsActive(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return false
    end
    return LevelVars.Engine.Stopwatch.stopwatches[self.name].active
end

function Stopwatch:IsTicking()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:IsTicking(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return false
    end
    local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
    return not stopwatchEntry.paused and stopwatchEntry.ticking or false
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