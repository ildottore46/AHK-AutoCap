; aText-probe.ahk - finds out how aText reacts to keys typed by another program,
; which decides AUTOCAP_COMPANION_ORDER and AUTOCAP_CAPITAL_SEND in AutoCap.ahk.
;
; 1. Put one of your aText abbreviations below (as you normally type it).
; 2. Disable AutoCap (Ctrl+Alt+Shift+K) so it does not interfere.
; 3. Run this script, open Notepad, click into it.
; 4. Press F1, F2, F3 and F4, each on a new line. For F3/F4 type the REST of the
;    abbreviation yourself right after the key (e.g. F3, then "fg"), plus aText's
;    trigger key (Space/Enter) if your aText needs one.
; 5. Note which ones expanded, press Esc to quit, and see the table in the README.
;
;   F1  types the whole abbreviation as real keystrokes from another program
;   F2  types the whole abbreviation as Unicode characters from another program
;   F3  types the first letter as a CAPITAL Unicode character    (AutoCap "text")
;   F4  types the first letter as Shift + the real key            (AutoCap "key")
#Requires AutoHotkey v2.0
#SingleInstance Force

ABBR := "mfg"     ; <<< replace with one of your aText abbreviations

SetKeyDelay(-1, -1)
first := SubStr(ABBR, 1, 1)
F1::SendEvent("{Blind}" ABBR)                     ; translated to normal key presses
F2::SendEvent("{Text}" ABBR)                      ; VK_PACKET Unicode characters
F3::SendEvent("{Text}" StrUpper(first))
F4::SendEvent("{Blind}{LShift down}{vk" Format("{:02X}", GetKeyVK(first)) "}{LShift up}")
Esc::ExitApp()
TrayTip("F1-F4 ready. Abbreviation: " ABBR "`nEsc quits.", "aText probe")
