--RING INVENTORY BY TRAINWRECK

--CONSTANTS
local NO_VALUE = -1
local HEALTH_MAX = 1000
local ROTATION = 4 --rotation speed of Inventory Item
local CAMERA_START = Vec3(0,-2500, 200)
local CAMERA_END = Vec3(0,-36,-1151)
local TARGET_START = Vec3(0,0, 1000)
local TARGET_END = Vec3(0,110,0)
local INVENTORY_ANIM_TIME = 0.5
local RING_CENTER = Vec3(0,200,1024)
local RING_RADIUS = -512
local PROGRESS_COMPLETE = 1

--External table of all pickup data
local PICKUP_DATA = require("Levels.InventoryConstants")

--Inventory types
local INVENTORY_MODE = 
{
    INVENTORY = 1,
    EXAMINE = 2,
    STATISTICS = 3,
    RING_OPENING = 4,
    RING_CLOSING = 5,
    STATISTICS_OPEN = 6,
    STATISTICS_CLOSE = 7,
    EXAMINE_OPEN = 8,
    EXAMINE_CLOSE = 9
}

--Structure for SoundMap
local SOUND_MAP =
{
    PLAYER_NO = 2,
    MENU_ROTATE = 108,
    MENU_SELECT = 109,
    MENU_CHOOSE = 111,
    MENU_COMBINE = 114,
    TR4_MENU_MEDI = 116,
    INVENTORY_OPEN = 195,
    INVENTORY_CLOSE = 196
}

local COLOR_MAP =
{
    NORMAL_FONT = Color(255,255,255,255),
    HEADER_FONT = Color(216,117,49,255),
    BLACK = Color(0,0,0,255),
    BACKGROUND = Color(128,128,128,255),
    INVENTORY_AMBIENT = Color(255,0,0),
    ITEM_COLOR = Color(64,64,64,0)
}

--Structure for weapon data. TEN Weapon type constant, underwater equip allowed, equip while crawling allowed
local WEAPON_SET = {
    [TEN.Objects.ObjID.PISTOLS_ITEM] = {slot = TEN.Objects.WeaponType.PISTOLS, underwater = false, crawl = true}, 
    [TEN.Objects.ObjID.UZI_ITEM] = {slot = TEN.Objects.WeaponType.UZIS, underwater = false, crawl = true}, 
    [TEN.Objects.ObjID.SHOTGUN_ITEM] = {slot = TEN.Objects.WeaponType.SHOTGUN, underwater = false, crawl = false},
    [TEN.Objects.ObjID.REVOLVER_ITEM] = {slot = TEN.Objects.WeaponType.REVOLVER, underwater = false, crawl = true},
    [TEN.Objects.ObjID.CROSSBOW_ITEM] = {slot = TEN.Objects.WeaponType.CROSSBOW, underwater = false, crawl = false},
    [TEN.Objects.ObjID.HK_ITEM] = {slot = TEN.Objects.WeaponType.HK, underwater = false, crawl = false},
    [TEN.Objects.ObjID.GRENADE_GUN_ITEM] = {slot = TEN.Objects.WeaponType.GRENADE_LAUNCHER, underwater = false, crawl = false},
    [TEN.Objects.ObjID.HARPOON_ITEM] = {slot = TEN.Objects.WeaponType.HARPOON_GUN, underwater = true, crawl = false},
    [TEN.Objects.ObjID.ROCKET_LAUNCHER_ITEM] = {slot = TEN.Objects.WeaponType.ROCKET_LAUNCHER, underwater = false, crawl = false},
    [TEN.Objects.ObjID.FLARE_INV_ITEM] = {slot = TEN.Objects.WeaponType.FLARE, underwater = true, crawl = true}
}

local HEALTH_SET = {
    [TEN.Objects.ObjID.BIGMEDI_ITEM] = HEALTH_MAX,
    [TEN.Objects.ObjID.SMALLMEDI_ITEM] = HEALTH_MAX / 2
}

local MOTION_TYPE = {
    LINEAR = 1,
    VEC2 = 2,
    VEC3 = 3,
    ROTATION = 4,
    COLOR = 5 
}

local ammoSet = {
    [TEN.Objects.ObjID.PISTOLS_ITEM] = true,
    [TEN.Objects.ObjID.UZI_ITEM] = true,
    [TEN.Objects.ObjID.SHOTGUN_ITEM] = true,
    [TEN.Objects.ObjID.REVOLVER_ITEM] = true,
    [TEN.Objects.ObjID.CROSSBOW_ITEM] = true,
    [TEN.Objects.ObjID.HK_ITEM] = true,
    [TEN.Objects.ObjID.GRENADE_GUN_ITEM] = true,
    [TEN.Objects.ObjID.HARPOON_ITEM] = true,
    [TEN.Objects.ObjID.ROCKET_LAUNCHER_ITEM] = true
}

--variables
local timeInMenu = 0
local inventoryDelay = 0 --count of actual frames before inventory is opened. Used for setting the grayscale tint.
local inventoryMode = INVENTORY_MODE.RING_OPENING
local currentAngle = 0
local targetAngle = 0
local rotationInProgress = false

local useBinoculars = false

local motionProgress = {}

local examineOrient = Rotation(0,0,0)
local examineScaler = 1.2
local examineShowString = true

LevelFuncs.Engine.CustomInventory = {}

--functions
local percentPos = function(x, y)
    return TEN.Vec2(TEN.Util.PercentToScreen(x, y))
end

local calculateCompassAngle = function()

    local needleOrient = Rotation(0, -Lara:GetRotation().y, 0)

	local wibble =  math.sin((timeInMenu % 0x40) / 0x3F * (2 * math.pi))
    needleOrient.y = needleOrient.y + wibble

    return needleOrient
end

local calculateStopWatchRotation = function()

    local angles = {}

    local level_time = Flow.GetStatistics().timeTaken

    angles.hour_hand_angle = Rotation(0,0,-(level_time.h / 12) * 360)
    angles.minute_hand_angle = Rotation(0,0,-(level_time.m / 60) * 360)
    angles.second_hand_angle = Rotation(0,0,-(level_time.s / 60) * 360)

    return angles

end

local SetRotationInventoryItems = function()

    local angles = calculateStopWatchRotation()

    --Stopwatch hands
    TEN.DrawItem.SetMeshRotation(TEN.Objects.ObjID.STOPWATCH_ITEM, 4, angles.hour_hand_angle)
    TEN.DrawItem.SetMeshRotation(TEN.Objects.ObjID.STOPWATCH_ITEM, 5, angles.minute_hand_angle)
    TEN.DrawItem.SetMeshRotation(TEN.Objects.ObjID.STOPWATCH_ITEM, 6, angles.second_hand_angle)

    --Compass Needle
    TEN.DrawItem.SetMeshRotation(TEN.Objects.ObjID.COMPASS_ITEM, 1, calculateCompassAngle())

end

local combine = function(item1, item2)
	
    for _, combo in ipairs(PICKUP_DATA.combineTable) do
		
        local a, b, result = combo[1], combo[2], combo[3]

		if (item1 == a and item2 == b) or (item1 == b and item2 == a) then

            -- Check if both items are actually present
            local count1 = TEN.Inventory.GetItemCount(item1)
            local count2 = TEN.Inventory.GetItemCount(item2)

            if count1 == 0 or count2 == 0 then
                return false
            end

            -- Remove the original items
            TEN.Inventory.TakeItem(item1, 1)
            TEN.Inventory.TakeItem(item2, 1)

            -- Add the new combined item
            TEN.Inventory.GiveItem(result, 1)
			return true
		end
	end

	-- No valid combination found
	return false
end


LevelFuncs.OnStart = function()

    local stats = Flow.GetStatistics()
    stats.timeTaken = Time({9,40,36}) 
    Flow.SetStatistics(stats)

    LevelFuncs.Engine.CustomInventory.IntializeInventory()

end

LevelFuncs.OnFreeze = function()

    --LevelFuncs.DrawCursor()
    --LevelFuncs.AdjustCamera()
end

--required for positioning the inventory
local selectedIndex = 1
local vector
LevelFuncs.AdjustCamera = function()

    local entrySprite2 = TEN.DisplaySprite(TEN.Objects.ObjID.DIARY_ENTRY_SPRITES, 0, TEN.Vec2(50, 50), 0, TEN.Vec2(100,100), COLOR_MAP.NORMAL_FONT)
    entrySprite2:Draw(1, View.AlignMode.CENTER, View.ScaleMode.FIT, TEN.Effects.BlendID.OPAQUE)

    local items = {
        "Camera",
        "Target",
        "FOV",
        "Label"
    }

    if IsKeyHit(TEN.Input.ActionID.TAB) then
        selectedIndex  = (selectedIndex % #items) + 1
    end

    local selectedItem = items[selectedIndex]

    local myText = DisplayString(selectedItem, percentPos(10, 10), 0.5, Color.new(64,250,60))
	ShowString(myText,1/30)

    if selectedItem == "Camera" then
        vector = TEN.DrawItem.GetInvCameraPosition()
    elseif selectedItem == "Target" then
        vector = TEN.DrawItem.GetInvTargetPosition()
    elseif selectedItem == "FOV" then
        vector = Vec3(0,View.GetFOV(),0)
    end

    if IsKeyHeld(TEN.Input.ActionID.LEFT) then
            vector.x = vector.x - 2
    elseif IsKeyHeld(TEN.Input.ActionID.RIGHT) then
            vector.x = vector.x + 2
    elseif IsKeyHeld(TEN.Input.ActionID.FORWARD) then
            vector.z = vector.z + 2
    elseif IsKeyHeld(TEN.Input.ActionID.BACK) then
            vector.z = vector.z - 2
    elseif IsKeyHeld(TEN.Input.ActionID.STEP_LEFT) then
            vector.y = vector.y - 2
    elseif IsKeyHeld(TEN.Input.ActionID.STEP_RIGHT) then
            vector.y = vector.y + 2
    elseif IsKeyHit(TEN.Input.ActionID.R) then

        if selectedItem == "Camera" then
            vector = Vec3(0,-512,512)
        elseif selectedItem == "Target" then
            vector = Vec3(0,0,512)
        elseif selectedItem == "FOV" then
            vector = Vec3(0,80,0)
        elseif selectedItem == "Label" then
            vector = Vec3(50,0.5,90)
        end
    end

    local myText2 = DisplayString(tostring(vector), percentPos(15, 10), 0.5, Color.new(64,250,60))
	ShowString(myText2,1/30)


    if selectedItem == "Camera" then
        TEN.DrawItem.SetInvCameraPosition(vector)
    elseif selectedItem == "Target" then
        TEN.DrawItem.SetInvTargetPosition(vector)
    elseif selectedItem == "FOV" then
        View.SetFOV(vector.y)
    end
end

local guiIsPulsed = function(actionID)

    local DELAY		 = 120
	local INITIAL_DELAY = 30

	--Action already held prior to entering menu; lock input.
	if (GetActionTimeActive(actionID) >= timeInMenu) then
	    return false
    end
	--Pulse only directional inputs.
	local oppositeAction = nil

    if actionID == TEN.Input.ActionID.FORWARD then
        oppositeAction = TEN.Input.ActionID.BACK
    elseif actionID == TEN.Input.ActionID.BACK then
        oppositeAction = TEN.Input.ActionID.FORWARD
    elseif actionID == TEN.Input.ActionID.LEFT then
        oppositeAction = TEN.Input.ActionID.RIGHT
    elseif actionID == TEN.Input.ActionID.RIGHT then
        oppositeAction = TEN.Input.ActionID.LEFT
    end

	--Opposite action held; lock input.
    local isActionLocked = false
	if oppositeAction ~= nil then
		isActionLocked = IsKeyHeld(oppositeAction)
	end

	if isActionLocked then
		return false
	end

	return IsKeyPulsed(actionID, DELAY, INITIAL_DELAY)
end

local Input = function(mode)

    if mode == INVENTORY_MODE.INVENTORY then

        local inventoryTable = LevelVars.Engine.CustomInventory.Inventory

        if not rotationInProgress then
            if guiIsPulsed(TEN.Input.ActionID.LEFT) then
                LevelVars.Engine.CustomInventory.SelectedItem = ((LevelVars.Engine.CustomInventory.SelectedItem - 2) % #inventoryTable) + 1
                targetAngle = currentAngle + LevelVars.Engine.CustomInventory.InventorySlice
                rotationInProgress = true
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            elseif guiIsPulsed(TEN.Input.ActionID.RIGHT) then
                LevelVars.Engine.CustomInventory.SelectedItem = (LevelVars.Engine.CustomInventory.SelectedItem % #inventoryTable) + 1
                targetAngle = currentAngle - LevelVars.Engine.CustomInventory.InventorySlice
                rotationInProgress = true
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            elseif guiIsPulsed(TEN.Input.ActionID.ACTION) then
                local item = LevelVars.Engine.CustomInventory.Inventory[LevelVars.Engine.CustomInventory.SelectedItem].item
                TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
                LevelFuncs.Engine.CustomInventory.UseItem(item)
                LevelFuncs.Engine.CustomInventory.ExitInventory()
            elseif guiIsPulsed(TEN.Input.ActionID.INVENTORY) and LevelVars.Engine.CustomInventory.InventoryOpenFreeze then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_SELECT)
                LevelVars.Engine.CustomInventory.RingClosing = true
                inventoryMode = INVENTORY_MODE.RING_CLOSING
                return
            end
        end
    elseif mode == INVENTORY_MODE.STATISTICS then

        if guiIsPulsed(TEN.Input.ActionID.INVENTORY) then
            mode = INVENTORY_MODE.STATISTICS_CLOSE
        end

    elseif mode == INVENTORY_MODE.EXAMINE then
         -- Static variables
        local MULTIPLIER = 1/30

        -- Handle rotation input
        if guiIsPulsed(TEN.Input.ActionID.FORWARD) then
            examineOrient.x = examineOrient.x + 3.0 / MULTIPLIER
        elseif guiIsPulsed(TEN.Input.ActionID.BACK) then
            examineOrient.x = examineOrient.x - (3.0 / MULTIPLIER)
        elseif guiIsPulsed(TEN.Input.ActionID.LEFT) then
            examineOrient.y = examineOrient.y + (3.0 / MULTIPLIER)
        elseif guiIsPulsed(TEN.Input.ActionID.RIGHT) then
            examineOrient.y = examineOrient.y - (3.0 / MULTIPLIER)
        elseif guiIsPulsed(TEN.Input.ActionID.SPRINT) then
            examineScaler = examineScaler + (0.03 / MULTIPLIER)
        elseif guiIsPulsed(TEN.Input.ActionID.CROUCH) then
            examineScaler = examineScaler - (0.03 / MULTIPLIER)
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) then
            examineShowString = not examineShowString
        elseif guiIsPulsed(TEN.Input.ActionID.INVENTORY) then
            examineOrient = Rotation(0,0,0)
            examineScaler = 1.2
            mode = INVENTORY_MODE.EXAMINE_CLOSE
        end
    else
        return
    end
end

LevelFuncs.Engine.CustomInventory.StartInventory = function()

    if useBinoculars then
        TEN.View.UseBinoculars()
        useBinoculars = false
    end

    local playerHp = Lara:GetHP() > 0
    local isNotUsingBinoculars = TEN.View.GetCameraType() ~= CameraType.BINOCULARS

    if (IsKeyHit(TEN.Input.ActionID.INVENTORY) or TEN.DrawItem.GetOpenInventory() ~= NO_VALUE) and not LevelVars.Engine.CustomInventory.InventoryOpen and playerHp and isNotUsingBinoculars  then
        LevelVars.Engine.CustomInventory.InventoryOpen = true
        inventoryDelay = 0
    end

    if LevelVars.Engine.CustomInventory.InventoryOpen == true then
        inventoryDelay = inventoryDelay + 1
        SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        SetPostProcessStrength(1)
        SetPostProcessTint(COLOR_MAP.BACKGROUND)

        if inventoryDelay >= 2 then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_SELECT)
            TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.CustomInventory.UpdateInventory)
            Flow.SetFreezeMode(Flow.FreezeMode.SPECTATOR) -- SHOULD RUN IN FULL MODE
        end
    end

    
    if LevelVars.Engine.CustomInventory.InventoryClosed then
        LevelVars.Engine.CustomInventory.InventoryClosed = false
        TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.CustomInventory.UpdateInventory)
    end

end

LevelFuncs.Engine.CustomInventory.ExitInventory = function()

    LevelVars.Engine.CustomInventory.InventoryOpenFreeze = false
    TEN.DrawItem.ClearAllItems()
    TEN.DrawItem.SetOpenInventory(NO_VALUE)
    motionProgress = {}
    View.SetFOV(80)
    Flow.SetFreezeMode(Flow.FreezeMode.NONE)
    LevelVars.Engine.CustomInventory.InventoryClosed = true
    inventoryMode = INVENTORY_MODE.RING_OPENING
    TEN.DrawItem.SetInvCameraPosition(CAMERA_START)
    TEN.DrawItem.SetInvTargetPosition(TARGET_START)
    timeInMenu = 0

end

LevelFuncs.Engine.CustomInventory.UpdateInventory = function()

    timeInMenu = timeInMenu + 1

    if LevelVars.Engine.CustomInventory.InventoryOpen then
        View.SetFOV(80)
        SetPostProcessMode(View.PostProcessMode.NONE)
        LevelFuncs.Engine.CustomInventory.ConstructObjectList()
    else
        LevelFuncs.Engine.CustomInventory.DrawInventoryText()
        Input(inventoryMode)
        LevelFuncs.Engine.CustomInventory.DrawInventory(inventoryMode)

        --Set rotation of InventoryItems
        SetRotationInventoryItems()

    end
end


LevelFuncs.DrawCursor = function()

    local pos = GetMouseDisplayPosition()
	
	local myTextString = "X: " .. pos.x.." Y: "..pos.y
	local myText = DisplayString(myTextString, 10, 10, Color.new(64,250,60))
	ShowString(myText,1/30)

	local entrySprite = TEN.DisplaySprite(TEN.Objects.ObjID.SKY_GRAPHICS, 0, TEN.Vec2(pos.x,pos.y), 0, TEN.Vec2(5,5), TEN.Color(255,128,255))
    entrySprite:Draw(8, View.AlignMode.TOP_LEFT, View.ScaleMode.FIT, TEN.Effects.BlendID.OPAQUE)

end


LevelFuncs.Engine.CustomInventory.IntializeInventory = function()

    LevelVars.Engine.CustomInventory = {}
    LevelVars.Engine.CustomInventory.SelectedItem = 1 -- index of currently selected item
    LevelVars.Engine.CustomInventory.Inventory = {ring={}}
    LevelVars.Engine.CustomInventory.InventoryOpen = false
    LevelVars.Engine.CustomInventory.RingOpening = true
    LevelVars.Engine.CustomInventory.RingClosing = false
    LevelVars.Engine.CustomInventory.InventoryOpenFreeze = false
    LevelVars.Engine.CustomInventory.InventoryClosed = false

    TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.CustomInventory.StartInventory)

    TEN.DrawItem.SetInvCameraPosition(CAMERA_START)
    TEN.DrawItem.SetInvTargetPosition(TARGET_START)
    TEN.DrawItem.SetAmbientLight(COLOR_MAP.INVENTORY_AMBIENT)

    TEN.DrawItem.SetInventoryOverride(true)

end

LevelFuncs.Engine.CustomInventory.ConstructObjectList = function()

    currentAngle = 0
    targetAngle = 0
    LevelVars.Engine.CustomInventory.SelectedItem = 1
    LevelVars.Engine.CustomInventory.RingOpening = true

    local items  = PICKUP_DATA.constants
    local gameflowOverrides = LevelFuncs.Engine.CustomInventory.ReadGameflow() or {}
    
    local inventory = {}

    for _, itemID in ipairs(items) do

        local objectID = PICKUP_DATA.GetInventoryData(itemID)
        local count = TEN.Inventory.GetItemCount(objectID.itemID)
        local yOffset = PICKUP_DATA.GetItemData(objectID.itemID, "YOFFSET")
        local scale = PICKUP_DATA.GetItemData(objectID.itemID, "SCALE")
        local rotation = PICKUP_DATA.GetItemData(objectID.itemID, "ROTATION")
        local flags = PICKUP_DATA.GetItemData(objectID.itemID, "FLAGS")
        local name = PICKUP_DATA.GetItemData(objectID.itemID, "DISPLAY_NAME")
        local joint = PICKUP_DATA.GetItemData(objectID.itemID, "JOINT")
        local orientation = PICKUP_DATA.GetItemData(objectID.itemID, "SCALE")
        
        local override = gameflowOverrides[objectID.itemID] or {}
        if override then
            if override.yOffset     ~= nil then yOffset     = override.yOffset end
            if override.scale       ~= nil then scale       = override.scale end
            if override.rotation    ~= nil then rotation    = override.rotation end
            if override.flags       ~= nil then flags       = override.flags end
            if override.name        ~= nil then name        = override.name end
            if override.joint       ~= nil then joint       = override.joint end
            if override.orientation ~= nil then orientation = override.orientation end
        end

        if count ~= 0 then
            table.insert(inventory, { 
                item = objectID.itemID,
                count = count,
                yOffset = yOffset,
                scale = scale,
                rotation = rotation,
                flags = flags,
                name = name,
                joint = joint,
                orientation = orientation })
        end
    end

    LevelVars.Engine.CustomInventory.Inventory = inventory

    for i, item in ipairs(inventory) do
        TEN.DrawItem.AddItem(item.item, RING_CENTER, item.rotation, item.scale, item.joint)
        TEN.DrawItem.SetItemColor(item.item, COLOR_MAP.ITEM_COLOR)
    end

    LevelVars.Engine.CustomInventory.InventorySlice = (360 / #inventory)
    LevelVars.Engine.CustomInventory.InventoryOpen = false
end

local TranslateRing = function(ring, center, radius, rotationOffset)

    local itemCount = #ring
    
    for i = 1, itemCount do
        local currentItem = ring[i].item 

        local angleDeg = (360 / itemCount) * (i - 1) +  rotationOffset
       
        local position = center:Translate(Rotation(0,angleDeg,0),radius)

        local itemRotation  = TEN.DrawItem.GetItemRotation(currentItem)

        TEN.DrawItem.SetItemPosition(currentItem, position)
        TEN.DrawItem.SetItemRotation(currentItem, Rotation(itemRotation.x, angleDeg, itemRotation.z))
    end

end

local FadeRing = function(ring, fadeValue, omitSelectedItem)
    
    local itemCount = #ring
    local selectedItem = omitSelectedItem and LevelVars.Engine.CustomInventory.Inventory[LevelVars.Engine.CustomInventory.SelectedItem].item

    for i = 1, itemCount do
        local currentItem = ring[i].item 

        if omitSelectedItem and selectedItem == currentItem then
            goto continue
        end

        local itemColor = TEN.DrawItem.GetItemColor(currentItem)
        TEN.DrawItem.SetItemColor(currentItem, Color(itemColor.r, itemColor.g, itemColor.b, fadeValue))

        ::continue::
    end
end

local RotateItem = function(item)
    local itemRotation  = TEN.DrawItem.GetItemRotation(item)
    TEN.DrawItem.SetItemRotation(item, Rotation(itemRotation.x, (itemRotation.y + ROTATION) % 360, itemRotation.z))
end

local PerformMotion = function(name, dataType, oldValue, newValue, time, smooth)

    if motionProgress[name] == nil then
        motionProgress[name] = 0
    end

    local interval = 1 / (time * 30)
    motionProgress[name] = math.min(motionProgress[name] + interval, 1)
	local factor = smooth and LevelFuncs.Engine.Node.Smoothstep(motionProgress[name]) or motionProgress[name]
	
	local newValue1
	local newValue2
	local newValue3
	local newValue4
	
	if (dataType == MOTION_TYPE.LINEAR) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue, newValue, factor)
		return {output = newValue1, progress = motionProgress[name]}
	elseif (dataType == MOTION_TYPE.VEC2) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue.x, newValue.x, factor)
		newValue2 = LevelFuncs.Engine.Node.Lerp(oldValue.y, newValue.y, factor)
		return {output = Vec2(newValue1, newValue2), progress = motionProgress[name]}
    elseif (dataType == MOTION_TYPE.VEC3) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue.x, newValue.x, factor)
		newValue2 = LevelFuncs.Engine.Node.Lerp(oldValue.y, newValue.y, factor)
	    newValue3 = LevelFuncs.Engine.Node.Lerp(oldValue.z, newValue.z, factor)
		return {output = Vec3(newValue1, newValue2, newValue3), progress = motionProgress[name]}
    elseif (dataType == MOTION_TYPE.ROTATION) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue.x, newValue.x, factor)
		newValue2 = LevelFuncs.Engine.Node.Lerp(oldValue.y, newValue.y, factor)
	    newValue3 = LevelFuncs.Engine.Node.Lerp(oldValue.z, newValue.z, factor)
		return {output = Rotation(newValue1, newValue2, newValue3), progress = motionProgress[name]}
    elseif (dataType == MOTION_TYPE.COLOR) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue.r, newValue.r, factor)
		newValue2 = LevelFuncs.Engine.Node.Lerp(oldValue.g, newValue.g, factor)
	    newValue3 = LevelFuncs.Engine.Node.Lerp(oldValue.b, newValue.b, factor)
	    newValue4 = LevelFuncs.Engine.Node.Lerp(oldValue.a, newValue.a, factor)
		return {output = Color(newValue1, newValue2, newValue3, newValue4), progress = motionProgress[name]}
	end
end

local ClearMotionProgress = function(name)
    if (motionProgress[name] >= 1) then
        motionProgress[name] = nil
    end
end

local AnimateInventory = function(mode)

    local inventoryTable = LevelVars.Engine.CustomInventory.Inventory

    if mode == INVENTORY_MODE.RING_OPENING then
        local radiusInterpolate = PerformMotion("RingOpening1", MOTION_TYPE.LINEAR, 0, RING_RADIUS, INVENTORY_ANIM_TIME, true)
        local angleInterpolate = PerformMotion("RingOpening2", MOTION_TYPE.LINEAR, -360, 0, INVENTORY_ANIM_TIME, true)
        local cameraInterpolate = PerformMotion("RingOpening3", MOTION_TYPE.VEC3, CAMERA_START, CAMERA_END, INVENTORY_ANIM_TIME, true)
        local targetInterpolate = PerformMotion("RingOpening4", MOTION_TYPE.VEC3, TARGET_START, TARGET_END, INVENTORY_ANIM_TIME, true)
        local fadeInterpolate = PerformMotion("RingOpening5", MOTION_TYPE.LINEAR, 0, 255, INVENTORY_ANIM_TIME, true)
        TranslateRing(inventoryTable, RING_CENTER, radiusInterpolate.output, angleInterpolate.output)
        FadeRing(inventoryTable, fadeInterpolate.output, false)
        TEN.DrawItem.SetInvCameraPosition(cameraInterpolate.output)
        TEN.DrawItem.SetInvTargetPosition(targetInterpolate.output)
        TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_OPEN)

        if radiusInterpolate.progress >= PROGRESS_COMPLETE then
            ClearMotionProgress("RingOpening1")
            ClearMotionProgress("RingOpening2")
            ClearMotionProgress("RingOpening3")
            ClearMotionProgress("RingOpening4")
            ClearMotionProgress("RingOpening5")
            LevelVars.Engine.CustomInventory.RingOpening = false
            LevelVars.Engine.CustomInventory.InventoryOpenFreeze = true
            return true
        end
    elseif mode == INVENTORY_MODE.RING_CLOSING then
        local radiusInterpolate = PerformMotion("RingClosing", MOTION_TYPE.LINEAR, RING_RADIUS, 0, INVENTORY_ANIM_TIME, true)
        local angleInterpolate = PerformMotion("RingClosing2", MOTION_TYPE.LINEAR, 0, -360, INVENTORY_ANIM_TIME, true)
        local cameraInterpolate = PerformMotion("RingClosing3", MOTION_TYPE.VEC3, CAMERA_END, CAMERA_START,  INVENTORY_ANIM_TIME, true)
        local targetInterpolate = PerformMotion("RingClosing4", MOTION_TYPE.VEC3, TARGET_END, TARGET_START, INVENTORY_ANIM_TIME, true)
        local fadeInterpolate = PerformMotion("RingClosing5", MOTION_TYPE.LINEAR, 255, 0, INVENTORY_ANIM_TIME, true)
        TranslateRing(inventoryTable, RING_CENTER, radiusInterpolate.output, angleInterpolate.output)
        FadeRing(inventoryTable, fadeInterpolate.output, false)
        TEN.DrawItem.SetInvCameraPosition(cameraInterpolate.output)
        TEN.DrawItem.SetInvTargetPosition(targetInterpolate.output)
        TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)

        if radiusInterpolate.progress >= PROGRESS_COMPLETE then
            ClearMotionProgress("RingClosing")
            ClearMotionProgress("RingClosing2")
            ClearMotionProgress("RingClosing3")
            ClearMotionProgress("RingClosing4")
            ClearMotionProgress("RingClosing5")
            LevelVars.Engine.CustomInventory.RingClosing = false
            return true
        end
    end

end

LevelFuncs.Engine.CustomInventory.DrawInventory = function(mode)
    
    local inventoryTable = LevelVars.Engine.CustomInventory.Inventory

    if mode == INVENTORY_MODE.INVENTORY then
        if LevelVars.Engine.CustomInventory.RingOpening == false and LevelVars.Engine.CustomInventory.RingClosing == false then

            if rotationInProgress then
                local angleInterpolate = PerformMotion("RingRotating", MOTION_TYPE.LINEAR, currentAngle, targetAngle, INVENTORY_ANIM_TIME/4, true)
                
                TranslateRing(inventoryTable, RING_CENTER, RING_RADIUS, angleInterpolate.output)
                
                if angleInterpolate.progress >= PROGRESS_COMPLETE then
                    ClearMotionProgress("RingRotating")
                    currentAngle = targetAngle
                    rotationInProgress = false
                end
            end

            if not rotationInProgress then
                local selectedItem = inventoryTable[LevelVars.Engine.CustomInventory.SelectedItem].item
                RotateItem(selectedItem)
                LevelFuncs.Engine.CustomInventory.DrawItemLabel(selectedItem)
            end
        end
    elseif mode == INVENTORY_MODE.RING_OPENING then
        if LevelVars.Engine.CustomInventory.RingOpening == true then

            if AnimateInventory(mode) then

                inventoryMode = INVENTORY_MODE.INVENTORY

            end

        end

    elseif mode == INVENTORY_MODE.RING_CLOSING then

        if LevelVars.Engine.CustomInventory.RingClosing == true then

            if AnimateInventory(mode) then
    
                LevelFuncs.Engine.CustomInventory.ExitInventory()

            end

        end
    elseif mode == INVENTORY_MODE.EXAMINE then
        LevelFuncs.Engine.CustomInventory.ExamineItem(selectedItem)
    end
end

LevelFuncs.Engine.CustomInventory.GetSelectedItem = function()
    
    return LevelVars.Engine.CustomInventory.SelectedItem

end

LevelFuncs.Engine.CustomInventory.ReduceItem = function(item, count)

    TEN.Inventory.TakeItem(item, count)

end

LevelFuncs.Engine.CustomInventory.UseItem = function(item)

    local levelStatistics = Flow.GetStatistics()
    local gameStatistics = Flow.GetStatistics(true)

    local CROUCH_STATES ={
			LS_CROUCH_IDLE = 71,
			LS_CROUCH_TURN_LEFT = 105,
			LS_CROUCH_TURN_RIGHT = 106,
			LS_CROUCH_TURN_180 = 171
		}

    local CRAWL_STATES = {
			LS_CRAWL_IDLE = 80,
			LS_CRAWL_FORWARD = 81,
			LS_CRAWL_BACK = 86,
			LS_CRAWL_TURN_LEFT = 84,
			LS_CRAWL_TURN_RIGHT = 85,
			LS_CRAWL_TURN_180 = 172,
			LS_CRAWL_TO_HANG = 88
		}

    local TestState = function(table)
        local currentState = Lara:GetState()
        for _, state in pairs(table) do
            if currentState == state then
                return true
            end
        end
        return false
    end

    local CrawlTest = function(item)

        if item.crawl then
            return true
        end

        return not (TestState(CROUCH_STATES) or TestState(CRAWL_STATES))

    end

    local WaterTest = function(item)
        
        if item.underwater then
            return true
        end

        return (Lara:GetWaterStatus() == TEN.Objects.WaterStatus.DRY or Lara:GetWaterStatus() == TEN.Objects.WaterStatus.WADE)

    end

	TEN.Inventory.SetUsedItem(item)

	--Use item event handling.
	TEN.Util.OnUseItemCallBack()
    
    --Quickly discard further processing if chosen item was reset in script.
    if (TEN.Inventory.GetUsedItem() == NO_VALUE) then
        return
    end

    if WEAPON_SET[item] and WaterTest(WEAPON_SET[item]) and CrawlTest(WEAPON_SET[item]) then
        
        TEN.Inventory.ClearUsedItem()

        local currentWeapon = Lara:GetWeaponType()

        --Return if flare is already equipped
        if currentWeapon == TEN.Objects.WeaponType.FLARE then
            return
        end
        
        Lara:SetWeaponType(WEAPON_SET[item].slot, true)

        if currentWeapon == WEAPON_SET[item].slot and Lara:GetHandStatus() ~= TEN.Objects.HandStatus.WEAPON_READY then
            Lara:SetHandStatus(TEN.Objects.HandStatus.WEAPON_DRAW)
        end

        if item == TEN.Objects.ObjID.FLARE_INV_ITEM then
            LevelFuncs.Engine.CustomInventory.ReduceItem(item, 1)
        end
        
    end

    if HEALTH_SET[item] then

        TEN.Inventory.ClearUsedItem()

        local hp = Lara:GetHP()
        local poison = Lara:GetPoison()

        if hp <= 0 or hp >= HEALTH_MAX then
            if poison == 0 then
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                return
            end
        end

        local count = TEN.Inventory.GetItemCount(item)
        
        if count then
            if count ~= NO_VALUE then
                LevelFuncs.Engine.CustomInventory.ReduceItem(item, 1)
            end

            Lara:SetPoison(0)
            
            local setHP = math.min(1000, (hp + HEALTH_SET[item]))
            Lara:SetHP(setHP)

            TEN.Sound.PlaySound(SOUND_MAP.TR4_MENU_MEDI)
            
            --update statistics for health item used
            levelStatistics.healthPacksUsed = levelStatistics.healthPacksUsed + 1
            gameStatistics.healthPacksUsed = gameStatistics.healthPacksUsed + 1
            Flow.SetStatistics(levelStatistics)
            Flow.SetStatistics(gameStatistics, true)
        end

    end

    if item == TEN.Objects.ObjID.BINOCULARS_ITEM then
        
        TEN.Inventory.ClearUsedItem()
        useBinoculars = true

    end

end

LevelFuncs.Engine.CustomInventory.CombineItem = function(item1, item2)

    if combine(item1, item2) then
     
        LevelFuncs.Engine.CustomInventory.ConstructObjectList() 
        
    end

end



LevelFuncs.Engine.CustomInventory.ExamineItem = function(item)

    --local screenPos = percentPos(50, 50)

    -- Get current inventory item
    -- local inventoryRing = g_Gui:GetRing(RingTypes.Inventory)
    -- local currentIndex = inventoryRing.CurrentObjectInList
    -- local currentItemID = inventoryRing.CurrentObjectList[currentIndex].InventoryItem
    -- local object = InventoryObjectTable[currentItemID]

    -- Clamp scale
    if examineScaler > 1.6 then
        examineScaler = 1.6
    elseif examineScaler < 0.8 then
        examineScaler = 0.8
    end

    -- Get the localized string key
    local objectName = Util.GetObjectIDString(item)
    local stringKey = objectName:lower() .. "_text"

    print(stringKey)
    local localizedString = GetString(stringKey)

    -- Draw the inventory object with scale applied
    -- local savedScale = object.Scale1
    -- object.Scale1 = scaler
    -- DrawObjectIn2DSpace(g_Gui:ConvertInventoryItemToObject(currentItemID), screenPos, orient, object.Scale1)
    -- object.Scale1 = savedScale

    --TEN.DrawItem.SetItemPosition(item, screenPos)
    TEN.DrawItem.SetItemRotation(item, examineOrient)
    TEN.DrawItem.SetItemScale(item, examineScaler)
    
    if localizedString and examineShowString then
        local entryText = TEN.Strings.DisplayString(localizedString, percentPos(50, 80), 1, COLOR_MAP.NORMAL_FONT, true, {Strings.DisplayStringOption.VERTICAL_CENTER, Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER})
        ShowString(entryText, 1 / 30)
    end

end

LevelFuncs.Engine.CustomInventory.DrawItemLabel = function(item)

    local entryPosInPixel = percentPos(50, 86) --Item label
    local label = GetString(LevelVars.Engine.CustomInventory.Inventory[LevelVars.Engine.CustomInventory.SelectedItem].name)
    local count = LevelVars.Engine.CustomInventory.Inventory[LevelVars.Engine.CustomInventory.SelectedItem].count
    local result

    if count == -1 then
        result = GetString("unlimited"):gsub(" ", ""):gsub("%%s", "").. " "
    elseif count > 1 then
        result = tostring(count) .. " x "
    else
        result = ""
    end

    local string = result ..label
    local entryText = TEN.Strings.DisplayString(string, entryPosInPixel, 1.5, COLOR_MAP.NORMAL_FONT, false, {Strings.DisplayStringOption.CENTER, Strings.DisplayStringOption.SHADOW})
    ShowString(entryText, 1 / 30)
    
end

LevelFuncs.Engine.CustomInventory.DrawAmmoLabel = function(item)

    if WEAPON_SET[item] then
        
    end 
end

LevelFuncs.Engine.CustomInventory.DrawInventoryText = function()
    
    local fadeInterpolate
    if inventoryMode == INVENTORY_MODE.RING_OPENING then
        fadeInterpolate = PerformMotion("FontFade", MOTION_TYPE.LINEAR, 0, 255, INVENTORY_ANIM_TIME, true)
        if fadeInterpolate.progress >= PROGRESS_COMPLETE then
            ClearMotionProgress("FontFade")
        end
    elseif inventoryMode == INVENTORY_MODE.RING_CLOSING then
        fadeInterpolate = PerformMotion("FontFade", MOTION_TYPE.LINEAR, 255, 0, INVENTORY_ANIM_TIME, true)
        if fadeInterpolate.progress >= PROGRESS_COMPLETE then
            ClearMotionProgress("FontFade")
        end
    elseif inventoryMode == INVENTORY_MODE.INVENTORY then
        fadeInterpolate = {output = 255, progress = 1}
    end

    local stringTable = {
    {"actions_inventory", Vec2(50, 4), 1.5, COLOR_MAP.HEADER_FONT},
    {"choose_ammo", Vec2(78, 70), 0.5, COLOR_MAP.NORMAL_FONT},
    {"equip", Vec2(22, 84), 0.5, COLOR_MAP.NORMAL_FONT},
    {"close", Vec2(78, 84), 0.5, COLOR_MAP.NORMAL_FONT},
    }

    for _, entry in ipairs(stringTable) do

    local string = GetString(entry[1])
    local position = entry[2]
    local scale = entry[3]
    local color = Color(entry[4].r, entry[4].g, entry[4].b, fadeInterpolate.output)

    local entryPosInPixel = percentPos(position.x, position.y)

    local entryText = TEN.Strings.DisplayString(string, entryPosInPixel, scale, color, false, {Strings.DisplayStringOption.CENTER, Strings.DisplayStringOption.SHADOW})
    ShowString(entryText, 1 / 30)
    end

end



LevelFuncs.Engine.CustomInventory.ReadGameflow = function()

    local overrides = {}
    for _, itemID in ipairs(TEN.Flow.GetCurrentLevel().objects) do

        if itemID.objectID then
            local id = TEN.Inventory.ConvertInventoryItemToObject(itemID.objectID)
            overrides[id] = { 
                    item = id,
                    yOffset = itemID.yOffset,
                    scale = itemID.scale,
                    rotation = itemID.rotation,
                    flags = itemID.menuAction,
                    name = itemID.name,
                    joint = itemID.meshBits,
                    orientation = itemID.rotationFlags
            }
        end
    end

    return overrides

end