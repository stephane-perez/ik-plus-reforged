; ============================================================================
; IK+ (Atari ST) - mode 3 joueurs : joueur 3 sur l'adaptateur joystick
; du port parallèle (type Gauntlet II / Leatherneck, prise « joystick 3 »).
;
; Assemblé en $800, dans l'ancien chargeur de boot inutilisé ($704-$9xx,
; contourné par le crack : $1000 saute directement en $14E6). La pile du jeu
; part de $F28 et ne descend pas sous $E64 : $800-$BFF est libre.
;
; Principe :
;  - le jeu range déjà tout par combattant (0 blanc, 1 rouge, 2 bleu) ;
;    $1009 = « combattant 2 humain » existe mais n'est jamais mis à 1 ;
;  - joystick du joueur i en $126C+i : on écrit le 3e en $126E, au format du
;    jeu (bits 0-3 directions actives à 0, bit 4 = feu) ;
;  - pendant une partie (au moins un humain), F3 fait passer le bleu
;    humain <-> ordinateur (F3 ne gère plus la musique, toujours active) ;
;  - dès que le joueur 3 est là : plus d'élimination, et la partie se
;    termine après LIMIT secondes de combat cumulées (chronomètre du jeu).
;
; Adaptateur (câblage vérifié sur machine réelle avec JOYTEST) :
;  prise « joystick 3 » : directions D4-D7 (0 = appuyé), tir sur BUSY (GPIP bit 0) ;
;  prise « joystick 4 » (-DPORT4) : directions D0-D3, tir sur STROBE (PSG port A
;  bit 5). Hatari : « parport stick 1 » / « 2 ».
; ============================================================================

            ifnd LIMIT
LIMIT       equ 300             ; durée d'une partie à 3 (secondes de combat)
            endif

P1          equ $1007           ; drapeaux humain : combattants 0,1,2
P2          equ $1008
P3          equ $1009
STATE       equ $1076           ; état principal (1 = partie en cours)
JOY3        equ $126E           ; joystick du joueur 3 (après $126C/$126D)
SCRA        equ $78000          ; les deux écrans du jeu
SCRB        equ $70000
BLIT        equ $126CC          ; F_126CC : affiche un bloc 16 x d6+1
FIST_GFX    equ $198C8          ; poing (celui du rouge)
BLANK_GFX   equ $198D0          ; bloc vide (effacement)
FIST_X      equ $78             ; blanc $28, rouge $50, bleu $78 (octets)

            org $800

; --- entrées fixes (les correctifs du jeu sautent ici) ----------------------
            bra.w pre           ; $800  début de F_07732 (chaque image de combat)
            bra.w looptail      ; $804  fin de boucle de F_07732
            bra.w other         ; $808  « l'autre humain » de F_07732
            bra.w elim          ; $80C  fin de round : élimination / fin de partie
            bra.w tick          ; $810  chronomètre, une fois par seconde
            bra.w erasehook     ; $814  F_07680 (efface le poing du combattant d2)
            bra.w drawhook      ; $818  F_0765C (dessine le poing du combattant d2)
            bra.w roundend      ; $81C  fin de round : masque des humains qui restent
            bra.w roundmsg      ; $820  message de fin de round ($1092)
            bra.w f3key         ; $824  touche F3 : joueur 3 oui / non

; --- variables ----------------------------------------------------------------
gamesec     dc.w 0              ; secondes de combat depuis l'arrivée du joueur 3
fiston      dc.b 0              ; poing bleu affiché ?
            even

; ----------------------------------------------------------------------------
; pre : remplace « clr.w d0 / clr.w d1 / clr.w d2 » au début de F_07732.
; Contexte : boucle principale (pas une interruption), donc on peut
; sélectionner un registre du PSG, en masquant les IRQ le temps de la lecture.
; ----------------------------------------------------------------------------
pre         movem.l d0-d2/a0,-(a7)
            move.w  sr,-(a7)
            or.w    #$0700,sr
            ; Port B du PSG (données du port parallèle) en ENTRÉE : la routine
            ; son du jeu ($B2B6) écrit sans cesse $DC dans le registre 7, dont
            ; le bit 7 met le port B en sortie. On relirait alors notre propre
            ; sortie au lieu des joysticks (Hatari ignore ce bit, pas la machine).
            move.b  #7,$ffff8800.w
            move.b  $ffff8800.w,d1
            bclr    #7,d1
            move.b  d1,$ffff8802.w
            ifd PORT4
            ; prise « joystick 4 » : directions sur D0-D3, tir sur STROBE
            ; (bit 5 du port A du PSG). Le jeu met STROBE à 0 : on le remet
            ; à 1, sinon le bouton serait toujours vu appuyé.
            ; Sélection + lecture deux fois : sous Hatari la valeur lue est
            ; figée à la sélection ; sur la machine, on lit l'état des broches.
            move.b  #14,$ffff8800.w
            move.b  $ffff8800.w,d1
            move.b  #14,$ffff8800.w
            move.b  $ffff8800.w,d1          ; bit 5 = tir, 0 = appuyé
            move.b  d1,d2
            bset    #5,d2                   ; STROBE remis à 1
            move.b  d2,$ffff8802.w
            move.b  #15,$ffff8800.w
            move.b  $ffff8800.w,d0          ; D0-D3 : directions, actives à 0
            move.w  (a7)+,sr
            andi.b  #$0f,d0
            btst    #5,d1
            else
            ; prise « joystick 3 » : directions sur D4-D7, tir sur BUSY
            move.b  #15,$ffff8800.w         ; PSG registre 15 = données du port parallèle
            move.b  $ffff8800.w,d0
            move.b  $fffffa01.w,d1          ; GPIP : bit 0 = BUSY
            move.w  (a7)+,sr
            lsr.b   #4,d0                   ; D4-D7 -> bits 0-3, actifs à 0
            btst    #0,d1
            endif
            bne.s   .nofire
            bset    #4,d0                   ; tir appuyé
.nofire     move.b  d0,JOY3.w

            ; poing bleu synchronisé avec $1009
.sync       move.b  P3.w,d0
            cmp.b   fiston(pc),d0
            beq.s   .done
            move.b  d0,fiston
            tst.b   d0
            beq.s   .erase
            bsr     drawblue
            bra.s   .done
.erase      bsr     eraseblue
.done       movem.l (a7)+,d0-d2/a0
            clr.w   d0
            clr.w   d1
            clr.w   d2
            rts

; ----------------------------------------------------------------------------
; looptail : remplace la fin de boucle de F_07732 ($7850-$7869).
; L'original traite le joueur 0, puis 1 (si $1008), et s'arrête.
; Ici : joueur suivant jusqu'à 2, en sautant les non-humains.
; Sans joueur 3, le comportement est identique.
; ----------------------------------------------------------------------------
looptail    move.w  d7,d2
.next       addq.w  #1,d2
            cmpi.w  #3,d2
            bge.s   .end
            lea     P1.w,a0
            tst.b   (a0,d2.w)
            beq.s   .next
            move.w  d2,d7
            jmp     $7746
.end        rts

; ----------------------------------------------------------------------------
; other : remplace « eori.w #1,d2 » ($7772). d2 = soi -> d2 = l'autre humain
; examiné en premier. Original : i^1 (0<->1). Ajout : 2 -> 0.
; (Le second adversaire vient de la table du jeu $786F = [2,2,1].)
; ----------------------------------------------------------------------------
other       move.b  .tab(pc,d2.w),d2
            rts
.tab        dc.b    1,0,0
            even

; ----------------------------------------------------------------------------
; elim : remplace « cmpi.b #6,$1092.w » ($66E4), la règle supplémentaire
; d'élimination (score du round < $50). Avec un joueur 3 : on la saute.
; ----------------------------------------------------------------------------
elim        tst.b   P3.w
            beq.s   .orig
            jmp     $67e8                   ; pas d'élimination, suite normale (bonus de temps)
.orig       cmpi.b  #6,$1092.w
            jmp     $66ea

; ----------------------------------------------------------------------------
; roundend : remplace « move.b #$32,$11ed.w » en L_06872 ($6872), point de
; passage de toutes les fins de round. L'original applique ensuite le masque
; de la table $64C4 (le dernier humain classé perd sa place), efface $1009
; ($68EC) et passe en état 4 (fin de partie) s'il ne reste personne.
; Avec un joueur 3 :
;  - si LIMIT secondes de combat sont écoulées : fin de partie par le chemin
;    « plus aucun humain » du jeu (L_067A6 : message $23, état 8) ;
;  - sinon : tout le monde reste, et on enchaîne le round suivant ($68F0),
;    sans le masque ni l'effacement de $1009.
; ----------------------------------------------------------------------------
roundend    move.b  #$32,$11ed.w
            tst.b   P3.w
            bne.s   .p3
            jmp     $6878                   ; comportement d'origine
.p3         jsr     $6e84                   ; attente/affichage de l'original
            cmpi.w  #LIMIT,gamesec
            bcs.s   .next
            clr.b   P3.w                    ; fin de partie au chronomètre
            bsr     eraseblue
            clr.b   fiston
            ; = L_067A6 (« plus aucun humain »), avec « MATCH OVER » ($11)
            ; au lieu de « IT SEEMS THAT WE HAVE A LIFELESS CROWD » ($23)
            clr.b   P1.w
            clr.b   P2.w
            clr.b   $100a.w
            moveq   #0,d2
            jsr     $7680
            moveq   #1,d2
            jsr     $7680
            move.b  #$11,$108f.w
            jmp     $67cc                   ; durée, affichage, état 8
.next       move.b  #1,STATE.w
            clr.w   d2
            jmp     $68f0

; ----------------------------------------------------------------------------
; roundmsg : remplace « move.b d0,$1092.w / move.w #2,d2 » ($662C-$6633).
; $1092 = message de fin de round, tiré de la table $64C4 avec l'index
; $1309 = catégorie d'égalité (0, 7, 14, 21) + humains classés (3 bits).
; La table n'a jamais prévu 3 humains (index +7 : « PRESS F3 FOR MUSIC »)
; et annonce parfois « IS OUT » alors que personne ne sort. Avec un joueur 3,
; message neutre selon la catégorie.
; ----------------------------------------------------------------------------
roundmsg    move.b  d0,$1092.w
            tst.b   P3.w
            beq.s   .r
            moveq   #0,d0
            move.b  $1309.w,d0
            sub.b   $1091.w,d0              ; catégorie : 0, 7, 14 ou 21
            divu    #7,d0
            move.b  .msg(pc,d0.w),$1092.w
.r          move.w  #2,d2
            rts
.msg        dc.b    $0a                     ; tous différents : X IS BEST / Y IS SECOND / Z IS WORST
            dc.b    $06                     ; 2e = 3e : X WINS / Y AND Z ARE EQUAL SECOND PLACE
            dc.b    $08                     ; 1er = 2e : X AND Y ARE EQUAL FIRST / Z MUST IMPROVE
            dc.b    $09                     ; tous égaux : YOU ARE ALL OF EQUAL ABILITY
            even

; ----------------------------------------------------------------------------
; f3key : remplace l'action de F3 (musique marche / arrêt, $731E-$733B).
; Pendant une partie (état 1, au moins un humain) : le bleu passe
; humain <-> ordinateur. Ailleurs : rien. La musique reste toujours active.
; ----------------------------------------------------------------------------
f3key       cmpi.b  #1,STATE.w
            bne.s   .r
            move.b  P1.w,d0
            or.b    P2.w,d0
            beq.s   .r
            eori.b  #1,P3.w
            clr.w   gamesec
.r          rts

; ----------------------------------------------------------------------------
; tick : remplace « move.b #$32,$125b.w » ($1DCC), exécuté quand le
; chronomètre du round perd une seconde (interruption VBL).
; ----------------------------------------------------------------------------
tick        move.b  #$32,$125b.w
            tst.b   P3.w
            beq.s   .r
            addq.w  #1,gamesec
.r          rts

; ----------------------------------------------------------------------------
; erasehook / drawhook : F_07680 et F_0765C n'ont de table que pour les
; combattants 0 et 1. Pour d2 = 2 on dessine nous-mêmes.
; ----------------------------------------------------------------------------
erasehook   cmpi.w  #2,d2
            bne.s   .orig
            bsr     eraseblue
            clr.b   fiston
            rts
.orig       move.l  d2,-(a7)
            lea     $7644.w,a1
            jmp     $7686

drawhook    cmpi.w  #2,d2
            bne.s   .orig
            bsr     drawblue
            move.b  #1,fiston
            rts
.orig       move.l  d2,-(a7)
            lea     $24.w,a3
            jmp     $7662

drawblue    movem.l d0-d7/a0-a6,-(a7)
            lea     FIST_GFX,a0
            bra.s   blue
eraseblue   movem.l d0-d7/a0-a6,-(a7)
            lea     BLANK_GFX,a0
blue        moveq   #FIST_X,d1
            moveq   #0,d0
            moveq   #0,d2
            moveq   #$f,d6
            lea     SCRA,a1
            suba.l  a5,a5
            jsr     BLIT
            lea     SCRB,a1
            jsr     BLIT
            movem.l (a7)+,d0-d7/a0-a6
            rts

            ; fin : doit rester sous $C00
end_p3
            if end_p3>$c00
            fail "code 3 joueurs trop long"
            endif
