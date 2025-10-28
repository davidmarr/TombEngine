--RING INVENTORY BY TRAINWRECK

local CustomInventory = {}

local PICKUP_DATA = require("Engine.CustomInventory.InventoryConstants")
local Settings = require("Engine.CustomInventory.Settings")
local Interpolate = require("Engine.InterpolateModule")
local Menu = require("Engine.CustomMenu")

local debug = false

--CONSTANTS
local NO_VALUE = -1
local HEALTH_MAX = 1000
local ROTATION_SPEED = 4 --rotation speed of Inventory Item
local CAMERA_START = Vec3(0,-2500, 200)
local CAMERA_END = Vec3(0,-36,-1151)
local TARGET_START = Vec3(0,0, 1000)
local TARGET_END = Vec3(0,110,0)
local INVENTORY_ANIM_TIME = 0.5
local RING_RADIUS = -512
local ITEM_START = Vec3(0,200,512)
local ITEM_END = Vec3(0,0,400)
local RING_POSITION_OFFSET = 1000
local PROGRESS_COMPLETE = 1
local EXAMINE_DEFAULT_SCALE = 1
local EXAMINE_MIN_SCALE = 0.3
local EXAMINE_MAX_SCALE = 1.6
local EXAMINE_TEXT_POS = Vec2(50, 80)
local ALPHA_MAX = 255
local ALPHA_MIN = 0

-- ITEM = {
--     ObjectID = 1,
--     Count = 2,
--     YOffset = 3,
--     Scale = 4,
--     Rotation = 5,
--     MenuActions = 6,
--     Name = 7,
--     MeshBits = 8,
--     Orientation = 9
-- }

local TYPE = {
    WEAPON = 1,
    AMMO = 2,
    MEDIPACK = 3,
    TOOL = 4,
    PUZZLE = 5,
    WATERSKIN = 6,
    SAVE = 7
}

local RING = {
	PUZZLE = 1,
    MAIN = 2,
	OPTIONS = 3,
	COMBINE = 4,
	AMMO = 5,
}

local RING_CENTER = {
    [RING.PUZZLE] = Vec3(0,-800,1024),
    [RING.MAIN] = Vec3(0,200,1024),
    [RING.OPTIONS] = Vec3(0,1200,1024),
    [RING.COMBINE] = Vec3(0,200,1024),
    [RING.AMMO] = Vec3(0,200,1024)
}

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
    EXAMINE_CLOSE = 9,
    ITEM_USE = 10,
    ITEM_SELECT = 11,
    ITEM_DESELECT = 12,
    ITEM_SELECTED = 13,
    RING_CHANGE = 14,
    RING_ROTATE = 15,
    COMBINE = 16,
    COMBINE_SETUP = 17,
    COMBINE_CLOSE = 18,
    COMBINE_RING_OPENING = 19,
    COMBINE_SUCCESS = 20,
    AMMO_SELECT_SETUP = 21,
    AMMO_SELECT_OPEN = 22,
    AMMO_SELECT = 23,
    AMMO_SELECT_CLOSE = 24,
    SAVE_SETUP = 25,
    SAVE_MENU = 26,
    SAVE_CLOSE = 27,
    COMBINE_COMPLETE = 28
}

local SOUND_MAP = Settings.SOUND_MAP
local COLOR_MAP = Settings.COLOR_MAP

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

local WEAPON_LASERSIGHT_DATA = {
    [TEN.Objects.ObjID.REVOLVER_ITEM] = {MESHBITS = 0x0B, NAME = "revolver_lasersight", FLAGS = ItemAction.EQUIP | ItemAction.SEPARATE | ItemAction.CHOOSE_AMMO_REVOLVER},                            
    [TEN.Objects.ObjID.CROSSBOW_ITEM] = {MESHBITS = 0x03, NAME = "crossbow_lasersight", FLAGS = ItemAction.EQUIP | ItemAction.SEPARATE | ItemAction.CHOOSE_AMMO_CROSSBOW},                          
    [TEN.Objects.ObjID.HK_ITEM]       = {MESHBITS = 0, NAME = "hk_lasersight", FLAGS = ItemAction.EQUIP | ItemAction.SEPARATE | ItemAction.CHOOSE_AMMO_HK},
    }

local WEAPON_AMMO_LOOKUP = {
    [TEN.Objects.ObjID.PISTOLS_ITEM] = {TEN.Objects.ObjID.PISTOLS_AMMO_ITEM},
    [TEN.Objects.ObjID.UZI_ITEM] = {TEN.Objects.ObjID.UZI_AMMO_ITEM},
    [TEN.Objects.ObjID.SHOTGUN_ITEM] = {TEN.Objects.ObjID.SHOTGUN_AMMO1_ITEM, TEN.Objects.ObjID.SHOTGUN_AMMO2_ITEM},
    [TEN.Objects.ObjID.REVOLVER_ITEM] = {TEN.Objects.ObjID.REVOLVER_AMMO_ITEM},
    [TEN.Objects.ObjID.CROSSBOW_ITEM] = {TEN.Objects.ObjID.CROSSBOW_AMMO1_ITEM, TEN.Objects.ObjID.CROSSBOW_AMMO2_ITEM, TEN.Objects.ObjID.CROSSBOW_AMMO3_ITEM},
    [TEN.Objects.ObjID.HK_ITEM] = {TEN.Objects.ObjID.HK_AMMO_ITEM},
    [TEN.Objects.ObjID.GRENADE_GUN_ITEM] = {TEN.Objects.ObjID.GRENADE_AMMO1_ITEM, TEN.Objects.ObjID.GRENADE_AMMO2_ITEM, TEN.Objects.ObjID.GRENADE_AMMO3_ITEM},
    [TEN.Objects.ObjID.HARPOON_ITEM] = {TEN.Objects.ObjID.HARPOON_AMMO_ITEM},
    [TEN.Objects.ObjID.ROCKET_LAUNCHER_ITEM] = {TEN.Objects.ObjID.ROCKET_LAUNCHER_AMMO_ITEM}
}

local AMMO_SET = {
    [TEN.Objects.ObjID.PISTOLS_AMMO_ITEM] = {slot = TEN.Objects.AmmoType.PISTOLS, weapon = TEN.Objects.ObjID.PISTOLS_ITEM}, 
    [TEN.Objects.ObjID.UZI_AMMO_ITEM] = {slot = TEN.Objects.AmmoType.UZI, weapon = TEN.Objects.ObjID.UZI_ITEM}, 
    [TEN.Objects.ObjID.SHOTGUN_AMMO1_ITEM] = {slot = TEN.Objects.AmmoType.SHOTGUN_NORMAL, weapon = TEN.Objects.ObjID.SHOTGUN_ITEM},
    [TEN.Objects.ObjID.SHOTGUN_AMMO2_ITEM] = {slot = TEN.Objects.AmmoType.SHOTGUN_WIDE, weapon = TEN.Objects.ObjID.SHOTGUN_ITEM},
    [TEN.Objects.ObjID.REVOLVER_AMMO_ITEM] = {slot = TEN.Objects.AmmoType.REVOLVER, weapon = TEN.Objects.ObjID.REVOLVER_ITEM}, 
    [TEN.Objects.ObjID.CROSSBOW_AMMO1_ITEM] = {slot = TEN.Objects.AmmoType.CROSSBOW_BOLT_NORMAL, weapon = TEN.Objects.ObjID.CROSSBOW_ITEM},
    [TEN.Objects.ObjID.CROSSBOW_AMMO2_ITEM] = {slot = TEN.Objects.AmmoType.CROSSBOW_BOLT_POISON, weapon = TEN.Objects.ObjID.CROSSBOW_ITEM},
    [TEN.Objects.ObjID.CROSSBOW_AMMO3_ITEM] = {slot = TEN.Objects.AmmoType.CROSSBOW_BOLT_EXPLOSIVE, weapon = TEN.Objects.ObjID.CROSSBOW_ITEM},
    [TEN.Objects.ObjID.HK_AMMO_ITEM] = {slot = TEN.Objects.AmmoType.HK, weapon = TEN.Objects.ObjID.HK_ITEM},
    [TEN.Objects.ObjID.GRENADE_AMMO1_ITEM] = {slot = TEN.Objects.AmmoType.GRENADE_NORMAL, weapon = TEN.Objects.ObjID.GRENADE_GUN_ITEM},
    [TEN.Objects.ObjID.GRENADE_AMMO2_ITEM] = {slot = TEN.Objects.AmmoType.GRENADE_FRAG, weapon = TEN.Objects.ObjID.GRENADE_GUN_ITEM},
    [TEN.Objects.ObjID.GRENADE_AMMO3_ITEM] = {slot = TEN.Objects.AmmoType.GRENADE_FLASH, weapon = TEN.Objects.ObjID.GRENADE_GUN_ITEM},
    [TEN.Objects.ObjID.HARPOON_AMMO_ITEM] = {slot = TEN.Objects.AmmoType.HARPOON, weapon = TEN.Objects.ObjID.HARPOON_ITEM},
    [TEN.Objects.ObjID.ROCKET_LAUNCHER_AMMO_ITEM] = {slot = TEN.Objects.AmmoType.ROCKET, weapon = TEN.Objects.ObjID.ROCKET_LAUNCHER_ITEM}

}

local HEALTH_SET = {
    [TEN.Objects.ObjID.BIGMEDI_ITEM] = HEALTH_MAX,
    [TEN.Objects.ObjID.SMALLMEDI_ITEM] = HEALTH_MAX / 2
}

local ItemActionFlags = {
    {bit = ItemAction.EQUIP, string = "equip", action = "Action"},
    {bit = ItemAction.USE, string = "use", action = "Action"},
    {bit = ItemAction.EXAMINE, string = "examine"},
    {bit = ItemAction.CHOOSE_AMMO_SHOTGUN, string = "choose_ammo"},
    {bit = ItemAction.CHOOSE_AMMO_CROSSBOW, string = "choose_ammo"},
    {bit = ItemAction.CHOOSE_AMMO_GRENADEGUN, string = "choose_ammo"},
    {bit = ItemAction.CHOOSE_AMMO_UZI, string = "choose_ammo"},
    {bit = ItemAction.CHOOSE_AMMO_PISTOLS, string = "choose_ammo"},
    {bit = ItemAction.CHOOSE_AMMO_REVOLVER, string = "choose_ammo"},
    {bit = ItemAction.LOAD, string = "load_game"},
    {bit = ItemAction.SAVE, string = "save_game"},
    {bit = ItemAction.CHOOSE_AMMO_HK, string = "choose_ammo"},
    {bit = ItemAction.STATISTICS , string = "statistics"},
    {bit = ItemAction.CHOOSE_AMMO_HARPOON, string = "choose_ammo"},
    {bit = ItemAction.CHOOSE_AMMO_ROCKET, string = "choose_ammo"},
    {bit = ItemAction.COMBINE, string = "combine", action = "Action"},
    {bit = ItemAction.SEPARATE, string = "separate"},
}

local CHOOSE_AMMO_FLAGS = {
    ItemAction.CHOOSE_AMMO_SHOTGUN,
    ItemAction.CHOOSE_AMMO_CROSSBOW,
    ItemAction.CHOOSE_AMMO_GRENADEGUN,
    ItemAction.CHOOSE_AMMO_UZI,
    ItemAction.CHOOSE_AMMO_PISTOLS,
    ItemAction.CHOOSE_AMMO_REVOLVER,
    ItemAction.CHOOSE_AMMO_HK,
    ItemAction.CHOOSE_AMMO_HARPOON,
    ItemAction.CHOOSE_AMMO_ROCKET
}

--variables
local useBinoculars = false

local itemStoreRotations = false
local itemRotation = Rotation(0, 0, 0)
local itemRotationOld = Rotation(0, 0, 0)

local examineScaler = EXAMINE_DEFAULT_SCALE
local examineShowString = false

local combineItem1 = nil
local combineItem2 = nil
local combineResult = nil
local performCombine = false
local addedItems = 0

--Structure for inventory
local inventory = {ring = {}, slice = {}, selectedItem = {}, ringPosition = {}}
local inventoryOpenItem = nil
local inventoryStart = true
local gameflowOverrides = nil
local selectedRing = RING.MAIN
local previousRing = nil
local timeInMenu = 0
local inventoryDelay = 0 --count of actual frames before inventory is opened. Used for setting the grayscale tint.
local inventoryMode = INVENTORY_MODE.RING_OPENING
local previousMode = nil
local currentRingAngle = 0
local previousRingAngle = 0
local targetRingAngle = 0
local direction = 1

local saveList = false
local saveSelected = false

local selectedAmmo = nil

LevelFuncs.Engine.CustomInventory = {}

--functions

local colorCombine = function(color, transparency)
    return Color(color.r, color.g, color.b, transparency)
end

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

local hasItemAction = function(packedFlags, flag)
    return (packedFlags & flag) ~= 0
end


local function hasChooseAmmo(menuActions)
    for _, flag in ipairs(CHOOSE_AMMO_FLAGS) do
        if hasItemAction(menuActions, flag) then
            return true
        end
    end
    return false
end


local isSingleFlagSet = function(flags)
    return flags ~= 0 and (flags & (flags - 1)) == 0
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

-- Function to display level statistics on the screen
local ShowLevelStats = function(gameStats)
    -- Retrieve current level statistics and configuration
    local levelStats = Flow.GetStatistics(gameStats)
    local level = Flow.GetCurrentLevel()

    -- Define screen positions for various UI elements using percentages
    local levelNameX, levelNameY = PercentToScreen(50, 20)   -- Position of the level name
    local headingsX, headingsY = PercentToScreen(25, 30)     -- Position of the headings
    local dataX, dataY = PercentToScreen(65, 30.5)           -- Position of the statistics data
    local controlX, controlY = PercentToScreen(50, 90)       -- Position of the control instructions
    
    -- Set color and text scale for all UI elements
    local textScale = 1                                      -- Default text scale

    -- Create and display text for the UI.
 	local headings = DisplayString("Time Taken\nSecrets\nPickups\nKills\nAmmo Used\nMedi packs used\nDistance Travelled", Vec2(headingsX, headingsY), textScale, COLOR_MAP.HEADER_FONT, false)
	local levelName = DisplayString(tostring(Flow.GetString(level.nameKey)), Vec2(levelNameX, levelNameY), textScale, textColor, false)
	local control = DisplayString("Press ACTION to continue", Vec2(controlX, controlY), textScale / 2, textColor, false)


    -- Create and display statistics values
    local stats = DisplayString(
        tostring(levelStats.timeTaken):sub(1, -4) .. "\n" ..
        tostring(Flow.GetSecretCount()) .. " / " .. tostring(level.secrets) .. "\n" ..
        tostring(levelStats.pickups) .. "\n" ..
        tostring(levelStats.kills) .. "\n" ..
        tostring(levelStats.ammoUsed) .. "\n" ..
        tostring(levelStats.healthPacksUsed) .. "\n" ..
        string.format("%.1f", levelStats.distanceTraveled / 420) .. " m",
        Vec2(dataX, dataY),
        textScale,
        COLOR_MAP.NORMAL_FONT,
        false  -- Disable translations
    )

    -- Apply text effects (e.g., centering, shadow, blink)
    levelName:SetFlags({ TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW })
    headings:SetFlags({ TEN.Strings.DisplayStringOption.SHADOW })
    stats:SetFlags({ TEN.Strings.DisplayStringOption.SHADOW })
    control:SetFlags({ TEN.Strings.DisplayStringOption.SHADOW, TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.BLINK })

    -- Display all UI elements on the screen
    ShowString(levelName, 1 / 30)
    ShowString(headings, 1 / 30)
    ShowString(stats, 1 / 30)
    ShowString(control, 1 / 30)

    -- Draw a background graphic for the stats screen
	
    -- local bg = DisplaySprite(ObjID.BAR_BORDER_GRAPHICS, 1, Vec2(50, 48), 0, Vec2(60, 60), Color(20, 157, 0, 128))
    -- bg:Draw(0, View.AlignMode.CENTER, View.ScaleMode.STRETCH, Effects.BlendID.ADDITIVE)
end

local FindItemInInventory = function(targetID)
    for ringIndex, ring in pairs(inventory.ring) do
        for itemIndex, itemEntry in ipairs(ring) do
            if itemEntry.objectID == targetID then
                return ringIndex, itemIndex
            end
        end
    end
    return nil, nil -- not found
end

local GetInventoryItem = function(itemID)
	local ringIndex, itemIndex = FindItemInInventory(itemID)
	if not ringIndex or not itemIndex then
		return nil
	end
	return inventory.ring[ringIndex][itemIndex]
end

local BuildInventoryItem = function(data)

    data.count = TEN.Inventory.GetItemCount(data.objectID)

    local override = gameflowOverrides[data.itemID] or {}

    if override.yOffset     ~= nil then data.yOffset     = override.yOffset end
    if override.scale       ~= nil then data.scale       = override.scale end
    if override.rotation    ~= nil then data.rotation    = override.rotation end
    if override.menuActions ~= nil then data.menuActions = override.menuActions end
    if override.name        ~= nil then data.name        = override.name end
    if override.meshBits    ~= nil then data.meshBits    = override.meshBits end
    if override.orientation ~= nil then data.orientation = override.orientation end
    if override.type        ~= nil then data.type        = override.type end
    if override.combine     ~= nil then data.combine     = override.combine end

    return data
end

local ReplaceInventoryItem = function(oldItemID, newItemID)

    local item = GetInventoryItem(oldItemID)
    gameflowOverrides = LevelFuncs.Engine.CustomInventory.ReadGameflow() or {}

    local itemData = PICKUP_DATA.ConvertRowData(PICKUP_DATA.GetRow(newItemID))
    local data = BuildInventoryItem(itemData)
    
    -- Store current transform before replacement
    local oldPos    = TEN.DrawItem.GetItemPosition(oldItemID)
    local oldColor  = TEN.DrawItem.GetItemColor(oldItemID)

    -- Apply updated transform while preserving old position, rotation, etc.
    TEN.DrawItem.AddItem(newItemID, oldPos, data.rotation, data.scale, data.meshBits)
    TEN.DrawItem.SetItemColor(newItemID, oldColor)

    -- Update inventory entry fields
    item = data

end

local CombineItems = function(item1, item2)
	
    for _, combo in ipairs(PICKUP_DATA.combineTable) do
		
        local a, b, result = combo[1], combo[2], combo[3]

		if (item1 == a and item2 == b) or (item1 == b and item2 == a) then

            -- Check if both items are actually present
            local count1 = TEN.Inventory.GetItemCount(item1)
            local count2 = TEN.Inventory.GetItemCount(item2)

            if count1 == 0 or count2 == 0 then
                return false
            end

            -- If the combined result is a weapon that supports lasersight, enable it
            if WEAPON_LASERSIGHT_DATA[result]
                and WEAPON_SET[result]
                and WEAPON_SET[result].slot then
                Lara:SetLaserSight(WEAPON_SET[result].slot, true)
            end

            -- Remove the original items
            TEN.Inventory.TakeItem(item1, 1)
            TEN.Inventory.TakeItem(item2, 1)

            -- Add the new combined item
            TEN.Inventory.GiveItem(result, 1)



            combineResult = result
			return true
		end
	end

	-- No valid combination found
	return false
end

local CreateRingMenu = function(ringName)
    
    local ringItems = {}
    local ring = inventory.ring[ringName]

    if ring then
        for _, itemData in ipairs(ring) do

            local text = "< " .. GetString(itemData.name) .. " >"

            table.insert(ringItems, text)
        end
    end

    local ringTable = {
        {
            itemName = "Blank",
            options = ringItems,
            currentOption = 1
        }
    }

    local text = "combine_with"

    if ringName == RING.AMMO then text = "choose_ammo" end

    local combineMenu = Menu.Create("ringMenu", text, ringTable, nil, nil, Menu.Type.OPTIONS_ONLY)

    combineMenu:SetOptionsPosition(Vec2(50, 35))
    combineMenu:SetVisibility(true)
    combineMenu:SetLineSpacing(5.3)
    combineMenu:SetOptionsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    combineMenu:EnableInputs(false)
    combineMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, nil, nil, true)

end

local ShowRingMenu = function()

    local ringMenu = Menu.Get("ringMenu")
    ringMenu:Draw()

end


local CreateSaveMenu = function(save)

    local textPosition = {
        Vec2(10, 12),
        Vec2(20, 12),
        Vec2(75, 12),
        Vec2(50, 12),
    }

    local saveTitleText = {
        nil,
        "save_game", 
        nil,
        nil
    }

    local loadTitleText = {
        nil,
        "load_game", 
        nil,
        nil
    }

    local saveFunctions = {
        nil,
        "Engine.CustomInventory.DoSave", 
        nil,
        nil
    }

    local loadFunctions = {
        nil,
        "Engine.CustomInventory.DoLoad", 
        nil,
        nil
    }

    local soundMap = {
    [1] = { select = nil, choose = nil },
    [2] = { select = SOUND_MAP.MENU_SELECT, choose = SOUND_MAP.MENU_CHOOSE },
    [3] = { select = nil, choose = nil },
    [4] = { select = nil, choose = nil}
    }

    local itemFlag = {Strings.DisplayStringOption.SHADOW}
    local selectedFlag = {Strings.DisplayStringOption.BLINK, Strings.DisplayStringOption.SHADOW}


    local itemFlags = {itemFlag, itemFlag, itemFlag, {Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER}}

    local selectedFlags = {selectedFlag, selectedFlag,  selectedFlag, {Strings.DisplayStringOption.BLINK, Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER}}

    local headers = Flow:GetSaveHeaders()

    local items = {
        [1] = {},
        [2] = {},
        [3] = {},
        [4] = {}
    }

    for i = 1, #headers do
        local h = headers[i]
        local itemText1
        local itemText2
        local itemText3
        local itemText4

        if h and h.Present then
            itemText1 = string.format("%02d", h.Count)
            itemText2 = string.format("%s", h.LevelName)
            itemText3 = string.format("%02d:%02d:%02d", h.Hours, h.Minutes, h.Seconds)
            itemText4 = ""
        else
            itemText1 = ""
            itemText2 = ""
            itemText3 = ""
            itemText4 = "empty"
        end

        table.insert(items[1], { itemName = itemText1 })
        table.insert(items[2], { itemName = itemText2 })
        table.insert(items[3], { itemName = itemText3 })
        table.insert(items[4], { itemName = itemText4 })
    end

    if save then
        for index in ipairs(items) do
            Menu.Create("SaveMenu"..index, saveTitleText[index], items[index], saveFunctions[index], nil, Menu.Type.ITEMS_ONLY)
        end 
    else
        for index in ipairs(items) do
            Menu.Create("SaveMenu"..index, loadTitleText[index], items[index], loadFunctions[index], nil, Menu.Type.ITEMS_ONLY)
        end 
    end

    for index = 1, 4 do

        local saveMenu = Menu.Get("SaveMenu"..index)
        
        local translate = false
        if index == 4 then  translate = true end
        
        saveMenu:SetItemsPosition(textPosition[index])
        saveMenu:SetTitlePosition(Vec2(50, 4))
        saveMenu:SetVisibility(true)
        saveMenu:SetLineSpacing(5.3)
        saveMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9, itemFlags[index])
        saveMenu:SetSelectedItemFlags(selectedFlags[index])
        saveMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, 1.5, nil, true)
        saveMenu:SetItemsTranslate(translate)
        saveMenu:SetSoundEffects(soundMap[index].select, soundMap[index].choose)
    end 

end

LevelFuncs.Engine.CustomInventory.DoSave = function()

    local slot = Menu.Get("SaveMenu2"):getCurrentItemIndex() -1
    Flow.SaveGame(slot)
    inventoryMode = INVENTORY_MODE.SAVE_CLOSE
    saveSelected = true

    for index = 1, 4 do
        Interpolate.Clear("SaveMenu"..index)
    end 

end

LevelFuncs.Engine.CustomInventory.DoLoad = function()

    local slot = Menu.Get("SaveMenu2"):getCurrentItemIndex() - 1

    if Flow.DoesSaveGameExist(slot) then
        Flow.LoadGame(slot)
        inventoryMode = INVENTORY_MODE.SAVE_CLOSE
        saveSelected = true
        for index = 1, 4 do
            Interpolate.Clear("SaveMenu"..index)
        end 
    else
        TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
    end

end

local RunSaveMenu = function()

    for index = 1, 4 do
        local saveMenu = Menu.Get("SaveMenu"..index)
        saveMenu:Draw()
    end 

end

local ParseMenuAction = function(menuActions)

    if hasItemAction(menuActions, ItemAction.USE) or hasItemAction(menuActions, ItemAction.EQUIP) then
        inventoryMode = INVENTORY_MODE.ITEM_USE
    elseif hasItemAction(menuActions, ItemAction.EXAMINE) then
        inventoryMode = INVENTORY_MODE.EXAMINE_OPEN
    elseif hasItemAction(menuActions, ItemAction.COMBINE) then
        inventoryMode = INVENTORY_MODE.COMBINE_SETUP
    elseif hasItemAction(menuActions, ItemAction.STATISTICS) then
        inventoryMode = INVENTORY_MODE.STATISTICS_OPEN
    elseif hasItemAction(menuActions, ItemAction.SAVE) then
        saveList = true
        inventoryMode = INVENTORY_MODE.SAVE_SETUP
    elseif hasItemAction(menuActions, ItemAction.LOAD) then
        saveList = false
        inventoryMode = INVENTORY_MODE.SAVE_SETUP
    elseif hasChooseAmmo(menuActions) then
        inventoryMode = INVENTORY_MODE.AMMO_SELECT_SETUP
    end

end

LevelFuncs.Engine.CustomInventory.DoItemAction = function()

    local menu = LevelVars.Engine.Menus["menuActions"]
    if not menu then return end

    local selectedItem = menu.items[menu.currentItem]
    if selectedItem and selectedItem.actionBit then
        ParseMenuAction(selectedItem.actionBit)
    end

end

local CreateItemMenu = function(item)

    local menuActions = {}
    local itemData = GetInventoryItem(item)
    local itemMenuActions = itemData.menuActions

    for _, entry in ipairs(ItemActionFlags) do
        if hasItemAction(itemMenuActions, entry.bit) then
            table.insert(menuActions, {
                itemName = entry.string,
                actionBit = entry.bit,
                options = nil,
                currentOption = 1
            })
        end
    end

    local itemMenu = Menu.Create("menuActions", itemData.name, menuActions, "Engine.CustomInventory.DoItemAction", nil, Menu.Type.ITEMS_ONLY)

    itemMenu:SetItemsPosition(Vec2(50, 35))
    itemMenu:SetVisibility(true)
    itemMenu:SetLineSpacing(5.3)
    itemMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    itemMenu:SetItemsTranslate(true)
    itemMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, nil, nil, true)
end

local ShowItemMenu = function()

    local itemMenu = Menu.Get("menuActions")
    itemMenu:Draw()

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

	return TEN.Input.IsKeyPulsed(actionID, DELAY, INITIAL_DELAY)
end

local GetSelectedItem = function(ring)

    return inventory.ring[ring][inventory.selectedItem[ring]]

end

local ClearInventory = function(ringName, clearDrawItems)
    
    if ringName then

        local ring = inventory.ring[ringName]

        if clearDrawItems and ring then
            for _, itemData in ipairs(ring) do
                TEN.DrawItem.RemoveItem(itemData.objectID)
            end
        end

        -- Clear only the specific ring
        inventory.ring[ringName] = {}
        inventory.slice[ringName] = nil
        inventory.selectedItem[ringName] = nil
        inventory.ringPosition[ringName] = nil

    else

        if clearDrawItems then
            TEN.DrawItem.ClearAllItems()
        end

        -- Clear entire inventory
        inventory = {ring = {}, slice = {}, selectedItem = {}, ringPosition = {}}

    end

end

local changeOptionsforMenu = function()

    if selectedRing == RING.AMMO or selectedRing == RING.COMBINE then
        
        local ringMenu = Menu.Get("ringMenu")
        ringMenu:setOptionIndexForItem(1, inventory.selectedItem[selectedRing])
        
    end

end

local doLeftKey = function()
    local inventoryTable = inventory.ring[selectedRing]
    inventory.selectedItem[selectedRing] = (inventory.selectedItem[selectedRing] % #inventoryTable) + 1
    targetRingAngle = currentRingAngle - inventory.slice[selectedRing]
    previousMode = inventoryMode
    inventoryMode = INVENTORY_MODE.RING_ROTATE
    TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)

    changeOptionsforMenu()
end

local doRightKey = function()
    local inventoryTable = inventory.ring[selectedRing]
    inventory.selectedItem[selectedRing] = ((inventory.selectedItem[selectedRing] - 2) % #inventoryTable) + 1
    targetRingAngle = currentRingAngle + inventory.slice[selectedRing]
    previousMode = inventoryMode
    inventoryMode = INVENTORY_MODE.RING_ROTATE
    TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE) 

    changeOptionsforMenu()
end

local Input = function(mode)

    if mode == INVENTORY_MODE.INVENTORY then

        if guiIsPulsed(TEN.Input.ActionID.LEFT) then
            doLeftKey()
        elseif guiIsPulsed(TEN.Input.ActionID.RIGHT) then
            doRightKey()
        elseif guiIsPulsed(TEN.Input.ActionID.FORWARD) and selectedRing < RING.COMBINE then --disable up and down keys for combine and ammo rings
            previousRing = selectedRing
            selectedRing = math.max(RING.PUZZLE, selectedRing - 1) 
            if selectedRing ~= previousRing then
                inventoryMode = INVENTORY_MODE.RING_CHANGE
                direction = 1
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            end
        elseif guiIsPulsed(TEN.Input.ActionID.BACK) and selectedRing < RING.COMBINE then --disable up and down keys for combine and ammo rings
            previousRing = selectedRing
            selectedRing = math.min(RING.OPTIONS, selectedRing + 1)
            if selectedRing ~= previousRing then
                direction = -1
                inventoryMode = INVENTORY_MODE.RING_CHANGE
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            end
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) or guiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            
            itemStoreRotations = true

            local menuActions = GetSelectedItem(selectedRing).menuActions
            --if the item has single action, proceed with direct action for items like medipack and flares.
            if isSingleFlagSet(menuActions) then  
                ParseMenuAction(menuActions)
            else
                inventoryMode = INVENTORY_MODE.ITEM_SELECT  
            end
        elseif (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) and LevelVars.Engine.CustomInventory.InventoryOpenFreeze then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            inventoryMode = INVENTORY_MODE.RING_CLOSING
        end
    elseif mode == INVENTORY_MODE.COMBINE then

        if guiIsPulsed(TEN.Input.ActionID.LEFT) then
            doLeftKey()
        elseif guiIsPulsed(TEN.Input.ActionID.RIGHT) then
            doRightKey()
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) or guiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            itemStoreRotations = true
            performCombine = true
        elseif (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            inventoryMode = INVENTORY_MODE.COMBINE_CLOSE
        end
    elseif mode == INVENTORY_MODE.STATISTICS then

        if (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.STATISTICS_CLOSE
        end
    elseif mode == INVENTORY_MODE.SAVE_MENU then

        if (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.SAVE_CLOSE
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECTED then
        if (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.ITEM_DESELECT
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT then

        if guiIsPulsed(TEN.Input.ActionID.LEFT) then
            doLeftKey()
        elseif guiIsPulsed(TEN.Input.ActionID.RIGHT) then
            doRightKey()
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) or guiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            itemStoreRotations = true
            performCombine = true
        elseif (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT_CLOSE
        end
    elseif mode == INVENTORY_MODE.EXAMINE then
         -- Static variables
        local ROTATION_MULTIPLIER = 2
        local ZOOM_MULTIPLIER = 0.3
        -- Handle rotation input
        if TEN.Input.IsKeyHeld(TEN.Input.ActionID.FORWARD) then
            itemRotation.x = itemRotation.x + ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.BACK) then
            itemRotation.x = itemRotation.x - ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT) then
            itemRotation.y = itemRotation.y + ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT) then
            itemRotation.y = itemRotation.y - ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.SPRINT) then
            examineScaler = examineScaler + (ZOOM_MULTIPLIER)
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.CROUCH) then
            examineScaler = examineScaler - (ZOOM_MULTIPLIER)
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) then
            examineShowString = not examineShowString
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
        elseif guiIsPulsed(TEN.Input.ActionID.INVENTORY) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.EXAMINE_CLOSE
        end
    else
        return
    end
end

local contains = function(tbl, value)
    for _, v in ipairs(tbl) do
    if v == value then
        return true
    end
    end
    return false
end

--Only uses combine and ammo as an option. Everything else dumps the whole inventory.
LevelFuncs.Engine.CustomInventory.ConstructObjectList = function(ringType, selectedWeapon)

    addedItems = 0
    local items  = PICKUP_DATA.constants
    gameflowOverrides = LevelFuncs.Engine.CustomInventory.ReadGameflow() or {}

    if ringType == RING.AMMO or ringType == RING.COMBINE then
        ClearInventory(ringType, true)
    else
        ClearInventory()
    end

    for _, itemRow in ipairs(items) do

        local itemData = PICKUP_DATA.ConvertRowData(itemRow)

        local data = BuildInventoryItem(itemData)

        --Check if weapon is present and skip adding ammo to main inventory ring
        if data.type == TYPE.AMMO and ringType ~= RING.AMMO then
    
            local weaponPresent = TEN.Inventory.GetItemCount(AMMO_SET[data.objectID].weapon)
            if weaponPresent ~= 0 then
                goto continue
            end

        end

        --Check if laseright is connected and adjust the meshbits and name
        if data.type == TYPE.WEAPON then
            if Lara:GetLaserSight(WEAPON_SET[data.objectID].slot) then
                data.meshBits = WEAPON_LASERSIGHT_DATA[data.objectID].MESHBITS
                data.name = WEAPON_LASERSIGHT_DATA[data.objectID].NAME
                data.menuActions = WEAPON_LASERSIGHT_DATA[data.objectID].FLAGS
            end
        end

        --ammoRing is a bool to make sure to add ammo to the ring if creating an ammo ring even if the count is zero
        local ammoRing = false
        --shouldInsert is a bool to make sure the item gets added to the ring being created
        local shouldInsert = false

        --Check if a combine ring is being created and only proceed if the item is a combine type otherwise skip to continue
        if ringType == RING.COMBINE then
            if data.combine == true then
                data.ringName = RING.COMBINE

                --skip adding the selected item
                if combineItem1 == data.objectID then
                    goto continue
                end

                --Check if lasersight is connected and if it is skip adding to the combine table
                if data.type == TYPE.WEAPON and Lara:GetLaserSight(WEAPON_SET[data.objectID].slot) then
                    goto continue
                end

                --should only insert the item if count is not zero
                shouldInsert = (data.count ~= 0)

            else
                --skip adding this item to table if the item is not a combine type
                goto continue
            end
        elseif ringType == RING.AMMO then
            --if Ammo is present for the weapon add it for the ammo ring being created for the weapon
   
            if data.type == TYPE.AMMO and WEAPON_AMMO_LOOKUP[selectedWeapon] and contains(WEAPON_AMMO_LOOKUP[selectedWeapon], data.objectID) then
                data.ringName = RING.AMMO
                ammoRing = true
                shouldInsert = true
                
                --ADD function for checking ammo type by weapon then save it in selectedAmmo

            else
                --skip adding this item to table if the item is not an ammo type 
                goto continue
            end

        else
            -- Dump all inventory, skip only if count is 0
            shouldInsert = (data.count ~= 0)
        end

        inventory.ring[data.ringName] = inventory.ring[data.ringName] or {}
        
        if debug then
            print("Item: "..Util.GetObjectIDString(data.objectID))
            print("shouldInsert: ".. tostring(shouldInsert))
            print("ammoRing: " .. tostring(ammoRing))
            print("Actions:"..tostring(menuActions))
        end

        if shouldInsert or ammoRing then
            table.insert(inventory.ring[data.ringName], data)

            TEN.DrawItem.AddItem(data.objectID, RING_CENTER[data.ringName], data.rotation, data.scale, data.meshBits)
            TEN.DrawItem.SetItemColor(data.objectID, COLOR_MAP.ITEM_COLOR)
            addedItems = addedItems + 1
        end

        ::continue::
    end

    --Calculate the slice angle and save it
    if ringType then
        local ringItems = inventory.ring[ringType] or {}
        local count = #ringItems
        inventory.selectedItem[ringType] = 1
        inventory.slice[ringType] = (count > 0) and (360 / count) or 0
        inventory.ringPosition[ringType] = RING_CENTER[ringType]
    else
        for index, ringItems in pairs(inventory.ring) do
            local count = #ringItems
            inventory.selectedItem[index] = 1
            inventory.slice[index] = (count > 0) and (360 / count) or 0
            inventory.ringPosition[index] = RING_CENTER[index]
        end
    end

end

local SetRingVisibility = function(ringName, visible)
    
    local ring = inventory.ring[ringName]

    if not ring then
        return
    end

    local itemCount = #ring

    for i = 1, itemCount do
        local currentItem = ring[i].objectID
        TEN.DrawItem.SetItemVisibility(currentItem, visible)
    end
end

local TranslateRing = function(ringName, center, radius, rotationOffset)

    local ring = inventory.ring[ringName]

    if not ring then
        return
    end

    local itemCount = #ring
    
    for i = 1, itemCount do
        local currentItem = ring[i].objectID 

        local angleDeg = (360 / itemCount) * (i - 1) +  rotationOffset
       
        local position = center:Translate(Rotation(0,angleDeg,0),radius)

        local itemRotation  = TEN.DrawItem.GetItemRotation(currentItem)

        TEN.DrawItem.SetItemPosition(currentItem, position)
        TEN.DrawItem.SetItemRotation(currentItem, Rotation(itemRotation.x, angleDeg, itemRotation.z))
    end

end

local FadeRing = function(ringName, fadeValue, omitSelectedItem)
    
    local ring = inventory.ring[ringName]

    if not ring then
        return
    end

    local itemCount = #ring
    local selectedItem = omitSelectedItem and GetSelectedItem(selectedRing).objectID

    for i = 1, itemCount do
        local currentItem = ring[i].objectID 

        if omitSelectedItem and selectedItem == currentItem then
            goto continue
        end

        local itemColor = TEN.DrawItem.GetItemColor(currentItem)
        TEN.DrawItem.SetItemColor(currentItem, colorCombine(itemColor, fadeValue))

        ::continue::
    end
end

local FadeRings = function(visible, omitSelectedRing)
    
    local fadeValue = visible and 255 or 0

    for index in pairs(inventory.ring) do
        
        if not (omitSelectedRing and index == selectedRing) then
            FadeRing(index, fadeValue, false)
            SetRingVisibility(index, visible)
        end
    end

end

local RotateItem = function(item)
    local itemRotation  = TEN.DrawItem.GetItemRotation(item)
    TEN.DrawItem.SetItemRotation(item, Rotation(itemRotation.x, (itemRotation.y + ROTATION_SPEED) % 360, itemRotation.z))
end


local OpenInventoryAtItem = function(itemID)

    if itemID == NO_VALUE then
		return
	end

    local ringIndex, itemIndex = FindItemInInventory(itemID)

    if not (ringIndex and itemIndex) then
		return
	end

    selectedRing = ringIndex
    inventory.selectedItem[ringIndex] = itemIndex
    local slice = inventory.slice[ringIndex]
	local angle = -slice * (itemIndex - 1) --this has to be a negative angle cause reasons.
    currentRingAngle = angle
    targetRingAngle = angle

    -- Position the selected ring at RING.MAIN
	local ringPosition = RING_CENTER[RING.MAIN]

	for index in pairs(inventory.ring) do
		local offset = (index - selectedRing) * RING_POSITION_OFFSET
		inventory.ringPosition[index] = Vec3(ringPosition.x, ringPosition.y + offset, ringPosition.z)
        TranslateRing(index, inventory.ringPosition[index], RING_RADIUS, angle)
	end

    --Hack for save menu loading
    if itemID == TEN.Objects.ObjID.PC_SAVE_INV_ITEM or itemID == TEN.Objects.ObjID.PC_LOAD_INV_ITEM then
        if itemID == TEN.Objects.ObjID.PC_SAVE_INV_ITEM then
            saveList = true  
        end
        saveSelected = true
    end

end

local SetupSecondaryRing = function(ringName, item)
    --used for combine and ammo rings

    previousRing = selectedRing
    combineItem1 = item or GetSelectedItem(selectedRing).objectID
    targetRingAngle = 0
    currentRingAngle = 0
    LevelFuncs.Engine.CustomInventory.ConstructObjectList(ringName, combineItem1)
    selectedRing = ringName
    CreateRingMenu(ringName)
    inventory.ringPosition[ringName] = RING_CENTER[RING.MAIN]

end

LevelFuncs.Engine.CustomInventory.ExitInventory = function()

    LevelVars.Engine.CustomInventory.InventoryOpenFreeze = false
    ClearInventory(nil, true)
    TEN.DrawItem.SetOpenInventory(NO_VALUE)
    Interpolate.ClearAll()
    View.SetFOV(80)
    Flow.SetFreezeMode(Flow.FreezeMode.NONE)
    LevelVars.Engine.CustomInventory.InventoryClosed = true
    inventoryMode = INVENTORY_MODE.RING_OPENING
    selectedRing = RING.MAIN
    TEN.DrawItem.SetInvCameraPosition(CAMERA_START)
    TEN.DrawItem.SetInvTargetPosition(TARGET_START)
    timeInMenu = 0
    saveList = false

end

LevelFuncs.Engine.CustomInventory.UpdateInventory = function()

    timeInMenu = timeInMenu + 1

    if LevelVars.Engine.CustomInventory.InventoryOpen then
        TEN.View.SetFOV(80)
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        currentRingAngle = 0
        targetRingAngle = 0
        TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_OPEN)
        LevelFuncs.Engine.CustomInventory.ConstructObjectList()
        LevelVars.Engine.CustomInventory.InventoryOpen = false
        OpenInventoryAtItem(inventoryOpenItem)
    else
        --LevelFuncs.Engine.CustomInventory.DrawInventoryText()
        Input(inventoryMode)
        --LevelFuncs.Engine.CustomInventory.ControlTexts(inventoryMode)
        LevelFuncs.Engine.CustomInventory.DrawInventory(inventoryMode)

        --Set rotation of InventoryItems like compass and stopwatch
        SetRotationInventoryItems()

    end
end

function CustomInventory.Run()
    
    if inventoryStart then
        inventoryStart = false
        LevelVars.Engine.CustomInventory = {}
        LevelVars.Engine.CustomInventory.InventoryOpen = false
        LevelVars.Engine.CustomInventory.InventoryOpenFreeze = false
        LevelVars.Engine.CustomInventory.InventoryClosed = false
        TEN.DrawItem.SetInvCameraPosition(CAMERA_START)
        TEN.DrawItem.SetInvTargetPosition(TARGET_START)
        TEN.DrawItem.SetAmbientLight(COLOR_MAP.INVENTORY_AMBIENT)

        TEN.DrawItem.SetInventoryOverride(true)
    end

    if useBinoculars then
        TEN.View.UseBinoculars()
        useBinoculars = false
    end

    local playerHp = Lara:GetHP() > 0
    local isNotUsingBinoculars = TEN.View.GetCameraType() ~= CameraType.BINOCULARS

    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.INVENTORY) or TEN.DrawItem.GetOpenInventory() ~= NO_VALUE) and not LevelVars.Engine.CustomInventory.InventoryOpen and playerHp and isNotUsingBinoculars  then
        LevelVars.Engine.CustomInventory.InventoryOpen = true
        inventoryOpenItem = TEN.DrawItem.GetOpenInventory()
        inventoryDelay = 0
    end

    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.SAVE) or TEN.DrawItem.GetOpenInventory() ~= NO_VALUE) and not LevelVars.Engine.CustomInventory.InventoryOpen and playerHp and isNotUsingBinoculars  then
        LevelVars.Engine.CustomInventory.InventoryOpen = true
        inventoryOpenItem = TEN.Objects.ObjID.PC_SAVE_INV_ITEM
        inventoryDelay = 0
    end

    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.LOAD) or TEN.DrawItem.GetOpenInventory() ~= NO_VALUE) and not LevelVars.Engine.CustomInventory.InventoryOpen and isNotUsingBinoculars  then
        LevelVars.Engine.CustomInventory.InventoryOpen = true
        inventoryOpenItem = TEN.Objects.ObjID.PC_LOAD_INV_ITEM
        inventoryDelay = 0
    end

    if LevelVars.Engine.CustomInventory.InventoryOpen == true then
        inventoryDelay = inventoryDelay + 1
        TEN.View.SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.BACKGROUND)

        if inventoryDelay >= 2 then
            TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.CustomInventory.UpdateInventory)
            Flow.SetFreezeMode(Flow.FreezeMode.FULL)
        end
    end

    
    if LevelVars.Engine.CustomInventory.InventoryClosed then
        TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.CustomInventory.UpdateInventory)
        LevelVars.Engine.CustomInventory.InventoryClosed = false
    end
end

-- Clear progress for a batch
local ClearBatchMotionProgress = function(prefix, motionTable)
    for _, motion in ipairs(motionTable) do
        local id = prefix .. motion.key
        Interpolate.Clear(id)
    end
end

-- Perform a batch of motions and apply their effects
local PerformBatchMotion = function(prefix, motionTable, time, clearProgress, ringName, item, reverse)
    local interpolated = {}
    local allComplete = true
    local omitSelectedItem = item and true or false

    for _, motion in ipairs(motionTable) do
        local id = prefix .. motion.key
        local interp = {output = motion.start, progress = PROGRESS_COMPLETE}

        if motion.start ~= motion.finish then
            local startVal = reverse and motion.finish or motion.start
            local endVal = reverse and motion.start or motion.finish
            interp = Interpolate.Calculate(id, motion.type, startVal, endVal, time, true)
        end

        interpolated[motion.key] = interp
        
        if interp.progress < PROGRESS_COMPLETE then
            allComplete = false
        end
    end

    if interpolated.ringCenter or interpolated.ringRadius or interpolated.ringAngle then
        local center = interpolated.ringCenter and interpolated.ringCenter.output or inventory.ringPosition[ringName]
        local radius = interpolated.ringRadius and interpolated.ringRadius.output or RING_RADIUS
        local angle = interpolated.ringAngle and interpolated.ringAngle.output or 0
        TranslateRing(ringName, center, radius, angle)
    end

    if interpolated.ringFade then
        FadeRing(ringName, interpolated.ringFade.output, omitSelectedItem)
    end

    if interpolated.camera then TEN.DrawItem.SetInvCameraPosition(interpolated.camera.output) end
    if interpolated.target then TEN.DrawItem.SetInvTargetPosition(interpolated.target.output) end
    if interpolated.itemColor then TEN.DrawItem.SetItemColor(item, interpolated.itemColor.output) end
    if interpolated.itemPosition then TEN.DrawItem.SetItemPosition(item, interpolated.itemPosition.output) end
    if interpolated.itemScale then TEN.DrawItem.SetItemScale(item, interpolated.itemScale.output) end
    if interpolated.itemRotation then TEN.DrawItem.SetItemRotation(item, interpolated.itemRotation.output) end

    if allComplete then
        if clearProgress then
            ClearBatchMotionProgress(prefix, motionTable)
        end
        return true
    end
end

local AnimateInventory = function(mode)

    local selectedItem = GetSelectedItem(selectedRing)

    local ringAnimation = {
        { key = "ringRadius", type = Interpolate.Type.LINEAR, start = 0, finish = RING_RADIUS },
        { key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = currentRingAngle },
        { key = "ringCenter", type = Interpolate.Type.VEC3, start = inventory.ringPosition[selectedRing], finish = inventory.ringPosition[selectedRing] },
        { key = "ringFade", type = Interpolate.Type.LINEAR, start = 0, finish = 255 },
        { key = "camera", type = Interpolate.Type.VEC3, start = CAMERA_START, finish = CAMERA_END },
        { key = "target", type = Interpolate.Type.VEC3, start = TARGET_START, finish = TARGET_END },
        }

    local useAnimation = {
        { key = "itemPosition", type = Interpolate.Type.VEC3, start = ITEM_START, finish = ITEM_END },
        { key = "itemScale", type = Interpolate.Type.LINEAR, start = selectedItem.scale, finish = examineScaler },
        { key = "itemRotation", type = Interpolate.Type.ROTATION, start = itemRotationOld, finish = itemRotation },
        }

    local examineAnimation = {
        useAnimation[1],
        useAnimation[2],
        useAnimation[3],
        { key = "ringFade", type = Interpolate.Type.LINEAR, start = ALPHA_MAX, finish = ALPHA_MIN},
        }

    local combineRingAnimation = {
        ringAnimation[1],
        ringAnimation[2],
        ringAnimation[3],
        ringAnimation[4]
        }

    local combineClose = {
        { key = "ringFade", type = Interpolate.Type.LINEAR, start = ALPHA_MAX, finish = ALPHA_MIN}
        }

    if mode == INVENTORY_MODE.RING_OPENING then

        if PerformBatchMotion("RingOpening", ringAnimation, INVENTORY_ANIM_TIME, true, selectedRing) then

            --set alpha for all rings. This is required to make items in other items visible.
            FadeRings(true, true)
            LevelVars.Engine.CustomInventory.InventoryOpenFreeze = true
            return true
        end

    elseif mode == INVENTORY_MODE.RING_CLOSING then

        --Hide other rings to ensure the closing animation looks clean.
        FadeRings(false, true)

        if PerformBatchMotion("RingClosing", ringAnimation, INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end

    elseif mode == INVENTORY_MODE.RING_CHANGE then
        
        local allMotionComplete = true

        for index in pairs(inventory.ring) do

            local oldPosition = inventory.ringPosition[index]
            local newPosition = Vec3(oldPosition.x, oldPosition.y + direction * RING_POSITION_OFFSET, oldPosition.z) 
            local motionSet = {
            { key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = 0},
            { key = "ringCenter", type = Interpolate.Type.VEC3, start = oldPosition, finish = newPosition},
            }

            if PerformBatchMotion("RingChange"..index, motionSet, INVENTORY_ANIM_TIME, true, index) then
                inventory.ringPosition[index] = newPosition
            else
                allMotionComplete = false
            end

        end
        
        if allMotionComplete then
            return true
        end
    
    elseif mode == INVENTORY_MODE.RING_ROTATE then

        local motionSet = {
            { key = "ringAngle", type = Interpolate.Type.LINEAR, start = currentRingAngle, finish = targetRingAngle},
            }

            if PerformBatchMotion("RingRotate", motionSet, INVENTORY_ANIM_TIME/4, true, selectedRing) then
                currentRingAngle = targetRingAngle
                return true
            end
        
    elseif mode == INVENTORY_MODE.EXAMINE_OPEN or mode == INVENTORY_MODE.STATISTICS_OPEN or mode == INVENTORY_MODE.SAVE_SETUP or mode == INVENTORY_MODE.COMBINE_SETUP or mode == INVENTORY_MODE.ITEM_SELECT or mode == INVENTORY_MODE.COMBINE_SUCCESS then
        
        if PerformBatchMotion("ExamineOpen", examineAnimation, INVENTORY_ANIM_TIME, true, selectedRing, selectedItem.objectID) then
            return true
        end

    elseif mode == INVENTORY_MODE.EXAMINE_CLOSE or mode == INVENTORY_MODE.STATISTICS_CLOSE or mode == INVENTORY_MODE.SAVE_CLOSE or mode == INVENTORY_MODE.ITEM_DESELECT then

        if PerformBatchMotion("ExamineClose", examineAnimation, INVENTORY_ANIM_TIME, true, selectedRing, selectedItem.objectID, true) then
            return true
        end

    elseif mode == INVENTORY_MODE.COMBINE_RING_OPENING or mode == INVENTORY_MODE.AMMO_SELECT_OPEN then

        if PerformBatchMotion("CombineRingOpening", combineRingAnimation, INVENTORY_ANIM_TIME, true, selectedRing) then
            return true
        end

    elseif mode == INVENTORY_MODE.COMBINE_CLOSE then

        local allMotionComplete = true

        for index in pairs(inventory.ring) do

            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, INVENTORY_ANIM_TIME, true, index) then
                allMotionComplete = false 
            end

        end
        
        if allMotionComplete then
            return true
        end

    elseif mode == INVENTORY_MODE.COMBINE_COMPLETE then

        local allMotionComplete = true

        for index in pairs(inventory.ring) do

            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, INVENTORY_ANIM_TIME, true, index, nil, true) then
                allMotionComplete = false 
            end

        end
        
        if allMotionComplete then
            return true
        end

    elseif mode == INVENTORY_MODE.ITEM_USE then

        if combineItem1 or PerformBatchMotion("ItemSelect", useAnimation, INVENTORY_ANIM_TIME, false, selectedRing, selectedItem.objectID) then
            if PerformBatchMotion("ItemDeselect", useAnimation, INVENTORY_ANIM_TIME, false, selectedRing, selectedItem.objectID, true) then
                FadeRings(false, true)
                if PerformBatchMotion("RingClosing", ringAnimation, INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
                    if not combineItem1 then ClearBatchMotionProgress("ItemSelect", useAnimation) end
                    ClearBatchMotionProgress("ItemDeselect", useAnimation)
                    return true
                end
            end
        end

    elseif mode == INVENTORY_MODE.AMMO_SELECT_CLOSE then

        if PerformBatchMotion("AmmoRingClosing", combineRingAnimation, INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end
    end

end

local SaveItemData = function(selectedItem)
   
    if itemStoreRotations then
        itemRotationOld =  TEN.DrawItem.GetItemRotation(selectedItem.objectID)
        itemRotation = selectedItem.rotation
        examineScaler = selectedItem.scale
        itemStoreRotations = false
    end
    
end

LevelFuncs.Engine.CustomInventory.DrawInventory = function(mode)
    
    local selectedItem = GetSelectedItem(selectedRing)

    if mode == INVENTORY_MODE.INVENTORY then
        
        RotateItem(selectedItem.objectID)
        LevelFuncs.Engine.CustomInventory.DrawItemLabel(selectedItem.objectID)

    elseif mode == INVENTORY_MODE.RING_OPENING then
        
        if AnimateInventory(mode) then

            if saveSelected then
                inventoryMode = INVENTORY_MODE.SAVE_SETUP
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
            
        end

    elseif mode == INVENTORY_MODE.RING_CLOSING then

        if AnimateInventory(mode) then

            LevelFuncs.Engine.CustomInventory.ExitInventory()

        end

    elseif mode == INVENTORY_MODE.RING_ROTATE then

        if AnimateInventory(mode) then
            currentRingAngle = targetRingAngle
            
            if previousMode then
                inventoryMode = previousMode
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end

        end

    elseif mode == INVENTORY_MODE.RING_CHANGE then

        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
            
            --reset to first item in ring
            for index, _ in ipairs(inventory.selectedItem) do
                inventory.selectedItem[index] = 1
            end

            currentRingAngle = 0
            targetRingAngle = 0

        end

    elseif mode == INVENTORY_MODE.EXAMINE_OPEN then
        
        SaveItemData(selectedItem)
        
        if combineItem1 or AnimateInventory(mode) then

            inventoryMode = INVENTORY_MODE.EXAMINE

        end

    elseif mode == INVENTORY_MODE.EXAMINE then

        LevelFuncs.Engine.CustomInventory.ExamineItem(selectedItem.objectID)

    elseif mode == INVENTORY_MODE.EXAMINE_CLOSE then
        
        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = combineItem1 and INVENTORY_MODE.ITEM_SELECTED or INVENTORY_MODE.INVENTORY
            examineShowString = false
            examineScaler = EXAMINE_DEFAULT_SCALE
        end

    elseif mode == INVENTORY_MODE.ITEM_SELECT then
        
        SaveItemData(selectedItem)

        if AnimateInventory(mode) then
            previousRingAngle = currentRingAngle
            combineItem1 = selectedItem.objectID
            CreateItemMenu(selectedItem.objectID)
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED

        end

    elseif mode == INVENTORY_MODE.ITEM_SELECTED then

        ShowItemMenu()

    elseif mode == INVENTORY_MODE.ITEM_DESELECT then
        
        if AnimateInventory(mode) then
            combineItem1 = nil
            currentRingAngle = previousRingAngle
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.STATISTICS_OPEN then
        
        SaveItemData(selectedItem)

        if combineItem1 or  AnimateInventory(mode)then
            inventoryMode = INVENTORY_MODE.STATISTICS
        end

    elseif mode == INVENTORY_MODE.STATISTICS then
        
        ShowLevelStats()

    elseif mode == INVENTORY_MODE.STATISTICS_CLOSE then

        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = combineItem1 and INVENTORY_MODE.ITEM_SELECTED or INVENTORY_MODE.INVENTORY
        end

    elseif mode == INVENTORY_MODE.SAVE_SETUP then

        SaveItemData(selectedItem)

        if combineItem1 or  AnimateInventory(mode) then
            CreateSaveMenu(saveList)
            inventoryMode = INVENTORY_MODE.SAVE_MENU
        end

    elseif mode == INVENTORY_MODE.SAVE_MENU then
        
        RunSaveMenu()

    elseif mode == INVENTORY_MODE.SAVE_CLOSE then

        if combineItem1 then
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        elseif AnimateInventory(mode) then
            if saveSelected then
                saveSelected = false
                inventoryMode = INVENTORY_MODE.RING_CLOSING
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
        end
    elseif mode == INVENTORY_MODE.COMBINE_SETUP then

        SaveItemData(selectedItem)
        if  combineItem1 or AnimateInventory(mode) then
            SetupSecondaryRing(RING.COMBINE)
            inventoryMode = INVENTORY_MODE.COMBINE_RING_OPENING
        end

    elseif mode == INVENTORY_MODE.COMBINE_RING_OPENING then
        
        if AnimateInventory(mode) then
            
            inventoryMode = INVENTORY_MODE.COMBINE

        end

    elseif mode == INVENTORY_MODE.COMBINE then
        RotateItem(selectedItem.objectID)
        LevelFuncs.Engine.CustomInventory.DrawItemLabel(selectedItem.objectID)

        ShowRingMenu()

        if performCombine then

            combineItem2 = GetSelectedItem(RING.COMBINE).objectID

            if CombineItems(combineItem1, combineItem2) then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                inventoryMode = INVENTORY_MODE.COMBINE_SUCCESS
            else
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                performCombine = false
            end
        end
    elseif mode == INVENTORY_MODE.COMBINE_SUCCESS then

        if AnimateInventory(mode) then
            ReplaceInventoryItem(combineItem1, combineResult)
            inventoryMode = INVENTORY_MODE.COMBINE_CLOSE
        end

    elseif mode == INVENTORY_MODE.COMBINE_CLOSE then
        

        if AnimateInventory(mode) then
            inventoryOpenItem = combineResult and combineResult or combineItem1
            combineItem1 = nil
            combineItem2 = nil
            combineResult = nil
            performCombine = false
            inventoryMode = INVENTORY_MODE.COMBINE_COMPLETE
            LevelVars.Engine.CustomInventory.InventoryOpen = true
        end
    elseif mode == INVENTORY_MODE.COMBINE_COMPLETE then
        

        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.ITEM_USE then
        
        
        SaveItemData(selectedItem)

        if AnimateInventory(mode) then
            
            LevelFuncs.Engine.CustomInventory.UseItem(selectedItem.objectID)

        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT_SETUP then

            SetupSecondaryRing(RING.AMMO, combineItem1)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT_OPEN

    elseif mode == INVENTORY_MODE.AMMO_SELECT_OPEN then

        SaveItemData(selectedItem)
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.AMMO_SELECT
        end

    elseif mode == INVENTORY_MODE.AMMO_SELECT then
        
        RotateItem(selectedItem.objectID)
        ShowRingMenu()

        if performCombine then
            local ammo = AMMO_SET[selectedItem.objectID]
            Lara:SetAmmoType(ammo.slot)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT_CLOSE
        end

    elseif mode == INVENTORY_MODE.AMMO_SELECT_CLOSE then
        
        if AnimateInventory(mode) then
            performCombine = false
            selectedRing = previousRing
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        end

    end
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
        LevelFuncs.Engine.CustomInventory.ExitInventory()
        return
    end

    if WEAPON_SET[item] and WaterTest(WEAPON_SET[item]) and CrawlTest(WEAPON_SET[item]) then
        
        TEN.Inventory.ClearUsedItem()

        local currentWeapon = Lara:GetWeaponType()

        --Return if flare is already equipped
        if item == TEN.Objects.ObjID.FLARE_INV_ITEM and currentWeapon == TEN.Objects.WeaponType.FLARE then
            LevelFuncs.Engine.CustomInventory.ExitInventory()
            return
        end
        
        Lara:SetWeaponType(WEAPON_SET[item].slot, true)

        if currentWeapon == WEAPON_SET[item].slot and Lara:GetHandStatus() ~= TEN.Objects.HandStatus.WEAPON_READY then
            Lara:SetHandStatus(TEN.Objects.HandStatus.WEAPON_DRAW)
        end

        if item == TEN.Objects.ObjID.FLARE_INV_ITEM then
            TEN.Inventory.TakeItem(item, 1)
        end
        
    end

    if HEALTH_SET[item] then

        TEN.Inventory.ClearUsedItem()

        local hp = Lara:GetHP()
        local poison = Lara:GetPoison()

        if hp <= 0 or hp >= HEALTH_MAX then
            if poison == 0 then
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                LevelFuncs.Engine.CustomInventory.ExitInventory()
                return
            end
        end

        local count = TEN.Inventory.GetItemCount(item)
        
        if count then
            if count ~= NO_VALUE then
                TEN.Inventory.TakeItem(item, 1)
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

    LevelFuncs.Engine.CustomInventory.ExitInventory()

end

LevelFuncs.Engine.CustomInventory.ExamineItem = function(item)
    
    examineScaler = math.max(EXAMINE_MIN_SCALE, math.min(EXAMINE_MAX_SCALE, examineScaler))

    -- Get the localized string key
    local objectName = Util.GetObjectIDString(item)
    local stringKey = objectName:lower() .. "_text"
    local localizedString = IsStringPresent(stringKey) and GetString(stringKey) or nil

    TEN.DrawItem.SetItemRotation(item, itemRotation)
    TEN.DrawItem.SetItemScale(item, examineScaler)
    
    if localizedString and examineShowString then
        local entryText = TEN.Strings.DisplayString(localizedString, percentPos(EXAMINE_TEXT_POS.x, EXAMINE_TEXT_POS.y), 1, COLOR_MAP.NORMAL_FONT, true, {Strings.DisplayStringOption.VERTICAL_CENTER, Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER})
        ShowString(entryText, 1 / 30)
    end

end

LevelFuncs.Engine.CustomInventory.DrawItemLabel = function(item)

    local entryPosInPixel = percentPos(50, 86) --Item label
    local label = GetString(GetSelectedItem(selectedRing).name)
    local count = GetSelectedItem(selectedRing).count
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
        fadeInterpolate = Interpolate.Calculate("FontFade", Interpolate.Type.LINEAR, 0, 255, INVENTORY_ANIM_TIME, true)
        if fadeInterpolate.progress >= PROGRESS_COMPLETE then
            Interpolate.Clear("FontFade")
        end
    elseif inventoryMode == INVENTORY_MODE.RING_CLOSING then
        fadeInterpolate = Interpolate.Calculate("FontFade", Interpolate.Type.LINEAR, 255, 0, INVENTORY_ANIM_TIME, true)
        if fadeInterpolate.progress >= PROGRESS_COMPLETE then
            Interpolate.Clear("FontFade")
        end
    else
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
    local color = colorCombine(entry[4], fadeInterpolate.output)

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
                    menuActions = itemID.menuAction,
                    name = itemID.name,
                    meshBits = itemID.meshBits,
                    orientation = itemID.rotationFlags
            }
        end
    end

    return overrides

end

local PerformWaterskinCombine = function(flag)

--     bool GuiController::PerformWaterskinCombine(ItemInfo* item, bool flag)
-- 	{
-- 		auto& player = GetLaraInfo(*item);

-- 		int smallLiters = player.Inventory.SmallWaterskin - 1; // How many liters in the small one?
-- 		int bigLiters = player.Inventory.BigWaterskin - 1;	  // How many liters in the big one?
-- 		int smallCapacity = 3 - smallLiters;				  // How many more liters can fit in the small one?
-- 		int bigCapacity = 5 - bigLiters;					  // How many more liters can fit in the big one?

-- 		int i;
-- 		if (flag)
-- 		{
-- 			// Big one isn't empty and the small one isn't full.
-- 			if (player.Inventory.BigWaterskin != 1 && smallCapacity)
-- 			{
-- 				i = bigLiters;

-- 				do
-- 				{
-- 					if (smallCapacity)
-- 					{
-- 						smallLiters++;
-- 						smallCapacity--;
-- 						bigLiters--;
-- 					}

-- 					i--;
-- 				} while (i);

-- 				player.Inventory.SmallWaterskin = smallLiters + 1;
-- 				player.Inventory.BigWaterskin = bigLiters + 1;
-- 				CombineObject1 = (smallLiters + 1) + (INV_OBJECT_SMALL_WATERSKIN_EMPTY - 1);
-- 				return true;
-- 			}
-- 		}
-- 		else
-- 		{
-- 			// Small one isn't empty and the big one isn't full.
-- 			if (player.Inventory.SmallWaterskin != 1 && bigCapacity)
-- 			{
-- 				i = player.Inventory.SmallWaterskin - 1;

-- 				do
-- 				{
-- 					if (bigCapacity)
-- 					{
-- 						bigLiters++;
-- 						bigCapacity--;
-- 						smallLiters--;
-- 					}

-- 					i--;
-- 				} while (i);

-- 				player.Inventory.SmallWaterskin = smallLiters + 1;
-- 				player.Inventory.BigWaterskin = bigLiters + 1;
-- 				CombineObject1 = (bigLiters + 1) + (INV_OBJECT_BIG_WATERSKIN_EMPTY - 1);
-- 				return true;
-- 			}
-- 		}

-- 		return false;
-- 	}
-- }
    function PerformWaterskinCombine(item, flag)
    local player = GetLaraInfo(item)

        local smallLiters = player.Inventory.SmallWaterskin - 1  -- How many liters in the small one?
        local bigLiters = player.Inventory.BigWaterskin - 1      -- How many liters in the big one?
        local smallCapacity = 3 - smallLiters                    -- How many more liters can fit in the small one?
        local bigCapacity = 5 - bigLiters                        -- How many more liters can fit in the big one?

        local i

        if flag then
            -- Big one isn't empty and the small one isn't full.
            if player.Inventory.BigWaterskin ~= 1 and smallCapacity > 0 then
                i = bigLiters

                while i > 0 do
                    if smallCapacity > 0 then
                        smallLiters = smallLiters + 1
                        smallCapacity = smallCapacity - 1
                        bigLiters = bigLiters - 1
                    end

                    i = i - 1
                end

                player.Inventory.SmallWaterskin = smallLiters + 1
                player.Inventory.BigWaterskin = bigLiters + 1
                CombineObject1 = (smallLiters + 1) + (INV_OBJECT_SMALL_WATERSKIN_EMPTY - 1)
                return true
            end
        else
            -- Small one isn't empty and the big one isn't full.
            if player.Inventory.SmallWaterskin ~= 1 and bigCapacity > 0 then
                i = player.Inventory.SmallWaterskin - 1

                while i > 0 do
                    if bigCapacity > 0 then
                        bigLiters = bigLiters + 1
                        bigCapacity = bigCapacity - 1
                        smallLiters = smallLiters - 1
                    end

                    i = i - 1
                end

                player.Inventory.SmallWaterskin = smallLiters + 1
                player.Inventory.BigWaterskin = bigLiters + 1
                CombineObject1 = (bigLiters + 1) + (INV_OBJECT_BIG_WATERSKIN_EMPTY - 1)
                return true
            end
        end

        return false
    end
end

LevelFuncs.Engine.CustomInventory.ControlTexts = function(inventoryMode)

    local fadeInterpolate = nil
    if inventoryMode == INVENTORY_MODE.RING_OPENING then
        fadeInterpolate = Interpolate.Calculate("FontFade", Interpolate.Type.LINEAR, 0, 255, INVENTORY_ANIM_TIME, true)
        if fadeInterpolate.progress >= PROGRESS_COMPLETE then
            Interpolate.Clear("FontFade")
        end
    elseif inventoryMode == INVENTORY_MODE.RING_CLOSING then
        fadeInterpolate = Interpolate.Calculate("FontFade", Interpolate.Type.LINEAR, 255, 0, INVENTORY_ANIM_TIME, true)
        if fadeInterpolate.progress >= PROGRESS_COMPLETE then
            Interpolate.Clear("FontFade")
        end
    else
        fadeInterpolate = {output = 255, progress = 1}
    end

    local stringTable = {}

    for _, entry in ipairs(ItemActionFlags) do
        
        if hasItemAction(GetSelectedItem(selectedRing).menuActions, entry.bit) then
            table.insert(stringTable, GetString(entry.string))
        end
    end

    local finalString = table.concat(stringTable, " ")
    local scale = 0.5
    local color = colorCombine(COLOR_MAP.NORMAL_FONT, fadeInterpolate.output)

    local entryPosInPixel = percentPos(5, 95)

    local entryText = TEN.Strings.DisplayString(finalString, entryPosInPixel, scale, color, false, {Strings.DisplayStringOption.SHADOW})
    ShowString(entryText, 1 / 30)

end

return CustomInventory