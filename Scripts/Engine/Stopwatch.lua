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
local Util = require("Engine.Util")

local Stopwatch = {}
Stopwatch.__index = Stopwatch
LevelFuncs.Engine.Stopwatch = {}
LevelVars.Engine.Stopwatch = { stopwatches = {} }

local ZERO = TEN.Time()
local DEFAULT_TEXT_OPTIONS = {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.VERTICAL_CENTER}
local DEFAULT_TIMER_FORMAT = {minutes = true, seconds = true, centiseconds = true}
local FPS = 30
local FRAME_TIME = 1 / FPS
local COMPARISON_OPS =
{
    function(a, b) return a == b end,   -- 0: equal
    function(a, b) return a ~= b end,   -- 1: not equal
    function(a, b) return a < b end,    -- 2: less than
    function(a, b) return a <= b end,   -- 3: less than or equal
    function(a, b) return a > b end,    -- 4: greater than
    function(a, b) return a >= b end,   -- 5: greater than or equal
}
local floor = math.floor
local pairs = pairs
local unpack = table.unpack

local Time = TEN.Time

local function Round2Decimal(second)
	return floor(second * 100 + 0.5) / 100
end

local CheckOperator = function(operator)
	if not Type.IsNumber(operator) then
		return nil
	end
    local op = COMPARISON_OPS[operator + 1]
    return Type.IsFunction(op) and op or nil
end

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

    -- check stringOption
    local warning1Message = warningPrefix .. "stringOption must be a table. Stopwatch '".. stopwatchData.name .."' will use default stringOption."
    local warning2Message = warningPrefix .. "all values in stringOption must be of type TEN.Strings.DisplayStringOption. Stopwatch '".. stopwatchData.name .."' will use default stringOption."
    stopwatchEntry.stringOption = LevelFuncs.Engine.Stopwatch.CheckTextOptions(stopwatchData.stringOption, warning1Message, warning2Message)

    stopwatchEntry.currentTime = 0
    stopwatchEntry.active = false
    stopwatchEntry.paused = false
    stopwatchEntry.stop = false

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
        return TEN.Util.PrintLog("Error " .. errorPrefix .. "name must be a string.", TEN.Util.LogLevel.ERROR)
    end
    if not LevelVars.Engine.Stopwatch.stopwatches[name] then
        return TEN.Util.PrintLog("Warning " .. errorPrefix .. "no stopwatch found with name '" .. tostring(name) .. "'.", TEN.Util.LogLevel.WARNING)
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
-- @tparam[opt=false] bool reset If true, resets the stopwatch to zero before starting. If false or not provided, the stopwatch will continue from its current time.
-- @usage
-- -- Example 1: Start the stopwatch
-- Stopwatch.Get("MyStopwatch"):Start()
--
-- -- Example 2: Start the stopwatch and reset its time to zero
-- Stopwatch.Get("MyStopwatch"):Start(true)
function Stopwatch:Start(reset)
    local stopwatch = LevelVars.Engine.Stopwatch.stopwatches[self.name]
    if reset then
        stopwatch.currentTime = 0
    end
    stopwatch.active = true
    stopwatch.paused = false
    stopwatch.stop = false
end

--- Pause the stopwatch.
-- @usage
-- Stopwatch.Get("MyStopwatch"):Pause()
function Stopwatch:Pause()
    local stopwatch = LevelVars.Engine.Stopwatch.stopwatches[self.name]
    stopwatch.paused = true
end

--- Stop the stopwatch.
-- @usage
-- Stopwatch.Get("MyStopwatch"):Stop()
function Stopwatch:Stop()
    local stopwatch = LevelVars.Engine.Stopwatch.stopwatches[self.name]
    stopwatch.stop = true
    stopwatch.active = false
    stopwatch.paused = false
end

--- Get the current time of the stopwatch.
-- @treturn Time The current time of the stopwatch.
-- @usage
-- local currentTime = Stopwatch.Get("MyStopwatch"):GetCurrentTime()
function Stopwatch:GetCurrentTime()
    return LevelVars.Engine.Stopwatch.stopwatches[self.name].currentTime
end

--- Get the current time of the stopwatch in seconds.
-- @treturn float The current time of the stopwatch in seconds.
-- @usage
-- local currentTimeInSeconds = Stopwatch.Get("MyStopwatch"):GetCurrentTimeInSeconds()
function Stopwatch:GetCurrentTimeInSeconds()
    local currentTime = LevelVars.Engine.Stopwatch.stopwatches[self.name].currentTime
    local seconds = floor(currentTime / FPS * 100) / 100
    return seconds
end

--- Get the current time of the stopwatch formatted as a string.
-- @tparam[opt={minutes = true&#44; seconds = true&#44; deciseconds = false}] table|bool timerFormat The format to use for the time string. See <a href="Timer.html#timerFormat">Timer format</a> for details.<br>
-- @treturn string The formatted time string.
function Stopwatch:GetCurrentTimeFormatted(timerFormat)
    timerFormat = timerFormat or DEFAULT_TIMER_FORMAT
    if timerFormat ~= DEFAULT_TIMER_FORMAT then
        timerFormat = Util.CheckTimeFormat(timerFormat, "Warning in Stopwatch:GetCurrentTimeFormatted(): wrong value for timerFormat, default format will be used.")
    end
    local stopwatch = LevelVars.Engine.Stopwatch.stopwatches[self.name]
    return Util.GenerateTimeFormattedString(stopwatch.currentTime, timerFormat)
end

--- Set the current time of the stopwatch.
-- @tparam float newTime The new time for the stopwatch in seconds with 2 decimal places<br>
-- No negative values allowed. Values ​​are rounded to 2 decimal places and converted to 30 FPS game frames and rounded to the nearest frame.
-- @usage
-- Stopwatch.Get("MyStopwatch"):SetCurrentTime(30.5) -- Set time to 30.5 seconds
function Stopwatch:SetCurrentTime(newTime)
    if not Type.IsNumber(newTime) or newTime < 0 then
        TEN.Util.PrintLog("Error in Stopwatch:SetCurrentTime(): wrong value (" .. tostring(newTime) .. ") for newTime, it must be a non-negative number.", TEN.Util.LogLevel.ERROR)
    else
        local stopwatch = LevelVars.Engine.Stopwatch.stopwatches[self.name]
        stopwatch.currentTime = Time(Round2Decimal(newTime) * FPS)
    end
end

--- Check if the current time of the stopwatch meets a specific condition.
--
-- It's recommended to use the IfCurrentTimeIs method to have error-free comparisons.
-- @tparam int operator The type of comparison.<br>
-- 0 : If the remaining time is equal to the value<br>
-- 1 : If the remaining time is different from the value<br>
-- 2 : If the remaining time is less the value<br>
-- 3 : If the remaining time is less or equal to the value<br>
-- 4 : If the remaining time is greater the value<br>
-- 5 : If the remaining time is greater or equal to the value
-- @tparam float seconds The value in seconds to compare.<br>
-- No negative values allowed. Values are converted to 30 FPS game frames and rounded to the nearest frame.<br>
-- Please note: to have continuous control, the remaining time must be controlled within the *OnLoop* event and only when the stopwatch is active @{Stopwatch.IsActive}.
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
    local op = CheckOperator(operator)
    if not op then
        TEN.Util.PrintLog("Error in Stopwatch:IfCurrentTimeIs(): invalid operator for '" .. self.name .. "' stopwatch", TEN.Util.LogLevel.ERROR)
        return false
    end
    if not Type.IsNumber(seconds) or seconds < 0 then
        TEN.Util.PrintLog("Error in Stopwatch:IfCurrentTimeIs(): wrong value (" .. tostring(seconds) .. ") for seconds in '" .. self.name .. "' stopwatch", TEN.Util.LogLevel.ERROR)
        return false
    end
    local stopwatch = LevelVars.Engine.Stopwatch.stopwatches[self.name]
    local time = TEN.Time(Round2Decimal(seconds) * FPS)
    return op(stopwatch.currentTime, time)
end

--- Get the position of the stopwatch on screen.
-- @treturn Vec2 The position of the stopwatch in percentage (0 to 100).
-- @usage
-- local position = Stopwatch.Get("MyStopwatch"):GetPosition()
function Stopwatch:GetPosition()
    local position = LevelVars.Engine.Stopwatch.stopwatches[self.name].position
    return TEN.Vec2(TEN.Util.ScreenToPercent(position.x, position.y))
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
    if not Type.IsNumber(x) or not Type.IsNumber(y) then
        TEN.Util.PrintLog("Error in Stopwatch:SetPosition(): x and y must be numbers.", TEN.Util.LogLevel.ERROR)
    else
        LevelVars.Engine.Stopwatch.stopwatches[self.name].position = TEN.Vec2(TEN.Util.PercentToScreen(x, y))
    end
end

--- Get the scale of the stopwatch display.
-- @treturn float The scale factor.
-- @usage
-- local scale = Stopwatch.Get("MyStopwatch"):GetScale()
function Stopwatch:GetScale()
    return LevelVars.Engine.Stopwatch.stopwatches[self.name].scale
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
    if not Type.IsNumber(scale) or scale <= 0 then
        TEN.Util.PrintLog("Error in Stopwatch:SetScale(): scale must be a positive number.", TEN.Util.LogLevel.ERROR)
    else
        LevelVars.Engine.Stopwatch.stopwatches[self.name].scale = scale
    end
end

--- Get the color of the stopwatch display.
-- @treturn Color The color of the stopwatch display.
-- @usage
-- local color = Stopwatch.Get("MyStopwatch"):GetColor()
function Stopwatch:GetColor()
    return LevelVars.Engine.Stopwatch.stopwatches[self.name].color
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
    color = color or TEN.Color(255, 255, 255, 255)
    if not Type.IsColor(color) then
        TEN.Util.PrintLog("Error in Stopwatch:SetColor(): color must be a Color object.", TEN.Util.LogLevel.ERROR)
    else
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
    color = color or TEN.Color(255, 255, 255, 255)
    if not Type.IsColor(color) then
        TEN.Util.PrintLog("Error in Stopwatch:SetPausedColor(): color must be a Color object.", TEN.Util.LogLevel.ERROR)
        return
    end
    LevelVars.Engine.Stopwatch.stopwatches[self.name].pausedColor = color
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
    optionsTable = optionsTable or DEFAULT_TEXT_OPTIONS
    if not Type.IsTable(optionsTable) then
        TEN.Util.PrintLog("Error in Stopwatch:SetTextOptions(): optionsTable must be a table.", TEN.Util.LogLevel.ERROR)
        return
    else
        for i, option in pairs(optionsTable) do
            -- Remove vertical bottom option if present, as it is not compatible with stopwatch display
            if option == TEN.Strings.DisplayStringOption.VERTICAL_BOTTOM then
                table.remove(optionsTable, i)
            end
            if not Type.IsEnumValue(option, TEN.Strings.DisplayStringOption, false) then
                TEN.Util.PrintLog("Error in Stopwatch:SetTextOptions(): all values in optionsTable must be of type TEN.Strings.DisplayStringOption.", TEN.Util.LogLevel.ERROR)
                return
            end
        end
        -- Ensure VERTICAL_CENTER is always present
        if not Util.TableHasValue(optionsTable, TEN.Strings.DisplayStringOption.VERTICAL_CENTER) then
            table.insert(optionsTable, TEN.Strings.DisplayStringOption.VERTICAL_CENTER)
        end
        -- Set the options
        LevelVars.Engine.Stopwatch.stopwatches[self.name].stringOption = optionsTable
    end
end

--- Check if the stopwatch is in paused state.
-- @treturn bool True if the stopwatch is paused, false otherwise.
-- @usage
-- local isPaused = Stopwatch.Get("MyStopwatch"):IsPaused()
function Stopwatch:IsPaused()
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
    return LevelVars.Engine.Stopwatch.stopwatches[self.name].active
end

--- Check if the stopwatch is active.
-- Returns `true` only if the stopwatch is ticking, i.e., it is active and not paused.
-- @treturn bool True if the stopwatch is ticking, false otherwise.
function Stopwatch:IsTicking()
    local stopwatch = LevelVars.Engine.Stopwatch.stopwatches[self.name]
    return stopwatch.active and not stopwatch.paused
end

LevelFuncs.Engine.Stopwatch.IncrementTime = function()
    for _, s in pairs(LevelVars.Engine.Stopwatch.stopwatches) do
        if s.active and not s.paused then
            s.currentTime = s.currentTime + 1
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
                end
            end
        end
    end
end

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.Stopwatch.IncrementTime)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POSTLOOP, LevelFuncs.Engine.Stopwatch.UpdateAll)

return Stopwatch