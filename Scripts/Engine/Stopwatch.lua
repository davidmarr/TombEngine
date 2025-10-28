-----<style>table.function_list td.name {min-width: 395px;} .section-header.has-description {border-top: 1px solid #ccc; padding-top: 1em;}</style>
--- Basic stopwatches that perform countup. Timers are updated automatically at every frame before OnLoop event.<br>To use Timer inside scripts you need to call the module:
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
local Util = require("Engine.Util")

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
-- local options = {
--     TEN.Strings.DisplayStringOption.RIGHT,
--     TEN.Strings.DisplayStringOption.SHADOW,
--     TEN.Strings.DisplayStringOption.VERTICAL_CENTER
-- }
-- local myStopwatch = Stopwatch.Create({
--     name = "RaceTimer",
--     startTime = 10
--     timerFormat = { seconds = true, deciseconds = true },
--     position = TEN.Vec2(90, 10),
--     scale = 1.5,
--     color = TEN.Color(0, 255, 0, 255),
--     pausedColor = TEN.Color(255, 0, 0, 255),
--     stringOption = options,
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

    -- check timerFormat
    local timerFormat = stopwatchData.timerFormat or false
    stopwatchEntry.timerFormat = Util.CheckTimeFormat(timerFormat, "Warning in Stopwatch.Create(): wrong value for timerFormat, timerFormat for '".. stopwatchData.name .."' timer will be set to false")
    
    -- check position
    stopwatchEntry.position = Type.IsVec2(stopwatchData.position) and TEN.Vec2(TEN.Util.PercentToScreen(stopwatchData.position.x, stopwatchData.position.y)) or TEN.Vec2(TEN.Util.PercentToScreen(50, 90))
    if not Type.IsVec2(stopwatchEntry.position) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for position, position for '".. stopwatchData.name .."' timer will be set to Vec2(50, 90)", TEN.Util.LogLevel.WARNING)
    end

    -- check scale
    stopwatchEntry.scale = Type.IsNumber(stopwatchData.scale) and stopwatchData.scale or 1
    if not Type.IsNumber(stopwatchEntry.scale) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for scale, scale for '".. stopwatchData.name .."' timer will be set to 1", TEN.Util.LogLevel.WARNING)
    end

    -- check color
    stopwatchEntry.color = Type.IsColor(stopwatchData.color) and stopwatchData.color or TEN.Color(255, 255, 255, 255)
    if not Type.IsColor(stopwatchEntry.color) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for color, color for '".. stopwatchData.name .."' timer will be set to Color(255, 255, 255, 255)", TEN.Util.LogLevel.WARNING)
    end
    
    -- check pausedColor
    stopwatchEntry.pausedColor = Type.IsColor(stopwatchData.pausedColor) and stopwatchData.pausedColor or TEN.Color(255, 255, 0, 255)
    if not Type.IsColor(stopwatchEntry.pausedColor) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for pausedColor, pausedColor for '".. stopwatchData.name .."' timer will be set to Color(255, 255, 0, 255)", TEN.Util.LogLevel.WARNING)
    end

    -- check startTime
    if not Type.IsNull(stopwatchData.startTime) and not Type.IsNumber(stopwatchData.startTime) then
        TEN.Util.PrintLog(warningPrefix .. "wrong value for startTime, startTime for '".. stopwatchData.name .."' timer will be set to 0", TEN.Util.LogLevel.WARNING)
    end
    stopwatchEntry.startTime = Type.IsNumber(stopwatchData.startTime) and TEN.Time((math.floor(stopwatchData.startTime * 10) / 10)  * 30) or zero

    -- check stringOption
    local warning1Message = warningPrefix .. "stringOption must be a table. Stopwatch '".. stopwatchData.name .."' will use default stringOption."
    local warning2Message = warningPrefix .. "all values in stringOption must be of type TEN.Strings.DisplayStringOption. Stopwatch '".. stopwatchData.name .."' will use default stringOption."
    stopwatchEntry.stringOption = LevelFuncs.Engine.Stopwatch.CheckTextOptions(stopwatchData.stringOption, warning1Message, warning2Message)

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
-- @tfield[opt=0] float startTime The time (in seconds) from which the stopwatch will start counting up.
-- @tfield[opt=false] table|bool timerFormat Sets the time display. See <a href="Timer.html#timerFormat">Timer format</a> for details.
-- @tfield[opt=Vec2(50&#44; 90)] Vec2 position The position in percentage on screen where the stopwatch will be displayed.
-- @tfield[opt=1] float scale The scale of the stopwatch display.
-- @tfield[opt=Color(255&#44; 255&#44; 255&#44; 255)] Color color The color of the displayed stopwatch when it is active.
-- @tfield[opt=Color(255&#44; 255&#44; 0&#44; 255)] Color pausedColor The color of the displayed stopwatch when it is not active.
-- @tfield[opt=<br>{<br>TEN.Strings.DisplayStringOption.CENTER&#44;<br> TEN.Strings.DisplayStringOption.SHADOW&#44;<br> TEN.Strings.DisplayStringOption.VERTICAL_CENTER<br>}] table stringOption A table containing values from @{Strings.DisplayStringOption} to set the text options. Vertical center option is always added automatically if not present.<br>


----
-- The list of all methods for Stopwatch objects. We suggest that you always use the @{Stopwatch.Get} function to use the methods of the Timer object to prevent errors or unexpected behavior
-- @type Stopwatch
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
-- @tparam[opt={minutes = true&#44; seconds = true&#44; deciseconds = false}] table|bool timerFormat The format to use for the time string. See <a href="Timer.html#timerFormat">Timer format</a> for details.<br>
-- @treturn string The formatted time string.
function Stopwatch:GetCurrentTimeFormatted(timerFormat)
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:GetCurrentTimeFormatted(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return "00:00.0"
    else
        local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
        local format = timerFormat or {minutes = true, seconds = true, deciseconds = false}
        local errorMessage = "Warning in Stopwatch:GetCurrentTimeFormatted(): wrong value for timerFormat, default format will be used."
        return Util.GenerateTimeFormattedString(stopwatchEntry.currentTime, format, errorMessage)
    end
end

--- Set the current time of the stopwatch. Values with only 1 tenth of a second (0.1) are accepted, example: 1.5 - 6.0 - 9.9 - 123.6. No negative values allowed!
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

--- Check if the current time of the stopwatch meets a specific condition. <br> It's recommended to use the IfCurrentTimeIs method to have error-free comparisons.
-- Values with only 1 tenth of a second (0.1) are accepted, example: 1.5 - 6.0 - 9.9 - 123.6. No negative values allowed!<br>
-- Please note: to have continuous control, the remaining time must be controlled within the *OnLoop* event and only when the stopwatch is active @{Stopwatch.IsActive}.
-- @tparam int operator The type of comparison.<br>
-- 0 : If the remaining time is equal to the value<br>
-- 1 : If the remaining time is different from the value<br>
-- 2 : If the remaining time is less the value<br>
-- 3 : If the remaining time is less or equal to the value<br>
-- 4 : If the remaining time is greater the value<br>
-- 5 : If the remaining time is greater or equal to the value
-- @tparam float seconds The value in seconds to compare.<br>
-- @treturn bool True if the condition is met, false otherwise.
-- @usage
-- -- Example1: Alternative method to create a sequence of events based on stopwatch time
-- LevelFuncs.OnLoop = function() -- this LevelFuncs is already present in your level script
--     local stopwatch = Stopwatch.Get("MyStopwatch")
--     if stopwatch:IsActive() then
--         if stopwatch:IfCurrentTimeIs(0, 2.0) then -- If current time is equal to 2.0 seconds
--             -- Do something
--         end
--         if stopwatch:IfCurrentTimeIs(0, 4.0) then -- If current time is equal to 4.0 seconds
--             -- Do something else
--         end
--         if stopwatch:IfCurrentTimeIs(0, 6.0) then -- If current time is equal to 6.0 seconds
--             -- Do another thing
--         end
--     end
-- end
--
-- -- Example2: Using callbacks
-- LevelFuncs.MySequenceOfEvents = function()
--     local stopwatch = Stopwatch.Get("MyStopwatch")
--     if stopwatch:IsActive() then
--         if stopwatch:IfCurrentTimeIs(0, 3.0) then -- If current time is equal to 3.0 seconds
--             -- Do something
--         end
--         if stopwatch:IfCurrentTimeIs(0, 5.0) then -- If current time is equal to 5.0 seconds
--             -- Do something else
--         end
--     end
-- end
-- TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POSTLOOP, LevelFuncs.MySequenceOfEvents)
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
            return Util.CompareValues(stopwatchEntry.currentTime, time, operator)
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
-- @tparam[opt=Color(255&#44; 255&#44; 0&#44; 255)] Color color The new color for the stopwatch display when paused.
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
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:SetTextOption(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
    else
        local warning1Message = "Error in Stopwatch:SetTextOption(): optionsTable must be a table."
        local warning2Message = "Error in Stopwatch:SetTextOption(): all values in optionsTable must be of type TEN.Strings.DisplayStringOption."
        LevelVars.Engine.Stopwatch.stopwatches[self.name].stringOption = LevelFuncs.Engine.Stopwatch.CheckTextOptions(optionsTable, warning1Message, warning2Message)
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
-- Example: Activate a post-process effect only if the stopwatch is active
-- if Stopwatch.Get("MyStopwatch"):IsActive() then
--     TEN.View.SetPostProcessMode(TEN.View.PostProcessMode.EXCLUSION)
-- end
function Stopwatch:IsActive()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:IsActive(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return false
    end
    return LevelVars.Engine.Stopwatch.stopwatches[self.name].active
end

--- Check if the stopwatch is active.
-- Returns `true` every 0.1 seconds when the stopwatch is active and not paused.<br>
-- TEN's engine runs on a 0.03-second internal tick, while stopwatches ticks every 0.1 seconds.<br>
-- Use `IsTicking()` to ensure consistency and avoid unexpected behavior — for example, inside the `OnLoop` event.
-- @treturn bool True if the stopwatch is ticking, false otherwise.
-- @usage
-- -- Example: Display currentTime when the stopwatch is active and ticking
-- LevelFuncs.OnLoop = function() -- this function is present in the .lua file of the level
--     if Stopwatch.Get("MyStopwatch"):IsActive() and Stopwatch.Get("MyStopwatch"):IsTicking() then
--         local currentTime = Stopwatch.Get("MyStopwatch"):GetCurrentTimeFormatted()
--         print("Current Time: " .. currentTime)
--     end
-- end
function Stopwatch:IsTicking()
    if self.error then
        TEN.Util.PrintLog("Error in Stopwatch:IsTicking(): invalid Stopwatch object.", TEN.Util.LogLevel.ERROR)
        return false
    end
    local stopwatchEntry = LevelVars.Engine.Stopwatch.stopwatches[self.name]
    return not stopwatchEntry.paused and stopwatchEntry.ticking or false
end

LevelFuncs.Engine.Stopwatch.CheckTextOptions = function(optionsTable, warning1Message, warning2Message)
    local defaultOptions = {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.VERTICAL_CENTER}
    optionsTable = optionsTable or defaultOptions
    if not Type.IsTable(optionsTable) then
        TEN.Util.PrintLog(warning1Message, TEN.Util.LogLevel.WARNING)
        return defaultOptions
    else
        for _, option in ipairs(optionsTable) do
            if not Type.IsEnumValue(option, TEN.Strings.DisplayStringOption, false) then
                TEN.Util.PrintLog(warning2Message, TEN.Util.LogLevel.WARNING)
                return defaultOptions
            end
        end
    end
    if not Util.TableHasValue(optionsTable, TEN.Strings.DisplayStringOption.VERTICAL_CENTER) then
        table.insert(optionsTable, TEN.Strings.DisplayStringOption.VERTICAL_CENTER)
    end
    return optionsTable
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
                local textTimer = Util.GenerateTimeFormattedString(s.currentTime, s.timerFormat)
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