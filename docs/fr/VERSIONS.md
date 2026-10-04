# IK+ — historique des versions (essais sur machine réelle)

*Notes de travail, en français. Les numéros de section suivent ceux de [METHODOLOGIE.md](METHODOLOGIE.md).*

## 6. Retours sur machine réelle (septembre 2026) et version 2

| Machine | Retour |
|---|---|
| STE / TOS 1.62 | Le jeu tourne, plus de « BUM COPY » (correctif `$36D2` confirmé). |
| Mega STE / TOS 2.06 | Bloqué sur l'écran du second chargeur de l'ancienne version. Démarrage sans pilote ni accessoires : **2 bombes**. 8 MHz sans cache : **écran figé**. Ça fonctionne avec un TOS 1.04 chargé en RAM. Non reproduit dans Hatari (1, 2 ou 4 Mo, 8 ou 16 MHz). |

**Hypothèse retenue (non prouvée) : la puce série SCC du Mega STE.** Elle est absente des STF/STE, et le TOS 2.06 active ses interruptions (niveau 5, vecteurs `$180`–`$1BC`). Ce second chargeur ne redirige les vecteurs que jusqu'à `$1A4`, vers un `rte` en `$7F000`, qui se trouve au milieu du 2ᵉ écran du jeu (`$78000`–`$7FD00`). Dès que le jeu abaisse l'IPL (`$236C`, `SR=$2300`), une interruption SCC saute soit dans le TOS déjà écrasé (bombes), soit dans un `rte` sans acquitter la puce, qui se redéclenche sans fin (blocage).

### Nouveau chargeur (`src/loader.s`, 803 octets)

Il remplace les trois fichiers de lancement de l'ancienne version : il n'y a plus d'intro, et seule l'image du jeu est lue.
- Lecture dans un bloc `Malloc` (aligné sur 4). La routine de recopie est posée juste après les données : bloc > `$700`, donc fin > `$53800`, hors de la source comme de la destination.
- Attente de 100 VBL avant de prendre la machine (moteur du lecteur), comme l'ancien second chargeur.
- Cookie `_MCH` : STE/Mega STE → son DMA arrêté, `$FF820F`/`$FF8265`/`$FF820D` = 0. Mega STE → SCC WR9 = 0 (canal A, `$FF8C81`), puis `$FF8E21` = 0 (8 MHz, sans cache).
- Vecteurs `$10`–`$3FC` → `rte` en `$6F0` (sous l'image du jeu) ; `$8`/`$C` → arrêt sur fond rouge en `$6E0`.
- Registres de départ identiques à ceux de l'ancien second chargeur, puis `jmp $1000`.
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
- Validé dans Hatari (STF/1.04, 3 humains) : épreuve A au round 3 et épreuve B au round 6, avec le joueur 3 en premier, puis les joueurs 2 et 1 ; `$1316` reste à 0 ; le bleu est bien affiché. Empreintes : image `IK3J_S3` = `cd6b83ab485dc33f0b6de4bbc8df2423`, image `IK3J_S4` = `c70c6e623faa00cce0509e4c527b757d`.

## 10. Version 6 : version STE (port étendu, son DMA, blitter)

Version réservée au **STE avec au moins 1 Mo** (cookie `_MCH` = `$00010000`, `phystop` ≥ `$100000`) : dossier `IK3J_STE`, chargeur `loader.s -DSTE` qui inclut `build/ste.bin` et le recopie en `$C0000`. Le jeu, écrit pour 512 Ko, n'utilise rien au-dessus de `$80000`.

### Mesures de départ (Hatari, STE/1.62, combat)

- **Une image = un pas du jeu.** `F_06EBE` attend que le compteur de VBL `$124A` dépasse `P_06EB8[$100D + $1010]` = [1, 3, 4, 5, 6, 7] ; `$100D` = 0 à 4 selon F6 à F10 (`$7086`). F6 (turbo) : 2 VBL par image au minimum (25 images/s) ; F8 (normal) : 5 VBL (10 images/s). À 50 images/s, le jeu irait deux fois plus vite que le turbo.
- `F_06EDC` (échange des écrans) attend d'abord que le faisceau soit entre les lignes 150 et 160 (`F_076D6`, lecture de `$FF8207`) : temps d'attente pure.
- Table mise à zéro (plus de limite) : 2,50 VBL par image en moyenne (61 % en 2 VBL, 23 % en 3, 14 % en 4).
- Profil : combattants 27 % (`F_09C5C`, `P_09D70`, `F_09E90`), effacement 13 % (`F_0D6C4`), bruitages 13 % hors coût d'entrée des interruptions (`P_017D8`/`P_0180E`), attente du faisceau 12 %, textes 8×8 6 % (`F_084C0`), raster 5 %.

### Joueur 3 sur le port étendu A (`p3.s -DSTEPAD`)

Ligne 0 (`$FF9202` = `$FFFE`) : directions en bits 8–11, actives à 0 ; `$FF9200` (accès en mot) bit 0 = Pause, bit 1 = A. Lignes 1 et 2 : bit 1 = B, puis C. Tir = A, B, C ou Pause. JOYTEST affiche aussi les ports A et B (STE et Falcon seulement : lire `$FF9202` sur STF provoque une erreur de bus).

### Son DMA (`ste.s` : `init`, `dmaplay`)

- Bruitages d'origine : 18 échantillons 8 bits non signés (centrés sur `$80`, multiples de 4) en `$2B178`, débuts et fins en `$2B078`/`$2B0F8`. Lancement en `$2064` (combat) et `$E36E` (épreuves) : Timer C, diviseur 4 et donnée `$3D`–`$44` (≈ 9,0 à 10,1 kHz, tirée au hasard), avec une interruption par octet qui convertit l'octet en deux volumes YM (registres 9 et 10, table en `$1834`). Pendant un bruitage, `$1374` ≠ 0 et la musique n'utilise plus que la voie A.
- Au lancement : rééchantillonnage à 12 517 Hz (interpolation linéaire, virgule fixe 16 bits, 8 bits signés, volume divisé par 2) en `$D0000`–`$EBE74`, en environ 2,3 s. Le résultat est identique octet par octet à une référence en Python. Le LMC1992 est réglé par le Microwire (0 dB, YM mélangé au DMA).
- Accroches : `$2064` → `jsr dmaplay` / `rts` ; `$E36E` → `jsr dmaplay` / `bra.s $E3BA`. Le Timer C n'est plus armé et `$1374` reste à 0 : la musique garde ses 3 voies.
- Gain : 85 % des images en 2 VBL (au lieu de 61 %), 2,11 VBL en moyenne.

### Blitter (`ste.s` : `initspr`, `drawf0/1/2`, `restore`, `rasterw`)

- Sprites des combattants : banques `$43078` (et miroir `$53078`), fabriquées par `F_02570` au démarrage (`$2208`). Table de 96 images ; une image = suite de bandes (décalage.w, nombre.w, puis nombre lignes de 3 mots), terminée par nombre = 0. Une bande fait 16 pixels de large, les décalages sont multiples de 8. Le masque est le OU des 3 plans.
- Chaque combattant répartit ses 3 plans sur les 4 plans de l'écran : blanc [effacé, p0, p1, p2], rouge [p1, p0, p1, p2], bleu [p1, p0, effacé, p2]. C'est ce qui donne la couleur de la veste.
- `initspr` recopie les deux banques au format du blitter (masque, p0, p1, p2 par ligne) en `$80000`, soit environ 142 Ko.
- Dessin : par bande, une passe par plan d'écran « ET NON masque » (op 4) puis « OU plan » (op 7), plus « OU masque » dans la carte de collision `($9FAC)` si `$9FB4` ≠ 0. Décalage de 0 à 14 pixels par le registre de décalage : 2 mots par ligne, sans FXSR ni NFSR. Le 2ᵉ mot source lu est la ligne suivante (pas en X = 8, pas en Y = 0) ; les restes sont coupés par les masques de bord. La liste de restauration et l'ombre (`F_0D818`, avec `a5` et `d7` comme l'original) sont inchangées.
- `restore` : copie de 8 mots × (nombre + 1) lignes depuis le décor `$23378`, et remise à zéro des cartes `($9FAC)`/`($9FB0)` si `$9FB4`/`$9FB6`.
- **Contrôle** (`-DCHECK`, `-DCHECKBONUS`) : chaque appel exécute l'original puis la nouvelle routine sur le même état, avec les interruptions masquées, et compare l'écran, les deux cartes, la liste et son pointeur. Résultat : 1 158 appels en combat à 3 joueurs et 15 dans les épreuves, **aucune différence**.
- **Deux pièges du mode partagé** :
  1. **Raster** : les couleurs changent parfois toutes les 2 lignes (table `$199C`). Le gestionnaire du Timer B (`$1934`) doit donc écrire le compteur suivant en moins de 2 lignes. Si le blitter partage le bus, il n'y arrive plus, et le bas de l'écran prend les couleurs de la zone d'avant (mer grise, pantalon noir : environ 1 image sur 25). Correctif : `$1934` → `jmp rasterw`, qui met le blitter en pause (bit 7 de `$FF8A3C` à 0), et la boucle d'attente `$194A` perd 3 tours pour compenser les 40 cycles ajoutés. Résultat : 0 défaut sur 186 captures, contre 6 sur 158 avant.
  2. **Fin de travail** : après cette pause, le bit 7 se relit à 0. La boucle d'Atari (`bset #7` / `nop` / `bne`) croyait alors le travail fini et reprogrammait le blitter en pleine copie : il restait des morceaux de combattants dans l'épreuve A. La fin se teste donc maintenant sur le compteur de lignes (`$FF8A38` = 0).
- Résultat final, sans limite de vitesse : 1,96 VBL par image (87 % en 2 VBL, 4 % en 3). **Turbo (F6) : 25 images/s dans 100 % des images mesurées**, contre 22,5 en moyenne pour l'original.
- Empreintes : image `IK3J_STE` = `000bc16b2c0866b16e001c22b0c8048d`, `IK3J_STE/IK_PLUS.TOS` = `1a711eae25e9a54b95d59478dbc3e1b4`.

## 11. Version 6.1 : clignotements sur STE réel (garde du blitter)

- **Retour de la machine réelle** (STE 4 Mo / TOS 1.62, `IKPLUS_STE_v2`) : clignotements dans la partie centrale de l'image (reflet du soleil sur l'eau), et parfois de l'image entière. Rien de tel dans Hatari : 0 défaut sur les captures, mer toujours bleue. Port étendu non testé (pas de manette Jaguar sous la main).
- **Chaîne raster** : `F_023B2` (appelée par le VBL vers la ligne de balayage 7 à 19, bien avant l'affichage) arme le Timer B en comptage de lignes. Interruptions à la fin des lignes affichées 14, 19, 22, **68, 70, 72, 74, 76**, 101, 115 et 190 : routines `$1A06`, `$1A34`, `$1A42`, **`$1A4C`–`$1A6A` (couleur 10 : `$733`, `$743`, `$754`, `$765`, dégradé du reflet)**, `$1A7C`, `$1AA4`, `$1ACE`, `$1B2E` (couleurs du bas et adresse de l'écran suivant, `$1B70`).
- **Mesure dans Hatari** (point d'arrêt à l'entrée du gestionnaire, variables `HBL` et `LineCycles`) : l'interruption arrive vers le cycle 464 de la ligne ; retard à l'entrée : v5 : 99 % sous 184–192 cycles, 296 au pire ; v6 : 99 % sous 244–256, **284 au pire**. Sans retard, la couleur du reflet change vers le pixel 278 de la ligne suivante, à droite du reflet (pixels ~145–180) : il faudrait environ 380 cycles de retard pour qu'elle tombe dedans.
- **Hypothèse retenue (non prouvée sur machine)** : en mode partagé, le blitter garde le bus jusqu'à 64 accès (~256 cycles). Sur la machine, si la boucle le relance (`bset #7`) juste avant que le 68000 prenne l'interruption, il repart pour un paquet de plus : le retard dépasse alors ~500 cycles, le dégradé se décale dans le reflet, et le compteur suivant du Timer B peut être écrit trop tard (tout le bas de l'écran aux mauvaises couleurs : clignotement « de l'image entière »). Hatari ne reproduit pas ce cas.
- **Correctif** (`ste.s`, `bwait`, commun aux 5 lancements du blitter) : on ne lance ni ne relance jamais le blitter quand le compteur du Timer B (`$FFFA21`) vaut 1, c'est-à-dire pendant la dernière ligne avant une interruption raster ; on le met en pause et on attend que l'interruption soit passée. Lancé à 2 lignes ou plus (≥ 512 cycles), il rend le bus au bout de 256 cycles au plus, et la boucle le met en pause avant l'interruption. Timer B arrêté (`$FFFA1B` = 0, écrans sans raster) : pas de garde. `-DNOGUARD` redonne l'ancienne boucle, pour comparer sur la machine.
- **Résultats dans Hatari** :
  - retard à l'entrée du gestionnaire : **144 cycles au pire** pour les 10 premières interruptions (au lieu de 284 ; la v5 allait jusqu'à 296) ;
  - interruption de la ligne 190 : retards jusqu'à ~430 cycles, déjà présents dans la v5 (340) ; ils viennent de l'interruption clavier/joystick (IKBD, `$2492`), qui arrive vers les lignes 186 à 189 dans les deux versions ; sans effet visible (10 dernières lignes, adresse d'écran prise au VBL suivant) ;
  - vitesse : turbo (F6) à 2 VBL par image dans 100 % des images de combat, comme avant ; sans limite (`unlock.py`) : 25,3 images/s avec ou sans garde ;
  - contrôle octet par octet (`-DCHECK`, 3 humains) : 420 appels, aucune différence.
- **Retour de la machine réelle** (STE 4 Mo / TOS 1.62, `IKPLUS_STE_v3`) : **affichage parfait**, plus aucun clignotement du reflet ni de l'image entière. L'hypothèse du retard dû au blitter est donc confirmée par le correctif. Reste à tester : la manette Jaguar sur le port étendu A.
- Empreintes : image `IK3J_STE` = `000bc16b2c0866b16e001c22b0c8048d` (inchangé), `IK3J_STE/IK_PLUS.TOS` = `ac65346a23401c7e02d1402a39b3dc96`.

## 12. Manette Jaguar sur STE réel : A et Option muets

- **Retour de la machine réelle** (STE 4 Mo / TOS 1.62, `IKPLUS_STE_v3`) : bruitages présents, volume correct par rapport à la musique. Manette Jaguar sur le port étendu A : directions, B, C et Pause fonctionnent dans JOYTEST et dans le jeu ; **A et Option ne réagissent pas**, ni dans JOYTEST ni dans le jeu. Dans le jeu, B et C servent de tir.
- Les deux programmes suivent le brochage documenté (et émulé par Hatari) : ligne 0 (`$FF9202` = `$FFFE`) → directions en bits 8–11, Pause en bit 0 et **A en bit 1** de `$FF9200` ; lignes 1, 2, 3 → B, C, **Option** en bit 1. B et C (lignes 1 et 2) arrivent bien sur le bit 1 : c'est le bit 1 des lignes 0 et 3 qui reste muet. Cette manette (ou un adaptateur) envoie donc A et Option ailleurs, ou pas du tout.
- **JOYTEST** : nouvelles lignes « Lignes brutes », qui affichent pour les lignes 0 à 3 (les deux ports sélectionnés ensemble : `$FFEE`, `$FFDD`, `$FFBB`, `$FF77`) les valeurs lues dans `$FF9202` et `$FF9200`, bits à 0 = appuyé. Vérifié dans Hatari (sans manette : `FFFF` partout). À faire sur la machine : noter les 8 valeurs au repos, puis en appuyant sur A, puis sur Option.
- **Deuxième essai** (JOYTEST avec les lignes brutes, manette Jaguar d'origine, ports A et B) : directions correctes, mais **plus aucun bouton** ne réagit (`$FF9200` = `FFFF` sur les 4 lignes). Au repos, `$FF9202` relit dans son octet bas la sélection écrite (`FFEE`, `FFDD`, `FFBB`, `FF77`).
- **Piste** : ce JOYTEST lit `$FF9202` avant `$FF9200` sur chaque ligne ; le premier ne le faisait que sur la ligne 0 (A muet), et lisait `$FF9200` aussitôt sur les lignes 1 et 2 (B et C corrects). Le jeu lit aussi `$FF9202` avant `$FF9200` sur la ligne 0. Lire `$FF9202` perturberait donc la lecture suivante de `$FF9200` sur la machine (Option, lu aussitôt, reste inexpliqué).
- **JOYTEST, 3ᵉ version** : pour chaque ligne, `$FF9200` est lu de trois façons : (1) juste après la sélection, (2) après ~64 cycles d'attente, (3) après une lecture de `$FF9202`. La ligne « Port étendu » utilise la lecture (1). Vérifié dans Hatari (sans manette : `FFFF` partout).
- **Troisième essai** (JOYTEST 3ᵉ version, photos sur STE réel) : avec les lectures (1) et (2), les cinq boutons répondent (A et Pause sur la ligne 0, B sur la ligne 1, Option sur la ligne 3 : `FFFD` ou `FFFE`) ; avec la lecture (3), `$FF9200` relit toujours `FFFF`. Même résultat sur le port B. **Sur la machine, une lecture de `$FF9202` masque les boutons dans la lecture suivante de `$FF9200`** ; une nouvelle sélection remet tout en ordre. Hatari ne reproduit pas ce comportement.
- **Correctif** (`p3.s -DSTEPAD`) : sur la ligne 0, `$FF9200` est lu avant `$FF9202`. A redevient un tir, comme B, C et Pause (Stéphane : A, B et C suffisent ; Option n'est pas utilisé). Vérifié dans Hatari (manette émulée : tir → `$126E` = `$1F`, droite → `$07`, haut → `$0E`). Empreinte : image `IK3J_STE` = `b13f02f89dcebf935af8a1a5f6c4cc83` (`IK3J_STE/IK_PLUS.TOS` inchangé : `ac65346a23401c7e02d1402a39b3dc96`).

## 13. Deux dossiers : IK3J_PAR et IK3J_STE

- **Retour de la machine réelle** (STE, `IKPLUS_STE_v4`) : tout est validé : manette Jaguar (directions, tir A, B et C, F3 dans les deux sens), épreuves bonus à 3, affichage, bruitages, turbo.
- **Décision de Stéphane** : deux versions seulement.
  - `IK3J_PAR` (ex-`IK3J_S3`) : STF, STE, Mega STE ; joueur 3 sur la prise joystick 3 de l'adaptateur parallèle (D4–D7 + BUSY). Même fichier qu'avant : image `IK3J_PAR` = `cd6b83ab485dc33f0b6de4bbc8df2423`.
  - `IK3J_STE` : STE uniquement ; manette Jaguar sur le port étendu A ; son DMA et blitter.
- **Abandon de la prise joystick 4** (`IK3J_S4`, `p3.s -DPORT4`, D0–D3 + STROBE) : code retiré de `p3.s` (`p3.bin` et `p3_ste.bin` inchangés à l'octet) et du `Makefile`. Les faux tirs de BUSY sur la prise 3 (§9) venaient de l'ancien STE de Stéphane ; sa machine actuelle n'a pas ce défaut. JOYTEST affiche toujours les deux prises.
- Le chargeur n'impose rien selon la machine : c'est le dossier choisi qui décide du périphérique du joueur 3 (on ne peut pas détecter une manette Jaguar : au repos, elle lit comme un port vide). Un petit menu au démarrage est envisagé plus tard.

## 14. Version 7 : à partir de IK+.PRG

- **Nouvelle version de départ** : `IK+.PRG`, un seul programme (344 516 octets, MD5 `4107c876be9d49deb2a3cf5b390f70be`), fourni par Stéphane. Sa provenance est inconnue et ce n'est pas le fichier de la disquette d'origine : sa vérification de la disquette est déjà neutralisée (METHODOLOGIE.md §1). Choix de Stéphane : une version d'un seul fichier, sans message de cracker dans le jeu. Le crédit affiché redevient « IK+ (C) 1988 ARCHER MACLEAN ».
- **Même code de jeu** : 62 octets diffèrent de l'image utilisée jusqu'à la v6, aucun dans les zones corrigées. Toutes les accroches (`patch_p3.py`, `patch_ste.py`) s'appliquent telles quelles.
- **Outils** : `tools/ikimg.py` tire l'image du jeu (`$700`–`$537FF`) de `IK+.PRG` ; `tools/patch_game.py` y ajoute le correctif STE (`$36D2`) et saute la vérification de la disquette (`$6A44` : `bra.w $6AF8`, qui garde la sauvegarde et la restauration des registres de `F_06A40`, et la valeur posée en `$1030`). Sans ce saut, le jeu attend l'arrêt du moteur du lecteur et se bloque s'il n'y a pas de disquette (vérifié dans Hatari).
- **Fichiers sur l'Atari** : `IK_PLUS.TOS` (notre chargeur) et `IKPLUS.IMG` (l'image corrigée). `make game PRG=…/IK+.PRG`.
- Vérifié dans Hatari : `IK3J_PAR` sur STF/1.04, STE/1.62 et Mega STE/2.06, `IK3J_STE` sur STE/1.62 : démarrage, partie à 3 (F2 puis F3), turbo, mer toujours bleue. Les images ne diffèrent des précédentes que dans les zones attendues (ancien chargeur `$704`–`$7FF`, vérification, crédit, graphismes).
- **Retour de la machine réelle** (`IKPLUS_V7`, STE et Mega STE) : tout est validé : démarrage sans disquette dans le lecteur, partie à 3 avec l'adaptateur parallèle (`IK3J_PAR`) et avec la manette Jaguar (`IK3J_STE`), affichage, bruitages, turbo, crédit « ARCHER MACLEAN ». Étiquette `v1.0.7`.
- Empreintes : image `IK3J_PAR` = `15fb38453300c0700f3588928d6d4513`, `IK_PLUS.TOS` = `2094db4eb20774ec27957cdff56751ad`, image `IK3J_STE` = `b56480f2eaa42f280ec4682f9cc8dc07`, `IK3J_STE/IK_PLUS.TOS` = `95fae0ec107d35232150d69da54b0250`.

## 15. Version 8 : touches F3 et F5, vitesse, reset, barre du haut

Tickets #7, #9, #10, #11 et #14. Les deux dossiers changent (`patch_p3.py`, 26 accroches).

- **F3 = partie à 3 joueurs** (#9) : comme F1 et F2 (`L_07388`), avec la même condition (`$1006` ≥ `$19`) : `$1007`, `$1008`, `$1009` = 1 puis `$135F` = 1 (nouvelle partie). Les trois poings clignotent : le jeu n'a que deux compteurs (`$1314`/`$1315`, `$1316` est un autre drapeau), d'où `blink3` dans `p3.s`, mis à $1E en même temps (`$6CE4`) et décompté dans `F_07608` (`$7608`). Pendant le clignotement, `pre` ne resynchronise pas le poing bleu. F1, F2 et le tir d'un joystick (`$7388`) remettent `$1009` à 0. F3 ne fait plus passer le bleu humain / ordinateur en cours de partie.
- **F5 = musique** (#11) : ancienne action de F3 (`F_01706` / `F_01734`), code `$3F`, inutilisé par le jeu. `$7316`-`$733B` réécrit : F3 → `f3key`, F5 → `f5key`.
- **Textes** (#11) : message `$0B` « PRESS F5 FOR MUSIC ON OR OFF » ; message de la démo « OR F1 F2 F3 KEYS » (même longueur). **Écran d'aide** : image non compressée en `$19DA0` ; `tools/helpscreen.py` refait deux lignes, « F3 ..... 3 PLAYER GAME » et « F4/F5 .. FX/MUSIC ON/OFF », avec les lettres de l'image (cases de 6 x 5 pixels) ; seul le « 5 » est dessiné. Couleur de chaque nouveau pixel : celle du pixel de texte d'origine le plus proche (dégradé animé par la palette). Empreinte des lignes 61-71 vérifiée avant correction.
- **Vitesse gardée** (#10) : `P_014FA` (toute nouvelle partie) écrivait `move.b #2,$100d.w` en `$151E` → NOP. Le démarrage à froid (`L_022AC`) met toujours « normal ».
- **Bouton reset** (#14) : ce n'était pas une interruption : le jeu écrit `resvalid` = `$31415926` et `resvector` = `L_02160` (`$21E6`), donc le TOS relance le jeu au reset. Remplacé par `clr.l $426.w` : le reset revient au TOS.
- **Barre du haut** (#7) : groupes (points de vie, score, poing) tous les 80 pixels, poing bleu collé à « LV ». Rouge décalé de 8 pixels, bleu de 16 vers la gauche : tables `$85D4` (points de vie), `$85D7` (scores), `$7648` (poing rouge, `$50` → `$4C`), `FIST_X` dans `p3.s` (`$78` → `$70`). Écarts : 8, 8 puis 16 pixels avant « LV » (les points et les chiffres sont en cases de 8 pixels).
- Vérifié dans Hatari : `IK3J_PAR` sur STF/1.04 (F3, clignotement des trois poings, F7 puis F2 : vitesse « SWIFT » gardée et bleu rendu à l'ordinateur, F3 de nouveau ; F5 : `$100E` passe de 1 à 0 puis à 1 ; `$426` reste à 0, et après un reset le processeur est dans le TOS), `IK3J_STE` sur STE/1.62 (F3, barre du haut). Écran d'aide vérifié sur l'image produite.
- **Retour de la machine réelle** (`IKPLUS_V8`, STE 4 Mo / TOS 1.62) : tout est validé, selon la liste du `LISEZMOI.TXT` : F3 et clignotement des trois poings, F1/F2, F5 (musique), écran d'aide et messages, vitesse gardée, bouton reset, barre du haut.
  Mega STE / TOS 2.06 avec `IK3J_PAR` (le seul dossier qui y tourne) : tests validés, bouton reset compris. Étiquette `v1.0.8`.
- Empreintes : image `IK3J_PAR` = `ea71bbcd3b431a860122de6ca25754f3`, image `IK3J_STE` = `7c964b140aa63d7f7c00c4eb2abbc248` (chargeurs inchangés).

## 16. Version 9 (étape 1 du ticket #16) : page d'introduction

Ticket #16 : un seul programme pour toutes les machines, une page d'introduction et le choix des contrôles. Il reprend le ticket #4 (Mega STE). Décisions de Stéphane :
- page : logo IK+, « REFORGED », une ligne par joueur (F1, F2, F3 changent la source), « SPACE TO START », « CLAUDE AI 2026 » ; textes en anglais, comme le jeu ;
- sources : JOYSTICK 0, JOYSTICK 1, JOYSTICK 2 (prise 3 du port parallèle : D4–D7 + BUSY), JOYSTICK 3 (prise 4 : D0–D3 + STROBE, remise en service), JOYPAD A et JOYPAD B (STE seulement), NONE (joueur 3 seulement ; F3 ne peut alors pas rendre le joueur 3 jouable) ; une même source ne sert jamais à deux joueurs ;
- choix mémorisé dans un fichier ; disquette protégée ou disque plein : rien n'est écrit, sans erreur ;
- Mega STE : « / » bascule entre 8 MHz sans cache et 16 MHz avec cache (pour les essais, pas affiché sur la page).
Étapes prévues : 1. la page ; 2. le choix des contrôles et la lecture paramétrable ; 3. le programme unique ; 4. le Mega STE (son DMA, blitter, « / »).

**Étape 1** (cette version) : la page, dans le chargeur `src/loader.s` (`intro`), sous le TOS, après la lecture de `IKPLUS.IMG`. Le logo et la police sont pris dans l'image lue : rien du jeu dans `IK_PLUS.TOS`.
- Logo : image 160 x 121 non compressée en `$1B678` (format écran, 160 octets par ligne, couleurs 9 à 15), copiée par `F_061A2` dans l'introduction du jeu ; lignes 5 à 111 recopiées en y = 4. Couleurs 9 à 15 = celles de l'introduction du jeu (`$300` à `$700`, `$000`, `$666`).
- Police : 8 x 8 en `$9736` (celle de `F_084C0`), index = code − `'0'` ; espace = `'@'` ; `:` dessiné avec le `=` du jeu (même forme) ; `(` et `)` dessinés dans le chargeur.
- Pour l'instant, les lignes des joueurs ne font qu'afficher les commandes du dossier (joueur 3 : JOYSTICK 2 dans `IK3J_PAR`, JOYPAD A dans `IK3J_STE`). Espace lance la suite ; l'attente de ~2 s pour le lecteur de disquette compte le temps passé sur la page.
- Vérifié dans Hatari : STF/1.04 et Mega STE/2.06 (`IK3J_PAR`), STE/1.62 (`IK3J_STE`) : page, puis introduction du jeu après Espace. Images du jeu inchangées.
- Empreintes de l'étape 1 : `IK3J_PAR/IK_PLUS.TOS` = `4f67ca0554f029764d53ba04f9c87a19`, `IK3J_STE/IK_PLUS.TOS` = `8c0b785577cd5619217416bd4c4b11f1`.
- **Retour de la machine réelle** (étape 1) : Mega STE validé, y compris le lancement depuis un bureau en moyenne résolution (retour en basse résolution).

**Étape 2** : choix des joysticks.
- **Jeu** (`src/p3.s`, `patch_p3.py`, 27 accroches) : le gestionnaire IKBD du jeu (`P_02516`, `$2532`) ne remplit plus `$126C`/`$126D` ; `ikbdhook` garde les deux joysticks du clavier (`RAW0`, `RAW1`). Le VBL (`$1BAA`, avant la routine son) appelle `vblmap`, qui remplit `$126C`, `$126D`, `$126E` à partir de la source de chaque joueur (`CTL`, 3 octets en `$848`, écrits par le chargeur). Sources : 0, 1 = joysticks du clavier ; 2 = prise 3 (D4–D7 + BUSY) ; 3 = prise 4 (D0–D3 + STROBE, code de l'ancienne variante `-DPORT4`) ; 4, 5 = manettes Jaguar A et B ($FF9200 lu avant $FF9202) ; 6 = aucune. L'ancienne lecture du joueur 3 dans `pre` et au début de `F_0ED04` (accroche 19, `rdhook`) est retirée : la lecture au VBL sert partout (combat, épreuves, menus). F3 ne fait rien si le joueur 3 est sur NONE. `p3.bin` et `p3_ste.bin` sont maintenant identiques (934 octets).
- **Chargeur** : F1, F2, F3 passent à la source suivante permise (pas déjà prise ; manettes si `_MCH` = STE ; NONE pour le joueur 3 seulement). Clic clavier coupé (`conterm`). `IKPLUS.CFG` : 4 octets, `'I'` puis les trois sources ; vérifié à la lecture (sinon choix par défaut) ; écrit à l'appui sur Espace s'il a changé (ou s'il n'existait pas), avec un gestionnaire `etv_critic` qui renvoie l'erreur sans boîte d'alerte. Après une écriture, nouvelle attente de ~2 s pour le lecteur.
- Vérifié dans Hatari : lecture des sources par l'émulation des joysticks (Xvfb + xdotool, `$126C`–`$126E` lus au débogueur) : joysticks 0 et 1, prises 3 et 4 (STF/1.04), manettes A et B et joystick 1 (STE/1.62), directions, tirs et trois joueurs à la fois ; F3 sans effet avec NONE, partie à 3 sinon ; `IKPLUS.CFG` relu et écrit (disque dur GEMDOS, disquette) ; disquette protégée en écriture : pas de message, le jeu démarre, rien d'écrit.
- Empreintes : images `IK3J_PAR` = `47c4470c565aed31afed2fdafc2fa5ae`, `IK3J_STE` = `1f8287f1eabad2373a98013a6f8e76af` ; `IK3J_PAR/IK_PLUS.TOS` = `2ee9920d4f637526efc272e407d280d2`, `IK3J_STE/IK_PLUS.TOS` = `53ba614726a0e7c85fa0b59313a27917`.
