local _, LL = ...

local function SplitCommand(message)
    message = message or ""
    local command, rest = message:match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    return command, rest or ""
end

function LL:PrintHelp()
    self:Print("/ll - toggle the viewer")
    self:Print("/ll lock - lock the viewer")
    self:Print("/ll unlock - unlock and drag the viewer")
    self:Print("/ll test - listen to selected strategy events outside the encounter")
    self:Print("/ll demo - load a local solo demo sequence")
    self:Print("/ll add circle|cross|diamond|t|triangle - add one local test rune")
    self:Print("/ll send circle|x|diamond|t|triangle - test out-of-combat leader/assistant transport")
    self:Print("/ll undo - remove the last local symbol")
    self:Print("/ll mode normal|heroic|mythic - set sequence length")
    self:Print("/ll scale 50-125 - set viewer scale percent")
    self:Print("/ll scale reset - reset viewer scale to 100%")
    self:Print("/ll channel raid|instance|party - set the direct macro channel")
    self:Print("/ll strategy - show the selected transmit strategy")
    self:Print("/ll strategy texture - set the direct texture-path strategy")
    self:Print("/ll strategy ping - select the experimental ping strategy")
    self:Print("/ll pinglog - show recent experimental ping diagnostics")
    self:Print("/ll pinglog clear - clear experimental ping diagnostics")
    self:Print("/ll macros - create or update direct caller macros")
    self:Print("/ll macros print - print direct macro text")
    self:Print("/ll reset - clear the local sequence")
end

function LL:PrintMacroText()
    local channel = self:GetChannel()
    local strategy = self:GetStrategy()
    if strategy and strategy.usesChannel == false then
        self:Print("Direct caller macros for strategy (" .. strategy.label .. "; channel settings ignored):")
    else
        self:Print("Direct caller macros for selected channel (" .. channel.label .. ", " .. channel.command .. ") and strategy (" .. strategy.label .. "):")
    end

    for i, rune in ipairs(self.RUNE_DEFS) do
        self:Print(self:GetRuneMacroName(rune) .. ": " .. self:GetRuneMacroText(rune))
    end

    self:Print(self.UNDO_MACRO_NAME .. ": " .. self:GetUndoMacroText())
    self:Print("Put these direct macros on the caller's action bar.")
end

function LL:HandleSlash(message)
    local command, rest = SplitCommand(message)

    if command == "" then
        self:ToggleViewer()
    elseif command == "help" then
        self:PrintHelp()
    elseif command == "lock" then
        self:SetLocked(true)
    elseif command == "unlock" then
        self:SetLocked(false)
    elseif command == "test" or command == "listen" then
        self:SetTestListening(not self.db.testListen)
        self:Print("Test listening " .. (self.db.testListen and "enabled." or "disabled."))
    elseif command == "demo" then
        self:RunDemoSequence()
    elseif command == "add" or command == "rune" then
        self:AppendTestRune(rest)
    elseif command == "send" then
        self:SendTestRune(rest)
    elseif command == "undo" then
        self:UndoLast()
    elseif command == "mode" then
        local mode = string.lower(rest or "")
        self:SetMode(mode)
    elseif command == "scale" or command == "size" then
        local scale = string.lower(rest or "")
        if scale == "" then
            self:PrintUIScale()
        elseif scale == "reset" then
            self:SetUIScalePercent((self.DEFAULT_UI_SCALE or 1.0) * 100)
        else
            self:SetUIScalePercent(tonumber(scale))
        end
    elseif command == "channel" or command == "chan" then
        self:SetChannel(rest)
    elseif command == "strategy" or command == "strat" then
        self:SetStrategy(rest)
    elseif command == "pinglog" then
        if string.lower(rest or "") == "clear" then
            if self.ClearPingDiagnostics then
                self:ClearPingDiagnostics()
            else
                self:Print("Ping diagnostics are unavailable.")
            end
        elseif self.PrintPingDiagnostics then
            self:PrintPingDiagnostics()
        else
            self:Print("Ping diagnostics are unavailable.")
        end
    elseif command == "macros" then
        if string.lower(rest or "") == "print" then
            self:PrintMacroText()
        else
            self:CreateCallerMacros()
        end
    elseif command == "reset" or command == "clear" then
        self:ResetSequence("slash")
    else
        self:Print("Unknown command. Use /ll help.")
    end
end

function LL:RegisterSlashCommands()
    SLASH_LURABRAINBOOSTER1 = "/ll"
    SLASH_LURABRAINBOOSTER2 = "/lurabrainbooster"
    SlashCmdList.LURABRAINBOOSTER = function(message)
        LL:HandleSlash(message)
    end
end
