# Feuille de route

Chaque point peut devenir un ticket GitHub. Ordre proposé.

Machines visées : les machines de base, STF, STE et Mega STE. Les cartes
accélératrices ne sont pas prises en charge.

## 1. Version STE sur machine réelle : fait

Validée sur STE (affichage, manette Jaguar, bruitages, turbo) : étiquette
`v1.0.6`, puis `v1.0.7` (jeu tiré de `IK+.PRG`).

## 2. Mega STE dans le même dossier

- Accepter `_MCH` = `$00010010` ; joueur 3 sur l'adaptateur parallèle
  (pas de ports étendus : ne jamais lire `$FF9202`) ; son DMA et Microwire
  identiques au STE ; blitter (toujours présent).
- Étudier le 16 MHz avec cache (aujourd'hui le chargeur force 8 MHz) : la
  version STE n'a plus le code qui se modifie lui-même (lecteur Timer C),
  mais la boucle d'attente du raster est calée pour 8 MHz.

## 3. Falcon030 : essai exploratoire

D'abord : le jeu d'origine tourne-t-il dans Hatari en mode Falcon (vidéo
compatible ST, rasters) ? Points connus : ports étendus présents, son DMA
compatible mais pas de Microwire, caches du 68030, blitter à laisser éteint.
Ne rien promettre avant cet essai.

## 4. Idées en attente

- 4ᵉ joueur par rotation : 4 manettes, 3 combattants ; le dernier du round
  cède sa place à celui qui attend (scores par joueur à sauvegarder).
  Un vrai 4ᵉ combattant à l'écran est hors de portée (tout le jeu est prévu
  pour 3).
- Accélérer les textes 8×8 (`F_084C0`, environ 7 % d'une image) en ne les
  redessinant qu'en cas de changement.
- Variantes de hauteur des bruitages (le jeu d'origine les faisait varier de ±5 %).
