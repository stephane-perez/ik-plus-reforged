"""textfile.py <source> <sortie> : fichier texte pour l'Atari.

Le texte du dépôt (UTF-8) est recopié avec des fins de ligne CR LF et le jeu
de caractères de l'Atari ST (le code page 437, sauf quelques lettres comme
« À » et « œ », table ATARI) ; apostrophes et tirets
typographiques -> ASCII.
"""
import sys

# lettres placées ailleurs que dans le code page 437 sur l'Atari ST
ATARI = {'À': 0xB6, 'Ã': 0xB7, 'Õ': 0xB8, 'ã': 0xB0, 'õ': 0xB1, 'Ø': 0xB2,
         'ø': 0xB3, 'œ': 0xB4, 'Œ': 0xB5}
SUBST = {'’': "'", '‘': "'", '“': '"', '”': '"',
         '–': '-', '—': '-', '…': '...', ' ': ' '}


def main(src, dst):
    t = open(src, encoding='utf-8').read()
    for a, b in SUBST.items():
        t = t.replace(a, b)
    t = t.replace('\r\n', '\n').replace('\n', '\r\n')
    data = b''.join(bytes([ATARI[c]]) if c in ATARI else c.encode('cp437') for c in t)
    open(dst, 'wb').write(data)


if __name__ == '__main__':
    main(*sys.argv[1:3])
