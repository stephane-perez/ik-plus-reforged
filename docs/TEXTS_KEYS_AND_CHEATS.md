# IK+ (Atari ST): texts, keys and secret words

## Source and method

Everything comes from the game's code: the texts, the keys and the **21 secret words** (plus 5 separate codes) were read in `ATOR.EXE`, The Blade Runners version (MD5 `d76da60c6cd7d9f6ce42630b1271d8d7`). Addresses (`$xxxx`) refer to the image loaded at `$700`.

- **Texts**: the game has its own font. `@` = space, `<` = full stop, `:` = comma, `=` = +, `]` = apostrophe, `;` = exclamation mark. The texts below are converted.
- **Keys**: the keyboard handler (`$2492`) keeps the last 5 keys at `$13AC`. The game's keys are tested in `F_0708C` (`$708C`–`$73CC`).
- **Secret words**: `F_073CE` packs the last 4 keys into a 32-bit word (`$139E`), compared with a table at `$73EA` and with 5 constants.
- **Non-QWERTY keyboards**: the game compares **QWERTY key codes**. On a French (AZERTY) ST, type Q for A, A for Q, W for Z and Z for W (so PAC is typed P Q C). Words without these letters (FISH, BIRD, PERI…) are typed as they are.
- **Checked**: code reading for the whole document; runs in Hatari for the triggering of the PAC, FISH, BIRD and PERI animations, whose look was confirmed on a real machine. **Not identified**: the effect of the J key.

## Keys

The game is played with joysticks; the keyboard is used for settings and gags. Words are typed as described in the next section.

| Key | When | Effect | Code |
| --- | --- | --- | --- |
| F1 or fire on joystick 1 | menu, demo | 1-player game (against the computer) | `$737A` |
| F2 or fire on joystick 0 | menu, demo | 2-player game | `$7364` |
| F3 | always | music on / off | `$7316` |
| F4 | always | sound effects on / off (`$100F`) | `$733C` |
| F6 to F10 | always | game speed: F6 turbo, F7 fast, **F8 normal**, F9 and F10 slower (table `$6EB8`) | `$7122` |
| Space bar | fight | pause; space or fire to resume | `$6482` |
| P | during the pause | starts an animation during the pause (`$1370`, call to `F_01E76`) | `$724C` |
| T | fight, before round 5, fighters idle | the trousers drop | `$A0A8` |
| S | always | shadow colour: dark or light grey (`$0111` / `$0222`) | `$71CA` |
| Keypad `*` | always | changes the colours of the reflection on the water (4 sets, table `$1A74`) | `$714C` |
| Keypad `+` (or key code `$0D`) | always | music volume (YM chip), one step up (12 steps, set to the maximum when the music starts) | `$71EA` |
| Keypad `−` (or key code `$29`) | always | music volume, one step down | `$720C` |
| B | ball bonus stage | replaces the ball graphics (`$19528` → `$1A8B8`) | `$722C` |
| J | always | changes one image of a fighter (`$107B` + 12); on-screen effect not identified | `$726E` |
| HELP | fight, demo | shows the players' belt colour (or "ALL PLAYERS IN DEMO MODE") | `$72B4` |
| Up and down arrows | hall of fame | choose the letters of the name | `$AC98` |

The game ignores keys for 12 frames after each one (counter `$100C`). Secret words only work during a fight or the demo, not in the bonus stages.

## Secret words

The game recognises **26 words**: 4 background animations, 1 freeze frame and 21 hidden messages (the scrolling text speaks of "twenty codes"). Type them during a fight or the demo; the AZERTY column is what to type on a French ST.

### Animations and freeze frame

The animation does not start at once: it is booked, then started as soon as the background has finished its current animation (scheduler `$1062A`, state `$FBDA`). In Hatari, it started 8 to 23 seconds after typing.

| Word | AZERTY | Effect | Code |
| --- | --- | --- | --- |
| PAC | PQC | background animation no. 6 (Pac-Man) | `$716C`, flag `$FC9C` |
| FISH | FISH | background animation no. 4, fixed variant (fish) | `$7182`, flag `$FC9E` |
| BIRD | BIRD | animation no. 4, random variant (bird) | `$719A`, flag `$FCA0` |
| PERI | PERI | background animation no. 7 (periscope) | `$71B2`, flag `$FCA2` |
| FREZ | FREW | freezes the game ("to take photos"); any key to resume | `$70CA`, `$1372` |

### Hidden messages

Each word shows a message for 250 frames and sets the speed back to normal (F8). Most of them are nods to Archer Maclean's team. Word table at `$73EA`, message table at `$285E`.

| Word | AZERTY | Message shown |
| --- | --- | --- |
| ARCH | QRCH | IK+ C. 1988 ATOR |
| EDHK | EDHK | WHY HAVE DAN AND MIKE BEEN LAZY RECENTLY |
| FOOK | FOOK | NEVER MIND FOO, GOLFS ARNT SO BAD... |
| ANGL | QNGL | WHY DIDNT I BUY PDS EARLIER... |
| SHAH | SHQH | GO ON SHAHID, BUY ANOTHER COPY... |
| ANBK | QNBK | FANCY ANOTHER TRIP TOO BLACKPOOL... |
| STEW | STEZ | STRANGE PLACE TO KEEP THE PHONE, STEWART |
| TOTO | TOTO | CHEERS TO ALL AT INTOTO |
| GPZP | GPWP | GARY, ME OLD MATE, WHEN YAH COMING UP |
| GLZP | GLWP | GARY, YOU WONT TELL ANYONE, WILL YOU.. |
| SIMR | SI,R | SIMON, TYPE 'FREZ' TO TAKE PHOTOS |
| SUNL | SUNL | SPECIAL HELLO TO SUE AND NEIL FROM ARCH |
| JACQ | JQCA | WELL JACQUI, THATS ANOTHER ONE IN THE CAN... |
| SLAN | SLQN | THIS IS AN EXAMPLE OF THE SHADOW SLANT |
| DATE | DQTE | A.S PRODUCTION COPY 5TH OCT 1988 |
| JUMP | JU,P | IK+ JUMPERS ARE AVAILABLE TO ORDER |
| TIT | TIT | DICKHEAD |
| DICK | DICK | TITHEAD |
| WANK | ZQNK | SWEATY HANDS SLIP OFF JOYSTICKS |
| FUCK | FUCK | TUT TUT / ANY MORE OF THAT AND THE / GAME WILL BE TOTALLY RESET |
| CUNT | CUNT | (same message as FUCK) |

FUCK and CUNT each count one penalty point (`$1026`, table `$7446`): at the second one, the game restarts (`$2160`). TIT has only 3 letters: it only works right after a game is started (F1 or F2), when the game has just cleared the last keys. On AZERTY, M is where the QWERTY `,` is, hence SI,R and JU,P.

## Referee messages

The referee speaks in a speech bubble, on 1 to 3 lines (separated here by `/`). X, Y and Z are replaced by WHITE, RED or BLUE according to the round's ranking; N by a number. Texts at `$8BC4`–`$9195`.

**End of round**

- X WINS / Y STAYS IN / Z IS OUT
- X WINS / Y STAYS IN / COME ON Z
- X IS FIRST / Y STAYS IN / Z IS OUT
- X WINS / Y AND Z / COULD DO BETTER
- X WINS / Y IS SECOND / Z IS OUT
- X WINS / Y STAYS IN / Z MUST IMPROVE
- X WINS / Y AND Z ARE / EQUAL SECOND PLACE
- X AND Y / ARE BEST. / Z IS OUT
- X AND Y / ARE EQUAL FIRST. / Z MUST IMPROVE
- YOU ARE ALL OF / EQUAL ABILITY, / SO PLAY ON
- X IS BEST / Y IS SECOND / Z IS WORST
- X IS AWARDED / N00 POINTS / AS A TIME BONUS
- MATCH OVER

**End of game and hall of fame**

- Z HAS ACHIEVED / HALL OF FAME / ENTRY STATUS
- Z DID WELL BUT / HAS NOT QUALIFIED / FOR HALL OF FAME
- PRACTICE IS / DEFINITELY / RECOMMENDED
- IT SEEMS THAT WE / HAVE A LIFELESS / CROWD IN TODAY...
- WHITE HAS BEEN / TERMINATED FOR / BEING LAZY...
- RED HAS BEEN / TERMINATED FOR / BEING LAZY...

**Bonus stages**

- DEFLECT BALLS FOR / 100 POINTS EACH / OR AVOID THEM.
- KICK BOMBS OFF FOR / 100 POINTS EACH / BEFORE THEY BLOWUP
- SURVIVAL BONUS OF / N00 POINTS

**Menu, demo and tips** (shown in turn when nobody is playing)

- USE FIRE BUTTONS / OR F1 AND F2 KEYS / TO START A GAME
- PLAYERS ARE / NEEDED....
- WHERES EVERYBODY / GONE.....
- WELL, DONT JUST SIT / THERE HAVE A GO!
- IK+ / COPYRIGHT 1987/8 / ATOR
- PRESS F3 FOR / MUSIC ON OR OFF / F4 FOR SOUND FX
- F6 TO F10 CHANGE / THE GAMES SPEED. / F8 IS NORMAL
- PRESS SPACE BAR / WHILST FIGHTING / TO PAUSE GAME
- HAVE YOU TRIED THE / S KEY TO ALTER / SHADOW COLOR.
- HAVE YOU TRIED THE / ASTERISK KEY FOR / DIFFERENT RIPPLES
- FOR A LAUGH, PRESS / THE T KEY WHEN THE / MEN ARE INACTIVE!
- HAVE YOU TRIED THE / B KEY DURING / BALL BONUS SCREEN.
- HAVE YOU TRIED THE / P KEY DURING / PAUSE MODE.
- DO YOU FEEL LIKE / A LOST NINJA.... / TRY IK+ FOR ACTION

ATOR is the nickname of the cracker of this version (The Blade Runners): this credit, like "IK+ C. 1988 ATOR" (word ARCH), therefore comes from the crack and not from the original game.

## Other on-screen texts

**Scrolling text** (`$20B2`), with the words run together in the game:

> WHY NOT TRY PRESSING THE ASTERISK KEY OR THE T KEY FOR TROUSERS TO DROP OR THE S KEY FOR SHADOWS... MOST OF THE TWENTY CODES ARE FOUR LETTERS LONG. FOR EXAMPLE TRY TYPING FISH.

**HELP key** (messages 0 to 3 of `$285E`, depending on the human players):

- ALL PLAYERS IN DEMO MODE. NO BELT COLOURS
- WHITE'S BELT IS CURRENTLY … (white's belt)
- RED'S BELT IS CURRENTLY … (red's belt)
- WHITE MAN … RED MAN … (both)

**Belts** (`$D28B`), from weakest to strongest: WHITE 1 to 3, YELLOW 1 to 3, GREEN 1 to 3, PURPLE 1 to 3, BROWN 1 to 3, BLACK 1 to 8, then **MEGAHERO**.

**Score table** (`$D3AC`): header POS · NAME · BELT · SCORE, under the "TOP 50 SCORES" sign (an image, not a text).

**Top bar and pause** (`$74C6`): PAUSE, DEMO TIME=, and SPEED = NORMAL (shown at the top right during the fight).

**BUM COPY.....** (hidden message no. 25): this is not a code to type. Every 32 frames, the game checks the position of its stack (`F_06C98`); if it is not the expected one, it shows this message. It is a protection against modifications, and it is what appeared on the STE before the random number generator fix.

The help screen ("F3 MUSIC ON/OFF"…) and the IK+ logo are images, not included in this list.

## What IK+ Reforged changes

Reforged changes only one key and one text; everything else in this document also applies to the patched versions.

| | Original game | Reforged v5 and v6 (STE) |
| --- | --- | --- |
| F3 | music on / off | gives the blue fighter to player 3 or takes it back; the music always stays on |
| Referee message `$0B` | PRESS F3 FOR MUSIC ON OR OFF | PRESS F3 FOR PLAYER 3 ON OFF (same length, `patch_p3.py` hook 12) |
| Help screen | F3 MUSIC ON/OFF | unchanged (it is an image) |
| End of a 3-player match | — | neutral messages (X IS BEST…) then MATCH OVER after 5 minutes of fighting |
| Intro and crack screen | present | removed by the new loader |

The secret words, F4, F6–F10, `+`/`−` (music volume), the gag keys and BUM COPY are unchanged, including in the STE version.
