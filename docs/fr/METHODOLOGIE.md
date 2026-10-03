# IK+ (Atari ST) — analyse et correctifs STE / Mega STE

*Notes de travail, en français. Voir aussi [CODE_MAP.md](CODE_MAP.md) (carte du code) et [VERSIONS.md](VERSIONS.md) (historique des versions, essais sur machine réelle).*

Règle suivie : **aucune affirmation sans les octets qui la portent**. Version étudiée : depuis la v7, `IK+.PRG`, un programme d'un seul fichier (344 516 octets, MD5 `4107c876be9d49deb2a3cf5b390f70be`) ; jusqu'à la v6, une autre version modifiée du jeu, en trois fichiers (§1). Les deux contiennent le même code de jeu, aux mêmes adresses.

## 1. Les fichiers

### Depuis la v7 : `IK+.PRG`

Programme TOS classique : texte `$541A0` octets, ni données ni BSS, 4 relocations, aucune compression. Ce n'est pas le fichier de la disquette d'origine (sa protection est déjà neutralisée, voir plus bas), et sa provenance est inconnue.

Chaîne de lancement :
1. Super ; Setscreen en basse résolution ; pile en `$F28` ; recopie d'une petite routine en `$380`, qui fait pointer les vecteurs `$18`–`$1A4` sur un `rte`.
2. Recopie du texte à partir de l'octet `$B0` en `$1000`–`$537FF` (le jeu), puis des 6 384 derniers octets en `$78000` : l'**image d'une piste de disquette protégée**.
3. Palette noire, puis `jmp $1000`.

`tools/ikimg.py` en tire l'image du jeu de `$700` à `$537FF` (`$700`–`$FFF` à zéro), que lit notre chargeur.

**Vérification de la disquette** (`F_06A40`, appelée en `$2202`) : elle programme le contrôleur de disquette (`$8604`/`$8606`), cherche en `$78000` un en-tête de secteur `A1 A1 FE` dont la taille vaut `$F7` (sinon `$27A4` efface la mémoire), puis attend l'arrêt du moteur du lecteur. Dans `IK+.PRG`, les deux lectures (`$6A98`) sont déjà remplacées par des `nop`, et la piste attendue est celle que le chargeur recopie en `$78000`. Sans disquette dans le lecteur, le moteur ne s'arrête jamais et le jeu reste bloqué. `tools/patch_game.py` saute donc cette vérification (`$6A44` → `bra.w $6AF8`).

**Différences avec l'image de la v6** : 62 octets sur 337 920 (`$1000`–`$537FF`) : l'appel de la vérification (`$2207`), sa fin (`$6A98`, `$6B0E`), le crédit « IK+ (C) 1988 ARCHER MACLEAN » (`$29B8`, `$8D94`, au lieu du pseudonyme d'un cracker) et deux zones de 15 octets de graphismes (`$2CDC4`, `$34FC4`). Aucun correctif ne touche ces zones.

### Jusqu'à la v6 : version en trois fichiers

| Fichier | Taille | Nature |
|---|---|---|
| `IK_PLUS.TOS` | 563 | PRG chargeur (texte `$20C`, 7 relocations) |
| intro | 29 637 | **GFA Basic compilé** (Line-A, runtime appelé par `a6`) |
| second chargeur | 2 146 | PRG chargeur du jeu, premier mot brouillé (`EOR #$FFFF`) |
| image mémoire | 340 224 (`$53100`) | **Image mémoire brute** du jeu, sans en-tête ni relocation, à placer en `$700` |

Chaîne de lancement :
1. `IK_PLUS.TOS` : Mshrink ; Supexec (palette noire) ; `Pexec(0)` de l'intro ; Supexec (`$D4`) : palette blanche et vérification d'une chaîne en `$600`, sinon boucle infinie ; `Pexec(3)` du second chargeur ; `EORI.W #$FFFF` sur le premier mot du texte ; `Pexec(4)`.
2. Second chargeur : Super ; efface l'écran ; affiche un texte ; lit l'image (`$53100` octets) ; attend 100 VBL ; copie un stub en `$7F000` ; `SR=$2700` ; vecteurs `$18`–`$1A4` → `rte` ; recopie l'image en `$700` ; charge les registres d'un chargeur de boot depuis une table (`a5=$FF8604`, `a6=$FF8606`, `a7=$F28`…) ; `jmp $1000`.
3. Le jeu écrase le TOS et prend toute la machine.

Le dépôt a remplacé les étapes 1 et 2 par un chargeur unique (`src/loader.s`), qui ne lit que l'image du jeu.

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
| Mega STE / 2.06 | Intro : 3 bombes ; puis blocage sur l'écran du second chargeur | OK (confirmé sur machine réelle, voir VERSIONS.md) |

### 3.1 L'intro plante sous TOS 2.06

- Sous TOS 2.06, l'intro est chargée en `$154AC`, contre `$FC6C` sous 1.04 : `$5840` octets d'écart.
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

- `tools/patch_game.py` : image du jeu tirée de `IK+.PRG` et vérification de la disquette sautée (§1) ; `lea $FC0000.l,a0` devient `lea $030000.l,a0` en `$36D2`, soit **un octet** (`$36D5` : `$FC` → `$03`). La fenêtre lue, `$28000`–`$37FFE`, tombe dans les graphismes du jeu (5,7 bits d'entropie par octet).
- `src/loader.s` : chargeur sans intro (voir VERSIONS.md §6).
- `src/p3.s` + `tools/patch_p3.py` : mode 3 joueurs (voir CODE_MAP.md et VERSIONS.md).
- Tous les outils vérifient le MD5 et les octets d'origine avant d'écrire.
