local _, LL = ...

local function CopyDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function LL:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffb58cffLura Brain Booster:|r " .. tostring(message))
    end
end

function LL:GetMode()
    local mode = self.db and self.db.mode or "heroic"
    return self.MODES[mode] or self.MODES.heroic
end

function LL:GetSlotCount()
    return self:GetMode().slots
end

local function FormatScalePercent(scale)
    return tostring(math.floor((scale or 1) * 100 + 0.5))
end

function LL:GetUIScale()
    local scale = self.db and self.db.uiScale

    if type(scale) == "number"
        and scale >= (self.MIN_UI_SCALE or 0.5)
        and scale <= (self.MAX_UI_SCALE or 1.25) then
        return scale
    end

    return self.DEFAULT_UI_SCALE or 1.0
end

function LL:ApplyUIScale()
    if self.viewerFrame then
        self.viewerFrame:SetScale(self:GetUIScale())
    end
end

function LL:PrintUIScale()
    local minPercent = FormatScalePercent(self.MIN_UI_SCALE or 0.5)
    local maxPercent = FormatScalePercent(self.MAX_UI_SCALE or 1.25)

    self:Print("Viewer scale is " .. FormatScalePercent(self:GetUIScale()) .. "%. Use /ll scale " .. minPercent .. "-" .. maxPercent .. ", or /ll scale reset.")
end

function LL:SetUIScalePercent(percent, silent)
    local minScale = self.MIN_UI_SCALE or 0.5
    local maxScale = self.MAX_UI_SCALE or 1.25
    local minPercent = minScale * 100
    local maxPercent = maxScale * 100

    if type(percent) ~= "number" or percent < minPercent or percent > maxPercent then
        self:Print("Invalid scale. Use a number from " .. FormatScalePercent(minScale) .. " to " .. FormatScalePercent(maxScale) .. ", or /ll scale reset.")
        return
    end

    self.db.uiScale = percent / 100
    self:ApplyUIScale()
    self:RefreshSettingsPanel()
    if not silent then
        self:Print("Viewer scale set to " .. FormatScalePercent(self.db.uiScale) .. "%.")
    end
end

function LL:GetChannel()
    local channel = self.db and self.db.channel or "raid"
    return self.CHANNELS[channel] or self.CHANNELS.raid
end

function LL:GetStrategyKey()
    local key = self.db and self.db.strategy or self.DEFAULTS.strategy or "texture"
    if self.STRATEGIES and self.STRATEGIES[key] then
        return key
    end

    return self.DEFAULTS.strategy or "texture"
end

function LL:GetStrategy()
    local key = self:GetStrategyKey()
    if self.STRATEGIES and self.STRATEGIES[key] then
        return self.STRATEGIES[key]
    end

    return self.STRATEGIES and self.STRATEGIES.texture
end

function LL:GetRuneTexture(runeOrKey)
    local rune = runeOrKey
    if type(runeOrKey) ~= "table" then
        rune = self:FindRune(runeOrKey)
    end

    return rune and (rune.texture or rune.chat)
end

function LL:GetRuneMacroText(rune)
    local strategy = self:GetStrategy()
    if strategy and strategy.BuildRuneMacroText then
        return strategy.BuildRuneMacroText(self, rune, self:GetChannel())
    end

    return self:GetChannel().command .. " " .. rune.chat
end

function LL:GetRuneMacroName(rune)
    return rune.macroName or ("LL " .. rune.label)
end

function LL:GetUndoMacroText()
    local strategy = self:GetStrategy()
    if strategy and strategy.BuildUndoMacroText then
        return strategy.BuildUndoMacroText(self, self:GetChannel())
    end

    return "/rw " .. self.UNDO_RAID_WARNING_TEXT
end

function LL:GetMacroIcon(icon)
    if not icon then
        return 134400
    end

    if GetFileIDFromPath then
        local fileID = GetFileIDFromPath(icon)
        if fileID then
            return fileID
        end

        fileID = GetFileIDFromPath(icon:gsub("/", "\\"))
        if fileID then
            return fileID
        end
    end

    return icon
end

local function NormalizeLookupText(value)
    if type(value) ~= "string" then
        return nil
    end

    local normalized = string.lower(value)
    normalized = normalized:gsub("[^%w]+", "")

    if normalized == "" then
        return nil
    end

    return normalized
end

function LL:IsTargetRaidInstance()
    if not GetInstanceInfo then
        return false
    end

    local instanceName, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "raid" then
        return false
    end

    if self.TARGET_RAID_INSTANCE_IDS and instanceID and self.TARGET_RAID_INSTANCE_IDS[instanceID] then
        return true
    end

    local normalizedName = NormalizeLookupText(instanceName)
    return normalizedName
        and self.TARGET_RAID_INSTANCE_NAMES
        and self.TARGET_RAID_INSTANCE_NAMES[normalizedName] == true
end

function LL:IsMidnightFallsEncounter(encounterID, encounterName)
    if self.ENCOUNTER_IDS and encounterID and self.ENCOUNTER_IDS[encounterID] then
        return true
    end

    if type(encounterName) == "string" then
        local normalized = string.lower(encounterName)
        return self.ENCOUNTER_NAMES[normalized] == true
    end

    return false
end

local LOCATION_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
}

local ENCOUNTER_EVENTS = {
    "ENCOUNTER_START",
    "ENCOUNTER_END",
}

function LL:RegisterLocationEvents()
    if self.locationEventsRegistered then
        return
    end

    for _, event in ipairs(LOCATION_EVENTS) do
        self.eventFrame:RegisterEvent(event)
    end

    self.locationEventsRegistered = true
end

function LL:SetEncounterTrackingEnabled(enabled)
    enabled = not not enabled

    if self.encounterTrackingEnabled == enabled then
        return
    end

    for _, event in ipairs(ENCOUNTER_EVENTS) do
        if enabled then
            self.eventFrame:RegisterEvent(event)
        else
            self.eventFrame:UnregisterEvent(event)
        end
    end

    self.encounterTrackingEnabled = enabled
end

function LL:RefreshEncounterTracking()
    self:SetEncounterTrackingEnabled(self.inTargetRaid or self.inEncounter)
end

function LL:UpdateTargetRaidState()
    local wasInTargetRaid = self.inTargetRaid
    self.inTargetRaid = self:IsTargetRaidInstance()

    if wasInTargetRaid and not self.inTargetRaid and self.inEncounter then
        self.inEncounter = false
        self:ResetSequence("zone")
    end

    self:RefreshEncounterTracking()
    self:RefreshListening()
end

function LL:UnregisterStrategyEvents()
    if not self.registeredStrategyEvents then
        return
    end

    for _, event in ipairs(self.registeredStrategyEvents) do
        self.eventFrame:UnregisterEvent(event)
    end

    self.registeredStrategyEvents = nil
    self.registeredStrategyEventSet = nil
end

function LL:RegisterStrategyEvents()
    self:UnregisterStrategyEvents()

    local strategy = self:GetStrategy()
    if not strategy or not strategy.events then
        return
    end

    self.registeredStrategyEvents = {}
    self.registeredStrategyEventSet = {}

    for _, event in ipairs(strategy.events) do
        if not self.registeredStrategyEventSet[event] then
            self.eventFrame:RegisterEvent(event)
            self.registeredStrategyEvents[#self.registeredStrategyEvents + 1] = event
            self.registeredStrategyEventSet[event] = true
        end
    end
end

function LL:RefreshListening()
    local shouldListen = self.inEncounter or (self.db and self.db.testListen)

    if shouldListen then
        self:RegisterStrategyEvents()
    else
        self:UnregisterStrategyEvents()
    end

    self:UpdateStatusText()
end

function LL:SetTestListening(enabled)
    self.db.testListen = not not enabled
    self:RefreshListening()
    self:RefreshSettingsPanel()
end

function LL:AppendRenderValue(renderValue, forceLocal)
    if not forceLocal and not (self.inEncounter or (self.db and self.db.testListen)) then
        return
    end

    local maxSlots = self:GetSlotCount()
    if self.sequenceCount >= maxSlots then
        self:ArmAutoClear()
        return
    end

    self.sequenceCount = self.sequenceCount + 1
    self:RenderValue(self.sequenceCount, renderValue)
    self:ShowViewer()
    self:ArmAutoClear()
    self:UpdateStatusText()
end

function LL:FindRune(value)
    local normalized = string.lower(value or "")
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")

    for i, rune in ipairs(self.RUNE_DEFS) do
        if normalized == tostring(i)
            or normalized == rune.key
            or normalized == string.lower(rune.label) then
            return rune
        end

        if rune.aliases then
            for _, alias in ipairs(rune.aliases) do
                if normalized == alias then
                    return rune
                end
            end
        end
    end
end

function LL:AppendTestRune(value)
    local rune = self:FindRune(value)
    if not rune then
        self:Print("Unknown rune. Use circle, cross, diamond, t, triangle, or 1-5.")
        return
    end

    local strategy = self:GetStrategy()
    local renderValue = strategy and strategy.BuildTestRenderValue and strategy.BuildTestRenderValue(self, rune)
    if not renderValue then
        self:Print("The selected strategy does not support local test runes.")
        return
    end

    self:AppendRenderValue(renderValue, true)
end

function LL:GetGroupChatType()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid and IsInRaid() then
        return "RAID"
    end

    if IsInGroup and IsInGroup() then
        return "PARTY"
    end
end

function LL:SendTestRune(value)
    local rune = self:FindRune(value)
    if not rune then
        self:Print("Unknown rune. Use circle, x, diamond, t, triangle, or 1-5.")
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self:Print("/ll send is only for out-of-combat testing. Use direct macros during the fight.")
        return
    end

    local strategy = self:GetStrategy()
    local message = strategy and strategy.BuildSendMessage and strategy.BuildSendMessage(self, rune)
    if not message then
        self:Print("The selected strategy does not support /ll send group transport.")
        return
    end

    local chatType = self:GetGroupChatType()
    if not chatType then
        self:AppendTestRune(value)
        self:Print("Not in a group, so this was shown locally only.")
        return
    end

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, chatType)
    elseif SendChatMessage then
        SendChatMessage(message, chatType)
    else
        self:Print("No chat send API is available on this client.")
        return
    end

    self:Print("Sent " .. rune.label .. " with " .. strategy.label .. " to " .. chatType .. " for transport testing. Listeners accept this only from the group leader or a raid assistant.")
end

function LL:SetChannel(channel, silent)
    channel = string.lower(channel or "")

    if not self.CHANNELS[channel] then
        self:Print("Unknown channel. Use raid, instance, or party.")
        return
    end

    self.db.channel = channel

    if not silent then
        self:Print("Macro channel set to " .. self.CHANNELS[channel].label .. " (" .. self.CHANNELS[channel].command .. ").")
    end
    local strategy = self:GetStrategy()
    if strategy and strategy.usesChannel == false and not silent then
        self:Print("The selected " .. strategy.label .. " strategy ignores channel settings.")
    end

    self:UpdateStatusText()
    self:RefreshSettingsPanel()
end

function LL:ListStrategies()
    local currentKey = self:GetStrategyKey()
    local current = self:GetStrategy()

    if current then
        self:Print("Current strategy: " .. current.label .. " (" .. currentKey .. ").")
    end

    self:Print("Available strategies:")
    for _, key in ipairs(self.STRATEGY_ORDER or {}) do
        local strategy = self.STRATEGIES[key]
        if strategy then
            local selected = key == currentKey and "* " or "  "
            local safety = strategy.encounterSafe and "encounter-safe" or "experimental"
            self:Print(selected .. key .. " - " .. strategy.label .. " (" .. safety .. "): " .. strategy.description)
        end
    end
end

function LL:SetStrategy(strategy, silent)
    strategy = string.lower(strategy or "")
    strategy = strategy:gsub("^%s+", ""):gsub("%s+$", "")

    if strategy == "" then
        self:ListStrategies()
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self:Print("Strategy changes are blocked in combat.")
        return
    end

    if self.inEncounter then
        self:Print("Strategy changes are blocked during the encounter.")
        return
    end

    if not self.STRATEGIES or not self.STRATEGIES[strategy] then
        self:Print("Unknown strategy. Use /ll strategy to list options.")
        return
    end

    if self.db and self.db.strategy == strategy then
        self:Print("Strategy is already set to " .. self.STRATEGIES[strategy].label .. ".")
        return
    end

    self.db.strategy = strategy
    self:ResetSequence("strategy")
    self:RefreshListening()
    self:RefreshSettingsPanel()
    if not silent then
        self:Print("Strategy set to " .. self.STRATEGIES[strategy].label .. ". Run /ll macros to update caller macros.")
    end
end

function LL:BuildMacroSpecs()
    local specs = {}

    for _, rune in ipairs(self.RUNE_DEFS) do
        specs[#specs + 1] = {
            name = self:GetRuneMacroName(rune),
            icon = self:GetMacroIcon(rune.macroIcon or self:GetRuneTexture(rune)),
            body = self:GetRuneMacroText(rune),
        }
    end

    specs[#specs + 1] = {
        name = self.UNDO_MACRO_NAME,
        icon = self:GetMacroIcon(self.UNDO_MACRO_ICON),
        body = self:GetUndoMacroText(),
    }

    return specs
end

function LL:GetMacroIndex(name)
    if not GetMacroIndexByName then
        return 0
    end

    local index = GetMacroIndexByName(name)
    if type(index) == "number" then
        return index
    end

    return 0
end

function LL:CreateOrUpdateMacro(spec)
    local index = self:GetMacroIndex(spec.name)

    if index > 0 then
        EditMacro(index, spec.name, spec.icon, spec.body)
        return "updated"
    end

    CreateMacro(spec.name, spec.icon, spec.body)
    return "created"
end

function LL:CreateCallerMacros()
    if InCombatLockdown and InCombatLockdown() then
        self:Print("Macro creation is blocked in combat. Try again after combat.")
        return
    end

    if not CreateMacro or not EditMacro or not GetMacroIndexByName then
        self:Print("Macro creation API is unavailable. Printing macro text instead.")
        self:PrintMacroText()
        return
    end

    local specs = self:BuildMacroSpecs()
    local missing = 0

    for _, spec in ipairs(specs) do
        if self:GetMacroIndex(spec.name) == 0 then
            missing = missing + 1
        end
    end

    if missing > 0 and GetNumMacros then
        local accountMacros = GetNumMacros()
        local maxAccountMacros = MAX_ACCOUNT_MACROS or 120

        if accountMacros and accountMacros + missing > maxAccountMacros then
            self:Print("Not enough account macro slots. Need " .. missing .. " free slots, or use /ll macros print.")
            return
        end
    end

    local created = 0
    local updated = 0

    for _, spec in ipairs(specs) do
        local result = self:CreateOrUpdateMacro(spec)
        if result == "created" then
            created = created + 1
        else
            updated = updated + 1
        end
    end

    local strategy = self:GetStrategy()
    if strategy and strategy.usesChannel == false then
        self:Print("Created " .. created .. " and updated " .. updated .. " account macros for " .. strategy.label .. ". Channel settings do not affect this strategy.")
    else
        self:Print("Created " .. created .. " and updated " .. updated .. " account macros for " .. self:GetChannel().label .. ".")
    end
    self:Print("Open /macro and drag LL Circle, LL X, LL Diamond, LL T, LL Triangle, and LL Undo to the caller's action bar.")
end

function LL:RunDemoSequence()
    self:ResetSequence("demo")
    self:ShowViewer()

    for i = 1, self:GetSlotCount() do
        local rune = self.RUNE_DEFS[i]
        if rune then
            local strategy = self:GetStrategy()
            local renderValue = strategy and strategy.BuildTestRenderValue and strategy.BuildTestRenderValue(self, rune)
            if renderValue then
                self:AppendRenderValue(renderValue, true)
            end
        end
    end

    self:Print("Loaded a local demo sequence. Use /ll undo or /ll reset to test clearing.")
end

function LL:UndoLast()
    if self.sequenceCount <= 0 then
        return
    end

    self:ClearSlot(self.sequenceCount)
    self.sequenceCount = self.sequenceCount - 1
    self:ArmAutoClear()
    self:UpdateStatusText()

    if self.sequenceCount <= 0 and self.ResetPingSender then
        self:ResetPingSender()
    end
end

function LL:ResetSequence(reason)
    self.sequenceCount = 0
    self.autoClearSerial = (self.autoClearSerial or 0) + 1

    for i = 1, self.MAX_SLOTS do
        self:ClearSlot(i)
    end

    self:UpdateStatusText()

    if self.ResetPingSender then
        self:ResetPingSender()
    end

    if reason == "slash" then
        self:Print("Sequence cleared locally.")
    end
end

function LL:ArmAutoClear()
    self.autoClearSerial = (self.autoClearSerial or 0) + 1
    local serial = self.autoClearSerial
    local seconds = self.db and self.db.autoClearSeconds or self.AUTO_CLEAR_SECONDS

    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, function()
            if LL.autoClearSerial == serial and LL.sequenceCount > 0 then
                LL:ResetSequence("timeout")
            end
        end)
    end
end

function LL:SetMode(mode, silent)
    if not self.MODES[mode] then
        self:Print("Unknown mode. Use normal, heroic, or mythic.")
        return
    end

    self.db.mode = mode
    self:ResetSequence("mode")
    self:UpdateModeDisplay()
    self:RefreshSettingsPanel()
    if not silent then
        self:Print("Mode set to " .. self.MODES[mode].label .. ".")
    end
end

function LL:SetLocked(locked, silent)
    self.db.locked = not not locked
    self:UpdateLockState()
    self:RefreshSettingsPanel()
    if not silent then
        self:Print(self.db.locked and "Frame locked." or "Frame unlocked. Drag the viewer.")
    end
end

function LL:SaveFramePosition(frame, key)
    if not self.db or not self.db.positions or not frame then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then
        self.db.positions[key] = {
            point = point,
            relativePoint = relativePoint or point,
            x = x or 0,
            y = y or 0,
        }
    end
end

function LL:RestoreFramePosition(frame, key)
    if not frame then
        return
    end

    local pos = self.db and self.db.positions and self.db.positions[key]
    frame:ClearAllPoints()

    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function LL:OnAddonLoaded()
    LuraBrainBoosterDB = CopyDefaults(LuraBrainBoosterDB, self.DEFAULTS)
    self.db = LuraBrainBoosterDB
    self.db.testCaller = nil
    if self.db.positions then
        self.db.positions.caller = nil
    end

    self.sequenceCount = 0
    self.inEncounter = false
    self.inTargetRaid = false
    self.locationEventsRegistered = nil
    self.encounterTrackingEnabled = nil
    self.registeredStrategyEvents = nil
    self.registeredStrategyEventSet = nil

    self:CreateUI()
    self:ResetSequence("load")
    self:RegisterLocationEvents()
    self:UpdateTargetRaidState()
    self:RegisterSlashCommands()
    self:RegisterSettingsPanel()

    if self.db.shown then
        self:ShowViewer()
    else
        self:HideViewer()
    end

    self:Print("Loaded. Use /ll macros for direct macros, or /ll help for commands.")
end

function LL:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == self.ADDON_NAME then
            self.eventFrame:UnregisterEvent("ADDON_LOADED")
            self:OnAddonLoaded()
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        self:UpdateTargetRaidState()
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if self.inTargetRaid and self:IsMidnightFallsEncounter(encounterID, encounterName) then
            self.inEncounter = true
            self:ResetSequence("encounter")
            self:RefreshListening()
            self:ShowViewer()
        end
    elseif event == "ENCOUNTER_END" then
        if self.inEncounter then
            self.inEncounter = false
            self:RefreshEncounterTracking()
            self:RefreshListening()
            self:ResetSequence("encounter-end")
        end
    elseif self.registeredStrategyEventSet and self.registeredStrategyEventSet[event] then
        local strategy = self:GetStrategy()
        if strategy and strategy.HandleEvent then
            strategy.HandleEvent(self, event, ...)
        end
    end
end

LL.eventFrame = CreateFrame("Frame")
LL.eventFrame:RegisterEvent("ADDON_LOADED")
LL.eventFrame:SetScript("OnEvent", function(_, event, ...)
    LL:OnEvent(event, ...)
end)
