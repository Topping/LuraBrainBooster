# L'ura Brain Booster

L'ura Brain Booster is a World of Warcraft Retail addon for the L'ura / Midnight Falls `Death's Dirge` memory mechanic in March on Quel'Danas.

The addon's job is to show the rune sequence clearly and consistently so players can follow the mechanic with less cognitive load. It does not automate gameplay, choose assignments, inspect private player state, place markers, target enemies, move characters, or cast spells.

The default live flow is intentionally simple:

1. Everyone installs the addon.
2. A human group leader or raid assistant watches the boss symbols.
3. The caller presses one direct macro for each symbol shown by the boss.
4. Other addon users receive the authorized signal and see the symbols appear in order on the viewer.
5. The sequence clears automatically after a short delay, or can be cleared locally with `/ll reset`.

## Basic Usage

Install the addon as `Interface/AddOns/LuraBrainBooster`, then restart WoW if you added or renamed any texture files. A `/reload` is often not enough for new image files.

Open **Options > AddOns > L'ura Brain Booster** to configure the viewer, encounter mode, macro channel, strategy, caller macros, and local testing. The `/ll` commands remain available as an alternate quick path.

Use the settings panel or `/ll` to show or hide the viewer. Unlock the viewer to drag it, lock it again when positioned, and adjust the saved viewer size from the scale control or `/ll scale`.

Set the sequence length from the settings panel or with `/ll mode normal`, `/ll mode heroic`, or `/ll mode mythic`. Normal shows 3 slots; Heroic and Mythic show 5.

For live use, keep the default `texture` strategy unless the whole group has agreed to use another one:

```text
/ll strategy texture
/ll channel raid
/ll macros
```

Open `/macro`, then drag `LL Circle`, `LL X`, `LL Diamond`, `LL T`, `LL Triangle`, and `LL Undo` to the caller's action bar. During `Death's Dirge`, the caller presses the rune macros in the order the boss shows them. If the caller misclicks, `LL Undo` removes the most recent symbol from listening clients.

The macro channel can be changed in the settings panel or with `/ll channel raid`, `/ll channel instance`, or `/ll channel party`. Use **Create / Update Macros** in settings, or re-run `/ll macros`, after changing channel or strategy so the account-wide macros are updated.

If encounter transport is blocked, use the local fallback on the caller only:

```text
/ll strategy local
/ll macros
```

This updates the `LL Circle`, `LL X`, `LL Diamond`, `LL T`, `LL Triangle`, and `LL Undo` macros to render directly on the caller's own viewer with no chat or ping transport.

## Testing

Use **Run Demo** in settings or `/ll demo` for a local viewer test. It fills the current mode's slots without sending any group message.

Use `/ll add circle`, `/ll add x`, `/ll add diamond`, `/ll add t`, or `/ll add triangle` to build a local sequence one symbol at a time. `/ll undo` removes the most recent local symbol.

For an out-of-combat group transport test, make the caller the group leader or a raid assistant, have listeners run `/ll test`, then try:

```text
/ll send x
```

Listening clients only accept group test messages from the group leader or a raid assistant. `/ll send` is a testing fallback, not the intended in-encounter path.

For the ping strategy, every addon user must select `/ll strategy ping`, then the caller must run `/ll macros` again. Ping macros ignore `/ll channel`. Use `/ll pinglog` and `/ll pinglog clear` while testing ping payloads.

For the local-only strategy, only the caller needs to select `/ll strategy local`, then run `/ll macros` again. Local macros ignore `/ll channel` and do not send anything to other clients.

For the debug strategy, every addon user should select `/ll strategy debug`, then the caller should run `/ll macros` again. Debug macros send both the configured chat payload and a ping, and listeners accept either transport. If both transports arrive, duplicate symbols may appear.

## Local Deploy

For Windows development, copy `.env.local.example` to `.env.local` and set `LURA_WOW_ADDONS_DIR` to your WoW Retail AddOns folder, for example:

```text
LURA_WOW_ADDONS_DIR=C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns
```

Then deploy the current repo build with PowerShell:

```powershell
.\scripts\Deploy-Local.ps1
```

Use `.\scripts\Deploy-Local.ps1 -Plan` to preview the files, or `.\scripts\Deploy-Local.ps1 -Clean` to remove the existing deployed `LuraBrainBooster` folder before copying. `.env.local` is gitignored so your local install path stays private.

## Commands

- `/ll` toggles the viewer.
- `/ll lock` locks the viewer.
- `/ll unlock` unlocks the viewer for dragging.
- `/ll test` is currently a legacy test toggle; strategy event listening is temporarily always on while encounter filtering is disabled for diagnosis.
- `/ll demo` loads a local solo demo sequence.
- `/ll add circle|x|diamond|t|triangle` adds one local test rune.
- `/ll send circle|x|diamond|t|triangle` sends one out-of-combat group test signal when the selected strategy supports it.
- `/ll undo` removes the most recent local symbol.
- `/ll mode normal|heroic|mythic` changes sequence length.
- `/ll scale 50-125` sets viewer scale as a percentage.
- `/ll scale reset` resets viewer scale to 100%.
- `/ll channel raid|instance|party` changes the direct macro channel.
- `/ll strategy` lists available transmit strategies.
- `/ll strategy texture` selects the default direct texture-path strategy.
- `/ll strategy ping` selects the direct ping strategy.
- `/ll pinglog` shows recent ping diagnostics.
- `/ll pinglog clear` clears recent ping diagnostics.
- `/ll macros` creates or updates account-wide caller macros.
- `/ll macros print` prints caller macro text without creating macros.
- `/ll reset` clears the local sequence.

## Caller Notes

The default `texture` strategy creates direct macros whose rune bodies look like this:

```text
/raid Interface/AddOns/LuraBrainBooster/Textures/circle.tga
```

The payload uses forward slashes because that is the form stored in the addon and passed to WoW texture rendering.

During the encounter, authorized group chat from the caller can be interpreted as rune input because the default strategy deliberately does not inspect the chat payload. Authorized raid warnings can also act as undo events. Keep leader and assistant chat clear while `Death's Dirge` is being entered.

## Project Structure

- `LuraBrainBooster.toc` declares addon metadata and load order.
- `Constants.lua` defines rune order, texture paths, modes, channels, UI defaults, and saved-variable defaults.
- `Strategies.lua` contains the strategy registry, caller authorization helpers, and the default `texture` strategy.
- `Strategy_Ping.lua` adds the `ping` strategy and ping diagnostics.
- `Core.lua` owns saved variables, slash command wiring, encounter/test listening state, sequence state, macro creation, and event dispatch.
- `UI.lua` builds the draggable viewer, positions mode-specific slots, and renders strategy output as textures.
- `Slash.lua` parses `/ll` commands.
- `docs/STRATEGIES.md` documents the strategy interface for future transmit methods.
- `Textures/` contains the local rune and viewer art.

## Implementation Approach

Temporary diagnostic build: encounter filtering is disabled, so the selected strategy's events stay registered without requiring the L'ura encounter detector to fire. Sender authorization still applies before any symbol is rendered.

Incoming signals are accepted only from the current group leader or a raid assistant, using public group roster information. The addon does not rely on combat-log solving, private aura scanning, addon-message sync, automatic assignment, target markers, movement, casting, or secret-value decoding.

The sequence model is small: each accepted signal appends one render value to the viewer until the current mode's slot count is full. Normal uses 3 slots; Heroic and Mythic use 5. A timer clears the sequence after 15 seconds.

## Strategy Pattern

Transmit methods are isolated behind strategy objects registered with `LL:RegisterStrategy(...)`. A strategy declares:

- `key`, `label`, and `description` for saved settings and `/ll strategy`.
- `encounterSafe` and `requiresMatchingStrategy` metadata.
- `events` to register while listening is active.
- `BuildRuneMacroText` and `BuildUndoMacroText` for caller macro generation.
- `BuildTestRenderValue` for `/ll demo` and `/ll add`.
- Optional `BuildSendMessage` support for `/ll send`.
- `HandleEvent` to receive registered events and append render values.

Strategies return render values instead of drawing directly:

```lua
{ kind = "texture", path = "Interface/AddOns/LuraBrainBooster/Textures/circle.tga" }
{ kind = "rune", key = "circle" }
```

`UI.lua` is the only layer that turns those values into visible textures. This keeps transmission details out of the viewer and lets future strategies reuse the same display path.

The default `texture` strategy preserves the Midnight-safe direct payload flow: authorized group chat is passed directly into `FontString:SetFormattedText("|T%s:44:44|t", payload)` without parsing, comparing, concatenating, or translating the payload during the encounter.

The `local` strategy is a transport-free fallback: caller macros run `/ll add <rune>` and `/ll undo` locally, so only the caller's own viewer updates.

The `debug` strategy combines the texture and ping transports for diagnosis. Generated macros contain both a chat line and a `/ping` line, and the strategy registers both event families.

Future strategies should follow `docs/STRATEGIES.md` and must avoid combat-log data, Secret Value inspection, private aura scanning, in-combat addon comm sync, and gameplay automation.
