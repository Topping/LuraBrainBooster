local _, LL = ...

local PANEL_NAME = "L'ura Brain Booster"
local LEFT = 24
local TOP = -24
local ROW = 34
local SECTION_GAP = 18
local CONTENT_WIDTH = 640
local BOTTOM_PADDING = 40
local SETUP_LABEL_WIDTH = 120
local SETUP_DROPDOWN_WIDTH = 120

local PLAYER_STRATEGY_DESCRIPTIONS = {
    texture = "Recommended. The caller presses the LL rune macros, and everyone sees the symbols appear in order.",
    ping = "Alternate setup. The caller uses ping macros instead of raid or party chat. Only use this if your group has tested it.",
}

local function AddText(parent, text, x, y, template)
    local fontString = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fontString:SetJustifyH("LEFT")
    fontString:SetText(text)
    return fontString
end

local function AddSection(parent, text, y)
    local title = AddText(parent, text, LEFT, y, "GameFontNormalLarge")
    title:SetTextColor(1, 0.82, 0.45)
    return y - 28
end

local function SetControlText(control, text)
    if control.Text then
        control.Text:SetText(text)
        return control.Text
    end

    local label = control:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", control, "RIGHT", 4, 0)
    label:SetText(text)
    control.Text = label
    return label
end

local function AddCheckbox(parent, label, x, y, onClick)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    SetControlText(checkbox, label)
    checkbox:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
    end)
    return checkbox
end

local function AddButton(parent, label, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width or 160, 24)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function AddSlider(parent, name, x, y, onValueChanged)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(240)
    slider:SetMinMaxValues((LL.MIN_UI_SCALE or 0.5) * 100, (LL.MAX_UI_SCALE or 1.25) * 100)
    slider:SetValueStep(5)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    local text = _G[name .. "Text"]
    if low then
        low:SetText(tostring((LL.MIN_UI_SCALE or 0.5) * 100) .. "%")
    end
    if high then
        high:SetText(tostring((LL.MAX_UI_SCALE or 1.25) * 100) .. "%")
    end
    if text then
        text:SetText("Viewer Scale")
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if self.settingValue then
            return
        end

        value = math.floor((value or 100) + 0.5)
        onValueChanged(value)
    end)
    return slider
end

local function AddDropdown(parent, name, label, x, y, width, getOptions, getValue, setValue)
    AddText(parent, label, x, y + 4, "GameFontNormal")

    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x + SETUP_LABEL_WIDTH, y + 8)
    UIDropDownMenu_SetWidth(dropdown, width or 150)
    if UIDropDownMenu_JustifyText then
        UIDropDownMenu_JustifyText(dropdown, "LEFT")
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local selected = getValue()
        for _, option in ipairs(getOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.value
            info.checked = option.value == selected
            info.func = function()
                setValue(option.value)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dropdown.Refresh = function(self)
        local selected = getValue()
        local selectedLabel = selected
        for _, option in ipairs(getOptions()) do
            if option.value == selected then
                selectedLabel = option.label
                break
            end
        end
        UIDropDownMenu_SetText(self, selectedLabel)
        if UIDropDownMenu_JustifyText then
            UIDropDownMenu_JustifyText(self, "LEFT")
        end
    end

    return dropdown
end

local function GetModeOptions()
    return {
        { value = "normal", label = LL.MODES.normal.label },
        { value = "heroic", label = LL.MODES.heroic.label },
        { value = "mythic", label = LL.MODES.mythic.label },
    }
end

local function GetChannelOptions()
    return {
        { value = "raid", label = LL.CHANNELS.raid.label },
        { value = "instance", label = LL.CHANNELS.instance.label },
        { value = "party", label = LL.CHANNELS.party.label },
    }
end

local function GetStrategyOptions()
    local options = {}
    for _, key in ipairs(LL.STRATEGY_ORDER or {}) do
        local strategy = LL.STRATEGIES and LL.STRATEGIES[key]
        if strategy then
            options[#options + 1] = {
                value = key,
                label = strategy.label or key,
            }
        end
    end
    return options
end

local function AddRuneButtons(parent, y)
    local x = LEFT
    for _, rune in ipairs(LL.RUNE_DEFS or {}) do
        AddButton(parent, rune.label, x, y, 96, function()
            LL:AppendTestRune(rune.key)
        end)
        x = x + 104
    end
end

local function SetWrappedText(fontString, text)
    if not fontString then
        return
    end

    fontString:SetText(text or "")
end

local function GetPlayerStrategyDescription(strategyKey, strategy)
    return PLAYER_STRATEGY_DESCRIPTIONS[strategyKey]
        or (strategy and strategy.description)
        or ""
end

function LL:RefreshSettingsPanel()
    local controls = self.settingsControls
    if not controls or not self.db then
        return
    end

    if controls.showViewer then
        controls.showViewer:SetChecked(self.viewerFrame and self.viewerFrame:IsShown())
    end
    if controls.lockViewer then
        controls.lockViewer:SetChecked(self.db.locked)
    end
    if controls.testListen then
        controls.testListen:SetChecked(self.db.testListen)
    end
    if controls.scaleSlider then
        controls.scaleSlider.settingValue = true
        controls.scaleSlider:SetValue(math.floor(self:GetUIScale() * 100 + 0.5))
        controls.scaleSlider.settingValue = nil
    end
    if controls.modeDropdown then
        controls.modeDropdown:Refresh()
    end
    if controls.channelDropdown then
        controls.channelDropdown:Refresh()
    end
    if controls.strategyDropdown then
        controls.strategyDropdown:Refresh()
    end
    if controls.channelNote then
        local strategy = self:GetStrategy()
        controls.channelNote:SetShown(strategy and strategy.usesChannel == false)
    end
    if controls.strategyDescription then
        local strategyKey = self:GetStrategyKey()
        local strategy = self:GetStrategy()
        SetWrappedText(controls.strategyDescription, GetPlayerStrategyDescription(strategyKey, strategy))
    end
    if controls.strategyMatchNote then
        local strategy = self:GetStrategy()
        controls.strategyMatchNote:SetShown(strategy and strategy.requiresMatchingStrategy == true)
    end
end

function LL:CreateSettingsPanel()
    local panel = CreateFrame("Frame")
    panel.name = PANEL_NAME

    local scrollFrame = CreateFrame("ScrollFrame", LL.ADDON_NAME .. "SettingsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)

    local content = CreateFrame("Frame", LL.ADDON_NAME .. "SettingsContent", scrollFrame)
    content:SetSize(CONTENT_WIDTH, 1)
    scrollFrame:SetScrollChild(content)

    panel.scrollFrame = scrollFrame
    panel.content = content

    local controls = {}
    self.settingsControls = controls

    local y = TOP
    AddText(content, PANEL_NAME, LEFT, y, "GameFontNormalHuge")
    y = y - 38

    y = AddSection(content, "Viewer", y)
    controls.showViewer = AddCheckbox(content, "Show viewer", LEFT, y, function(checked)
        if checked then
            LL:ShowViewer()
        else
            LL:HideViewer()
        end
    end)
    controls.lockViewer = AddCheckbox(content, "Lock viewer", LEFT + 190, y, function(checked)
        LL:SetLocked(checked, true)
    end)
    y = y - ROW

    controls.scaleSlider = AddSlider(content, LL.ADDON_NAME .. "SettingsScaleSlider", LEFT, y - 6, function(value)
        LL:SetUIScalePercent(value, true)
    end)
    y = y - 46

    AddButton(content, "Reset Scale", LEFT, y, 120, function()
        LL:SetUIScalePercent((LL.DEFAULT_UI_SCALE or 1.0) * 100, true)
    end)
    y = y - ROW - SECTION_GAP

    y = AddSection(content, "Encounter Setup", y)
    controls.modeDropdown = AddDropdown(content, LL.ADDON_NAME .. "ModeDropdown", "Difficulty", LEFT, y, SETUP_DROPDOWN_WIDTH, GetModeOptions, function()
        return LL.db and LL.db.mode or "heroic"
    end, function(value)
        LL:SetMode(value, true)
    end)
    y = y - ROW

    controls.channelDropdown = AddDropdown(content, LL.ADDON_NAME .. "ChannelDropdown", "Macro Channel", LEFT, y, SETUP_DROPDOWN_WIDTH, GetChannelOptions, function()
        return LL.db and LL.db.channel or "raid"
    end, function(value)
        LL:SetChannel(value, true)
    end)
    y = y - ROW

    controls.strategyDropdown = AddDropdown(content, LL.ADDON_NAME .. "StrategyDropdown", "Strategy", LEFT, y, SETUP_DROPDOWN_WIDTH, GetStrategyOptions, function()
        return LL:GetStrategyKey()
    end, function(value)
        LL:SetStrategy(value, true)
    end)
    y = y - 30

    controls.channelNote = AddText(content, "The selected strategy ignores macro channel settings.", LEFT + 150, y, "GameFontDisableSmall")
    y = y - 22

    controls.strategyDescription = AddText(content, "", LEFT, y, "GameFontHighlightSmall")
    controls.strategyDescription:SetWidth(560)
    y = y - 34

    controls.strategyMatchNote = AddText(content, "Important: everyone in the raid should pick the same strategy, or some players may not receive the caller's symbols.", LEFT, y, "GameFontNormalSmall")
    controls.strategyMatchNote:SetWidth(560)
    y = y - ROW - SECTION_GAP

    y = AddSection(content, "Caller Macros", y)
    AddButton(content, "Create / Update Macros", LEFT, y, 190, function()
        LL:CreateCallerMacros()
    end)
    AddButton(content, "Print Macro Text", LEFT + 202, y, 150, function()
        LL:PrintMacroText()
    end)
    y = y - ROW

    local helper = AddText(content, "Open /macro and drag LL Circle, LL X, LL Diamond, LL T, LL Triangle, and LL Undo to the caller's action bar.", LEFT, y, "GameFontHighlightSmall")
    helper:SetWidth(560)
    y = y - 42 - SECTION_GAP

    y = AddSection(content, "Testing", y)
    controls.testListen = AddCheckbox(content, "Listen outside the encounter, except unrelated instances", LEFT, y, function(checked)
        LL:SetTestListening(checked)
    end)
    y = y - ROW

    AddButton(content, "Run Demo", LEFT, y, 120, function()
        LL:RunDemoSequence()
    end)
    AddButton(content, "Clear Sequence", LEFT + 132, y, 130, function()
        LL:ResetSequence("slash")
    end)
    y = y - ROW

    AddText(content, "Add one local test rune:", LEFT, y + 4, "GameFontNormal")
    y = y - ROW
    AddRuneButtons(content, y)

    content:SetHeight(math.abs(y) + ROW + BOTTOM_PADDING)

    panel:SetScript("OnSizeChanged", function(self, width)
        if self.content then
            self.content:SetWidth(math.max(CONTENT_WIDTH, (width or CONTENT_WIDTH) - 36))
        end
    end)

    panel:SetScript("OnShow", function()
        LL:RefreshSettingsPanel()
    end)

    return panel
end

function LL:RegisterSettingsPanel()
    if self.settingsCategory then
        return
    end

    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        self:Print("Native settings panel is unavailable on this client. Use /ll help for commands.")
        return
    end

    local panel = self:CreateSettingsPanel()
    local category = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME)
    category.ID = self.ADDON_NAME
    Settings.RegisterAddOnCategory(category)

    self.settingsPanel = panel
    self.settingsCategory = category
    self:RefreshSettingsPanel()
end
