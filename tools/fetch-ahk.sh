#!/bin/bash
# Downloads the official AutoHotkey v2 zip into tools/.ahk and verifies its SHA-256.
set -euo pipefail
cd "$(dirname "$0")"
VER=$(curl -fsSL https://www.autohotkey.com/download/2.0/version.txt)
mkdir -p .ahk && cd .ahk
curl -fsSL -o ahk.zip "https://www.autohotkey.com/download/2.0/AutoHotkey_${VER}.zip"
EXP=$(curl -fsSL "https://www.autohotkey.com/download/2.0/AutoHotkey_${VER}.zip.sha256" | grep -oiE '[a-f0-9]{64}' | tr A-F a-f)
GOT=$(sha256sum ahk.zip | cut -d' ' -f1)
[ "$EXP" = "$GOT" ] || { echo "checksum mismatch"; exit 1; }
python3 -c "import zipfile; zipfile.ZipFile('ahk.zip').extract('AutoHotkey64.exe', '.')"
echo "AutoHotkey $VER ready: $(pwd)/AutoHotkey64.exe"
