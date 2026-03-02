--- <style> table, th, td {border: 1px solid black;} .tableSP {border-collapse: collapse; width: 100%; text-align: center; } .tableSP th {background-color: #525252; color: white; padding: 6px;}</style>
--- <style> .tableSP td {padding: 4px;} .tableSP tr:nth-child(even) {background-color: #f2f2f2;}</style>
--- Advanced interpolation system. This module offers a flexible way to create and manage interpolations (tweens) for the following data types: numbers, Color, Rotation, Vec2 and Vec3.
-- It supports different easing functions, modes (once, restart, ping-pong), looping, and callbacks for various events.
-- Supports multiple tweens with different parameters.<br><br>
-- **Important note about interpolation:**<br>
-- The Tween module to interpolate primitives uses their internal methods (Color:Lerp, Vec2:Lerp. Vec3:Lerp, Rotation:Lerp).<br>
-- Rotation:Lerp() uses the **shortest angular path**. This means:<br>
--
-- - Rotation(10,0,0):Lerp(Rotation(350,0,0), 0.5) → Rotation(0,0,0) (not 180°)
--
-- - Cannot create gradual rotations like 0°→90°→180°→270°→360° using Rotation primitives
--
-- - The tween will always interpolate via the shortest route between angles
--
-- <br>To use Tween inside scripts you need to call the module:
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
--	-- Define callback functions in LevelFuncs 
--	LevelFuncs.MyTweenOnUpdate = function(value, progress, tween)
--
--      -- Get the object to move
--	    local bridge = TEN.Objects.GetMoveableByName("bridge_flat_6")
--	    bridge:SetPosition(value)
--
--      -- Optional: use tween parameter for advanced control
--	    if progress > 0.5 then
--	        tween:SetEasing(Tween.Easing.BOUNCE)
--	    end
--	end
--
--	local myVecTween = Tween.Create{
--	    name = "myVecTween",
--	    from = Vec3.New(8704, -384, 14848),
--	    to = Vec3.New(8704, -384, 13824),
--	    period = 3.0, -- 3 seconds duration for one direction. Full cycle (from → to → from) is 6 seconds
--	    mode = Tween.Mode.PING_PONG,
--	    loopCount = 6, -- Loop 6 times (3 full cycles)
--	    autoStart = true, -- Start immediately
--	    onUpdate = LevelFuncs.MyTweenOnUpdate,
--	}
--
-- Example with wrapAngle for HUD compass needle (shortest angular path):
--
--	-- Setup sprite and tracking variable
--	local objID = TEN.Objects.ObjID.SPEEDOMETER_GRAPHICS
--	local compassNeedle = TEN.View.DisplaySprite(objID, 1, TEN.Vec2(80, 80), 0, TEN.Vec2(20, 20))
--	local lastTargetAngle = 0
--
--	-- Callback: only update needle rotation (not drawing!)
--	LevelFuncs.OnCompassUpdate = function(value, progress, tween)
--	    compassNeedle:SetRotation(value)
--	end
--
--	-- Create tween with wrapAngle for smooth rotation via shortest path
--	local compassTween = Tween.Create{
--	    name = "compassNeedle",
--	    from = 0,
--	    to = 0,
--	    period = 0.5,
--	    mode = Tween.Mode.ONCE,  -- Manual restart control
--	    wrapAngle = true,  -- Use shortest angular path (350° → 10° goes through 0°)
--	    easing = Tween.Easing.ELASTIC,  -- Overshoot effect for realism
--	    easingParams = {amplitude = 1.2, period = 0.35},
--	    autoStart = false,  -- Start manually when target changes
--	    onUpdate = LevelFuncs.OnCompassUpdate,
--	}
--
--	-- Main loop: draw sprite + update target when player rotates
--	LevelFuncs.OnLoop = function()
--	    -- Always draw sprite every frame (required to keep it visible)
--	    compassNeedle:Draw()
--
--	    -- Check if player facing direction changed significantly
--	    local playerYaw = Lara:GetRotation().y
--	    local newTarget = -playerYaw + 180  -- Offset because sprite points down
--      -- Use MathUtils.WrapAngle to calculate shortest angle difference between new target and last target
--	    local angleDelta = math.abs(MathUtils.WrapAngle(newTarget - lastTargetAngle, -180, 180))
--
--	    -- Update tween only if rotation changed by more than 3 degrees
--	    if angleDelta > 3 then
--	        local currentAngle = compassNeedle:GetRotation()
--	        compassTween:SetFromAndTo(currentAngle, newTarget)
--
--	        -- Adaptive easing: bigger rotations = more dramatic effect
--	        if angleDelta > 60 then
--	            compassTween:SetEasing(Tween.Easing.ELASTIC, {amplitude = 1.3, period = 0.4})
--	            compassTween:SetPeriod(0.7)
--	        else
--	            compassTween:SetEasing(Tween.Easing.EASE_IN_OUT)
--	            compassTween:SetPeriod(0.3)
--	        end
--
--	        compassTween:Restart()
--	        lastTargetAngle = newTarget
--	    end
--	end
-- @luautil Tween

local Type = require("Engine.Type")
local Util = require("Engine.Util")
local TableUtils = require("Engine.TableUtils")
local ConversionUtils = require("Engine.ConversionUtils")
local InterpolationUtils = require("Engine.InterpolationUtils")

local Round = Util.Round
local WrapAngle = Util.WrapAngleRaw
local TableHasValue = Util.TableHasValue
local SetTableReadOnly = TableUtils.SetTableReadOnly
local SecondsToFrames = ConversionUtils.SecondsToFrames
local FramesToSeconds = ConversionUtils.FramesToSeconds


local IsNumber = Type.IsNumber
local IsVec2 = Type.IsVec2
local IsVec3 = Type.IsVec3
local IsColor = Type.IsColor
local IsRotation = Type.IsRotation
local IsBoolean = Type.IsBoolean
local IsString = Type.IsString
local IsTable = Type.IsTable
local IsLevelFunc = Type.IsLevelFunc

local floor = math.floor
local max = math.max
local min = math.min

local LogMessage  = TEN.Util.PrintLog
local GetFreezeMode = TEN.Flow.GetFreezeMode
local AddCallback = TEN.Logic.AddCallback
local logLevelError  = TEN.Util.LogLevel.ERROR
local logLevelWarning = TEN.Util.LogLevel.WARNING
local CallbackPoint = TEN.Logic.CallbackPoint
local FreezeModeNONE = TEN.Flow.FreezeMode.NONE

local Tween = {}
Tween.__index = Tween
LevelFuncs.Engine.Tween = {}

-- local reference for LevelFuncs.Engine.Tween to avoid table lookups
local F = LevelFuncs.Engine.Tween

local IsValidTweenValue = function(value)
    return IsNumber(value) or
           IsColor(value) or
           IsRotation(value) or
           IsVec2(value) or
           IsVec3(value)
end

local CheckEasingParams = function (functionName, easing, easingParams)
    if easing == Tween.Easing.SMOOTHSTEP or easing == Tween.Easing.SMOOTHERSTEP then
        if not IsTable(easingParams) then
            LogMessage("Warning in ".. functionName .. ": easingParams must be a table for SMOOTHSTEP/SMOOTHERSTEP. Using default values '0' and '1'", logLevelWarning)
            return {0, 1}
        end
        if not easingParams.edge0 or not IsNumber(easingParams.edge0) then
            LogMessage("Warning in ".. functionName .. ": easingParams.edge0 must be a number for SMOOTHSTEP/SMOOTHERSTEP. Using default value '0'", logLevelWarning)
            easingParams.edge0 = 0
        end
        if not easingParams.edge1 or not IsNumber(easingParams.edge1) then
            LogMessage("Warning in ".. functionName .. ": easingParams.edge1 must be a number for SMOOTHSTEP/SMOOTHERSTEP. Using default value '1'", logLevelWarning)
            easingParams.edge1 = 1
        end
        if IsNumber(easingParams.edge1) and IsNumber(easingParams.edge0) and easingParams.edge1 - easingParams.edge0 == 0 then
            LogMessage("Warning in ".. functionName .. ": easingParams.edge1 must be different from edge0 for SMOOTHSTEP/SMOOTHERSTEP. Using default values '0' and '1'", logLevelWarning)
            easingParams.edge0 = 0
            easingParams.edge1 = 1
        end
        return {easingParams.edge0, easingParams.edge1}
    end
    if easing == Tween.Easing.ELASTIC then
        if not IsTable(easingParams) then
            LogMessage("Warning in ".. functionName .. ": easingParams must be a table for ELASTIC. Using default values '1.0' and '0.3'", logLevelWarning)
            return {1.0, 0.3}
        end
        if not easingParams.amplitude or not IsNumber(easingParams.amplitude) or easingParams.amplitude < 1 then
            LogMessage("Warning in ".. functionName .. ": easingParams.amplitude must be a number >= 1 for ELASTIC. Using default value '1.0'", logLevelWarning)
            easingParams.amplitude = 1.0
        end
        if not easingParams.period or not IsNumber(easingParams.period) then
            LogMessage("Warning in ".. functionName .. ": easingParams.period must be a number for ELASTIC. Using default value '0.3'", logLevelWarning)
            easingParams.period = 0.3
        end
        return {easingParams.amplitude, easingParams.period}
    end
    if easing == Tween.Easing.BOUNCE then
        if not IsTable(easingParams) then
            LogMessage("Warning in ".. functionName .. ": easingParams must be a table for BOUNCE. Using default values '4' and '0.5'", logLevelWarning)
            return {4, 0.5}
        end
        if not easingParams.bounces or not IsNumber(easingParams.bounces) or easingParams.bounces < 1 or (easingParams.bounces % 1 ~= 0) then
            LogMessage("Warning in ".. functionName .. ": easingParams.bounces must be an integer and >= 1 for BOUNCE. Using default value '4'", logLevelWarning)
            easingParams.bounces = 4
        end
        if not easingParams.damping or not IsNumber(easingParams.damping) or easingParams.damping < 0 or easingParams.damping > 1 then
            LogMessage("Warning in ".. functionName .. ": easingParams.damping must be a number between 0 and 1 for BOUNCE. Using default value '0.5'", logLevelWarning)
            easingParams.damping = 0.5
        end
        return {easingParams.bounces, easingParams.damping}
    end
end

-- Storage
LevelVars.Engine.Tween = { tweens = {} }

-- local references to avoid table lookups
local T = LevelVars.Engine.Tween.tweens

local TWEEN_INTERPOLATIONS = {
    "Lerp",
    "Smoothstep",
    "Smootherstep",
    "EaseInOut",
    "Elastic",
    "Bounce"
}

Tween.Mode = {
    ONCE = 0,              -- from → to (stop)
    RESTART = 1,           -- from → to - from → to
    PING_PONG = 2,         -- from → to → from
}

Tween.Mode = SetTableReadOnly(Tween.Mode)

Tween.Easing = {
    LERP = 1,
    SMOOTHSTEP = 2,
    SMOOTHERSTEP = 3,
    EASE_IN_OUT = 4,
    ELASTIC = 5,
    BOUNCE = 6
}

Tween.Easing = SetTableReadOnly(Tween.Easing)

Tween.UpdateMode = {
    GAMEPLAY_ONLY = 1,  -- Update only during normal gameplay (PRELOOP)
    FREEZE_ONLY = 2,    -- Update only during freeze/pause (PRE_FREEZE)
    ALWAYS = 3          -- Update in both contexts
}

Tween.UpdateMode = SetTableReadOnly(Tween.UpdateMode)

Tween.ColorSpace = {
    RGB = 1,
    HSL = 2,
    OKLCH = 3
}

Tween.ColorSpace = SetTableReadOnly(Tween.ColorSpace)

Tween.CallbackType = {
    ON_START = "onStart",
    ON_COMPLETE = "onComplete",
    ON_LOOP = "onLoop",
    ON_UPDATE = "onUpdate",
    ON_TO = "onTo",
    ON_FROM = "onFrom"
}

Tween.CallbackType = SetTableReadOnly(Tween.CallbackType)

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
--     from = TEN.Vec3(0, 0, 0),
--     to = TEN.Vec3(10, 10, 10),
--     period = 3.0,
--     mode = Tween.Mode.PING_PONG,
--     loopCount = 5,
--     autoStart = true,
-- }
Tween.Create = function(params)

    -- Validate parameters
    if not IsTable(params) then
        LogMessage("Error in Tween.Create(): params must be a table", logLevelError)
        return nil
    end
    if not IsString(params.name) then
        LogMessage("Error in Tween.Create(): params.name must be a string", logLevelError)
        return nil
    end
    if T[params.name] then
        LogMessage("Warning in Tween.Create(): tween with name '" .. params.name .. "' already exists. Overwriting.", logLevelWarning)
    end
    if not IsValidTweenValue(params.from) then
        LogMessage("Error in Tween.Create(): params.from has invalid type", logLevelError)
        return nil
    end
    if not IsValidTweenValue(params.to) then
        LogMessage("Error in Tween.Create(): params.to has invalid type", logLevelError)
        return nil
    end
    if getmetatable(params.from) ~= getmetatable(params.to) then
        LogMessage("Error in Tween.Create(): params.from and params.to must be of the same type", logLevelError)
        return nil
    end
    if not IsNumber(params.period) or params.period <= 0 then
        LogMessage("Error in Tween.Create(): params.period must be a positive number", logLevelError)
        return nil
    end
    if params.loopCount and (not IsNumber(params.loopCount) or params.loopCount <= 0) then
        LogMessage("Warning in Tween.Create(): params.loopCount must be a positive integer or nil. Using default value 'nil'", logLevelWarning)
        params.loopCount = nil
    end
    if params.loopCount and params.loopCount % 1 ~= 0 then
        LogMessage("Warning in Tween.Create(): params.loopCount is not an integer, flooring the value", logLevelWarning)
        params.loopCount = floor(params.loopCount)
    end
    if params.autoStart and not IsBoolean(params.autoStart) then
        LogMessage("Warning in Tween.Create(): params.autoStart must be a boolean. Using default value 'false'", logLevelWarning)
    end
    if params.seamlessLoop and not IsBoolean(params.seamlessLoop) then
        LogMessage("Warning in Tween.Create(): params.seamlessLoop must be a boolean. Using default value 'false'", logLevelWarning)
    end
    if params.wrapAngle and not IsBoolean(params.wrapAngle) then
        LogMessage("Warning in Tween.Create(): params.wrapAngle must be a boolean. Using default value 'false'", logLevelWarning)
    end
    if params.wrapAngle and not IsNumber(params.from) then
        LogMessage("Warning in Tween.Create(): params.wrapAngle is only supported for numeric values. Flag will be ignored for this tween.", logLevelWarning)
    end
    if params.mode and not TableHasValue(Tween.Mode, params.mode) then
        LogMessage("Warning in Tween.Create(): params.mode has invalid value. Using default value 'ONCE'", logLevelWarning)
    end
    if params.updateMode and not TableHasValue(Tween.UpdateMode, params.updateMode) then
        LogMessage("Warning in Tween.Create(): params.updateMode has invalid value. Using default value 'GAMEPLAY_ONLY'", logLevelWarning)
    end
    if params.easing and not TableHasValue(Tween.Easing, params.easing) then
        LogMessage("Warning in Tween.Create(): params.easing has invalid value. Using default value 'LERP'", logLevelWarning)
    end
    if params.onStart and not IsLevelFunc(params.onStart) then
        LogMessage("Warning in Tween.Create(): params.onStart must be a LevelFunc. The callback will not be assigned", logLevelWarning)
    end
    if params.onComplete and not IsLevelFunc(params.onComplete) then
        LogMessage("Warning in Tween.Create(): params.onComplete must be a LevelFunc. The callback will not be assigned", logLevelWarning)
    end
    if params.onLoop and not IsLevelFunc(params.onLoop) then
        LogMessage("Warning in Tween.Create(): params.onLoop must be a LevelFunc. The callback will not be assigned", logLevelWarning)
    end
    if params.onUpdate and not IsLevelFunc(params.onUpdate) then
        LogMessage("Warning in Tween.Create(): params.onUpdate must be a LevelFunc. The callback will not be assigned", logLevelWarning)
    end
    if params.onTo and not IsLevelFunc(params.onTo) then
        LogMessage("Warning in Tween.Create(): params.onTo must be a LevelFunc. The callback will not be assigned", logLevelWarning)
    end
    if params.onFrom and not IsLevelFunc(params.onFrom) then
        LogMessage("Warning in Tween.Create(): params.onFrom must be a LevelFunc. The callback will not be assigned", logLevelWarning)
    end
    -- Create tween
    T[params.name] = {}
    local thisTween = T[params.name]
    thisTween.from = params.from
    thisTween.to = params.to
    thisTween.period = params.period
    thisTween.mode = TableHasValue(Tween.Mode, params.mode) and params.mode or Tween.Mode.ONCE
    thisTween.updateMode = TableHasValue(Tween.UpdateMode, params.updateMode) and params.updateMode or Tween.UpdateMode.GAMEPLAY_ONLY
    thisTween.easing = TableHasValue(Tween.Easing, params.easing) and  params.easing or Tween.Easing.LERP

    if params.easingParams and thisTween.easing == Tween.Easing.LERP then
        LogMessage("Warning in Tween.Create(): easingParams are not used with LERP easing. Ignoring easingParams.", logLevelWarning)
        params.easingParams = nil
    end

    if params.easingParams then
        thisTween.easingParams = CheckEasingParams("Tween.Create()", thisTween.easing, params.easingParams)
    end


    thisTween.loopCount = params.loopCount or nil
    thisTween.autoStart = IsBoolean(params.autoStart) and params.autoStart or false
    thisTween.seamlessLoop = IsBoolean(params.seamlessLoop) and params.seamlessLoop or false
    -- wrapAngle: only effective for numeric values (uses shortest angular path like MathUtils.LerpAngle)
    thisTween.wrapAngle = IsBoolean(params.wrapAngle) and params.wrapAngle and IsNumber(params.from) or false

    -- Pre-calculate effectiveTo for wrapAngle (shortest angular path)
    if thisTween.wrapAngle then
        local delta = WrapAngle(thisTween.to - thisTween.from, -180, 180)
        thisTween.effectiveTo = thisTween.from + delta
    end

    -- State management
    thisTween.active = params.autoStart and true or false
    thisTween.paused = false

    thisTween.interpolation = TWEEN_INTERPOLATIONS[thisTween.easing]
    thisTween.interpolationDuration = SecondsToFrames(thisTween.period)

    -- Interpolation state
    thisTween.elapsed = 0
    thisTween.progress = 0.0
    thisTween.value = thisTween.from
    thisTween.direction = 1
    thisTween.currentLoopIndex = 0
    thisTween.completed = false
    thisTween.hasStarted = false
    thisTween.shouldResetNextFrame = false
    thisTween.shouldFlipNextFrame = false

    -- Cache wrapper to avoid runtime allocations
    thisTween.wrapper = setmetatable({ name = params.name }, Tween)

    -- Callbacks
    thisTween.callbacks = {
        onStart = IsLevelFunc(params.onStart) and params.onStart or nil,
        onComplete = IsLevelFunc(params.onComplete) and params.onComplete or nil,
        onLoop = IsLevelFunc(params.onLoop) and params.onLoop or nil,
        onUpdate = IsLevelFunc(params.onUpdate) and params.onUpdate or nil,
        onTo = IsLevelFunc(params.onTo) and params.onTo or nil,
        onFrom = IsLevelFunc(params.onFrom) and params.onFrom or nil,
    }

    -- Callback ON_START if autoStart is true
    if thisTween.autoStart then
        thisTween.hasStarted = true
        if thisTween.callbacks.onStart then
            thisTween.callbacks.onStart(thisTween.wrapper)
        end
    end

    local self = { name = params.name }
    return setmetatable(self, Tween)
end

--- Delete tween instance
-- @tparam string name Name of the tween to delete
-- @usage Tween.Delete("myTween")
Tween.Delete = function (name)
    if not IsString(name) then
        LogMessage("Error in Tween.Delete(): invalid name", logLevelError)
        return nil
    end
    if  T[name] then
        T[name] = nil
    end
end

--- Get tween instance
-- @tparam string name Name of the tween to get
-- @treturn[1] Tween instance
-- @treturn[2] nil If tween does not exist
-- @usage local myTween = Tween.Get("myTween")
Tween.Get = function(name)
    if not IsString(name) then
        LogMessage("Error in Tween.Get(): invalid name", logLevelError)
        return nil
    end
    if not T[name] then
        LogMessage("Error in Tween.Get(): tween '" .. name .. "' does not exist. Use Tween.Create() first or check Tween.IfExists()", logLevelError)
        return nil
    end
    return setmetatable({ name = name }, Tween)
end

--- Check if tween instance exists
-- @tparam string name Name of the tween to check
-- @treturn bool True if exists, false otherwise
-- @usage if Tween.IfExists("myTween") then ... end
Tween.IfExists = function(name)
    if not IsString(name) then
        LogMessage("Error in Tween.IfExists(): invalid name", logLevelError)
        return nil
    end
    return T[name] and true or false
end

----
-- List of all methods of the Tween object. For proper error handling, before calling the method, we recommend that you always check whether the tween exists with `Tween.IfExists`.
-- Also to avoid errors when loading a save game it is recommended to use `Tween.Get` to retrieve the tween at any time. Be careful when saving the tween to a **local variable**. Loading a save file resets the local variables. Use this approach with caution.
-- @usage
-- -- Warning: This approach, if handled poorly, can cause errors after loading a save game
-- local myTween
-- if Tween.IfExists("myTween") then
--     myTween = Tween.Get("myTween")
--     myTween:Start()
-- end
-- -- ... later in the code
-- myTween:Reverse()
--
-- -- Recommended approach: Check for the existence of a tween and retrieve it with the Get() method
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Start()
-- end
-- -- ... later in the code
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Reverse()
-- end
--
-- -- if you need to use it multiple times in a function, you can store it in a local variable safely
-- local function UpdateMyTween()
--     if Tween.IfExists("myTween") then
--         local myTween = Tween.Get("myTween")
--         myTween:Start()
--         -- ... other operations
--         myTween:Reverse()
--     end
-- end
--
-- -- If you are sure that the tween exists, then you can just use the Get() method
-- Tween.Get("myTween"):Start()
-- -- ... later in the code
-- Tween.Get("myTween"):Reverse()
-- @type Tween

--- Start or resume the tween
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Start()
-- end
function Tween:Start()
    local t = T[self.name]
    if t.completed then
        self:Reset()
    end
    t.active = true
    t.paused = false
    -- Callback ON_START only if not already started
    if not t.hasStarted then
        t.hasStarted = true
        if t.callbacks.onStart then
            t.callbacks.onStart(self)
        end
    end
end

--- Restart the tween from the beginning
-- @usage 
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Restart()
-- end
function Tween:Restart()
    local t = T[self.name]
    t.active = true
    t.paused = false
    t.elapsed = 0
    t.progress = 0.0
    t.value = t.from
    t.direction = 1
    t.currentLoopIndex = 0
    t.completed = false
    t.hasStarted = true
    t.shouldResetNextFrame = false
    t.shouldFlipNextFrame = false
    -- Callback ON_START (Restart always triggers onStart)
    if t.callbacks.onStart then
        t.callbacks.onStart(self)
    end
end

--- Pause the tween
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Pause()
-- end
function Tween:Pause()
    T[self.name].paused = true
end

--- Stop the tween
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Stop()
-- end
function Tween:Stop()
    T[self.name].active = false
end

--- Reset the tween to the initial state
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Reset()
-- end
function Tween:Reset()
    local t = T[self.name]
    t.active = false
    t.paused = false
    t.elapsed = 0
    t.progress = 0.0
    t.value = t.from
    t.direction = 1
    t.currentLoopIndex = 0
    t.completed = false
    t.hasStarted = false
    t.shouldResetNextFrame = false
    t.shouldFlipNextFrame = false
end

--- Get the current direction of the tween
-- @treturn int 1 for from→to, -1 for to→from
-- @usage
-- local direction
-- if Tween.IfExists("myTween") then
--     direction = Tween.Get("myTween"):GetDirection()
-- end
function Tween:GetDirection()
    return T[self.name].direction
end

--- Get the current loop index (0-based)
-- @treturn int Current loop index
-- @usage
-- local currentLoop
-- if Tween.IfExists("myTween") then
--     currentLoop = Tween.Get("myTween"):GetCurrentLoop()
-- end
function Tween:GetCurrentLoop()
    return T[self.name].currentLoopIndex
end

--- Get the current value of the tween
-- @treturn float|Color|Rotation|Vec2|Vec3 Current tweened value
-- @usage
-- local currentValue
-- if Tween.IfExists("myTween") then
--     currentValue = Tween.Get("myTween"):GetValue()
-- end
function Tween:GetValue()
    return T[self.name].value
end

--- Get the current progress of the tween (0.0 to 1.0)
-- @treturn number Current progress (0.0 to 1.0)
-- @usage
-- local progress
-- if Tween.IfExists("myTween") then
--     progress = Tween.Get("myTween"):GetProgress()
-- end
function Tween:GetProgress()
    return T[self.name].progress
end

--- Set the current progress of the tween (0.0 to 1.0)
-- @tparam number t Progress value to set (0.0 to 1.0). Values outside this range will be clamped.
-- @usage myTween:SetProgress(0.5)  -- Set progress to halfway
function Tween:SetProgress(t)
    if not IsNumber(t) then
        return LogMessage("Error in Tween:SetProgress(t): t must be a number", logLevelError)
    end
    local clampT = max(0, min(1, t))
    T[self.name].progress = clampT
end

--- Get the time remaining for the tween to complete (in seconds)
-- @treturn number Time remaining in seconds
-- @usage
-- local timeRemaining
-- if Tween.IfExists("myTween") then
--     timeRemaining = Tween.Get("myTween"):GetTimeRemaining()
-- end
function Tween:GetTimeRemaining()
    local t = T[self.name]
    local remainingFrames = t.interpolationDuration - t.elapsed
    if remainingFrames < 0 then
        remainingFrames = 0
    end
    return Round(FramesToSeconds(remainingFrames), 2)  -- Assuming 30 FPS
end

--- Get the period of the tween (in seconds)
-- @treturn number Period in seconds (duration of one direction; for PING_PONG, full cycle is period * 2)
-- @usage
-- local period
-- if Tween.IfExists("myTween") then
--     period = Tween.Get("myTween"):GetPeriod()
-- end
function Tween:GetPeriod()
    return T[self.name].period
end

--- Set the period of the tween (in seconds)
-- @tparam float period Period in seconds (duration of one direction; for PING_PONG, full cycle is period * 2). Must be positive.
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetPeriod(3.0)  -- Set period to 3 seconds
-- end
function Tween:SetPeriod(period)
    if not IsNumber(period) or period <= 0 then
        return LogMessage("Error in Tween:SetPeriod(period): period must be a positive number", logLevelError)
    end
    local t = T[self.name]
    t.period = period
    t.interpolationDuration = SecondsToFrames(period)
end

--- Get the 'from' value of the tween
-- @treturn float|Color|Rotation|Vec2|Vec3 'from' value
-- @usage
-- local fromValue
-- if Tween.IfExists("myTween") then
--     fromValue = Tween.Get("myTween"):GetFrom()
-- end
function Tween:GetFrom()
    return T[self.name].from
end

--- Set the 'from' value of the tween
-- @tparam float|Color|Rotation|Vec2|Vec3 value 'from' value to set. Remember that 'from' and 'to' must be the same type!
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetFrom(0)  -- Set 'from' value to 0
-- end
function Tween:SetFrom(value)
    if not IsValidTweenValue(value) then
        return LogMessage("Error in Tween:SetFrom(value): invalid value type", logLevelError)
    end
    if getmetatable(value) ~= getmetatable(T[self.name].to) then
        return LogMessage("Error in Tween:SetFrom(value): 'from' value type must match 'to' value type", logLevelError)
    end
    local t = T[self.name]
    t.from = value
    -- Recalculate effectiveTo if wrapAngle is active
    if t.wrapAngle then
        local delta = WrapAngle(t.to - t.from, -180, 180)
        t.effectiveTo = t.from + delta
    end
end

--- Get the 'to' value of the tween
-- @treturn float|Color|Rotation|Vec2|Vec3 'to' value.
-- @usage
-- local toValue
-- if Tween.IfExists("myTween") then
--     toValue = Tween.Get("myTween"):GetTo()
-- end
function Tween:GetTo()
    return T[self.name].to
end

--- Set the 'to' value of the tween
-- @tparam float|Color|Rotation|Vec2|Vec3 value 'to' value to set. Remember that 'from' and 'to' must be the same type!
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetTo(100)  -- Set 'to' value to 100
-- end
function Tween:SetTo(value)
    if not IsValidTweenValue(value) then
        return LogMessage("Error in Tween:SetTo(value): invalid value type", logLevelError)
    end
    if getmetatable(value) ~= getmetatable(T[self.name].from) then
        return LogMessage("Error in Tween:SetTo(value): 'to' value type must match 'from' value type", logLevelError)
    end
    local t = T[self.name]
    t.to = value
    -- Recalculate effectiveTo if wrapAngle is active
    if t.wrapAngle then
        local delta = WrapAngle(t.to - t.from, -180, 180)
        t.effectiveTo = t.from + delta
    end
end

--- Get both 'from' and 'to' values of the tween
-- @treturn float|Color|Rotation|Vec2|Vec3 'from' values
-- @treturn float|Color|Rotation|Vec2|Vec3 'to' values
-- @usage
-- local fromValue, toValue
-- if Tween.IfExists("myTween") then
--     fromValue, toValue = Tween.Get("myTween"):GetFromAndTo()
-- end
function Tween:GetFromAndTo()
    local t = T[self.name]
    return t.from, t.to
end

--- Set both 'from' and 'to' values of the tween. Remember that 'from' and 'to' must be the same type!
-- @tparam float|Color|Rotation|Vec2|Vec3 from 'from' value to set
-- @tparam float|Color|Rotation|Vec2|Vec3 to 'to' value to set
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetFromAndTo(0, 100)  -- Set 'from' to 0 and 'to' to 100
-- end
function Tween:SetFromAndTo(from, to)
    if not IsValidTweenValue(from) then
        return LogMessage("Error in Tween:SetFromAndTo(from, to): invalid 'from' value type", logLevelError)
    end
    if not IsValidTweenValue(to) then
        return LogMessage("Error in Tween:SetFromAndTo(from, to): invalid 'to' value type", logLevelError)
    end
    if getmetatable(from) ~= getmetatable(to) then
        return LogMessage("Error in Tween:SetFromAndTo(from, to): 'from' and 'to' value types must match", logLevelError)
    end
    local t = T[self.name]
    t.from = from
    t.to = to
    -- Recalculate effectiveTo if wrapAngle is active
    if t.wrapAngle then
        local delta = WrapAngle(t.to - t.from, -180, 180)
        t.effectiveTo = t.from + delta
    end
end

--- Get the easing function of the tween
-- @treturn int Easing function (use Tween.Easing)
-- @usage
-- local easing
-- if Tween.IfExists("myTween") then
--     easing = Tween.Get("myTween"):GetEasing()
-- end
function Tween:GetEasing()
    return T[self.name].easing
end

--- Set the easing function of the tween
-- @tparam Easing easing Easing function to set (use Tween.Easing)
-- @tparam[opt] table params Easing parameters table. Please note: if you change the easing without specifying params, the existing parameters will be reset to default values (nil). To preserve custom parameters, always provide them when changing easing, or use SetEasingParams() separately after SetEasing().
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetEasing(Tween.Easing.SMOOTHSTEP)
-- end
--
-- -- Example with custom parameters
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetEasing(Tween.Easing.SMOOTHSTEP, {edge0 = 0.2, edge1 = 0.8})
-- end
function Tween:SetEasing(easing, params)
    if not TableHasValue(Tween.Easing, easing) then
        return LogMessage("Error in Tween:SetEasing(easing): invalid easing value", logLevelError)
    end
    local t = T[self.name]
    t.easing = easing
    t.interpolation = TWEEN_INTERPOLATIONS[easing]
    if params and not IsTable(params) then
        return LogMessage("Error in Tween:SetEasing(): params must be a table", logLevelError)
    end
    if params and IsTable(params) then
        t.easingParams = CheckEasingParams("Tween:SetEasing()", easing, params)
    else
        t.easingParams = nil
    end
end

--- Set the easing parameters of the tween
-- @tparam table params Easing parameters table
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetEasingParams({edge0 = 0, edge1 = 1})
-- end
function Tween:SetEasingParams(params)
    if not IsTable(params) then
        return LogMessage("Error in Tween:SetEasingParams(params): params must be a table", logLevelError)
    end
    local t = T[self.name]
    t.easingParams = CheckEasingParams("Tween:SetEasingParams()", t.easing, params)
end

--- Get the loop count of the tween
-- @treturn int|nil Loop count, or nil for infinite loops
-- @usage
-- local loopCount
-- if Tween.IfExists("myTween") then
--     loopCount = Tween.Get("myTween"):GetLoopCount()
-- end
function Tween:GetLoopCount()
    return T[self.name].loopCount
end

--- Set the loop count of the tween. Remember that nil means infinite loops! Not a zero value.
-- @tparam int|nil count Loop count to set, or nil for infinite loops
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetLoopCount(5)  -- Set loop count to 5
-- end
function Tween:SetLoopCount(count)
    if count ~= nil then
        if not IsNumber(count) or count <= 0 then
            return LogMessage("Error in Tween:SetLoopCount(): count deve essere un intero positivo o nil", logLevelError)
        end

        if count % 1 ~= 0 then
            LogMessage("Warning in Tween:SetLoopCount(): count non è un intero, arrotondamento (floor)", logLevelWarning)
            count = floor(count)
        end
    end
    T[self.name].loopCount = count
end

--- Get the update mode of the tween
-- @treturn int Update mode (use Tween.UpdateMode)
-- @usage
-- local updateMode
-- if Tween.IfExists("myTween") then
--     updateMode = Tween.Get("myTween"):GetUpdateMode()
-- end
function Tween:GetUpdateMode()
    return T[self.name].updateMode
end

--- Set the update mode of the tween
-- @tparam UpdateMode mode Update mode to set (use Tween.UpdateMode)
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetUpdateMode(Tween.UpdateMode.ALWAYS)
-- end
function Tween:SetUpdateMode(mode)
    if not TableHasValue(Tween.UpdateMode, mode) then
        return LogMessage("Error in Tween:SetUpdateMode(mode): invalid updateMode value", logLevelError)
    end
    T[self.name].updateMode = mode
end

--- Reverse the tween direction
-- @usage
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):Reverse()
-- end
function Tween:Reverse()
    local t = T[self.name]
    t.direction = -t.direction
end

--- Set callback function
-- @tparam CallbackType callbackType Type of callback (use Tween.CallbackType)
-- @tparam function func Callback function in LevelFuncs hierarchy
-- @usage
-- -- Define callback function in LevelFuncs
-- LevelFuncs.MyTweenOnUpdate = function(value, progress, tween)
--     TEN.Util.PrintLog("Tween Update: Value=" .. tostring(value) .. " Progress=" .. tostring(progress))
--     -- Optional: use tween parameter for dynamic control
--     if value > 50 then
--         tween:SetTo(Lara:GetAir())
--     end
-- end
-- -- Set the callback
-- if Tween.IfExists("myTween") then
--     Tween.Get("myTween"):SetCallback(Tween.CallbackType.ON_UPDATE, LevelFuncs.MyTweenOnUpdate)
-- end
function Tween:SetCallback(callbackType, func)
    if not TableHasValue(Tween.CallbackType, callbackType) then
        return LogMessage("Error in Tween:SetCallback(callbackType, func): invalid callbackType", logLevelError)
    end
    if not IsLevelFunc(func) then
        return LogMessage("Error in Tween:SetCallback(callbackType, func): func must be a LevelFunc", logLevelError)
    end
    T[self.name].callbacks[callbackType] = func
end

--- Check if the tween is currently active
-- @treturn bool True if active, false otherwise
-- @usage
-- if Tween.IfExists("myTween") and Tween.Get("myTween"):IsActive() then
--  ...
-- end
function Tween:IsActive()
    return T[self.name].active
end

--- Check if the tween is currently paused
-- @treturn bool True if paused, false otherwise
-- @usage
-- if Tween.IfExists("myTween") and Tween.Get("myTween"):IsPaused() then
--  ... 
-- end
function Tween:IsPaused()
    return T[self.name].paused
end

--- Check if the tween has completed
-- @treturn bool True if completed, false otherwise
-- @usage
-- if Tween.IfExists("myTween") and Tween.Get("myTween"):IsCompleted() then
--  ... 
-- end
function Tween:IsCompleted()
    return T[self.name].completed
end

----
-- Table and constants for Tween system
-- @section TweenConstants

---
-- Table setup for creating Tween.
--
-- For PING_PONG mode:
--
-- each period is ONE DIRECTION (from→to or to→from).
-- <table class="tableSP">
-- <tr><td>period = 1.0s</td><td>from → to → from 2.0s</td></tr>
-- <tr><td>period = 2.0s</td><td>from → to → from (4.0s)</td></tr>
-- <tr><td>period = 0.5s</td><td>from → to → from (1.0s)</td></tr>
-- </table>
--
-- each loop is ONE DIRECTION.
-- <table class="tableSP">
-- <tr><td>loopCount = 1</td><td>from → to</td></tr>
-- <tr><td>loopCount = 2</td><td>from → to → from</td></tr>
-- <tr><td>loopCount = 3</td><td>from → to → from → to</td></tr>
-- <tr><td>loopCount = 4</td><td>from → to → from → to → from</td></tr>
-- </table>
-- @table TweenParameters
-- @tfield string name Name of the tween (unique identifier)
-- @tfield float|Color|Rotation|Vec2|Vec3 from Starting value
-- @tfield float|Color|Rotation|Vec2|Vec3 to Ending value. `from` and `to` must be the same type!
-- @tfield float period Duration of ONE DIRECTION in seconds. For PING_PONG mode, a complete cycle (from→to→from) takes `period * 2` seconds. This follows the standard convention used by professional tween libraries (DOTween, GSAP, etc.).
-- @tfield[opt=Tween.Mode.ONCE] int mode Tween mode (use `Tween.Mode`)
-- @tfield[opt=Tween.UpdateMode.GAMEPLAY_ONLY] int updateMode When the tween should update (use `Tween.UpdateMode`).<br>
-- @tfield[opt=Tween.Easing.LERP] int easing Easing function (use `Tween.Easing`)
-- @tfield[opt=nil] int loopCount Number of loops (nil for infinite). In RESTART mode, each loop is a complete from→to cycle. In PING_PONG mode, each loop is ONE DIRECTION (from→to or to→from). This follows DOTween/GSAP conventions.
-- @tfield[opt=false] bool autoStart Whether to start the tween immediately
-- @tfield[opt] table easingParams Optional parameters for easing function. See documentation for each easing type for details. For SMOOTHSTEP and SMOOTHERSTEP expect `edge0` and `edge1` numeric fields. see `InterpolationUtils.Smoothstep` and `InterpolationUtils.Smootherstep`. ELASTIC expects `amplitude` and `period` numeric fields, see `InterpolationUtils.Elastic`. If not provided, default parameters will be used. For BOUNCE expects `bounces` (integer) and `damping` (number) fields, see `InterpolationUtils.Bounce`.
-- @tfield[opt=false] bool seamlessLoop When true, RESTART mode uses seamless loop transitions for cyclic values like rotations (0-360°). When false (default), uses precise reset for better accuracy with Vec3/Color. Only affects RESTART mode - PING_PONG always uses seamless transitions. Use true for smooth infinite rotations, false for precise positional loops.
-- @tfield[opt=false] bool wrapAngle When true, interpolates numeric values using the **shortest angular path** (like `InterpolationUtils.LerpAngle`). Only works with numeric `from`/`to` values - ignored for Color, Vec2, Vec3. For Rotation primitives, use `Rotation:Lerp()` which already handles shortest path automatically. Perfect for 2D UI elements like compass needles, gauges, and indicators. Example: from=350° to=10° will interpolate through 0° (20° path) instead of going the long way (340° path).
-- @tfield[opt] function onStart function in LevelFuncs hierarchy called on start. Signature: `function(tween)`
-- @tfield[opt] function onComplete function in LevelFuncs hierarchy called on complete. Signature: `function(value, tween)`
-- @tfield[opt] function onLoop function in LevelFuncs hierarchy called on loop. Signature: `function(value, tween)`
-- @tfield[opt] function onUpdate function in LevelFuncs hierarchy called on update. Signature: `function(value, progress, tween)`
-- @tfield[opt] function onTo function in LevelFuncs hierarchy called on reaching 'to' value. Signature: `function(value, tween)`
-- @tfield[opt] function onFrom function in LevelFuncs hierarchy called on reaching 'from' value. Signature: `function(value, tween)`

---
-- Costants for tween modes.
-- @table Mode
-- @tfield 0 ONCE Tween runs once from 'from' to 'to'. Default mode.
-- @tfield 1 RESTART Tween restarts from 'from' to 'to' repeatedly. Each loop takes `period` seconds. loopCount=N means N complete from→to cycles.
-- @tfield 2 PING_PONG Tween oscillates between 'from' and 'to'. Each direction takes `period` seconds. loopCount counts EACH DIRECTION: loopCount=1 means from→to only, loopCount=2 means from→to→from, loopCount=4 means from→to→from→to→from (2 complete cycles). This follows DOTween/GSAP conventions.

---
-- Constants for tween easing functions.
-- @table Easing
-- @tfield 1 LERP Linear interpolation. See `InterpolationUtils.Lerp`. Default easing.
-- @tfield 2 SMOOTHSTEP Smoothstep interpolation. See `InterpolationUtils.Smoothstep`.
-- @tfield 3 SMOOTHERSTEP Smootherstep interpolation. See `InterpolationUtils.Smootherstep`.
-- @tfield 4 EASE_IN_OUT Ease in-out interpolation. See `InterpolationUtils.EaseInOut`.
-- @tfield 5 ELASTIC Elastic interpolation. See `InterpolationUtils.Elastic`.
-- @tfield 6 BOUNCE Bounce interpolation. See `InterpolationUtils.Bounce`.

---
-- Constants for tween update modes.
-- @table UpdateMode
-- @tfield 1 GAMEPLAY_ONLY Update only during normal gameplay (PRE_LOOP callback). Use for gameplay animations like moving platforms, doors, etc. Default mode.
-- @tfield 2 FREEZE_ONLY Update only during freeze mode (PRE_FREEZE callback). Use for UI animations during pause, loading screens, etc.
-- @tfield 3 ALWAYS Update in both gameplay and freeze mode contexts. Use for cross-context effects like audio fades, screen transitions, etc.

---
-- Constants for tween callback types.
-- @table CallbackType
-- @tfield "onStart" ON_START Called when the tween starts. Signature: `function(tween)`
-- @tfield "onComplete" ON_COMPLETE Called when the tween completes. Signature: `function(value, tween)`
-- @tfield "onLoop" ON_LOOP Called when the tween loops. For RESTART mode, called after reaching 'to' value. For PING_PONG mode, called after reaching 'to' or 'from' value. Signature: `function(value, tween)`
-- @tfield "onUpdate" ON_UPDATE Called on each update/frame. Signature: `function(value, progress, tween)`
-- @tfield "onTo" ON_TO Called when reaching the 'to' value. Signature: `function(value, tween)`
-- @tfield "onFrom" ON_FROM Called when reaching the 'from' value. Signature: `function(value, tween)`

----
-- Example usage of Tween system.
-- @section TweenExample

--- Example: Bridge moved from point a to point b in 5 seconds using a tween with a callback function.
-- @table Example 1
-- @usage
-- local bridgeTweenParams = {
--    name = "BridgeMove",
--    from = Vec3.New(0, 0, 0),
--    to = Vec3.New(0, 10, 0),
--    period = 5.0,
--    autoStart = true,
-- }
-- -- Define callback function in LevelFuncs
-- LevelFuncs.BridgeOnUpdate = function(value, progress, tween)
--     -- Move the bridge to the new position
--     local bridgeEntity = TEN.Entity.GetByName("Bridge")
--     if bridgeEntity then
--         bridgeEntity:SetPosition(value)
--     end
-- end
--
-- -- Create the tween
-- Tween.Create(bridgeTweenParams)

F.UpdateAll = function()
    local isInFreeze = GetFreezeMode() ~= FreezeModeNONE

    for name, t in pairs(T) do
        if t.active and not t.paused then
            -- Check if should update based on updateMode and current freeze state
            local shouldUpdate = (t.updateMode == Tween.UpdateMode.ALWAYS) or
                                 (t.updateMode == Tween.UpdateMode.GAMEPLAY_ONLY and not isInFreeze) or
                                 (t.updateMode == Tween.UpdateMode.FREEZE_ONLY and isInFreeze)

            if shouldUpdate then
                -- If completed in the previous frame, deactivate now (after OnLoop has seen the final value)
                if t.completed then
                    t.active = false
                else
                    -- Apply reset/flip deferred from the previous frame (BEFORE calculating the new value)
                    if t.shouldResetNextFrame then
                        t.elapsed = t.seamlessLoop and 1 or 0
                        t.progress = 0.0
                        t.value = t.from
                        t.shouldResetNextFrame = false
                    end

                    if t.shouldFlipNextFrame then
                        t.elapsed = 1
                        t.progress = 0.0
                        t.direction = -t.direction
                        t.shouldFlipNextFrame = false
                    end
                    -- Calculate progress BEFORE incrementing (to show initial value)
                    t.progress = t.elapsed / t.interpolationDuration

                    if t.progress > 1.0 then
                        t.progress = 1.0
                    end

                    -- Calculate value: swap from/to when going backwards to preserve easing curve
                    -- Use effectiveTo for wrapAngle (shortest angular path)
                    local targetTo = t.wrapAngle and t.effectiveTo or t.to
                    if t.direction == 1 then
                        if t.easingParams then
                            t.value = InterpolationUtils[t.interpolation](t.from, targetTo, t.progress, table.unpack(t.easingParams))
                        else
                            t.value = InterpolationUtils[t.interpolation](t.from, targetTo, t.progress)
                        end
                    else
                        if t.easingParams then
                            t.value = InterpolationUtils[t.interpolation](targetTo, t.from, t.progress, table.unpack(t.easingParams))
                        else
                            t.value = InterpolationUtils[t.interpolation](targetTo, t.from, t.progress)
                        end
                    end

                    -- Callback ON_UPDATE
                    if t.callbacks.onUpdate then
                        t.callbacks.onUpdate(t.value, t.progress, t.wrapper)
                    end

                    -- Increment AFTER calculating the value
                    t.elapsed = t.elapsed + 1

                    if t.progress >= 1.0 then
                        -- Force exact final value (for safety)
                        t.value = t.direction == 1 and t.to or t.from

                        -- Callback ON_TO or ON_FROM based on direction (common to all modes)
                        if t.direction == 1 then
                            if t.callbacks.onTo then
                                t.callbacks.onTo(t.value, t.wrapper)
                            end
                        else
                            if t.callbacks.onFrom then
                                t.callbacks.onFrom(t.value, t.wrapper)
                            end
                        end

                        -- Handle completion based on mode
                        if t.mode == Tween.Mode.ONCE then
                            t.completed = true
                            -- Callback ON_COMPLETE
                            if t.callbacks.onComplete then
                                t.callbacks.onComplete(t.value, t.wrapper)
                            end
                        else -- RESTART or PING_PONG
                            -- set deferred action
                            if t.mode == Tween.Mode.RESTART then
                                t.shouldResetNextFrame = true
                            else -- PING_PONG mode
                                t.shouldFlipNextFrame = true
                            end

                            -- Loop counting logic (identical for RESTART and PING_PONG)
                            if t.loopCount then
                                t.currentLoopIndex = t.currentLoopIndex + 1
                                if t.currentLoopIndex >= t.loopCount then
                                    t.completed = true
                                    -- Cancel deferred action if completed
                                    t.shouldResetNextFrame = false
                                    t.shouldFlipNextFrame = false
                                    -- Callback ON_COMPLETE
                                    if t.callbacks.onComplete then
                                        t.callbacks.onComplete(t.value, t.wrapper)
                                    end
                                else
                                    -- Not completed yet: call ON_LOOP
                                    if t.callbacks.onLoop then
                                        t.callbacks.onLoop(t.value, t.wrapper)
                                    end
                                end
                            else
                                -- Infinite loop: continue without counting. Call ON_LOOP
                                if t.callbacks.onLoop then
                                    t.callbacks.onLoop(t.value, t.wrapper)
                                end
                            end
                        end -- close mode check
                    end -- close if progress >= 1.0
                end -- closes if not completed
            end  -- close if shouldUpdate
        end -- close if active and not paused
    end -- close for each tween
end

AddCallback(CallbackPoint.PRE_LOOP, F.UpdateAll)

AddCallback(CallbackPoint.PRE_FREEZE, F.UpdateAll)

return Tween