# Agent Handoff: L'ura Brain Booster

## Project Context

This repository is a World of Warcraft Retail addon for the Midnight expansion.

The addon helps with the L'ura / Midnight Falls boss in the March on
Quel'Danas raid, specifically the `Death's Dirge` memory-game mechanic.

The target users are a community guild with players who have various mental
disabilities. The addon should reduce memory/translation load without
automating gameplay or making player decisions.

## Midnight Restrictions To Respect

Midnight introduced major addon restrictions:

- Addons must not use combat-log data to solve encounters.
- Addons must not inspect or compute from Secret Values.
- Addons must not scan private auras to determine each player's rune.
- Addons must not automate targeting, marker placement, movement, casting, or
  assignments.
- Addon communication can be blocked during encounters, so do not depend on
  `C_ChatInfo.SendAddonMessage` for in-combat sync.
- Raid chat payloads inside instances/encounters may be Secret Values. Do not
  parse, compare, concatenate, inspect, or read them back.

The safe pattern used here is:

1. A human group leader or raid assistant watches the boss symbols.
2. The human presses one direct macro per symbol.
3. The macro sends a group-exclusive chat message (`/raid`, `/i`, or `/party`)
   containing only a texture path.
4. Other clients receive the group chat event, verify the sender is the group
   leader or a raid assistant, and pass the payload directly into
   `FontString:SetFormattedText("|T%s:...|t", payload)`.

This intentionally displays the payload without understanding it.

## Current Addon Shape

Important files:

- `LuraBrainBooster.toc` - addon metadata, current interface/version.
- `Constants.lua` - rune definitions, texture paths, defaults, mode settings.
- `Core.lua` - saved variables, event handling, sequence state, test helpers.
- `UI.lua` - viewer, compass, texture rendering.
- `Slash.lua` - `/ll` commands.
- `STRATEGIES.md` - strategy interface and registration notes.
- `Textures/` - local 512x512 TGA rune textures based on user-provided PNGs.
- `README.md` - user-facing commands and test notes.

The current rune order/macros are:

1. Circle
2. X
3. Diamond
4. T
5. Triangle

These map to:

- `Interface\AddOns\LuraBrainBooster\Textures\circle.png`
- `Interface\AddOns\LuraBrainBooster\Textures\x.png`
- `Interface\AddOns\LuraBrainBooster\Textures\diamond.png`
- `Interface\AddOns\LuraBrainBooster\Textures\t.png`
- `Interface\AddOns\LuraBrainBooster\Textures\triangle.png`

In code/chat payloads, these are stored with forward slashes, e.g.
`Interface/AddOns/LuraBrainBooster/Textures/circle.png`. Keep that style for macro
payloads.

If texture files are added or renamed while WoW is already open, users should
fully restart the game client. `/reload` is often not enough for new image
files.

## User Commands

- `/ll` toggles the viewer.
- `/ll lock` locks the viewer.
- `/ll unlock` unlocks the viewer for dragging.
- `/ll test` listens to raid chat outside the L'ura encounter.
- `/ll demo` fills a local solo demo sequence.
- `/ll add circle|x|diamond|t|triangle` adds one local test rune.
- `/ll send circle|x|diamond|t|triangle` sends one out-of-combat group test
  message using normal chat APIs. This is only a transport test fallback, not
  the intended in-encounter path, and listeners accept it only from the group
  leader or a raid assistant.
- `/ll undo` removes the most recent local symbol.
- `/ll mode normal|heroic|mythic` changes sequence length.
- `/ll channel raid|instance|party` changes the direct macro channel.
- `/ll macros` creates or updates account-wide direct caller macros.
- `/ll macros print` prints direct macro text without creating macros.
- `/ll reset` clears the local sequence.

## Development Notes

- Keep edits small and conservative.
- Do not introduce combat log, aura scanning, marker automation, boss timer
  solving, or in-combat addon comm sync.
- The macro channel is configurable because `/raid` may not propagate in every
  instanced encounter test.
- The default texture strategy listens to group chat events and checks the
  sender against the current group leader or raid assistants before rendering
  or undoing.
- Do not replace direct texture rendering with parsed message formats unless
  you are certain it remains safe with Secret Values.
- If adding user-facing art, prefer power-of-two TGA/PNG dimensions; TGA is the
  safer WoW UI texture format.
- The addon folder may not be a git repo, and `git` may not be installed on the
  user's PATH.
- Before implementing a new transmit/decode strategy, load `docs/STRATEGIES.md` into
  context and follow its strategy interface, render value, registration, and
  safety guidance.
