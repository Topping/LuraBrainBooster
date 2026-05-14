local _, LL = ...

LL.ADDON_NAME = "LuraBrainBooster"
LL.VERSION = "0.4.2"
LL.PREFIX = "LuraBrainBooster"

LL.MAX_SLOTS = 5
LL.AUTO_CLEAR_SECONDS = 15
LL.UNDO_RAID_WARNING_TEXT = "LL_UNDO"
LL.UNDO_MACRO_NAME = "LL Undo"
LL.UNDO_MACRO_ICON = "Interface/Buttons/UI-GroupLoot-Pass-Up"

-- Viewer layout coordinates are relative to the center of the 410x410 frame:
-- positive x moves right, positive y moves up.
LL.UI_LAYOUT = {
    viewerSize = 410,
    backgroundTexture = "Interface\\AddOns\\LuraBrainBooster\\Textures\\arena_background.png",
    slotSize = 65,

    slotOffsetX = 0,
    slotOffsetY = 0,
    bossTextOffsetX = -18,
    bossTextOffsetY = 0,

    -- Slots start at the box to the right of the tank icon, then continue clockwise.
    slots = {
        [3] = {
            { x = 116, y = 42 },
            { x = 0, y = -116 },
            { x = -116, y = 42 },
        },
        [5] = {
            { x = 78, y = 73 },
            { x = 95, y = -46 },
            { x = -18, y = -128 },
            { x = -126, y = -46 },
            { x = -113, y = 73 },
        },
    },
}

LL.MODES = {
    normal = {
        label = "Normal",
        slots = 3,
        direction = "Clockwise",
    },
    heroic = {
        label = "Heroic",
        slots = 5,
        direction = "Clockwise",
    },
    mythic = {
        label = "Mythic",
        slots = 5,
        direction = "Clockwise",
    },
}

LL.CHANNELS = {
    raid = {
        label = "Raid",
        command = "/raid",
        chatType = "RAID",
    },
    instance = {
        label = "Instance",
        command = "/i",
        chatType = "INSTANCE_CHAT",
    },
    party = {
        label = "Party",
        command = "/party",
        chatType = "PARTY",
    },
}

LL.RUNE_DEFS = {
    {
        key = "circle",
        label = "Circle",
        macroName = "LL Circle",
        macroIcon = "Interface/AddOns/LuraBrainBooster/Textures/circle.png",
        chat = "Interface/AddOns/LuraBrainBooster/Textures/circle.png",
        aliases = { "orange", "o" },
    },
    {
        key = "cross",
        label = "X",
        macroName = "LL X",
        macroIcon = "Interface/AddOns/LuraBrainBooster/Textures/x.png",
        chat = "Interface/AddOns/LuraBrainBooster/Textures/x.png",
        aliases = { "x" },
    },
    {
        key = "diamond",
        label = "Diamond",
        macroName = "LL Diamond",
        macroIcon = "Interface/AddOns/LuraBrainBooster/Textures/diamond.png",
        chat = "Interface/AddOns/LuraBrainBooster/Textures/diamond.png",
        aliases = { "square" },
    },
    {
        key = "t",
        label = "T",
        macroName = "LL T",
        macroIcon = "Interface/AddOns/LuraBrainBooster/Textures/t.png",
        chat = "Interface/AddOns/LuraBrainBooster/Textures/t.png",
        aliases = { "tee", "skull" },
    },
    {
        key = "triangle",
        label = "Triangle",
        macroName = "LL Triangle",
        macroIcon = "Interface/AddOns/LuraBrainBooster/Textures/triangle.png",
        chat = "Interface/AddOns/LuraBrainBooster/Textures/triangle.png",
        aliases = { "tri" },
    },
}

LL.ENCOUNTER_NAMES = {
    ["midnight falls"] = true,
    ["l'ura"] = true,
}

LL.DEFAULTS = {
    locked = true,
    shown = true,
    mode = "heroic",
    channel = "raid",
    strategy = "texture",
    testListen = false,
    autoClearSeconds = LL.AUTO_CLEAR_SECONDS,
    positions = {
        viewer = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 140,
        },
    },
}
