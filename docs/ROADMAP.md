# Feuille de route

Chaque point peut devenir un ticket GitHub. Ordre proposé.

## 1. Tester la version STE sur machine réelle

Sur le STE 4 Mo / TOS 1.62, avec `IK3J_STE` et le nouveau JOYTEST :
- manette ou joystick sur le port étendu A : directions, tir (A, B, C, Pause), F3 ;
- couleurs pendant les combats et les épreuves (pas de bande de mer grise,
  pas de pantalon noir, pas de restes de combattants) ;
- bruitages : présents, volume par rapport à la musique ;
- turbo (F6) régulier ;
- écran vert d'environ 2 s au lancement (conversion des sons) : normal.

Si c'est bon : fusionner la branche `ste` dans `main`, étiquette `v6`.

## 2. Réglage du blitter par `Blitmode(-1)`

Demande d'un utilisateur : sur certaines cartes accélératrices (68030,
DFB1X), le blitter n'apporte rien et fait planter la machine.
- Le chargeur lit `Blitmode(-1)` (XBIOS 64) : blitter utilisé seulement si
  présent (bit 1) et activé dans le bureau (bit 0, option « Blitter »).
- Sans blitter : routines d'origine du jeu (passerelles `tr0`/`tr1`/`tr2`/`trr`
  déjà écrites pour le mode contrôle) ; `rasterw` ne touche plus `$FF8A3C`,
  et le délai de la boucle d'attente du raster doit rester celui d'origine
  (deux versions de l'entrée, chacune avec son délai).
- Le son DMA reste actif : c'est lui qui apporte l'essentiel du gain.
- Test : Hatari avec le blitter désactivé dans le bureau (menu Options,
  sauvegardé dans DESKTOP.INF).

## 3. Mega STE dans le même dossier

- Accepter `_MCH` = `$00010010` ; joueur 3 sur l'adaptateur parallèle
  (pas de ports étendus : ne jamais lire `$FF9202`) ; son DMA et Microwire
  identiques au STE ; blitter selon `Blitmode`.
- Étudier le 16 MHz avec cache (aujourd'hui le chargeur force 8 MHz) : la
  version STE n'a plus le code qui se modifie lui-même (lecteur Timer C),
  mais la boucle d'attente du raster est calée pour 8 MHz.

## 4. Falcon030 : essai exploratoire

D'abord : le jeu d'origine tourne-t-il dans Hatari en mode Falcon (vidéo
compatible ST, rasters) ? Points connus : ports étendus présents, son DMA
compatible mais pas de Microwire, caches du 68030, blitter à laisser éteint.
Ne rien promettre avant cet essai.

## 5. Idées en attente

- 4ᵉ joueur par rotation : 4 manettes, 3 combattants ; le dernier du round
  cède sa place à celui qui attend (scores par joueur à sauvegarder).
  Un vrai 4ᵉ combattant à l'écran est hors de portée (tout le jeu est prévu
  pour 3).
- Accélérer les textes 8×8 (`F_084C0`, environ 7 % d'une image) en ne les
  redessinant qu'en cas de changement.
- Variantes de hauteur des bruitages (le jeu d'origine les faisait varier de ±5 %).
