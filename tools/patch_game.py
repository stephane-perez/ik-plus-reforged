"""patch_game.py <IK+.PRG> <sortie>

Fabrique l'image mémoire du jeu à partir de IK+.PRG (tools/ikimg.py), à
charger en $700 par notre chargeur (src/loader.s), et y applique deux
correctifs.

1. Correctif STE / Mega STE / TOS 2.06 : le générateur aléatoire du jeu
   ($36B2) lit des mots dans la ROM du TOS 1.x, à (a0,d0.w) et (a0,d3.w) avec
   a0 = $FC0000. Sur STE et Mega STE, le TOS est en $E00000 et $FC0000
   n'existe pas : erreur de bus, que le gestionnaire du jeu ($14FA) traite en
   relançant la partie ($1600). Résultat : démo cassée, message « BUM COPY »,
   puis plantage sur Mega STE.
   On remplace   lea $FC0000.l,a0   (41F9 00FC 0000, en $36D2)
   par           lea $030000.l,a0   (41F9 0003 0000)
   La fenêtre lue ($28000-$37FFE, index sur 16 bits signés) tombe dans les
   graphismes du jeu, présents en RAM sur toutes les machines. C'est le seul
   accès du jeu à la ROM (recherche de toutes les adresses absolues
   $FC0000-$FEFFFF dans les instructions de l'image).

2. Vérification de la disquette sautée : F_06A40 (appelée en $2202 à
   l'initialisation) programme le contrôleur de disquette, cherche en $78000
   un en-tête de secteur (A1 A1 FE) dont la taille vaut $F7, sinon efface la
   mémoire ($27A4), puis attend l'arrêt du moteur du lecteur. Dans IK+.PRG,
   les lectures sont déjà neutralisées et la piste attendue est fournie par
   le chargeur ; mais l'attente du moteur bloque le jeu sans disquette dans
   le lecteur. On garde l'entrée de la fonction (sauvegarde des registres)
   et on saute directement à sa fin ($6AF8), qui pose la valeur $3846 en
   $1030 puis rend les registres :
   move.b #7,$8800.w (11FC 0007 8800, en $6A44)  ->  bra.w $6AF8 / nop
"""
import sys
from ikimg import load, BASE


def main(src, dst):
    d = load(src)

    def put(addr, old_hex, new_hex):
        o = addr - BASE
        old, new = bytes.fromhex(old_hex), bytes.fromhex(new_hex)
        assert len(new) == len(old), hex(addr)
        assert d[o:o + len(old)] == old, 'octets inattendus en $%x : %s' % (addr, d[o:o + len(old)].hex())
        d[o:o + len(old)] = new

    put(0x36D2, '41f900fc0000', '41f900030000')
    disp = 0x6AF8 - (0x6A44 + 2)
    put(0x6A44, '11fc00078800', '6000%04x4e71' % disp)
    open(dst, 'wb').write(d)
    print('%s : image du jeu, lea $FC0000 -> $030000 en $36D2, vérification de la disquette sautée' % dst)


if __name__ == '__main__':
    main(*sys.argv[1:3])
