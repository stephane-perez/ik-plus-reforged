# IK+ — historique des versions 2 à 4 (essais sur machine réelle)

*Notes de travail, en français. Les numéros de section suivent ceux de [METHODOLOGIE.md](METHODOLOGIE.md).*

## 6. Retours sur machine réelle (septembre 2026) et version 2

| Machine | Retour |
|---|---|
| STE / TOS 1.62 | Le jeu tourne, plus de « BUM COPY » (correctif `$36D2` confirmé). |
| Mega STE / TOS 2.06 | Bloqué sur l'écran du crack (`DT1`). Démarrage sans pilote ni accessoires : **2 bombes**. 8 MHz sans cache : **écran figé**. Ça fonctionne avec un TOS 1.04 chargé en RAM. Non reproduit dans Hatari (1, 2 ou 4 Mo, 8 ou 16 MHz). |

**Hypothèse retenue (non prouvée) : la puce série SCC du Mega STE.** Elle est absente des STF/STE, et le TOS 2.06 active ses interruptions (niveau 5, vecteurs `$180`–`$1BC`). `DT1` ne redirige les vecteurs que jusqu'à `$1A4`, vers un `rte` en `$7F000`, qui se trouve au milieu du 2ᵉ écran du jeu (`$78000`–`$7FD00`). Dès que le jeu abaisse l'IPL (`$236C`, `SR=$2300`), une interruption SCC saute soit dans le TOS déjà écrasé (bombes), soit dans un `rte` sans acquitter la puce, qui se redéclenche sans fin (blocage).

### Nouveau chargeur (`src/loader.s`, 803 octets)

Il remplace `IK_PLUS.TOS`, `DT0` et `DT1` : il n'y a plus d'intro ni d'écran pirate, et seul `ATOR.EXE` est lu.
- Lecture dans un bloc `Malloc` (aligné sur 4). La routine de recopie est posée juste après les données : bloc > `$700`, donc fin > `$53800`, hors de la source comme de la destination.
- Attente de 100 VBL avant de prendre la machine (moteur du lecteur), comme `DT1`.
- Cookie `_MCH` : STE/Mega STE → son DMA arrêté, `$FF820F`/`$FF8265`/`$FF820D` = 0. Mega STE → SCC WR9 = 0 (canal A, `$FF8C81`), puis `$FF8E21` = 0 (8 MHz, sans cache).
- Vecteurs `$10`–`$3FC` → `rte` en `$6F0` (sous l'image du jeu) ; `$8`/`$C` → arrêt sur fond rouge en `$6E0`.
- Registres de départ identiques à `DT1` (table en `$EA` de `DT1`), puis `jmp $1000`.
- **Diagnostic par la couleur du fond** : bleu = chargement, vert = saut dans le jeu, rouge fixe = erreur de bus ou d'adresse avant l'initialisation du jeu.
- Validé dans Hatari : STF/1.04, STE/1.62, Mega STE/2.06 avec 4 Mo à 16 MHz. Le jeu démarre directement sur le logo IK+.

### Mode 3 joueurs, version 2

- **F3** (accroche 11, `$731E`–`$733B`) : pendant une partie (état 1, au moins un humain), bascule le bleu entre humain et ordinateur, et remet le compteur de durée à zéro. Ailleurs, sans effet. La musique reste toujours active. L'arrivée par le tir du joystick 3 est supprimée (un adaptateur au tir bloqué ne gêne plus).
- Message `$0B` de l'arbitre : « MUSIC ON OR OFF » → « PLAYER 3 ON OFF » (accroche 12, même longueur). L'écran d'aide « F3 MUSIC ON/OFF » est une image, inchangée.
- **Variante `-DPORT4`** : prise « joystick 4 » de l'adaptateur, directions sur D0–D3 et tir sur STROBE (PSG port A, bit 5). Le jeu force STROBE à 0 (`$2312`, registre 14 = `$06`), donc on le remet à 1 à chaque lecture. **Hatari 2.4.1 fige la valeur lue au moment de la sélection du registre** (`PSGRegisterReadData`), d'où une sélection et une lecture en double. Tir validé (`$126E = $1F`).
- Validé dans Hatari : prise 3 sur STE/1.62, prise 4 sur Mega STE/2.06 (4 Mo, 16 MHz). F3 fonctionne dans les deux sens, directions et tir sont lus.

## 7. Version 3 (25 septembre 2026)

- **Mega STE / TOS 2.06 : le nouveau chargeur fonctionne sur la machine réelle** (les deux dossiers). L'hypothèse de la SCC est donc très probable : les interruptions coupées et les vecteurs mis en lieu sûr suffisent.
- **Prise 4 sans réaction sur la machine réelle** (directions comprises), alors qu'elle marche dans Hatari. Avec l'échec des directions sur la prise 1 en v1, le plus probable est que **le câblage réel inverse les demi-octets par rapport à Hatari** (prise 1 sur D0–D3, prise 2 sur D4–D7). Ce n'est pas encore confirmé.
- **Correctif** (`merge` dans `p3.s`) : les directions du joueur 3 sont lues sur D0–D3 **et** D4–D7, fusionnées (actives à 0). Un demi-octet à 0 (les quatre directions à la fois, impossible avec un joystick) est traité comme une prise vide : dans Hatari, la prise inutilisée lit 0. Seule la ligne de tir diffère encore entre les variantes (BUSY ou STROBE). Validé dans Hatari pour les deux prises.
- **JOYTEST.TOS** (`src/joytest.s`, 1 679 octets) : affiche en direct les ports 0 et 1 (IKBD en mode événements `$14`, `joyvec`), D0–D3, D4–D7, BUSY, STROBE et les 8 lignes brutes. À la sortie, il restaure `joyvec`, la souris (`$08`) et les registres 7 et 14 du PSG. **Piège** : le TOS passe à `joyvec` un tampon de **3 octets** (en-tête `$FE`/`$FF`, joystick 0, joystick 1). La valeur d'un paquet `$FF` est donc en `2(a0)`, pas en `1(a0)`. Validé dans Hatari : STF/1.04 et Mega STE/2.06, quatre joysticks simultanés, diagonales, tirs, retour au bureau.

## 8. Version 4 : la vraie cause du joystick 3 muet

- **Retour de la machine réelle** : l'adaptateur fonctionne sous JOYTEST, avec **exactement le câblage émulé par Hatari** (joystick 3 = D4–D7 + BUSY, joystick 4 = D0–D3 + STROBE). L'hypothèse des demi-octets inversés (§7) était donc **fausse**.
- **Cause** : la routine son du jeu écrit le registre 7 du PSG à chaque image, avec `$DC` en `$B2B6` (environ 2 800 fois en 60 s) et `$F8` en `$B2D0` (son coupé). Le **bit 7 à 1 met le port B (données du port parallèle) en sortie**. Sur la machine, la lecture du registre 15 renvoie alors le verrou de sortie, et non les joysticks. **Hatari 2.4.1 ignore ce bit** et renvoie toujours les joysticks : c'est pour ça que tout passait dans l'émulateur. Mis en évidence avec `--trace psg_write`.
- **Correctifs** :
  - `pre` remet le bit 7 du registre 7 à 0 juste avant chaque lecture, IRQ masquées, comme JOYTEST ;
  - accroches 13 et 14 : `$DC` → `$5C` et `$F8` → `$78`, même mixage mais port B en entrée, pour que la machine ne pilote plus les lignes que les joysticks mettent à la masse ;
  - retour à la lecture par prise (`merge` supprimé) : prise 3 = D4–D7 + BUSY, prise 4 (`-DPORT4`) = D0–D3 + STROBE.
  - Après correction, la trace ne montre plus que `$5C`, `$78`, `$7E` et `$7F` (le `$C0` au démarrage vient du TOS).
- **Leçon** : pour tout accès matériel, valider aussi la **configuration** des registres (sens des ports, masques), pas seulement les valeurs lues. L'émulateur peut être plus permissif que la machine.
- **JOYTEST** : version anglaise par `-DENGLISH` (`JOYTSTEN.TOS`), avec un `README.TXT` en anglais pour la diffusion.

## 9. Version 5 : le joueur 3 dans les épreuves bonus

- **Retour STE / TOS 1.62** : sur la prise 3, faux tirs intermittents sur BUSY, déjà vus sous Dynabusters ; aucun problème sur la prise 4. Même adaptateur, même joystick : **ça marche sur le Mega STE**. Diagnostic : **l'entrée BUSY de ce STE** (ligne mal tenue à l'état haut ou contact du port parallèle) ; ce n'est pas un défaut d'IK+. Remède matériel proposé : une résistance de rappel d'environ 4,7 kΩ entre BUSY (broche 11) et +5 V.
- **Épreuves bonus** : A (balles et bouclier, `$DFA0`, état 5) et B (bombes, `$EEC8`, état 7). Les humains y jouent **à tour de rôle** : `$1077` (joueur) et `$1078` (combattant) partent de 1 et descendent jusqu'à 0 (`L_0E146` / `L_0F088`). Chaque tour n'a lieu que si `$1007[joueur]` est actif.
- **Accroches 15 à 21** :
  - `$DFCE`/`$DFD4`, `$EF02`/`$EF08` : départ à **2**. Sans joueur 3, le tour 2 est sauté : comportement identique à l'original.
  - `$DFF8` (`blinka`), `$EF4A` (`blinkb`) : `$14` n'est écrit dans `$1314[joueur]` (clignotement du poing) que pour les joueurs 0 et 1. Pour le joueur 2, l'écriture serait tombée sur `$1316`, un drapeau d'état.
  - `$ED04` (`rdhook`) : `F_0ED04` lit les joysticks pendant les épreuves sans passer par `F_07732`. On y lit donc aussi l'adaptateur (routine commune `readjoy3`).
- **Couleurs dans l'épreuve B** : `$1022` est la couleur 1 (`$FF8242`), posée par le raster (`$1AF2`, routines Timer B en `$1934`). Elle vaut normalement `$007` (veste du bleu). L'épreuve B la met à `$700` (`$EEEC`) et la remet à `$007` à la fin (`$F0AE`). `blinkb` la met à `$007` pendant le tour du joueur 3 et à `$700` pour les autres. Effet de bord accepté : explosions et bulle de l'arbitre en bleu pendant ce tour.
- Validé dans Hatari (STF/1.04, 3 humains) : épreuve A au round 3 et épreuve B au round 6, avec le joueur 3 en premier, puis les joueurs 2 et 1 ; `$1316` reste à 0 ; le bleu est bien affiché. Empreintes : `IK3J_S3/ATOR.EXE` = `cd6b83ab485dc33f0b6de4bbc8df2423`, `IK3J_S4/ATOR.EXE` = `c70c6e623faa00cce0509e4c527b757d`.
