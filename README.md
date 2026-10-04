# IK+ Reforged

*[Version française](README_FR.md)*

Patches and tools for **International Karate +** (IK+) on the Atari ST:

- **STE / Mega STE / TOS 2.06 compatibility**: the game now runs on STF, STE and Mega STE, at 8 and 16 MHz;
- a **simultaneous 3-player mode**: the third player uses a joystick on a parallel-port adapter;
- an **STE version**: player 3 on the STE's enhanced joystick port, sound effects played by DMA, fighters drawn by the blitter; the turbo speed now holds 25 frames per second;
- a **new loader**: an intro page (IK+ logo, controls), then the game's own intro;
- **JOYTEST**, a small utility that shows the state of every joystick, including those on the parallel port and the STE's enhanced ports.

> ## ⚠️ Disclaimer
>
> *International Karate +* (IK+) © 1987–1988 System 3 / Archer Maclean. This project is **not affiliated with, endorsed by or connected to** System 3 or any other rights holder.
>
> **This repository contains no part of the game**: no program, graphics, music or data, whether original or modified. It only contains original source code and tools. They modify, **on your own computer**, a copy of the game that **you** provide. You alone are responsible for making sure you have the right to use that copy, for example by owning an original. The tools only accept one specific version of the game: `IK+.PRG`, a single program of 344,516 bytes (MD5 `4107c876be9d49deb2a3cf5b390f70be`). It is **not** the file from the original disk: its copy protection is already disabled, and Reforged skips the protection check entirely. No other version will work.
>
> The names and trademarks mentioned belong to their respective owners. Everything is provided "as is", without any warranty. Use it at your own risk, including on real hardware.

## Features

### Compatibility

| Machine / TOS | `IK+.PRG` | Reforged |
|---|---|---|
| STF / TOS 1.04 | works, with a floppy disk in drive A | works |
| STF / TOS 2.06 | crashes at start-up | works |
| STE / TOS 1.62 | crashes at start-up | works (tested on real hardware) |
| Mega STE / TOS 2.06 | crashes at start-up | works (tested on real hardware) |

The `IK+.PRG` column was checked in the Hatari emulator.

What was fixed:

- **The game's random number generator** read the TOS 1.x ROM at `$FC0000`. That address does not exist on STE and Mega STE, nor with TOS 2.06, so each read caused a bus error, and the game crashed or restarted in a loop. It now reads graphics data in RAM instead. This is a one-byte change.
- **The floppy disk check**: `IK+.PRG` still runs it at start-up, then waits for the floppy drive motor to stop, which never happens without a disk in the drive. Reforged skips it.
- **The new loader** reads the game into reserved memory and copies it into place safely. On a Mega STE it switches off the serial chip (SCC) interrupts and selects 8 MHz with the cache off. All unused exception vectors point to a safe place. Before the game starts, it shows an intro page: the IK+ logo and the game's font, both taken from your copy of the game, "REFORGED", the joystick of each player, and "SPACE TO START".

### 3-player mode

The game was designed around three fighters, and its data already had room for a third human player that was never enabled. This mode enables it.

- **F1**, **F2** and **F3** start a game for 1, 2 or 3 players (or the fire button of joystick 1 or 2, as in the original game). Like F1 and F2, F3 starts a new game: the three fists flash, and player 3 gets the **blue** fighter.
- **While player 3 is in the game:**
  - nobody is eliminated;
  - the referee announces neutral results ("X IS BEST / Y IS SECOND / Z IS WORST"…);
  - the match lasts **5 minutes of fighting**, then the referee says "MATCH OVER" and the game returns to the menu.
- The music is switched on and off with **F5** (F3 in the original game). The help screen and the referee's tips show the new keys.
- Player 3 also takes part in the two **bonus stages** (deflecting balls with the shield, kicking bombs), taking turns with the other human players. In the bomb stage, the fighter's jacket colour is also used for the explosions: during player 3's turn they are blue instead of red.
- Without player 3, the game plays like the original, with a few changes:
  - the speed chosen with F6–F10 is kept when a new game starts (the original went back to "normal");
  - the **reset** button resets the machine instead of restarting the game;
  - the red and blue scores, energy bars and fists in the top bar are moved a little to the left, so that the blue fist no longer touches "LV".

Player 3 uses a **parallel-port joystick adapter**, the kind used by *Gauntlet II*, *Leatherneck* or *Dynabusters+*. Two folders are produced:

| Folder | Machines | Player 3 | Extras |
|---|---|---|---|
| `IK3J_PAR` | STF, STE, Mega STE | parallel-port adapter, joystick 3 socket (directions D4–D7, fire on BUSY) by default | — |
| `IK3J_STE` | STE with 1 MB or more | Jaguar pad on enhanced joystick port A | DMA sound, blitter (see below) |

**Choosing the joysticks**: on the intro page, **F1**, **F2** and **F3** change the controller of players 1, 2 and 3. The choices are JOYSTICK 0 (mouse port), JOYSTICK 1, JOYSTICK 2 and JOYSTICK 3 (sockets 3 and 4 of the parallel-port adapter), JOYPAD A and JOYPAD B (Jaguar pads on the STE's enhanced ports, offered on an STE only), and NONE for player 3 (F3 then cannot start a 3-player game). A controller is never given to two players. The choice is saved in `IKPLUS.CFG`, next to the game; on a write-protected or full disk, nothing is written and the game starts anyway. The folder only changes the default for player 3: JOYSTICK 2 in `IK3J_PAR`, JOYPAD A in `IK3J_STE`.

### STE version

The `IK3J_STE` folder is for the **STE only, with 1 MB of memory or more**. On any other machine, the loader shows a message and stops. It has the same 3-player mode, with three differences:

- **Player 3 uses the STE's enhanced joystick port A** (the 15-pin socket): a Jaguar pad (tested on a real STE), or an ordinary joystick with a DB15 adapter (not tested). Fire = A, B, C or Pause. No parallel-port adapter is needed.
- **Sound effects are played by DMA**, at 12,517 Hz. The original played each effect through the YM chip, with one interrupt per sample, which used 13 to 18% of the processor. The 18 sounds are converted when the game starts, which takes about 2 seconds of green screen. The music now keeps its three voices during the shouts, and the effects no longer vary in pitch.
- **The fighters are drawn and erased by the blitter.** The result is identical, byte for byte, to the original drawing: this was checked in the emulator over more than a thousand calls.

Measured in Hatari during a fight:

| Build | Frames per second, with no speed limit | Turbo (F6) |
|---|---|---|
| Original | 20.0 on average | 22.5 on average: 1 frame in 6 drops to 16.7 or 12.5 |
| STE version | 25.5 on average | **25 all the time** |

In IK+, one frame is one step of the game: F6 to F10 set a minimum number of screen refreshes per frame, so F6 (turbo) is limited to 25 frames per second, and F8 (normal) to 10. Running at 50 frames per second would make the game twice as fast as the turbo, not smoother, so it is not offered.

### JOYTEST

`JOYTSTEN.TOS` (English) and `JOYTEST.TOS` (French) show, in real time:

- ports 0 and 1 of the ST: the 8 directions and the fire button;
- the parallel port: the directions read on D0–D3 and on D4–D7, the fire button on BUSY and on STROBE, and the 8 raw data lines;
- on an STE or a Falcon, the enhanced ports A and B: the directions and the A, B, C, Pause (P) and Option (O) buttons.

This makes it easy to check any joystick adapter. Press any key to quit: the mouse is switched back on.

## Building

### Automatic build (GitHub Actions)

Every push builds the loaders, the 3-player code, the STE module and JOYTEST. The result can be downloaded from the **Actions** tab, as the `ik-plus-reforged` artifact. The game itself is **never** built there, because no game file is available to the workflow.

### Manual build

Requirements: `make`, a C compiler (to build the vasm assembler), `python3`, and `curl` or `git`. Tested on Linux; it should also work on macOS and on Windows through WSL.

```sh
git clone https://github.com/stephane-perez/ik-plus-reforged
cd ik-plus-reforged
make                                  # loaders, 3-player code, STE module, JOYTEST
make game PRG=/path/to/IK+.PRG        # patches YOUR copy of the game
make check                            # checks the result
```

On the first run, `make` builds the [vasm](http://sun.hasenbraten.de/vasm/) assembler in `.tools/`, unless `vasmm68k_mot` is already installed.

**The file to provide**: `IK+.PRG`, the game as a single program (344,516 bytes, MD5 `4107c876be9d49deb2a3cf5b390f70be`). The tools refuse any other file.

**The result**: `build/IK3J_PAR/` and `build/IK3J_STE/` each contain `IK_PLUS.TOS` (the loader) and `IKPLUS.IMG` (the patched game). Copy the folder you need to a floppy disk or a hard disk, then run `IK_PLUS.TOS`: `IK3J_PAR` with a parallel-port adapter (any ST), or `IK3J_STE` with a Jaguar pad on an STE. With the default settings, `make check` compares the result with the expected checksums:

| File | MD5 |
|---|---|
| `IK3J_PAR/IKPLUS.IMG` | `47c4470c565aed31afed2fdafc2fa5ae` |
| `IK3J_PAR/IK_PLUS.TOS` | `2ee9920d4f637526efc272e407d280d2` |
| `IK3J_STE/IKPLUS.IMG` | `1f8287f1eabad2373a98013a6f8e76af` |
| `IK3J_STE/IK_PLUS.TOS` | `53ba614726a0e7c85fa0b59313a27917` |

**Option**: `make game LIMIT=180 PRG=…` sets the length of a 3-player match, in seconds of fighting (300 by default). `make check` only applies to the default value.

## Testing in Hatari (optional)

The `hatari/` folder contains the scripts used during development. You provide the TOS ROM images, which are not included.

- `run.sh`: a run without a display, with one screenshot per second.
- `runx.sh`: a run on a virtual screen (Xvfb + xdotool), so that simulated key presses go through Hatari's joystick emulation, including joysticks on the parallel port. See `example_3players.keys`.

Note: Hatari 2.4.1 is more permissive than real hardware on the parallel port. It ignores the port direction set in PSG register 7. See the technical notes.

## How it works

- `src/loader.s`: the loader, which reads `IKPLUS.IMG` and starts the game. Assembled with `-DSTE`, it also loads the STE module.
- `src/p3.s`: the 3-player code, placed at `$800` in unused memory.
- `src/ste.s`: the STE module (DMA sound, blitter), placed at `$C0000`, above the 512 KB the game was written for.
- `tools/ikimg.py`: extracts the game's memory image from `IK+.PRG`.
- `tools/patch_game.py`, `tools/patch_p3.py` and `tools/patch_ste.py`: apply the patches. Before changing any byte, they check the checksum and the original bytes.
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
