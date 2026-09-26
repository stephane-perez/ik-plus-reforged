"""patch_ste.py <ATOR.EXE avec le mode 3 joueurs> <sortie>

Version STE : relie le jeu au module src/ste.s, chargé en $C0000 par le
chargeur STE (IK_PLUS.TOS assemblé avec -DSTE).
Entrées fixes de ste.s : $C0000 init (appelé par le chargeur), $C0004 dmaplay,
$C0008 initspr, $C000C/$C0010/$C0014 dessin des combattants 0/1/2 au blitter,
$C0018 restore (effacement au blitter).
Chaque accroche vérifie les octets d'origine avant de les remplacer.
"""
import sys

BASE = 0x700
STE = 0xC0000


def main(src, dst, *opts):
    d = bytearray(open(src, 'rb').read())
    assert len(d) == 0x53100, 'taille inattendue'

    def put(addr, old_hex, new):
        o = addr - BASE
        old = bytes.fromhex(old_hex)
        assert len(new) == len(old), hex(addr)
        assert d[o:o + len(old)] == old, 'octets inattendus en $%x : %s' % (addr, d[o:o + len(old)].hex())
        d[o:o + len(old)] = new

    jsr = lambda a: bytes.fromhex('4eb9') + a.to_bytes(4, 'big')

    # 1. combat : lancement d'un bruitage par le Timer C ($2064-$20AE).
    #    move.b d0,$fffa23.l / lsl.w #2,d1  ->  jsr dmaplay / rts
    #    (d1 = numéro du son ; la suite, qui armait le Timer C, n'est plus exécutée)
    put(0x2064, '13c000fffa23' 'e549', jsr(STE + 4) + bytes.fromhex('4e75'))
    # 2. épreuves bonus : idem en $E36E-$E3B8, puis movem.l (a7)+ / rts en $E3BA
    #    move.b d2,$fffa23.l / lsl.w #2,d1  ->  jsr dmaplay / bra.s $E3BA
    put(0xE36E, '13c200fffa23' 'e549', jsr(STE + 4) + bytes.fromhex('6044'))

    jmp = lambda a: bytes.fromhex('4ef9') + a.to_bytes(4, 'big')
    if '--noblit' in opts:      # essais : son DMA seul, dessin d'origine
        open(dst, 'wb').write(d)
        print('%s : version STE sans blitter (essais)' % dst)
        return
    # 3. initialisation : jsr F_02570 (banques de sprites) -> jsr initspr
    put(0x2208, '4eb900002570', jsr(STE + 8))
    # 4-6. dessin des 3 combattants : clr.w d0 / suba.l a1,a1 / move.b $107x.w,d0
    #      (6 premiers octets) -> jmp drawf0/1/2
    put(0x9C5C, '424093c91038', jmp(STE + 0x0C))
    put(0x9D70, '424093c91038', jmp(STE + 0x10))
    put(0x9E90, '424093c91038', jmp(STE + 0x14))
    # 7. effacement : movea.l $103a.w,a3 / clr.w d3 -> jmp restore
    put(0xD6C4, '2678103a4243', jmp(STE + 0x18))

    # 8. raster (Timer B) : movem.l d0/a0-a1,-(a7) / lea $19aa.l,a0 -> jmp rasterw
    #    (met le blitter en pause) ; attente move.w #$11,d0 -> #$0e en $194A (40 cycles de moins)
    put(0x1934, '48e780c0' '41f9000019aa', jmp(STE + 0x1C) + bytes.fromhex('4e714e71'))
    put(0x194A, '303c0011', bytes.fromhex('303c000e'))

    open(dst, 'wb').write(d)
    print('%s : version STE, 9 accroches (son DMA, blitter)' % dst)


if __name__ == '__main__':
    main(*sys.argv[1:])
