; Test companion: maps x -> Y. If its hook runs BEFORE AutoCap's, "ende. x" becomes
; "ende. Y"; if AutoCap's hook runs first, AutoCap capitalises the x first: "ende. X".
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
FileAppend("companion.ahk started pid " ProcessExist() "`n", A_ScriptDir "\launch.log")
$x::SendEvent("{Text}Y")
