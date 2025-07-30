local Motion = {}

local Ring = require("Engine.CustomInventory.RingFunctions")

local RING_RADIUS = -512

-- Internal motion progress tracker
local motionProgress = {}

-- Expose motion type enum
Motion.Type = {
    LINEAR   = 1,
    VEC2     = 2,
    VEC3     = 3,
    ROTATION = 4,
    COLOR    = 5
}

-- Perform single motion
function Motion.PerformMotion(name, dataType, oldValue, newValue, time, smooth)
    if motionProgress[name] == nil then
        motionProgress[name] = 0
    end

    local interval = 1 / (time * 30)
    motionProgress[name] = math.min(motionProgress[name] + interval, 1)

    local factor = smooth and LevelFuncs.Engine.Node.Smoothstep(motionProgress[name]) or motionProgress[name]

    local function lerp(a, b)
        return LevelFuncs.Engine.Node.Lerp(a, b, factor)
    end

    if dataType == Motion.Type.LINEAR then
        return {output = lerp(oldValue, newValue), progress = motionProgress[name]}

    elseif dataType == Motion.Type.VEC2 then
        return {
            output = Vec2(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y)),
            progress = motionProgress[name]
        }

    elseif dataType == Motion.Type.VEC3 then
        return {
            output = Vec3(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y), lerp(oldValue.z, newValue.z)),
            progress = motionProgress[name]
        }

    elseif dataType == Motion.Type.ROTATION then
        return {
            output = Rotation(lerp(oldValue.x, newValue.x), lerp(oldValue.y, newValue.y), lerp(oldValue.z, newValue.z)),
            progress = motionProgress[name]
        }

    elseif dataType == Motion.Type.COLOR then
        return {
            output = Color(lerp(oldValue.r, newValue.r), lerp(oldValue.g, newValue.g), lerp(oldValue.b, newValue.b), lerp(oldValue.a, newValue.a)),
            progress = motionProgress[name]
        }
    end
end

-- Clear motion progress by name
function Motion.ClearMotionProgress(name)
    if motionProgress[name] and motionProgress[name] >= 1 then
        motionProgress[name] = nil
    end
end

-- Clear progress for a batch
function Motion.ClearBatchMotionProgress(prefix, motionTable)
    for _, motion in ipairs(motionTable) do
        local id = prefix .. motion.key
        if motionProgress[id] and motionProgress[id] >= 1 then
            motionProgress[id] = nil
        end
    end
end

-- Clear progress for all
function Motion.ClearAllProgress()
    motionProgress = {}
end

function Motion.GetProgress(motionName)

    return motionProgress[motionName] or 0
    
end

-- Perform a batch of motions and apply their effects
function Motion.PerformBatchMotion(prefix, motionTable, time, clearProgress, ringName, item, reverse)
    local interpolated = {}
    local allComplete = true
    local omitSelectedItem = item and true or false

    for _, motion in ipairs(motionTable) do
        local id = prefix .. motion.key
        local interp = {output = motion.start, progress = 1}

        if motion.start ~= motion.finish then
            local startVal = reverse and motion.finish or motion.start
            local endVal = reverse and motion.start or motion.finish
            interp = Motion.PerformMotion(id, motion.type, startVal, endVal, time, true)
        end

        interpolated[motion.key] = interp
        if interp.progress < 1 then
            allComplete = false
        end
    end

    if interpolated.ringCenter or interpolated.ringRadius or interpolated.ringAngle then
        local center = interpolated.ringCenter and interpolated.ringCenter.output or inventory.ringPosition[ringName]
        local radius = interpolated.ringRadius and interpolated.ringRadius.output or RING_RADIUS
        local angle = interpolated.ringAngle and interpolated.ringAngle.output or 0
        Ring.TranslateRing(ringName, center, radius, angle)
    end

    if interpolated.ringFade then
        Ring.FadeRing(ringName, interpolated.ringFade.output, omitSelectedItem)
    end

    if interpolated.camera then TEN.DrawItem.SetInvCameraPosition(interpolated.camera.output) end
    if interpolated.target then TEN.DrawItem.SetInvTargetPosition(interpolated.target.output) end
    if interpolated.itemColor then TEN.DrawItem.SetItemColor(item, interpolated.itemColor.output) end
    if interpolated.itemPosition then TEN.DrawItem.SetItemPosition(item, interpolated.itemPosition.output) end
    if interpolated.itemScale then TEN.DrawItem.SetItemScale(item, interpolated.itemScale.output) end
    if interpolated.itemRotation then TEN.DrawItem.SetItemRotation(item, interpolated.itemRotation.output) end

    if allComplete and clearProgress then
        for _, motion in ipairs(motionTable) do
            Motion.ClearMotionProgress(prefix .. motion.key)
        end
        return true
    end
end

return Motion