# L'ura Brain Booster

L'ura Brain Booster is a Midnight-safe helper for the Midnight Falls / L'ura
`Death's Dirge` memory mechanic in March on Quel'Danas.

The default live strategy does not read the combat log, detect private auras,
scan player debuffs, assign players, place markers, or inspect chat payloads
during the encounter. The group leader or a raid assistant manually presses one
macro for each rune shown by the boss. Everyone with the addon sees those
incoming authorized macro payloads in a fixed order display.

## Commands

- `/ll` toggles the viewer.
- `/ll lock` locks the viewer.
- `/ll unlock` unlocks the viewer for dragging.
- `/ll test` listens to the selected strategy's events outside the L'ura
  encounter for testing.
- `/ll demo` loads a local solo demo sequence without using raid chat.
- `/ll add circle|cross|diamond|t|triangle` adds one local test rune.
- `/ll send circle|x|diamond|t|triangle` sends one test rune to your current
  group out of combat. Listening clients accept it only from the group leader
  or a raid assistant.
- `/ll undo` removes the most recent local symbol.
- `/ll mode normal|heroic|mythic` sets sequence length.
- `/ll scale 50-125` sets the viewer scale percentage.
- `/ll scale reset` resets the viewer scale to 100%.
- `/ll channel raid|instance|party` changes the direct macro channel.
- `/ll strategy` shows the selected transmit strategy and available options.
- `/ll strategy texture` selects the default direct texture-path strategy.
- `/ll strategy ping` selects the direct ping strategy.
- `/ll pinglog` shows recent ping diagnostics.
- `/ll pinglog clear` clears recent ping diagnostics.
- `/ll macros` creates or updates account-wide direct caller macros.
- `/ll macros print` prints direct macro text without creating macros.
- `/ll reset` clears the local sequence.

## Solo Testing

If texture files were added or renamed while WoW was already open, fully exit
and restart the game before testing. A `/reload` is often not enough for newly
added image files. The generated macro icons use these same texture files.

Use `/ll demo` to verify that the viewer, order display, mode length, undo,
reset, and 15 second auto-clear work before sharing the addon with a raid.
Use `/ll mode normal` or `/ll mode heroic` before `/ll demo` to test different
sequence lengths.

Use `/ll scale 80` to shrink the viewer to 80%, or `/ll scale reset` to restore
the default 100% size. Scale is saved per account with the rest of the addon
settings.

Use `/ll add circle`, `/ll add t`, and so on to build a sequence manually.
The solo commands do not send chat and do not test Blizzard's raid chat delivery;
for that, make a party or raid, make the caller the group leader or a raid
assistant, use `/ll test`, then try `/ll send x`.

Use `/ll strategy` to confirm the selected transmit strategy. The default
`texture` strategy is the live-encounter strategy and preserves the Midnight-safe
direct texture-path payload behavior. If future strategies are added, every
addon user must select the same strategy before the pull so incoming signals are
interpreted the same way.

The `ping` strategy creates one manual `/ping [@player] <number>` macro per
symbol plus one undo macro, then decodes `CHAT_MSG_PING`. Use `/ll test`, press
the generated ping macros, and inspect `/ll pinglog` to verify payloads on the
current client. `/ll channel` does not affect ping macros, and `/ll send` is
unsupported for ping because addon/script ping sending is protected. Like the
texture strategy, decoded pings are accepted only from the group leader or a
raid assistant.

For an instanced boss test, try `/ll channel raid` first. Make the caller the
group leader or a raid assistant. If a hand-typed
`/raid Interface/AddOns/LuraBrainBooster/Textures/circle.tga` works, run `/ll macros`
and use the created direct macros for the pull.

## Caller Workflow

1. Before pull, set the macro channel with `/ll channel raid`,
   `/ll channel instance`, or `/ll channel party`. Experimental channel-less
   strategies such as `ping` ignore this setting.
2. Make the caller the group leader or a raid assistant, then confirm the
   transmit strategy with `/ll strategy`; use `/ll strategy texture`
   for the default direct texture-path method.
3. Use `/ll macros` out of combat to create or update the account-wide macros
   after changing channel or strategy.
4. Open `/macro` and drag `LL Circle`, `LL X`, `LL Diamond`, `LL T`,
   `LL Triangle`, and `LL Undo` to the caller's action bar.
5. During `Death's Dirge`, press one macro for each rune in the order the boss
   shows them.
6. If you misclick, press `LL Undo`. With `texture`, it sends a raid warning
   event. With `ping`, it sends `/ping [@player] 6`. Every
   listening client using the same strategy removes the most recent symbol.

During the encounter, any leader or assistant group chat from an authorized
caller can look like a rune input to the addon because Midnight hides chat
contents from addon code. Keep authorized caller chat clear while
`Death's Dirge` is being entered.

Outside March on Quel'Danas and outside explicit `/ll test` mode, the addon
keeps its strategy-specific chat and ping events unregistered.
