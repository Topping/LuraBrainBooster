local _, LL = ...

local PING_DIAGNOSTIC_LIMIT = 12

local PING_CODE_BY_RUNE = {
    circle = "1",
    cross = "2",
    diamond = "3",
    t = "4",
    triangle = "5",
}

local PING_ACTIONS = {}
local PING_ACTION_CONTAINS = {}

local function NormalizePingValue(value)
    if value == nil then
        return nil
    end

    local normalized = tostring(value)
    normalized = normalized:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    normalized = string.lower(normalized)
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    normalized = normalized:gsub("[%s_%-]+", "")

    if normalized == "" then
        return nil
    end

    return normalized
end

local function AddPingAction(alias, action)
    local normalized = NormalizePingValue(alias)
    if normalized then
        PING_ACTIONS[normalized] = action
    end
end

local function AddPingActionContains(alias, action)
    local normalized = NormalizePingValue(alias)
    if normalized then
        PING_ACTION_CONTAINS[#PING_ACTION_CONTAINS + 1] = {
            token = normalized,
            action = action,
        }
    end
end

AddPingAction("1", "circle")
AddPingAction("attack", "circle")
AddPingAction("PING_TYPE_ATTACK", "circle")
AddPingAction(PING_TYPE_ATTACK, "circle")
AddPingActionContains("PingChatAttack", "circle")
AddPingActionContains("PingTypeAttack", "circle")

AddPingAction("2", "cross")
AddPingAction("warning", "cross")
AddPingAction("PING_TYPE_WARNING", "cross")
AddPingAction(PING_TYPE_WARNING, "cross")
AddPingActionContains("PingChatWarning", "cross")
AddPingActionContains("PingTypeWarning", "cross")

AddPingAction("3", "diamond")
AddPingAction("onmyway", "diamond")
AddPingAction("on my way", "diamond")
AddPingAction("PING_TYPE_ON_MY_WAY", "diamond")
AddPingAction(PING_TYPE_ON_MY_WAY, "diamond")
AddPingActionContains("PingChatOnMyWay", "diamond")
AddPingActionContains("PingTypeOnMyWay", "diamond")

AddPingAction("4", "t")
AddPingAction("assist", "t")
AddPingAction("PING_TYPE_ASSIST", "t")
AddPingAction(PING_TYPE_ASSIST, "t")
AddPingActionContains("PingChatAssist", "t")
AddPingActionContains("PingTypeAssist", "t")

AddPingAction("5", "triangle")
AddPingAction("look", "triangle")
AddPingAction("nonthreat", "triangle")
AddPingAction("nonthread", "triangle")
AddPingAction("PING_TYPE_LOOK", "triangle")
AddPingAction(PING_TYPE_LOOK, "triangle")
AddPingAction(PING_TYPE_ALERT_NOT_THREAT, "triangle")
AddPingActionContains("PingChatLook", "triangle")
AddPingActionContains("PingTypeLook", "triangle")
AddPingActionContains("PingChatAlertNotThreat", "triangle")
AddPingActionContains("PingTypeAlertNotThreat", "triangle")
AddPingActionContains("PingChatNotThreat", "triangle")
AddPingActionContains("PingTypeNotThreat", "triangle")
AddPingActionContains("PingChatNonThreat", "triangle")
AddPingActionContains("PingTypeNonThreat", "triangle")
AddPingActionContains("PingChatNonThread", "triangle")
AddPingActionContains("PingTypeNonThread", "triangle")

AddPingAction("6", "undo")
AddPingAction("threat", "undo")
AddPingAction("alertthreat", "undo")
AddPingAction("alert threat", "undo")
AddPingAction("PING_TYPE_THREAT", "undo")
AddPingAction("PING_TYPE_ALERT_THREAT", "undo")
AddPingAction(PING_TYPE_THREAT, "undo")
AddPingAction(PING_TYPE_ALERT_THREAT, "undo")
AddPingActionContains("PingChatThreat", "undo")
AddPingActionContains("PingTypeThreat", "undo")
AddPingActionContains("PingChatAlertThreat", "undo")
AddPingActionContains("PingTypeAlertThreat", "undo")

local function ValueToLogString(value)
    if value == nil then
        return "nil"
    end

    if type(value) == "boolean" then
        return value and "true" or "false"
    end

    local ok, text = pcall(tostring, value)
    if not ok then
        return "<restricted>"
    end

    return text:gsub("|", "||")
end

local function IsNonEmptyStringValue(value)
    if type(value) ~= "string" then
        return false
    end

    local ok, isNonEmpty = pcall(function()
        return value ~= ""
    end)

    return ok and isNonEmpty
end

local function GetPingSenderKey(playerName, guid)
    if IsNonEmptyStringValue(guid) then
        return guid
    end

    if IsNonEmptyStringValue(playerName) then
        return playerName
    end

    return "UNKNOWN"
end

local function IsAuthorizedPingSender(addon, guid, ...)
    if not addon.IsAuthorizedCallerSender then
        return true, nil
    end

    if addon:IsAuthorizedCallerSender(nil, guid) then
        return true, guid
    end

    for i = 1, select("#", ...) do
        local sender = select(i, ...)
        if addon:IsAuthorizedCallerSender(sender, guid) then
            local normalizedSender = addon.NormalizeCallerSender and addon:NormalizeCallerSender(sender)
            return true, normalizedSender or sender
        end
    end

    return false, nil
end

local function RecordPingDiagnostic(addon, entry)
    addon.pingDiagnostics = addon.pingDiagnostics or {}
    addon.pingDiagnostics[#addon.pingDiagnostics + 1] = entry

    while #addon.pingDiagnostics > PING_DIAGNOSTIC_LIMIT do
        table.remove(addon.pingDiagnostics, 1)
    end
end

local function AcceptPingSender(addon, senderKey, action)
    if not senderKey or senderKey == "" then
        senderKey = "UNKNOWN"
    end

    if addon.pingSenderKey and addon.pingSenderKey ~= senderKey then
        return false
    end

    if not addon.pingSenderKey and (action ~= "undo" or addon.sequenceCount > 0) then
        addon.pingSenderKey = senderKey
    end

    return true
end

local function DecodePingActionValue(value)
    local normalized = NormalizePingValue(value)
    if not normalized then
        return nil, nil
    end

    if PING_ACTIONS[normalized] then
        return PING_ACTIONS[normalized], normalized
    end

    for _, match in ipairs(PING_ACTION_CONTAINS) do
        if string.find(normalized, match.token, 1, true) then
            return match.action, normalized
        end
    end

    return nil, normalized
end

local function DecodePingAction(...)
    local fallbackNormalized

    for i = 1, select("#", ...) do
        local action, normalized = DecodePingActionValue(select(i, ...))
        fallbackNormalized = fallbackNormalized or normalized
        if action then
            return action, normalized
        end
    end

    return nil, fallbackNormalized
end

local function IsEmptyPingPayload(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value ~= nil and tostring(value) ~= "" then
            return false
        end
    end

    return true
end

function LL:ResetPingSender()
    self.pingSenderKey = nil
end

function LL:ClearPingDiagnostics()
    self.pingDiagnostics = {}
    self:Print("Ping diagnostic log cleared.")
end

function LL:PrintPingDiagnostics()
    local log = self.pingDiagnostics
    if not log or #log == 0 then
        self:Print("Ping diagnostic log is empty. Use /ll test with /ll strategy ping, then press ping macros.")
        return
    end

    self:Print("Recent ping diagnostics:")
    for i, entry in ipairs(log) do
        local status = entry.accepted and "accepted" or ("ignored:" .. entry.reason)
        self:Print(i .. ". time=" .. entry.time
            .. " text=" .. entry.text
            .. " normalized=" .. entry.normalized
            .. " player=" .. entry.playerName
            .. " sender=" .. entry.sender
            .. " guid=" .. entry.guid
            .. " action=" .. entry.action
            .. " lineID=" .. entry.lineID
            .. " " .. status)
    end
end

LL:RegisterStrategy({
    key = "ping",
    label = "Ping",
    description = "Direct /ping macros decoded from CHAT_MSG_PING.",
    encounterSafe = true,
    requiresMatchingStrategy = true,
    usesChannel = false,
    events = {
        "CHAT_MSG_PING",
    },

    BuildRuneMacroText = function(addon, rune)
        return "/ping [@player] " .. (PING_CODE_BY_RUNE[rune.key] or "1")
    end,

    BuildUndoMacroText = function()
        return "/ping [@player] 6"
    end,

    BuildTestRenderValue = function(addon, rune)
        return {
            kind = "rune",
            key = rune.key,
        }
    end,

    HandleEvent = function(addon, event, ...)
        if event ~= "CHAT_MSG_PING" then
            return
        end

        local text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, suppressRaidIcons = ...
        if IsEmptyPingPayload(text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID) then
            return
        end

        local action, normalized = DecodePingAction(text, playerName, channelName, playerName2, channelBaseName)
        local authorized, pingSender = IsAuthorizedPingSender(addon, guid, text, playerName, playerName2)
        local senderKey = GetPingSenderKey(pingSender or playerName, guid)
        local accepted = false
        local reason = "unknown-payload"

        if action and not authorized then
            reason = "unauthorized-sender"
        elseif action and not AcceptPingSender(addon, senderKey, action) then
            reason = "other-sender"
        elseif action == "undo" then
            accepted = true
            reason = ""
            addon:UndoLast()
        elseif action then
            accepted = true
            reason = ""
            addon:AppendRenderValue({
                kind = "rune",
                key = action,
            })
        end

        RecordPingDiagnostic(addon, {
            time = ValueToLogString(GetTime and GetTime() or 0),
            text = ValueToLogString(text),
            normalized = normalized or "nil",
            playerName = ValueToLogString(playerName),
            sender = ValueToLogString(pingSender),
            guid = ValueToLogString(guid),
            action = action or "nil",
            lineID = ValueToLogString(lineID),
            channelName = ValueToLogString(channelName),
            playerName2 = ValueToLogString(playerName2),
            languageName = ValueToLogString(languageName),
            specialFlags = ValueToLogString(specialFlags),
            zoneChannelID = ValueToLogString(zoneChannelID),
            channelIndex = ValueToLogString(channelIndex),
            channelBaseName = ValueToLogString(channelBaseName),
            languageID = ValueToLogString(languageID),
            bnSenderID = ValueToLogString(bnSenderID),
            isMobile = ValueToLogString(isMobile),
            isSubtitle = ValueToLogString(isSubtitle),
            hideSenderInLetterbox = ValueToLogString(hideSenderInLetterbox),
            suppressRaidIcons = ValueToLogString(suppressRaidIcons),
            accepted = accepted,
            reason = reason,
        })
    end,
})
