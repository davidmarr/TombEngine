--- A chain of functions to call at specified times, modeled after TRNG's organizers.
--
-- Works atop the Timer, and so is updated automatically pre-OnControlPhase, and saved automatically when the game is saved.
-- The sequence can be paused, unpaused, stopped, and started, and can be set to loop.
--
-- To use EventSequence inside scripts you need to call the module:
--	local EventSequence = require("Engine.EventSequence")
--
-- Example usage:
--	local EventSequence = require("Engine.EventSequence")
--
--	-- These will be called by the sequence
--	LevelFuncs.HealLara = function()
--		Lara:SetHP(Lara:GetHP()+10)
--	end
--	
--	local nSpawned = 0
--	LevelFuncs.SpawnBaddy = function(baddy, name, pos)
--		local myBaddy = TEN.Objects.Moveable(baddy, name..nSpawned, pos, nil, 0)
--		myBaddy:Enable()
--		nSpawned = nSpawned + 1
--	end
--
--	-- This function triggers the sequence
--	LevelFuncs.TriggerSequence = function(obj) 
--		local posSteve = TEN.Objects.GetMoveableByName("stevePosNullmesh"):GetPosition()
--		local posChris = TEN.Objects.GetMoveableByName("chrisPosNullmesh"):GetPosition()
--		if not EventSequence.IfExists("my_seq") then
--			EventSequence.Create("my_seq",
--				false, -- does not loop
--				{seconds = true, deciseconds = true}, -- timer format, see Timer for details
--				6, -- seconds until call the function specified in next arg 
--				LevelFuncs.HealLara, -- first function to call. If we don't need to pass any arguments, we can just pass the function
--				2.1, -- seconds until the next function, after the previous one has been called
--				{LevelFuncs.SpawnBaddy, TEN.Objects.ObjID.BADDY1, "steve", posSteve}, -- if we DO want to pass arguments to the function to be called, we give a table with the function (LevelFuncs.SpawnBaddy in this case) followed by the args to pass to it
--				0.5,
--				{LevelFuncs.SpawnBaddy, TEN.Objects.ObjID.SAS_CAIRO, "chris", posChris},
--				1,
--				LevelFuncs.HealLara)
--		end
--
--		-- event sequences are inactive to begin with and so need to be started
--		EventSequence.Get("my_seq"):Start()
--	end
--
-- @luautil EventSequence

local Timer = require("Engine.Timer")
local Type = require("Engine.Type")
local Utility = require("Engine.Util")

local EventSequence = {}
EventSequence.__index = EventSequence

LevelFuncs.Engine.EventSequence = {}
local F = LevelFuncs.Engine.EventSequence
LevelVars.Engine.EventSequence = {sequences = {}}

local sequences = LevelVars.Engine.EventSequence.sequences
local TimerGet = Timer.Get
local TimerDelete = Timer.Delete

-- HELPER FUNCTIONS
local pairs = pairs
local unpack = table.unpack
local tableRemove = table.remove

-- Utility functions from Engine.Util that are used in this module
local CheckTimeFormat = Utility.CheckTimeFormat
local GenerateTimeFormattedString = Utility.GenerateTimeFormattedString
local TableHasValue = Utility.TableHasValue

-- Utility functions from TEN 
local LogMessage  = TEN.Util.PrintLog
local logLevelError  = TEN.Util.LogLevel.ERROR
local logLevelWarning = TEN.Util.LogLevel.WARNING

-- Type checking functions from Engine.Type that are used in this module
local IsNumber = Type.IsNumber
local IsBoolean = Type.IsBoolean
local IsString = Type.IsString
local IsTable = Type.IsTable
local IsLevelFunc = Type.IsLevelFunc


F.CallNext = function(sequenceName, nextTimerName, func, ...)
	local thisES = sequences[sequenceName]
	func(...)

	thisES.currentTimer = thisES.currentTimer + 1
	if thisES.currentTimer <= #thisES.timers then
		local theTimer = TimerGet(nextTimerName)
		theTimer:Start(true)
	elseif thisES.loop then
		local theTimer = TimerGet(thisES.firstTimerName)
		theTimer:Start(true)
		thisES.currentTimer = 1
	else
		thisES.currentTimer = 1
	end
end

--- Create (but do not start) a new event sequence.
--
-- @tparam string name A label to give the sequence; used to retrieve the timer later as well as internally by TEN.
-- @tparam bool loop If `true`, the sequence will start again from its first timer once its final function has been called.
-- @tparam ?table|bool timerFormat Same as in <a href="Timer.html#timerFormat">Timer format</a> for Timer. This is mainly for debugging. __This will not work properly if another sequence or timer is showing a countdown.__
-- @tparam float|LevelFuncs|table ... A variable number of pairs of arguments, each pair consisting of:<br>
-- - a time in seconds (positive values are accepted and with only 1 tenth of a second [__0.1__]),<br>
-- - followed by the function defined in the *LevelFuncs* table to call once the time has elapsed,<br>
-- - followed by another duration in seconds, another function name, etc.
--
-- You can specify a function either by its name, or by a *table* __{ }__ with the function name as the first member, followed by its arguments (see example).
-- @treturn[1] EventSequence The inactive sequence.
-- @treturn[2] nil If there was an error creating the sequence.
-- @usage
-- local EventSequence = require("Engine.EventSequence")
-- local TimerFormat = {seconds = true, deciseconds = true}
--
-- -- Example 1 function without arguments:
-- -- This creates a sequence that calls LevelFuncs.Func after 2 seconds
-- -- then LevelFuncs.Func after 3 seconds
-- -- and finally LevelFuncs.Func after 4 seconds
-- LevelFuncs.Func = function ()
--    local pos = TEN.Vec2(TEN.Util.PercentToScreen(50, 10))
--    local str = TEN.Strings.DisplayString("Repeated function without arguments", pos, 1)
--    TEN.Strings.ShowString(str, 1)
-- end
-- EventSequence.Create(
--    "test1", -- sequence's name
--    true, -- loop
--    TimerFormat, -- timer format
--    2.0,  -- seconds until call the function
--    LevelFuncs.Func, -- first function to call
--    3.0, 
--    LevelFuncs.Func,
--    4.0,
--    LevelFuncs.Func)
--
-- -- Example 2 function with arguments:
-- -- This creates a sequence that calls LevelFuncs.Func2("1", 5, 10) after 2.3 seconds
-- -- then LevelFuncs.Func2("2", 5, 15) after 3.1 seconds
-- -- and finally LevelFuncs.Func2("3", 5, 20) after 4.8 seconds
-- LevelFuncs.Func2 = function (text, x, y)
--    local pos = TEN.Vec2(TEN.Util.PercentToScreen(x, y))
--    local str = TEN.Strings.DisplayString("Function " .. text .. "!", pos, 1)
--    TEN.Strings.ShowString(str, 1)
-- end
-- EventSequence.Create(
--    "test2", -- sequence's name
--    true, -- loop
--    false, -- no countdown is displayed
--    2.3,
--    {LevelFuncs.Func2, "1", 5, 10},
--    3.1,
--    {LevelFuncs.Func2, "2", 5, 15},
--    4.8,
--    {LevelFuncs.Func2, "3", 5, 20})
EventSequence.Create = function (name, loop, timerFormat, ...)
	if not IsString(name) then
		LogMessage("Error in EventSequence.Create(): invalid name, sequence was not created", logLevelError)
		return
	end
	local self = {name = name}
	if sequences[name] then
		LogMessage("Warning in EventSequence.Create(): an EventSequence with name '" .. name .. "' already exists; overwriting it with a new one...", logLevelWarning)
	end
	sequences[name] = {}
	local thisES = sequences[name]
	thisES.name = name
	thisES.timers = {}
	thisES.currentTimer = 1

	if not IsBoolean(loop) then
		LogMessage("Warning in EventSequence.Create(): wrong value for loop, loop for '".. name .."' sequence will be set to false", logLevelWarning)
		loop = false
	end
	thisES.loop = loop

	local errorCheckFormat = "Warning in EventSequence.Create(): wrong value for timerFormat, timerFormat for '".. name .."' sequence will be set to false"
	thisES.timerFormat = CheckTimeFormat(timerFormat, errorCheckFormat)

	thisES.timesFuncsAndArgs = {...}
	local tfa = thisES.timesFuncsAndArgs

	for i = 1, #tfa, 2 do
		local time = tfa[i]
		local funcAndArgs = tfa[i+1]
		local error = false
		if not IsNumber(time) or time < 0 then
			LogMessage("Error in EventSequence.Create(): wrong value for seconds, '".. name .."' sequence was not created", logLevelError)
			error = true
		end
		if not (IsLevelFunc(funcAndArgs) or (IsTable(funcAndArgs) and IsLevelFunc(funcAndArgs[1]))) then
			LogMessage("Error in EventSequence.Create(): wrong value for function arguments, used function must be inside LevelFuncs. '".. name .."' sequence was not created", logLevelError)
			error = true
		end
		if error then
			for z = 1, #thisES.timers do
				TimerDelete(thisES.timers[z])
			end
			sequences[name] = nil
			return
		end

		local timerIndex = #thisES.timers + 1
		local timerName = "__TEN_eventSequence_" .. name .. "_timer" .. timerIndex
		local nextTimerName = "__TEN_eventSequence_" .. name .. "_timer" .. timerIndex + 1

		local func, args
		if i == 1 then
			thisES.firstTimerName = timerName
		end
		if IsTable(funcAndArgs) then
			func = tableRemove(funcAndArgs, 1)
			args = funcAndArgs
		else
			func = funcAndArgs
			args = {}
		end
		Timer.Create(timerName,
				time,
				false,
				thisES.timerFormat,
				F.CallNext,
				name,
				nextTimerName,
				func,
				unpack(args)
				)
		thisES.timers[timerIndex] = timerName
	end
	return setmetatable(self, EventSequence)
end

--- Get an event sequence by its name.
-- @tparam string name The label that was given to the sequence when it was created.
-- @treturn[1] EventSequence The sequence if it exists.
-- @treturn[2] nil If the sequence does not exist.
-- @usage
-- -- Example:
-- EventSequence.Get("my_seq")
EventSequence.Get = function(name)
	if not IsString(name) then
		LogMessage("Error in EventSequence.Get(): invalid name", logLevelError)
	end
	local thisES = sequences[name]
	if not thisES then
		LogMessage("Warning in EventSequence.Get(): sequence with name '".. name .."' sequence not found", logLevelWarning)
	end
	return setmetatable({name = name}, EventSequence)
end

--- Check if an event sequence exists.
-- @tparam string name The label that was given to the event sequence when it was created.
-- @treturn bool `true` if the event sequence exists, `false` if it does not exist.
-- @usage
-- -- Example:
-- -- This function checks if an event sequence named "my_seq" exists and starts it
-- LevelFuncs.CheckAndStart = function()
--    if EventSequence.IfExists("my_seq") then
--       EventSequence.Get("my_seq"):Start()
--    end
-- end
EventSequence.IfExists = function (name)
	if not IsString(name) then
		LogMessage("Error in EventSequence.IfExists(): invalid name", logLevelError)
		return false
	end
	return sequences[name] and true or false
end

--- Delete an event sequence.
-- @tparam string name The label that was given to the event sequence when it was created.
-- @usage
-- -- Example:
-- EventSequence.Delete("my_seq")
EventSequence.Delete = function (name)
	if not IsString(name) then
		LogMessage("Error in EventSequence.Delete(): invalid name", logLevelError)
		return
	elseif not sequences[name] then
		LogMessage("Error in EventSequence.Delete(): sequence with name '".. name .."' sequence does not exist", logLevelError)
	else
		for i = 1, #sequences[name].timers do
			TimerDelete(sequences[name].timers[i])
		end
		sequences[name] = nil
	end
end

----
-- List of all methods of the EventSequence object. It is always recommended to check the existence of a sequence with the *EventSequence.IfExists()* function before using methods, to avoid errors or unexpected behavior. When calling a method, it is recommended to use the *EventSequence.Get()* function, to avoid errors after loading a save game.
-- @type EventSequence
-- @usage
-- -- Examples of some methods
-- EventSequence.Get("my_seq"):Start()
-- EventSequence.Get("my_seq"):Stop()
-- EventSequence.Get("my_seq"):SetPaused(true)
--
-- -- check if sequence exists before using methods
-- if EventSequence.IfExists("my_seq") then
--    EventSequence.Get("my_seq"):Start()
-- end

--- Begin or unpause a sequence. If showing the remaining time on-screen, its color will be set to white.
-- @usage
-- -- Example:
-- if EventSequence.IfExists("my_seq") then
--    EventSequence.Get("my_seq"):Start()
-- end
function EventSequence:Start()
	local thisES = sequences[self.name]
	TimerGet(thisES.timers[thisES.currentTimer]):Start(true)
end

--- Pause or unpause the sequence. If showing the remaining time on-screen, its color will be set to yellow (paused) or white (unpaused).
-- @tparam bool p If `true`, the sequence will be paused; if `false`, it will be unpaused.
-- @usage
-- -- Example 1: Pause the sequence
-- if EventSequence.IfExists("my_seq") then
--    EventSequence.Get("my_seq"):SetPaused(true)
-- end
--
-- -- Example 2: Unpause the sequence
-- if EventSequence.IfExists("my_seq") then
--    EventSequence.Get("my_seq"):SetPaused(false)
-- end
function EventSequence:SetPaused(p)
	if not IsBoolean(p) then
		LogMessage("Error in EventSequence:SetPaused(): invalid value for p", logLevelError)
	else
		local thisES = sequences[self.name]
		TimerGet(thisES.timers[thisES.currentTimer]):SetPaused(p)
	end
end

--- Stop the sequence.
-- @usage
-- -- Example:
-- EventSequence.Get("my_seq"):Stop()
function EventSequence:Stop()
	local thisES = sequences[self.name]
	TimerGet(thisES.timers[thisES.currentTimer]):Stop()
end

--- Returns whether the sequence is paused.
-- @treturn bool `true` If the timer is paused, `false` if otherwise.
-- @usage
-- -- Example 1: paused sequence
-- if not EventSequence.Get("my_seq"):IsPaused() then
--    EventSequence.Get("my_seq"):SetPaused(true)
-- end
--
-- -- Example 2: unpause the sequence
-- if EventSequence.Get("my_seq"):IsPaused() then
--    EventSequence.Get("my_seq"):SetPaused(false)
-- end
function EventSequence:IsPaused()
	local thisES = sequences[self.name]
	return TimerGet(thisES.timers[thisES.currentTimer]):IsPaused()
end

--- Returns whether the sequence is active.
-- @treturn bool `true` If the sequence is active, `false` if otherwise.
-- @usage
-- -- Example:
-- if not EventSequence.Get("my_seq"):IsActive() then
--    EventSequence.Get("my_seq"):Start()
-- end
function EventSequence:IsActive()
	local thisES = sequences[self.name]
	return TimerGet(thisES.timers[thisES.currentTimer]):IsActive()
end

return EventSequence