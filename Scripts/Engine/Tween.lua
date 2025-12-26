
local Type = require("Engine.Type")
local LuaUtil = require("Engine.LuaUtil")

local Tween = {}
Tween.__index = Tween
LevelFuncs.Engine.Tween = {}

Tween.Mode ={
    ONCE = 0,              -- from → to (stop)
    RESTART = 1,           -- from → to - from → to
    PING_PONG = 2,         -- from → to → from
}

Tween.Easing = {
    LERP = 0,
    SMOOTHSTEP = 1,
    SMOOTHERSTEP = 2,
    EASE_IN_OUT = 3,
    ELASTIC = 4
}

Tween.CallbackType = {
    ON_START = "onStart",
    ON_COMPLETE = "onComplete",
    ON_LOOP = "onLoop",
    ON_PEAK = "onPeak",      -- Quando raggiunge max
    ON_VALLEY = "onValley"   -- Quando raggiunge min
}

-- Storage
LevelVars.Engine.Tween = { tweens = {} }


Tween.Create = function(parameters)
    LevelVars.Engine.Tween.tweens[parameters.name] = {}
    local thisTween = LevelVars.Engine.Tween.tweens[parameters.name]
    thisTween.from = parameters.from
    thisTween.to = parameters.to
    thisTween.period = parameters.period
    thisTween.mode = parameters.mode or Tween.Mode.ONCE
    thisTween.easing = parameters.easing or Tween.Easing.LERP
    thisTween.easingParams = parameters.easingParams or nil
    thisTween.loopCount = parameters.loopCount or nil
    thisTween.autoStart = parameters.autoStart or false

    thisTween.active = parameters.autoStart and true or false
    thisTween.pause = parameters.autoStart and true or false
    local self = { name = parameters.name }
    return setmetatable(self, Tween)
end

Tween.Delete = function (name)
    if LevelVars.Engine.Tween.tweens[name] then
        LevelVars.Engine.Tween.tweens[name] = nil
    end
end

Tween.Get = function (name)
    if LevelVars.Engine.Tween.tweens[name] then
        return setmetatable({ name = name }, Tween)
    end
end

Tween.IfExists = function(name)
    return LevelVars.Engine.Tween.tweens[name] and true or false
end

--- Methods
function Tween:Start() end
function Tween:Stop() end
function Tween:Pause() end
function Tween:Reset() end
function Tween:GetValue() end
function Tween:SetValue(value) end
function Tween:GetPeriod() end
function Tween:SetPeriod(period) end
function Tween:GetFrom() end
function Tween:SetFrom(min) end
function Tween:GetTo() end
function Tween:SetTo(min) end
function Tween:SetEasing(easing) end
function Tween:SetCallback(callbackType, func) end
function Tween:Reverse() end
function Tween:IsActive() end
function Tween:IsPaused() end

LevelFuncs.Engine.Tween.UpdateAll = function()
    for _, t in pairs(LevelVars.Engine.Tween.tweens) do
        if t.active then
            
        end
    end
end

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.Tween.UpdateAll)

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_FREEZE, LevelFuncs.Engine.Tween.UpdateAll)

return Tween