#!/bin/bash
# Runs AutoCap.ahk --test under Wine (Linux). Needs: wine64, xvfb, tools/fetch-ahk.sh run once.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WINE=$(command -v wine64 || echo /usr/lib/wine/wine64)
export WINEDEBUG=-all WINEPREFIX="${WINEPREFIX:-$ROOT/tools/.wineprefix}"
cd "$ROOT"
xvfb-run -a "$WINE" tools/.ahk/AutoHotkey64.exe /ErrorStdOut AutoCap.ahk --test 2>&1 | grep -v "X connection"
exit "${PIPESTATUS[0]}"
