#!/bin/bash
# End-to-end test: Xvfb + openbox + Wine Notepad + AutoCap, keys typed with xdotool,
# Notepad's text read back by read-notepad.ahk.  Usage: tools/integration/run.sh [scenario.sh]
# Needs: wine64, xvfb, openbox, xdotool, tools/fetch-ahk.sh run once.
# Known harness artifact: after a SECOND mouse click Wine drops all further keystrokes,
# even with no AHK running - so clicks are not tested here.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCEN="${1:-$ROOT/tools/integration/scenarios.sh}"
W=$(command -v wine64 || echo /usr/lib/wine/wine64)
AHK="$ROOT/tools/.ahk/AutoHotkey64.exe"
export WINEDEBUG=-all WINEPREFIX="${WINEPREFIX:-$ROOT/tools/.wineprefix}" DISPLAY=:57
cd "$ROOT"
Xvfb :57 -screen 0 1280x800x24 >/dev/null 2>&1 & XV=$!
sleep 2; openbox >/dev/null 2>&1 & sleep 1
$W notepad >/dev/null 2>&1 & sleep 4
[ -n "${NOAC:-}" ] || { $W "$AHK" /ErrorStdOut AutoCap.ahk > /tmp/autocap.out 2>&1 & sleep 4; }
NP=$(xdotool search --name "Notepad" | head -1)
# Wine without focus: give Notepad focus with ONE real click (also exercises the click reset)
eval "$(xdotool getwindowgeometry --shell "$NP")"; xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 1
NP=$NP bash "$SCEN"
sleep 2
timeout 30 $W "$AHK" /ErrorStdOut tools/integration/read-notepad.ahk 2>&1 | sed 's/\\r\\n/\n/g'
echo "--- AutoCap output:"; cat /tmp/autocap.out 2>/dev/null
"$(dirname "$W")/wineserver" -k 2>/dev/null; kill $XV 2>/dev/null; wait 2>/dev/null
