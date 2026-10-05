"""patch_p3.py <image du jeu corrigée (patch_game.py)> <build/p3.bin> <sortie>

Pose le code du mode 3 joueurs (src/p3.s, assemblé en $800) dans l'image
du jeu et le relie par 27 accroches. Chaque accroche vérifie les octets
d'origine avant de les remplacer. Corrige aussi quelques réglages du jeu
(vitesse gardée, bouton reset, barre du haut, textes, écran d'aide).
Entrées fixes de p3.s : $800 pre, $804 looptail, $808 other, $80C elim,
$810 tick, $814 erasehook, $818 drawhook, $81C roundend, $820 roundmsg, $824 f3key,
$828 ikbdhook, $82C blinka, $830 blinkb, $834 f5key, $838 setp12, $83C blinkset,
$840 blinkvbl, $844 vblmap, $848 slashkey ; choix des joysticks (CTL) et
drapeau Mega STE en $84C (écrits par le chargeur).
"""
import sys, hashlib
import helpscreen

BASE = 0x700


def main(src, binf, dst):
    d = bytearray(open(src, 'rb').read())
    assert hashlib.md5(d).hexdigest() == 'a22b79cf08f33762e9013a997895442d', \
        'il faut l\'image du jeu produite par patch_game.py'
    code = open(binf, 'rb').read()
    assert len(code) <= 0xC00 - 0x800

    def put(addr, old_hex, new):
        o = addr - BASE
        old = bytes.fromhex(old_hex)
        assert len(new) == len(old), hex(addr)
        assert d[o:o + len(old)] == old, 'octets inattendus en $%x : %s' % (addr, d[o:o + len(old)].hex())
        d[o:o + len(old)] = new

    jsr = lambda a: bytes.fromhex('4eb9') + a.to_bytes(4, 'big')
    jmp = lambda a: bytes.fromhex('4ef9') + a.to_bytes(4, 'big')
    nops = lambda n: bytes.fromhex('4e71') * n

    # code en $800 (zone de l'ancien chargeur de boot, jamais exécutée)
    d[0x800 - BASE:0x800 - BASE + len(code)] = code

    # 1. début de F_07732 : clr.w d0 / clr.w d1 / clr.w d2  ->  jsr pre
    put(0x7732, '424042414242', jsr(0x800))
    # 2. fin de boucle de F_07732 ($7850-$7869)  ->  jmp looptail + NOP
    put(0x7850, '3407' '66000016' '5202' '3e02' '41f81007' '10302000' '67000006' '4ef87746',
        jmp(0x804) + nops(10))
    # 3. eori.w #1,d2  ->  bsr.w other
    disp = (0x808 - (0x7772 + 2)) & 0xFFFF
    put(0x7772, '0a420001', bytes.fromhex('6100') + disp.to_bytes(2, 'big'))
    # 4. lea $786c.l,a0 / move.b (a0,d2.w),d1  ->  move.w d7,d1 + NOP
    #    ($786C[i^1] == i pour i = 0,1 : même résultat, et correct pour i = 2)
    put(0x7782, '41f90000786c' '12302000', bytes.fromhex('3207') + nops(4))
    # 5. cmpi.b #6,$1092.w (règle d'élimination)  ->  jmp elim
    put(0x66E4, '0c3800061092', jmp(0x80C))
    # 6. move.b #$32,$125b.w (une seconde de chronomètre)  ->  jsr tick
    put(0x1DCC, '11fc0032125b', jsr(0x810))
    # 7. F_07680 : move.l d2,-(a7) / lea $7644.w,a1  ->  jmp erasehook
    put(0x7680, '2f0243f87644', jmp(0x814))
    # 8. F_0765C : move.l d2,-(a7) / lea $24.w,a3  ->  jmp drawhook
    put(0x765C, '2f0247f80024', jmp(0x818))

    # 9. L_06872 : move.b #$32,$11ed.w (toute fin de round)  ->  jmp roundend
    put(0x6872, '11fc003211ed', jmp(0x81C))

    # 10. move.b d0,$1092.w / move.w #2,d2 ($662C, cible de branchement)  ->  jsr roundmsg + NOP
    put(0x662C, '11c01092' '343c0002', jsr(0x820) + nops(1))

    # 11. touche F3 (musique, $7316-$733B)  ->  F3 : jmp f3key (partie à
    #     3 joueurs) ; F5 (code $3F, inutilisé par le jeu) : jmp f5key (musique) ;
    #     « / » du pavé numérique (code $65) : jmp slashkey (Mega STE, 8/16 MHz)
    put(0x7316, '0c11003d' '66000020'
        '4a38100e' '6700000a' '4eb81706' '6000007c' '11fc0001100e' '4eb81734' '6000006e',
        bytes.fromhex('0c11003d' '6606') + jmp(0x824)
        + bytes.fromhex('0c11003f' '6606') + jmp(0x834)
        + bytes.fromhex('0c110065' '6608') + jmp(0x848) + nops(1))
    # 12. message $0B de l'arbitre : « PRESS F3 FOR MUSIC » -> « PRESS F5 FOR MUSIC »
    #     et message des démos : « OR F1 AND F2 KEYS » -> « OR F1 F2 F3 KEYS »
    for old, new in ((b'@PRESS@F3@FOR@', b'@PRESS@F5@FOR@'),
                     (b'OR@@F1@AND@F2@KEYS', b'@OR@F1@F2@F3@KEYS@')):
        o = d.find(old)
        assert o > 0 and d.find(old, o + 1) < 0 and len(old) == len(new)
        d[o:o + len(old)] = new

    # 13. routine son : registre 7 du PSG = $DC (port B en sortie)  ->  $5C
    #     (même mixage, port B du port parallèle en entrée)
    put(0xB2B6, '21fc0700dc008800', bytes.fromhex('21fc07005c008800'))
    # 14. idem en $B2D0 (son coupé) : $F8 -> $78
    put(0xB2D0, '21fc0700f8008800', bytes.fromhex('21fc070078008800'))

    # 15-18. épreuves bonus A ($DFA0) et B ($EEC8) : les humains jouent à tour
    #        de rôle, $1077/$1078 = 1 puis 0. Départ à 2 : le joueur 3 a son
    #        tour ; sans lui, le tour 2 est sauté (test de $1007[2] = $1009).
    for a in (0xDFCE, 0xEF02):
        put(a, '11fc00011077', bytes.fromhex('11fc00021077'))
    for a in (0xDFD4, 0xEF08):
        put(a, '11fc00011078', bytes.fromhex('11fc00021078'))
    # 19. P_02516 (paquet joysticks de l'IKBD) : move.b d0,$126c.w / lsr.w #8,d0 /
    #     move.b d0,$126d.w -> jmp ikbdhook + NOP (joysticks du clavier gardés à
    #     part ; $126C-$126E sont remplis à chaque VBL selon le choix des joueurs)
    put(0x2532, '11c0126c' 'e048' '11c0126d', jmp(0x828) + nops(2))
    # 20. épreuve A : clignotement du poing $1314[joueur] -> jsr blinka + NOP
    put(0xDFF8, '103c0014' '41f81314' '11802000', jsr(0x82C) + nops(3))
    # 21. épreuve B : idem -> jsr blinkb + NOP
    put(0xEF4A, '41f81314' '11bc00142000', jsr(0x830) + nops(2))
    # 27. VBL (P_01BA6) : move.b #1,$1016.w -> jsr vblmap
    put(0x1BAA, '11fc00011016', jsr(0x844))
    # 22. F1, F2 (L_07388) : move.b d1,$1007.w / move.b d2,$1008.w -> jsr setp12 + NOP
    put(0x7388, '11c11007' '11c21008', jsr(0x838) + nops(1))
    # 23. début de partie (F_06CD0) : clignotement des poings 0 et 1 -> jsr blinkset
    put(0x6CE4, '11fc001e1314' '11fc001e1315', jsr(0x83C) + nops(3))
    # 24. F_07608 (clignotement, VBL) : moveq #1,d2 / lea $1007.w,a0 -> jsr blinkvbl
    put(0x7608, '7401' '41f81007', jsr(0x840))
    # 25. nouvelle partie (P_014FA) : move.b #2,$100d.w (vitesse « normal »)
    #     -> NOP : la vitesse choisie (F6-F10) est gardée
    put(0x151E, '11fc0002100d', nops(3))
    # 26. démarrage (L_02160) : le jeu écrit resvalid ($426) et resvector ($42A)
    #     pour que le bouton reset le relance. -> clr.l $426.w : le reset rend
    #     la main au TOS.
    put(0x21E6, '21fc314159260426' '21fc00002160042a',
        bytes.fromhex('42b80426') + nops(6))

    # barre du haut : rouge 8 pixels et bleu 16 pixels plus à gauche, pour
    # laisser de la place entre le poing bleu et « LV ». Points de vie
    # ($85D4) et scores ($85D7) en cases de 8 pixels, poing rouge ($7648)
    # en pas de 2 pixels (le bleu : FIST_X dans p3.s).
    put(0x85D4, '000a14' '28323c', bytes.fromhex('000912' '28313a'))
    put(0x7648, '00000050', bytes.fromhex('0000004c'))

    # écran d'aide : F3 = partie à 3 joueurs, F5 = musique
    helpscreen.patch(d, BASE)

    open(dst, 'wb').write(d)
    print('%s : code 3 joueurs %d octets en $800, 27 accroches' % (dst, len(code)))


if __name__ == '__main__':
    main(*sys.argv[1:4])
