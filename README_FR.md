# IK+ Reforged

*[English version](README.md)*

Correctifs et outils pour **International Karate +** (IK+) sur Atari ST :

- **compatibilité STE / Mega STE / TOS 2.06** : le jeu tourne désormais sur STF, STE et Mega STE, à 8 et 16 MHz ;
- un **mode 3 joueurs simultanés** : le troisième joueur utilise un joystick branché sur un adaptateur du port parallèle ;
- un **nouveau chargeur**, sans intro, qui lance directement le jeu ;
- **JOYTEST**, un petit utilitaire qui affiche l'état de tous les joysticks, y compris ceux du port parallèle.

> ## ⚠️ Avertissement
>
> *International Karate +* (IK+) © 1987–1988 System 3 / Archer Maclean. Ce projet **n'est ni affilié, ni approuvé, ni lié** à System 3 ou à un autre ayant droit.
>
> **Ce dépôt ne contient aucune partie du jeu** : ni programme, ni graphismes, ni musique, ni données, qu'ils soient d'origine ou modifiés. Il ne contient que du code source original et des outils. Ceux-ci modifient, **sur votre propre ordinateur**, une copie du jeu que **vous** fournissez. Vous seul êtes responsable de vous assurer que vous avez le droit d'utiliser cette copie, par exemple en possédant un original.
>
> Les noms et marques cités appartiennent à leurs propriétaires respectifs. L'ensemble est fourni « tel quel », sans aucune garantie. Vous l'utilisez à vos risques, y compris sur une vraie machine.

## Fonctionnalités

### Compatibilité

| Machine / TOS | Original | Reforged |
|---|---|---|
| STF / TOS 1.04 | fonctionne | fonctionne |
| STF / TOS 2.06 | l'intro plante | fonctionne |
| STE / TOS 1.62 | la démo redémarre sans fin, « BUM COPY » | fonctionne (testé sur machine réelle) |
| Mega STE / TOS 2.06 | plante au démarrage | fonctionne (testé sur machine réelle) |

Ce qui a été corrigé :

- **Le générateur de nombres aléatoires du jeu** lisait la ROM du TOS 1.x en `$FC0000`. Cette adresse n'existe pas sur STE et Mega STE : chaque lecture provoquait une erreur de bus, et le jeu redémarrait en boucle. Il lit maintenant des données graphiques en RAM. La modification tient en un octet.
- **L'intro** plaçait son lecteur de musique à une adresse fixe, sans réserver cette mémoire. Sous TOS 2.06, la mémoire était réutilisée et l'intro plantait. L'intro est supprimée.
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
- Sans joueur 3, le jeu se comporte exactement comme l'original.

Le joueur 3 utilise un **adaptateur joystick sur le port parallèle**, du type de ceux de *Gauntlet II*, *Leatherneck* ou *Dynabusters+*. Deux versions sont produites, une pour chaque prise de l'adaptateur :

| Dossier | Prise de l'adaptateur | Directions | Tir |
|---|---|---|---|
| `IK3J_S3` | joystick 3 | D4–D7 | BUSY |
| `IK3J_S4` | joystick 4 | D0–D3 | STROBE |

### JOYTEST

`JOYTEST.TOS` (français) et `JOYTSTEN.TOS` (anglais) affichent en temps réel :

- les ports 0 et 1 du ST : les 8 directions et le bouton de tir ;
- le port parallèle : les directions lues sur D0–D3 et sur D4–D7, le tir sur BUSY et sur STROBE, et les 8 lignes de données brutes.

C'est pratique pour vérifier n'importe quel adaptateur. Une touche quelconque quitte le programme, et la souris est remise en service.

## Construction

### Construction automatique (GitHub Actions)

Chaque envoi (push) construit le chargeur, le code 3 joueurs et JOYTEST. Le résultat se télécharge depuis l'onglet **Actions**, sous le nom d'artefact `ik-plus-reforged`. Le jeu lui-même n'y est **jamais** construit, puisque le workflow n'a accès à aucun fichier du jeu.

### Construction manuelle

Prérequis : `make`, un compilateur C (pour construire l'assembleur vasm), `python3`, et `curl` ou `git`. Testé sous Linux ; ça devrait aussi fonctionner sous macOS et sous Windows avec WSL.

```sh
git clone https://github.com/stephane-perez/ik-plus-reforged
cd ik-plus-reforged
make                                  # chargeur, code 3 joueurs, JOYTEST
make game ATOR=/chemin/vers/ATOR.EXE  # corrige VOTRE copie du jeu
make check                            # vérifie le résultat
```

Au premier lancement, `make` construit l'assembleur [vasm](http://sun.hasenbraten.de/vasm/) dans `.tools/`, sauf si `vasmm68k_mot` est déjà installé.

**Le fichier à fournir** : `ATOR.EXE`, l'image mémoire du jeu (340 224 octets, MD5 `d76da60c6cd7d9f6ce42630b1271d8d7`). Les outils refusent tout autre fichier.

**Le résultat** : `build/IK3J_S3/` et `build/IK3J_S4/` contiennent chacun `IK_PLUS.TOS` et le `ATOR.EXE` corrigé. Copiez le dossier qui correspond à la prise de votre adaptateur sur une disquette ou un disque dur, puis lancez `IK_PLUS.TOS`. Les autres fichiers de l'original ne servent plus. Avec les réglages par défaut, `make check` compare le résultat aux empreintes attendues :

| Fichier | MD5 |
|---|---|
| `IK3J_S3/ATOR.EXE` | `f5b9267d9eaec3f3e02d55d9b33a7e17` |
| `IK3J_S4/ATOR.EXE` | `5ebc2295d80d9c0e7e0d96bf61859cf4` |
| `IK_PLUS.TOS` | `0a89bb68ba0b62e122cc9d63670fe7fa` |

**Option** : `make game LIMIT=180 ATOR=…` règle la durée d'un match à trois, en secondes de combat (300 par défaut). `make check` ne s'applique qu'à la valeur par défaut.

## Tester dans Hatari (facultatif)

Le dossier `hatari/` contient les scripts utilisés pendant le développement. Vous fournissez les images ROM du TOS, qui ne sont pas incluses.

- `run.sh` : un lancement sans affichage, avec une capture d'écran par seconde.
- `runx.sh` : un lancement sur un écran virtuel (Xvfb + xdotool), pour que les appuis de touches simulés passent par l'émulation des joysticks de Hatari, y compris ceux du port parallèle. Voir `example_3players.keys`.

Attention : Hatari 2.4.1 est plus permissif que la vraie machine sur le port parallèle. Il ignore le sens du port réglé par le registre 7 du PSG. Voir les notes techniques.

## Fonctionnement

- `src/loader.s` : le chargeur, qui remplace l'intro et les anciens programmes de démarrage.
- `src/p3.s` : le code du mode 3 joueurs, placé en `$800` dans une zone mémoire inutilisée.
- `tools/patch_game.py` et `tools/patch_p3.py` : appliquent les correctifs. Avant de modifier le moindre octet, ils vérifient l'empreinte et les octets d'origine.
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
