; Run by Companion2.exe (a copy of AutoHotkey64.exe) to stand in for an .exe companion such as aText.
#Requires AutoHotkey v2.0
Persistent
FileAppend("Companion2.exe started pid " ProcessExist() "`n", A_ScriptDir "\launch.log")
