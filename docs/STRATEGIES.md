# LuraBrainBooster Strategy Interface

Strategies isolate how symbol signals are transmitted, received, decoded, and
turned into UI render values. Register strategies before `Core.lua` loads.

## Registration

```lua
LL:RegisterStrategy({
    key = "texture",
    label = "Texture Path",
    description = "Leader/assistant direct chat payloads are rendered as WoW texture paths.",
    encounterSafe = true,
    requiresMatchingStrategy = true,
    usesChannel = true,
    events = {
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING",
    },

    BuildRuneMacroText = function(addon, rune, channel)
        return channel.command .. " " .. rune.chat
    end,

    BuildUndoMacroText = function(addon, channel)
        return "/rw " .. addon.UNDO_RAID_WARNING_TEXT
    end,

    BuildTestRenderValue = function(addon, rune)
        return { kind = "rune", key = rune.key }
    end,

    BuildSendMessage = function(addon, rune)
        return rune.chat
    end,

    HandleEvent = function(addon, event, ...)
        -- Decode selected events, then call addon:AppendRenderValue(...)
    end,
})
```

## Required Fields

- `key`: Stable saved setting used by `/ll strategy <key>`.
- `label`: Short user-facing name.
- `description`: One-line explanation for `/ll strategy`.
- `encounterSafe`: `true` only if intended for live encounter use.
- `events`: WoW events to register while listening is active.
- `BuildRuneMacroText(addon, rune, channel)`: Caller macro body for one rune.
- `BuildUndoMacroText(addon, channel)`: Caller macro body for undo.
- `BuildTestRenderValue(addon, rune)`: Local `/ll add` and `/ll demo` output.
- `HandleEvent(addon, event, ...)`: Decode events and append render values.

`BuildSendMessage(addon, rune)` is optional and only needed for `/ll send`.

`usesChannel = false` is optional for strategies whose direct macros do not use
`/raid`, `/i`, or `/party`. In that case `/ll channel` does not affect generated
macro text.

## Render Values

Strategies should output one of these:

```lua
{ kind = "texture", path = "Interface/AddOns/LuraBrainBooster/Textures/circle.tga" }
{ kind = "rune", key = "circle" }
```

Use `kind = "texture"` only when the strategy must pass a payload directly to
WoW texture rendering. Use `kind = "rune"` for decoded strategies.

## Safety Notes

- Do not add combat log, aura scanning, marker automation, targeting, movement,
  casting, or addon-message sync.
- Sender filtering may use public group roster role APIs. In instances, prefer
  chat GUIDs and avoid inspecting sender strings; never inspect or compare the
  chat payload.
- Register normal group chat events when needed to receive raid assistant
  messages, then reject normal members by sender role before rendering.
- Do not parse live encounter raid chat unless that specific strategy has been
  reviewed and marked encounter-safe.
- Ping-based strategies should reuse `LL:IsAuthorizedCallerSender(...)` before
  decoding a ping into a rendered rune.
- Future strategy files should load after `Strategies.lua` and before `Core.lua`.
