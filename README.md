# AutoCap

AutoHotkey v2 script for Windows 11. It capitalises the first letter of every
sentence as you type, in every application, and keeps new lines from starting
with a space. Tuned for German QWERTZ and German (radiology) text. Single
file, no dependencies: [`AutoCap.ahk`](AutoCap.ahk).

- **Toggle:** Ctrl+Alt+Shift+K, or the tray menu. When disabled, the tray icon switches to AHK's suspended icon.
- **Autostart:** Win+R → `shell:startup` → create a shortcut to `AutoCap.ahk` there.
- **Configure:** the top of the script holds the abbreviation list, the closing and opening characters, the excluded programs (with placeholders for your dictation and RIS programs) and the send level.

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
```

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

## Status / open items

- [ ] Run `--test` once on the real Windows machine
- [ ] Manual checklist below
- [ ] Fill in the dictation/RIS placeholder lines in the exclusion group (top of the script)
- [ ] **aText risk:** the script blocks the lowercase key and types a capital. If its hook sits before aText's, aText never sees the original key. Whether aText abbreviations still expand at a sentence start is untested. If they don't, try changing which of the two starts first.
- [ ] RIS over Citrix/RDP: capitals are sent as Unicode text (VK_PACKET); check that they arrive

## Manual checklist (Windows)

1. Notepad: `hallo. welt`, `ende. äpfel`, Enter + spaces + text, Shift+Space at a line start, `z.B. die`, `am 3. november`.
2. Word: the same; Word's own autocorrect may also capitalise (redundant, harmless).
3. Browser textarea: the same, plus a click into the middle of existing text after `x. `. The next letter must stay lowercase.
4. Outlook: message body and subject, and clicking between them.
5. Rapid typing: `test. hallo` about 20 times as fast as possible. No `hAllo`, no lost letters.
6. Holding a key: at a sentence start, hold `a` → `Aaaa…`. At a line start, hold Space → nothing appears, no AHK warning dialog.
7. AltGr: `test@ x`, `{` `}` `€`. Normal characters, no reset.
8. aText: an abbreviation at a sentence start and after Enter still expands.
9. Windows Terminal / VS Code: nothing is capitalised.
10. Toggle: Ctrl+Alt+Shift+K and the tray menu (Enable/Disable, Edit script, Reload, Exit); the icon changes when disabled.
