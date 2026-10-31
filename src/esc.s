; ============================================================================
; IK+ (Atari ST) - page d'introduction pendant le jeu (touche Échap).
;
; Module résident, assemblé en ESCBASE ($6C000) et posé là par le chargeur
; (src/loader.s, routine de recopie) avec le jeu. Zone libre pour le jeu :
; ses derniers tampons finissent en $6B077 ($63078-$6B077, 4 x 8 Ko), et rien
; ne vise $6B078-$6FFFF (désassemblage, et mémoire remplie d'un motif puis
; relue après une longue partie à 3 avec les épreuves bonus, STF et STE).
;
; Échap ($01 en $13AC) est testé dans F_0708C (touches, appelé par la VBL en
; $1C20/$1C38) : l'accroche de $732E saute en ESCBASE (eschook). Là, encore
; dans l'interruption, l'adresse de retour de la VBL ($42(a7) : cadre de la
; VBL + l'adresse de retour de F_0708C) est remplacée par escmain : à la fin
; de la VBL, le processeur arrive dans la page au lieu de reprendre le jeu
; (même principe que la pause du jeu, en $1C4C).
;
; escmain : le TOS n'est plus là (le jeu l'a écrasé). La page coupe toutes
; les interruptions (rasters, VBL, clavier du jeu), le son et le blitter,
; dessine la page dans l'écran $70000 avec le logo et la police du jeu
; (intacts en mémoire), puis lit elle-même le clavier sur l'ACIA (paquets de
; l'IKBD sautés) : F1 à F4 et Espace, comme la page du chargeur. (Avec le
; gestionnaire clavier du jeu, des touches se perdaient.) Les choix
; vont directement dans CTL / TRAIN ($850-$853, src/p3.s) ; ils ne sont pas
; écrits dans IKPLUS.CFG (pas de TOS). Espace : interruptions du jeu remises,
; plus aucun humain, décor du jeu recopié dans les deux écrans (F_02550,
; comme en fin de partie), puis relance du jeu ($135F, comme F1/F2 : la VBL
; repart en P_014FA) : le jeu reprend sur sa démo.
; ============================================================================

ESCBASE     equ $6C000
LOGO        equ $1b678
FONT        equ $9736
SCREEN      equ $70000
CTL         equ $850                ; sources des joueurs 1 à 3 (src/p3.s)
TRAIN       equ $853                ; mode entraînement
P1          equ $1007               ; drapeaux humain des combattants 0 à 2
KEY         equ $13ac               ; dernière touche enfoncée (gestionnaire du jeu)
RESTART     equ $135f               ; 1 : nouvelle partie (VBL du jeu, $1C56)
PAUSE       equ $1372
BACKDROP    equ $2550               ; F_02550 : décor ($23378) recopié dans les deux écrans
NSRC        equ 7                   ; sources 0 à 6 (6 = aucune)
NAMECOL     equ 26
ROW1        equ 112
RSTEP       equ 10

            org ESCBASE

; --- entrées fixes ------------------------------------------------------------
            bra.w   eschook         ; $6C000  accroche de F_0708C (Échap)
; écrits par le chargeur, dans sa copie du module, avant la recopie
haspad      dc.b    0               ; $6C004  manettes possibles (STE, Falcon)
hasdma      dc.b    0               ; $6C005  son DMA présent (STE, Mega STE, Falcon)
blit        dc.b    0               ; $6C006  mode STE : le blitter peut tourner
            dc.b    0
            if haspad!=ESCBASE+4
            fail "haspad doit rester en ESCBASE+4 (chargeur)"
            endif

; eschook : dans la VBL, appelé par un saut depuis F_0708C (touche Échap).
; $42(a7) : adresse de retour de la VBL (la VBL l'utilise en $3E(a7), plus
; les 4 octets de l'appel de F_0708C).
eschook     clr.b   KEY.w
            move.l  #escmain,$42(a7)
            rts                             ; fin de F_0708C

; --- la page ------------------------------------------------------------------
escmain     move.w  #$2700,sr
            tst.b   blit
            beq.s   .nb
            clr.b   $ffff8a3c.w             ; blitter arrêté
.nb         tst.b   hasdma
            beq.s   .nd
            clr.b   $ffff8901.w             ; son DMA arrêté
.nd         moveq   #8,d0                   ; volumes du YM à 0 (registres 8-10)
.vol        move.b  d0,$ffff8800.w
            clr.b   $ffff8802.w
            addq.b  #1,d0
            cmp.b   #11,d0
            blo.s   .vol
            ; écran $70000, couleurs de la page (interruptions coupées
            ; jusqu'à la relance)
            move.b  #SCREEN>>16,$ffff8201.w
            move.b  #(SCREEN>>8)&$ff,$ffff8203.w
            lea     pal(pc),a0
            lea     $ffff8240.w,a1
            moveq   #16/2-1,d0
.pal        move.l  (a0)+,(a1)+
            dbra    d0,.pal
            bsr     draw
            bsr     flush                   ; clavier vidé : rien en cours
            moveq   #0,d7                   ; octets de paquet IKBD à sauter

.wk         bsr     getkey                  ; d0 = touche enfoncée
            cmp.b   #$39,d0                 ; Espace
            beq.s   .go
            sub.b   #$3b,d0                 ; F1, F2, F3 -> 0, 1, 2 ; F4 -> 3
            cmp.b   #3,d0
            beq.s   .f4
            bhs.s   .wk
            moveq   #0,d5
            move.b  d0,d5
            bsr     nextsrc
            bsr     dname
            bra.s   .wk
.f4         eori.b  #1,TRAIN.w
            bsr     dtrain
            bra.s   .wk

            ; Espace : relance du jeu
.go         clr.b   P1.w                    ; plus d'humain : introduction,
            clr.b   P1+1.w                  ; puis démo du jeu
            clr.b   P1+2.w
            clr.w   PAUSE.w
            clr.b   KEY.w
            jsr     BACKDROP.w              ; la page effacée des écrans (la
                                            ; relance ne redessine que le bas)
            move.b  #1,RESTART.w
            move.w  #$2300,sr
.wr         bra.s   .wr                     ; la VBL du jeu relance la partie

; getkey : attend une touche enfoncée sur l'ACIA du clavier (lecture
; directe, interruptions coupées) ; d0 = son code. Les relâchements (bit 7)
; et les paquets de l'IKBD (en-tête $F6-$FF, puis 1 à 7 octets : joysticks,
; souris…) sont ignorés ; d7 = octets de paquet encore à sauter.
getkey      btst    #0,$fffffc00.w          ; un octet reçu ?
            beq.s   getkey
            moveq   #0,d0
            move.b  $fffffc02.w,d0
            tst.w   d7
            beq.s   .hd
            subq.w  #1,d7                   ; octet d'un paquet
            bra.s   getkey
.hd         cmp.b   #$f6,d0
            blo.s   .key
            sub.b   #$f6,d0
            move.b  pklen(pc,d0.w),d7       ; en-tête : longueur du paquet
            bra.s   getkey
.key        tst.b   d0
            bmi.s   getkey                  ; relâchement
            rts
; flush : vide l'ACIA du clavier jusqu'à un silence (~40 à 75 ms). Pendant
; le dessin, une réponse de l'IKBD (le jeu interroge les joysticks : $FD et 2
; octets) a pu arriver en partie seulement (débordement de l'ACIA, qui ne
; garde qu'un octet) : sans cela, ses octets manquants seraient pris sur les
; touches suivantes. Ensuite, plus d'interrogation (la VBL du jeu est coupée).
flush       move.l  #30000,d1
.f          btst    #0,$fffffc00.w
            beq.s   .n
            move.b  $fffffc02.w,d0
            move.l  #30000,d1
.n          subq.l  #1,d1
            bne.s   .f
            rts

; octets qui suivent chaque en-tête $F6 à $FF
pklen       dc.b    7,5,2,2,2,2,6,2,1,1
            even

; --- dessin de la page (a6 = écran) ------------------------------------------
draw        lea     SCREEN,a6
            move.l  a6,a0
            move.w  #32000/4-1,d0
.cls        clr.l   (a0)+
            dbra    d0,.cls
            ; logo : lignes 5 à 111 de l'image du jeu, en haut, centré
            lea     LOGO+5*160,a0
            lea     40(a6),a1
            move.w  #111-5,d0
.lg         moveq   #80/4-1,d1
.lgw        move.l  (a0)+,(a1)+
            dbra    d1,.lgw
            lea     80(a0),a0
            lea     80(a1),a1
            dbra    d0,.lg
            lea     sidel(pc),a0            ; dessins « REFORGED » et « EDITION »
            lea     SIDEY*160(a6),a1
            moveq   #SIDELW-1,d2
            bsr     dside
            lea     sider(pc),a0
            lea     SIDEY*160+120(a6),a1
            moveq   #SIDERW-1,d2
            bsr     dside
            lea     texts(pc),a5
.tx         move.b  (a5)+,d2                ; couleur (0 = fin)
            beq.s   .txe
            moveq   #0,d0
            move.b  (a5)+,d0                ; ligne
            moveq   #0,d1
            move.b  (a5)+,d1                ; colonne (255 = centré)
            bsr     dtext
            bra.s   .tx
.txe        bsr     dtrain
            moveq   #0,d5
.nm         bsr     dname
            addq.w  #1,d5
            cmp.w   #3,d5
            blo.s   .nm
            rts

; dtrain : ligne « F4 TRAINING MODE », grise (arrêt) ou verte (marche).
dtrain      movem.l d0-d7/a0-a5,-(a7)
            lea     ttrain(pc),a5
            moveq   #3,d2
            tst.b   TRAIN.w
            beq.s   .off
            moveq   #4,d2
.off        moveq   #0,d0
            move.b  -2(a5),d0
            moveq   #0,d1
            move.b  -1(a5),d1
            bsr     dtext
            movem.l (a7)+,d0-d7/a0-a5
            rts

; ok : d1 = 0 si la source d0 est permise pour le joueur d5 (0 à 2).
ok          cmp.b   #6,d0                   ; « aucun » : joueur 3 seulement
            bne.s   .n6
            cmp.w   #2,d5
            bne.s   .no
            bra.s   .yes
.n6         cmp.b   #4,d0                   ; manettes : STE et Falcon seulement
            blo.s   .np
            tst.b   haspad
            beq.s   .no
.np         lea     CTL.w,a0                ; pas déjà prise par un autre joueur
            moveq   #2,d1
.ot         cmp.w   d1,d5
            beq.s   .nx
            cmp.b   (a0,d1.w),d0
            beq.s   .no
.nx         dbra    d1,.ot
.yes        moveq   #0,d1
            rts
.no         moveq   #-1,d1
            rts

; nextsrc : source suivante permise pour le joueur d5.
nextsrc     lea     CTL.w,a1
            move.b  (a1,d5.w),d0
            moveq   #NSRC-1,d2
.nx         addq.b  #1,d0
            cmp.b   #NSRC,d0
            blo.s   .in
            moveq   #0,d0
.in         bsr.s   ok
            tst.w   d1
            beq.s   .set
            dbra    d2,.nx
            rts
.set        lea     CTL.w,a1
            move.b  d0,(a1,d5.w)
            rts

; dname : nom de la source du joueur d5.
dname       movem.l d0-d7/a0-a5,-(a7)
            lea     CTL.w,a0
            moveq   #0,d0
            move.b  (a0,d5.w),d0
            mulu    #11,d0
            lea     names(pc),a5
            add.w   d0,a5
            moveq   #RSTEP,d0
            mulu    d5,d0
            add.w   #ROW1,d0
            moveq   #NAMECOL,d1
            moveq   #1,d2
            bsr     dtext
            movem.l (a7)+,d0-d7/a0-a5
            rts

; dtext : texte a5 (fin 0) en couleur d2, ligne d0, colonne d1 (255 :
; centré), avec la police 8 x 8 du jeu (lettre = code - '0'). Comme dans le
; chargeur : espace -> '@', ':' -> '=', '-' -> $5C, '+' -> ';', et
; « ( », « ) », « . » dessinés ici.
dtext       move.l  a5,a0
.len        tst.b   (a0)+
            bne.s   .len
            move.l  a0,d3
            sub.l   a5,d3
            subq.w  #1,d3
            cmp.b   #255,d1
            bne.s   .col
            moveq   #40,d1
            sub.w   d3,d1
            lsr.w   #1,d1
.col        mulu    #160,d0
            lea     (a6,d0.l),a1
.ch         moveq   #0,d0
            move.b  (a5)+,d0
            beq     .end
            lea     FONT,a2
            cmp.b   #' ',d0
            bne.s   .nsp
            moveq   #'@',d0
.nsp        cmp.b   #':',d0
            bne.s   .ncl
            moveq   #'=',d0
.ncl        cmp.b   #'-',d0
            bne.s   .nmi
            moveq   #$5c,d0
.nmi        cmp.b   #'+',d0
            bne.s   .npl
            moveq   #';',d0
.npl        cmp.b   #'.',d0
            bne.s   .npt
            lea     gdot(pc),a2
            moveq   #'0',d0
.npt        cmp.b   #'(',d0
            bne.s   .npo
            lea     gparen(pc),a2
            moveq   #'0',d0
.npo        cmp.b   #')',d0
            bne.s   .npf
            lea     gparen+8(pc),a2
            moveq   #'0',d0
.npf        sub.w   #'0',d0
            lsl.w   #3,d0
            add.w   d0,a2
            move.w  d1,d0
            lsr.w   #1,d0
            lsl.w   #3,d0
            btst    #0,d1
            beq.s   .ev
            addq.w  #1,d0
.ev         lea     (a1,d0.w),a3
            moveq   #7,d4
.row        move.b  (a2)+,d5
            move.l  a3,a4
            moveq   #0,d6
.pl         btst    d6,d2
            beq.s   .p0
            move.b  d5,(a4)
            bra.s   .pn
.p0         clr.b   (a4)
.pn         addq.l  #2,a4
            addq.w  #1,d6
            cmp.w   #4,d6
            blo.s   .pl
            lea     160(a3),a3
            dbra    d4,.row
            addq.w  #1,d1
            bra     .ch
.end        rts

; dside : bloc de SIDEH lignes de d2+1 groupes de 16 pixels, a0 = bloc,
; a1 = écran ; seuls les pixels non noirs du bloc sont écrits.
dside       movem.l d3-d7/a2,-(a7)
            moveq   #SIDEH-1,d0
.l          move.l  a1,a2
            move.w  d2,d1
.g          movem.w (a0)+,d3-d6
            move.w  d3,d7
            or.w    d4,d7
            or.w    d5,d7
            or.w    d6,d7
            not.w   d7
            and.w   d7,(a2)
            or.w    d3,(a2)+
            and.w   d7,(a2)
            or.w    d4,(a2)+
            and.w   d7,(a2)
            or.w    d5,(a2)+
            and.w   d7,(a2)
            or.w    d6,(a2)+
            dbra    d1,.g
            lea     160(a1),a1
            dbra    d0,.l
            movem.l (a7)+,d3-d7/a2
            rts

; --- données ------------------------------------------------------------------
            include "src/sides.i"           ; dessins de Stéphane (tools/sides.py)
gparen      dc.b    $0c,$18,$30,$30,$30,$18,$0c,$00
            dc.b    $30,$18,$0c,$0c,$0c,$18,$30,$00
gdot        dc.b    $00,$00,$00,$00,$00,$18,$18,$00
pal         dc.w    $000,$777,$750,$444,$070,$000,$000,$000
            dc.w    $000,$300,$400,$500,$600,$700,$000,$666
texts       dc.b    1,ROW1,3,'F1  PLAYER 1 (WHITE) :',0
            dc.b    1,ROW1+RSTEP,3,'F2  PLAYER 2 (RED)   :',0
            dc.b    1,ROW1+2*RSTEP,3,'F3  PLAYER 3 (BLUE)  :',0
            dc.b    2,TROW,255,'PRESS SPACE TO START',0
            dc.b    3,180,255
            ifd     REFTAG
            dc.b    'ENHANCED BY CLAUDE AI - 2026 - V0.0.0',0
            else
            include "build/version.i"       ; « ENHANCED BY CLAUDE AI - 2026 - Vx.y.z »
            endif
            dc.b    11,191,255,'IN MEMORY OF ARCHER MACLEAN (1962-2022)',0
            dc.b    0
TROW        equ     (ROW1+3*RSTEP+8+180-8)/2
            dc.b    ROW1+3*RSTEP,3
ttrain      dc.b    'F4  TRAINING MODE (NO TIME LIMIT)',0
names       dc.b    'JOYSTICK 0',0,'JOYSTICK 1',0,'JOYSTICK 2',0,'JOYSTICK 3',0
            dc.b    'JOYPAD A  ',0,'JOYPAD B  ',0,'NONE      ',0
            even
esc_end
            if esc_end>$70000
            fail "module Échap trop long (doit finir sous l'écran $70000)"
            endif
