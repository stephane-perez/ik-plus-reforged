IK+ REFORGED
============

International Karate + (IK+) (c) 1987-1988 System 3 / Archer Maclean.
IK+ Reforged is an unofficial patch, not affiliated with System 3 or any
other rights holder. https://github.com/stephane-perez/ik-plus-reforged

Run IK_PLUS.TOS, from a floppy disk or a hard disk. The folder contains:
  IK_PLUS.TOS   the loader
  IKPLUS.IMG    the patched game
  IKPLUS.CFG    your joystick choice (written by the loader)
  README.TXT    this file (LISEZMOI.TXT: the same in French)

Machines: STF, STE and Mega STE, TOS 1.04 to 2.06. On an STE or a Mega STE
with 1 MB or more, DMA sound and the blitter are used automatically.


WHAT IS DIFFERENT FROM THE ORIGINAL GAME
----------------------------------------

Start-up
- A new loader replaces the original program. It shows LOADING, then an
  intro page (IK+ logo, joystick choice, training mode, PRESS SPACE TO
  START), then the game's own intro.
- No floppy disk check: the game no longer needs a disk in drive A, and
  it runs from a hard disk.
- Runs on STE, Mega STE and TOS 2.06. The original crashed at start-up
  on these machines (its random number generator read the TOS 1.x ROM).
- Mega STE: the game runs at 8 MHz with the cache off, as it expects.
- The reset button resets the machine instead of restarting the game.

Joysticks (intro page)
- F1, F2 and F3 choose the controller of players 1 (white), 2 (red)
  and 3 (blue):
    JOYSTICK 0   mouse port
    JOYSTICK 1   joystick port
    JOYSTICK 2   parallel port, adapter's joystick 3 socket (fire: BUSY)
    JOYSTICK 3   parallel port, adapter's joystick 4 socket (fire: STROBE)
    JOYPAD A/B   Jaguar pad on the enhanced port A or B (STE only)
    NONE         player 3 only: no third player
  A controller is never given to two players. Defaults: player 1 on
  JOYSTICK 1, player 2 on JOYSTICK 0 (as in the original game), player 3
  on JOYSTICK 2 (JOYPAD A on an STE).
- The choice is saved in IKPLUS.CFG. On a write-protected or full disk,
  nothing is written and the game starts anyway.
- F4: training mode on or off (see below). It is never saved.
- No key click on the intro page.

3-player mode
- F3 starts a 3-player game, like F1 (1 player) and F2 (2 players): the
  three fists flash, and player 3 gets the blue fighter. If player 3 is
  set to NONE, F3 does nothing.
- With 3 players: nobody is eliminated, the referee announces neutral
  results (X IS BEST / Y IS SECOND / Z IS WORST...), and the match ends
  after 5 minutes of fighting with "MATCH OVER".
- Player 3 also plays the two bonus stages, taking turns with the other
  players. In the bomb stage, the explosions are blue during that turn.

Training mode (F4 on the intro page)
- During a game, the round time does not count down and shows
  "TIME: --", and nobody scores round points (the score still goes up):
  rounds never end, nor does a 3-player match. The demo and the bonus
  stages are unchanged. Quit the game to get the normal rules back.

Keys
- F3: 3-player game (was: music on/off).
- F5: music on/off (was unused).
- F6 to F10: the chosen speed is kept when a new game starts (the
  original went back to "normal").
- The help screen ("F3 ..... 3 PLAYER GAME", "F4/F5 .. FX/MUSIC ON/OFF"),
  the referee's tip ("PRESS F5 FOR MUSIC ON OR OFF") and the demo message
  ("OR F1 F2 F3 KEYS") show the new keys.
- Unchanged: F1, F2, F4, Space (pause), the secret words and all the
  other keys.

Display
- Top bar: the red and blue energy bars, scores and fists are moved a
  little to the left, so that the blue fist no longer touches "LV".

STE or Mega STE with 1 MB or more
- Sound effects are played by DMA, at 12.5 kHz. The music keeps its three
  voices during the shouts. After SPACE, about 2 seconds of PLEASE WAIT
  while the sounds are converted.
- The fighters are drawn and erased by the blitter, with the same result
  as the original drawing.
- Turbo speed (F6) holds a steady 25 frames per second.
