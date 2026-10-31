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
- **Retour de la machine réelle** (étape 2) : validé sur Mega STE et sur STE.

**Étape 3** : un seul programme, un seul dossier `IK_PLUS`.
- **Chargeur** : plus de variante `-DSTE`. `prep` (au tout début) lit `_MCH` et `phystop` : STE (`$00010000`) → manettes proposées ; STE avec au moins 1 Mo → mode STE possible, si le bloc `Malloc` finit sous `$C0000` (sinon, mode normal, sans message). Après la lecture de `IKPLUS.IMG`, `stehook` vérifie les octets d'origine des 9 accroches (table `build/stehooks.i`, produite par `patch_ste.py --asm`), puis les pose ; le module `ste.bin` est recopié en `$C0000` et initialisé par la routine de recopie (`stubste`). Sur STF, Mega STE ou STE 512 Ko, le jeu tourne sans ces accroches. Joueur 3 par défaut : JOYPAD A sur tout STE, JOYSTICK 2 ailleurs.
- **Outils** : `patch_ste.py` garde une seule liste d'accroches (`HOOKS`) pour la table du chargeur et pour l'image de contrôle `IK_STE_CHECK.IMG`, dont l'empreinte est celle de l'ancien `IK3J_STE/IKPLUS.IMG` validé sur STE réel (`1f8287f1…`) : les accroches posées par le chargeur sont donc exactement celles de la v6. `p3_ste.bin`, `IK_STE.TOS` et `-DSTEPAD` sont retirés (`p3.bin` était déjà commun).
- **Distribution** : `dist/README.TXT` (anglais) et `dist/LISEZMOI.TXT` (français) listent toutes les différences avec le jeu d'origine ; `tools/textfile.py` les recopie dans le dossier avec des fins de ligne CR LF et le jeu de caractères de l'Atari (code page 437, sauf « À », « œ »…). Les notes d'essai livrées à Stéphane s'appellent désormais `A_TESTER.TXT`.
- Vérifié dans Hatari : STF/1.04 (mode normal, joueur 3 sur JOYSTICK 2), STE/1.62 4 Mo (mode STE : accroche en `$2064` = `jsr $C0004`, module en `$C0000`, écran vert de conversion des sons, partie à 3 avec F3), STE/1.62 512 Ko (mode normal, JOYPAD A par défaut), Mega STE/2.06 (mode normal).
- Empreintes : `IK_PLUS/IKPLUS.IMG` = `47c4470c565aed31afed2fdafc2fa5ae` (inchangée), `IK_PLUS/IK_PLUS.TOS` = `467fd398b98d0594f39fc1a8764893ca`, `IK_STE_CHECK.IMG` = `1f8287f1eabad2373a98013a6f8e76af`.
- **Retour de la machine réelle** (étape 3) : validé sur STE et Mega STE.

**Étape 4** : Mega STE (ticket #4).
- **Mode STE sur Mega STE** : `prep` reconnaît aussi `_MCH` = `$00010010` (`ismste`) ; avec au moins 1 Mo, le chargeur pose les mêmes 9 accroches et recopie le module (son DMA, Microwire et blitter existent aussi sur Mega STE). Pas de manettes (pas de ports étendus) : joueur 3 par défaut sur JOYSTICK 2. Le chargeur règle toujours 8 MHz sans cache au départ.
- **Touche « / » du pavé numérique** (code `$65`), pour les essais : sur Mega STE seulement (drapeau `MSTE` écrit par le chargeur), bascule entre 8 MHz sans cache et 16 MHz avec cache (`$FF8E21` = 0 ou 3). Accroche 11 réécrite : F3 → `f3key`, F5 → `f5key`, `$65` → `slashkey` (nouvelle entrée `$848`). `CTL` passe en `$84C`, suivi de `MSTE`. Code 3 joueurs : 970 octets.
- Vérifié dans Hatari (Mega STE/2.06, 4 Mo) : mode STE (accroche en `$2064`, module en `$C0000`), « / » → `$FF8E21` = `03`, partie à 3 qui continue ; mer toujours bleue (`glitch.py`, 84 captures) à 8 et à 16 MHz, en turbo (F6). Sur STE, « / » ne fait rien (`MSTE` = 0).
- À vérifier sur machine réelle : son DMA et blitter sur Mega STE (reflet sans clignotement, à 8 puis à 16 MHz), turbo, et la bascule « / ».
- Empreintes : `IK_PLUS/IKPLUS.IMG` = `27a89706e1ed3ed66090db8122d66f76`, `IK_PLUS/IK_PLUS.TOS` = `71f575dedc3c2ee4b98f74d529737756`, `IK_STE_CHECK.IMG` = `b9d8dddfe68b650fc2ffc0a5396777cf` (les accroches STE ne changent pas : seul le code 3 joueurs change).
- **Retour de la machine réelle** (étape 4, Mega STE) : son DMA et blitter validés. La touche « / » passait bien à 16 MHz avec cache, mais certains rasters étaient moins stables, sans aucun gain : **option retirée**. Le chargeur règle toujours le Mega STE à 8 MHz sans cache avant le jeu (vérifié dans Hatari : `$FF8E21` = 0 en combat).

**Ticket #18** (page d'introduction) et **ticket #19** (mode entraînement).
- **Page** : logo tout en haut (y = 0) ; « REFORGED EDITION » ; « PRESS SPACE TO START », remplacé par « PLEASE WAIT » après Espace (plus de fond vert avant le jeu : le fond reste noir, la page reste affichée pendant l'attente du lecteur et la conversion des sons) ; « ENHANCED BY CLAUDE AI - 2026 - Vx.y.z » ; « IN MEMORY OF ARCHER MACLEAN (1962-2022) ». Lettres ajoutées au chargeur : « . » ; « - » = lettre 44 de la police du jeu. La police n'a que des majuscules : la version s'écrit « V1.0.9 ».
- **Version** : `make TAG=v1.0.9` ; par défaut, l'étiquette git du commit (la CI récupère les étiquettes : `fetch-depth: 0`), sinon la dernière étiquette suivie de « + » (`build/version.i`, réécrit seulement s'il change). `make check` vérifie `IK_PLUS_REF.TOS`, le même chargeur avec le texte « V0.0.0 » (`-DREFTAG`), car l'empreinte de `IK_PLUS.TOS` change avec la version.
- **Mode entraînement** : F4 sur la page (ligne grise à l'arrêt, verte en marche ; jamais mémorisé dans `IKPLUS.CFG`) ; le chargeur écrit `TRAIN` en `$853`, après `CTL` (passé en `$850`). Dans le jeu, quand `TRAIN` est mis et qu'au moins un humain joue : accroche 28 (`$1DBA`, VBL) : le temps du round (`$11FB`) ne baisse plus, et le chronomètre des parties à 3 (`gamesec`) non plus ; accroche 29 (`$7564`, `F_07536`) : le temps s'affiche « -- » (lettre 44). La démo (aucun humain) et les épreuves bonus (leur propre chronomètre) ne changent pas. En fin de round, le bonus de temps compte toujours 30 secondes.
- `slashkey` et le drapeau `MSTE` retirés ; code 3 joueurs : 1010 octets sur 1 024 (presque plein) ; 29 accroches.
- Vérifié dans Hatari : page (STF, STE, Mega STE), F4, « PLEASE WAIT » sans fond vert (aussi pendant la conversion des sons sur STE) ; entraînement en partie à 1 joueur : « TIME: -- », `$11FB` reste à `$30` ; sans entraînement, le temps baisse normalement ; Mega STE en mode STE à 8 MHz.
- Empreintes : `IK_PLUS/IKPLUS.IMG` = `d4b04662410edecebb08ecd4babaf052`, `IK_PLUS_REF.TOS` = `579567695ab7465149d96149eed7e7dd`, `IK_STE_CHECK.IMG` = `648aa93950588c2da491ef0b1b912980`.
- **Retouches de la page** (demande de Stéphane) : « REFORGED » à gauche du logo et « EDITION » à droite (ligne 49, cases 1 et 31) au lieu de la ligne « REFORGED EDITION » ; options F1 à F4 tous les 10 points (2 lignes d'écart, `RSTEP`) à partir de la ligne 112 ; « PRESS SPACE TO START » centré entre la ligne F4 et « ENHANCED BY CLAUDE AI » (`TROW` calculé).
- **Mode entraînement, points** (ajout au ticket #19) : personne ne marque de points de round, donc les rounds ne finissent jamais. Accroche 30 en `$8586` (`F_08564`, ajout de `$125E` aux points `$11EE`-`$11F0`, la fin de round se décide en `$69A6` à 6 points). Le score continue d'augmenter.
- **Place** : le code 3 joueurs était presque plein (1010 octets). Le code du mode entraînement passe dans `src/p3b.s`, assemblé en `$6A4A`, dans le corps de la vérification de la disquette (`F_06A40`) que `patch_game.py` saute depuis la v7 ($6A44 → $6AF8) : 174 octets libres, 94 utilisés ; empreinte de la zone d'origine vérifiée avant écriture. Entrées fixes `$6A4A` timechk, `$6A4E` timedisp, `$6A52` ptschk. `p3.s` revient à 942 octets (`CTL` reste en `$850`).
- Vérifié dans Hatari (STF/1.04) : page ; partie à 1 joueur en entraînement, 75 s de combat contre l'ordinateur : points de round toujours à 0, « TIME: -- », le round continue ; sans entraînement, la même partie se termine normalement.
- Empreintes : `IK_PLUS/IKPLUS.IMG` = `90c05ec22bd45bc9898ed30653b37300`, `IK_PLUS_REF.TOS` = `2b13ae7a9cbff22b48d9e2a0fbbafdd3`, `IK_STE_CHECK.IMG` = `368df6c7c8ae7cd4bc9c729f61e6f341`.
- **Retour de la machine réelle** : tout validé sur STE et Mega STE (page, entraînement sans points, mode STE). Fusion dans `master`.

## 17. Version 10 : écran de chargement

- **Plus de fond bleu** pendant la lecture de `IKPLUS.IMG` : le chargeur (`loading`) passe en basse résolution, met la palette à noir (couleur 0) et blanc (couleur 15, celle du texte du TOS), cache la souris et le curseur, puis écrit « Loading, please wait... » en haut à gauche avec la police du TOS (la police du jeu n'est pas encore lue ; d'abord « LOADING », texte changé à la demande de Stéphane). La page d'introduction suit.
- Textes de la distribution et README : « PLEASE WAIT » (page d'introduction) au lieu de l'ancien écran vert pendant la conversion des sons.
- Vérifié dans Hatari : Mega STE/2.06 depuis une disquette (« Loading, please wait... » pendant la lecture, puis la page), STF/1.04 depuis le disque dur (lecture trop rapide pour le voir, page normale).
- Empreintes : `IK_PLUS/IKPLUS.IMG` inchangée (`90c05ec22bd45bc9898ed30653b37300`), `IK_PLUS_REF.TOS` = `efd3aa5f4b6dbf8d376fc24d203786fe`.

- **Retour de la machine réelle** (essai 5) : « Loading, please wait... » validé sur STF, STE, Mega STE et Falcon. Fusion dans `master` après le Falcon (§18) : `IK_PLUS_REF.TOS` = `2d8d92fd5dbe391febd66d4ff42c4f73`.

## 18. Falcon030 (ticket #5) : premiers essais

- **Essai du jeu tel quel** (Hatari, Falcon, EmuTOS 1.3, moniteur RGB, 4 Mo) : le chargeur et la page d'introduction marchent ; le jeu démarre son introduction puis plante en boucle (saut à une adresse impaire près de `$1506`).
- **Cause** : en `$1C9C` (nouvelle partie demandée), le jeu fabrique un cadre d'exception de 68000 (`move.l #P_014FA,-(a7)` / `move.w #$2300,-(a7)` / `rte`). Le 68030 attend en plus un mot de format après le PC. Les autres `rte` du jeu reviennent de vraies interruptions : sans problème. **Correctif** (accroche 31) : `restart` (`p3b.s`, `$6A56`) empile un mot de format nul quand `_longframe` (`$59E`) n'est pas nul (68010 et plus) ; sur 68000, rien ne change.
- **Chargeur, sur Falcon** (`_MCH` = `$00030000`) : son DMA arrêté, caches du 68030 vidés et coupés (`movec d0,cacr`, écrit en `dc.w`), processeur à 8 MHz (`$FF8007`, bit 0), comme un ST. Pas de mode STE (son DMA, blitter) : à voir après l'essai sur machine réelle. Manettes JOYPAD A et B proposées (ports étendus présents, drapeau `haspad`) ; joueur 3 par défaut sur JOYSTICK 2.
- **Résultat dans Hatari** : introduction, partie à 3 (F3), combat, chronomètre ; le Timer B tombe aux mêmes lignes que sur STE (76, 81, 84, 130-138, 163, 177, 252) et les registres de palette ont les mêmes valeurs ; mais Hatari n'affiche pas les changements de palette en cours d'écran sur Falcon (une seule palette par image) : **les couleurs du combat ne peuvent être jugées que sur la machine réelle**. Manettes A et B lues sur Falcon.
- Page d'introduction : le « + » des versions de développement (« V1.0.8+ ») utilise la lettre 11 de la police du jeu (avant : un pavé).
- **CT60 (68060)** : pas encore traité. Le jeu utilise `movep` (VBL, `$1BDC`), absent du 68060 et émulé par le gestionnaire du TOS de la CT60, que le chargeur écrase en remplaçant tous les vecteurs ; caches et vitesse à voir aussi.
- Empreintes : `IK_PLUS/IKPLUS.IMG` = `013611bbd5cd32e80b95482e1696755d`, `IK_PLUS_REF.TOS` = `809e5a2d723f26f73d774f8924b30c55`, `IK_STE_CHECK.IMG` = `b6eaf97dc6de13dfc49e560aba921663`.
- **TOS 4.04** (fourni par Stéphane, `rom/tos404.img`) : même résultat qu'avec EmuTOS dans Hatari (page, introduction, partie à 3 avec F3, relance à 2 avec F2, aucune erreur) ; couleurs du combat toujours non jugeables dans Hatari.
- **Preuve de la limite de Hatari** : petit programme d'essai (Timer B en comptage d'événements toutes les 20 lignes, couleur 0 changée à chaque interruption ; sur Falcon, caches coupés et 8 MHz comme le chargeur). Sur STE : une bande de couleur toutes les 20 lignes. Sur Falcon (TOS 4.04, RGB) : tout l'écran d'une seule couleur, celle de la dernière interruption (pas noire : les interruptions ont bien lieu). Hatari 2.4.1 ne dessine qu'une palette par image en mode Falcon ; le Timer B, lui, fonctionne.
- **Blocage sur Falcon réel** (TOS 4.04, 14 Mo, RGB) : le programme se fige quand on appuie sur Espace. **Cause** : le TOS 4 active la MMU du 68030 et place sa table racine en `$700` (lue dans Hatari : CRP = `$00000700`, TC = `$80F04445`), justement là où le chargeur recopie le jeu : la traduction d'adresses part dans le décor dès la recopie. Hatari n'émule pas la MMU par défaut : avec `--mmu on`, il s'arrête (« Halt ») au même moment. **Correctif** (chargeur, sur Falcon avec un 68030, cookie `_CPU` = 30) : MMU coupée (`pmove.l (a7),tc` avec 0, écrit en `dc.w`) en même temps que les caches ; le TOS n'y faisait qu'une correspondance identité. Les 14 Mo n'y sont pour rien (même blocage avec 4 Mo et la MMU émulée) ; le calcul des sons non plus (pas de mode STE sur Falcon).
- Essais Hatari après le correctif : Falcon TOS 4.04 et EmuTOS, 14 Mo, `--mmu on`, RGB (page, introduction, partie à 3) ; STF, STE, Mega STE inchangés. Les essais Falcon précédents étaient faits sans `--mmu on` : désormais, toujours l'activer.
- Empreinte : `IK_PLUS_REF.TOS` = `25cc870f15c748bcf4c0c61cf8e0997b`.
- **Essai 4 sur Falcon réel** (TOS 4.04, 14 Mo, RGB) : le jeu démarre, mais combats lents, bruitages qui coupent la musique (pas de mode STE sur Falcon), rasters instables (soleil, reflets dans l'eau, ligne au niveau des pieds des combattants), écran qui saute. Dans Hatari, le combat sur Falcon reste à 5 VBL par image (vitesse normale) : Hatari ne reproduit pas la lenteur du 68030 à 8 MHz sur le bus du Falcon. Hypothèse : à 8 MHz sans cache, le Falcon est plus lent qu'un ST ; les images dépassent 5 VBL et les interruptions raster arrivent en retard.
- **Essais proposés** (`-DF16` : 16 MHz ; `-DFCACHE` : caches remis à `$3111` comme le TOS). Le jeu compte ses images en VBL : un processeur plus rapide ne change pas sa vitesse, sauf en turbo. Dans Hatari (Falcon, TOS 4.04, 14 Mo, `--mmu on`) : 8 MHz et 16 MHz sans cache tournent normalement ; **avec les caches, le jeu se fige** (plus aucune image après VBL 2 845) : variante écartée.
- Chargeur, sur Falcon : interruptions de la SCC coupées (WR9 = 0) comme sur Mega STE, avec 4 `nop` entre deux accès (au lieu de 2) ; `$FF8E21` (vitesse du Mega STE) écrit sur Mega STE seulement. Bits de `$FF8007` (d'après Hatari) : 0 = 68030 à 16 MHz, 2 = blitter à 16 MHz, 3 = blitter coupé, 5 = bus du Falcon (0 = émulation du bus STE) ; le chargeur ne touche que le bit 0.
- Empreinte : `IK_PLUS_REF.TOS` = `b65aa0cd39019e933e8fa0b1b41dc77b`.
- **Essai 5 sur Falcon réel** (TOS 4.04, 14 Mo, RGB) : avec le chargeur à 16 MHz sans cache (`IK16.TOS`), tout est bon : vitesse des combats, rasters (soleil, reflets, pieds des combattants) et écran stables. À 8 MHz, les défauts de l'essai 4 restent. Les bruitages coupent toujours la musique (pas de son DMA sur Falcon) : accepté par Stéphane.
- **16 MHz par défaut** sur Falcon (`-DF8` : 8 MHz, pour les essais) ; l'option des caches (`-DFCACHE`) est retirée (jeu figé dans Hatari).
- Textes de la distribution et README : Falcon030 ajouté (16 MHz, caches coupés, pas de son DMA ni de blitter, CT60 non prise en charge ; manettes JOYPAD A/B sur STE et Falcon). Le `IK+.PRG` d'origine ne démarre pas sur Falcon dans Hatari (écran noir).
- Empreinte : `IK_PLUS_REF.TOS` = `0f76be43ff62e7301d674e1bce951587`.
- **Autres essais de Stéphane** : Falcon030 sur moniteur **VGA** : le jeu fonctionne, mais la musique est trop rapide (l'écran n'est pas à 50 Hz) ; accepté. Falcon avec **CT60** (68060) : plantage après la page d'introduction ; ignoré (la CT60 se remet facilement en mode 68030), noté dans les textes et les README comme non pris en charge.

## 19. Page d'introduction : dessins « REFORGED » et « EDITION »

- Les textes « REFORGED » et « EDITION » (police du jeu, ligne 49) sont remplacés par deux dessins de Stéphane, de part et d'autre du logo, lignes 43 à 60 (gauche : x = 0 à 82 ; droite : x = 245 à 318).
- Source : son écran Degas `IKPLUS2.PI1` (MD5 `b42973810f1abce24c1b5523601727d8`), hors du dépôt dans `../ikplus-local/` puisqu'il contient aussi le logo du jeu. `tools/sides.py` en tire les deux blocs (6 et 5 groupes de 16 pixels, 4 plans entrelacés, 1 584 octets), seuls dans le dépôt : `src/sides.i`. La palette du PI1 est d'un cran plus sombre (conversion PNG → PI1) : chaque couleur est remontée d'un cran et retrouvée dans la palette du chargeur, qui ne change pas (rouges du logo 9 à 13, gris clair 15).
- Chargeur : `dside` pose chaque bloc après le logo, avec un masque (les pixels noirs du dessin ne touchent pas l'écran).
- Page d'introduction : le « + » des versions de développement (« V1.0.9+ ») utilise la lettre 11 de la police du jeu (avant : un pavé ; même correctif que sur la branche `falcon`).
- Essais Hatari (STF TOS 1.04, STE TOS 1.62, Mega STE TOS 2.06) : l'écran obtenu est identique, au pixel près, à la maquette tirée du PI1 (couleurs corrigées), hormis la ligne de version ; le jeu démarre après Espace.
- Empreinte : `IK_PLUS_REF.TOS` = `c457539f4593793a993c093c5b8fa94f`.
- **Retour de la machine réelle** (essai 4) : validé sur STF, STE et Mega STE. Fusion dans `master`.

## 20. Mode STE quelle que soit la mémoire occupée au lancement

- **Constat** (Stéphane, Mega STE réel) : le jeu était plus lent que sur STE quand le Mega STE démarrait avec plusieurs accessoires et un bureau alternatif ; avec un démarrage propre, même vitesse que le STE.
- **Cause** : le chargeur ne choisissait le mode STE (son DMA, blitter) que si le bloc `Malloc` où il lit `IKPLUS.IMG` finissait sous `$C0000` : il posait le module STE en `$C0000` *avant* de recopier le jeu, et aurait écrasé une image lue à cet endroit. Avec la mémoire basse occupée, le bloc montait au-dessus, et le jeu partait en silence en mode STF. Le cookie `_MCH` (STE `$00010000`, Mega STE `$00010010`) et `phystop` (au moins 1 Mo) n'étaient pas en cause.
- **Correctif** (chargeur) : la condition sur la fin du bloc disparaît. La routine de recopie, posée après l'image lue, est suivie du module STE (bloc `Malloc` agrandi : `STUBSPACE` = 4 Ko). Elle recopie d'abord le jeu en `$700` (toujours vers le bas, sans risque) ; en mode STE, elle déplace ensuite sa fin et le module en `TAIL` = `$53800`, juste après l'image du jeu, et de là pose le module en `$C0000` et lance son `init`. Ainsi, ni la pose du module ni les sons rééchantillonnés (`$D0000`–`$EBE74`) ne peuvent écraser la routine en cours, où que soit le bloc lu. Seule condition restante sur le bloc : commencer au-dessus de `$10000` (toujours vrai).
- **Essais Hatari** : programme d'essai (hors dépôt) qui réserve 448 Ko ou 800 Ko de mémoire basse puis lance `IK_PLUS.TOS`. STE 1 Mo et 4 Mo, Mega STE 4 Mo : bloc lu jusqu'en `$D4A98` / `$12CAxx` ; ancien chargeur : accroches absentes (`$2064` = `13 C0 00 FF FA 23`), nouveau : accroches et module en place (`jsr $C0004`, `$C0000` = `60 00 01 1E`), partie à 3, turbo à 23,4 images/s. STF 1 Mo (avec et sans programme d'essai) et STE 512 Ko : jeu d'origine, comme avant.
- Empreinte : `IK_PLUS_REF.TOS` = `2ac168888f2a9be282b8520409a71fe8`.
- **Retour de la machine réelle** (essai 4) : validé sur STF, STE et Mega STE ; le Mega STE garde le mode STE avec accessoires et bureau alternatif. Fusion dans `master` (après le §19 : empreinte du chargeur avec les deux, `IK_PLUS_REF.TOS` = `a50580870c9f0534922c6f8b02400c18`).

## 21. Feu du joueur 3 : partie à 3 joueurs depuis la démo

- Demande de Stéphane : pendant la démo, le feu du joueur 1 lance une partie à 1, celui du joueur 2 une partie à 2 ; le feu du joueur 3 ne faisait rien.
- Le jeu teste le feu pendant la démo en `L_073B0` (`$1007` et `$1008` nuls) : `$126C` (joueur 1) → `L_07382`, puis `$126D` (joueur 2) → `L_0736C`. **Accroche 32** (`$73C4`) : `btst #4,$126d.w / bne.b L_0736C` → `jmp fire3` + NOP. `fire3` (`p3.s`, entrée `$848`, libre depuis le mode entraînement) teste le feu du joueur 2 comme avant, puis celui du joueur 3 (`$126E`, rempli à chaque VBL par `vblmap` selon son joystick) : il lance alors la partie à 3 comme F3 (`start3`, partagé avec `f3key` : `$1007`–`$1009` = 1, chronomètre à 0, `$135F` = 1). Rien si le joueur 3 est sur NONE. Comme pour les joueurs 1 et 2, pas de test de `$1006` (F1–F3 l'ont).
- `p3.s` : 972 octets sur 1 024.
- Essais Hatari (STF, TOS 1.04, émulation des joysticks par `runx.sh`, joueur 3 sur JOYSTICK 2) : feu du joueur 3 → partie à 3 (trois poings) ; feu du joueur 1 → partie à 1 ; feu du joueur 2 → partie à 2 ; joueur 3 sur NONE → son feu ne fait rien.
- `README.TXT` / `LISEZMOI.TXT` : mode 3 joueurs, feu du joueur 3 pendant la démo.
- Empreintes : `IK_PLUS/IKPLUS.IMG` = `8400e5ff1bbdc51e445debf7d909cb61`, `IK_STE_CHECK.IMG` = `5d6a0fa424d0dd333d99f339b6fce926`.
- **Retour de la machine réelle** (essai 5) : validé (feu du joueur 3 pendant la démo). Fusion dans `master` après le Falcon (§18), l'écran de chargement (§17), les dessins (§19) et le mode STE (§20) : 32 accroches ; `IKPLUS.IMG` identique à celui de l'essai 5. Empreintes : `IK_PLUS/IKPLUS.IMG` = `c37781546d8a0d30da69ffada25a2bf5`, `IK_PLUS_REF.TOS` = `2d8d92fd5dbe391febd66d4ff42c4f73` (inchangée), `IK_STE_CHECK.IMG` = `ceb320652984ac5858572e451c0ce28d`.

## 22. JOYTEST dans son propre dépôt

- À la demande de Stéphane, après la v1.1.0 : JOYTEST (`src/joytest.s`) quitte IK+ Reforged pour devenir un outil à part entière, [joystick-tester](https://github.com/stephane-perez/joystick-tester) (Makefile, intégration continue avec publication sur étiquette `v*`, README anglais et français, notes techniques `docs/fr/NOTES.md`, scripts Hatari). `JOYTEST.TOS` et `JOYTSTEN.TOS` y sont construits identiques à l'octet (`409a6a20a58231d018e19241b7feac34`, `324808fc4ba48e3561794939379ea1ce`).
- Ici : `src/joytest.s`, ses deux cibles du `Makefile` et ses fichiers dans l'intégration continue sont retirés ; les README renvoient vers le nouveau dépôt. Les sections ci-dessus (§7, §8, §12) gardent l'historique. Le jeu et le chargeur ne changent pas (`make check` inchangé).

## 23. Échap : retour à la page d'introduction pendant le jeu

- **Demande de Stéphane** : pendant la partie, Échap ramène la page d'introduction (choix des joysticks, mode entraînement). Choix non mémorisés dans `IKPLUS.CFG` (accepté : le TOS n'est plus là).
- **Échap est libre** : aucun test de `$01` dans `F_0708C` (touches, appelé par la VBL en `$1C20`/`$1C38`). **Accroche 11** (même place, `$7316`–`$733B`) : après F3 et F5, `cmpi.b #$01,(a1)` / `bne` / `jmp $6C000`, dans les 14 octets de `nop` libres.
- **Mémoire libre** : les derniers tampons du jeu sont `$63078`–`$6B077` (4 × 8 Ko, pointeurs en `$9FA4`–`$9FB0`) ; rien ne vise `$6B078`–`$6FFFF` dans le désassemblage. Vérifié aussi en mesure : `$53800`–`$6FFFF` rempli d'un motif au départ du jeu (`loadbin` au point d'arrêt `$1000`), puis relu après une partie à 3 de 290 s (combats et épreuve bonus), STF et STE : intact à partir de `$6AFD0`. Logo (`$1B678`) et police (`$9736`) intacts.
- **Module `src/esc.s`** (2,7 Ko, assemblé en `$6C000`) : posé par le chargeur, sur toutes les machines. La routine de recopie transporte maintenant le module Échap (et le module STE en mode STE) : après la recopie du jeu, sa fin et les modules passent en `TAIL` (`$53800`), puis le module Échap va en `$6C000` (`STUBSPACE` passe à 8 Ko ; bloc lu refusé sous `$10000`). Le chargeur écrit dans sa copie du module : manettes possibles, son DMA présent, blitter utilisé.
- **Déroulement** : `eschook` (dans la VBL) remplace l'adresse de retour de l'interruption (`$42(a7)` : celle que la VBL utilise en `$3E(a7)`, plus l'appel de `F_0708C`) par `escmain`, comme la pause du jeu (`$1C4C`). `escmain`, au niveau principal, interruptions coupées : blitter et son DMA arrêtés, volumes du YM à 0, écran `$70000`, palette et page dessinées comme dans le chargeur (logo et police du jeu, dessins `src/sides.i`), puis clavier lu directement sur l'ACIA (paquets de l'IKBD sautés). F1 à F4 modifient `CTL`/`TRAIN` (`$850`–`$853`) avec les mêmes règles que le chargeur. Espace : plus aucun humain, décor recopié dans les deux écrans (`F_02550`, sinon le haut de l'écran garde la page : la relance ne redessine que le bas), puis `$135F` = 1 : la VBL du jeu relance la partie (`P_014FA`) sur la démo.
- **Pièges rencontrés** : (1) avec le gestionnaire clavier du jeu, des touches se perdaient ; (2) en lecture directe, la première touche se perdait encore : une réponse d'interrogation des joysticks de l'IKBD (`$FD` + 2 octets) arrive pendant le dessin, l'ACIA (1 octet) déborde et ne garde que l'en-tête, dont les octets manquants étaient pris sur les touches suivantes. Correctif : l'ACIA est vidé jusqu'à un silence (~40–75 ms) après le dessin ; ensuite, plus d'interrogation (VBL du jeu coupée). (3) Dans `KEYS` de `run.sh`, Échap s'écrit `0x01`.
- **Essais Hatari** (image de la v1.1.0 avec la nouvelle accroche, chargeur neuf) : STF 512 Ko et 1 Mo, STE, Mega STE, Falcon (TOS 4.04, `--mmu on`) : Échap en plein combat → page ; F4 (vert), F2 (joueur 2 suivant) ; Espace → démo, décor propre ; F1 → partie en entraînement (« -- ») ; Échap une deuxième fois, Espace → démo. Échap pendant l'épreuve bonus A : page, puis démo. Après le retour, le feu du joueur 1 (`runx.sh`) lance bien une partie. Pendant les changements de manche, le jeu ignore toutes les touches, Échap compris (comportement d'origine).
- `scripts/setup-dev.sh` : installe aussi Xvfb et xdotool (`runx.sh`), et vérifie Pillow par `import PIL.Image` (un Pillow du système cassé s'importait sans erreur).
- Empreintes (calculées sur l'image de la v1.1.0 + l'accroche, ce que `make game` produit : `p3.s` et `p3b.s` inchangés ; à revérifier avec `IK+.PRG`) : `IK_PLUS/IKPLUS.IMG` = `be351fa7f5d013334608b5a8d497123e`, `IK_PLUS_REF.TOS` = `f2e4a712b5c1e172c1410ba0af35d600`, `IK_STE_CHECK.IMG` = `04799834dd1744a6400d8e2a5e399332`.


## 24. Essai 7 sur STE : HELP et ceintures après Échap

- **HELP remettait la vitesse à « normal »** (signalé par Stéphane, déjà dans le jeu d'origine) : la touche HELP (`$62`, `L_072AA`) et les mots tapés au clavier (`$139E`, table `$73EA`) mènent à `L_072E2`, qui affiche la couleur de la ceinture (`$1378` = `$FA`) mais écrit aussi `move.b #2,$100d.w` (`$7306`) avant d'afficher la vitesse (`F_0759E`). **Accroche 33** : ces 6 octets → 3 `nop` (comme l'accroche 25 en `$151E`). Hatari, STE : en turbo (F6), HELP affiche « WHITE'S BELT IS CURRENTLY WHITE » et la vitesse reste TURBO (`$100D` = 0 ; 2 avec l'essai 7).
- **Ceintures après Échap** (signalé : après Échap, une nouvelle partie garde l'ancienne couleur de ceinture) : la couleur des ceintures des joueurs 1 et 2 (`$101C`/`$101E`, `F_0B200`, table `$D25E`) se calcule sur leur score (`$11F2`, `$11F5`), et le jeu ne remet les scores à zéro qu'au début d'un round sans humain (`L_06BBA` : scores, « LV » `$11EB`, rounds avant l'épreuve bonus `$1269`). Le module Échap le fait maintenant lui-même avant la relance (Espace), sans dépendre du round de démo. **Non reproduit dans Hatari** avec l'essai 7 (score forcé à 9 500, ceinture noire ; Échap, Espace puis F1 jusqu'à 1 s après : scores à 0, ceinture blanche) : à juger sur la machine.
- **Clignotement au niveau des pieds (STE)** : réponses de Stéphane : aussi présent avec la v1.1.0 (sans rapport avec Échap), absent sur STF ; ligne noire, par intermittence, pas forcément sous les combattants, pas plus fréquente avec les joysticks. Propre au mode STE (blitter, son DMA) : pas encore corrigé.
- Empreintes (image de l'essai 7 + l'accroche 33 ; à revérifier avec `IK+.PRG`) : `IK_PLUS/IKPLUS.IMG` = `67fcd27cdfcfa60d98c4eb2ac840a18c`, `IK_PLUS_REF.TOS` = `43d5472991cbe18e0228b19e8ab649ef`, `IK_STE_CHECK.IMG` = `c73aa58f6f91c58741f8a7ac1e3c28aa`.

## 25. Ligne noire vers les pieds (STE) : clavier et raster

- **Essai 9** (diagnostic, hors dépôt) : STE sans blitter (9A) et STE sans son DMA (9B) : la ligne noire reste dans les deux. Absente sur STF, présente avec la v1.1.0.
- **Mesure** (Hatari, STE) : point d'arrêt sur l'écriture des couleurs de la ligne 190 (routine `$1B2E`, après la première écriture : `$1B36`), avec `HBL` et `LineCycles`. STF : toujours en HBL 253 (ligne 190), cycles 372–452, dans la bordure droite. STE : 12 % des écritures en HBL 254, cycles 4–208, au milieu de la ligne suivante, où les couleurs 1, 5 et 7 passent au noir avant la fin de la ligne. Mêmes retards avec 9A et 9B.
- **Cause** (`history on` / `history 40` au point d'arrêt) : à chaque retard, le gestionnaire de l'ACIA du clavier (`P_02492`, octets de l'IKBD : réponse à l'interrogation des joysticks) venait de commencer. Le MFP est en fin d'interruption automatique (VR = `$40` ; seuls Timer B et ACIA actifs) : Timer B est prioritaire dans le MFP, mais le 68000 reste au niveau 6 pendant tout le gestionnaire (~300 cycles). Sur STF, les octets de l'IKBD arrivent ailleurs dans l'image.
- **Accroche 34** (toutes machines) : en `$2492`, `movem.l d0-d2/a0-a2,-(a7) / clr.w $102c.w` → `move.w #$2500,sr / bra.w acia` ; `acia` (`p3b.s`, adresse fixe `$6A5A`) refait les deux instructions et revient en `$249A`. Le raster interrompt le gestionnaire du clavier ; la VBL (niveau 4) reste masquée. Retards : 12 % → 0,27 %.
- **Reste** (mode STE) : le blitter lancé à 2 lignes du raster partage le bus avec le gestionnaire du clavier, et `bwait` ne le met en pause qu'au retour. **Garde de `bwait` élargie** à 2 lignes (`$FFFA21` à 1 ou 2, `src/ste.s`) : 0 retard sur 3 286 interruptions. Vitesse inchangée (turbo, combat : 2,08 VBL par image, 24 images/s, avant comme après).
- Essais Hatari (STE, STF) : clavier, F1 à F10, HELP, Échap, combats ; seule la machine réelle juge la ligne.
- Empreintes (image de l'essai 8 + `p3b.s` neuf + accroche 34 ; à revérifier avec `IK+.PRG`) : `IK_PLUS/IKPLUS.IMG` = `c6aa495e52b83acd7a04727ae7a7324a`, `IK_PLUS_REF.TOS` = `c9dbbf0f2e5f998bc08c9869a70f2a30`, `IK_STE_CHECK.IMG` = `f06635988bd770f63fb4802eeb382b36`.
