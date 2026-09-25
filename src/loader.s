; ============================================================================
; IK_PLUS.TOS - chargeur d'IK+ sans intro ni écran pirate.
; Remplace IK_PLUS.TOS + BLADERUN.DT0 + BLADERUN.DT1 : seul ATOR.EXE est lu.
;
; ATOR.EXE est l'image mémoire du jeu ($53100 octets) à placer en $700,
; point d'entrée $1000. Comme BLADERUN.DT1, on écrase le TOS, mais :
;  - le fichier est lu dans un bloc Malloc (pas d'adresse fixe) ; la routine
;    de recopie est posée juste après les données, donc hors de la source
;    et hors de la destination (bloc > $700 => fin > $53800) ;
;  - le « rte » des vecteurs non utilisés est en $6F0, sous l'image du jeu,
;    et non en $7F000 (au milieu du 2e écran du jeu) ; tous les vecteurs
;    $10-$3FC y pointent (DT1 s'arrêtait à $1A4, avant ceux de la SCC) ;
;  - Mega STE : interruptions de la SCC coupées (WR9 = 0), 8 MHz sans cache ;
;  - STE / Mega STE : son DMA arrêté, registres vidéo STE remis à zéro.
; Diagnostic (couleur du fond) : bleu = chargement, vert = saut dans le jeu,
; rouge figé = erreur de bus / d'adresse avant que le jeu ait installé ses
; propres vecteurs.
; ============================================================================

SIZE        equ $53100              ; taille de ATOR.EXE
DEST        equ $700

            section text
start       move.l  4(a7),a5                ; basepage
            lea     mystack,a7
            move.l  $c(a5),d0               ; Mshrink : texte + données + bss + $100
            add.l   $14(a5),d0
            add.l   $1c(a5),d0
            add.l   #$100,d0
            move.l  d0,-(a7)
            move.l  a5,-(a7)
            clr.w   -(a7)
            move.w  #$4a,-(a7)
            trap    #1
            lea     12(a7),a7

            move.l  #SIZE+$200,-(a7)        ; Malloc : image + routine de recopie
            move.w  #$48,-(a7)
            trap    #1
            addq.l  #6,a7
            tst.l   d0
            beq     lderr
            addq.l  #3,d0                   ; aligné sur 4
            and.b   #$fc,d0
            move.l  d0,buf

            pea     setblue(pc)             ; fond bleu pendant le chargement
            move.w  #$26,-(a7)
            trap    #14
            addq.l  #6,a7

            clr.w   -(a7)                   ; Fopen("ATOR.EXE", lecture)
            pea     fname(pc)
            move.w  #$3d,-(a7)
            trap    #1
            addq.l  #8,a7
            tst.l   d0
            bmi     lderr
            move.w  d0,fh
            move.l  buf,-(a7)               ; Fread
            move.l  #SIZE,-(a7)
            move.w  fh,-(a7)
            move.w  #$3f,-(a7)
            trap    #1
            lea     12(a7),a7
            move.l  d0,d7
            move.w  fh,-(a7)                ; Fclose
            move.w  #$3e,-(a7)
            trap    #1
            addq.l  #4,a7
            cmp.l   #SIZE,d7
            bne     lderr

            move.w  #99,d7                  ; ~2 s : laisser le lecteur s'arrêter (comme DT1)
.vs         move.w  #$25,-(a7)              ; Vsync
            trap    #14
            addq.l  #2,a7
            dbra    d7,.vs

            pea     go(pc)                  ; Supexec : ne revient pas
            move.w  #$26,-(a7)
            trap    #14

lderr        pea     errmsg(pc)
            move.w  #9,-(a7)
            trap    #1
            addq.l  #6,a7
            move.w  #7,-(a7)                ; Crawcin
            trap    #1
            addq.l  #2,a7
            clr.w   -(a7)
            trap    #1

setblue     move.w  #$007,$ffff8240.w
            rts

; ----------------------------------------------------------------------------
; go (superviseur) : le TOS est encore là tant qu'on n'a pas recopié.
; ----------------------------------------------------------------------------
go          move.w  #$2700,sr
            ; type de machine : cookie _MCH (TOS >= 1.06), sinon STF
            moveq   #0,d6
            move.l  $5a0.w,d0
            beq.s   .nocj
            move.l  d0,a0
.cj         move.l  (a0)+,d0
            beq.s   .nocj
            move.l  (a0)+,d1
            cmp.l   #'_MCH',d0
            bne.s   .cj
            move.l  d1,d6
.nocj
            swap    d6                      ; 0 = ST, 1 = STE/Mega STE, 2 = TT...
            cmp.w   #1,d6
            bne.s   .nost
            clr.b   $ffff8901.w             ; son DMA arrêté
            clr.b   $ffff820f.w             ; largeur de ligne en plus
            clr.b   $ffff8265.w             ; décalage horizontal
            clr.b   $ffff820d.w             ; adresse vidéo, octet bas
            swap    d6
            cmp.w   #$10,d6                 ; Mega STE ?
            bne.s   .nost
            ; SCC : WR9 = 0 (plus d'interruptions), via le canal A
            tst.b   $ffff8c81.w             ; remet le pointeur de registre à 0
            nop
            nop
            move.b  #9,$ffff8c81.w
            nop
            nop
            move.b  #0,$ffff8c81.w
            nop
            nop
            clr.b   $ffff8e21.w             ; 8 MHz, cache coupé
.nost
            ; vecteurs : rte en $6F0, arrêt rouge en $6E0 (bus/adresse)
            move.w  #$4e73,$6f0.w           ; rte
            move.l  #$31fc0700,$6e0.w       ; move.w #$700,$ffff8240.w
            move.w  #$8240,$6e4.w
            move.w  #$60fe,$6e6.w           ; bra.s *
            move.l  #$6e0,$8.w
            move.l  #$6e0,$c.w
            lea     $10.w,a0
            move.w  #($400-$10)/4-1,d0
.vec        move.l  #$6f0,(a0)+
            dbra    d0,.vec
            move.w  #$070,$ffff8240.w       ; vert : on saute dans le jeu

            ; routine de recopie posée après les données
            move.l  buf,a0
            move.l  a0,a1
            adda.l  #SIZE,a1
            move.l  a1,a2
            lea     stub(pc),a3
            move.w  #(stubend-stub)/2-1,d0
.cp         move.w  (a3)+,(a1)+
            dbra    d0,.cp
            jmp     (a2)                    ; a0 = source

; position indépendante : ne dépend que de a0 et de sa table
stub        lea     DEST.w,a1
            move.l  #SIZE/4-1,d0
.l          move.l  (a0)+,(a1)+
            subq.l  #1,d0
            bpl.s   .l
            movem.l regs(pc),d0-d7/a0-a7    ; état laissé par BLADERUN.DT1
            jmp     $1000.w
regs        dc.l    $ffff,$ffff,$123400fb,0,0,$1f33a,$ffff,$ffff
            dc.l    $97c,$946,$70000,0,$fffffa01,$ffff8604,$ffff8606,$f28
stubend

fname       dc.b    'ATOR.EXE',0
errmsg      dc.b    13,10,'IK+ : ATOR.EXE introuvable ou memoire insuffisante.',13,10,0
            even

            section bss
buf         ds.l    1
fh          ds.w    1
            ds.b    1024
mystack
