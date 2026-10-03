"""ikimg.py : image mémoire d'IK+ à partir de IK+.PRG.

IK+.PRG est un programme TOS d'un seul fichier (344 516 octets). Son court
chargeur (176 octets) recopie le jeu en $1000-$537FF, puis 6 384 octets en
$78000 (image d'une piste de disquette, voir patch_game.py), et saute en
$1000. load() rend l'image du jeu telle qu'elle doit se trouver en mémoire,
de $700 à $537FF ($53100 octets, $700-$FFF à zéro) : c'est ce que lit notre
chargeur (src/loader.s), et ce que visent toutes les adresses des correctifs.
"""
import hashlib, struct

PRG_MD5 = '4107c876be9d49deb2a3cf5b390f70be'
BASE = 0x700
SIZE = 0x53100          # $700-$537FF
GAME = 0x1000           # le jeu commence en $1000...
TEXT_OFF = 0xB0         # ... à l'octet $B0 du segment texte du programme


def load(path):
    d = open(path, 'rb').read()
    if hashlib.md5(d).hexdigest() != PRG_MD5:
        raise SystemExit('%s : ce n\'est pas IK+.PRG (344 516 octets, MD5 %s)' % (path, PRG_MD5))
    magic, tlen = struct.unpack('>HI', d[:6])
    assert magic == 0x601A
    text = d[28:28 + tlen]
    img = bytearray(SIZE)
    n = SIZE - (GAME - BASE)
    img[GAME - BASE:] = text[TEXT_OFF:TEXT_OFF + n]
    return img
