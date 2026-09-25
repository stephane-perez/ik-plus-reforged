# IK+ (Atari ST) — analyse et correctifs STE / Mega STE

*Notes de travail, en français. Voir aussi [CODE_MAP.md](CODE_MAP.md) (carte du code) et [VERSIONS.md](VERSIONS.md) (versions 2 à 4, essais sur machine réelle).*

Règle suivie : **aucune affirmation sans les octets qui la portent**. Version étudiée : la version « The Blade Runners » (ATOR, novembre 1988), identifiée par l'empreinte de `ATOR.EXE` (MD5 `d76da60c6cd7d9f6ce42630b1271d8d7`).

## 1. Les fichiers

| Fichier | Taille | Nature |
|---|---|---|
| `IK_PLUS.TOS` | 563 | PRG chargeur (texte `$20C`, 7 relocations) |
| `BLADERUN.DT0` | 29 637 | Intro, **GFA Basic compilé** (Line-A, runtime appelé par `a6`) |
| `BLADERUN.DT1` | 2 146 | PRG chargeur du jeu, premier mot brouillé (`EOR #$FFFF`) |
| `ATOR.EXE` | 340 224 (`$53100`) | **Image mémoire brute** du jeu, sans en-tête ni relocation, à placer en `$700` |

Chaîne de lancement d'origine :
1. `IK_PLUS.TOS` : Mshrink ; Supexec (palette noire) ; `Pexec(0, "bladerun.dt0")` ; Supexec (`$D4`) : palette blanche et vérification de la chaîne `BLADERUNNER` en `$600`, sinon boucle infinie ; `Pexec(3, "bladerun.dt1")` ; `EORI.W #$FFFF` sur le premier mot du texte ; `Pexec(4)`.
2. `DT1` : Super ; efface l'écran ; affiche un texte ; lit `ator.exe` (`$53100` octets) ; attend 100 VBL ; copie un stub en `$7F000` ; `SR=$2700` ; vecteurs `$18`–`$1A4` → `rte` ; recopie l'image en `$700` ; charge les registres d'un chargeur de boot depuis une table (`a5=$FF8604`, `a6=$FF8606`, `a7=$F28`…) ; `jmp $1000`.
3. Le jeu écrase le TOS et prend toute la machine.

Le dépôt remplace les étapes 1 et 2 par un chargeur unique (`src/loader.s`), qui ne lit que `ATOR.EXE`.

## 2. Environnement de test

- Hatari 2.4.1, sans écran (`SDL_VIDEODRIVER=dummy`), disque GEMDOS sur un dossier, `--auto C:\IK_PLUS.TOS`, captures toutes les secondes, touches via `--cmd-fifo` (`hatari/run.sh`). Pour les joysticks : Xvfb + xdotool (`hatari/runx.sh`).
- ROM TOS 1.04, 1.62 et 2.06 (non fournies). Hatari refuse 1.62 en mode ST ; TOS 2.06 est accepté en ST. Une image « TOS chargé en RAM » (relogeur de 256 octets) n'est pas utilisable par Hatari.
- Débogueur : `--parse` avec `b pc = TEXT && pc < $400000 :file …`, `history cpu N`, points d'arrêt sur changement mémoire `b ($44c34).l ! ($44c34).l`, `--trace psg_write`. Les exceptions du TOS 2.06 au démarrage (sondage du matériel) sont normales.

## 3. Constats

| Machine / TOS | Original | Après correctifs |
|---|---|---|
| STF / 1.04 | Intro puis jeu : OK | OK |
| STF / 2.06 | Intro : 2 bombes | OK |
| STE / 1.62 | Intro OK, puis jeu en boucle : démo cassée et « BUM COPY » | OK (confirmé sur machine réelle) |
| Mega STE / 2.06 | Intro : 3 bombes ; puis blocage sur l'écran de `DT1` | OK (confirmé sur machine réelle, voir VERSIONS.md) |

### 3.1 L'intro plante sous TOS 2.06

- Sous TOS 2.06, `DT0` est chargé en `$154AC`, contre `$FC6C` sous 1.04 : `$5840` octets d'écart.
- L'intro recopie un lecteur de musique à une **adresse fixe** (routine VBL en `$44C34`) et l'inscrit dans `vblqueue`, **sans réserver la mémoire**.
- Sous 2.06, un `DIM` du runtime GFA (`$16B0` longs, remis à zéro en `TEXT+$15C8`) **efface le lecteur** ; la VBL suivante saute dans des zéros.
- Décision : **supprimer l'intro**.

### 3.2 Le jeu relance sa partie en boucle sur STE

- `$36B2` est le **générateur aléatoire** : compteurs, `MULU`, puis deux mots lus en `(a0,d0.w)` et `(a0,d3.w)` avec `a0 = $FC0000` (la **ROM du TOS 1.x**), `EOR`, et soustraction du compteur vidéo `$FF8209`.
- Sur STE et Mega STE, le TOS est en `$E00000` et `$FC0000` provoque une erreur de bus.
- Le jeu fait pointer les vecteurs `$8`–`$3C` sur `$14FA` : **reprise sur erreur** (remise à zéro de l'état, `jmp $1600`). D'où la démo qui redémarre sans cesse.
- « BUM COPY <<<<< » n'est pas une protection : c'est un des messages cachés du jeu.
- `$36D2` est le seul accès du code à `$FC0000`–`$FEFFFF`.

## 4. Correctifs

- `tools/patch_game.py` : `lea $FC0000.l,a0` devient `lea $030000.l,a0` en `$36D2`, soit **un octet** (`$36D5` : `$FC` → `$03`). La fenêtre lue, `$28000`–`$37FFE`, tombe dans les graphismes du jeu (5,7 bits d'entropie par octet).
- `src/loader.s` : chargeur sans intro (voir VERSIONS.md §6).
- `src/p3.s` + `tools/patch_p3.py` : mode 3 joueurs (voir CODE_MAP.md et VERSIONS.md).
- Tous les outils vérifient le MD5 et les octets d'origine avant d'écrire.
