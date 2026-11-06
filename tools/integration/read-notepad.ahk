#Requires AutoHotkey v2.0
DetectHiddenWindows(true)
t := ""
try t := ControlGetText("Edit1", "ahk_class Notepad")
catch as e
    t := "ERR " e.Message
DetectHiddenWindows(true)
info := ""
for h in WinGetList("ahk_class AutoHotkey")
    info .= WinGetTitle(h) " | "
for h in WinGetList("ahk_exe AutoHotkey64.exe")
    if (WinGetClass(h) != "AutoHotkey")
        info .= "[" WinGetClass(h) ": " WinGetTitle(h) "] "
FileAppend("TEXT<<" StrReplace(StrReplace(t, "`r", "\r"), "`n", "\n") ">>`nWINDOWS: " info "`n", "*", "UTF-8")
