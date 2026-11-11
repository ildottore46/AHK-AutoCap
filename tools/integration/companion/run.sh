#!/bin/bash
# Checks that AutoCap starts its companions AFTER its own hook (companion hook first),
# that this survives disable/enable, and that a second AutoCap start restarts them.
# MODE=before: AutoCap's hook goes in front, so all three lines must read "X".
# Needs the same packages as ../run.sh.
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"; HERE="$ROOT/tools/integration/companion"
W=$(command -v wine64 || echo /usr/lib/wine/wine64); AHK="$ROOT/tools/.ahk/AutoHotkey64.exe"
export WINEDEBUG=-all WINEPREFIX="${WINEPREFIX:-$ROOT/tools/.wineprefix}" DISPLAY=:58
WHERE=$(winepath -w "$HERE" 2>/dev/null || $W winepath -w "$HERE")
cp "$AHK" "$HERE/Companion2.exe"; rm -f "$HERE/launch.log"
# .ahk file association inside the Wine prefix (real Windows has one already)
$W reg add 'HKLM\Software\Classes\.ahk' /ve /d AutoHotkeyScript /f >/dev/null 2>&1
$W reg add 'HKLM\Software\Classes\AutoHotkeyScript\Shell\Open\Command' /ve /d "\"$(winepath -w "$AHK" 2>/dev/null || $W winepath -w "$AHK")\" \"%1\"" /f >/dev/null 2>&1
# AutoCap copy with the two companions configured (MODE=nohook drops InstallKeybdHook as a control)
python3 - "$ROOT/AutoCap.ahk" "$HERE/AutoCapC.ahk" "$WHERE" "${MODE:-}" <<'PY'
import sys,re
src,dst,where,mode=sys.argv[1:5]; s=open(src,encoding='utf8').read()
new='global AUTOCAP_COMPANIONS := [\n    "%s\\companion.ahk",\n    "%s\\Companion2.exe",\n]' % (where,where)
s=re.sub(r'global AUTOCAP_COMPANIONS := \[.*?\n\]', lambda m: new, s, flags=re.S)
if mode=='nohook': s=s.replace('    InstallKeybdHook(true)\n','')
if mode=='before': s=s.replace('global AUTOCAP_COMPANION_ORDER := "after"','global AUTOCAP_COMPANION_ORDER := "before"')
open(dst,'w',encoding='utf8').write(s)
PY
cd "$ROOT"
Xvfb :58 -screen 0 1280x800x24 >/dev/null 2>&1 & XV=$!; sleep 2; openbox >/dev/null 2>&1 & sleep 1
$W notepad >/dev/null 2>&1 & sleep 4
NP=$(xdotool search --name "Notepad" | head -1)
focus() { xdotool windowactivate --sync "$NP" >/dev/null 2>&1; sleep 0.5; }
if [ "${MODE:-}" = "reverse" ]; then   # control: companion first, then AutoCap without companions
  $W "$AHK" "$HERE/companion.ahk" & sleep 3
  sed -i 's#^    ".*companion.ahk",$##; s#^    ".*Companion2.exe",$##' "$HERE/AutoCapC.ahk"
fi
$W "$AHK" /ErrorStdOut "$HERE/AutoCapC.ahk" > /tmp/autocapc.out 2>&1 & sleep 14
focus; xdotool type --delay 60 "ende. x"; xdotool key Return
xdotool key ctrl+alt+shift+k; sleep 0.5; xdotool key ctrl+alt+shift+k; sleep 0.5
xdotool type --delay 60 "nach toggle. x"; xdotool key Return
if [ -z "${MODE:-}" ] || [ "${MODE:-}" = "before" ]; then
  $W "$AHK" /ErrorStdOut "$HERE/AutoCapC.ahk" > /tmp/autocapc2.out 2>&1 & sleep 12   # second start = reload
  focus; xdotool type --delay 60 "nach neustart. x"
fi
sleep 2
timeout 30 $W "$AHK" /ErrorStdOut "$ROOT/tools/integration/read-notepad.ahk" 2>&1 | sed 's/\\r\\n/\n/g' | grep -v '^WINDOWS'
echo "--- launch.log:"; cat "$HERE/launch.log" 2>/dev/null
echo "--- AutoCap output:"; cat /tmp/autocapc.out /tmp/autocapc2.out 2>/dev/null
"$(dirname "$W")/wineserver" -k 2>/dev/null; kill $XV 2>/dev/null; wait 2>/dev/null
rm -f "$HERE/AutoCapC.ahk" "$HERE/Companion2.exe" "$HERE/launch.log"
