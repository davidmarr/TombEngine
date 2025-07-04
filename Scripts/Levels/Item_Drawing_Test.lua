-- FILE: Levels\Item_Drawing_Test.lua

local inventoryModeType = 
{
    INVENTORY = 1,
    EXAMINE = 2,
    STATISTICS = 3,
    OPENING = 4,
    CLOSING = 5
}

--constants
local NO_VALUE = -1
local HEALTH_MAX = 1000
local ROTATION = 4 --rotation speed of Inventory Item
local CAMERA_START = Vec3(0,-2500, 200)
local CAMERA_END = Vec3(0,-36,-1151)
local TARGET_START = Vec3(0,0, 1000)
local TARGET_END = Vec3(0,110,0)
local INVENTORY_ANIM_TIME = 1

--variables
local timeInMenu = 0
local inventoryDelay = 0 --count of actual frames before inventory is opened. Used for setting the grayscale tint.
local inventoryMode = inventoryModeType.OPENING

--data maps
local pickupData = require("Levels.InventoryConstants")

--Structure for SoundMap
local soundMap =
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

--Structure for weapon data. TEN Weapon type constant, underwater equip allowed, equip while crawling allowed
local weaponSet = {
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

local healthSet = {
    [TEN.Objects.ObjID.BIGMEDI_ITEM] = HEALTH_MAX,
    [TEN.Objects.ObjID.SMALLMEDI_ITEM] = HEALTH_MAX / 2
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

LevelFuncs.Engine.CustomInventory = {}

--functions
local percentPos = function(x, y)
    return TEN.Vec2(TEN.Util.PercentToScreen(x, y))
end

math.sign = function(x)
    return x > 0 and 1 or (x < 0 and -1 or 0)
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
	
    for _, combo in ipairs(pickupData.combineTable) do
		
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

    local entrySprite2 = TEN.DisplaySprite(TEN.Objects.ObjID.DIARY_ENTRY_SPRITES, 0, TEN.Vec2(50, 50), 0, TEN.Vec2(100,100), TEN.Color(255,255,255))
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

LevelFuncs.Engine.CustomInventory.StartInventory = function()

    if LevelVars.Engine.CustomInventory.UseBinoculars then
        TEN.View.UseBinoculars()
        LevelVars.Engine.CustomInventory.UseBinoculars = false
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
        SetPostProcessTint(Color(128,128,128))

        if inventoryDelay >= 2 then
            TEN.Sound.PlaySound(soundMap.MENU_SELECT)
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
    LevelVars.Engine.CustomInventory.Progress = {}
    View.SetFOV(80)
    Flow.SetFreezeMode(Flow.FreezeMode.NONE)
    LevelVars.Engine.CustomInventory.InventoryClosed = true
    inventoryMode = inventoryModeType.OPENING
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
        LevelFuncs.Engine.CustomInventory.Input(inventoryMode)
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
    LevelVars.Engine.CustomInventory.CurrentAngle = 0
    LevelVars.Engine.CustomInventory.TargetAngle = 0
    LevelVars.Engine.CustomInventory.RotationInProgress = false
    LevelVars.Engine.CustomInventory.Centre = Vec3(0,200,1024)
    LevelVars.Engine.CustomInventory.Radius = -512
    LevelVars.Engine.CustomInventory.Inventory = {}
    LevelVars.Engine.CustomInventory.InventoryOpen = false
    LevelVars.Engine.CustomInventory.RingOpening = true
    LevelVars.Engine.CustomInventory.RingClosing = false
    LevelVars.Engine.CustomInventory.InventoryOpenFreeze = false
    LevelVars.Engine.CustomInventory.InventoryClosed = false
    LevelVars.Engine.CustomInventory.UseBinoculars = false
    LevelVars.Engine.CustomInventory.Progress = {}

    TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.CustomInventory.StartInventory)

    TEN.DrawItem.SetInvCameraPosition(CAMERA_START)
    TEN.DrawItem.SetInvTargetPosition(TARGET_START)
    TEN.DrawItem.SetAmbientLight(Color(255,0,0))

    TEN.DrawItem.SetInventoryOverride(true)

end

LevelFuncs.Engine.CustomInventory.ConstructObjectList = function()


    LevelVars.Engine.CustomInventory.CurrentAngle = 0
    LevelVars.Engine.CustomInventory.TargetAngle = 0
    LevelVars.Engine.CustomInventory.SelectedItem = 1
    LevelVars.Engine.CustomInventory.RingOpening = true

    local items  = pickupData.constants
    local gameflowOverrides = LevelFuncs.Engine.CustomInventory.ReadGameflow() or {}
    
    local inventory = {}

    for _, itemID in ipairs(items) do

        local objectID = pickupData.GetInventoryData(itemID)
        local count = TEN.Inventory.GetItemCount(objectID.itemID)
        local yOffset = pickupData.GetItemData(objectID.itemID, "YOFFSET")
        local scale = pickupData.GetItemData(objectID.itemID, "SCALE")
        local rotation = pickupData.GetItemData(objectID.itemID, "ROTATION")
        local flags = pickupData.GetItemData(objectID.itemID, "FLAGS")
        local name = pickupData.GetItemData(objectID.itemID, "DISPLAY_NAME")
        local joint = pickupData.GetItemData(objectID.itemID, "JOINT")
        local orientation = pickupData.GetItemData(objectID.itemID, "SCALE")
        
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
        TEN.DrawItem.AddItem(item.item, LevelVars.Engine.CustomInventory.Centre, item.rotation, item.scale, item.joint)
        TEN.DrawItem.SetItemColor(item.item, Color(64,64,64,255))
    end

    LevelVars.Engine.CustomInventory.InventorySlice = (360 / #inventory)
    LevelVars.Engine.CustomInventory.InventoryOpen = false
end

LevelFuncs.Engine.CustomInventory.TranslateInventory = function(ring, center, radius, rotationOffset)

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

LevelFuncs.Engine.CustomInventory.RotateItem = function(item)
    local itemRotation  = TEN.DrawItem.GetItemRotation(item)
    TEN.DrawItem.SetItemRotation(item, Rotation(itemRotation.x, (itemRotation.y + ROTATION) % 360, itemRotation.z))
end

local motionInputTypes = {
    LINEAR = 1,
    VEC2 = 2,
    VEC3 = 3,
    ROTATION = 4,
    COLOR = 5 
}

LevelFuncs.Engine.CustomInventory.Motion = function(name, dataType, oldValue, newValue, time, smooth)

    if LevelVars.Engine.CustomInventory.Progress[name] == nil then
        LevelVars.Engine.CustomInventory.Progress[name] = 0
    end

    local interval = 1 / (time * 30)
    LevelVars.Engine.CustomInventory.Progress[name] = math.min(LevelVars.Engine.CustomInventory.Progress[name] + interval, 1)
	local factor = smooth and LevelFuncs.Engine.Node.Smoothstep(LevelVars.Engine.CustomInventory.Progress[name]) or LevelVars.Engine.CustomInventory.Progress[name]
	
	local newValue1
	local newValue2
	local newValue3
	local newValue4
	
	if (dataType == motionInputTypes.LINEAR) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue, newValue, factor)
	elseif (dataType == motionInputTypes.VEC2) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue.x, newValue.x, factor)
		newValue2 = LevelFuncs.Engine.Node.Lerp(oldValue.y, newValue.y, factor)
    elseif (dataType == motionInputTypes.VEC3) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue.x, newValue.x, factor)
		newValue2 = LevelFuncs.Engine.Node.Lerp(oldValue.y, newValue.y, factor)
	    newValue3 = LevelFuncs.Engine.Node.Lerp(oldValue.z, newValue.z, factor)
    elseif (dataType == motionInputTypes.ROTATION) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue.x, newValue.x, factor)
		newValue2 = LevelFuncs.Engine.Node.Lerp(oldValue.y, newValue.y, factor)
	    newValue3 = LevelFuncs.Engine.Node.Lerp(oldValue.z, newValue.z, factor)
    elseif (dataType == motionInputTypes.COLOR) then
		newValue1 = LevelFuncs.Engine.Node.Lerp(oldValue.r, newValue.r, factor)
		newValue2 = LevelFuncs.Engine.Node.Lerp(oldValue.g, newValue.g, factor)
	    newValue3 = LevelFuncs.Engine.Node.Lerp(oldValue.b, newValue.b, factor)
	    newValue4 = LevelFuncs.Engine.Node.Lerp(oldValue.a, newValue.a, factor)
	end

    if (LevelVars.Engine.CustomInventory.Progress[name] >= 1) then
		LevelVars.Engine.CustomInventory.Progress[name] = nil
        print(LevelVars.Engine.CustomInventory.Progress[name])
	end

    if (dataType == motionInputTypes.LINEAR) then
		return newValue1
	elseif (dataType == motionInputTypes.VEC2) then
		return Vec2(newValue1, newValue2)
    elseif (dataType == motionInputTypes.VEC3) then
		return Vec3(newValue1, newValue2, newValue3)
    elseif (dataType == motionInputTypes.ROTATION) then
		return Rotation(newValue1, newValue2, newValue3)
    elseif (dataType == motionInputTypes.COLOR) then
		return Color(newValue1, newValue2, newValue3, newValue4)
	end

end

LevelFuncs.Engine.CustomInventory.Input = function(mode)

    if mode == inventoryModeType.INVENTORY then
        local inventoryTable = LevelVars.Engine.CustomInventory.Inventory

        if not LevelVars.Engine.CustomInventory.RotationInProgress then
            if LevelFuncs.Engine.CustomInventory.GuiIsPulsed(TEN.Input.ActionID.LEFT) then
                LevelVars.Engine.CustomInventory.SelectedItem = ((LevelVars.Engine.CustomInventory.SelectedItem - 2) % #inventoryTable) + 1
                LevelVars.Engine.CustomInventory.TargetAngle = LevelVars.Engine.CustomInventory.CurrentAngle + LevelVars.Engine.CustomInventory.InventorySlice
                LevelVars.Engine.CustomInventory.RotationInProgress = true
                TEN.Sound.PlaySound(soundMap.MENU_ROTATE)
            elseif LevelFuncs.Engine.CustomInventory.GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
                LevelVars.Engine.CustomInventory.SelectedItem = (LevelVars.Engine.CustomInventory.SelectedItem % #inventoryTable) + 1
                LevelVars.Engine.CustomInventory.TargetAngle = LevelVars.Engine.CustomInventory.CurrentAngle - LevelVars.Engine.CustomInventory.InventorySlice
                LevelVars.Engine.CustomInventory.RotationInProgress = true
                TEN.Sound.PlaySound(soundMap.MENU_ROTATE)
            elseif LevelFuncs.Engine.CustomInventory.GuiIsPulsed(TEN.Input.ActionID.ACTION) then
                local item = LevelVars.Engine.CustomInventory.Inventory[LevelVars.Engine.CustomInventory.SelectedItem].item
                TEN.Sound.PlaySound(soundMap.MENU_CHOOSE)
                LevelFuncs.Engine.CustomInventory.UseItem(item)
                LevelFuncs.Engine.CustomInventory.ExitInventory()
            elseif LevelFuncs.Engine.CustomInventory.GuiIsPulsed(TEN.Input.ActionID.INVENTORY) and LevelVars.Engine.CustomInventory.InventoryOpenFreeze then
                TEN.Sound.PlaySound(soundMap.MENU_SELECT)
                LevelVars.Engine.CustomInventory.RingClosing = true
                inventoryMode = inventoryModeType.CLOSING
                --LevelFuncs.Engine.CustomInventory.ExitInventory()
                return
            end
        end
    else
        return
    end
end


local AnimateInventory = function(mode)

    local inventoryTable = LevelVars.Engine.CustomInventory.Inventory

    if mode == inventoryModeType.OPENING then
        local radiusInterpolate = LevelFuncs.Engine.CustomInventory.Motion("RingOpening1", motionInputTypes.LINEAR, 0, LevelVars.Engine.CustomInventory.Radius, INVENTORY_ANIM_TIME, true)
        local angleInterpolate = LevelFuncs.Engine.CustomInventory.Motion("RingOpening2", motionInputTypes.LINEAR, -360, 0, INVENTORY_ANIM_TIME, true)
        local cameraInterpolate = LevelFuncs.Engine.CustomInventory.Motion("RingOpening3", motionInputTypes.VEC3, CAMERA_START, CAMERA_END, INVENTORY_ANIM_TIME, true)
        local targetInterpolate = LevelFuncs.Engine.CustomInventory.Motion("RingOpening4", motionInputTypes.VEC3, TARGET_START, TARGET_END, INVENTORY_ANIM_TIME, true)
        LevelFuncs.Engine.CustomInventory.TranslateInventory(inventoryTable, LevelVars.Engine.CustomInventory.Centre, radiusInterpolate, angleInterpolate)
        TEN.DrawItem.SetInvCameraPosition(cameraInterpolate)
        TEN.DrawItem.SetInvTargetPosition(targetInterpolate)
        TEN.Sound.PlaySound(soundMap.INVENTORY_OPEN)

        if radiusInterpolate <= LevelVars.Engine.CustomInventory.Radius then
            LevelVars.Engine.CustomInventory.RingOpening = false
            LevelVars.Engine.CustomInventory.InventoryOpenFreeze = true
            return true
        end
    elseif mode == inventoryModeType.CLOSING then
        local radiusInterpolate = LevelFuncs.Engine.CustomInventory.Motion("RingClosing", motionInputTypes.LINEAR, LevelVars.Engine.CustomInventory.Radius, 0, INVENTORY_ANIM_TIME, true)
        local angleInterpolate = LevelFuncs.Engine.CustomInventory.Motion("RingClosing2", motionInputTypes.LINEAR, 0, -360, INVENTORY_ANIM_TIME, true)
        local cameraInterpolate = LevelFuncs.Engine.CustomInventory.Motion("RingClosing3", motionInputTypes.VEC3, CAMERA_END, CAMERA_START,  INVENTORY_ANIM_TIME, true)
        local targetInterpolate = LevelFuncs.Engine.CustomInventory.Motion("RingClosing4", motionInputTypes.VEC3, TARGET_END, TARGET_START, INVENTORY_ANIM_TIME, true)
        LevelFuncs.Engine.CustomInventory.TranslateInventory(inventoryTable, LevelVars.Engine.CustomInventory.Centre, radiusInterpolate, angleInterpolate)
        TEN.DrawItem.SetInvCameraPosition(cameraInterpolate)
        TEN.DrawItem.SetInvTargetPosition(targetInterpolate)
        TEN.Sound.PlaySound(soundMap.INVENTORY_CLOSE)

        if radiusInterpolate >= 0 then
            LevelVars.Engine.CustomInventory.RingClosing = false
            return true
        end
    end

end

LevelFuncs.Engine.CustomInventory.DrawInventory = function(mode)
    
    local inventoryTable = LevelVars.Engine.CustomInventory.Inventory

    if mode == inventoryModeType.INVENTORY then
        if LevelVars.Engine.CustomInventory.RingOpening == false and LevelVars.Engine.CustomInventory.RingClosing == false then
            
            -- Smooth rotation
            if LevelVars.Engine.CustomInventory.RotationInProgress then
                local speed = 10 -- degrees per frame
                local diff = LevelVars.Engine.CustomInventory.TargetAngle - LevelVars.Engine.CustomInventory.CurrentAngle
                -- Normalize the difference to the shortest direction
                if diff > 180 then
                    diff = diff - 360
                elseif diff < -180 then
                    diff = diff + 360
                end

                -- Apply incremental movement
                if math.abs(diff) < speed then
                    LevelVars.Engine.CustomInventory.CurrentAngle = LevelVars.Engine.CustomInventory.TargetAngle
                    LevelVars.Engine.CustomInventory.RotationInProgress = false
                else
                    LevelVars.Engine.CustomInventory.CurrentAngle = LevelVars.Engine.CustomInventory.CurrentAngle + math.sign(diff) * speed
                end

                LevelFuncs.Engine.CustomInventory.TranslateInventory(inventoryTable, LevelVars.Engine.CustomInventory.Centre, LevelVars.Engine.CustomInventory.Radius, LevelVars.Engine.CustomInventory.CurrentAngle)

            end

            if not LevelVars.Engine.CustomInventory.RotationInProgress then
                local selectedItem = inventoryTable[LevelVars.Engine.CustomInventory.SelectedItem].item
                LevelFuncs.Engine.CustomInventory.RotateItem(selectedItem)
                LevelFuncs.Engine.CustomInventory.DrawItemLabel(selectedItem)
            end
        end
    elseif mode == inventoryModeType.OPENING then
        if LevelVars.Engine.CustomInventory.RingOpening == true then

            if AnimateInventory(mode) then

                inventoryMode = inventoryModeType.INVENTORY

            end

        end

    elseif mode == inventoryModeType.CLOSING then

        if LevelVars.Engine.CustomInventory.RingClosing == true then

            if AnimateInventory(mode) then
    
                LevelFuncs.Engine.CustomInventory.ExitInventory()

            end

        end
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

    if weaponSet[item] and WaterTest(weaponSet[item]) and CrawlTest(weaponSet[item]) then
        
        TEN.Inventory.ClearUsedItem()

        local currentWeapon = Lara:GetWeaponType()

        --Return if flare is already equipped
        if currentWeapon == TEN.Objects.WeaponType.FLARE then
            return
        end
        
        Lara:SetWeaponType(weaponSet[item].slot, true)

        if currentWeapon == weaponSet[item].slot and Lara:GetHandStatus() ~= TEN.Objects.HandStatus.WEAPON_READY then
            Lara:SetHandStatus(TEN.Objects.HandStatus.WEAPON_DRAW)
        end

        if item == TEN.Objects.ObjID.FLARE_INV_ITEM then
            LevelFuncs.Engine.CustomInventory.ReduceItem(item, 1)
        end
        
    end

    if healthSet[item] then

        TEN.Inventory.ClearUsedItem()

        local hp = Lara:GetHP()
        local poison = Lara:GetPoison()

        if hp <= 0 or hp >= HEALTH_MAX then
            if poison == 0 then
                TEN.Sound.PlaySound(soundMap.PLAYER_NO)
                return
            end
        end

        local count = TEN.Inventory.GetItemCount(item)
        
        if count then
            if count ~= NO_VALUE then
                LevelFuncs.Engine.CustomInventory.ReduceItem(item, 1)
            end

            Lara:SetPoison(0)
            
            local setHP = math.min(1000, (hp + healthSet[item]))
            Lara:SetHP(setHP)

            TEN.Sound.PlaySound(soundMap.TR4_MENU_MEDI)
            
            --update statistics for health item used
            levelStatistics.healthPacksUsed = levelStatistics.healthPacksUsed + 1
            gameStatistics.healthPacksUsed = gameStatistics.healthPacksUsed + 1
            Flow.SetStatistics(levelStatistics)
            Flow.SetStatistics(gameStatistics, true)
        end

    end

    if item == TEN.Objects.ObjID.BINOCULARS_ITEM then
        
        TEN.Inventory.ClearUsedItem()
        LevelVars.Engine.CustomInventory.UseBinoculars = true

    end

end

LevelFuncs.Engine.CustomInventory.CombineItem = function(item1, item2)

    if combine(item1, item2) then
     
        LevelFuncs.Engine.CustomInventory.ConstructObjectList() 
        
    end

end

local examineOrient = Rotation(0,0,0)
local examineScaler = 1.2
local showString = true
LevelFuncs.Engine.CustomInventory.ExamineItem = function(item)

    --local screenPos = percentPos(50, 50)

    -- Static variables
    local multiplier = 1/30

    -- Get current inventory item
    -- local inventoryRing = g_Gui:GetRing(RingTypes.Inventory)
    -- local currentIndex = inventoryRing.CurrentObjectInList
    -- local currentItemID = inventoryRing.CurrentObjectList[currentIndex].InventoryItem
    -- local object = InventoryObjectTable[currentItemID]

    -- Handle rotation input
    if IsKeyHeld(Input.ActionID.FORWARD) then
        examineOrient.x = examineOrient.x + 3.0 / multiplier
    end

    if IsKeyHeld(Input.ActionID.BACK) then
        examineOrient.x = examineOrient.x - (3.0 / multiplier)
    end

    if IsKeyHeld(Input.ActionID.LEFT) then
        examineOrient.y = examineOrient.y + (3.0 / multiplier)
    end

    if IsKeyHeld(Input.ActionID.RIGHT) then
        examineOrient.y = examineOrient.y - (3.0 / multiplier)
    end

    -- Handle scaling input
    if IsKeyHeld(Input.ActionID.SPRINT) then
        examineScaler = examineScaler + (0.03 / multiplier)
    end

    if IsKeyHeld(Input.ActionID.CROUCH) then
        examineScaler = examineScaler - (0.03 / multiplier)
    end

    if IsKeyHeld(Input.ActionID.ACTION) then
        showString = not showString
    end

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
    
    if localizedString and showString then
        local entryText = TEN.Strings.DisplayString(localizedString, percentPos(50, 80), 1, Color(255,255,255), true, {Strings.DisplayStringOption.VERTICAL_CENTER, Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER})
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
    local entryText = TEN.Strings.DisplayString(string, entryPosInPixel, 1.5, Color(255,255,255), false, {Strings.DisplayStringOption.CENTER, Strings.DisplayStringOption.SHADOW})
    ShowString(entryText, 1 / 30)
    
end

LevelFuncs.Engine.CustomInventory.DrawAmmoLabel = function(item)

    if weaponSet[item] then
        
    end 
end

LevelFuncs.Engine.CustomInventory.DrawInventoryText = function()

    local stringTable = {
    {"actions_inventory", Vec2(50, 4), 1.5, Color(255, 240, 220)},
    {"choose_ammo", Vec2(78, 70), 0.5, Color(255, 240, 220)},
    {"equip", Vec2(22, 84), 0.5, Color(255, 255, 225)},
    {"close", Vec2(78, 84), 0.5, Color(255, 255, 255)},
    }

    for _, entry in ipairs(stringTable) do

    local string = GetString(entry[1])
    local position = entry[2]
    local scale = entry[3]
    local color = entry[4]

    local entryPosInPixel = percentPos(position.x, position.y)

    local entryText = TEN.Strings.DisplayString(string, entryPosInPixel, scale, color, false, {Strings.DisplayStringOption.CENTER, Strings.DisplayStringOption.SHADOW})
    ShowString(entryText, 1 / 30)
    end

end

LevelFuncs.Engine.CustomInventory.GuiIsPulsed = function(actionID)

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