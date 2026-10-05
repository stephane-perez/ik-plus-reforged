; ============================================================================
; IK_PLUS.TOS - chargeur d'IK+.
;
; IKPLUS.IMG est l'image mémoire du jeu ($53100 octets) à placer en $700,
; point d'entrée $1000, produite à partir de IK+.PRG par tools/patch_game.py.
; Comme le chargeur de IK+.PRG, on écrase le TOS, mais :
;  - le fichier est lu dans un bloc Malloc (pas d'adresse fixe) ; la routine
;    de recopie est posée juste après les données, donc hors de la source
;    et hors de la destination (bloc > $700 => fin > $53800) ;
;  - le « rte » des vecteurs non utilisés est en $6F0, sous l'image du jeu ;
;    tous les vecteurs $10-$3FC y pointent, y compris
;    ceux de la SCC du Mega STE ($180-$1BC) ;
;  - Mega STE : interruptions de la SCC coupées (WR9 = 0), 8 MHz sans cache ;
;  - STE / Mega STE : son DMA arrêté, registres vidéo STE remis à zéro ;
;  - un seul programme pour toutes les machines : sur un STE ou un Mega STE
;    (cookie _MCH = $00010000 ou $00010010) avec au moins 1 Mo, le module src/ste.s (son DMA, blitter)
;    est recopié en STEBASE et ses 9 accroches sont posées dans l'image lue,
;    après vérification des octets d'origine (table build/stehooks.i, tirée
;    de tools/patch_ste.py) ; sinon, le jeu tourne sans elles ;
;  - page d'introduction (logo IK+ et police du jeu, pris dans l'image lue :
;    rien du jeu dans ce programme) : F1, F2, F3 choisissent le joystick de
;    chaque joueur, mémorisé dans IKPLUS.CFG ; Espace pour continuer.
; Au départ : « LOADING » en haut à gauche, en blanc sur noir (VT52 du TOS,
; basse résolution). Diagnostic (couleur du fond) :
; rouge figé = erreur de bus / d'adresse avant que le jeu ait installé ses
; propres vecteurs.
; ============================================================================

SIZE        equ $53100              ; taille de IKPLUS.IMG
DEST        equ $700
STEBASE     equ $C0000              ; module STE : il faut un bloc Malloc qui finit dessous

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

            pea     prep(pc)                ; Supexec : machine, mémoire, clic clavier
            move.w  #$26,-(a7)
            trap    #14
            addq.l  #6,a7

            move.l  #SIZE+$200,-(a7)        ; Malloc : image + routine de recopie
            move.w  #$48,-(a7)
            trap    #1
            addq.l  #6,a7
            tst.l   d0
            beq     lderr
            addq.l  #3,d0                   ; aligné sur 4
            and.b   #$fc,d0
            move.l  d0,buf
            add.l   #SIZE+$200,d0           ; mode STE : le bloc doit finir sous STEBASE
            cmp.l   #STEBASE,d0
            bls.s   .blk
            clr.b   stecan
.blk

            bsr     loading                 ; « LOADING », blanc sur noir

            clr.w   -(a7)                   ; Fopen("IKPLUS.IMG", lecture)
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
            tst.b   stecan                  ; STE, 1 Mo : accroches du module STE
            beq.s   .nost
            bsr     stehook
.nost
            bsr     intro                   ; page d'introduction, Espace
            move.l  buf,a0                  ; choix des joysticks -> jeu (CTL de p3.s)
            add.l   #CTLADR-DEST,a0
            move.b  ctl,(a0)+
            move.b  ctl+1,(a0)+
            move.b  ctl+2,(a0)+
            move.b  train,(a0)+             ; TRAIN : mode entraînement

            ; au moins ~2 s depuis la fin de la lecture : laisser le lecteur
            ; de disquette s'arrêter (d7 = images déjà passées sur la page)
.vs         cmp.w   #100,d7
            bhs.s   .vsok
            move.w  #$25,-(a7)              ; Vsync
            trap    #14
            addq.l  #2,a7
            addq.w  #1,d7
            bra.s   .vs
.vsok

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

; loading : basse résolution, fond noir, « LOADING » en haut à gauche (police
; du TOS : la police du jeu n'est pas encore lue), souris et curseur cachés.
loading     dc.w    $a00a                   ; Line-A : souris cachée
            move.w  #4,-(a7)                ; Getrez
            trap    #14
            addq.l  #2,a7
            tst.w   d0
            beq.s   .low
            clr.w   -(a7)                   ; Setscreen(-1, -1, 0) : basse résolution
            moveq   #-1,d0
            move.l  d0,-(a7)
            move.l  d0,-(a7)
            move.w  #5,-(a7)
            trap    #14
            lea     12(a7),a7
.low        pea     ldpal(pc)               ; Setpalette : 0 noir, 15 blanc (texte)
            move.w  #6,-(a7)
            trap    #14
            addq.l  #6,a7
            clr.w   -(a7)                   ; Cursconf(0) : curseur caché
            move.w  #21,-(a7)
            trap    #14
            addq.l  #4,a7
            pea     ldmsg(pc)               ; Cconws
            move.w  #9,-(a7)
            trap    #1
            addq.l  #6,a7
            move.w  #$25,-(a7)              ; Vsync : la palette est posée
            trap    #14
            addq.l  #2,a7
            rts

; stehook : pose les accroches du module STE (table stehooks) dans l'image
; lue, si les octets d'origine de toutes sont bien là ; stemode = 1 alors.
stehook     lea     stehooks,a0             ; 1. vérification
.ck         move.l  (a0)+,d0
            beq.s   .ok
            move.w  (a0)+,d1
            move.l  buf,a1
            add.l   d0,a1
            sub.l   #DEST,a1
            subq.w  #1,d1
            move.w  d1,d2
.cb         cmpm.b  (a0)+,(a1)+
            bne.s   .no
            dbra    d1,.cb
            lea     1(a0,d2.w),a0           ; nouveaux octets sautés
            bra.s   .ck
.ok         lea     stehooks,a0             ; 2. pose
.pt         move.l  (a0)+,d0
            beq.s   .done
            move.w  (a0)+,d1
            move.l  buf,a1
            add.l   d0,a1
            sub.l   #DEST,a1
            add.w   d1,a0                   ; octets d'origine sautés
            subq.w  #1,d1
.pb         move.b  (a0)+,(a1)+
            dbra    d1,.pb
            bra.s   .pt
.done       move.b  #1,stemode
.no         rts

; ----------------------------------------------------------------------------
; intro : page d'introduction, sous le TOS (mode utilisateur).
; Logo IK+ : image 160 x 121 en 16 couleurs, rangée dans le jeu en LOGO
; (lignes 5 à 111 utiles, couleurs 9 à 15) ; police 8 x 8 du jeu en FONT
; (un plan, 8 octets par lettre, index = code - '0', comme F_084C0).
; Sortie : d7 = nombre d'images passées à attendre Espace.
; ----------------------------------------------------------------------------
LOGO        equ $1b678
FONT        equ $9736
CTLADR      equ $850                        ; CTL dans src/p3.s : sources des joueurs, puis TRAIN
NSRC        equ 7                           ; sources 0 à 6 (6 = aucune)
NAMECOL     equ 26                          ; colonne du nom de la source
ROW1        equ 112                         ; ligne du joueur 1 (puis +RSTEP)
RSTEP       equ 10                          ; 8 lignes de lettres + 2 d'écart

intro       bsr     loadcfg
            dc.w    $a00a                   ; Line-A : souris cachée
            clr.w   -(a7)                   ; Cursconf(0) : curseur caché
            move.w  #21,-(a7)
            trap    #14
            addq.l  #4,a7
            move.w  #4,-(a7)                ; Getrez
            trap    #14
            addq.l  #2,a7
            tst.w   d0
            beq.s   .low
            clr.w   -(a7)                   ; Setscreen(-1, -1, 0) : basse résolution
            moveq   #-1,d0
            move.l  d0,-(a7)
            move.l  d0,-(a7)
            move.w  #5,-(a7)
            trap    #14
            lea     12(a7),a7
.low        move.w  #2,-(a7)                ; Physbase
            trap    #14
            addq.l  #2,a7
            move.l  d0,a6                   ; a6 = écran
            move.l  a6,a0
            move.w  #32000/4-1,d0
.cls        clr.l   (a0)+
            dbra    d0,.cls
            pea     pal(pc)                 ; Setpalette
            move.w  #6,-(a7)
            trap    #14
            addq.l  #6,a7

            ; logo : lignes 5 à 111 de l'image, tout en haut (y = 0), centré
            move.l  buf,a0
            add.l   #LOGO-DEST+5*160,a0
            lea     40(a6),a1
            move.w  #111-5,d0
.lg         moveq   #80/4-1,d1
.lgw        move.l  (a0)+,(a1)+
            dbra    d1,.lgw
            lea     80(a0),a0
            lea     80(a1),a1
            dbra    d0,.lg

            lea     texts(pc),a5
.tx         move.b  (a5)+,d2                ; couleur (0 = fin)
            beq.s   .txe
            moveq   #0,d0
            move.b  (a5)+,d0                ; ligne de l'écran
            moveq   #0,d1
            move.b  (a5)+,d1                ; colonne (255 = centré)
            bsr     dtext
            bra.s   .tx
.txe        bsr     dtrain                  ; ligne F4 (mode entraînement)
            moveq   #0,d5                   ; noms des sources des 3 joueurs
.nm         bsr     dname
            addq.w  #1,d5
            cmp.w   #3,d5
            blo.s   .nm
            ; clavier : touches en attente vidées, puis attente d'Espace
.fl         move.w  #2,-(a7)                ; Bconstat(clavier)
            move.w  #1,-(a7)
            trap    #13
            addq.l  #4,a7
            tst.w   d0
            beq.s   .wait
            bsr     getkey
            bra.s   .fl
.wait       moveq   #0,d7
.wk         move.w  #2,-(a7)
            move.w  #1,-(a7)
            trap    #13
            addq.l  #4,a7
            tst.w   d0
            bne.s   .key
            move.w  #$25,-(a7)              ; Vsync
            trap    #14
            addq.l  #2,a7
            cmp.w   #$7fff,d7
            beq.s   .wk
            addq.w  #1,d7
            bra.s   .wk
.key        bsr     getkey
            cmp.b   #' ',d0
            beq.s   .go
            swap    d0                      ; code de la touche
            sub.b   #$3b,d0                 ; F1, F2, F3 -> 0, 1, 2 ; F4 -> 3
            cmp.b   #3,d0
            beq.s   .f4
            bhs.s   .wk
            moveq   #0,d5
            move.b  d0,d5
            bsr     nextsrc
            bsr     dname
            bra.s   .wk
.f4         eori.b  #1,train                ; mode entraînement (jamais mémorisé)
            bsr     dtrain
            bra     .wk
.go         lea     tblank(pc),a5           ; « PLEASE WAIT » à la place de
            moveq   #2,d2                   ; « PRESS SPACE TO START »
            moveq   #0,d0
            move.b  -2(a5),d0
            moveq   #0,d1
            move.b  -1(a5),d1
            bsr     dtext
            lea     twait(pc),a5
            moveq   #0,d0
            move.b  -2(a5),d0
            moveq   #-1,d1
            bsr     dtext
            bsr     savecfg
            beq.s   .r
            moveq   #0,d7                   ; fichier écrit : ~2 s pour le lecteur
.r          rts

; dtrain : ligne « F4 TRAINING MODE », grise (arrêt) ou verte (marche).
dtrain      movem.l d0-d7/a0-a6,-(a7)
            lea     ttrain(pc),a5
            moveq   #3,d2
            tst.b   train
            beq.s   .off
            moveq   #4,d2
.off        moveq   #0,d0
            move.b  -2(a5),d0
            moveq   #0,d1
            move.b  -1(a5),d1
            bsr     dtext
            movem.l (a7)+,d0-d7/a0-a6
            rts

; prep (superviseur) : STE ? (cookie _MCH = $00010000 : ports étendus) ;
; Mega STE ? ($00010010) ; STE ou Mega STE avec au moins 1 Mo (phystop) :
; mode STE possible (son DMA, blitter) ; clic clavier coupé (conterm, bit 0).
prep        bclr    #0,$484.w
            bsr.s   .mch
            move.b  isste,d0
            or.b    ismste,d0
            beq.s   .r
            cmp.l   #$100000,$42e.w
            shs     stecan
.r          rts
.mch        move.l  $5a0.w,d0
            beq.s   .x
            move.l  d0,a0
.cj         move.l  (a0)+,d0
            beq.s   .x
            move.l  (a0)+,d1
            cmp.l   #'_MCH',d0
            bne.s   .cj
            cmp.l   #$00010000,d1
            seq     isste
            cmp.l   #$00010010,d1
            seq     ismste
.x          rts

; ok : d0 = 0 si la source d0 est permise pour le joueur d5 (0 à 2),
; compte tenu des deux autres joueurs. Détruit d1, a0.
ok          cmp.b   #6,d0                   ; « aucun » : joueur 3 seulement
            bne.s   .n6
            cmp.w   #2,d5
            bne.s   .no
            bra.s   .yes
.n6         cmp.b   #4,d0                   ; manettes : STE seulement
            blo.s   .np
            tst.b   isste
            beq.s   .no
.np         lea     ctl,a0                  ; pas déjà prise par un autre joueur
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
nextsrc     lea     ctl,a1
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
.set        lea     ctl,a1
            move.b  d0,(a1,d5.w)
            rts

; dname : affiche le nom de la source du joueur d5.
dname       movem.l d0-d7/a0-a6,-(a7)
            lea     ctl,a0
            moveq   #0,d0
            move.b  (a0,d5.w),d0
            mulu    #11,d0
            lea     names(pc),a5
            add.w   d0,a5
            moveq   #RSTEP,d0               ; ligne ROW1 + RSTEP x joueur
            mulu    d5,d0
            add.w   #ROW1,d0
            moveq   #NAMECOL,d1
            moveq   #1,d2
            bsr     dtext
            movem.l (a7)+,d0-d7/a0-a6
            rts

; loadcfg : IKPLUS.CFG (4 octets : 'I', puis les sources des joueurs 1 à 3).
; Fichier absent ou incohérent : choix par défaut.
loadcfg     clr.w   -(a7)                   ; Fopen(lecture)
            pea     cfgname(pc)
            move.w  #$3d,-(a7)
            trap    #1
            addq.l  #8,a7
            tst.l   d0
            bmi.s   .def
            move.w  d0,d3
            pea     cfgbuf
            move.l  #4,-(a7)
            move.w  d3,-(a7)
            move.w  #$3f,-(a7)              ; Fread
            trap    #1
            lea     12(a7),a7
            move.l  d0,d4
            move.w  d3,-(a7)                ; Fclose
            move.w  #$3e,-(a7)
            trap    #1
            addq.l  #4,a7
            cmp.l   #4,d4
            bne.s   .def
            lea     cfgbuf,a1
            cmp.b   #'I',(a1)+
            bne.s   .def
            lea     ctl,a2                  ; vérifié joueur par joueur
            move.l  #$ffffffff,(a2)
            moveq   #0,d5
.ck         move.b  (a1)+,d0
            cmp.b   #NSRC,d0
            bhs.s   .def
            bsr     ok
            tst.w   d1
            bne.s   .def
            lea     ctl,a2
            move.b  d0,(a2,d5.w)
            addq.w  #1,d5
            cmp.w   #3,d5
            blo.s   .ck
            move.l  ctl,cfgold
            rts
.def        move.l  defctl(pc),ctl
            tst.b   isste                   ; STE : joueur 3 sur la manette A
            beq.s   .dp
            move.b  #4,ctl+2
.dp            move.l  #-1,cfgold              ; rien de lu : à écrire
            rts

; savecfg : écrit IKPLUS.CFG si le choix a changé. Disquette protégée en
; écriture, disque plein ou autre erreur : rien, sans message (le
; gestionnaire d'erreurs critiques du TOS est remplacé le temps de l'écriture).
; Sortie : Z = 1 si rien n'a été écrit.
savecfg     move.l  ctl,d0
            cmp.l   cfgold,d0
            beq     .none
            pea     critic(pc)              ; Setexc($101) : etv_critic
            move.w  #$101,-(a7)
            move.w  #5,-(a7)
            trap    #13
            addq.l  #8,a7
            move.l  d0,oldcrit
            clr.w   -(a7)                   ; Fcreate
            pea     cfgname(pc)
            move.w  #$3c,-(a7)
            trap    #1
            addq.l  #8,a7
            tst.l   d0
            bmi.s   .rest
            move.w  d0,d3
            lea     cfgbuf,a0
            move.b  #'I',(a0)+
            move.b  ctl,(a0)+
            move.b  ctl+1,(a0)+
            move.b  ctl+2,(a0)+
            pea     cfgbuf
            move.l  #4,-(a7)
            move.w  d3,-(a7)
            move.w  #$40,-(a7)              ; Fwrite
            trap    #1
            lea     12(a7),a7
            move.w  d3,-(a7)                ; Fclose
            move.w  #$3e,-(a7)
            trap    #1
            addq.l  #4,a7
.rest       move.l  oldcrit,-(a7)           ; ancien etv_critic
            move.w  #$101,-(a7)
            move.w  #5,-(a7)
            trap    #13
            addq.l  #8,a7
            moveq   #1,d0                   ; Z = 0 : le lecteur a pu tourner
            rts
.none       moveq   #0,d0
            rts

; etv_critic : renvoie l'erreur telle quelle (pas de boîte d'alerte).
critic      move.w  4(a7),d0
            ext.l   d0
            rts

getkey      move.w  #2,-(a7)                ; Bconin(clavier)
            move.w  #2,-(a7)
            trap    #13
            addq.l  #4,a7
            rts

; dtext : a5 = texte (terminé par 0, avancé après), d0 = ligne de l'écran,
; d1 = colonne de 8 pixels (255 = centré), d2 = couleur (1 à 15), a6 = écran.
dtext       move.l  a5,a0
.len        tst.b   (a0)+
            bne.s   .len
            move.l  a0,d3
            sub.l   a5,d3
            subq.w  #1,d3                   ; d3 = longueur
            cmp.b   #255,d1
            bne.s   .col
            moveq   #40,d1
            sub.w   d3,d1
            lsr.w   #1,d1
.col        mulu    #160,d0
            lea     (a6,d0.l),a1            ; a1 = début de la ligne
.ch         moveq   #0,d0
            move.b  (a5)+,d0
            beq     .end
            move.l  buf,a2                  ; police du jeu
            add.l   #FONT-DEST,a2
            cmp.b   #' ',d0
            bne.s   .nsp
            moveq   #'@',d0                 ; espace du jeu (lettre vide)
.nsp        cmp.b   #':',d0
            bne.s   .ncl
            moveq   #'=',d0                 ; le « = » du jeu a la forme de « : »
.ncl        cmp.b   #'-',d0
            bne.s   .nmi
            moveq   #$5c,d0                 ; le « - » du jeu : lettre 44 ($5C - '0')
.nmi        cmp.b   #'.',d0
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
            add.w   d0,a2                   ; a2 = 8 octets de la lettre
            move.w  d1,d0                   ; octet de la case : (col/2)*8 + col&1
            lsr.w   #1,d0
            lsl.w   #3,d0
            btst    #0,d1
            beq.s   .ev
            addq.w  #1,d0
.ev         lea     (a1,d0.w),a3
            moveq   #7,d4
.row        move.b  (a2)+,d5
            move.l  a3,a4
            moveq   #0,d6                   ; plan 0 à 3
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

; « ( », « ) » et « . », absents de la police du jeu
gparen      dc.b    $0c,$18,$30,$30,$30,$18,$0c,$00
            dc.b    $30,$18,$0c,$0c,$0c,$18,$30,$00
gdot        dc.b    $00,$00,$00,$00,$00,$18,$18,$00

; couleurs : 0 noir, 1 blanc, 2 jaune, 3 gris, 4 vert ; 9 à 15 : celles du
; logo dans l'introduction du jeu (rouges, noir, gris clair)
pal         dc.w    $000,$777,$750,$444,$070,$000,$000,$000
            dc.w    $000,$300,$400,$500,$600,$700,$000,$666

; textes : couleur, ligne, colonne (255 = centré), texte, 0
texts       dc.b    13,49,1,'REFORGED',0     ; à gauche du logo (cases 10 à 29)
            dc.b    13,49,31,'EDITION',0     ; à droite
            dc.b    1,ROW1,3,'F1  PLAYER 1 (WHITE) :',0
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
; « PRESS SPACE TO START » centré entre la fin de la ligne F4 et la ligne
; « ENHANCED BY CLAUDE AI » (180)
TROW        equ     (ROW1+3*RSTEP+8+180-8)/2
            dc.b    ROW1+3*RSTEP,3          ; (ligne, colonne de ttrain)
ttrain      dc.b    'F4  TRAINING MODE (NO TIME LIMIT)',0
            dc.b    TROW,10
tblank      dc.b    '                    ',0
            dc.b    TROW,0
twait       dc.b    'PLEASE WAIT',0
; noms des sources (10 lettres + 0), dans l'ordre de vblmap (src/p3.s)
names       dc.b    'JOYSTICK 0',0,'JOYSTICK 1',0,'JOYSTICK 2',0,'JOYSTICK 3',0
            dc.b    'JOYPAD A  ',0,'JOYPAD B  ',0,'NONE      ',0
cfgname     dc.b    'IKPLUS.CFG',0
            even
; choix par défaut : joueur 1 = joystick 1, joueur 2 = joystick 0 (comme le
; jeu d'origine), joueur 3 = prise 3 (manette A sur STE, voir loadcfg)
defctl      dc.b    1,0,2,0

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
            move.b  stemode,stubste         ; pour la routine de recopie
            beq.s   .nste
            lea     steblob,a0              ; module STE en STEBASE
            lea     STEBASE,a1
            move.w  #(steend-steblob)/2-1,d0
.cs         move.w  (a0)+,(a1)+
            dbra    d0,.cs
.nste

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
            move.b  stubste(pc),d0
            beq.s   .go
            lea     STEBASE+$10000,a7       ; pile hors de l'image du jeu
            jsr     STEBASE                 ; init : sons rééchantillonnés
.go
            movem.l regs(pc),d0-d7/a0-a7    ; registres au départ du jeu (pile en $F28)
            jmp     $1000.w
regs        dc.l    $ffff,$ffff,$123400fb,0,0,$1f33a,$ffff,$ffff
            dc.l    $97c,$946,$70000,0,$fffffa01,$ffff8604,$ffff8606,$f28
stubste     dc.w    0                       ; 1 : module STE en place
stubend

fname       dc.b    'IKPLUS.IMG',0
ldmsg       dc.b    27,'E','LOADING',0      ; écran effacé, curseur en haut à gauche
            even
ldpal       dc.w    $000,$000,$000,$000,$000,$000,$000,$000
            dc.w    $000,$000,$000,$000,$000,$000,$000,$777
errmsg      dc.b    13,10,'IK+ : IKPLUS.IMG introuvable ou memoire insuffisante.',13,10,0
            even
            section data
            even
steblob     incbin  "build/ste.bin"
            even
steend
            include "build/stehooks.i"
            even

            section bss
buf         ds.l    1
ctl         ds.l    1                       ; sources des joueurs 1 à 3 (+ 1 octet)
cfgold      ds.l    1                       ; ce qui a été lu dans IKPLUS.CFG
cfgbuf      ds.l    1
oldcrit     ds.l    1
isste       ds.b    1                       ; STE : ports étendus (manettes)
train       ds.b    1                       ; mode entraînement choisi (F4)
ismste      ds.b    1                       ; Mega STE
stecan      ds.b    1                       ; STE ou Mega STE avec 1 Mo : mode STE possible
stemode     ds.b    1                       ; accroches STE posées
            even
fh          ds.w    1
            ds.b    1024
mystack
