# IK+ — carte du code (joueurs, joysticks, IA, règles)

*Notes de travail, en français. Le tableau « Mode 3 joueurs » en fin de document décrit la première version (10 accroches, arrivée par le tir). La version actuelle (14 accroches, touche F3, port parallèle forcé en entrée) est décrite dans [VERSIONS.md](VERSIONS.md) et dans les commentaires de `src/p3.s` et `tools/patch_p3.py`.*

Image `ATOR.EXE` chargée en `$700`. Adresses absolues. Listing : `python3 tools/trace_ik.py ATOR.EXE` → `work/ik.lst` (tracé récursif : 43,6 Ko de code, 11 020 instructions, zone de code `$14E6`–`$12D40`). Extraits : `python3 tools/show.py <début> <fin>`.

Le vidage de la RAM pendant la démo, comparé à l'image, montre que **le code n'est ni décompressé ni modifié** à l'exécution. Ce qui change : les variables `$E64`–`$14E5` (dont la pile, qui part de `$F28`), des buffers et la fin de mémoire. `$704`–`$9xx` est l'ancien chargeur de boot, jamais exécuté (`$1000` : `jmp $14E6`). **`$800`–`$BFF` sert à loger le code du mode 3 joueurs.**

## Boucle principale et états

| Adresse | Rôle |
|---|---|
| `$1000` | `jmp $14E6` (initialisation) |
| `$1600` | Boucle principale : machine à états sur `$1076`. 1 = combat, 3 = démo, 4 = fin de partie et tableau des scores, 8 = retour au titre et au menu |
| `$14FA` / `$153C` | Reprise sur exception : vecteurs `$8`–`$3C`, puis `jmp $1600` |
| `$1BA6` | VBL (installée sur `$70`) ; en `$1DB2`, une seconde de chronomètre toutes les `$32` images |
| `$36B2` | Générateur aléatoire |
| `$B2B6` / `$B2D0` | Routine son : écrit le registre 7 du PSG (`$DC` / `$F8`, port B en sortie) |

## Entrées

- `$23EE` : installe le gestionnaire IKBD `$2492` sur `$118`, puis envoie `$15` (joystick en **mode interrogation**).
- `$2492` : assemble les paquets IKBD et les distribue par la table `$2464`.
- `$2516` : paquet `$FD` → **`$126C` = joystick du port 1, `$126D` = joystick du port 0**. Format : bits 0–3 = directions, **actives à 0** ; bit 4 = feu (actif à 1).
- **`$126E` n'est référencé nulle part** : c'est l'emplacement du 3ᵉ joystick.

## Joueurs et combattants

Tout est indexé par combattant, **i = 0 (blanc), 1 (rouge), 2 (bleu)**, et joueur i = combattant i.

| Variable | Rôle |
|---|---|
| `$1007`, `$1008`, `$1009` | Combattant i contrôlé par un humain. Dans l'original, `$1009` n'est jamais mis à 1, seulement effacé |
| `$126C + i` | État du joystick du joueur i |
| `$120F + i` | Commande du joueur (sortie de `F_07732`) |
| `$107E + i` / `$1081 + i` | Position x / orientation |
| `$11F2 + 3i` (2 octets) | Score |
| `$11FB` | Chronomètre du round, en BCD (`$30`) |
| `$11EB` | « LV » : numéro du round, en BCD |
| `$1093`–`$1095` | Classement du round : combattant 1ᵉʳ, 2ᵉ, 3ᵉ |
| `$1091` | Humains classés : bit 2 = 1ᵉʳ, bit 1 = 2ᵉ, bit 0 = 3ᵉ |
| `$1309` | Catégorie d'égalité (0, 7, 14, 21) + `$1091` |
| `$1092` / `$108F` | Message de fin de round / message affiché |

- **Menu (`$7316`–`$73CC`)** : F1 ou feu du port 1 → partie à 1 joueur ; F2 ou feu du port 0 → partie à 2 joueurs ; F3 = musique (remplacé par le joueur 3), F4 = bruitages.
- **`F_07732`** : lecture des humains, joueurs 0 puis 1 seulement dans l'original. « L'autre humain » vient de `eori.w #1,d2` (`$7772`) ; le combattant de l'ordinateur de la table `$786F` = [2,2,1].
- **`F_079FE`** : si `$1007[i]` est non nul → commande humaine ; sinon **IA**.
- **Poing « humain »** : `F_0765C(d2)` / `F_07680(d2)`, table `P_07644` à deux entrées seulement (positions `$28`, `$50` ; graphismes `$198C0`/`$198C8`, vide `$198D0`).

## Fin de round et élimination

- **`$6580`** : classement, puis `$1091`, `$1309`, et `$1092` = quartet haut de la table **`$64C4[$1309]`**.
- **`L_06872`** (toutes les fins de round) : le quartet bas de `$64C4[$1309]` est un **masque des humains qui restent** ; puis `clr.b $1009`. S'il ne reste plus personne, état 4.
- **`$6702`–`$67C4`** : règle supplémentaire (score du round < `$50`).
- **`L_067A6`** : « plus aucun humain » : message `$23`, état 8.
- La table `$64C4` n'a jamais prévu **trois** humains.

### Messages de l'arbitre (`$108F`)

| Code | Texte |
|---|---|
| `$06` | X WINS / Y AND Z ARE EQUAL SECOND PLACE |
| `$08` | X AND Y ARE EQUAL FIRST / Z MUST IMPROVE |
| `$09` | YOU ARE ALL OF EQUAL ABILITY: SO PLAY ON |
| `$0A` | X IS BEST / Y IS SECOND / Z IS WORST |
| `$0B` | PRESS F3 FOR MUSIC ON OR OFF… |
| `$11` | MATCH OVER |
| `$23` | IT SEEMS THAT WE HAVE A LIFELESS CROWD IN TODAY |

## Mode 3 joueurs — première version

| Accroche | Remplace | Rôle |
|---|---|---|
| `$7732` → `pre` | `clr.w d0/d1/d2` | Lit l'adaptateur et écrit `$126E` ; synchronise le poing bleu |
| `$7850` → `looptail` | fin de boucle de `F_07732` | Joueurs 0 à 2 |
| `$7772` → `other` | `eori.w #1,d2` | Autre humain = [1,0,0][i] |
| `$7782` | `lea $786C / move.b (a0,d2.w),d1` | `move.w d7,d1` |
| `$66E4` → `elim` | `cmpi.b #6,$1092.w` | Avec joueur 3 : pas de règle supplémentaire |
| `$6872` → `roundend` | `move.b #$32,$11ED.w` | Avec joueur 3 : tout le monde reste ; fin après LIMIT secondes avec « MATCH OVER » |
| `$662C` → `roundmsg` | `move.b d0,$1092.w / move.w #2,d2` | Avec joueur 3 : message neutre (`$0A`, `$06`, `$08`, `$09`) |
| `$1DCC` → `tick` | `move.b #$32,$125B.w` | Compteur de secondes de combat |
| `$7680` / `$765C` | entrées de `F_07680` / `F_0765C` | Poing bleu (`$78`) |
