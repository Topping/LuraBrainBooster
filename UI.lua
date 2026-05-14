local _, LL = ...

local DEFAULT_BACKGROUND_TEXTURE = "Interface\\AddOns\\LuraBrainBooster\\Textures\\arena_background.tga"

local SLOT_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 2,
    insets = {
        left = 2,
        right = 2,
        top = 2,
        bottom = 2,
    },
}

local function ApplyPanelStyle(frame)
    frame:SetBackdrop(nil)
end

local function ApplySlotStyle(frame, active)
    frame:SetBackdrop(SLOT_BACKDROP)
    if active then
        frame:SetBackdropColor(0.035, 0.034, 0.045, 0.94)
        frame:SetBackdropBorderColor(0.92, 0.78, 0.45, 0.96)
    else
        frame:SetBackdropColor(0.025, 0.024, 0.032, 0.45)
        frame:SetBackdropBorderColor(0.28, 0.26, 0.33, 0.55)
    end
end

local function PositionSlot(slot, parent, point, layout)
    local offsetX = layout.slotOffsetX or 0
    local offsetY = layout.slotOffsetY or 0

    slot:ClearAllPoints()
    slot:SetPoint("CENTER", parent, "CENTER", (point.x or 0) + offsetX, (point.y or 0) + offsetY)
end

local function PositionBossText(fontString, parent, layout)
    fontString:ClearAllPoints()
    fontString:SetPoint("CENTER", parent, "CENTER", layout.bossTextOffsetX or 0, layout.bossTextOffsetY or 0)
end

local function MakeDraggable(addon, frame, key)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        if addon.db and not addon.db.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:SaveFramePosition(self, key)
    end)
end

function LL:CreateUI()
    self.compassSlots = {}

    local layout = self.UI_LAYOUT or {}
    local viewerSize = layout.viewerSize or 410
    local slotSize = layout.slotSize or 60
    local backgroundTexture = layout.backgroundTexture or DEFAULT_BACKGROUND_TEXTURE

    local viewer = CreateFrame("Frame", "LuraBrainBoosterFrame", UIParent, "BackdropTemplate")
    viewer:SetSize(viewerSize, viewerSize)
    ApplyPanelStyle(viewer)
    MakeDraggable(self, viewer, "viewer")
    self:RestoreFramePosition(viewer, "viewer")
    self.viewerFrame = viewer

    viewer.background = viewer:CreateTexture(nil, "ARTWORK")
    viewer.background:SetAllPoints(viewer)
    viewer.background:SetTexture(backgroundTexture)
    viewer.background:SetTexCoord(0, 1, 0, 1)

    viewer.bossText = viewer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    PositionBossText(viewer.bossText, viewer, layout)
    viewer.bossText:SetText("Boss")
    viewer.bossText:SetTextColor(1, 0.86, 0.52, 1)
    viewer.bossText:SetShadowColor(0, 0, 0, 0.9)
    viewer.bossText:SetShadowOffset(2, -2)
    viewer.bossText:SetScale(1.25)

    for i = 1, self.MAX_SLOTS do
        local marker = CreateFrame("Frame", nil, viewer, "BackdropTemplate")
        marker:SetSize(slotSize, slotSize)
        marker:EnableMouse(false)
        ApplySlotStyle(marker, true)

        marker.payload = marker:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        marker.payload:SetPoint("CENTER", marker, "CENTER", 0, 0)
        marker.payload:SetJustifyH("CENTER")
        marker.payload:SetJustifyV("MIDDLE")
        marker.payload:SetText("")

        self.compassSlots[i] = marker
    end

    self:UpdateModeDisplay()
    self:UpdateLockState()
end

function LL:UpdateModeDisplay()
    if not self.viewerFrame then
        return
    end

    local mode = self:GetMode()
    local uiLayout = self.UI_LAYOUT or {}
    local slotLayouts = uiLayout.slots or {}
    local layout = slotLayouts[mode.slots] or slotLayouts[5] or {}

    if self.viewerFrame.bossText then
        PositionBossText(self.viewerFrame.bossText, self.viewerFrame, uiLayout)
    end

    for i = 1, self.MAX_SLOTS do
        local active = i <= mode.slots and layout[i] ~= nil
        if self.compassSlots[i] then
            self.compassSlots[i]:SetShown(active)
            self.compassSlots[i]:EnableMouse(false)
            ApplySlotStyle(self.compassSlots[i], active)
            if active then
                PositionSlot(self.compassSlots[i], self.viewerFrame, layout[i], uiLayout)
            end
        end
    end

    self:UpdateStatusText()
end

function LL:UpdateStatusText()
    -- The viewer intentionally has no debug/status text; chat commands still print state changes.
end

function LL:UpdateLockState()
    -- Dragging remains controlled by /ll lock and /ll unlock without adding viewer text.
end

function LL:ShowViewer()
    if not self.viewerFrame then
        return
    end

    self.viewerFrame:Show()
    if self.db then
        self.db.shown = true
    end
end

function LL:HideViewer()
    if not self.viewerFrame then
        return
    end

    self.viewerFrame:Hide()
    if self.db then
        self.db.shown = false
    end
end

function LL:ToggleViewer()
    if self.viewerFrame and self.viewerFrame:IsShown() then
        self:HideViewer()
    else
        self:ShowViewer()
    end
end

local function RenderTexturePath(compassSlot, path)
    if compassSlot and compassSlot.payload then
        compassSlot.payload:SetFormattedText("|T%s:44:44|t", path)
    end
end

function LL:RenderValue(index, renderValue)
    local compassSlot = self.compassSlots and self.compassSlots[index]
    if not compassSlot or not compassSlot.payload then
        return
    end

    if type(renderValue) ~= "table" then
        compassSlot.payload:SetText("")
        return
    end

    if renderValue.kind == "texture" then
        RenderTexturePath(compassSlot, renderValue.path)
    elseif renderValue.kind == "rune" then
        RenderTexturePath(compassSlot, self:GetRuneTexture(renderValue.key))
    else
        compassSlot.payload:SetText("")
    end
end

function LL:ClearSlot(index)
    local compassSlot = self.compassSlots and self.compassSlots[index]
    if compassSlot and compassSlot.payload then
        compassSlot.payload:SetText("")
    end
end
