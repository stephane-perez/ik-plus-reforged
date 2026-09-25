# IK+ Reforged

*[Version française](README_FR.md)*

Patches and tools for **International Karate +** (IK+) on the Atari ST:

- **STE / Mega STE / TOS 2.06 compatibility**: the game now runs on STF, STE and Mega STE, at 8 and 16 MHz;
- a **simultaneous 3-player mode**: the third player uses a joystick on a parallel-port adapter;
- a **new loader** with no intro, which starts the game directly;
- **JOYTEST**, a small utility that shows the state of every joystick, including those on the parallel port.

> ## ⚠️ Disclaimer
>
> *International Karate +* (IK+) © 1987–1988 System 3 / Archer Maclean. This project is **not affiliated with, endorsed by or connected to** System 3 or any other rights holder.
>
> **This repository contains no part of the game**: no program, graphics, music or data, whether original or modified. It only contains original source code and tools. They modify, **on your own computer**, a copy of the game that **you** provide. You alone are responsible for making sure you have the right to use that copy, for example by owning an original. Even if you own the original, you **must** provide the game cracked by Ator of The Blade Runners, no other version will work.
>
> The names and trademarks mentioned belong to their respective owners. Everything is provided "as is", without any warranty. Use it at your own risk, including on real hardware.

## Features

### Compatibility

| Machine / TOS | Original | Reforged |
|---|---|---|
| STF / TOS 1.04 | works | works |
| STF / TOS 2.06 | intro crashes | works |
| STE / TOS 1.62 | the demo restarts endlessly, "BUM COPY" | works (tested on real hardware) |
| Mega STE / TOS 2.06 | crashes at start-up | works (tested on real hardware) |

What was fixed:

- **The game's random number generator** read the TOS 1.x ROM at `$FC0000`. That address does not exist on STE and Mega STE, so each read caused a bus error, and the game restarted in a loop. It now reads graphics data in RAM instead. This is a one-byte change.
- **The intro** placed its music player at a fixed address without reserving that memory. Under TOS 2.06 the memory was reused and the intro crashed. The intro is gone.
- **The new loader** reads the game into reserved memory and copies it into place safely. On a Mega STE it switches off the serial chip (SCC) interrupts and selects 8 MHz with the cache off. All unused exception vectors point to a safe place.

### 3-player mode

The game was designed around three fighters, and its data already had room for a third human player that was never enabled. This mode enables it.

- Start a game as usual: **F1** or **F2**, or the fire button of joystick 1 or 2.
- During the game, **F3** gives the **blue** fighter to player 3, and a fist appears next to the blue score. Press **F3** again to hand the blue fighter back to the computer.
- **While player 3 is in the game:**
  - nobody is eliminated;
  - the referee announces neutral results ("X IS BEST / Y IS SECOND / Z IS WORST"…);
  - the match lasts **5 minutes of fighting**, then the referee says "MATCH OVER" and the game returns to the menu.
- F3 no longer controls the music, which is always on. The help screen still shows "F3 MUSIC ON/OFF", because it is a picture.
- Player 3 also takes part in the two **bonus stages** (deflecting balls with the shield, kicking bombs), taking turns with the other human players. In the bomb stage, the fighter's jacket colour is also used for the explosions: during player 3's turn they are blue instead of red.
- Without player 3, the game behaves exactly like the original.

Player 3 uses a **parallel-port joystick adapter**, the kind used by *Gauntlet II*, *Leatherneck* or *Dynabusters+*. Two builds are produced, one for each socket of the adapter:

| Folder | Adapter socket | Directions | Fire |
|---|---|---|---|
| `IK3J_S3` | joystick 3 | D4–D7 | BUSY |
| `IK3J_S4` | joystick 4 | D0–D3 | STROBE |

### JOYTEST

`JOYTSTEN.TOS` (English) and `JOYTEST.TOS` (French) show, in real time:

- ports 0 and 1 of the ST: the 8 directions and the fire button;
- the parallel port: the directions read on D0–D3 and on D4–D7, the fire button on BUSY and on STROBE, and the 8 raw data lines.

This makes it easy to check any joystick adapter. Press any key to quit: the mouse is switched back on.

## Building

### Automatic build (GitHub Actions)

Every push builds the loader, the 3-player code and JOYTEST. The result can be downloaded from the **Actions** tab, as the `ik-plus-reforged` artifact. The game itself is **never** built there, because no game file is available to the workflow.

### Manual build

Requirements: `make`, a C compiler (to build the vasm assembler), `python3`, and `curl` or `git`. Tested on Linux; it should also work on macOS and on Windows through WSL.

```sh
git clone https://github.com/stephane-perez/ik-plus-reforged
cd ik-plus-reforged
make                                  # loader, 3-player code, JOYTEST
make game ATOR=/path/to/ATOR.EXE      # patches YOUR copy of the game
make check                            # checks the result
```

On the first run, `make` builds the [vasm](http://sun.hasenbraten.de/vasm/) assembler in `.tools/`, unless `vasmm68k_mot` is already installed.

**The file to provide**: `ATOR.EXE`, the memory image of the game (340,224 bytes, MD5 `d76da60c6cd7d9f6ce42630b1271d8d7`). The tools refuse any other file.

**The result**: `build/IK3J_S3/` and `build/IK3J_S4/` each contain `IK_PLUS.TOS` and the patched `ATOR.EXE`. Copy the folder that matches your adapter socket to a floppy disk or a hard disk, then run `IK_PLUS.TOS`. The original's other files are no longer needed. With the default settings, `make check` compares the result with the expected checksums:

| File | MD5 |
|---|---|
| `IK3J_S3/ATOR.EXE` | `cd6b83ab485dc33f0b6de4bbc8df2423` |
| `IK3J_S4/ATOR.EXE` | `c70c6e623faa00cce0509e4c527b757d` |
| `IK_PLUS.TOS` | `0a89bb68ba0b62e122cc9d63670fe7fa` |

**Option**: `make game LIMIT=180 ATOR=…` sets the length of a 3-player match, in seconds of fighting (300 by default). `make check` only applies to the default value.

## Testing in Hatari (optional)

The `hatari/` folder contains the scripts used during development. You provide the TOS ROM images, which are not included.

- `run.sh`: a run without a display, with one screenshot per second.
- `runx.sh`: a run on a virtual screen (Xvfb + xdotool), so that simulated key presses go through Hatari's joystick emulation, including joysticks on the parallel port. See `example_3players.keys`.

Note: Hatari 2.4.1 is more permissive than real hardware on the parallel port. It ignores the port direction set in PSG register 7. See the technical notes.

## How it works

- `src/loader.s`: the loader, which replaces the intro and the old start-up programs.
- `src/p3.s`: the 3-player code, placed at `$800` in unused memory.
- `tools/patch_game.py` and `tools/patch_p3.py`: apply the patches. Before changing any byte, they check the checksum and the original bytes.
- `src/joytest.s`: JOYTEST.
- `tools/trace_ik.py` and `tools/show.py`: a recursive disassembler and a listing viewer, for study. They need `pip install capstone`.
- `docs/fr/`: the technical notes (methodology, code map, version history).

Source comments, tool messages and technical notes are in French.

## Credits

- *International Karate +*: Archer Maclean (1962–2022), System 3.
- [vasm](http://sun.hasenbraten.de/vasm/): Volker Barthelmann and Frank Wille.
- [Hatari](https://hatari.tuxfamily.org/): the Atari ST emulator used for testing.
- [Capstone](https://www.capstone-engine.org/): the disassembly engine.

## License

The original code and documentation in this repository are released under the [MIT license](LICENSE). This license does not cover IK+ in any way.
