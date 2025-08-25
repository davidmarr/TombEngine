local Interpolate = {}

-- Internal motion progress tracker
LevelVars.Engine.InterpolateProgress = {}

-- Type of interpolation to perform
Interpolate.Type = {
    LINEAR   = 1,
    VEC2     = 2,
    VEC3     = 3,
    ROTATION = 4,
    COLOR    = 5
}

-- Perform single interpolation
function Interpolate.Calculate(name, dataType, oldValue, newValue, time, smooth)
    
    if LevelVars.Engine.InterpolateProgress[name] == nil then
        LevelVars.Engine.InterpolateProgress[name] = 0
    end

    local interval = 1 / (time * 30)
    LevelVars.Engine.InterpolateProgress[name] = math.min(LevelVars.Engine.InterpolateProgress[name] + interval, 1)

    local factor = smooth and LevelFuncs.Engine.Node.Smoothstep(LevelVars.Engine.InterpolateProgress[name]) or LevelVars.Engine.InterpolateProgress[name]

    local function lerp(a, b)
        return LevelFuncs.Engine.Node.Lerp(a, b, factor)
    end

    if dataType == Interpolate.Type.LINEAR then
        return {output = lerp(oldValue, newValue), progress = LevelVars.Engine.InterpolateProgress[name]}

    elseif dataType == Interpolate.Type.VEC2 then
        return {
            output = Vec2(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y)),
            progress = LevelVars.Engine.InterpolateProgress[name]
        }

    elseif dataType == Interpolate.Type.VEC3 then
        return {
            output = Vec3(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y), lerp(oldValue.z, newValue.z)),
            progress = LevelVars.Engine.InterpolateProgress[name]
        }

    elseif dataType == Interpolate.Type.ROTATION then
        return {
            output = Rotation(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y), lerp(oldValue.z, newValue.z)),
            progress = LevelVars.Engine.InterpolateProgress[name]
        }

    elseif dataType == Interpolate.Type.COLOR then
        return {
            output = Color(lerp(oldValue.r, newValue.r), lerp(oldValue.g, newValue.g), lerp(oldValue.b, newValue.b), lerp(oldValue.a, newValue.a)),
            progress = LevelVars.Engine.InterpolateProgress[name]
        }
    end
end

-- Clear motion progress by name
function Interpolate.Clear(name)
    if LevelVars.Engine.InterpolateProgress[name] and LevelVars.Engine.InterpolateProgress[name] >= 1 then
        LevelVars.Engine.InterpolateProgress[name] = nil
    end
end

-- Clear progress for all
function Interpolate.ClearAll()
    LevelVars.Engine.InterpolateProgress = {}
end

function Interpolate.GetProgress(motionName)

    return LevelVars.Engine.InterpolateProgress[motionName] or 0
    
end

return Interpolate