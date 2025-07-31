local CustomInventory = require("Engine.CustomInventory")


LevelFuncs.OnStart = function()

    local stats = Flow.GetStatistics()
    stats.timeTaken = Time({9,40,36}) 
    Flow.SetStatistics(stats)

    CustomInventory.Intialize()

end

LevelFuncs.OnFreeze = function()

    --LevelFuncs.DrawCursor()
    --LevelFuncs.AdjustCamera()
end

--required for positioning the inventory --Temporary function
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

    if TEN.Input.IsKeyHit(TEN.Input.ActionID.TAB) then
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

    if TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT) then
            vector.x = vector.x - 2
    elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT) then
            vector.x = vector.x + 2
    elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.FORWARD) then
            vector.z = vector.z + 2
    elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.BACK) then
            vector.z = vector.z - 2
    elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.STEP_LEFT) then
            vector.y = vector.y - 2
    elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.STEP_RIGHT) then
            vector.y = vector.y + 2
    elseif TEN.Input.IsKeyHit(TEN.Input.ActionID.R) then

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

LevelFuncs.DrawCursor = function() --Temporary function

    local pos = TEN.View.GetMouseDisplayPosition()
	
	local myTextString = "X: " .. pos.x.." Y: "..pos.y
	local myText = DisplayString(myTextString, 10, 10, Color.new(64,250,60))
	TEN.ShowString(myText,1/30)

	local entrySprite = TEN.DisplaySprite(TEN.Objects.ObjID.SKY_GRAPHICS, 0, TEN.Vec2(pos.x,pos.y), 0, TEN.Vec2(5,5), TEN.Color(255,128,255))
    entrySprite:Draw(8, View.AlignMode.TOP_LEFT, View.ScaleMode.FIT, TEN.Effects.BlendID.OPAQUE)

end
