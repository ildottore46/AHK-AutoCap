# Scenarios typed by run.sh; expected output is in tools/integration/expected.txt
# 1 sentence + line start + swallow
xdotool type --delay 50 "hello. world"
xdotool key --delay 50 Return space space n e x t space l i n e exclam space o k Return
# 2 abbreviations / numbers / ellipsis / internal dot / roman
xdotool type --delay 50 "v.a. pneumonie, am 3. nov, ok... and, www.x.de. dann, grad II. die"
xdotool key Return
# 4 arrow key resets
xdotool type --delay 50 "drei. "
xdotool key Left Right
xdotool type --delay 50 "vier"
xdotool key Return
# 5 backspace recompute
xdotool type --delay 50 "end.x"
xdotool key BackSpace
xdotool type --delay 50 " word"
xdotool key Return
# 6 Shift+Space escape hatch at line start, uppercase left alone
xdotool key shift+space
xdotool type --delay 50 "hallo. Schon gut. ja"
xdotool key Return
# 7 Ctrl shortcut resets (Ctrl+End keeps caret at end)
xdotool type --delay 50 "fuenf. "
xdotool key ctrl+End
xdotool type --delay 50 "sechs"
xdotool key Return
# 8 rapid typing (5 ms between keys)
xdotool type --delay 5 "schnell. getippt. text"
xdotool key Return
# 9 quote closers and openers
xdotool type --delay 50 "er sagte \"nein.\" dann. (siehe oben)"
xdotool type --delay 50 "on. yes"
xdotool key ctrl+alt+shift+k; sleep 0.5
xdotool key Return
xdotool type --delay 50 "off. no"
xdotool key ctrl+alt+shift+k; sleep 0.5
xdotool key Return
xdotool type --delay 50 "back. yes"
xdotool key shift+Return
xdotool type --delay 50 "shift enter"
xdotool key KP_Enter
xdotool type --delay 50 "numpad enter"
