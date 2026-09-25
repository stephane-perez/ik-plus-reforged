#!/bin/bash
# runx.sh <name> <machine> <tos.img> <seconds> <key_script> [extra hatari options]
# Hatari on a virtual X display (Xvfb); keys are sent with xdotool, so they go
# through Hatari's joystick emulation. Key script lines: "t down|up|tap key".
# Joystick keys (see joy3.cfg / joy4.cfg / joyall.cfg):
#   port 1 = I J K L + U (player 1), port 0 = W A S D + Q (player 2),
#   parallel port = T F G H + R (player 3), second parallel socket = 1 2 3 4 + 5.
# Environment: HD (drive C:, default ../build/IK3J_S3), PRG (default IK_PLUS.TOS),
#              CFG (Hatari config, default joy3.cfg).
# Needs: hatari, Xvfb, xdotool.
N=$1; M=$2; T=$3; D=$4; S=$5; shift 5
R=$(cd "$(dirname "$0")" && pwd)
HD=${HD:-$R/../build/IK3J_S3}; PRG=${PRG:-IK_PLUS.TOS}; CFG=${CFG:-$R/joy3.cfg}
O=$R/out/$N; rm -rf "$O"; mkdir -p "$O"; F=$O/fifo
export DISPLAY=:77 SDL_AUDIODRIVER=dummy
pgrep -f "Xvfb :77" >/dev/null || { Xvfb :77 -screen 0 1024x768x24 >/dev/null 2>&1 & sleep 1; }
hatari --configfile "$CFG" --machine "$M" --tos "$T" --harddrive "$HD" --gemdos-drive C \
  --auto "C:\\$PRG" --screenshot-dir "$O" --cmd-fifo "$F" --sound off --fast-boot yes \
  --confirm-quit no --statusbar no --drive-led no "$@" > "$O/log.txt" 2>&1 &
P=$!; sleep 2
W=$(xdotool search --name hatari | head -1); xdotool windowfocus "$W" 2>/dev/null
for i in $(seq 1 "$D"); do
  awk -v t="$i" '$1==t' "$S" | while read -r t a k; do
    case $a in
      down) xdotool keydown "$k";;
      up)   xdotool keyup "$k";;
      tap)  xdotool keydown "$k"; sleep 0.15; xdotool keyup "$k";;
    esac
  done
  sleep 1; [ -p "$F" ] && echo "hatari-shortcut screenshot" > "$F"
done
echo "hatari-shortcut quit" > "$F" 2>/dev/null; sleep 1; kill $P 2>/dev/null; wait $P 2>/dev/null
echo "$(ls "$O" | grep -c png) screenshots in $O"
