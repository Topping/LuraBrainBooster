local _, LL = ...

LL.STRATEGIES = LL.STRATEGIES or {}
LL.STRATEGY_ORDER = LL.STRATEGY_ORDER or {}

function LL:RegisterStrategy(strategy)
    if type(strategy) ~= "table" or type(strategy.key) ~= "string" or strategy.key == "" then
        error("LuraBrainBooster strategy must have a non-empty key.")
    end

    if not self.STRATEGIES[strategy.key] then
        self.STRATEGY_ORDER[#self.STRATEGY_ORDER + 1] = strategy.key
    end

    self.STRATEGIES[strategy.key] = strategy
end

local GROUP_CHAT_EVENTS = {
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_INSTANCE_CHAT = true,
    CHAT_MSG_INSTANCE_CHAT_LEADER = true,
}

local CHAT_GUID_ARG_INDEX = 12

local function IsNonEmptyPublicString(value)
    if type(value) ~= "string" then
        return false
    end

    local ok, isNonEmpty = pcall(function()
        return value ~= ""
    end)

    return ok and isNonEmpty
end

function LL:NormalizeCallerSender(sender)
    if type(sender) ~= "string" or sender == "" then
        return nil
    end

    local linkedSender = sender:match("|Hplayer:([^:|]+)")
    if linkedSender and linkedSender ~= "" then
        sender = linkedSender
    else
        local bracketedSender = sender:match("%[([^%]]+)%]")
        if bracketedSender and bracketedSender ~= "" then
            sender = bracketedSender
        end
    end

    sender = sender:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    sender = sender:gsub("|H.-|h", ""):gsub("|h", "")
    sender = sender:gsub("^%s+", ""):gsub("%s+$", "")

    if sender == "" then
        return nil
    end

    return sender
end

local function SenderMatchesUnit(sender, unit)
    local ok, normalizedSender = pcall(function()
        return LL:NormalizeCallerSender(sender)
    end)
    if not ok then
        return false
    end

    sender = normalizedSender
    if not sender or not UnitExists or not UnitExists(unit) then
        return false
    end

    local name, realm
    if UnitFullName then
        name, realm = UnitFullName(unit)
    else
        name, realm = UnitName(unit)
    end

    if not name then
        return false
    end

    if sender == name then
        return true
    end

    if realm and realm ~= "" and sender == (name .. "-" .. realm) then
        return true
    end

    if (not realm or realm == "") and GetNormalizedRealmName then
        local normalizedRealm = GetNormalizedRealmName()
        if normalizedRealm and normalizedRealm ~= "" and sender == (name .. "-" .. normalizedRealm) then
            return true
        end
    end

    return false
end

local function SenderGUIDMatchesUnit(guid, unit)
    if not IsNonEmptyPublicString(guid) or not UnitGUID or not UnitExists or not UnitExists(unit) then
        return false
    end

    local unitGUID = UnitGUID(unit)
    if not unitGUID then
        return false
    end

    local ok, matches = pcall(function()
        return unitGUID == guid
    end)

    return ok and matches
end

local function UnitCanCallRunes(unit)
    if UnitIsGroupLeader and UnitIsGroupLeader(unit) then
        return true
    end

    return UnitIsGroupAssistant and UnitIsGroupAssistant(unit)
end

function LL:IsAuthorizedCallerSender(sender, guid)
    -- Check the public roster role only; the chat payload stays opaque.
    local canUseGUID = IsNonEmptyPublicString(guid)
    local canUseSender = IsNonEmptyPublicString(sender)

    if UnitCanCallRunes("player")
        and ((canUseGUID and SenderGUIDMatchesUnit(guid, "player"))
            or (canUseSender and SenderMatchesUnit(sender, "player"))) then
        return true
    end

    local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
    if groupSize <= 0 then
        return false
    end

    if IsInRaid and IsInRaid() then
        for index = 1, groupSize do
            local unit = "raid" .. index
            if UnitCanCallRunes(unit)
                and ((canUseGUID and SenderGUIDMatchesUnit(guid, unit))
                    or (canUseSender and SenderMatchesUnit(sender, unit))) then
                return true
            end
        end
    else
        for index = 1, 4 do
            local unit = "party" .. index
            if UnitCanCallRunes(unit)
                and ((canUseGUID and SenderGUIDMatchesUnit(guid, unit))
                    or (canUseSender and SenderMatchesUnit(sender, unit))) then
                return true
            end
        end
    end

    return false
end

function LL:HandleTextureChatStrategyEvent(event, ...)
    if event == "CHAT_MSG_RAID_WARNING" then
        local _, sender = ...
        local guid = select(CHAT_GUID_ARG_INDEX, ...)
        if self:IsAuthorizedCallerSender(sender, guid) then
            self:UndoLast()
        end
        return true
    end

    if GROUP_CHAT_EVENTS[event] then
        local sender = select(2, ...)
        local guid = select(CHAT_GUID_ARG_INDEX, ...)
        if self:IsAuthorizedCallerSender(sender, guid) then
            local message = ...
            self:AppendRenderValue({
                kind = "texture",
                path = message,
            })
        end
        return true
    end

    return false
end

LL:RegisterStrategy({
    key = "texture",
    label = "Texture Path",
    description = "Leader/assistant direct chat payloads are rendered as WoW texture paths.",
    encounterSafe = true,
    requiresMatchingStrategy = true,
    events = {
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_RAID_WARNING",
    },

    BuildRuneMacroText = function(addon, rune, channel)
        return channel.command .. " " .. rune.chat
    end,

    BuildUndoMacroText = function(addon)
        return "/rw " .. addon.UNDO_RAID_WARNING_TEXT
    end,

    BuildTestRenderValue = function(addon, rune)
        return {
            kind = "texture",
            path = rune.chat,
        }
    end,

    BuildSendMessage = function(addon, rune)
        return rune.chat
    end,

    HandleEvent = function(addon, event, ...)
        addon:HandleTextureChatStrategyEvent(event, ...)
    end,
})

LL:RegisterStrategy({
    key = "local",
    label = "Local Only",
    description = "Caller macros render symbols only on this client, with no chat or ping transport.",
    encounterSafe = true,
    requiresMatchingStrategy = false,
    usesChannel = false,
    events = {},

    BuildRuneMacroText = function(addon, rune)
        return "/ll add " .. rune.key
    end,

    BuildUndoMacroText = function()
        return "/ll undo"
    end,

    BuildTestRenderValue = function(addon, rune)
        return {
            kind = "rune",
            key = rune.key,
        }
    end,

    HandleEvent = function()
    end,
})
