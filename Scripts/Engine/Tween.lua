
local Type = require("Engine.Type")
local LuaUtil = require("Engine.LuaUtil")

local Tween = {}
Tween.__index = Tween
LevelFuncs.Engine.Tween = {}

Tween.Mode = LuaUtil.SetTableReadOnly({
    ONCE = 0,              -- from → to (stop)
    RESTART = 1,           -- from → to - from → to
    PING_PONG = 2,         -- from → to → from
})

Tween.Easing = LuaUtil.SetTableReadOnly({
    LERP = 0,
    SMOOTHSTEP = 1,
    SMOOTHERSTEP = 2,
    EASE_IN_OUT = 3,
    ELASTIC = 4
})

Tween.CallbackType = LuaUtil.SetTableReadOnly({
    ON_START = "onStart",
    ON_COMPLETE = "onComplete",
    ON_LOOP = "onLoop",
    ON_TO = "onTo",      -- Quando raggiunge to
    ON_FROM = "onFrom"   -- Quando raggiunge from
})

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

--- Lifecycle (tutti separati, chiari)
function Tween:Start() end    -- Avvia o riprendi da pausa
function Tween:Restart() end  -- Riavvia da zero (progress = 0)
function Tween:Pause() end    -- Pausa, mantiene posizione
function Tween:Stop() end     -- Ferma, mantiene posizione (non attivo)
function Tween:Reset() end    -- Riporta a from, progress = 0 (non avvia)

--- State query
function Tween:IsActive() end
function Tween:IsPaused() end
function Tween:GetDirection() end
function Tween:GetCurrentLoop() end

--- Time
function Tween:GetTimeRemaining() end
function Tween:GetPeriod() end
function Tween:SetPeriod(period) end

--- Parameters (modificabili a runtime)
function Tween:GetFrom() end
function Tween:SetFrom(value) end
function Tween:GetTo() end
function Tween:SetTo(value) end
function Tween:SetEasing(easing) end
function Tween:SetEasingParams(params) end  -- Opzionale, per utenti avanzati
function Tween:SetLoopCount(count) end      -- Utile
function Tween:Reverse() end                -- Scambia from <-> to

--- Callbacks
function Tween:SetCallback(callbackType, func) end


LevelFuncs.Engine.Tween.UpdateAll = function()
    for _, t in pairs(LevelVars.Engine.Tween.tweens) do
        if t.active then
            
        end
    end
end

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.Tween.UpdateAll)

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_FREEZE, LevelFuncs.Engine.Tween.UpdateAll)

return Tween