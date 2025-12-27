
local Type = require("Engine.Type")
local LuaUtil = require("Engine.LuaUtil")

local Tween = {}
Tween.__index = Tween
LevelFuncs.Engine.Tween = {}

-- Storage
LevelVars.Engine.Tween = { tweens = {} }

Tween.Mode = LuaUtil.SetTableReadOnly({
    ONCE = 0,              -- from → to (stop)
    RESTART = 1,           -- from → to - from → to
    PING_PONG = 2,         -- from → to → from
})

Tween.Easing = LuaUtil.SetTableReadOnly({
    LERP = 1,
    SMOOTHSTEP = 2,
    SMOOTHERSTEP = 3,
    EASE_IN_OUT = 4,
    ELASTIC = 5
})

Tween.CallbackType = LuaUtil.SetTableReadOnly({
    ON_START = "onStart",
    ON_COMPLETE = "onComplete",
    ON_LOOP = "onLoop",
    ON_UPDATE = "onUpdate",
    ON_TO = "onTo",      -- Quando raggiunge to
    ON_FROM = "onFrom"   -- Quando raggiunge from
})

LevelVars.Engine.Tween.Interpolations = {
    LuaUtil.Lerp,
    LuaUtil.Smoothstep,
    LuaUtil.Smootherstep,
    LuaUtil.EaseInOut,
    LuaUtil.Elastic
}

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

    -- State management
    thisTween.active = parameters.autoStart and true or false
    thisTween.paused = false

    thisTween.interpolation = LevelVars.Engine.Tween.Interpolations[thisTween.easing]
    thisTween.interpolationDuration = LuaUtil.SecondsToFrames(thisTween.period)

    -- Interpolation state
    thisTween.shouldDeactivateNextFrame = false
    thisTween.elapsed = 0
    thisTween.progress = 0.0
    thisTween.value = thisTween.from
    thisTween.direction = 1
    thisTween.currentLoopIndex = 0
    thisTween.completed = false

    -- Callbacks
    thisTween.callbacks = {
        onStart = Type.IsLevelFunc(parameters.onStart) and parameters.onStart or nil,
        onComplete = Type.IsLevelFunc(parameters.onComplete) and parameters.onComplete or nil,
        onLoop = Type.IsLevelFunc(parameters.onLoop) and parameters.onLoop or nil,
        onUpdate = Type.IsLevelFunc(parameters.onUpdate) and parameters.onUpdate or nil,
        onTo = Type.IsLevelFunc(parameters.onTo) and parameters.onTo or nil,
        onFrom = Type.IsLevelFunc(parameters.onFrom) and parameters.onFrom or nil,
    }

    local self = { name = parameters.name }
    return setmetatable(self, Tween)
end

Tween.Delete = function (name)
    if not Type.IsString(name) then
        TEN.Util.PrintLog("Error in Tween.Delete(): invalid name", TEN.Util.LogLevel.ERROR)
        return nil
    end
    if LevelVars.Engine.Tween.tweens[name] then
        LevelVars.Engine.Tween.tweens[name] = nil
    end
end

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

Tween.IfExists = function(name)
    if not Type.IsString(name) then
        TEN.Util.PrintLog("Error in Tween.IfExists(): invalid name", TEN.Util.LogLevel.ERROR)
        return nil
    end
    return LevelVars.Engine.Tween.tweens[name] and true or false
end

--- Methods

--- Lifecycle (tutti separati, chiari)

-- Avvia o riprendi da pausa
function Tween:Start()
    LevelVars.Engine.Tween.tweens[self.name].active = true
    -- TODO: callback ON_START
end

-- Riavvia da zero (progress = 0)
function Tween:Restart()
    
end

-- Pausa, mantiene posizione
function Tween:Pause()
    LevelVars.Engine.Tween.tweens[self.name].paused = true
end

-- Ferma, mantiene posizione (non attivo)
function Tween:Stop()
    LevelVars.Engine.Tween.tweens[self.name].active = false
end
function Tween:Reset() end    -- Riporta a from, progress = 0 (non avvia)

--- State query
function Tween:IsActive()
    return LevelVars.Engine.Tween.tweens[self.name].active
end
function Tween:IsPaused()
    return LevelVars.Engine.Tween.tweens[self.name].paused
end
function Tween:GetDirection() end
function Tween:GetCurrentLoop() end

--- Value/Progress

-- Valore corrente interpolato
function Tween:GetValue()
    return LevelVars.Engine.Tween.tweens[self.name].value
end        
function Tween:GetProgress() end     -- 0.0 - 1.0
function Tween:SetProgress(t) end    -- Salta a posizione (avanzato)

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
    for name, t in pairs(LevelVars.Engine.Tween.tweens) do
        -- Prima: gestisci deactivazione ritardata
        if t.shouldDeactivateNextFrame then
            t.active = false
            t.shouldDeactivateNextFrame = false
        end
        
        if t.active and not t.paused and not t.completed then
            -- TODO: callback ON_UPDATE (ogni frame)
            if t.callbacks.onUpdate then
                t.callbacks.onUpdate(t.value, t.progress)
            end
            
            -- Calcola progress PRIMA di incrementare (per mostrare valore iniziale)
            t.progress = t.elapsed / t.interpolationDuration
            
            if t.progress > 1.0 then
                t.progress = 1.0
            end
            
            local effectiveProgress = t.direction == 1 and t.progress or (1.0 - t.progress)
            t.value = t.interpolation(t.from, t.to, effectiveProgress, t.easingParams)
            
            -- Incrementa DOPO aver calcolato il valore
            t.elapsed = t.elapsed + 1
            
            if t.progress >= 1.0 then
                -- Forza valore finale esatto (per sicurezza)
                t.value = t.direction == 1 and t.to or t.from
                
                if t.mode == Tween.Mode.ONCE then
                    t.shouldDeactivateNextFrame = true
                    t.completed = true
                    -- TODO: callback ON_TO
                    -- TODO: callback ON_COMPLETE
                
                elseif t.mode == Tween.Mode.RESTART then
                    t.elapsed = 0
                    t.progress = 0.0
                    -- Forza valore iniziale per prossimo ciclo
                    t.value = t.from
                    
                    if t.loopCount then
                        t.currentLoopIndex = t.currentLoopIndex + 1
                        if t.currentLoopIndex >= t.loopCount then
                            t.shouldDeactivateNextFrame = true
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
                    t.elapsed = 0
                    t.progress = 0.0
                    t.direction = -t.direction
                    
                    -- TODO: callback ON_TO (se direction=-1) o ON_FROM (se direction=1)
                    
                    if t.direction == 1 then
                        if t.loopCount then
                            t.currentLoopIndex = t.currentLoopIndex + 1
                            if t.currentLoopIndex >= t.loopCount then
                                t.shouldDeactivateNextFrame = true
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

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.Tween.UpdateAll)

TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_FREEZE, LevelFuncs.Engine.Tween.UpdateAll)

return Tween