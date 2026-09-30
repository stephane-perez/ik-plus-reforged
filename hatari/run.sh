#!/bin/bash
# run.sh <name> <machine> <tos.img> <seconds> [extra hatari options]
# Headless Hatari run (no display), one screenshot per second into out/<name>/.
# Environment: HD = folder mounted as drive C: (default ../build/IK3J_PAR),
#              PRG = program started automatically (default IK_PLUS.TOS),
#              KEYS = "t:scancode ..." ST keys pressed at second t (e.g. "30:59" = F1);
#                     "t:!name" sends the Hatari shortcut "name" instead
#                     (e.g. "40:!recsound" starts/stops recording hatari.wav),
#              SHOTS = screenshots per second (default 1).
# Note: ST keys sent this way bypass Hatari's joystick emulation; use runx.sh
# to drive joysticks.
N=$1; M=$2; T=$3; D=$4; shift 4
R=$(cd "$(dirname "$0")" && pwd)
HD=${HD:-$R/../build/IK3J_PAR}; PRG=${PRG:-IK_PLUS.TOS}
O=$R/out/$N; rm -rf "$O"; mkdir -p "$O"; F=$O/fifo
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
hatari --configfile /dev/null --machine "$M" --tos "$T" --harddrive "$HD" --gemdos-drive C \
  --auto "C:\\$PRG" --screenshot-dir "$O" --cmd-fifo "$F" --sound off --fast-boot yes \
  --confirm-quit no --statusbar no --drive-led no "$@" > "$O/log.txt" 2>&1 &
P=$!
for i in $(seq 1 "$D"); do
  sleep 1; [ -p "$F" ] || continue
  for k in $KEYS; do
    if [ "${k%%:*}" = "$i" ]; then
      v=${k##*:}
      case $v in
        !*) echo "hatari-shortcut ${v#!}" > "$F" ;;
        *)  echo "hatari-event keydown $v" > "$F"; sleep 0.2; echo "hatari-event keyup $v" > "$F" ;;
      esac
    fi
  done
  for s in $(seq 1 "${SHOTS:-1}"); do
    echo "hatari-shortcut screenshot" > "$F"
    [ "${SHOTS:-1}" -gt 1 ] && sleep 0.15
  done
done
echo "hatari-shortcut quit" > "$F" 2>/dev/null; sleep 1; kill $P 2>/dev/null; wait $P 2>/dev/null
echo "$(ls "$O" | grep -c png) screenshots in $O"
