; ============================================================================
; JOYTEST.TOS - état des joysticks de l'Atari ST, en direct.
; Assembler avec -DENGLISH pour la version anglaise.
;
;  - ports 0 (souris) et 1 : IKBD en mode joystick par événements ($14),
;    paquets $FE/$FF captés par le vecteur joyvec du TOS (Kbdvbase) ;
;  - adaptateur sur le port parallèle (Gauntlet II / Leatherneck…) :
;    lignes D0-D7 (PSG registre 15, port B en entrée), BUSY (MFP GPIP bit 0)
;    et STROBE (PSG registre 14 bit 5, remis à 1 avant lecture).
;    Toutes les lignes sont actives à 0. Les directions sont montrées pour
;    D0-D3 et D4-D7, le tir pour BUSY et STROBE, et les 8 lignes en brut :
;    ça permet de reconnaître le câblage de n'importe quel adaptateur.
;
; Une touche quelconque quitte. En sortant : joyvec d'origine, souris
; réactivée ($08), registres 7 et 14 du PSG remis comme avant.
; Fonctionne en basse, moyenne et haute résolution (lignes <= 40 colonnes).
; ============================================================================

            section text
start       clr.l   -(a7)                   ; Super(0)
            move.w  #$20,-(a7)
            trap    #1
            addq.l  #6,a7
            move.l  d0,oldssp

            pea     cls(pc)
            bsr     print

            move.w  #34,-(a7)               ; Kbdvbase
            trap    #14
            addq.l  #2,a7
            move.l  d0,a0
            move.l  24(a0),oldjoy           ; joyvec
            move.l  a0,kbdv
            move.l  #joyhand,24(a0)

            pea     ikbd_joy(pc)            ; IKBD : joystick par événements
            move.w  #0,-(a7)                ; (1 octet)
            move.w  #25,-(a7)               ; Ikbdws
            trap    #14
            addq.l  #8,a7

            move.w  sr,-(a7)                ; PSG : port B en entrée, STROBE à 1
            or.w    #$0700,sr
            move.b  #7,$ffff8800.w
            move.b  $ffff8800.w,d0
            move.b  d0,oldr7
            bclr    #7,d0
            move.b  d0,$ffff8802.w
            move.b  #14,$ffff8800.w
            move.b  $ffff8800.w,d0
            move.b  d0,oldr14
            bset    #5,d0
            move.b  d0,$ffff8802.w
            move.w  (a7)+,sr

; ---------------------------------------------------------------- boucle
loop        move.w  #37,-(a7)               ; Vsync
            trap    #14
            addq.l  #2,a7

            ; lecture du port parallèle (sélection + lecture en double :
            ; Hatari fige la valeur lue au moment de la sélection)
            move.w  sr,-(a7)
            or.w    #$0700,sr
            move.b  #15,$ffff8800.w
            move.b  $ffff8800.w,d0
            move.b  #15,$ffff8800.w
            move.b  $ffff8800.w,d0
            move.b  d0,pdata
            move.b  #14,$ffff8800.w
            move.b  $ffff8800.w,d1
            move.b  #14,$ffff8800.w
            move.b  $ffff8800.w,d1
            move.b  d1,d2
            bset    #5,d2                   ; STROBE reste à 1
            move.b  d2,$ffff8802.w
            move.b  d1,pstrobe
            move.b  $fffffa01.w,pbusy
            move.w  (a7)+,sr

            ; --- port 0 et port 1 : bits 0-3 directions (1 = appuyé), bit 7 tir
            moveq   #3,d7                   ; ligne 3
            move.b  joy0,d0
            lea     t_p0(pc),a1
            bsr     ikbdline
            moveq   #4,d7
            move.b  joy1,d0
            lea     t_p1(pc),a1
            bsr     ikbdline

            ; --- parallèle : directions actives à 0
            moveq   #6,d7
            move.b  pdata,d0
            not.b   d0
            and.b   #$0f,d0
            lea     t_lo(pc),a1
            bsr     dirline
            moveq   #7,d7
            move.b  pdata,d0
            not.b   d0
            lsr.b   #4,d0
            lea     t_hi(pc),a1
            bsr     dirline

            ; --- tirs du port parallèle
            moveq   #9,d7
            bsr     gotoline
            pea     t_busy(pc)
            bsr     print
            btst    #0,pbusy
            bsr     firestr
            pea     t_strobe(pc)
            bsr     print
            btst    #5,pstrobe
            bsr     firestr

            ; --- lignes brutes D7..D0
            moveq   #11,d7
            bsr     gotoline
            pea     t_raw(pc)
            bsr     print
            lea     bits(pc),a0
            move.b  pdata,d0
            moveq   #7,d1
.bit        moveq   #'0',d2
            btst    d1,d0
            beq.s   .z
            moveq   #'1',d2
.z          move.b  d2,(a0)+
            dbra    d1,.bit
            clr.b   (a0)
            pea     bits(pc)
            bsr     print

            move.w  #11,-(a7)               ; Cconis
            trap    #1
            addq.l  #2,a7
            tst.w   d0
            beq     loop
            move.w  #7,-(a7)                ; Crawcin
            trap    #1
            addq.l  #2,a7

; ---------------------------------------------------------------- sortie
            move.w  sr,-(a7)
            or.w    #$0700,sr
            move.b  #14,$ffff8800.w
            move.b  oldr14,$ffff8802.w
            move.b  #7,$ffff8800.w
            move.b  oldr7,$ffff8802.w
            move.w  (a7)+,sr
            move.l  kbdv,a0
            move.l  oldjoy,24(a0)
            pea     ikbd_mouse(pc)          ; souris relative : état du bureau
            move.w  #0,-(a7)
            move.w  #25,-(a7)
            trap    #14
            addq.l  #8,a7
            pea     bye(pc)
            bsr     print
            move.l  oldssp,-(a7)            ; retour en mode utilisateur
            move.w  #$20,-(a7)
            trap    #1
            addq.l  #6,a7
            clr.w   -(a7)
            trap    #1

; ---------------------------------------------------------------- routines
; print : chaîne sur la pile (pea), Cconws
print       move.l  4(a7),-(a7)
            move.w  #9,-(a7)
            trap    #1
            addq.l  #6,a7
            move.l  (a7)+,a0                ; retour
            addq.l  #4,a7                   ; retire l'argument
            jmp     (a0)

; gotoline : curseur en ligne d7, colonne 1
gotoline    lea     esc_y(pc),a0
            move.b  d7,d0
            add.b   #32,d0
            move.b  d0,2(a0)
            pea     (a0)
            bsr     print
            rts

; ikbdline : titre a1, octet IKBD d0 -> directions + tir
ikbdline    move.b  d0,d6
            and.b   #$0f,d0
            bsr     dirline
            btst    #7,d6
            seq     d0                      ; bit 7 = 1 : appuyé -> Z = 0
            tst.b   d0                      ; Z = 1 si appuyé (comme firestr)
            bsr     firestr
            rts

; dirline : ligne d7, titre a1, directions d0 (1 = appuyé, bits H B G D)
dirline     move.w  d0,-(a7)                ; GEMDOS écrase d0-d2/a0-a2
            move.l  a1,-(a7)
            bsr     gotoline
            bsr     print                   ; titre (déjà sur la pile)
            move.w  (a7)+,d0
            and.w   #$0f,d0
            add.w   d0,d0
            lea     dirtab(pc),a0
            adda.w  (a0,d0.w),a0
            move.l  a0,-(a7)
            bsr     print
            rts

; firestr : Z = 1 -> « TIR », sinon « --- » (lignes actives à 0)
firestr     beq.s   .on
            pea     s_off(pc)
            bra.s   .p
.on         pea     s_on(pc)
.p          bsr     print
            rts

; joyhand : appelé par le TOS (interruption IKBD) avec a0 -> tampon de
; 3 octets : en-tête ($FE ou $FF), joystick 0, joystick 1.
joyhand     move.b  1(a0),joy0
            move.b  2(a0),joy1
            rts

; ---------------------------------------------------------------- données
dirtab      dc.w    d_none-dirtab,d_u-dirtab,d_d-dirtab,d_x-dirtab
            dc.w    d_l-dirtab,d_ul-dirtab,d_dl-dirtab,d_x-dirtab
            dc.w    d_r-dirtab,d_ur-dirtab,d_dr-dirtab,d_x-dirtab
            dc.w    d_x-dirtab,d_x-dirtab,d_x-dirtab,d_x-dirtab
            ifd ENGLISH
d_none      dc.b    '---          ',0
d_u         dc.b    'Up           ',0
d_d         dc.b    'Down         ',0
d_l         dc.b    'Left         ',0
d_r         dc.b    'Right        ',0
d_ul        dc.b    'Up-Left      ',0
d_ur        dc.b    'Up-Right     ',0
d_dl        dc.b    'Down-Left    ',0
d_dr        dc.b    'Down-Right   ',0
d_x         dc.b    'Invalid      ',0
s_on        dc.b    'FIRE',0
s_off       dc.b    '--- ',0
t_p0        dc.b    'Port 0 (mouse)  : ',0
t_p1        dc.b    'Port 1          : ',0
t_lo        dc.b    'Parallel D0-D3  : ',0
t_hi        dc.b    'Parallel D4-D7  : ',0
t_busy      dc.b    'Fire BUSY: ',0
t_strobe    dc.b    '  Fire STROBE: ',0
t_raw       dc.b    'Lines D7..D0    : ',0
cls         dc.b    27,'E',27,'f'
            dc.b    'JOYTEST - joystick status',13,10
            dc.b    'Press any key to quit.',13,10,0
bye         dc.b    27,'E',27,'e',0
            else
d_none      dc.b    '---          ',0
d_u         dc.b    'Haut         ',0
d_d         dc.b    'Bas          ',0
d_l         dc.b    'Gauche       ',0
d_r         dc.b    'Droite       ',0
d_ul        dc.b    'Haut-Gauche  ',0
d_ur        dc.b    'Haut-Droite  ',0
d_dl        dc.b    'Bas-Gauche   ',0
d_dr        dc.b    'Bas-Droite   ',0
d_x         dc.b    'Incoherent   ',0
s_on        dc.b    'TIR ',0
s_off       dc.b    '--- ',0
t_p0        dc.b    'Port 0 (souris) : ',0
t_p1        dc.b    'Port 1          : ',0
t_lo        dc.b    'Parallele D0-D3 : ',0
t_hi        dc.b    'Parallele D4-D7 : ',0
t_busy      dc.b    'Tir BUSY : ',0
t_strobe    dc.b    '  Tir STROBE : ',0
t_raw       dc.b    'Lignes D7..D0   : ',0
cls         dc.b    27,'E',27,'f'
            dc.b    'JOYTEST - etat des joysticks',13,10
            dc.b    'Une touche pour quitter.',13,10,0
bye         dc.b    27,'E',27,'e',0
            endif
esc_y       dc.b    27,'Y',32,32+1,0
ikbd_joy    dc.b    $14
ikbd_mouse  dc.b    $08
            even

            section bss
oldssp      ds.l    1
oldjoy      ds.l    1
kbdv        ds.l    1
joy0        ds.b    1
joy1        ds.b    1
pdata       ds.b    1
pbusy       ds.b    1
pstrobe     ds.b    1
oldr7       ds.b    1
oldr14      ds.b    1
bits        ds.b    10
