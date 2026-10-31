#!/bin/bash
# run.sh <name> <machine> <tos.img> <seconds> [extra hatari options]
# Headless Hatari run (no display), one screenshot per second into out/<name>/.
# Environment: HD = folder mounted as drive C: (default ../build/IK_PLUS),
#              PRG = program started automatically (default IK_PLUS.TOS),
#              KEYS = "t:scancode ..." ST keys pressed at second t (e.g. "30:59" = F1,
#                     "60:0x01" = Esc: a lone "1" would be the digit 1 key);
#                     "t:!name" sends the Hatari shortcut "name" instead
#                     (e.g. "40:!recsound" starts/stops recording hatari.wav),
#              CMDS = file of lines "t <Hatari command>" sent to the command fifo
#                     at second t (e.g. "22 hatari-path memsave f.sav" then
#                     "23 hatari-shortcut savemem" to save the machine state;
#                     "1 hatari-debug b pc = $1000" to set a breakpoint),
#              FF = t : fast forward (like AltGr + X) from second t on; emulated
#                     time (VBLs, cycles) does not depend on it,
#              SHOTS = screenshots per second (default 1).
# Restart from a saved state: extra option --memstate f.sav (the state holds
# the program: one state per build). Restoring a state clears the breakpoints:
# set them afterwards with CMDS, not with --parse.
# Note: ST keys sent this way bypass Hatari's joystick emulation; use runx.sh
# to drive joysticks.
N=$1; M=$2; T=$3; D=$4; shift 4
R=$(cd "$(dirname "$0")" && pwd)
HD=${HD:-$R/../build/IK_PLUS}; PRG=${PRG:-IK_PLUS.TOS}
O=$R/out/$N; rm -rf "$O"; mkdir -p "$O"; F=$O/fifo
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
hatari --configfile /dev/null --machine "$M" --tos "$T" --harddrive "$HD" --gemdos-drive C \
  --auto "C:\\$PRG" --screenshot-dir "$O" --cmd-fifo "$F" --sound off --fast-boot yes \
  --confirm-quit no --statusbar no --drive-led no "$@" > "$O/log.txt" 2>&1 &
P=$!
for i in $(seq 1 "$D"); do
  sleep 1; kill -0 $P 2>/dev/null || break; [ -p "$F" ] || continue
  [ -n "$FF" ] && [ "$i" = "$FF" ] && echo "hatari-option --fast-forward yes" > "$F"
  [ -n "$CMDS" ] && awk -v t="$i" '$1==t { $1=""; sub(/^ /,""); print }' "$CMDS" |
    while read -r c; do echo "$c" > "$F"; sleep 0.3; done
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
