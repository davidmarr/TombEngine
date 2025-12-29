--- Advanced Tweening System. This module provides a flexible way to create and manage tweens (interpolation) for various data types such as numbers, Colors, Rotations, Vec2, and Vec3.
-- It supports different easing functions, modes (once, restart, ping-pong), looping, and callbacks for various events.
-- Supports multiple tweens with different parameters.
--
-- To use Tween inside scripts you need to call the module:
--	local Tween = require("Engine.Tween")
--
-- Example usage:
--	-- Create a tween from 0 to 100 over 2 seconds
--	local myTween = Tween.Create{
--	    name = "myTween",
--	    from = 0,
--	    to = 100,
--	    period = 2.0,
--	}
--	-- Start the tween
--	myTween:Start()
--	-- In your update loop, get the current value
--	local currentValue = myTween:GetValue()
--
-- Advanced usage with ping-pong mode and callbacks for updating object position:
--
--	-- Get the object to move
--	local bridge = TEN.Objects.GetMoveableByName("bridge_flat_6")
--
--	-- Define callback functions in LevelFuncs 
--	LevelFuncs.MyTweenOnUpdate = function(value, progress)
--	    bridge:SetPosition(value)
--      -- Optional: print progress to log
--	    TEN.Util.PrintLog("Tween Update: Value=" .. tostring(value) .. " Progress=" .. tostring(progress))
--	end
--
--	local myVecTween = Tween.Create{
--	    name = "myVecTween",
--	    from = Vec3.New(8704, -384, 14848),
--	    to = Vec3.New(8704, -384, 13824),
--	    period = 3.0,
--	    mode = Tween.Mode.PING_PONG,
--	    loopCount = 5,
--	    autoStart = true,
--	    onUpdate = LevelFuncs.MyTweenOnUpdate,
--	}
-- @luautil Tween

local Type = require("Engine.Type")
local LuaUtil = require("Engine.LuaUtil")

local Tween = {}
Tween.__index = Tween
LevelFuncs.Engine.Tween = {}

LevelFuncs.Engine.Tween.IsValidTweenValue = function(value)
    return Type.IsNumber(value) or
           Type.IsColor(value) or
           Type.IsRotation(value) or
           Type.IsVec2(value) or
           Type.IsVec3(value)
end
-- Storage
LevelVars.Engine.Tween = { tweens = {} }

LevelVars.Engine.Tween.Interpolations = {
    LuaUtil.Lerp,
    LuaUtil.Smoothstep,
    LuaUtil.Smootherstep,
    LuaUtil.EaseInOut,
    LuaUtil.Elastic
}

Tween.Mode = {
    ONCE = 0,              -- from → to (stop)
    RESTART = 1,           -- from → to - from → to
    PING_PONG = 2,         -- from → to → from
}

Tween.Mode = LuaUtil.SetTableReadOnly(Tween.Mode)

Tween.Easing = {
    LERP = 1,
    SMOOTHSTEP = 2,
    SMOOTHERSTEP = 3,
    EASE_IN_OUT = 4,
    ELASTIC = 5
}

Tween.Easing = LuaUtil.SetTableReadOnly(Tween.Easing)

Tween.CallbackType = {
    ON_START = "onStart",
    ON_COMPLETE = "onComplete",
    ON_LOOP = "onLoop",
    ON_UPDATE = "onUpdate",
    ON_TO = "onTo",
    ON_FROM = "onFrom"
}

Tween.CallbackType = LuaUtil.SetTableReadOnly(Tween.CallbackType)

--- Create tween instance
-- @tparam TweenParameters params Table with parameters
-- @treturn[1] Tween instance
-- @treturn[2] nil If error occurs
-- @usage
-- -- Create a tween from 0 to 100 over 2 seconds
-- local myTween = Tween.Create{
--     name = "myTween",
--     from = 0,
--     to = 100,
--     period = 2.0,
-- }
--
-- -- Create a ping-pong tween from Vec3(0,0,0) to Vec3(10,10,10) over 3 seconds, looping 5 times
-- local myVecTween = Tween.Create{
--     name = "myVecTween",
--     from = Vec3.New(0, 0, 0),
--     to = Vec3.New(10, 10, 10),
--     period = 3.0,
--     mode = Tween.Mode.PING_PONG,
--     loopCount = 5,
--     autoStart = true,
-- }
Tween.Create = function(params)

    -- Validate parameters
    if not Type.IsTable(params) then
        TEN.Util.PrintLog("Error in Tween.Create(): params must be a table", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not Type.IsString(params.name) then
        TEN.Util.PrintLog("Error in Tween.Create(): params.name must be a string", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if LevelVars.Engine.Tween.tweens[params.name] then
        TEN.Util.PrintLog("Warning in Tween.Create(): tween with name '" .. params.name .. "' already exists. Overwriting.", TEN.Util.LogLevel.WARNING)
    end
    if not LevelFuncs.Engine.Tween.IsValidTweenValue(params.from) then
        TEN.Util.PrintLog("Error in Tween.Create(): params.from has invalid type", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not LevelFuncs.Engine.Tween.IsValidTweenValue(params.to) then
        TEN.Util.PrintLog("Error in Tween.Create(): params.to has invalid type", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if getmetatable(params.from) ~= getmetatable(params.to) then
        TEN.Util.PrintLog("Error in Tween.Create(): params.from and params.to must be of the same type", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not Type.IsNumber(params.period) or params.period <= 0 then
        TEN.Util.PrintLog("Error in Tween.Create(): params.period must be a positive number", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if params.loopCount and (not Type.IsNumber(params.loopCount) or params.loopCount <= 0) then
        TEN.Util.PrintLog("Error in Tween.Create(): params.loopCount must be a positive integer or nil", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if params.loopCount and not LuaUtil.IsInteger(params.loopCount) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.loopCount is not an integer, flooring the value", TEN.Util.LogLevel.WARNING)
        params.loopCount = math.floor(params.loopCount)
    end
    if params.autoStart and not Type.IsBoolean(params.autoStart) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.autoStart must be a boolean. Using default value 'false'", TEN.Util.LogLevel.WARNING)
    end
    if params.mode and not LuaUtil.TableHasValue(Tween.Mode, params.mode) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.mode has invalid value. Using default value 'ONCE'", TEN.Util.LogLevel.WARNING)
    end
    if params.easing and not LuaUtil.TableHasValue(Tween.Easing, params.easing) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.easing has invalid value. Using default value 'LERP'", TEN.Util.LogLevel.WARNING)
    end
    if params.onStart and not Type.IsLevelFunc(params.onStart) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.onStart must be a LevelFunc. The callback will not be assigned", TEN.Util.LogLevel.WARNING)
    end
    if params.onComplete and not Type.IsLevelFunc(params.onComplete) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.onComplete must be a LevelFunc. The callback will not be assigned", TEN.Util.LogLevel.WARNING)
    end
    if params.onLoop and not Type.IsLevelFunc(params.onLoop) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.onLoop must be a LevelFunc. The callback will not be assigned", TEN.Util.LogLevel.WARNING)
    end
    if params.onUpdate and not Type.IsLevelFunc(params.onUpdate) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.onUpdate must be a LevelFunc. The callback will not be assigned", TEN.Util.LogLevel.WARNING)
    end
    if params.onTo and not Type.IsLevelFunc(params.onTo) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.onTo must be a LevelFunc. The callback will not be assigned", TEN.Util.LogLevel.WARNING)
    end
    if params.onFrom and not Type.IsLevelFunc(params.onFrom) then
        TEN.Util.PrintLog("Warning in Tween.Create(): params.onFrom must be a LevelFunc. The callback will not be assigned", TEN.Util.LogLevel.WARNING)
    end
    -- Create tween
    LevelVars.Engine.Tween.tweens[params.name] = {}
    local thisTween = LevelVars.Engine.Tween.tweens[params.name]
    thisTween.from = params.from
    thisTween.to = params.to
    thisTween.period = params.period
    thisTween.mode = LuaUtil.TableHasValue(Tween.Mode, params.mode) and params.mode or Tween.Mode.ONCE
    thisTween.easing = LuaUtil.TableHasValue(Tween.Easing, params.easing) and  params.easing or Tween.Easing.LERP

    if params.easingParams and (thisTween.easing == Tween.Easing.SMOOTHSTEP or thisTween.easing == Tween.Easing.SMOOTHERSTEP) then
        if not params.easingParams.edge0 then
            params.easingParams.edge0 = 0
        end
        if not params.easingParams.edge1 then
            params.easingParams.edge1 = 1
        end
    end
    if params.easingParams and thisTween.easing == Tween.Easing.ELASTIC then
        if not params.easingParams.amplitude then
            params.easingParams.amplitude = 1.0
        end
        if not params.easingParams.period then
            params.easingParams.period = 0.3
        end
    end
    thisTween.easingParams = params.easingParams or nil
    thisTween.loopCount = params.loopCount or nil
    thisTween.autoStart = Type.IsBoolean(params.autoStart) and params.autoStart or false

    -- State management
    thisTween.active = params.autoStart and true or false
    thisTween.paused = false

    thisTween.interpolation = LevelVars.Engine.Tween.Interpolations[thisTween.easing]
    thisTween.interpolationDuration = LuaUtil.SecondsToFrames(thisTween.period)

    -- Interpolation state
    thisTween.elapsed = 0
    thisTween.progress = 0.0
    thisTween.value = thisTween.from
    thisTween.direction = 1
    thisTween.currentLoopIndex = 0
    thisTween.completed = false

    -- Callbacks
    thisTween.callbacks = {
        onStart = Type.IsLevelFunc(params.onStart) and params.onStart or nil,
        onComplete = Type.IsLevelFunc(params.onComplete) and params.onComplete or nil,
        onLoop = Type.IsLevelFunc(params.onLoop) and params.onLoop or nil,
        onUpdate = Type.IsLevelFunc(params.onUpdate) and params.onUpdate or nil,
        onTo = Type.IsLevelFunc(params.onTo) and params.onTo or nil,
        onFrom = Type.IsLevelFunc(params.onFrom) and params.onFrom or nil,
    }

    local self = { name = params.name }
    return setmetatable(self, Tween)
end

--- Delete tween instance
-- @tparam string name Name of the tween to delete
-- @usage Tween.Delete("myTween")
Tween.Delete = function (name)
    if not Type.IsString(name) then
        TEN.Util.PrintLog("Error in Tween.Delete(): invalid name", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if LevelVars.Engine.Tween.tweens[name] then
        LevelVars.Engine.Tween.tweens[name] = nil
    end
end

--- Get tween instance
-- @tparam string name Name of the tween to get
-- @treturn[1] Tween instance
-- @treturn[2] nil If tween does not exist
-- @usage local myTween = Tween.Get("myTween")
Tween.Get = function(name)
    if not Type.IsString(name) then
        TEN.Util.PrintLog("Error in Tween.Get(): invalid name", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if not LevelVars.Engine.Tween.tweens[name] then
        TEN.Util.PrintLog("Error in Tween.Get(): tween '" .. name .. "' does not exist. Use Tween.Create() first or check Tween.IfExists()", TEN.Util.LogLevel.ERROR)
        return nil
    end
    return setmetatable({ name = name }, Tween)
end

--- Check if tween instance exists
-- @tparam string name Name of the tween to check
-- @treturn bool True if exists, false otherwise
-- @usage if Tween.IfExists("myTween") then ... end
Tween.IfExists = function(name)
    if not Type.IsString(name) then
        TEN.Util.PrintLog("Error in Tween.IfExists(): invalid name", TEN.Util.LogLevel.ERROR)
        return nil
    end
    return LevelVars.Engine.Tween.tweens[name] and true or false
end

----
-- List of all methods of the Tween object. For proper error handling, before calling the method, we recommend that you always check whether the tween exists with `Tween.IfExists`.
-- @usage
-- if Tween.IfExists("myTween") then
--     local myTween = Tween.Get("myTween")
--     myTween:Start()
-- end
-- -- or
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Start()
-- end
-- @type Tween

--- Start or resume the tween
--- @usage myTween:Start()
function Tween:Start()
    local t = LevelVars.Engine.Tween.tweens[self.name]
    if t.completed then
        self:Reset()
    end
    t.active = true
    -- TODO: callback ON_START
end

--- Restart the tween from the beginning
-- @usage myTween:Restart()
function Tween:Restart()
    local t = LevelVars.Engine.Tween.tweens[self.name]
    t.active = true
    t.paused = false
    t.elapsed = 0
    t.progress = 0.0
    t.value = t.from
    t.direction = 1
    t.currentLoopIndex = 0
    t.completed = false
end

--- Pause the tween
-- @usage myTween:Pause()
function Tween:Pause()
    LevelVars.Engine.Tween.tweens[self.name].paused = true
end

--- Stop the tween
-- @usage myTween:Stop()
function Tween:Stop()
    LevelVars.Engine.Tween.tweens[self.name].active = false
end

--- Reset the tween to the initial state
-- @usage myTween:Reset()
function Tween:Reset()
    local t = LevelVars.Engine.Tween.tweens[self.name]
    t.active = false
    t.paused = false
    t.elapsed = 0
    t.progress = 0.0
    t.value = t.from
    t.direction = 1
    t.currentLoopIndex = 0
    t.completed = false
end

--- Get the current direction of the tween
-- @treturn int 1 for from→to, -1 for to→from
function Tween:GetDirection()
    return LevelVars.Engine.Tween.tweens[self.name].direction
end

--- Get the current loop index (0-based)
-- @treturn int Current loop index
function Tween:GetCurrentLoop()
    return LevelVars.Engine.Tween.tweens[self.name].loopCount
end

--- Get the current value of the tween
-- @treturn float|Color|Rotation|Vec2|Vec3 Current tweened value
function Tween:GetValue()
    return LevelVars.Engine.Tween.tweens[self.name].value
end

--- Get the current progress of the tween (0.0 to 1.0)
-- @treturn number Current progress (0.0 to 1.0)
function Tween:GetProgress()
    return LevelVars.Engine.Tween.tweens[self.name].progress
end

--- Set the current progress of the tween (0.0 to 1.0)
-- @tparam number t Progress value to set (0.0 to 1.0)
-- @usage myTween:SetProgress(0.5)  -- Set progress to halfway
function Tween:SetProgress(t)
    if not Type.IsNumber(t) then
        return TEN.Util.PrintLog("Error in Tween:SetProgress(t): t must be a number", TEN.Util.LogLevel.ERROR)
    end
    local clampT = LuaUtil.Clamp(t, 0, 1)
    LevelVars.Engine.Tween.tweens[self.name].progress = clampT
end

--- Get the time remaining for the tween to complete (in seconds)
-- @treturn number Time remaining in seconds
function Tween:GetTimeRemaining()
    local t = LevelVars.Engine.Tween.tweens[self.name]
    local remainingFrames = t.interpolationDuration - t.elapsed
    if remainingFrames < 0 then
        remainingFrames = 0
    end
    return LuaUtil.Round(LuaUtil.FramesToSeconds(remainingFrames), 2)  -- Assuming 30 FPS
end

--- Get the period of the tween (in seconds)
-- @treturn number Period in seconds (duration of one direction; for PING_PONG, full cycle is period * 2)
-- @usage local period = myTween:GetPeriod()
function Tween:GetPeriod()
    return LevelVars.Engine.Tween.tweens[self.name].period
end

--- Set the period of the tween (in seconds)
-- @tparam number period Period in seconds (duration of one direction; for PING_PONG, full cycle is period * 2). Must be positive.
-- @usage myTween:SetPeriod(2.0)  -- Set period to 2 seconds (4 seconds for full PING_PONG cycle)
function Tween:SetPeriod(period)
    if not Type.IsNumber(period) or period <= 0 then
        return TEN.Util.PrintLog("Error in Tween:SetPeriod(period): period must be a positive number", TEN.Util.LogLevel.ERROR)
    end
    local t = LevelVars.Engine.Tween.tweens[self.name]
    t.period = period
    t.interpolationDuration = LuaUtil.SecondsToFrames(period)
end

--- Get the 'from' value of the tween
-- @treturn float|Color|Rotation|Vec2|Vec3 'from' value
-- @usage local fromValue = myTween:GetFrom()
function Tween:GetFrom()
    return LevelVars.Engine.Tween.tweens[self.name].from
end

--- Set the 'from' value of the tween
-- @tparam float|Color|Rotation|Vec2|Vec3 value 'from' value to set. Remember that 'from' and 'to' must be the same type!
-- @usage myTween:SetFrom(0)  -- Set 'from' value to 0
function Tween:SetFrom(value)
    if not LevelFuncs.Engine.Tween.IsValidTweenValue(value) then
        return TEN.Util.PrintLog("Error in Tween:SetFrom(value): invalid value type", TEN.Util.LogLevel.ERROR)
    end
    if getmetatable(value) ~= getmetatable(LevelVars.Engine.Tween.tweens[self.name].to) then
        return TEN.Util.PrintLog("Error in Tween:SetFrom(value): 'from' value type must match 'to' value type", TEN.Util.LogLevel.ERROR)
    end
    LevelVars.Engine.Tween.tweens[self.name].from = value
end

--- Get the 'to' value of the tween
-- @treturn float|Color|Rotation|Vec2|Vec3 'to' value.
-- @usage local toValue = myTween:GetTo()
function Tween:GetTo()
    return LevelVars.Engine.Tween.tweens[self.name].to
end

--- Set the 'to' value of the tween
-- @tparam float|Color|Rotation|Vec2|Vec3 value 'to' value to set. Remember that 'from' and 'to' must be the same type!
-- @usage myTween:SetTo(100)  -- Set 'to' value to 100
function Tween:SetTo(value)
    if not LevelFuncs.Engine.Tween.IsValidTweenValue(value) then
        return TEN.Util.PrintLog("Error in Tween:SetTo(value): invalid value type", TEN.Util.LogLevel.ERROR)
    end
    if getmetatable(value) ~= getmetatable(LevelVars.Engine.Tween.tweens[self.name].from) then
        return TEN.Util.PrintLog("Error in Tween:SetTo(value): 'to' value type must match 'from' value type", TEN.Util.LogLevel.ERROR)
    end
    LevelVars.Engine.Tween.tweens[self.name].to = value
end

--- Get both 'from' and 'to' values of the tween
-- @treturn float|Color|Rotation|Vec2|Vec3 'from' values
-- @treturn float|Color|Rotation|Vec2|Vec3 'to' values
-- @usage local fromValue, toValue = myTween:GetFromAndTo()
function Tween:GetFromAndTo()
    local t = LevelVars.Engine.Tween.tweens[self.name]
    return t.from, t.to
end

--- Set both 'from' and 'to' values of the tween. Remember that 'from' and 'to' must be the same type!
-- @tparam float|Color|Rotation|Vec2|Vec3 from 'from' value to set
-- @tparam float|Color|Rotation|Vec2|Vec3 to 'to' value to set
-- @usage myTween:SetFromAndTo(0, 100)  -- Set 'from' to 0 and 'to' to 100
function Tween:SetFromAndTo(from, to)
    if not LevelFuncs.Engine.Tween.IsValidTweenValue(from) then
        return TEN.Util.PrintLog("Error in Tween:SetFromAndTo(from, to): invalid 'from' value type", TEN.Util.LogLevel.ERROR)
    end
    if not LevelFuncs.Engine.Tween.IsValidTweenValue(to) then
        return TEN.Util.PrintLog("Error in Tween:SetFromAndTo(from, to): invalid 'to' value type", TEN.Util.LogLevel.ERROR)
    end
    if getmetatable(from) ~= getmetatable(to) then
        return TEN.Util.PrintLog("Error in Tween:SetFromAndTo(from, to): 'from' and 'to' value types must match", TEN.Util.LogLevel.ERROR)
    end
    LevelVars.Engine.Tween.tweens[self.name].from = from
    LevelVars.Engine.Tween.tweens[self.name].to = to
end

--- Get the easing function of the tween
-- @treturn int Easing function (use Tween.Easing)
-- @usage local easing = myTween:GetEasing()
function Tween:GetEasing()
    return LevelVars.Engine.Tween.tweens[self.name].easing
end

--- Set the easing function of the tween
-- @tparam Easing easing Easing function to set (use Tween.Easing)
-- @usage myTween:SetEasing(Tween.Easing.SMOOTHSTEP)
function Tween:SetEasing(easing)
    if not LuaUtil.TableHasValue(Tween.Easing, easing) then
        return TEN.Util.PrintLog("Error in Tween:SetEasing(easing): invalid easing value", TEN.Util.LogLevel.ERROR)
    end
    local t = LevelVars.Engine.Tween.tweens[self.name]
    t.easing = easing
    t.interpolation = LevelVars.Engine.Tween.Interpolations[easing]
end

--- Set the easing parameters of the tween
-- @tparam table params Easing parameters table
-- @usage myTween:SetEasingParams({ amplitude = 1.0, period = 0.3 })
function Tween:SetEasingParams(params)
    LevelVars.Engine.Tween.tweens[self.name].easingParams = params
end

--- Get the loop count of the tween
-- @treturn int|nil Loop count, or nil for infinite loops
-- @usage local loopCount = myTween:GetLoopCount()
function Tween:GetLoopCount()
    return LevelVars.Engine.Tween.tweens[self.name].loopCount
end

--- Set the loop count of the tween
-- @tparam int|nil count Loop count to set, or nil for infinite loops
-- @usage myTween:SetLoopCount(5)  -- Set loop count to 5
function Tween:SetLoopCount(count)
    if not (Type.IsNil(count) or (Type.IsInteger(count) and count > 0)) then
        return TEN.Util.PrintLog("Error in Tween:SetLoopCount(): count must be a positive integer or nil", TEN.Util.LogLevel.ERROR)
    end
    if not LuaUtil.IsInteger(count) then
        TEN.Util.PrintLog("Warning in Tween:SetLoopCount(): count is not an integer, flooring the value", TEN.Util.LogLevel.WARNING)
        count = math.floor(count)
    end
    LevelVars.Engine.Tween.tweens[self.name].loopCount = count
end

--- Reverse the tween direction
-- @usage myTween:Reverse()
function Tween:Reverse()
    local t = LevelVars.Engine.Tween.tweens[self.name]
    t.direction = -t.direction
end

--- Set callback function
-- @tparam CallbackType callbackType Type of callback (use Tween.CallbackType)
-- @tparam function func Callback function in LevelFuncs hierarchy
function Tween:SetCallback(callbackType, func)
    if not LuaUtil.TableHasValue(Tween.CallbackType, callbackType) then
        return TEN.Util.PrintLog("Error in Tween:SetCallback(callbackType, func): invalid callbackType", TEN.Util.LogLevel.ERROR)
    end
    if not Type.IsLevelFunc(func) then
        return TEN.Util.PrintLog("Error in Tween:SetCallback(callbackType, func): func must be a LevelFunc", TEN.Util.LogLevel.ERROR)
    end
    LevelVars.Engine.Tween.tweens[self.name].callbacks[callbackType] = func
end

--- Check if the tween is currently active
-- @treturn bool True if active, false otherwise
-- @usage 
-- if myTween:IsActive() then
--  ... 
-- end
function Tween:IsActive()
    return LevelVars.Engine.Tween.tweens[self.name].active
end

--- Check if the tween is currently paused
-- @treturn bool True if paused, false otherwise
-- @usage
-- if myTween:IsPaused() then
--  ... 
-- end
function Tween:IsPaused()
    return LevelVars.Engine.Tween.tweens[self.name].paused
end

--- Check if the tween has completed
-- @treturn bool True if completed, false otherwise
-- @usage
-- if myTween:IsCompleted() then
--  ... 
-- end
function Tween:IsCompleted()
    return LevelVars.Engine.Tween.tweens[self.name].completed
end

----
-- Table and constants for Tween system
-- @section TweenConstants

---
-- Table setup for creating Tween.
-- @table TweenParameters
-- @tfield string name Name of the tween (unique identifier)
-- @tfield float|Color|Rotation|Vec2|Vec3 from Starting value
-- @tfield float|Color|Rotation|Vec2|Vec3 to Ending value. `from` and `to` must be the same type!
-- @tfield float period Duration of ONE DIRECTION in seconds. For PING_PONG mode, a complete cycle (from→to→from) takes `period * 2` seconds. This follows the standard convention used by professional tween libraries (DOTween, GSAP, etc.).
-- @tfield[opt=Tween.Mode.ONCE] int mode Tween mode (use `Tween.Mode`)
-- @tfield[opt=Tween.Easing.LERP] int easing Easing function (use `Tween.Easing`)
-- @tfield[opt] table easingParams parameters for easing function
-- @tfield[opt=nil] int loopCount Number of loops (nil for infinite)
-- @tfield[opt=false] bool autoStart Whether to start the tween immediately
-- @tfield[opt] function onStart function in LevelFuncs hierarchy called on start
-- @tfield[opt] function onComplete function in LevelFuncs hierarchy called on complete
-- @tfield[opt] function onLoop function in LevelFuncs hierarchy called on loop
-- @tfield[opt] function onUpdate function in LevelFuncs hierarchy called on update
-- @tfield[opt] function onTo function in LevelFuncs hierarchy called on reaching 'to' value
-- @tfield[opt] function onFrom function in LevelFuncs hierarchy called on reaching 'from' value

---
-- Constants for tween callback types.
-- @table CallbackType
-- @tfield "onStart" ON_START Called when the tween starts
-- @tfield "onComplete" ON_COMPLETE Called when the tween completes
-- @tfield "onLoop" ON_LOOP Called when the tween loops
-- @tfield "onUpdate" ON_UPDATE Called on each update/frame
-- @tfield "onTo" ON_TO Called when reaching the 'to' value
-- @tfield "onFrom" ON_FROM Called when reaching the 'from' value

---
-- Costants for tween modes.
-- @table Mode
-- @tfield 0 ONCE Tween runs once from 'from' to 'to'
-- @tfield 1 RESTART Tween restarts from 'from' to 'to' repeatedly. Each loop takes `period` seconds.
-- @tfield 2 PING_PONG Tween goes from 'from' to 'to' and back repeatedly. Each complete cycle (from→to→from) takes `period * 2` seconds, as `period` represents the duration of ONE DIRECTION only.

---
-- Constants for tween easing functions.
-- @table Easing
-- @tfield 1 LERP Linear interpolation
-- @tfield 2 SMOOTHSTEP Smoothstep interpolation
-- @tfield 3 SMOOTHERSTEP Smootherstep interpolation
-- @tfield 4 EASE_IN_OUT Ease in-out interpolation
-- @tfield 5 ELASTIC Elastic interpolation

LevelFuncs.Engine.Tween.UpdateAll = function()
    for _, t in pairs(LevelVars.Engine.Tween.tweens) do
        if t.active and not t.paused then
            -- Se completato nel frame precedente, disattiva ora (dopo che OnLoop ha visto il valore finale)
            if t.completed then
                t.active = false
            else
                -- Calcola progress PRIMA di incrementare (per mostrare valore iniziale)
                t.progress = t.elapsed / t.interpolationDuration

                if t.progress > 1.0 then
                    t.progress = 1.0
                end

                local effectiveProgress = t.direction == 1 and t.progress or (1.0 - t.progress)
                t.value = t.interpolation(t.from, t.to, effectiveProgress, t.easingParams)

                -- Callback ON_UPDATE
                if t.callbacks.onUpdate then
                    t.callbacks.onUpdate(t.value, t.progress)
                end

                -- Incrementa DOPO aver calcolato il valore
                t.elapsed = t.elapsed + 1

                if t.progress >= 1.0 then
                    -- Forza valore finale esatto (per sicurezza)
                    t.value = t.direction == 1 and t.to or t.from

                    if t.mode == Tween.Mode.ONCE then
                        t.completed = true
                        -- TODO: callback ON_TO
                        -- TODO: callback ON_COMPLETE

                    elseif t.mode == Tween.Mode.RESTART then
                        t.elapsed = 0
                        t.progress = 0.0

                        if t.loopCount then
                            t.currentLoopIndex = t.currentLoopIndex + 1
                            if t.currentLoopIndex >= t.loopCount then
                                t.completed = true
                                -- TODO: callback ON_TO
                                -- TODO: callback ON_COMPLETE
                            else
                                -- TODO: callback ON_TO
                                -- TODO: callback ON_LOOP
                            end
                        else
                            -- Loop infinito: continua senza contare
                            -- TODO: callback ON_TO
                            -- TODO: callback ON_LOOP
                        end

                    elseif t.mode == Tween.Mode.PING_PONG then
                        t.elapsed = 1
                        t.progress = 0.0
                        t.direction = -t.direction

                        -- TODO: callback ON_TO (se direction=-1) o ON_FROM (se direction=1)

                        if t.direction == 1 then
                            if t.loopCount then
                                t.currentLoopIndex = t.currentLoopIndex + 1
                                if t.currentLoopIndex >= t.loopCount then
                                    t.completed = true
                                    -- TODO: callback ON_COMPLETE
                                else
                                    -- TODO: callback ON_LOOP
                                end
                            else
                                -- Loop infinito: continua senza contare
                                -- TODO: callback ON_LOOP
                            end
                        end
                    end
                end
            end
        end
    end
end

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.Tween.UpdateAll)

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_FREEZE, LevelFuncs.Engine.Tween.UpdateAll)

return Tween