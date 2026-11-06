; =============================================================================
; AutoCap.ahk  -  sentence-start capitalisation for Windows 11 (AutoHotkey v2)
; -----------------------------------------------------------------------------
; What it does
;   * Capitalises the first letter of every sentence as you type, system-wide:
;     after . ! ? followed by space(s), and after Enter / Shift+Enter /
;     NumpadEnter.
;   * Swallows Space at the very start of a new line (Shift+Space still types
;     a space - deliberate escape hatch).
;   * Tuned for German QWERTZ: a-z, ä ö ü (ß is left alone), no capital after
;     numbers/dates (am 3. November), Roman numerals (Grad II. die),
;     ellipsis (...), dotted tokens (www.x.de) or abbreviations (list below).
;   * When it cannot know where the caret is (mouse click, arrow keys,
;     shortcuts, window change, ...) it does nothing until you type again.
;
; Toggle:    Ctrl+Alt+Shift+K   (or the tray menu). Disabled = "suspended" icon.
; Autostart: Win+R -> shell:startup -> create a shortcut to this file there.
; Tests:     AutoHotkey64.exe /ErrorStdOut AutoCap.ahk --test
; =============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Off          ; handled manually below so that --test never kills the live instance
#HotIfTimeout 50             ; if the main thread ever stalls, keys pass through untouched after 50 ms

; ----------------------------- CONFIGURATION ---------------------------------
; Abbreviations: no capital after these. Space-separated, case-insensitive,
; each entry ends with its final dot.
global AUTOCAP_ABBREVIATIONS := "
(Join`s
z.B. d.h. u.a. bzw. ggf. ca. evtl. etc. vs. Dr. Prof. Nr. Fa. ggü. V.a. Z.n.
re. li. bds. max. min. i.v. e.g. i.e.
o.B. a.p. p.a. i.m. s.c. ant. post. lat. med. dist. prox. sog.
)"

; Characters allowed between . ! ? and the space (closing quotes/brackets).
global AUTOCAP_CLOSERS := "`"')»“”"
; Characters allowed after the trigger / at line start before the letter.
global AUTOCAP_OPENERS := "([{`"'„“«»‚‘"

; Windows where AutoCap is completely off.
GroupAdd("AutoCapExclude", "ahk_exe WindowsTerminal.exe")
GroupAdd("AutoCapExclude", "ahk_exe cmd.exe")
GroupAdd("AutoCapExclude", "ahk_exe powershell.exe")
GroupAdd("AutoCapExclude", "ahk_exe pwsh.exe")
GroupAdd("AutoCapExclude", "ahk_exe Code.exe")
; >>> PLACEHOLDER: dictation program  - replace the exe name and uncomment
; GroupAdd("AutoCapExclude", "ahk_exe YOUR_DICTATION_PROGRAM.exe")
; >>> PLACEHOLDER: RIS program        - replace the exe name and uncomment
; GroupAdd("AutoCapExclude", "ahk_exe YOUR_RIS_PROGRAM.exe")

; Send level of the capital letters this script types. 0 = other AHK scripts'
; hotkeys/hotstrings ignore them (AHK convention). 1 = they can see them.
; Must stay below AUTOCAP_MIN_INPUT_LEVEL so the script never reads its own output.
global AUTOCAP_SENDLEVEL := 0
global AUTOCAP_MIN_INPUT_LEVEL := AUTOCAP_SENDLEVEL + 1
; -----------------------------------------------------------------------------


; =============================================================================
; PURE CORE  (no Windows calls)
;   Feed(key)  -> "pass" | "upper" | "swallow"   (decides AND commits)
;   Peek(key)  -> same action, no state change   (used by the HotIf check)
;   Observe(c) -> commit a character that was already typed as-is
;   key: one character, "`n" (Enter), "BS" (Backspace) or "Reset"
;   Mode: "unknown" | "none" | "cap" (capitalise next letter)
;         | "line" (capitalise next letter + swallow Space)
; =============================================================================
class AutoCapCore {
    static MAXBUF := 32

    __New(abbrevs, closers, openers) {
        this.closers := closers
        this.openers := openers
        this.abbr := Map()
        this.abbrList := []
        for a in StrSplit(abbrevs, " ") {
            a := Trim(a)
            if (a = "")
                continue
            a := StrLower(a)
            if (SubStr(a, -1) != ".")
                a .= "."
            this.abbr[a] := true
            this.abbrList.Push(a)
        }
        this.Reset()
    }

    Reset() {
        this.buf := ""
        this.mode := "unknown"
    }

    Peek(key) {
        m := this.mode
        if (m != "cap" && m != "line")
            return "pass"
        if (key == " ")
            return (m = "line") ? "swallow" : "pass"
        if (StrLen(key) = 1 && RegExMatch(key, "^[a-zäöü]$"))   ; case-sensitive: lowercase only
            return "upper"
        return "pass"
    }

    Feed(key) {
        if (key == "BS") {
            this.Backspace()
            return "pass"
        }
        if (key == "Reset") {
            this.Reset()
            return "pass"
        }
        act := this.Peek(key)
        this.Apply(key, act)
        return act
    }

    Observe(ch) {
        this.Apply(ch, "pass")
    }

    Apply(ch, act) {
        if (act = "swallow")
            return
        this.Commit(act = "upper" ? StrUpper(ch) : ch)
    }

    Backspace() {
        if (this.buf = "") {
            this.Reset()
            return
        }
        b := SubStr(this.buf, 1, -1)
        if (b = "") {
            this.Reset()
            return
        }
        this.buf := b
        this.mode := this.ComputeMode(b)
    }

    Commit(s) {
        b := this.buf . s
        if (StrLen(b) > AutoCapCore.MAXBUF)
            b := SubStr(b, -AutoCapCore.MAXBUF)
        m := this.ComputeMode(b)
        this.buf := b          ; mode is assigned last: a reader never sees a newer
        this.mode := m         ; mode paired with an older buffer
    }

    ComputeMode(b) {
        if (b = "")
            return "unknown"
        t := RTrim(b, this.openers)
        if (t != b) {          ; ends with opening quote/bracket(s)
            if (t != "" && (SubStr(t, -1) == "`n" || RegExMatch(t, "`n +$") || this.IsSentenceEnd(t)))
                return "cap"
            return "none"
        }
        if (SubStr(b, -1) == "`n")
            return "line"
        if RegExMatch(b, "`n +$")        ; Shift+Space indentation: still capitalise, stop swallowing
            return "cap"
        return this.IsSentenceEnd(b) ? "cap" : "none"
    }

    ; s ends with one or more spaces after . ! ? (+ optional closers)
    IsSentenceEnd(s) {
        if (SubStr(s, -1) != " ")
            return false
        t := RTrim(s, " ")
        t := RTrim(t, this.closers)
        if (StrLen(t) < 2)               ; nothing known before the punctuation
            return false
        p := SubStr(t, -1)
        if (p == "!" || p == "?")
            return true
        if (p != ".")
            return false
        body := SubStr(t, 1, -1)
        if (SubStr(body, -1) == ".")     ; ellipsis
            return false
        if RegExMatch(body, "[ `t`n]([^ `t`n]*)$", &mt) {
            token := mt[1], atEdge := false
        } else {
            token := body, atEdge := true    ; token touches the start of what we saw
        }
        token := LTrim(token, this.openers)
        if (token = "")
            return false
        if RegExMatch(token, "^[0-9.]+$")                    ; 3.  12.03.  3.5.
            return false
        if RegExMatch(token, "^(?:X{0,3})(?:IX|IV|V?I{0,3})$")   ; I. - XXXIX. (uppercase only)
            return false
        if InStr(token, ".")                                 ; a.p  www.x.de  (internal dot)
            return false
        low := StrLower(token) "."
        if this.abbr.Has(low)
            return false
        if atEdge {
            ; we may only see the tail of a longer token (e.g. "tc." of "etc.")
            for a in this.abbrList
                if (StrLen(a) >= StrLen(low) && SubStr(a, -StrLen(low)) = low)
                    return false
        }
        return true
    }
}


; =============================================================================
; TESTS  (--test)
; =============================================================================
AutoCap_RunTests() {
    ; input  -> expected.   \n = Enter, <BS> = Backspace, <SSPACE> = Shift+Space,
    ; <CLICK> = any reset event (click, arrow, shortcut, window change), <TAB> = Tab
    cases := [
        ["hello. world",            "hello. World"],
        ["\nhello",                 "\nHello"],
        ["\n   hello",              "\nHello"],
        ["wow!  great",             "wow!  Great"],
        ["ende. äpfel",             "ende. Äpfel"],
        ["done.\n\nnext",           "done.\n\nNext"],
        ['he said "no." then',      'he said "no." Then'],
        ["am 3. november",          "am 3. november"],
        ["z.B. die lunge",          "z.B. die lunge"],
        ["V.a. pneumonie",          "V.a. pneumonie"],
        ["ok... and",               "ok... and"],
        ["3.5 cm",                  "3.5 cm"],
        ["file.txt is",             "file.txt is"],
        ["end.x<BS> word",          "end. Word"],
        ["\n<BS>hello",             "hello"],
        ; --- additional cases ---
        ["ende? ja",                "ende? Ja"],
        ["ende. Schon",             "ende. Schon"],
        ["ende. ßx",                "ende. ßx"],
        ["ende. 3 äpfel",           "ende. 3 äpfel"],
        ["ende. (siehe oben)",      "ende. (Siehe oben)"],
        ["\n„nein",                 "\n„Nein"],
        ["\n(siehe",                "\n(Siehe"],
        ["\n- befund",              "\n- befund"],
        ["(z.B. die",               "(z.B. die"],
        ["herz o.B. die",           "herz o.B. die"],
        ["siehe www.x.de. dann",    "siehe www.x.de. dann"],
        ["am 12.03. war",           "am 12.03. war"],
        ["grad II. die",            "grad II. die"],
        ["ein ggÜ. die",            "ein ggÜ. die"],
        ["herr DR. müller",         "herr DR. müller"],
        ["(siehe oben.) weiter",    "(siehe oben.) Weiter"],
        ["er sagt. 'ja",            "er sagt. 'Ja"],
        ["tc. und",                 "tc. und"],
        [". und",                   ". und"],
        ["\n<SSPACE>hallo",         "\n Hallo"],
        ["\n  \n  hi",              "\n\nHi"],
        ["ende. <CLICK>hallo",      "ende. hallo"],
        ["ende.<CLICK> hallo",      "ende. hallo"],
        ["ende. <TAB>hallo",        "ende. `thallo"],
        ["ende.  <BS>hallo",        "ende. Hallo"],
        ["ende. h<BS>hallo",        "ende. Hallo"],
        ["\nhallo.<BS><BS>x",       "\nHallx"],
        ["max. wert",               "max. wert"],
        ["wort. tschüss",           "wort. Tschüss"],
    ]
    fails := 0
    for c in cases {
        input := StrReplace(c[1], "\n", "`n")
        expect := StrReplace(c[2], "\n", "`n")
        core := AutoCapCore(AUTOCAP_ABBREVIATIONS, AUTOCAP_CLOSERS, AUTOCAP_OPENERS)
        out := ""
        i := 1
        while (i <= StrLen(input)) {
            if RegExMatch(input, "\G<(BS|SSPACE|CLICK|TAB)>", &m, i) {
                tok := m[1]
                i += m.Len
                switch tok {
                    case "BS":
                        core.Feed("BS")
                        out := SubStr(out, 1, -1)
                    case "SSPACE":          ; Shift+Space is never intercepted: observed as typed
                        core.Observe(" ")
                        out .= " "
                    case "CLICK":
                        core.Feed("Reset")
                    case "TAB":             ; Tab passes through, but resets the state
                        core.Feed("Reset")
                        out .= "`t"
                }
                continue
            }
            ch := SubStr(input, i, 1)
            i += 1
            act := core.Feed(ch)
            if (act = "upper")
                out .= StrUpper(ch)
            else if (act = "pass")
                out .= ch
        }
        ok := (out == expect)
        if !ok
            fails += 1
        FileAppend((ok ? "PASS  " : "FAIL  ") Show(c[1]) "  ->  " Show(out)
            . (ok ? "" : "   (expected " Show(expect) ")") "`n", "*", "UTF-8")
    }
    FileAppend("`n" (cases.Length - fails) "/" cases.Length " passed`n", "*", "UTF-8")
    return fails

    Show(s) => '"' StrReplace(StrReplace(s, "`n", "\n"), "`t", "\t") '"'
}

if (A_Args.Length && A_Args[1] = "--test") {
    A_IconHidden := true
    ExitApp(AutoCap_RunTests() ? 1 : 0)
}


; =============================================================================
; RUNTIME GLUE  (Windows side)
;
; How the pieces fit (verified against the v2 docs and the v2.0 hook source):
;  * One InputHook ("V" = visible, never blocks anything) observes typing.
;    OnChar gets text (incl. Enter = "`n", Tab = "`t", Esc = Chr(27), AltGr
;    characters). NotifyNonText makes OnKeyDown fire for everything that does
;    not produce text: arrows, Delete, F-keys, Ctrl/Alt/Win shortcuts, and
;    Backspace (option "B" stops the hook treating it as text).
;  * A key suppressed by one of this script's hotkeys never reaches the
;    script's InputHook (hook.cpp only calls CollectInput() on the pass-through
;    path), so the hotkey handler feeds the core itself.
;  * The script types with SendEvent at AUTOCAP_SENDLEVEL. The InputHook has
;    MinSendLevel = AUTOCAP_SENDLEVEL + 1, so it never sees that output, and
;    the script's own hotkeys (level 0) ignore it as well. SendEvent is used
;    instead of SendInput because SendInput uninstalls and reinstalls the
;    script's hook around every send (which changes hook order relative to
;    aText and opens a gap in which keys go unseen).
;  * Letter and Space hotkeys use HotIf(callback). The keyboard hook blocks
;    and asks the main thread to evaluate the callback, so the decision is
;    made in key order. The callback refuses (keys pass through untouched)
;    whenever the core might be behind: input not yet processed, a
;    callback mid-update, a hotkey still in flight, or a changed active window.
; =============================================================================

global gCore := AutoCapCore(AUTOCAP_ABBREVIATIONS, AUTOCAP_CLOSERS, AUTOCAP_OPENERS)
global gIH := 0              ; the InputHook
global gSeen := 0            ; characters processed by OnChar since the hook was started
global gBusy := false        ; a callback is mutating the core
global gInFlight := 0        ; decision handed from HotIf to the hotkey handler
global gHwnd := 0            ; active window the core state belongs to
global gExcluded := false
global gWinEventHook := 0
global gWinEventCb := 0
global gDeadKeys := Map()
global gKeyChar := Map()     ; "$a" -> "a"

AutoCap_Main()
return

AutoCap_Main() {
    global gIH, gWinEventCb, gWinEventHook
    ; --- single instance: close an older copy of this script. (A --test run
    ;     exits before reaching this point, so it never closes the live copy.)
    DetectHiddenWindows(true)
    for hwnd in WinGetList(A_ScriptFullPath " ahk_class AutoHotkey")
        if (hwnd != A_ScriptHwnd)
            WinClose(hwnd)
    DetectHiddenWindows(false)

    Persistent(true)
    A_MaxHotkeysPerInterval := 1000      ; holding Space at a line start fires repeatedly
    SetKeyDelay(-1, -1)                  ; SendEvent without any sleep
    SendMode("Event")
    A_SendLevel := AUTOCAP_SENDLEVEL

    ; dead keys on the German layout (^ and ´): don't capitalise right after one
    for vk in ["vkDC", "vkDD"] {
        n := GetKeyName(vk)
        if (n != "")
            gDeadKeys[n] := true
        gDeadKeys[vk] := true
    }

    ; --- observer ---
    gIH := InputHook("V B I" AUTOCAP_MIN_INPUT_LEVEL)
    gIH.NotifyNonText := true
    gIH.OnChar := AutoCap_OnChar
    gIH.OnKeyDown := AutoCap_OnKeyDown
    gIH.OnEnd := AutoCap_OnEnd

    ; --- always-on hotkeys ---
    HotIf()
    Hotkey("^!+k", AutoCap_Toggle, "S")          ; Ctrl+Alt+Shift+K, exempt from Suspend
    for btn in ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
        Hotkey("~*" btn, AutoCap_OnMouse)

    ; --- action hotkeys: only fire while the state needs an action ---
    HotIf(AutoCap_HotIfCheck)
    failed := ""
    usedVK := Map()
    for k in StrSplit("abcdefghijklmnopqrstuvwxyzäöü") {
        ; one hotkey per physical key: a layout without ä/ö/ü may map them onto
        ; a/o/u (Wine does), which would silently turn "o" into "Ö"
        vk := GetKeyVK(k)
        if (!vk || usedVK.Has(vk)) {
            failed .= k
            continue
        }
        try {
            Hotkey("$" k, AutoCap_OnActionKey, "B")
            gKeyChar["$" k] := k
            usedVK[vk] := true
        } catch
            failed .= k
    }
    Hotkey("$Space", AutoCap_OnActionKey, "B")
    gKeyChar["$Space"] := " "
    HotIf()

    ; --- window changes ---
    gWinEventCb := CallbackCreate(AutoCap_OnForeground, , 7)
    gWinEventHook := DllCall("SetWinEventHook", "UInt", 0x0003, "UInt", 0x0003   ; EVENT_SYSTEM_FOREGROUND
        , "Ptr", 0, "Ptr", gWinEventCb, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")  ; WINEVENT_OUTOFCONTEXT
    OnExit(AutoCap_OnExit)

    ; --- tray ---
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Disable`tCtrl+Alt+Shift+K", AutoCap_Toggle)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Edit script", (*) => Edit())
    A_TrayMenu.Add("Reload", (*) => Reload())
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    A_TrayMenu.Default := "1&"

    AutoCap_ApplyEnabled()
    if (failed != "")
        TrayTip("These keys don't exist on the current keyboard layout: " failed, "AutoCap", "Iconi Mute")
}

; ---------------------------------------------------------------- enable/disable
AutoCap_Toggle(*) {
    Suspend(-1)
    AutoCap_ApplyEnabled()
}

AutoCap_ApplyEnabled() {
    global gBusy, gInFlight, gSeen
    gBusy := true
    try {
        gInFlight := 0
        gCore.Reset()
        if A_IsSuspended {
            gIH.Stop()
            A_TrayMenu.Rename("1&", "Enable`tCtrl+Alt+Shift+K")
            A_IconTip := "AutoCap - disabled"
        } else {
            gSeen := 0
            gIH.Start()
            AutoCap_UpdateWindow()
            A_TrayMenu.Rename("1&", "Disable`tCtrl+Alt+Shift+K")
            A_IconTip := "AutoCap - enabled"
        }
    } finally gBusy := false
}

; ---------------------------------------------------------------- HotIf decision
; Runs synchronously while the keyboard hook waits. Side effects are limited
; to gInFlight; a stale value can only make the script do nothing for a moment.
AutoCap_HotIfCheck(hk) {
    global gInFlight
    if (gBusy || gExcluded || !gIH.InProgress)
        return false
    if (IsObject(gInFlight) && A_TickCount - gInFlight.tick < 500)
        return false                                   ; previous decision not executed yet
    if (StrLen(gIH.Input) != gSeen)
        return false                                   ; typed text not processed yet
    if (WinExist("A") != gHwnd)
        return false                                   ; window changed, event not processed yet
    if gDeadKeys.Has(A_PriorKey)
        return false                                   ; ´ or ^ pending in the target app
    if !gKeyChar.Has(hk)
        return false
    act := gCore.Peek(gKeyChar[hk])
    if (act = "pass")
        return false
    gInFlight := {hk: hk, act: act, tick: A_TickCount}
    return true
}

; ---------------------------------------------------------------- hotkey action
AutoCap_OnActionKey(hk) {
    global gBusy, gInFlight
    SendLevel(AUTOCAP_SENDLEVEL)          ; hotkey threads start at the hotkey's input level
    gBusy := true
    try {
        ch := gKeyChar[hk]
        d := gInFlight
        act := (IsObject(d) && d.hk == hk) ? d.act : "pass"   ; decision lost -> type the key unchanged
        gCore.Apply(ch, act)
        if (act = "upper")
            SendEvent("{Text}" StrUpper(ch))
        else if (act = "pass")
            SendEvent("{Text}" ch)
        ; "swallow": nothing is typed
    } finally {
        gInFlight := 0
        gBusy := false
    }
}

; ---------------------------------------------------------------- observer
AutoCap_OnChar(ih, chars) {
    global gBusy, gSeen
    gBusy := true
    try {
        if (WinExist("A") != gHwnd) {
            AutoCap_UpdateWindow()
            gCore.Reset()                 ; we can't tell which window got these characters
        } else if !gExcluded {
            Loop Parse chars {
                c := A_LoopField
                if (c == "`n")
                    gCore.Feed("`n")
                else if (Ord(c) < 32 || Ord(c) = 127)   ; Tab, Esc, other control characters
                    gCore.Reset()
                else
                    gCore.Observe(c)
            }
        }
        gSeen += StrLen(chars)
        ; keep the InputHook buffer short (HotIf reads it on every letter key)
        if (gSeen >= 256 && StrLen(ih.Input) = gSeen) {
            ih.Stop()
            gSeen := 0
            gCore.Reset()
            ih.Start()
        }
    } finally gBusy := false
}

AutoCap_OnKeyDown(ih, vk, sc) {
    global gBusy
    switch vk {
        case 0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C, 0x14, 0x90, 0x91:
            return                        ; modifiers and lock keys alone
    }
    gBusy := true
    try {
        if (vk = 0x08 && !GetKeyState("Ctrl") && !GetKeyState("Alt") && !GetKeyState("LWin") && !GetKeyState("RWin"))
            gCore.Feed("BS")              ; plain or Shift+Backspace
        else
            gCore.Reset()                 ; arrows, Home/End, PgUp/PgDn, Del, Ins, F-keys, Ctrl/Alt/Win+key, Ctrl+BS ...
    } finally gBusy := false
}

AutoCap_OnEnd(ih) {
    global gBusy, gSeen
    if (A_IsSuspended || ih.InProgress)
        return
    gBusy := true
    try {
        gSeen := 0
        gCore.Reset()
        ih.Start()
    } finally gBusy := false
}

AutoCap_OnMouse(*) {
    global gBusy
    gBusy := true
    try gCore.Reset()
    finally gBusy := false
}

AutoCap_OnForeground(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    global gBusy
    gBusy := true
    try {
        gCore.Reset()
        AutoCap_UpdateWindow()
    } finally gBusy := false
}

AutoCap_UpdateWindow() {
    global gHwnd, gExcluded
    gHwnd := WinExist("A")
    gExcluded := gHwnd && WinActive("ahk_group AutoCapExclude")
}

AutoCap_OnExit(*) {
    if gWinEventHook
        DllCall("UnhookWinEvent", "Ptr", gWinEventHook)
}
