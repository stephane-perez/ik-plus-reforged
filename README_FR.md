# IK+ Reforged

*[English version](README.md)*

Correctifs et outils pour **International Karate +** (IK+) sur Atari ST :

- **compatibilité STE / Mega STE / TOS 2.06** : le jeu tourne désormais sur STF, STE et Mega STE, à 8 et 16 MHz ;
- un **mode 3 joueurs simultanés** : le troisième joueur utilise un joystick branché sur un adaptateur du port parallèle ;
- une **version STE** : joueur 3 sur le port joystick étendu du STE, bruitages joués par le DMA, combattants dessinés par le blitter ; la vitesse turbo tient désormais 25 images par seconde ;
- un **nouveau chargeur**, sans intro, qui lance directement le jeu ;
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
- **Le nouveau chargeur** lit le jeu dans une zone mémoire réservée et le met en place sans risque. Sur Mega STE, il coupe les interruptions de la puce série (SCC) et passe en 8 MHz sans cache. Tous les vecteurs d'exception inutilisés pointent vers un endroit sûr.

### Mode 3 joueurs

Le jeu a été conçu autour de trois combattants, et ses données avaient déjà une place pour un troisième joueur humain, jamais activée. Ce mode l'active.

- Lancez une partie comme d'habitude : **F1** ou **F2**, ou le bouton de tir du joystick 1 ou 2.
- Pendant la partie, **F3** donne le combattant **bleu** au joueur 3, et un poing apparaît à côté du score bleu. Un nouvel appui sur **F3** rend le bleu à l'ordinateur.
- **Tant que le joueur 3 est en jeu :**
  - personne n'est éliminé ;
  - l'arbitre annonce des résultats neutres (« X IS BEST / Y IS SECOND / Z IS WORST »…) ;
  - le match dure **5 minutes de combat**, puis l'arbitre annonce « MATCH OVER » et le jeu revient au menu.
- F3 ne gère plus la musique, qui reste toujours active. L'écran d'aide affiche encore « F3 MUSIC ON/OFF », car c'est une image.
- Le joueur 3 participe aussi aux deux **épreuves bonus** (balles à renvoyer avec le bouclier, bombes à écarter), à tour de rôle avec les autres joueurs humains. Dans l'épreuve des bombes, la couleur de la veste du bleu sert aussi aux explosions : pendant son tour, elles sont bleues au lieu de rouges.
- Sans joueur 3, le jeu se comporte exactement comme l'original.

Le joueur 3 utilise un **adaptateur joystick sur le port parallèle**, du type de ceux de *Gauntlet II*, *Leatherneck* ou *Dynabusters+*. Deux dossiers sont produits :

| Dossier | Machines | Joueur 3 | En plus |
|---|---|---|---|
| `IK3J_PAR` | STF, STE, Mega STE | adaptateur du port parallèle, prise joystick 3 (directions D4–D7, tir sur BUSY) | — |
| `IK3J_STE` | STE avec au moins 1 Mo | manette Jaguar sur le port joystick étendu A | son DMA, blitter (voir plus bas) |

La prise joystick 4 de l'adaptateur n'est pas prise en charge.

### Version STE

Le dossier `IK3J_STE` est réservé au **STE, avec au moins 1 Mo de mémoire**. Sur une autre machine, le chargeur affiche un message et s'arrête. On y retrouve le même mode 3 joueurs, avec trois différences :

- **Le joueur 3 utilise le port joystick étendu A du STE** (la prise à 15 broches) : une manette Jaguar (testée sur un vrai STE), ou un joystick ordinaire avec un adaptateur DB15 (non testé). Tir = A, B, C ou Pause. Plus besoin d'adaptateur sur le port parallèle.
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

**Le résultat** : `build/IK3J_PAR/` et `build/IK3J_STE/` contiennent chacun `IK_PLUS.TOS` (le chargeur) et `IKPLUS.IMG` (le jeu corrigé). Copiez le dossier voulu sur une disquette ou un disque dur, puis lancez `IK_PLUS.TOS` : `IK3J_PAR` avec un adaptateur parallèle (tout ST), ou `IK3J_STE` avec une manette Jaguar sur un STE. Avec les réglages par défaut, `make check` compare le résultat aux empreintes attendues :

| Fichier | MD5 |
|---|---|
| `IK3J_PAR/IKPLUS.IMG` | `15fb38453300c0700f3588928d6d4513` |
| `IK3J_PAR/IK_PLUS.TOS` | `2094db4eb20774ec27957cdff56751ad` |
| `IK3J_STE/IKPLUS.IMG` | `b56480f2eaa42f280ec4682f9cc8dc07` |
| `IK3J_STE/IK_PLUS.TOS` | `95fae0ec107d35232150d69da54b0250` |

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
