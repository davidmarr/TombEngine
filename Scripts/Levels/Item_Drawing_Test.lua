-- FILE: Levels\Item_Drawing_Test.lua

local pickupData = require("Levels.InventoryConstants")

local inventoryMode = 
{
    MAINMENU = 1,
    INVENTORY = 2,
    EXAMINE = 3, 
}

local soundMap =
{
    MENU_CHOOSE = 0,
    MENU_SELECT = 0,
}

--variables
local rotation = 0
local alpha = 0
local interval = 1/10
local timeInMenu = 0
local inventoryDelay = 0 --count of actual frames before inventory is opened. Used for setting the grayscale tint.
local NO_VALUE = -1
local weaponSet = {
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

math.sign = function(x)
    return x > 0 and 1 or (x < 0 and -1 or 0)
end

LevelFuncs.OnLoad = function() end
LevelFuncs.OnSave = function() end

LevelFuncs.OnStart = function()

    LevelFuncs.Engine.CustomInventory.IntializeInventory()

end

LevelFuncs.OnFreeze = function()

    --LevelFuncs.DrawCursor()
    --LevelFuncs.AdjustCamera()
end

LevelFuncs.OnLoop = function()

    -- if LevelVars.Engine.CustomInventory.UseBinoculars then
    --     TEN.View.UseBinoculars()
    --     LevelVars.Engine.CustomInventory.UseBinoculars = false
    -- end

end

local count = 0
local selectedIndex = 1
local vector
LevelFuncs.Count = function(keydown)

    count = count + 1

    if count > 4 then
        count = 0
        return true
    end

    return false
end


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

    local myText = DisplayString(selectedItem, 10, 10, Color.new(64,250,60))
	ShowString(myText,1/30)

    if selectedItem == "Camera" then
        vector = TEN.DrawItem.GetCameraPosition()
    elseif selectedItem == "Target" then
        vector = TEN.DrawItem.GetTargetPosition()
    elseif selectedItem == "FOV" then
        vector = Vec3(0,View.GetFOV(),0)
    end

    if IsKeyHeld(TEN.Input.ActionID.LEFT) then
            vector.x = vector.x - 1
    elseif IsKeyHeld(TEN.Input.ActionID.RIGHT) then
            vector.x = vector.x + 1
    elseif IsKeyHeld(TEN.Input.ActionID.FORWARD) then
            vector.z = vector.z + 1
    elseif IsKeyHeld(TEN.Input.ActionID.BACK) then
            vector.z = vector.z - 1
    elseif IsKeyHeld(TEN.Input.ActionID.STEP_LEFT) then
            vector.y = vector.y - 1
    elseif IsKeyHeld(TEN.Input.ActionID.STEP_RIGHT) then
            vector.y = vector.y + 1
    elseif IsKeyHit(TEN.Input.ActionID.R) then

        if selectedItem == "Camera" then
            vector = Vec3(0,0,-1024)
        elseif selectedItem == "Target" then
            vector = Vec3(0,0,0)
        elseif selectedItem == "FOV" then
            vector = Vec3(0,80,0)
        elseif selectedItem == "Label" then
            vector = Vec3(50,0.5,90)
        end
    end

    local myText2 = DisplayString(tostring(vector), 10, 50, Color.new(64,250,60))
	ShowString(myText2,1/30)


    if selectedItem == "Camera" then
        TEN.DrawItem.SetCameraPosition(vector)
    elseif selectedItem == "Target" then
        TEN.DrawItem.SetTargetPosition(vector)
    elseif selectedItem == "FOV" then
        View.SetFOV(vector.y)
    end
end


LevelFuncs.Engine.CustomInventory.StartInventory = function()

    if (IsKeyHit(TEN.Input.ActionID.INVENTORY) or TEN.DrawItem.GetOpenInventory() ~= NO_VALUE)and not LevelVars.Engine.CustomInventory.InventoryOpen  then
        --ClearKey(TEN.Input.ActionID.INVENTORY)
        print("running inventory")
        LevelVars.Engine.CustomInventory.InventoryOpen = true
        inventoryDelay = 0
    end

    if LevelVars.Engine.CustomInventory.InventoryOpen == true then
        --ClearKey(TEN.Input.ActionID.INVENTORY)
        inventoryDelay = inventoryDelay + 1
        SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        SetPostProcessStrength(1)
        SetPostProcessTint(Color(128,128,128))

        if inventoryDelay >= 2 then
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
    TEN.Inventory.SetUsedItem(TEN.Objects.ObjID.PUZZLE_ITEM10)
    View.SetFOV(80)
    Flow.SetFreezeMode(Flow.FreezeMode.NONE)
    LevelVars.Engine.CustomInventory.InventoryClosed = true
    timeInMenu = 0
    rotation = 0
end

LevelFuncs.Engine.CustomInventory.UpdateInventory = function()

    timeInMenu = timeInMenu + 1

    LevelFuncs.Engine.CustomInventory.DrawInventoryText()

    if LevelVars.Engine.CustomInventory.InventoryOpen then
        SetPostProcessMode(View.PostProcessMode.NONE)
        LevelFuncs.Engine.CustomInventory.ConstructObjectList()
    else
        LevelFuncs.Engine.CustomInventory.Input()
        LevelFuncs.Engine.CustomInventory.RotateInventory()

        TEN.DrawItem.SetMeshRotation(TEN.Objects.ObjID.STOPWATCH_ITEM, 6, Rotation(0,0,(rotation) % 360))
        TEN.DrawItem.SetMeshRotation(TEN.Objects.ObjID.STOPWATCH_ITEM, 4, Rotation(0,0,(rotation+90) % 360))
        TEN.DrawItem.SetMeshRotation(TEN.Objects.ObjID.STOPWATCH_ITEM, 5, Rotation(0,0,(rotation+180) % 360))
        TEN.DrawItem.SetMeshRotation(TEN.Objects.ObjID.COMPASS_ITEM, 1, Rotation(0,(rotation) % 360,0))
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
    LevelVars.Engine.CustomInventory.InventoryOpenFreeze = false
    LevelVars.Engine.CustomInventory.InventoryClosed = false
    LevelVars.Engine.CustomInventory.UseBinoculars = false

    TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.CustomInventory.StartInventory)

    TEN.DrawItem.SetCameraPosition(Vec3(0,-36,-1151))
    TEN.DrawItem.SetTargetPosition(Vec3(0,110,0))

    TEN.DrawItem.SetInventoryOverride(true)

end



LevelFuncs.Engine.CustomInventory.ConstructObjectList = function()


    LevelVars.Engine.CustomInventory.CurrentAngle = 0
    LevelVars.Engine.CustomInventory.TargetAngle = 0
    LevelVars.Engine.CustomInventory.SelectedItem = 1
    alpha = 0
    LevelVars.Engine.CustomInventory.RingOpening = true

    local items  = pickupData.constants
    local gameflowOverrides = LevelFuncs.Engine.CustomInventory.ReadGameflow() or {}

    View.SetFOV(80)
    
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
        TEN.DrawItem.AddItem(item.item, LevelVars.Engine.CustomInventory.Centre, item.scale, 1, item.joint)
    end

    LevelVars.Engine.CustomInventory.InventorySlice = (360 / #inventory)
    LevelVars.Engine.CustomInventory.InventoryOpen = false
end

LevelFuncs.Engine.CustomInventory.DrawInventory = function(items, center, radius, rotationOffset)

    local itemCount = #items
    
    for i = 1, itemCount do
        local currentItem = items[i].item 

        local angleDeg = (360 / itemCount) * (i - 1) +  rotationOffset
       
        local position = center:Translate(Rotation(0,angleDeg,0),radius)

        TEN.DrawItem.SetItemPosition(currentItem, position)
        TEN.DrawItem.SetItemRotation(currentItem, Rotation(0,angleDeg+180,0))
    end

end

LevelFuncs.Engine.CustomInventory.DrawAmmoRing = function(items, center, radius, rotationOffset)

    local itemCount = #items
    
    for i = 1, itemCount do
        local currentItem = items[i].item 

        local angleDeg = (360 / itemCount) * (i - 1) +  rotationOffset
       
        local position = center:Translate(Rotation(0,angleDeg,0),radius)

        TEN.DrawItem.SetItemPosition(currentItem, position)
        TEN.DrawItem.SetItemRotation(currentItem, Rotation(0,angleDeg+180,0))
    end

end

LevelFuncs.Engine.CustomInventory.Input = function()

local inventoryTable = LevelVars.Engine.CustomInventory.Inventory

    if not LevelVars.Engine.CustomInventory.RotationInProgress then
        if LevelFuncs.Engine.CustomInventory.GuiIsPulsed(TEN.Input.ActionID.LEFT) then
            LevelVars.Engine.CustomInventory.SelectedItem = ((LevelVars.Engine.CustomInventory.SelectedItem - 2) % #inventoryTable) + 1
            LevelVars.Engine.CustomInventory.TargetAngle = LevelVars.Engine.CustomInventory.CurrentAngle + LevelVars.Engine.CustomInventory.InventorySlice
            LevelVars.Engine.CustomInventory.RotationInProgress = true
        elseif LevelFuncs.Engine.CustomInventory.GuiIsPulsed(TEN.Input.ActionID.RIGHT) then
            LevelVars.Engine.CustomInventory.SelectedItem = (LevelVars.Engine.CustomInventory.SelectedItem % #inventoryTable) + 1
            LevelVars.Engine.CustomInventory.TargetAngle = LevelVars.Engine.CustomInventory.CurrentAngle - LevelVars.Engine.CustomInventory.InventorySlice
            LevelVars.Engine.CustomInventory.RotationInProgress = true
        elseif LevelFuncs.Engine.CustomInventory.GuiIsPulsed(TEN.Input.ActionID.DRAW) then
            LevelVars.Engine.CustomInventory.SelectedItem = (LevelVars.Engine.CustomInventory.SelectedItem % #inventoryTable) + 1
            LevelVars.Engine.CustomInventory.TargetAngle = LevelVars.Engine.CustomInventory.CurrentAngle - LevelVars.Engine.CustomInventory.InventorySlice
            LevelVars.Engine.CustomInventory.RotationInProgress = true
        elseif LevelFuncs.Engine.CustomInventory.GuiIsPulsed(TEN.Input.ActionID.INVENTORY) and LevelVars.Engine.CustomInventory.InventoryOpenFreeze then
            LevelFuncs.Engine.CustomInventory.ExitInventory()
            return
        end
    end
end




LevelFuncs.Engine.CustomInventory.RotateInventory = function()
    
    local inventoryTable = LevelVars.Engine.CustomInventory.Inventory

    if LevelVars.Engine.CustomInventory.RingOpening == true then
        alpha = math.min(alpha + interval, 1)
        local factor = LevelFuncs.Engine.Node.Smoothstep(alpha)
        local newValue1 = LevelFuncs.Engine.Node.Lerp(0, LevelVars.Engine.CustomInventory.Radius, factor)
        print(newValue1)
        LevelFuncs.Engine.CustomInventory.DrawInventory(inventoryTable, LevelVars.Engine.CustomInventory.Centre, newValue1, LevelVars.Engine.CustomInventory.CurrentAngle)

        if alpha >=1 then
            LevelVars.Engine.CustomInventory.RingOpening =false
            LevelVars.Engine.CustomInventory.InventoryOpenFreeze = true
        end
    end

    if LevelVars.Engine.CustomInventory.RingOpening ==false then
        
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
        end

        LevelFuncs.Engine.CustomInventory.DrawInventory(inventoryTable, LevelVars.Engine.CustomInventory.Centre, LevelVars.Engine.CustomInventory.Radius, LevelVars.Engine.CustomInventory.CurrentAngle)

        if not LevelVars.Engine.CustomInventory.RotationInProgress then
            -- Optional: Rotate selected item
            local selectedItem = inventoryTable[LevelVars.Engine.CustomInventory.SelectedItem].item
            --TEN.DrawItem.SetItemRotation(selectedItem, Rotation(0, (rotation) % 360, 0))
            rotation  = rotation  + 4
            LevelFuncs.Engine.CustomInventory.DrawItemLabel(selectedItem)
        end
    end
end

LevelFuncs.Engine.CustomInventory.GetSelectedItem = function()
    
    return LevelVars.Engine.CustomInventory.SelectedItem

end

LevelFuncs.Engine.CustomInventory.ReduceItem = function(item, count)

    TEN.Inventory.TakeItem(item, count)

end

LevelFuncs.Engine.CustomInventory.UseItem = function(item, count)

    LevelFuncs.Engine.CustomInventory.ReduceItem(item, count)

end

LevelFuncs.Engine.CustomInventory.ExamineItem = function(item)

    local screenPos = TEN.Vec2(TEN.Util.PercentToScreen(50, 50))

    -- Static variables
    local orient = Rotation(0,0,0)

    local scaler = 1.2
   

    local multiplier = 1/30

    -- Get current inventory item
    local inventoryRing = g_Gui:GetRing(RingTypes.Inventory)
    local currentIndex = inventoryRing.CurrentObjectInList
    local currentItemID = inventoryRing.CurrentObjectList[currentIndex].InventoryItem
    local object = InventoryObjectTable[currentItemID]

    -- Handle rotation input
    if IsHeld(In.Forward) then
        orient.x = orient.x + 3.0 / multiplier
    end

    if IsHeld(In.Back) then
        orient.x = orient.x - (3.0 / multiplier)
    end

    if IsHeld(In.Left) then
        orient.y = orient.y + (3.0 / multiplier)
    end

    if IsHeld(In.Right) then
        orient.y = orient.y - (3.0 / multiplier)
    end

    -- Handle scaling input
    if IsHeld(In.Sprint) then
        scaler = scaler + (0.03 / multiplier)
    end

    if IsHeld(In.Crouch) then
        scaler = scaler - (0.03 / multiplier)
    end

    -- Clamp scale
    if scaler > 1.6 then
        scaler = 1.6
    elseif scaler < 0.8 then
        scaler = 0.8
    end

    -- Get the localized string key
    local objectName = GetObjectName(object.ObjectNumber)
    local stringKey = ToLower(objectName) .. "_text"
    local localizedString = g_GameFlow:GetString(stringKey)

    -- If string found (hash differs), draw it and shift position upward
    if GetHash(localizedString) ~= GetHash(stringKey) then
        AddString(
            screenPos.x,
            screenPos.y + screenPos.y / 2.0,
            localizedString,
            PRINTSTRING_COLOR_WHITE,
            SF_Center() + PrintStringFlags.VerticalCenter
        )
        screenPos.y = screenPos.y - (screenPos.y / 4.0)
    end

    -- Draw the inventory object with scale applied
    local savedScale = object.Scale1
    object.Scale1 = scaler
    DrawObjectIn2DSpace(g_Gui:ConvertInventoryItemToObject(currentItemID), screenPos, orient, object.Scale1)
    object.Scale1 = savedScale

    -- Draw UI strings
    local entryText = TEN.Strings.DisplayString(entry.text, entryPosInPixel, entry.textScale, textColor, IsString, entry.textOptions)
    ShowString(entryText, 1 / 30)

end

LevelFuncs.Engine.CustomInventory.DrawItemLabel = function(item)

    local entryPosInPixel = TEN.Vec2(TEN.Util.PercentToScreen(50, 86)) --Item label
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

    local entryPosInPixel = TEN.Vec2(TEN.Util.PercentToScreen(position.x, position.y))

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