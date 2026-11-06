# AutoCap

AutoHotkey v2 script for Windows 11. It capitalises the first letter of every
sentence as you type, in every application, and keeps new lines from starting
with a space. Tuned for German QWERTZ and German (radiology) text. Single
file, no dependencies: [`AutoCap.ahk`](AutoCap.ahk).

- **Toggle:** Ctrl+Alt+Shift+K, or the tray menu. When disabled, the tray icon switches to AHK's suspended icon.
- **Autostart:** Win+R → `shell:startup` → create a shortcut to `AutoCap.ahk` there.
- **Configure:** the top of the script holds the abbreviation list, the closing and opening characters, the excluded programs (with placeholders for your dictation and RIS programs), the send level and the companion programs (see [below](#running-alongside-atext-and-other-ahk-scripts)).

## Behaviour

| Rule | Example |
|---|---|
| Capital after `. ! ?` + space(s); closers `" ' ) » “ ”` may sit between | `he said "no." Then` |
| Capital after Enter / Shift+Enter / NumpadEnter | `\nHello` |
| Space swallowed at a line start; Shift+Space passes through (and the capital still follows) | `\n   hello` → `\nHello` |
| Openers `( [ { " ' „ “ « » ‚ ‘` keep a pending capital alive | `Ende. (Siehe`, `\n„Nein` |
| No capital after numbers/dates, ellipsis, Roman numerals I–XXXIX (uppercase), tokens with an inner dot, listed abbreviations (case-insensitive) | `am 3. november`, `am 12.03. war`, `ok... and`, `grad II. die`, `www.x.de. dann`, `z.B. die` |
| ß is never capitalised; letters you typed in uppercase are left alone | `ende. ßx`, `ende. Schon` |
| Back to "unknown" (does nothing) after a mouse click, arrows/Home/End/PgUp/PgDn/Esc/Tab/Del, any Ctrl/Alt/Win shortcut, or a window change. AltGr characters count as normal characters. | |
| Backspace drops the last buffered character and recomputes; an empty buffer means unknown | `end.x<BS> word` → `end. Word` |
| A token only partly seen (cut off by a reset) is refused if it could be the tail of an abbreviation | `tc. und` (could be `etc.`) |

## Tests

On Windows:

```bat
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut AutoCap.ahk --test
```

This prints PASS/FAIL for each case and exits with code 1 if any case fails. There are currently 44 cases, all passing.

On Linux (Wine), this is how the script was developed:

```bash
sudo apt-get install -y --no-install-recommends wine64 xvfb openbox xdotool
tools/fetch-ahk.sh            # official AHK v2 zip, SHA-256 verified -> tools/.ahk/
tools/run-tests-wine.sh       # unit tests (core state machine)
tools/integration/run.sh      # end-to-end: types into Wine Notepad, compare with tools/integration/expected.txt
tools/integration/companion/run.sh   # companion start order; expect "ende. Y" on all three lines
```

The companion test starts AutoCap with a test companion that maps `x` to `Y`.
If the companion's hook runs first, `ende. x` becomes `ende. Y`. If AutoCap's
runs first, it becomes `ende. X`. The test checks the result at three points:
after startup, after disabling and re-enabling AutoCap, and after a second
AutoCap start, which is what Reload does. Two controls show it can fail:
`MODE=reverse` starts the companion before AutoCap and gives `X`.
`MODE=nohook` drops `InstallKeybdHook` and gives `X` after the toggle.

The integration test exercises the real keyboard hook, HotIf, SendEvent, the
InputHook, Backspace, arrow keys, Ctrl shortcuts, the toggle, Enter variants
and 5 ms typing. It does **not** cover mouse clicks: after a second click,
Wine drops all keystrokes even with no AHK running. Wine also uses a US layout,
so ä/ö/ü hotkeys are not covered.

## Design (and what the AHK docs/source confirmed)

- **Pure core:** `AutoCapCore` has `Feed(key)` → `pass | upper | swallow`, `Peek`, `Observe`, and a 32-character rolling buffer. It makes no Windows calls; this is what `--test` runs.
- **One persistent InputHook** (`V B I1`, `NotifyNonText`). OnChar receives text, including `` `n `` for Enter, `` `t `` for Tab, `Chr(27)` for Esc and AltGr characters. OnKeyDown receives everything else: non-text keys reset the state, Backspace recomputes it.
- **The InputHook never sees a key that one of the script's hotkeys suppressed.** In `hook.cpp`, `CollectInput()` only runs on the pass-through path. So the hotkey handler feeds the core itself.
- **No feedback loop:** the script sends with SendEvent at SendLevel 0. The InputHook's MinSendLevel is 1, so it ignores that output, and the script's level-0 hotkeys ignore it too.
- **SendEvent instead of SendInput.** The docs say SendInput uninstalls and reinstalls the script's hook around every send. That changes hook order relative to aText and leaves a gap where keys go unseen. SendEvent uses `SetKeyDelay -1,-1`, so there is no Sleep.
- **Letter/Space hotkeys use `HotIf(callback)`.** The keyboard hook waits while the main thread evaluates the callback, so the decision is made in key order. This costs a few microseconds per letter or Space press, not zero. `#HotIfTimeout 50`: if evaluation ever stalls, the key passes through untouched.
- **The HotIf check refuses** (the key passes untouched) when:
  - typed text has not been processed yet (`StrLen(ih.Input) != gSeen`)
  - a callback is updating the state
  - the previous decision is still in flight
  - the active window changed
  - the previous key was a dead key (´ ^)
- **Window changes:** detected by `SetWinEventHook(EVENT_SYSTEM_FOREGROUND)`, with a synchronous active-window check as backup.
- **Exclusions:** the `ahk_group AutoCapExclude` group.
- **Single instance:** handled manually, so that a `--test` run never closes the running copy.

## Running alongside aText and other AHK scripts

AutoCap acts only at a sentence start or line start. There it blocks the
lowercase key and types the capital as a Unicode character at SendLevel 0. At
a line start it also blocks Space. It ignores level-0 output from other AHK
scripts, but it sees aText's output: AutoHotkey treats input from non-AHK
programs as normal typing.

**Start order matters.** Windows passes each keystroke to the most recently
installed hook first. A tool started after AutoCap therefore sees the original
key before AutoCap blocks it. AutoCap can start these tools itself:

1. Put their full paths in `AUTOCAP_COMPANIONS` at the top of the script: aText's `.exe` and any `.ahk` scripts.
2. Remove them from their own autostart: aText's "start at login" option, and their shortcuts in `shell:startup`.

With `AUTOCAP_RESTART_COMPANIONS := true` (the default), AutoCap restarts any
companion that is already running, for example after Reload. An `.ahk` script
is closed normally (WM_CLOSE). An `.exe` is terminated, because aText has no
documented close command, so don't reload AutoCap while you're editing an aText
snippet. The tray menu also has **Restart companion programs**.

AutoCap keeps its keyboard hook installed while disabled (`InstallKeybdHook`).
Without that, disabling would remove the hook, and re-enabling would put
AutoCap in front of the companions again (`hook.cpp`, `ChangeHookState`).

**Avoid in other AHK scripts:**
- hotkeys or remaps on plain letters (a–z ä ö ü) or on Space (`Space & x::`, `~Space::`)
- `SendLevel` or `#InputLevel` of 1 or higher for anything that types text. AutoCap would treat that output as your typing.
- long `SendInput` text. The docs say SendInput falls back to SendEvent whenever another script's hook is installed, so your keystrokes can mix into it. Paste via the clipboard instead.
- InputHooks that aren't visible (they block text), and `BlockInput`

**aText:**
- Give abbreviations a non-letter prefix (`;bef`). AutoCap then never blocks any of their keys.
- Write snippets with correct capitals.
- Test a snippet such as `test. hallo welt`. If aText types snippets as ordinary key presses, AutoCap could capitalise inside a snippet, out of order. If aText pastes them or types Unicode characters, AutoCap leaves them alone.

## Status / open items

- [ ] Run `--test` once on the real Windows machine
- [ ] Manual checklist below
- [ ] Fill in the dictation/RIS placeholder lines in the exclusion group (top of the script)
- [ ] Put aText (and any other AHK scripts) in `AUTOCAP_COMPANIONS` and remove them from their own autostart
- [ ] **aText:** check that a plain-letter abbreviation still expands at a sentence start, and that a snippet like `test. hallo welt` is never scrambled. If it is, consider a guard against keys arriving faster than a human can type.
- [ ] RIS over Citrix/RDP: capitals are sent as Unicode text (VK_PACKET); check that they arrive

## Manual checklist (Windows)

1. Notepad: `hallo. welt`, `ende. äpfel`, Enter + spaces + text, Shift+Space at a line start, `z.B. die`, `am 3. november`.
2. Word: the same; Word's own autocorrect may also capitalise (redundant, harmless).
3. Browser textarea: the same, plus a click into the middle of existing text after `x. `. The next letter must stay lowercase.
4. Outlook: message body and subject, and clicking between them.
5. Rapid typing: `test. hallo` about 20 times as fast as possible. No `hAllo`, no lost letters.
6. Holding a key: at a sentence start, hold `a` → `Aaaa…`. At a line start, hold Space → nothing appears, no AHK warning dialog.
7. AltGr: `test@ x`, `{` `}` `€`. Normal characters, no reset.
8. aText: an abbreviation at a sentence start and after Enter still expands. Also after Ctrl+Alt+Shift+K twice, and after Reload.
9. Windows Terminal / VS Code: nothing is capitalised.
10. Toggle: Ctrl+Alt+Shift+K and the tray menu (Enable/Disable, Edit script, Reload, Exit); the icon changes when disabled.
