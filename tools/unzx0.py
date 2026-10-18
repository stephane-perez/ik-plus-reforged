"""unzx0.py : décompresseur ZX0 de référence.

  unzx0.py <fichier.zx0>                       décompresse vers la sortie standard
  unzx0.py --check <fichier.zx0> <brut> <marge>
      vérifie que le fichier compressé redonne exactement <brut>, et qu'il se
      décompresse sur place comme le fait le chargeur : compressé lu à la fin
      d'un bloc de taille(<brut>) + <marge> octets (adresse ramenée à une
      adresse paire), décompressé vers le début du bloc, sans que l'écriture
      rattrape jamais la lecture.

Format ZX0 (Einar Saukas, https://github.com/einar-saukas/ZX0), mode normal
(non « classic »). Sert à vérifier, à la construction, que IKPLUS.IMG
compressé redonne bien l'image du jeu, et à valider la routine 68000 du
chargeur (src/loader.s, unzx0), écrite d'après la même description.

Utilisé comme module : unzx0(données, debut=None) -> octets ; debut = position
du compressé dans le bloc, pour la vérification sur place.
"""
import sys


def unzx0(src, debut=None):
    pos = 0
    bitbuf = 0
    mask = 0
    last = 0
    backtrack = False
    out = bytearray()

    def byte():
        nonlocal pos, last
        last = src[pos]
        pos += 1
        return last

    def bit():
        nonlocal mask, bitbuf, backtrack
        if backtrack:
            backtrack = False
            return last & 1
        mask >>= 1
        if mask == 0:
            mask = 128
            bitbuf = byte()
        return 1 if bitbuf & mask else 0

    def gamma(inv=0):
        v = 1
        while not bit():
            v = v << 1 | (bit() ^ inv)
        return v

    def put(b):
        # sur place : l'octet écrit ne doit pas écraser un octet encore à lire
        if debut is not None and len(out) >= debut + pos:
            raise ValueError('décompression sur place impossible (sortie %d, entrée %d)'
                             % (len(out), debut + pos))
        out.append(b)

    def copy(off, n):
        if off > len(out):
            raise ValueError('décalage invalide')
        for _ in range(n):
            put(out[-off])

    offset = 1
    state = 'lit'
    while True:
        if state == 'lit':
            for _ in range(gamma()):
                put(byte())
            if bit():
                state = 'new'
                continue
            copy(offset, gamma())
            state = 'new' if bit() else 'lit'
        else:
            msb = gamma(1)
            if msb == 256:
                if pos != len(src):
                    raise ValueError('données en trop après la fin')
                return bytes(out)
            offset = msb * 128 - (byte() >> 1)
            backtrack = True
            copy(offset, gamma() + 1)
            state = 'new' if bit() else 'lit'


if __name__ == '__main__':
    if sys.argv[1] == '--check':
        z = open(sys.argv[2], 'rb').read()
        raw = open(sys.argv[3], 'rb').read()
        debut = (len(raw) + int(sys.argv[4], 0) - len(z)) & ~1
        assert unzx0(z, debut) == raw, 'le compressé ne redonne pas %s' % sys.argv[3]
        print('%s : %d -> %d octets, décompression sur place vérifiée'
              % (sys.argv[2], len(raw), len(z)))
    else:
        sys.stdout.buffer.write(unzx0(open(sys.argv[1], 'rb').read()))
