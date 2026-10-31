; ============================================================================
; IK+ (Atari ST) - code en plus, hors de la zone de 1 Ko de p3.s.
;
; Assemblé en $6A4A, dans le corps de la vérification de la disquette
; (F_06A40) : depuis la v7, patch_game.py saute de $6A44 à $6AF8, et rien
; d'autre ne va dans $6A48-$6AF7. Place : $6A4A-$6AF7 (174 octets).
;
; Mode entraînement (choisi sur la page d'introduction, jamais mémorisé) :
; pendant une partie (au moins un humain), le temps du round ($11FB, en BCD)
; ne baisse plus et s'affiche « -- », et personne ne marque de points de
; round ($11EE-$11F0) : le round ne finit jamais. Le chronomètre des parties
; à 3 (gamesec, dans p3.s) s'arrête aussi. La démo et les épreuves bonus
; (leur propre chronomètre) ne changent pas.
; ============================================================================

TRAIN       equ $853            ; écrit par le chargeur (après CTL, voir p3.s)
P1          equ $1007           ; drapeaux humain : combattants 0,1,2
P2          equ $1008
P3          equ $1009

            org $6a4a

; --- entrées fixes (patch_p3.py) --------------------------------------------
            bra.w timechk       ; $6A4A  VBL ($1DBA) : chronomètre du round
            bra.w timedisp      ; $6A4E  F_07536 ($7564) : affichage du temps
            bra.w ptschk        ; $6A52  F_08564 ($8586) : points de round
            bra.w restart       ; $6A56  $1C9C : retour en P_014FA par rte

; acia ($6A5A, adresse fixe : bra.w depuis $2496) : suite du gestionnaire de
; l'ACIA du clavier (P_02492), dont l'accroche 34 remplace les deux premières
; instructions, « movem.l d0-d2/a0-a2,-(a7) / clr.w $102c.w », par
; « move.w #$2500,sr / bra.w acia ». Le MFP est en fin d'interruption
; automatique (VR = $40) : seul le masque du 68000 (niveau 6 pendant le
; gestionnaire) empêchait le raster (Timer B, prioritaire dans le MFP) de
; passer. Un octet de l'IKBD reçu juste avant une interruption raster la
; retardait de ~300 cycles : couleurs écrites au milieu de la ligne
; suivante (ligne noire vers les pieds, ligne 190, sur STE). Masque à 5 dès
; la première instruction : le raster interrompt le gestionnaire ; la VBL
; (niveau 4) reste masquée.
acia        movem.l d0-d2/a0-a2,-(a7)
            clr.w   $102c.w
            jmp     $249a
            if acia!=$6a5a
            fail "acia doit rester en $6A5A (accroche 34)"
            endif

; training : Z = 1 si le mode entraînement s'applique. Détruit d0.
training    tst.b   TRAIN.w
            beq.s   .no
            move.b  P1.w,d0
            or.b    P2.w,d0
            or.b    P3.w,d0
            beq.s   .no
            moveq   #0,d0                   ; Z = 1
            rts
.no         moveq   #1,d0                   ; Z = 0
            rts

; timechk : remplace « move.b $11fb.w,d0 / beq.w L_01DD2 » ($1DBA, VBL, une
; fois par seconde de combat), suivi de « beq.s L_01DD2 ». Sortie : Z = 1
; pour ne pas toucher au temps (entraînement, ou temps déjà à 0).
timechk     bsr.s   training
            beq.s   .r
            move.b  $11fb.w,d0
.r          rts

; timedisp : remplace « move.w #$26,d1 / move.b $11fb.w,d0 » ($7564, F_07536,
; deux chiffres du temps en cases $26-$27). Entraînement : « -- » (lettre 44
; de la police du jeu), et retour direct de F_07536.
timedisp    move.w  #$26,d1
            bsr.s   training
            beq.s   .dash
            move.b  $11fb.w,d0
            rts
.dash       moveq   #44,d0
            jsr     $84c0
            addq.w  #1,d1
            jsr     $84c0
            addq.l  #4,a7                   ; fin de F_07536
            rts

; ptschk : remplace « move.b $125e.w,d0 / add.b d0,(a0,d2.w) » ($8586,
; F_08564 : points de round du joueur d2, a0 = $11EE). Entraînement : rien.
ptschk      bsr.s   training
            beq.s   .r
            move.b  $125e.w,d0
            add.b   d0,(a0,d2.w)
.r          rts

; restart : remplace « move.l #P_014FA,-(a7) / move.w #$2300,-(a7) / rte »
; ($1C9C : nouvelle partie demandée, pile remise à zéro juste avant). Le jeu
; fabrique là un cadre d'exception de 68000 (SR, PC). Les 68010 et plus
; (Falcon030 : `_longframe`, en $59E, non nul) attendent en plus un mot de
; format après le PC : sans lui, rte repart n'importe où.
restart     tst.w   $59e.w
            beq.s   .short
            clr.w   -(a7)                   ; format 0, vecteur 0
.short      move.l  #$14fa,-(a7)
            move.w  #$2300,-(a7)
            rte

end_p3b
            if end_p3b>$6af8
            fail "code en plus trop long ($6A4A-$6AF7)"
            endif
