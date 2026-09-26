; ============================================================================
; IK+ (Atari ST) - version STE : son DMA (puis blitter).
;
; Ce module est chargé en $C0000 par le chargeur STE (loader.s -DSTE), qui
; exige un STE avec au moins 1 Mo. Le jeu, conçu pour 512 Ko, n'utilise rien
; au-dessus de $80000.
;
; Son : les bruitages du jeu (cris, coups) sont 18 échantillons 8 bits non
; signés, joués à ~9,6 kHz par le YM : une interruption Timer C par octet
; (P_017D8 / P_0180E), qui convertit l'octet en deux volumes YM. Cela coûte
; 13 à 18 % du processeur pendant chaque bruitage. Ici :
;  - init (appelé une fois par le chargeur, image du jeu déjà en $700) :
;    rééchantillonne les 18 sons à 12 517 Hz (interpolation linéaire, en
;    8 bits signés) dans SMPBUF, et règle le mélangeur du STE (LMC1992) ;
;  - dmaplay (appelé à la place du lancement Timer C, d1 = n° du son) :
;    lance le son en DMA, sans interruption. Le Timer C n'est plus armé et
;    $1374 (« son en cours ») reste à 0 : la musique garde ses 3 voies YM.
; La hauteur est fixe (9 600 Hz d'origine) ; le jeu la faisait varier de
; ±5 % (et ~-9 % dans les épreuves bonus).
;
; Blitter : les 3 combattants (F_09C5C blanc, P_09D70 rouge, F_09E90 bleu)
; étaient dessinés au 68000 (décalage par ror.l, masque = OU des 3 plans),
; et effacés par F_0D6C4 (recopie du décor $23378, 16 octets par ligne).
; Cela faisait ~40 % du temps d'une image de combat.
;  - initspr (à la place de « jsr F_02570 » en $2208, qui fabrique les deux
;    banques de sprites $43078 / $53078 en miroir) : recopie chaque image de
;    sprite au format du blitter, avec le masque : 4 mots par ligne
;    (masque, plan 0, plan 1, plan 2), dans CONVBUF ;
;  - drawf0/1/2 : dessin au blitter, bande par bande (16 pixels de large) :
;    pour chaque plan de l'écran, « ET NON masque » puis « OU plan du
;    sprite » ; chaque combattant répartit ses 3 plans sur les 4 plans de
;    l'écran à sa façon (c'est ce qui donne la couleur de la veste) ;
;    carte de collision ($9FAC, 1 bit par pixel) : « OU masque » ;
;  - restore : recopie du décor et effacement des cartes, au blitter.
; Le blitter tourne en mode partagé, relancé en boucle par le 68000 (méthode
; d'Atari) : les interruptions (raster Timer B, VBL) passent entre deux
; paquets de 64 accès, donc les dégradés de couleurs ne sautent pas.
; ============================================================================

STEBASE     equ $C0000
SMPBUF      equ $D0000          ; sons rééchantillonnés (~115 Ko)
SRC         equ $2B178          ; banque de sons du jeu
TSTART      equ $2B078          ; 32 débuts (décalages depuis SRC)
TEND        equ $2B0F8          ; 32 fins
NSMP        equ 32
STEP        equ 50263           ; 9600 / 12517 x 65536
CONVBUF     equ $80000          ; sprites au format du blitter (~150 Ko)
BANK        equ $43078          ; banques de sprites du jeu (table de 96 images)
NFRAMES     equ 96
BLT         equ $ffff8a00       ; blitter
B_SXI       equ $20
B_SYI       equ $22
B_SRC       equ $24
B_EM1       equ $28
B_EM2       equ $2a
B_EM3       equ $2c
B_DXI       equ $2e
B_DYI       equ $30
B_DST       equ $32
B_XC        equ $36
B_YC        equ $38
B_HOP       equ $3a             ; mot : HOP (octet haut), opération (octet bas)
B_CTL       equ $3c
B_SKEW      equ $3d
F_02570     equ $2570
F_0D752     equ $D752
F_0D818     equ $D818
            ifnd VOLSHIFT
VOLSHIFT    equ 1               ; sons à moitié du volume maximal du DMA
            endif

            org STEBASE

; --- entrées fixes --------------------------------------------------------
            bra.w   init        ; $C0000  appelé par le chargeur
            bra.w   dmaplay     ; $C0004  lancement d'un bruitage (d1 = n°)
            bra.w   initspr     ; $C0008  à la place de jsr F_02570 ($2208)
            ifd CHECK
            bra.w   chkf0
            bra.w   chkf1
            bra.w   chkf2
            bra.w   chkr
            else
            bra.w   drawf0      ; $C000C  F_09C5C : combattant blanc
            bra.w   drawf1      ; $C0010  P_09D70 : rouge
            bra.w   drawf2      ; $C0014  F_09E90 : bleu
            bra.w   restore     ; $C0018  F_0D6C4 : effacement des combattants
            endif
            bra.w   rasterw     ; $C001C  début du Timer B (raster) en $1934

smptab      ds.l    2*NSMP      ; début, fin (exclue) de chaque son rééchantillonné

; ----------------------------------------------------------------------------
; init : mélangeur + rééchantillonnage. Superviseur, IRQ masquées.
; ----------------------------------------------------------------------------
init        movem.l d0-d7/a0-a6,-(a7)
            clr.b   $ffff8901.w             ; DMA arrêté

            ; LMC1992 par le Microwire : volume maximal, graves/aigus neutres,
            ; YM mélangé au DMA
            lea     mwtab(pc),a0
            moveq   #(mwend-mwtab)/2-1,d7
.mw         move.w  #$07ff,$ffff8924.w
            move.w  (a0)+,$ffff8922.w
            move.w  #2000,d0                ; attente du début du décalage
.mw1        cmpi.w  #$07ff,$ffff8924.w      ; (borné : l'émulation peut être
            dbne    d0,.mw1                 ;  instantanée)
.mw2        cmpi.w  #$07ff,$ffff8924.w      ; attente de la fin
            bne.s   .mw2
            dbra    d7,.mw

            ; rééchantillonnage : pour chaque son, pointeur a0 sur l'octet
            ; courant s0, d3 = fraction (16 bits) ; sortie = s0 + (s1-s0) x d3.
            ; Le pas (9 600 / 12 517 < 1) avance a0 d'au plus un octet.
            lea     TSTART,a2
            lea     TEND,a3
            lea     SMPBUF,a1
            lea     smptab(pc),a4
            move.w  #STEP,d6
            moveq   #NSMP-1,d7
.smp        move.l  a1,(a4)+                ; début
            lea     SRC,a0
            move.l  a0,a5
            adda.l  (a2)+,a0                ; premier octet
            adda.l  (a3)+,a5                ; fin (exclue)
            subq.l  #1,a5                   ; dernier octet interpolable
            moveq   #0,d3
            cmpa.l  a5,a0
            bhs.s   .done
.lp         moveq   #0,d4
            move.b  (a0),d4                 ; s0 (non signé)
            moveq   #0,d5
            move.b  1(a0),d5                ; s1
            sub.w   d4,d5                   ; écart
            move.w  d3,d2
            lsr.w   #1,d2                   ; fraction sur 15 bits (muls signé)
            muls    d2,d5
            add.l   d5,d5
            swap    d5                      ; écart x fraction
            add.w   d5,d4
            eori.b  #$80,d4                 ; en signé
            ifne VOLSHIFT
            asr.b   #VOLSHIFT,d4            ; volume (le DMA est plus fort que le YM)
            endif
            move.b  d4,(a1)+
            add.w   d6,d3
            bcc.s   .same
            addq.l  #1,a0
.same       cmpa.l  a5,a0
            blo.s   .lp
.done       move.l  a1,d0                   ; fin paire (exigée par le DMA)
            btst    #0,d0
            beq.s   .even
            clr.b   (a1)+
.even       move.l  a1,(a4)+                ; fin
            dbra    d7,.smp
            movem.l (a7)+,d0-d7/a0-a6
            rts

; commandes Microwire du LMC1992 (adresse %10, puis commande)
mwtab       dc.w    %10011101000            ; volume général : 0 dB
            dc.w    %10101010100            ; volume gauche : 0 dB
            dc.w    %10100010100            ; volume droit : 0 dB
            dc.w    %10010000110            ; aigus : 0 dB
            dc.w    %10001000110            ; graves : 0 dB
            dc.w    %10000000001            ; mélange : YM + DMA
mwend

; ----------------------------------------------------------------------------
; dmaplay : remplace le lancement du son par le Timer C, en $2064 (combat)
; et en $E36E (épreuves bonus). d1.w = numéro du son. Tous registres gardés.
; ----------------------------------------------------------------------------
dmaplay     movem.l d0-d1/a0,-(a7)
            clr.b   $ffff8901.w             ; arrête le son précédent
            andi.w  #NSMP-1,d1
            lsl.w   #3,d1
            lea     smptab(pc),a0
            move.l  (a0,d1.w),d0            ; début
            cmp.l   4(a0,d1.w),d0
            beq.s   .x                      ; son vide
            move.b  d0,$ffff8907.w
            lsr.l   #8,d0
            move.b  d0,$ffff8905.w
            lsr.w   #8,d0
            move.b  d0,$ffff8903.w
            move.l  4(a0,d1.w),d0           ; fin
            move.b  d0,$ffff8913.w
            lsr.l   #8,d0
            move.b  d0,$ffff8911.w
            lsr.w   #8,d0
            move.b  d0,$ffff890f.w
            move.b  #$81,$ffff8921.w        ; mono, 12 517 Hz
            move.b  #1,$ffff8901.w          ; lecture, une fois
.x          movem.l (a7)+,d0-d1/a0
            rts

; ----------------------------------------------------------------------------
; initspr : fabrique les banques du jeu (F_02570), puis leur copie au format
; du blitter. Image convertie : suite de bandes « décalage.w, nombre.w, puis
; nombre lignes de 4 mots (masque, p0, p1, p2) », terminée par nombre = 0.
; ----------------------------------------------------------------------------
initspr     jsr     F_02570
            movem.l d0-d7/a0-a6,-(a7)
            lea     convtab(pc),a4
            lea     CONVBUF,a1
            lea     BANK,a2                 ; table de la banque 0
            move.w  #2*NFRAMES-1,d7         ; 96 images x 2 banques (tables
.frame      move.l  (a2)+,d0                ;  en $43078 et $53078 : voir .next)
            bne.s   .conv
            clr.l   (a4)+
            bra.s   .next
.conv       move.l  a1,(a4)+
            lea     BANK,a0
            adda.l  d0,a0                   ; décalage depuis $43078 (banque 1 : +$10000)
.strip      move.w  (a0)+,(a1)+             ; décalage à l'écran
            move.w  (a0)+,d6                ; nombre de lignes
            move.w  d6,(a1)+
            beq.s   .next
            andi.w  #$7f,d6
            subq.w  #1,d6
.row        move.w  (a0)+,d0
            move.w  (a0)+,d1
            move.w  (a0)+,d2
            move.w  d0,d3
            or.w    d1,d3
            or.w    d2,d3
            move.w  d3,(a1)+                ; masque
            move.w  d0,(a1)+
            move.w  d1,(a1)+
            move.w  d2,(a1)+
            dbra    d6,.row
            bra.s   .strip
.next       cmpi.w  #NFRAMES,d7             ; passage à la banque 1 (table en $53078)
            bne.s   .nb
            lea     BANK+$10000,a2
.nb         dbra    d7,.frame
            movem.l (a7)+,d0-d7/a0-a6
            rts

; ----------------------------------------------------------------------------
; drawf0/1/2 : remplacent les 3 routines de dessin des combattants.
; Comme l'original : liste de restauration ($103E, entrées adresse.l +
; nombre.w), carte de collision si $9FB4, puis F_0D818 (ombre) avec a5 =
; colonne de base et d7 = décalage.
; ----------------------------------------------------------------------------
drawf0      lea     pass0(pc),a4
            moveq   #0,d0
            bra.s   drawf
drawf1      lea     pass1(pc),a4
            moveq   #1,d0
            bra.s   drawf
drawf2      lea     pass2(pc),a4
            moveq   #2,d0
drawf       lea     $107b.w,a0
            moveq   #0,d1
            move.b  (a0,d0.w),d1            ; image
            moveq   #0,d2
            move.b  6(a0,d0.w),d2           ; sens ($1081+i)
            moveq   #0,d7
            move.b  3(a0,d0.w),d7           ; x ($107E+i), par 2 pixels
            cmpi.w  #NFRAMES,d1             ; hors table : rien (sécurité)
            bhs.s   .none
            move.w  d0,-(a7)                ; n° du combattant
            lsl.w   #2,d1
            lea     convtab(pc),a0
            tst.b   d2
            beq.s   .b0
            lea     4*NFRAMES(a0),a0
.b0         move.l  (a0,d1.w),d1
            bne.s   .go
            addq.l  #2,a7                   ; image vide : comme l'original, rien
.none       rts
.go         move.l  a6,-(a7)
            move.l  d1,a0                   ; bandes converties
            move.w  d7,d0
            andi.w  #$f8,d0
            addi.w  #$3bf0,d0
            ext.l   d0
            add.l   $1036.w,d0
            move.l  d0,a5                   ; colonne de base (écran de travail)
            andi.w  #7,d7
            add.w   d7,d7                   ; décalage 0..14 pixels
            move.l  $103e.w,a3              ; liste de restauration
            lea     BLT,a6

            ; réglages communs à toutes les bandes
            move.w  #$ffff,d0
            lsr.w   d7,d0
            move.w  d0,B_EM1(a6)            ; 1er mot : bits de la 1re colonne
            not.w   d0
            move.w  d0,B_EM3(a6)            ; 2e mot : bits débordant sur la 2e
            move.w  #$ffff,B_EM2(a6)
            move.w  #8,B_SXI(a6)
            move.w  #8,B_DXI(a6)
            move.b  d7,B_SKEW(a6)           ; ni FXSR ni NFSR
            tst.w   d7
            bne.s   .shift
            moveq   #1,d4                   ; aligné : 1 mot par ligne
            move.w  #8,d5                   ; source : ligne suivante
            move.w  #160,d6                 ; écran : ligne suivante
            bra.s   .setc
.shift      moveq   #2,d4                   ; décalé : 2 mots par ligne ; le 2e mot
            moveq   #0,d5                   ; lu est déjà la ligne suivante (+8)
            move.w  #160-8,d6
.setc       move.w  d4,B_XC(a6)
            move.w  d5,B_SYI(a6)
            move.w  d6,B_DYI(a6)

.strip      move.w  (a0)+,d0                ; décalage à l'écran
            move.w  (a0)+,d3                ; nombre de lignes (brut)
            beq.w   .end
            lea     (a5,d0.w),a1            ; adresse de la bande
            move.l  a1,(a3)+                ; liste de restauration
            move.w  d3,(a3)+
            andi.w  #$7f,d3
            move.l  a4,a2                   ; passes de ce combattant
.pass       move.w  (a2)+,d0                ; décalage source (masque/plan) ; -1 = fin
            bmi.s   .coll
            move.w  (a2)+,d1                ; plan à l'écran
            move.w  (a2)+,d2                ; opération
            lea     (a0,d0.w),a1
            move.l  a1,B_SRC(a6)
            move.l  -6(a3),a1
            adda.w  d1,a1
            move.l  a1,B_DST(a6)
            move.w  d3,B_YC(a6)
            move.w  d2,B_HOP(a6)
            move.b  #$80,B_CTL(a6)          ; départ, mode partagé
.w1         bset.b  #7,B_CTL(a6)            ; (re)lance ; fini quand le compteur
            nop
            tst.w   B_YC(a6)                ; de lignes est à 0 (pas le bit 7 :
            bne.s   .w1                     ;  rasterw peut le mettre à 0)
            bra.s   .pass

.coll       tst.w   $9fb4                   ; carte de collision : OU masque
            beq.s   .nextst
            move.l  -6(a3),d0
            andi.l  #$7ff8,d0
            lsr.w   #2,d0
            add.l   $9fac,d0
            move.l  d0,B_DST(a6)
            move.l  a0,B_SRC(a6)
            move.w  #2,B_DXI(a6)
            move.w  d6,d1
            lsr.w   #2,d1                   ; 160/4 = 40 (1 mot), 152/4 = 38 (2 mots)
            move.w  d1,B_DYI(a6)
            move.w  d3,B_YC(a6)
            move.w  #$0207,B_HOP(a6)
            move.b  #$80,B_CTL(a6)
.w2         bset.b  #7,B_CTL(a6)            ; (re)lance ; fini quand le compteur
            nop
            tst.w   B_YC(a6)                ; de lignes est à 0 (pas le bit 7 :
            bne.s   .w2                     ;  rasterw peut le mettre à 0)
            move.w  #8,B_DXI(a6)
            move.w  d6,B_DYI(a6)

.nextst     lsl.w   #3,d3                   ; lignes x 8 octets
            adda.w  d3,a0
            bra     .strip

.end        move.l  a3,$103e.w
            move.l  (a7)+,a6
            move.w  (a7)+,d2                ; n° du combattant
            moveq   #0,d0
            moveq   #0,d1
            lea     $107b.w,a0
            move.b  (a0,d2.w),d0            ; image
            move.b  6(a0,d2.w),d1           ; sens
            jmp     F_0D818                 ; ombre (a5, d7 comme l'original)

; passes : décalage source (0 masque, 2/4/6 plans du sprite), plan écran
; (0/2/4/6), opération ($0204 = ET NON source, $0207 = OU source)
pass0       dc.w    0,0,$0204               ; blanc : plan 0 effacé,
            dc.w    0,2,$0204, 2,2,$0207    ; plans 1-3 = sprite 0-2
            dc.w    0,4,$0204, 4,4,$0207
            dc.w    0,6,$0204, 6,6,$0207
            dc.w    -1
pass1       dc.w    0,0,$0204, 4,0,$0207    ; rouge : plan 0 = sprite 1,
            dc.w    0,2,$0204, 2,2,$0207    ; plan 1 = sprite 0, plan 2 = sprite 1,
            dc.w    0,4,$0204, 4,4,$0207    ; plan 3 = sprite 2
            dc.w    0,6,$0204, 6,6,$0207
            dc.w    -1
pass2       dc.w    0,0,$0204, 4,0,$0207    ; bleu : plan 0 = sprite 1,
            dc.w    0,2,$0204, 2,2,$0207    ; plan 1 = sprite 0, plan 2 effacé,
            dc.w    0,4,$0204               ; plan 3 = sprite 2
            dc.w    0,6,$0204, 6,6,$0207
            dc.w    -1

; ----------------------------------------------------------------------------
; rasterw : début de l'interruption raster (Timer B, $1934). Les couleurs
; changent parfois toutes les 2 lignes : le gestionnaire doit écrire le
; compteur suivant du Timer B en moins de 2 lignes. Si le blitter partage
; le bus à ce moment, il n'y arrive plus, et le bas de l'écran prend les
; couleurs de la zone d'avant. On met donc le blitter en pause (bit 7 à 0 :
; il reprendra où il en était, relancé par notre boucle). Le temps ajouté
; (40 cycles) est retiré de la boucle d'attente du gestionnaire ($194A).
; ----------------------------------------------------------------------------
rasterw     bclr.b  #7,$ffff8a3c.w
            movem.l d0/a0-a1,-(a7)
            lea     $19aa.w,a0
            jmp     $193e

; ----------------------------------------------------------------------------
; restore : remplace F_0D6C4. Pour chaque entrée de la liste $103A (au plus
; 59) : recopie du décor ($23378 + position) sur 16 octets et nombre+1
; lignes, et effacement des cartes $9FAC (si $9FB4) et $9FB0 (si $9FB6).
; ----------------------------------------------------------------------------
restore     move.l  a6,-(a7)
            lea     BLT,a6
            move.w  #$ffff,B_EM1(a6)
            move.w  #$ffff,B_EM2(a6)
            move.w  #$ffff,B_EM3(a6)
            move.w  #2,B_SXI(a6)
            move.w  #160-14,B_SYI(a6)
            clr.b   B_SKEW(a6)
            move.l  $103a.w,a3
            moveq   #$3c-2,d3               ; 59 entrées au plus
.ent        move.l  (a3)+,d0
            beq.w   .end
            move.w  (a3)+,d1
            beq.w   .end
            andi.w  #$7f,d1
            addq.w  #1,d1                   ; nombre + 1 lignes (comme l'original)
            move.l  d0,a1
            move.l  d0,d2
            andi.l  #$7ff8,d2
            move.l  d2,d4
            addi.l  #$23378,d4
            move.l  d4,B_SRC(a6)            ; décor
            move.l  a1,B_DST(a6)
            move.w  #8,B_XC(a6)
            move.w  #2,B_DXI(a6)
            move.w  #160-14,B_DYI(a6)
            move.w  d1,B_YC(a6)
            move.w  #$0203,B_HOP(a6)        ; copie
            move.b  #$80,B_CTL(a6)
.w1         bset.b  #7,B_CTL(a6)            ; (re)lance ; fini quand le compteur
            nop
            tst.w   B_YC(a6)                ; de lignes est à 0 (pas le bit 7 :
            bne.s   .w1                     ;  rasterw peut le mettre à 0)
            lsr.w   #2,d2                   ; position dans les cartes
            move.w  #2,B_XC(a6)
            move.w  #40-2,B_DYI(a6)
            move.w  #$0200,B_HOP(a6)        ; mise à zéro
            tst.w   $9fb4
            beq.s   .m2
            move.l  d2,d4
            add.l   $9fac,d4
            move.l  d4,B_DST(a6)
            move.w  d1,B_YC(a6)
            move.b  #$80,B_CTL(a6)
.w2         bset.b  #7,B_CTL(a6)            ; (re)lance ; fini quand le compteur
            nop
            tst.w   B_YC(a6)                ; de lignes est à 0 (pas le bit 7 :
            bne.s   .w2                     ;  rasterw peut le mettre à 0)
.m2         tst.w   $9fb6
            beq.s   .m3
            move.l  d2,d4
            add.l   $9fb0,d4
            move.l  d4,B_DST(a6)
            move.w  d1,B_YC(a6)
            move.b  #$80,B_CTL(a6)
.w3         bset.b  #7,B_CTL(a6)            ; (re)lance ; fini quand le compteur
            nop
            tst.w   B_YC(a6)                ; de lignes est à 0 (pas le bit 7 :
            bne.s   .w3                     ;  rasterw peut le mettre à 0)
.m3         dbra    d3,.ent
.end        move.l  (a7)+,a6
            jmp     F_0D752

            ifd CHECK
; ----------------------------------------------------------------------------
; Contrôle (essais seulement, -DCHECK) : chaque appel exécute la routine
; d'origine puis la nôtre sur le même état, et compare écran, cartes de
; collision, liste de restauration et son pointeur. Compteurs en chk_*.
; ----------------------------------------------------------------------------
S1          equ $a8000
S2          equ $b0000
M1A         equ $b8000
M2A         equ $ba000
M1B         equ $bc000
M2B         equ $be000
LA          equ $a7000
LB          equ $a7400
chkf0       pea     drawf0(pc)
            pea     tr0(pc)
            bra.s   chkgo
chkf1       pea     drawf1(pc)
            pea     tr1(pc)
            bra.s   chkgo
chkf2       pea     drawf2(pc)
            pea     tr2(pc)
            bra.s   chkgo
chkr        pea     restore(pc)
            pea     trr(pc)
chkgo
            ifd CHECKBONUS
            cmpi.b  #5,$1076.w              ; contrôle seulement dans les épreuves bonus
            beq.s   .yes
            cmpi.b  #7,$1076.w
            beq.s   .yes
            addq.l  #4,a7
            rts                             ; -> notre routine (adresse sur la pile)
.yes
            endif
            movem.l d0-d7/a0-a6,-(a7)
            move.w  sr,chk_sr
            ori.w   #$0700,sr               ; rien ne doit toucher l'écran pendant l'essai
            addq.l  #1,chk_n
            ; état de départ -> S1, M1A, M2A, LA
            move.l  $1036.w,a0
            lea     S1,a1
            bsr     cp32k
            move.l  $9fac,a0
            lea     M1A,a1
            bsr     cp8k
            move.l  $9fb0,a0
            lea     M2A,a1
            bsr     cp8k
            move.l  $103a.w,a0
            lea     LA,a1
            bsr     cplist
            move.l  $103e.w,chk_p
            ; routine d'origine
            movem.l (a7),d0-d7/a0-a6
            move.l  60(a7),a0
            jsr     (a0)
            ; résultat -> S2, M1B, M2B, LB
            move.l  $1036.w,a0
            lea     S2,a1
            bsr     cp32k
            move.l  $9fac,a0
            lea     M1B,a1
            bsr     cp8k
            move.l  $9fb0,a0
            lea     M2B,a1
            bsr     cp8k
            move.l  $103a.w,a0
            lea     LB,a1
            bsr     cplist
            move.l  $103e.w,chk_q
            ; retour à l'état de départ
            lea     S1,a0
            move.l  $1036.w,a1
            bsr     cp32k
            lea     M1A,a0
            move.l  $9fac,a1
            bsr     cp8k
            lea     M2A,a0
            move.l  $9fb0,a1
            bsr     cp8k
            lea     LA,a0
            move.l  $103a.w,a1
            bsr     cplist
            move.l  chk_p,$103e.w
            ; notre routine
            movem.l (a7),d0-d7/a0-a6
            move.l  64(a7),a0
            jsr     (a0)
            ; comparaisons
            move.l  $1036.w,a0
            lea     S2,a1
            move.w  #32000/4-1,d0
            moveq   #1,d2
            bsr     cmpz
            move.l  $9fac,a0
            lea     M1B,a1
            move.w  #8000/4-1,d0
            moveq   #2,d2
            bsr     cmpz
            move.l  $9fb0,a0
            lea     M2B,a1
            move.w  #8000/4-1,d0
            moveq   #3,d2
            bsr     cmpz
            move.l  $103a.w,a0
            lea     LB,a1
            move.w  #360/4-1,d0
            moveq   #4,d2
            bsr     cmpz
            move.l  $103e.w,d0
            cmp.l   chk_q,d0
            beq.s   .ok
            addq.l  #1,chk_bad+4*5
.ok         move.w  chk_sr,sr
            movem.l (a7)+,d0-d7/a0-a6
            addq.l  #8,a7
            rts

; cmp : a0 = zone produite, a1 = attendu, d0 = longs - 1, d2 = type
cmpz        moveq   #0,d1
.l          cmpm.l  (a0)+,(a1)+
            beq.s   .n
            addq.l  #1,d1
            tst.l   chk_fa
            bne.s   .n
            move.l  a0,chk_fa
            subq.l  #4,chk_fa
            move.l  -4(a0),chk_fv
            move.l  -4(a1),chk_fw
            move.w  d2,chk_ft
            move.l  chk_n,chk_fn
.n          dbra    d0,.l
            tst.l   d1
            beq.s   .x
            lsl.w   #2,d2
            lea     chk_bad(pc),a0
            addq.l  #1,(a0,d2.w)
.x          rts

cp32k       move.w  #32000/16-1,d0
            bra.s   cpl
cp8k        move.w  #8000/16-1,d0
            bra.s   cpl
cplist      move.w  #368/16-1,d0
cpl         move.l  (a0)+,(a1)+
            move.l  (a0)+,(a1)+
            move.l  (a0)+,(a1)+
            move.l  (a0)+,(a1)+
            dbra    d0,cpl
            rts

; trampolines : les instructions remplacées, puis la suite de l'original
tr0         clr.w   d0
            suba.l  a1,a1
            move.b  $107b.w,d0
            jmp     $9c64
tr1         clr.w   d0
            suba.l  a1,a1
            move.b  $107c.w,d0
            jmp     $9d78
tr2         clr.w   d0
            suba.l  a1,a1
            move.b  $107d.w,d0
            jmp     $9e98
trr         movea.l $103a.w,a3
            clr.w   d3
            jmp     $d6ca

chk_n       dc.l    0               ; appels contrôlés
chk_bad     dc.l    0,0,0,0,0,0     ; (inutilisé), écran, carte 1, carte 2, liste, pointeur
chk_fa      dc.l    0               ; 1re différence : adresse,
chk_fv      dc.l    0               ;  valeur obtenue,
chk_fw      dc.l    0               ;  valeur attendue,
chk_ft      dc.w    0               ;  type,
chk_fn      dc.l    0               ;  n° d'appel
chk_p       dc.l    0
chk_q       dc.l    0
chk_sr      dc.w    0
            endif

convtab     ds.l    2*NFRAMES       ; image -> bandes converties (0 = vide)
