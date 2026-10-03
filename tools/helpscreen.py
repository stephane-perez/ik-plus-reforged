"""helpscreen.py : retouche l'écran d'aide du jeu (liste des touches).

L'écran d'aide est une image 320 x 200 en 16 couleurs, rangée telle quelle
dans le jeu en $19DA0 (format de l'écran : 4 plans entrelacés, 160 octets par
ligne). Le texte y est écrit dans une petite police : cases de 6 x 5 pixels,
une ligne de texte toutes les 6 lignes (F1 en y = 49), première case en x = 88.
Les couleurs 8 à 15 du texte font un dégradé que le jeu anime en changeant
la palette.

Lignes changées (F3 lance maintenant une partie à 3 joueurs, la musique
passe sur F5) :
  « F3 ..... MUSIC ON/OFF »      ->  « F3 ..... 3 PLAYER GAME »
  « F4 ..... SOUND FX ON/OFF »   ->  « F4/F5 .. FX/MUSIC ON/OFF »

Les lettres sont prises dans l'image elle-même (aucun dessin du jeu dans le
dépôt) ; seul le « 5 », absent de l'écran, est dessiné ici. Chaque pixel
nouveau prend la couleur du pixel de texte d'origine le plus proche, pour
garder le dégradé.
"""
import hashlib

SCREEN = 0x19DA0                # adresse de l'image dans le jeu
X0, Y0 = 88, 49                 # première case de la première ligne
CW, LH = 6, 6                   # largeur d'une case, hauteur d'une ligne

# texte d'origine des lignes utilisées comme modèle (une lettre par case,
# « . » = case des points de suite)
SOURCES = {
    0: 'F1..... 1 PLAYER GAME',
    2: 'F3..... MUSIC ON/OFF',
    3: 'F4..... SOUND FX',
}
NEW = {
    2: 'F3..... 3 PLAYER GAME',
    3: 'F4/F5.. FX/MUSIC ON/OFF',
}
FIVE = ['#####',
        '#....',
        '####.',
        '....#',
        '####.']
# empreinte des lignes 61 à 71 de l'image (lignes F3 et F4) avant correction
BAND = (61, 72)
BAND_MD5 = 'cf76a4d457e688d00ffb4957a16751de'


def getpix(d, a, x, y):
    o = a + y * 160 + (x >> 4) * 8
    bit = 15 - (x & 15)
    return sum(((int.from_bytes(d[o + 2 * p:o + 2 * p + 2], 'big') >> bit) & 1) << p
               for p in range(4))


def setpix(d, a, x, y, v):
    o = a + y * 160 + (x >> 4) * 8
    bit = 15 - (x & 15)
    for p in range(4):
        w = int.from_bytes(d[o + 2 * p:o + 2 * p + 2], 'big')
        w = (w | (1 << bit)) if (v >> p) & 1 else (w & ~(1 << bit))
        d[o + 2 * p:o + 2 * p + 2] = w.to_bytes(2, 'big')


def patch(d, base):
    a = SCREEN - base
    lo, hi = BAND
    band = bytes(d[a + lo * 160:a + hi * 160])
    assert hashlib.md5(band).hexdigest() == BAND_MD5, \
        'écran d\'aide : octets inattendus en $%x' % (SCREEN + lo * 160)

    # police : 5 x 5 pixels par lettre, prise dans les lignes d'origine
    font = {' ': [[0] * 5 for _ in range(5)],
            '5': [[c == '#' for c in r] for r in FIVE]}
    for line, text in SOURCES.items():
        for k, ch in enumerate(text):
            g = [[getpix(d, a, X0 + CW * k + i, Y0 + LH * line + j) >= 8 for i in range(5)]
                 for j in range(5)]
            if ch in font:
                assert font[ch] == g, 'écran d\'aide : lettre %r différente' % ch
            font[ch] = g

    for line, text in NEW.items():
        y0 = Y0 + LH * line
        # pixels de texte d'origine de la ligne : modèle des couleurs
        model = [(x, y, getpix(d, a, x, y)) for y in range(y0, y0 + 5)
                 for x in range(X0, X0 + CW * 25) if getpix(d, a, x, y) >= 8]
        for y in range(y0, y0 + 5):
            for x in range(X0, X0 + CW * 25):
                setpix(d, a, x, y, 0)
        for k, ch in enumerate(text):
            g = font[ch]
            for j in range(5):
                for i in range(5):
                    if g[j][i]:
                        x, y = X0 + CW * k + i, y0 + j
                        c = min(model, key=lambda m: (m[0] - x) ** 2 + 4 * (m[1] - y) ** 2)[2]
                        setpix(d, a, x, y, c)
