# Feuille de route

Chaque point peut devenir un ticket GitHub. Ordre proposé.

Machines visées : les machines de base, STF, STE et Mega STE. Les cartes
accélératrices ne sont pas prises en charge.

## 1. Version STE sur machine réelle : fait

Validée sur STE (affichage, manette Jaguar, bruitages, turbo) : étiquette
`v1.0.6`, puis `v1.0.7` (jeu tiré de `IK+.PRG`).

## 2. Mega STE dans le même dossier : fait

Un seul dossier `IK_PLUS` depuis la v9 : le chargeur choisit le mode STE
sur un STE ou un Mega STE (8 MHz sans cache), validé sur machine réelle.

## 3. Falcon030 : fait

Validé sur machine réelle (VERSIONS.md §18) : 16 MHz, caches et MMU coupés,
ni son DMA ni blitter. En VGA, la musique va trop vite (écran pas à 50 Hz).
Les cartes accélératrices (CT60) ne sont pas prises en charge.

## 4. Échap, HELP, ligne noire du STE : fait (v1.1.1)

VERSIONS.md §23 à §25. Reste : `make check` avec `IK+.PRG` (empreintes
calculées sans lui) et un passage sur STF, Mega STE et Falcon réels.

## 5. Idées en attente

- 4ᵉ joueur par rotation : 4 manettes, 3 combattants ; le dernier du round
  cède sa place à celui qui attend (scores par joueur à sauvegarder).
  Un vrai 4ᵉ combattant à l'écran est hors de portée (tout le jeu est prévu
  pour 3).
- Accélérer les textes 8×8 (`F_084C0`, environ 7 % d'une image) en ne les
  redessinant qu'en cas de changement.
- Variantes de hauteur des bruitages (le jeu d'origine les faisait varier de ±5 %).
