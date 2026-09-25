"""patch_game.py <ATOR.EXE d'origine> <sortie>

ATOR.EXE est l'image mémoire du jeu, chargée en $700 par BLADERUN.DT1.

Correctif STE / Mega STE / TOS 2.06 : le générateur aléatoire du jeu ($36B2)
lit des mots dans la ROM du TOS 1.x, à (a0,d0.w) et (a0,d3.w) avec
a0 = $FC0000. Sur STE et Mega STE, le TOS est en $E00000 et $FC0000 n'existe
pas : erreur de bus, que le gestionnaire du jeu ($14FA) traite en relançant
la partie ($1600). Résultat : démo cassée, message « BUM COPY », puis
plantage sur Mega STE.

On remplace   lea $FC0000.l,a0   (41F9 00FC 0000, en $36D2)
par           lea $030000.l,a0   (41F9 0003 0000)
La fenêtre lue ($28000-$37FFE, index sur 16 bits signés) tombe dans les
graphismes du jeu, présents en RAM sur toutes les machines.
C'est le seul accès du jeu à la ROM (recherche de toutes les adresses
absolues $FC0000-$FEFFFF dans les instructions de l'image).
"""
import sys, hashlib

BASE = 0x700


def main(src, dst):
    d = bytearray(open(src, 'rb').read())
    assert hashlib.md5(d).hexdigest() == 'd76da60c6cd7d9f6ce42630b1271d8d7', 'ATOR.EXE inattendu'
    o = 0x36D2 - BASE
    assert d[o:o + 6] == bytes.fromhex('41f900fc0000')
    d[o:o + 6] = bytes.fromhex('41f900030000')
    open(dst, 'wb').write(d)
    print('%s : lea $FC0000 -> lea $030000 en $36D2' % dst)


if __name__ == '__main__':
    main(*sys.argv[1:3])
