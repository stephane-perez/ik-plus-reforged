"""sides.py <dessin.PI1> <sortie.i> : dessins de la page d'introduction.

Tire de l'écran Degas de Stéphane (IKPLUS2.PI1, basse résolution) les deux
dessins posés de part et d'autre du logo IK+ par le chargeur : « REFORGED »
à gauche, « EDITION » à droite. Le fichier PI1 contient aussi le logo du
jeu : il reste hors du dépôt (../ikplus-local/) ; seule la sortie, qui ne
contient que les deux dessins, est dans le dépôt (src/sides.i).

Couleurs : la palette du PI1 est d'un cran plus sombre que celle du
chargeur (conversion PNG -> PI1) ; chaque couleur est remontée d'un cran
puis cherchée dans la palette du chargeur (`pal` dans src/loader.s), qui
ne change pas.

Sortie : deux blocs de SIDEH lignes au format de l'écran (4 plans entrelacés
par groupe de 16 pixels), que le chargeur pose avec un masque (le noir du
dessin ne touche pas l'écran) :
  sidel : x = 0 à 95 (6 groupes), sider : x = 240 à 319 (5 groupes).
"""
import hashlib
import sys

MD5 = 'b42973810f1abce24c1b5523601727d8'
Y0, Y1 = 43, 61                 # lignes 43 à 60 : tout le dessin
LEFT = (0, 6, 83)               # x de départ, groupes, x de fin (exclu)
RIGHT = (240, 5, 320)
# palette du chargeur (src/loader.s, pal)
PAL = [0x000, 0x777, 0x750, 0x444, 0x070, 0, 0, 0,
       0, 0x300, 0x400, 0x500, 0x600, 0x700, 0x000, 0x666]


def up(v):
    """Couleur ST remontée d'un cran (composantes non nulles)."""
    return sum((min(7, c + 1) if c else 0) << s
               for s, c in ((s, (v >> s) & 7) for s in (8, 4, 0)))


def main(src, dst):
    d = open(src, 'rb').read()
    assert hashlib.md5(d).hexdigest() == MD5, 'empreinte inattendue : %s' % src
    assert len(d) >= 32034 and d[:2] == b'\0\0', 'pas un PI1 basse résolution'
    pal = [int.from_bytes(d[2 + 2 * i:4 + 2 * i], 'big') & 0x777 for i in range(16)]
    scr = d[34:34 + 32000]

    def pixel(x, y):
        o = y * 160 + (x // 16) * 8
        b = 15 - x % 16
        c = sum(((int.from_bytes(scr[o + 2 * p:o + 2 * p + 2], 'big') >> b) & 1) << p
                for p in range(4))
        if c == 0:
            return 0
        v = up(pal[c])
        assert v in PAL[1:], 'couleur $%03x absente de la palette du chargeur' % v
        return PAL.index(v, 1)

    # rien du dessin hors des deux blocs, dans la bande du logo
    for y in range(0, 107):
        for x in range(320):
            inside = Y0 <= y < Y1 and (LEFT[0] <= x < LEFT[2] or RIGHT[0] <= x < RIGHT[2])
            if not inside and (x < 80 or x >= 240):
                assert pixel(x, y) == 0, 'dessin hors des blocs en (%d,%d)' % (x, y)

    out = ['; généré par tools/sides.py : dessins « REFORGED » et « EDITION »',
           '; (Stéphane), de part et d\'autre du logo, lignes %d à %d' % (Y0, Y1 - 1),
           'SIDEY       equ     %d' % Y0,
           'SIDEH       equ     %d' % (Y1 - Y0)]
    for name, (x0, ng, x1) in (('sidel', LEFT), ('sider', RIGHT)):
        out.append('%-11s equ     %d' % (name.upper() + 'W', ng))
        out.append(name)
        for y in range(Y0, Y1):
            words = []
            for g in range(ng):
                cols = [pixel(x0 + g * 16 + b, y) if x0 + g * 16 + b < x1 else 0
                        for b in range(16)]
                for p in range(4):
                    words.append(sum(((c >> p) & 1) << (15 - b) for b, c in enumerate(cols)))
            out.append('            dc.w    ' + ','.join('$%04x' % w for w in words))
    open(dst, 'w').write('\n'.join(out) + '\n')
    print('%s : 2 dessins, %d lignes' % (dst, Y1 - Y0))


if __name__ == '__main__':
    main(*sys.argv[1:3])
