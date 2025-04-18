

return {
    {
        type = "diary",
        object = TEN.Objects.ObjID.DIARY_ITEM,
        objectIdBg = TEN.Objects.ObjID.DIARY_SPRITES,
        spriteIdBg = 0,
        colorBg = TEN.Color(255, 255, 255),
        pos = TEN.Vec2(50,47.5),
        rot = 0,
        scale = TEN.Vec2(100,95),
        alignMode = TEN.View.AlignMode.CENTER,
        scaleMode = TEN.View.ScaleMode.FIT,
        blendMode = TEN.Effects.BlendID.ALPHABLEND,
        alpha = 255,
        pageSound=369,
        exitSound=369,
        pagesToUnlock = 1
    },
    {
        type = "background",
        objectIdBg = TEN.Objects.ObjID.DIARY_SPRITES,
        spriteIdBg = 1,
        colorBg = TEN.Color(255,0, 0),
        pos = TEN.Vec2(50,50),
        rot = 0,
        scale = TEN.Vec2(100,100),
        alignMode = TEN.View.AlignMode.CENTER,
        scaleMode = TEN.View.ScaleMode.STRETCH,
        blendMode = TEN.Effects.BlendID.ALPHABLEND,
        alpha = 160
    },
    {
        type = "pageNumbers",
        pageNoType = 2,
        prefix = "Page: ",
        separator = " of ",
        textPos = TEN.Vec2(98,95),
        textOptions = {TEN.Strings.DisplayStringOption.RIGHT, TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 0.5,
        textColor = TEN.Color(255, 255, 255)
    },
    {
        type = "controls",
        string1 = "Space: Play Voice Note",
        string2 = "Left Key: Previous Page",
        string3 = "Right Key: Next Page",
        string4 = "Esc: Back",
        separator = " | ",
        textPos = TEN.Vec2(5,95),
        textOptions = {TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 0.5,
        textColor = TEN.Color(255, 255, 255)
    },
    {
        type = "notification",
        notificationTime = 3,
        objectId = TEN.Objects.ObjID.DIARY_SPRITES,
        spriteId = 2,
        color = TEN.Color(255,255,255),
        pos = TEN.Vec2(90,90),
        rot = 0,
        scale = TEN.Vec2(5,5),
        alignMode = TEN.View.AlignMode.CENTER,
        scaleMode = TEN.View.ScaleMode.FIT,
        blendMode = TEN.Effects.BlendID.ALPHABLEND,
        notificationSound = 114 
    },
    {
        type = "image",
        pageIndex = 1,
        objectId = TEN.Objects.ObjID.DIARY_ENTRY_SPRITES,
        spriteId = 0,
        color = TEN.Color(255, 255, 255),
        pos = TEN.Vec2(35,47.5),
        rot = 0,
        scale = TEN.Vec2(40,40),
        alignMode = TEN.View.AlignMode.CENTER,
        scaleMode = TEN.View.ScaleMode.FIT,
        blendMode = TEN.Effects.BlendID.ALPHABLEND
    },
    {
        type = "text",
        pageIndex = 1,
        text = "Welcome to TEN diary.",
        textPos = TEN.Vec2(52,47.5),
        textOptions = {TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 1,
        textColor = TEN.Color(255, 255, 255)
    },
    {
        type = "image",
        pageIndex = 2,
        objectId = TEN.Objects.ObjID.DIARY_ENTRY_SPRITES,
        spriteId = 1,
        color = TEN.Color(255, 255, 255),
        pos = TEN.Vec2(35,47.5),
        rot = 0,
        scale = TEN.Vec2(40,40),
        alignMode = TEN.View.AlignMode.CENTER,
        scaleMode = TEN.View.ScaleMode.FIT,
        blendMode = TEN.Effects.BlendID.ALPHABLEND
    },
    {
        type = "text",
        pageIndex = 2,
        text = "You can edit the diary by\nediting the file\nDiarySetup.lua in script\nfolder.",
        textPos = TEN.Vec2(52,10),
        textOptions = {TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 1,
        textColor = TEN.Color(128, 255, 128)
    },
    {
        type = "image",
        pageIndex = 3,
        objectId = TEN.Objects.ObjID.DIARY_ENTRY_SPRITES,
        spriteId = 2,
        color = TEN.Color(255, 255, 255),
        pos = TEN.Vec2(35,47.5),
        rot = 0,
        scale = TEN.Vec2(30,30),
        alignMode = TEN.View.AlignMode.CENTER,
        scaleMode = TEN.View.ScaleMode.FIT,
        blendMode = TEN.Effects.BlendID.ALPHABLEND
    },
    {
        type = "text",
        pageIndex = 3,
        text = "You can also use nodes\nto unlock pages.\nAdd additional text or\nimage entries.\nAdd or update narration.",
        textPos = TEN.Vec2(52,10),
        textOptions = {TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 1,
        textColor = TEN.Color(128, 255, 128)
    },
    {
        type = "image",
        pageIndex = 4,
        objectId = TEN.Objects.ObjID.DIARY_ENTRY_SPRITES,
        spriteId = 4,
        color = TEN.Color(255, 255, 255),
        pos = TEN.Vec2(25.5,40),
        rot = 0,
        scale = TEN.Vec2(15,15),
        alignMode = TEN.View.AlignMode.CENTER_BOTTOM,
        scaleMode = TEN.View.ScaleMode.FIT,
        blendMode = TEN.Effects.BlendID.ALPHABLEND
    },
    {
        type = "image",
        pageIndex = 4,
        objectId = TEN.Objects.ObjID.DIARY_ENTRY_SPRITES,
        spriteId = 5,
        color = TEN.Color(255, 255, 255),
        pos = TEN.Vec2(41.5,40),
        rot = 0,
        scale = TEN.Vec2(15,15),
        alignMode = TEN.View.AlignMode.CENTER_BOTTOM,
        scaleMode = TEN.View.ScaleMode.FIT,
        blendMode = TEN.Effects.BlendID.ALPHABLEND
    },
    {
        type = "image",
        pageIndex = 4,
        objectId = TEN.Objects.ObjID.DIARY_ENTRY_SPRITES,
        spriteId = 3,
        color = TEN.Color(255, 255, 255),
        pos = TEN.Vec2(33.5,80),
        rot = 0,
        scale = TEN.Vec2(30,30),
        alignMode = TEN.View.AlignMode.CENTER_BOTTOM,
        scaleMode = TEN.View.ScaleMode.FIT,
        blendMode = TEN.Effects.BlendID.ALPHABLEND
    },
    {
        type = "text",
        pageIndex = 4,
        text = "Funerary Mask",
        textPos = TEN.Vec2(25.5,42),
        textOptions = {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 0.3,
        textColor = TEN.Color(255, 184, 47)
    },
    {
        type = "text",
        pageIndex = 4,
        text = "Queen's Bust",
        textPos = TEN.Vec2(41.5,42),
        textOptions = {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 0.3,
        textColor = TEN.Color(255, 184, 47)
    },
    {
        type = "text",
        pageIndex = 4,
        text = "Amulet",
        textPos = TEN.Vec2(33.5,82),
        textOptions = {TEN.Strings.DisplayStringOption.CENTER, TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 0.3,
        textColor = TEN.Color(255, 184, 47)
    },
    {
        type = "text",
        pageIndex = 4,
        text = "You can create quite\ncomplex pages.\n\nThis page has 3 images\nand text.\n\nIt also has a narration\nthat can be played\nwith Space.",
        textPos = TEN.Vec2(52,10),
        textOptions = {TEN.Strings.DisplayStringOption.SHADOW},
        textScale = 1,
        textColor = TEN.Color(255, 128, 128)
    },
    {
        type = "narration",
        pageIndex = 4,
        trackName = "027",
    },
}