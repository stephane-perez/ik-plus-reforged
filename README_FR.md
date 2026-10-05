# IK+ Reforged

*[English version](README.md)*

Correctifs et outils pour **International Karate +** (IK+) sur Atari ST :

- **compatibilité STE / Mega STE / TOS 2.06** : le jeu tourne désormais sur STF, STE et Mega STE (à 8 MHz) ;
- un **mode 3 joueurs simultanés** : le troisième joueur utilise un joystick branché sur un adaptateur du port parallèle ;
- des **ajouts STE**, posés automatiquement sur un STE ou un Mega STE avec au moins 1 Mo : bruitages joués par le DMA, combattants dessinés par le blitter, la vitesse turbo tient désormais 25 images par seconde ; manettes Jaguar sur les ports joystick étendus ;
- **un seul programme pour toutes les machines**, et le choix de la commande de chaque joueur ;
- un **nouveau chargeur** : une page d'introduction (logo IK+, contrôles), puis l'introduction du jeu ;
- **JOYTEST**, un petit utilitaire qui affiche l'état de tous les joysticks, y compris ceux du port parallèle et des ports étendus du STE.

> ## ⚠️ Avertissement
>
> *International Karate +* (IK+) © 1987–1988 System 3 / Archer Maclean. Ce projet **n'est ni affilié, ni approuvé, ni lié** à System 3 ou à un autre ayant droit.
>
> **Ce dépôt ne contient aucune partie du jeu** : ni programme, ni graphismes, ni musique, ni données, qu'ils soient d'origine ou modifiés. Il ne contient que du code source original et des outils. Ceux-ci modifient, **sur votre propre ordinateur**, une copie du jeu que **vous** fournissez. Vous seul êtes responsable de vous assurer que vous avez le droit d'utiliser cette copie, par exemple en possédant un original. Les outils n'acceptent qu'une version précise du jeu : `IK+.PRG`, un programme d'un seul fichier de 344 516 octets (MD5 `4107c876be9d49deb2a3cf5b390f70be`). Ce n'est **pas** le fichier de la disquette originale : sa protection anti-copie est déjà neutralisée, et Reforged saute entièrement la vérification. Aucune autre version ne fonctionnera.
>
> Les noms et marques cités appartiennent à leurs propriétaires respectifs. L'ensemble est fourni « tel quel », sans aucune garantie. Vous l'utilisez à vos risques, y compris sur une vraie machine.

## Fonctionnalités

### Compatibilité

| Machine / TOS | `IK+.PRG` | Reforged |
|---|---|---|
| STF / TOS 1.04 | fonctionne, avec une disquette dans le lecteur A | fonctionne |
| STF / TOS 2.06 | plante au démarrage | fonctionne |
| STE / TOS 1.62 | plante au démarrage | fonctionne (testé sur machine réelle) |
| Mega STE / TOS 2.06 | plante au démarrage | fonctionne (testé sur machine réelle) |

La colonne `IK+.PRG` a été vérifiée dans l'émulateur Hatari.

Ce qui a été corrigé :

- **Le générateur de nombres aléatoires du jeu** lisait la ROM du TOS 1.x en `$FC0000`. Cette adresse n'existe ni sur STE et Mega STE, ni avec le TOS 2.06 : chaque lecture provoquait une erreur de bus, et le jeu plantait ou redémarrait en boucle. Il lit maintenant des données graphiques en RAM. La modification tient en un octet.
- **La vérification de la disquette** : `IK+.PRG` la lance toujours au démarrage, puis attend l'arrêt du moteur du lecteur, qui n'arrive jamais sans disquette dans le lecteur. Reforged la saute.
- **Le nouveau chargeur** lit le jeu dans une zone mémoire réservée et le met en place sans risque. Sur Mega STE, il coupe les interruptions de la puce série (SCC) et passe en 8 MHz sans cache. Tous les vecteurs d'exception inutilisés pointent vers un endroit sûr. Avant le jeu, il affiche une page d'introduction : le logo IK+ et la police du jeu, tous deux pris dans votre copie du jeu, « REFORGED EDITION », le joystick de chaque joueur, le mode entraînement, « PRESS SPACE TO START » (puis « PLEASE WAIT »), « ENHANCED BY CLAUDE AI - 2026 » avec la version (`make TAG=…`, par défaut l'étiquette git), et « IN MEMORY OF ARCHER MACLEAN (1962-2022) ».
- **Mode entraînement** : **F4** sur la page d'introduction l'active (il n'est jamais mémorisé). Pendant une partie, le temps du round ne baisse plus et s'affiche « TIME: -- » ; une partie à 3 ne s'arrête plus au bout de 5 minutes. La démo et les épreuves bonus ne changent pas.

### Mode 3 joueurs

Le jeu a été conçu autour de trois combattants, et ses données avaient déjà une place pour un troisième joueur humain, jamais activée. Ce mode l'active.

- **F1**, **F2** et **F3** lancent une partie à 1, 2 ou 3 joueurs (ou le bouton de tir du joystick 1 ou 2, comme dans le jeu d'origine). Comme F1 et F2, F3 lance une nouvelle partie : les trois poings clignotent, et le joueur 3 prend le combattant **bleu**.
- **Tant que le joueur 3 est en jeu :**
  - personne n'est éliminé ;
  - l'arbitre annonce des résultats neutres (« X IS BEST / Y IS SECOND / Z IS WORST »…) ;
  - le match dure **5 minutes de combat**, puis l'arbitre annonce « MATCH OVER » et le jeu revient au menu.
- La musique se coupe et se remet avec **F5** (F3 dans le jeu d'origine). L'écran d'aide et les conseils de l'arbitre indiquent les nouvelles touches.
- Le joueur 3 participe aussi aux deux **épreuves bonus** (balles à renvoyer avec le bouclier, bombes à écarter), à tour de rôle avec les autres joueurs humains. Dans l'épreuve des bombes, la couleur de la veste du bleu sert aussi aux explosions : pendant son tour, elles sont bleues au lieu de rouges.
- Sans joueur 3, le jeu se joue comme l'original, à quelques changements près :
  - la vitesse choisie avec F6–F10 est gardée au début d'une nouvelle partie (l'original revenait à « normal ») ;
  - le bouton **reset** redémarre la machine au lieu de relancer le jeu ;
  - dans la barre du haut, les scores, barres de vie et poings du rouge et du bleu sont un peu décalés vers la gauche : le poing bleu ne touche plus « LV ».

Le joueur 3 utilise un **adaptateur joystick sur le port parallèle**, du type de ceux de *Gauntlet II*, *Leatherneck* ou *Dynabusters+* (prise joystick 3 : directions D4–D7, tir sur BUSY), ou une **manette Jaguar** sur un port joystick étendu du STE. Un seul dossier, `IK_PLUS`, sert sur toutes les machines.

**Choix des joysticks** : sur la page d'introduction, **F1**, **F2** et **F3** changent la commande des joueurs 1, 2 et 3. Choix possibles : JOYSTICK 0 (prise de la souris), JOYSTICK 1, JOYSTICK 2 et JOYSTICK 3 (prises 3 et 4 de l'adaptateur du port parallèle), JOYPAD A et JOYPAD B (manettes Jaguar sur les ports étendus du STE, proposées sur STE seulement), et NONE pour le joueur 3 (F3 ne peut alors pas lancer de partie à 3). Une commande ne sert jamais à deux joueurs. Le choix est mémorisé dans `IKPLUS.CFG`, à côté du jeu ; sur un disque protégé en écriture ou plein, rien n'est écrit et le jeu démarre quand même. Par défaut, le joueur 3 est sur JOYSTICK 2, ou JOYPAD A sur un STE.

### Ajouts STE

Sur un **STE ou un Mega STE avec au moins 1 Mo de mémoire**, le chargeur ajoute de lui-même ce qui suit (sur une autre machine, le jeu tourne sans).

- **Manettes Jaguar** sur les ports joystick étendus A et B du STE (les prises à 15 broches ; testées sur un vrai STE), ou joysticks ordinaires avec un adaptateur DB15 (non testé). Tir = A, B, C ou Pause. Plus besoin d'adaptateur sur le port parallèle. Les manettes sont proposées sur tout STE, même avec 512 Ko.
- **Les bruitages sont joués par le DMA**, à 12 517 Hz. L'original jouait chaque bruitage par la puce YM, avec une interruption par échantillon, ce qui prenait 13 à 18 % du processeur. Les 18 sons sont convertis au lancement du jeu, soit environ 2 secondes d'écran vert. La musique garde maintenant ses trois voix pendant les cris, et la hauteur des bruitages ne varie plus.
- **Les combattants sont dessinés et effacés par le blitter.** Le résultat est identique, octet par octet, au dessin d'origine : c'est vérifié dans l'émulateur sur plus de mille appels.

Mesures dans Hatari, pendant un combat :

| Version | Images par seconde, sans limite de vitesse | Turbo (F6) |
|---|---|---|
| Originale | 20,0 en moyenne | 22,5 en moyenne : 1 image sur 6 tombe à 16,7 ou 12,5 |
| Version STE | 25,5 en moyenne | **25 en permanence** |

Dans IK+, une image correspond à un pas du jeu : F6 à F10 fixent un nombre minimal de rafraîchissements d'écran par image. F6 (turbo) est donc limité à 25 images par seconde, et F8 (normal) à 10. Tourner à 50 images par seconde rendrait le jeu deux fois plus rapide que le turbo, sans le rendre plus fluide : ce n'est donc pas proposé.

### JOYTEST

`JOYTEST.TOS` (français) et `JOYTSTEN.TOS` (anglais) affichent en temps réel :

- les ports 0 et 1 du ST : les 8 directions et le bouton de tir ;
- le port parallèle : les directions lues sur D0–D3 et sur D4–D7, le tir sur BUSY et sur STROBE, et les 8 lignes de données brutes ;
- sur STE ou Falcon, les ports étendus A et B : les directions et les boutons A, B, C, Pause (P) et Option (O).

C'est pratique pour vérifier n'importe quel adaptateur. Une touche quelconque quitte le programme, et la souris est remise en service.

## Construction

### Construction automatique (GitHub Actions)

Chaque envoi (push) construit les chargeurs, le code 3 joueurs, le module STE et JOYTEST. Le résultat se télécharge depuis l'onglet **Actions**, sous le nom d'artefact `ik-plus-reforged`. Le jeu lui-même n'y est **jamais** construit, puisque le workflow n'a accès à aucun fichier du jeu.

### Construction manuelle

Prérequis : `make`, un compilateur C (pour construire l'assembleur vasm), `python3`, et `curl` ou `git`. Testé sous Linux ; ça devrait aussi fonctionner sous macOS et sous Windows avec WSL.

```sh
git clone https://github.com/stephane-perez/ik-plus-reforged
cd ik-plus-reforged
make                                  # chargeurs, code 3 joueurs, module STE, JOYTEST
make game PRG=/chemin/vers/IK+.PRG    # corrige VOTRE copie du jeu
make check                            # vérifie le résultat
```

Au premier lancement, `make` construit l'assembleur [vasm](http://sun.hasenbraten.de/vasm/) dans `.tools/`, sauf si `vasmm68k_mot` est déjà installé.

**Le fichier à fournir** : `IK+.PRG`, le jeu en un seul programme (344 516 octets, MD5 `4107c876be9d49deb2a3cf5b390f70be`). Les outils refusent tout autre fichier.

**Le résultat** : `build/IK_PLUS/` contient `IK_PLUS.TOS` (le chargeur), `IKPLUS.IMG` (le jeu corrigé), et `README.TXT` / `LISEZMOI.TXT`, qui listent toutes les différences avec le jeu d'origine (tirés de `dist/`, convertis pour l'Atari par `tools/textfile.py`). Copiez le dossier sur une disquette ou un disque dur, puis lancez `IK_PLUS.TOS`. Sur un STE ou un Mega STE avec au moins 1 Mo, le chargeur pose les 9 accroches STE (table `build/stehooks.i`, tirée de `tools/patch_ste.py`) après avoir vérifié leurs octets d'origine. Avec les réglages par défaut, `make check` compare le résultat aux empreintes attendues (`IK_STE_CHECK.IMG` est l'image telle que le chargeur la corrige sur un STE : ses accroches STE sont celles de la version STE validée sur machine réelle) :

| Fichier | MD5 |
|---|---|
| `IK_PLUS/IKPLUS.IMG` | `d4b04662410edecebb08ecd4babaf052` |
| `IK_PLUS_REF.TOS` (le chargeur avec le texte de version `V0.0.0`) | `579567695ab7465149d96149eed7e7dd` |
| `IK_STE_CHECK.IMG` (contrôle) | `648aa93950588c2da491ef0b1b912980` |

**Option** : `make game LIMIT=180 PRG=…` règle la durée d'un match à trois, en secondes de combat (300 par défaut). `make check` ne s'applique qu'à la valeur par défaut.

## Tester dans Hatari (facultatif)

Le dossier `hatari/` contient les scripts utilisés pendant le développement. Vous fournissez les images ROM du TOS, qui ne sont pas incluses.

- `run.sh` : un lancement sans affichage, avec une capture d'écran par seconde.
- `runx.sh` : un lancement sur un écran virtuel (Xvfb + xdotool), pour que les appuis de touches simulés passent par l'émulation des joysticks de Hatari, y compris ceux du port parallèle. Voir `example_3players.keys`.

Attention : Hatari 2.4.1 est plus permissif que la vraie machine sur le port parallèle. Il ignore le sens du port réglé par le registre 7 du PSG. Voir les notes techniques.

## Fonctionnement

- `src/loader.s` : le chargeur, qui lit `IKPLUS.IMG` et lance le jeu. Assemblé avec `-DSTE`, il charge aussi le module STE.
- `src/p3.s` : le code du mode 3 joueurs, placé en `$800` dans une zone mémoire inutilisée.
- `src/ste.s` : le module STE (son DMA, blitter), placé en `$C0000`, au-dessus des 512 Ko prévus par le jeu.
- `tools/ikimg.py` : tire l'image mémoire du jeu de `IK+.PRG`.
- `tools/patch_game.py`, `tools/patch_p3.py` et `tools/patch_ste.py` : appliquent les correctifs. Avant de modifier le moindre octet, ils vérifient l'empreinte et les octets d'origine.
- `src/joytest.s` : JOYTEST.
- `tools/trace_ik.py` et `tools/show.py` : un désassembleur récursif et un visualiseur de listing, pour l'étude. Ils nécessitent `pip install capstone`.
- `docs/fr/` : les notes techniques (méthodologie, carte du code, historique des versions).

Les commentaires du code, les messages des outils et les notes techniques sont en français.

## Crédits

- *International Karate +* : Archer Maclean (1962–2022), System 3.
- [vasm](http://sun.hasenbraten.de/vasm/) : Volker Barthelmann et Frank Wille.
- [Hatari](https://hatari.tuxfamily.org/) : l'émulateur Atari ST utilisé pour les tests.
- [Capstone](https://www.capstone-engine.org/) : le moteur de désassemblage.

## Licence

Le code original et la documentation de ce dépôt sont publiés sous [licence MIT](LICENSE). Cette licence ne couvre en aucun cas IK+.
