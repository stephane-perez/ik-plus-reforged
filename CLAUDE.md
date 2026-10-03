# IK+ Reforged — notes pour Claude

Lis ce fichier en entier avant toute modification. L'historique détaillé est
dans `docs/fr/VERSIONS.md`, la carte du jeu dans `docs/fr/CODE_MAP.md`, la
méthode dans `docs/fr/METHODOLOGIE.md`, la suite prévue dans `docs/ROADMAP.md`.

## Le projet

Correctifs pour *International Karate +* (Atari ST, System 3 / Archer
Maclean), à partir de `IK+.PRG` : le jeu en un seul programme, protection
déjà neutralisée, provenance inconnue (pas le fichier de la disquette
originale). `tools/ikimg.py` en tire l'image mémoire du jeu (`$700`–`$537FF`,
point d'entrée `$1000`) ; sur l'Atari, notre chargeur `IK_PLUS.TOS` lit
cette image corrigée, `IKPLUS.IMG`. Ne jamais citer de cracker ni de groupe
de crackers dans le projet.

- **v5, validée sur machine réelle** : tourne sur STF, STE, Mega STE,
  TOS 1.04 à 2.06 ; nouveau chargeur sans intro ; mode 3 joueurs
  simultanés (joueur 3 = bleu, sur un adaptateur joystick du port
  parallèle, type Gauntlet II / Leatherneck) ; F3 donne ou reprend le bleu ;
  pas d'élimination à 3 ; fin de match après 5 min de combat ; le joueur 3
  joue aussi les épreuves bonus. Dossier `IK3J_PAR` (ex-`IK3J_S3` : prise
  joystick 3 = D4–D7 + BUSY). La prise 4 n'est plus prise en charge (v6).
- **v6, version STE, validée sur STE réel** (garde du blitter, boutons de la
  manette lus avant les directions) : `IK3J_STE`, STE avec 1 Mo minimum ;
  joueur 3 = manette Jaguar sur le port joystick étendu A ;
  bruitages en DMA ; combattants dessinés au blitter ; turbo (F6) à
  25 images/s en permanence.
- **JOYTEST** : testeur de joysticks (ports ST, port parallèle, ports étendus
  STE/Falcon), français (`JOYTEST.TOS`) et anglais (`JOYTSTEN.TOS`, `-DENGLISH`).

Le propriétaire (Stéphane) teste sur **STE 4 Mo / TOS 1.62** et
**Mega STE / TOS 2.06**. Ce qu'on ne peut valider que sur la machine, on le
lui demande, avec une liste précise de choses à vérifier.

## Règles absolues

1. **Aucun contenu sous copyright dans le dépôt** : ni `IK+.PRG`, ni
   aucun fichier produit à partir du jeu (image corrigée, sons, captures
   d'écran), ni ROM TOS. Le `.gitignore` les exclut ; vérifie quand même
   avant chaque commit (`git status`, pas de `git add -A` à l'aveugle).
   Les outils modifient la copie du jeu **de l'utilisateur, chez lui**.
2. **Chaque correctif vérifie les octets d'origine** avant de les remplacer
   (`put(adresse, octets_attendus, nouveaux)` dans `tools/patch_*.py`) et
   l'empreinte MD5 du fichier d'entrée.
3. **Les versions existantes restent identiques à l'octet** : toute nouveauté
   passe par `ifd`/`-D...` ou par un nouveau fichier. `make check` compare les
   empreintes ; si une sortie change volontairement, mets à jour les MD5 dans
   le `Makefile`, `README.md`, `README_FR.md` et `docs/fr/VERSIONS.md`.
4. **Français** pour les commentaires, les messages des outils, les notes
   techniques (`docs/fr/`). `README.md` (anglais) et `README_FR.md` (français)
   ont le même contenu et gardent l'avertissement juridique.
5. Toujours tester dans Hatari avant de livrer, et dire clairement ce qui
   n'a été vérifié que dans l'émulateur.

## Reprendre le travail (nouvelle session)

Le code se fait ici, dans Claude Code : on travaille sur une branche, on
pousse, et on ouvre une PR décrite en français. La machine de la session est
temporaire : tout ce qui n'est pas poussé disparaît avec elle.

1. **Outils** : `scripts/setup-dev.sh` installe vasm, Hatari, capstone,
   Pillow et numpy. Sur le web, le hook `.claude/hooks/session-start.sh` le
   lance tout seul au début de chaque session (une fois fusionné dans
   `master`).
2. **Fichiers du jeu**, jamais dans le dépôt : Stéphane les envoie dans la
   conversation (ils arrivent dans `/root/.claude/uploads/<session>/`). Les
   ranger dans `../ikplus-local/` (à côté du dépôt, variable `IKPLUS_LOCAL`) :
   `IK+.PRG` et `rom/tos104.img` (STF), `rom/tos162.img` (STE),
   `rom/tos206.img` (Mega STE). Puis relancer `sh scripts/setup-dev.sh`,
   qui fait `make game` et `make check`.
3. **Où on en est** : la section « Le projet » ci-dessus, `docs/ROADMAP.md`
   et les tickets GitHub ouverts ; l'historique dans `docs/fr/VERSIONS.md`.
4. **Étiquettes** : le proxy git des sessions refuse de pousser les
   étiquettes (`git push origin v6` → 403). Donner la commande à Stéphane.

## Construire

```sh
make                              # chargeurs, code 3 joueurs, module STE, JOYTEST
make game PRG=/chemin/IK+.PRG     # corrige la copie du jeu : build/IK3J_PAR, IK3J_STE
make check                        # empreintes attendues
```

`IK+.PRG` attendu : 344 516 octets, MD5 `4107c876be9d49deb2a3cf5b390f70be`.
L'assembleur est vasm (`vasmm68k_mot`), construit dans `.tools/` au besoin.
Listing du jeu pour l'étude : `python3 tools/trace_ik.py IK+.PRG` →
`work/ik.lst` (étiquettes `F_xxxxx` / `P_` / `L_`), extraits avec
`tools/show.py`.

Chaîne des correctifs : `patch_game.py` (image tirée de `IK+.PRG` ;
RNG lisant la ROM en `$FC0000`, cause du plantage STE ; vérification de la
disquette sautée en `$6A44`) → `patch_p3.py` (code `src/p3.s` en `$800` + 21
accroches) → pour le STE, `patch_ste.py` (9 accroches vers `src/ste.s`).

## Carte mémoire (à respecter)

| Zone | Usage |
|---|---|
| `$700`–`$537FF` | image du jeu (`$E64`–`$14E5` variables, pile depuis `$F28`) |
| `$800`–`$BFF` | code 3 joueurs (`p3.s`) : **1 Ko au total**, ~600 octets utilisés |
| `$70000` / `$78000` | les deux écrans |
| `$80000`–`$A37FF` | STE : sprites convertis pour le blitter |
| `$A7000`–`$BFFFF` | STE, mode contrôle (`-DCHECK`) seulement : copies de travail |
| `$C0000`–`$C0FFF` | STE : module `ste.s` (entrées fixes en `$C0000`, `$C0004`…) |
| `$D0000`–`$EBE74` | STE : sons rééchantillonnés |

Le jeu, écrit pour 512 Ko, n'utilise rien au-dessus de `$80000`. Le
chargeur STE exige un bloc `Malloc` qui finit sous `$C0000`.

## Tester dans Hatari (2.4.1)

Tu fournis les ROM TOS (pas dans le dépôt). Scripts dans `hatari/` :

- `run.sh <nom> <machine> <tos> <secondes>` : sans écran, captures dans
  `hatari/out/<nom>/`. Variables : `HD` (dossier monté en C:), `PRG`,
  `KEYS="20:59 22:59"` (touches ST à la seconde t ; F1 = 59, F2 = 60,
  F3 = 61, F6 = 64 ; `"t:!recsound"` = raccourci Hatari), `SHOTS` (captures
  par seconde). Démarrage du jeu au bout d'environ 15 s (20 s pour le STE,
  à cause de la conversion des sons).
- `runx.sh` : Xvfb + xdotool, pour passer par l'émulation des joysticks
  (configurations `joy3.cfg`, `joy4.cfg`, `joyall.cfg`, `joyste.cfg`).
- `hatari/measure/` (lancer depuis ce dossier, options `--parse …`) :
  - vitesse : `unlock.py` (copie du jeu sans limite de vitesse), `frames.dbg`
    puis `frames.py out/<nom>/log.txt` (images par seconde, par état du jeu) ;
  - profil : `profile.dbg` puis `profile.py profile.txt work/ik.lst [plages]` ;
  - couleurs : `glitch.py out/<nom>` (la mer doit rester bleue).
- **Contrôle octet par octet** des routines blitter : assembler `src/ste.s`
  avec `-DCHECK` (et `-DCHECKBONUS` pour les épreuves seulement) ; chaque
  appel exécute l'original puis la nouvelle routine et compare écran, cartes
  de collision et liste d'effacement. Les compteurs `chk_n`, `chk_bad`… sont
  à lire avec `m <adresse>` dans le débogueur (adresses dans le listing
  `vasm -L`). Ce mode masque les interruptions : couleurs fausses et jeu lent
  sont normaux.
- Épreuves bonus : avec 3 humains (F2 puis F3), épreuve A vers VBL 4 900,
  épreuve B vers VBL 10 800 (points d'arrêt `$DFA0`, `$EEC8`).

## Pièges déjà rencontrés

- **Hatari est plus permissif que la machine** : il ignore le bit 7 du
  registre 7 du PSG (sens du port parallèle) et fige la valeur lue au moment
  de la sélection d'un registre (lire deux fois). Valider aussi la
  configuration des registres, pas seulement les valeurs lues.
- Le TOS passe à `joyvec` un tampon de 3 octets (en-tête, joystick 0, joystick 1).
- Lire `$FF9202` sur une machine sans ports étendus (STF, Mega STE) peut
  provoquer une erreur de bus.
- **Ports étendus sur la machine réelle** : une lecture de `$FF9202`
  (directions) masque les boutons dans la lecture suivante de `$FF9200`
  (relu `$FFFF`). Toujours lire `$FF9200` juste après la sélection de la
  ligne, avant `$FF9202`. Hatari ne le reproduit pas (VERSIONS.md §12).
- **Blitter en mode partagé** : l'interruption raster (`$1934`) doit écrire le
  compteur suivant du Timer B en moins de 2 lignes → `rasterw` met le blitter
  en pause. Après une pause, le bit 7 se relit à 0 : la fin d'un travail se
  teste sur le compteur de lignes (`$FF8A38` = 0), jamais sur le bit 7.
- **Blitter et interruptions raster sur la machine réelle** : une interruption
  qui arrive pendant un paquet du blitter attend jusqu'à ~256 cycles, et
  Hatari ne reproduit pas tous les cas. `bwait` (seule façon de lancer le
  blitter) ne le lance jamais quand le Timer B est à 1 ligne de son
  interruption (`$FFFA21` = 1). Le dégradé du reflet (lignes 68–76, couleur
  10) est la zone la plus sensible. Mesure : points d'arrêt à l'entrée du
  gestionnaire avec `HBL` / `LineCycles` (VERSIONS.md §11).
- Le hasard du jeu (`F_036B2`) dépend du VBL et du faisceau : deux versions
  n'évoluent pas pareil. Pour comparer, préférer le mode contrôle.
- Dans IK+, une image = un pas du jeu (table de vitesse `$6EB8`) : plus
  d'images par seconde = jeu plus rapide, pas plus fluide.

## Façon de travailler

- Deux dossiers seulement : `IK3J_PAR` (tout ST, adaptateur parallèle) et
  `IK3J_STE` (STE, manette Jaguar). Un petit menu de choix au démarrage est
  envisagé plus tard.
- Une branche par sujet, une demande de fusion (PR) décrite en français ;
  on ne fusionne dans `master` qu'après le retour de la machine réelle.
- Mettre à jour `docs/fr/VERSIONS.md` (nouvelle section numérotée) et, si
  besoin, `CODE_MAP.md` à chaque version.
- Livrer à Stéphane un zip avec le dossier prêt à copier sur l'Atari et un
  `LISEZMOI.TXT` qui dit quoi vérifier. Ce zip contient le jeu corrigé :
  il se donne à lui seul, jamais dans le dépôt ni dans une release GitHub.
