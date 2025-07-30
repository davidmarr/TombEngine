local inventoryData = require("Levels.Item_Drawing_Test")

Ring = {}

function Ring.SetRingVisibility(ringName, visible)
    
    local ring = inventoryData.ring[ringName]

    if not ring then
        return
    end

    local itemCount = #ring

    for i = 1, itemCount do
        local currentItem = ring[i].item
        TEN.DrawItem.SetItemVisibility(currentItem, visible)
    end
end

function Ring.TranslateRing(ringName, center, radius, rotationOffset)

    local ring = inventoryData.ring[ringName]

    if not ring then
        return
    end

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

function Ring.FadeRing(ringName, fadeValue, omitSelectedItem)
    
    local ring = inventoryData.ring[ringName]

    if not ring then
        return
    end

    local itemCount = #ring
    local selectedItem = omitSelectedItem and GetSelectedItem(selectedRing).item

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

function Ring.FadeRings(visible, omitSelectedRing)
    
    local fadeValue = visible and 255 or 0

    for index in pairs(inventoryData.ring) do
        
        if not (omitSelectedRing and index == selectedRing) then
            Ring.FadeRing(index, fadeValue, false)
            Ring.SetRingVisibility(index, visible)
        end
    end

end

return Ring