local Interpolate = {}

-- Internal motion progress tracker
local motionProgress = {}

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
    
    if motionProgress[name] == nil then
        motionProgress[name] = 0
    end

    local interval = 1 / (time * 30)
    motionProgress[name] = math.min(motionProgress[name] + interval, 1)

    local factor = smooth and LevelFuncs.Engine.Node.Smoothstep(motionProgress[name]) or motionProgress[name]

    local function lerp(a, b)
        return LevelFuncs.Engine.Node.Lerp(a, b, factor)
    end

    if dataType == Interpolate.Type.LINEAR then
        return {output = lerp(oldValue, newValue), progress = motionProgress[name]}

    elseif dataType == Interpolate.Type.VEC2 then
        return {
            output = Vec2(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y)),
            progress = motionProgress[name]
        }

    elseif dataType == Interpolate.Type.VEC3 then
        return {
            output = Vec3(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y), lerp(oldValue.z, newValue.z)),
            progress = motionProgress[name]
        }

    elseif dataType == Interpolate.Type.ROTATION then
        return {
            output = Rotation(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y), lerp(oldValue.z, newValue.z)),
            progress = motionProgress[name]
        }

    elseif dataType == Interpolate.Type.COLOR then
        return {
            output = Color(lerp(oldValue.r, newValue.r), lerp(oldValue.g, newValue.g), lerp(oldValue.b, newValue.b), lerp(oldValue.a, newValue.a)),
            progress = motionProgress[name]
        }
    end
end

-- Clear motion progress by name
function Interpolate.Clear(name)
    if motionProgress[name] and motionProgress[name] >= 1 then
        motionProgress[name] = nil
    end
end

-- Clear progress for all
function Interpolate.ClearAll()
    motionProgress = {}
end

function Interpolate.GetProgress(motionName)

    return motionProgress[motionName] or 0
    
end

return Interpolate