; ============================================================================
; IK+ (Atari ST) - mode 3 joueurs : joueur 3 sur un adaptateur joystick
; du port parallèle (type Gauntlet II / Leatherneck) ou une manette Jaguar
; (STE) ; le joystick de chaque joueur est choisi au lancement.
;
; Assemblé en $800, dans l'ancien chargeur de boot inutilisé ($704-$9xx,
; contourné par le crack : $1000 saute directement en $14E6). La pile du jeu
; part de $F28 et ne descend pas sous $E64 : $800-$BFF est libre.
;
; Principe :
;  - le jeu range déjà tout par combattant (0 blanc, 1 rouge, 2 bleu) ;
;    $1009 = « combattant 2 humain » existe mais n'est jamais mis à 1 ;
;  - joystick du joueur i en $126C+i, au format du jeu (bits 0-3 directions
;    actives à 0, bit 4 = feu) : les trois sont remplis à chaque VBL depuis
;    la source choisie pour chaque joueur (vblmap) ;
;  - F3 lance une partie à 3 joueurs, comme F1 (1 joueur) et F2 (2 joueurs) :
;    les poings des 3 joueurs clignotent, puis la partie repart de zéro ;
;    la musique passe sur F5 ;
;  - dès que le joueur 3 est là : plus d'élimination, et la partie se
;    termine après LIMIT secondes de combat cumulées (chronomètre du jeu).
;
; Adaptateur (câblage vérifié sur machine réelle avec JOYTEST) :
;  prise « joystick 3 » : directions D4-D7 (0 = appuyé), tir sur BUSY (GPIP bit 0) ;
;  prise « joystick 4 » : directions D0-D3, tir sur STROBE (PSG port A, bit 5).
;  Hatari : « parport stick 1 » et « parport stick 2 ».
; ============================================================================

            ifnd LIMIT
LIMIT       equ 300             ; durée d'une partie à 3 (secondes de combat)
            endif

P1          equ $1007           ; drapeaux humain : combattants 0,1,2
P2          equ $1008
P3          equ $1009
STATE       equ $1076           ; état principal (1 = partie en cours)
SCRA        equ $78000          ; les deux écrans du jeu
SCRB        equ $70000
BLIT        equ $126CC          ; F_126CC : affiche un bloc 16 x d6+1
FIST_GFX    equ $198C8          ; poing (celui du rouge)
BLANK_GFX   equ $198D0          ; bloc vide (effacement)
FIST_X      equ $70             ; blanc $28, rouge $4C, bleu $70 (pas de 2 pixels ;
                                ; rouge et bleu décalés vers la gauche, patch_p3.py)

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
            bra.w f3key         ; $824  touche F3 : partie à 3 joueurs
            bra.w ikbdhook      ; $828  P_02516 : joysticks du clavier (IKBD)
            bra.w blinka        ; $82C  épreuve A : clignotement du poing (joueurs 0-1)
            bra.w blinkb        ; $830  épreuve B : idem
            bra.w f5key         ; $834  touche F5 : musique marche / arrêt
            bra.w setp12        ; $838  F1 / F2 : humains 0 et 1, plus de joueur 3
            bra.w blinkset      ; $83C  début de partie : clignotement des poings
            bra.w blinkvbl      ; $840  F_07608 : clignotement (interruption VBL)
            bra.w vblmap        ; $844  VBL ($1BAA) : joysticks des trois joueurs
            bra.w slashkey      ; $848  touche « / » du pavé numérique (Mega STE)

; --- écrit par le chargeur (adresse fixe $84C, 4 octets) -------------------
CTL         dc.b 1,0,2          ; sources des joueurs 1, 2, 3 (voir vblmap)
MSTE        dc.b 0              ; 1 = Mega STE (touche « / » permise)
RAW0        dc.b $0f            ; joystick 0 du clavier, au format du jeu
RAW1        dc.b $0f            ; joystick 1
FAST        dc.b 0              ; Mega STE : 1 = 16 MHz avec cache
            even
            if CTL!=$84c
            fail "CTL doit rester en $84C (chargeur)"
            endif

; --- variables ----------------------------------------------------------------
gamesec     dc.w 0              ; secondes de combat depuis l'arrivée du joueur 3
fiston      dc.b 0              ; poing bleu affiché ?
blink3      dc.b 0              ; clignotement du poing bleu (comme $1314/$1315)
            even

; ----------------------------------------------------------------------------
; pre : remplace « clr.w d0 / clr.w d1 / clr.w d2 » au début de F_07732.
; Contexte : boucle principale (pas une interruption), donc on peut
; sélectionner un registre du PSG, en masquant les IRQ le temps de la lecture.
; ----------------------------------------------------------------------------
pre         movem.l d0-d2/a0,-(a7)

            ; poing bleu synchronisé avec $1009 (sauf pendant son clignotement)
.sync       tst.b   blink3
            bne.s   .done
            move.b  P3.w,d0
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
; Joysticks : chaque joueur a sa source (choisie sur la page d'introduction
; du chargeur, qui écrit CTL avant de lancer le jeu). Le jeu lit $126C
; (joueur 1, blanc), $126D (joueur 2, rouge), $126E (joueur 3, bleu), au
; format : bits 0-3 = directions, actives à 0 ; bit 4 = tir, 1 = appuyé.
;  - ikbdhook : le gestionnaire IKBD du jeu (P_02516) ne fait plus que
;    garder les deux joysticks du clavier (RAW0, RAW1) ;
;  - vblmap : à chaque VBL (avant la routine son du jeu, même contexte),
;    les trois octets sont remplis à partir des sources choisies.
; Sources : 0, 1 = joysticks 0 et 1 (clavier) ; 2 = prise 3 du port
; parallèle (D4-D7 + BUSY) ; 3 = prise 4 (D0-D3 + STROBE) ; 4, 5 = manettes
; Jaguar sur les ports étendus A et B (STE seulement, le chargeur s'en
; assure) ; 6 = aucune (joueur 3 seulement).
; ----------------------------------------------------------------------------
ikbdhook    move.b  d0,RAW1                 ; octet bas : joystick 1
            lsr.w   #8,d0
            move.b  d0,RAW0                 ; octet haut : joystick 0
            rts

vblmap      move.b  #1,$1016.w              ; instruction remplacée ($1BAA)
            lea     CTL(pc),a2
            lea     $126c.w,a3
            moveq   #2,d3
.pl         moveq   #0,d0
            move.b  (a2)+,d0
            cmp.b   #6,d0
            bhi.s   .none
            add.w   d0,d0
            move.w  .tab(pc,d0.w),d0
            jsr     .tab(pc,d0.w)
            move.b  d0,(a3)+
            dbra    d3,.pl
            rts
.none       moveq   #$0f,d0                 ; rien d'appuyé
            move.b  d0,(a3)+
            dbra    d3,.pl
            rts
.tab        dc.w    src0-.tab,src1-.tab,src2-.tab,src3-.tab
            dc.w    srcpa-.tab,srcpb-.tab,src6-.tab

src0        move.b  RAW0(pc),d0
            rts
src1        move.b  RAW1(pc),d0
            rts
src6        moveq   #$0f,d0
            rts

; Prises du port parallèle. Port B du PSG (données) mis en ENTRÉE : la
; routine son du jeu écrit $DC/$F8 dans le registre 7 (bit 7 = sortie ;
; corrigé en $5C/$78 par patch_p3.py, mais on s'en assure). IRQ masquées le
; temps des accès au PSG (quelques dizaines de cycles).
psgin       move.b  #7,$ffff8800.w
            move.b  $ffff8800.w,d1
            bclr    #7,d1
            move.b  d1,$ffff8802.w
            move.b  #15,$ffff8800.w         ; registre 15 = données du port parallèle
            move.b  $ffff8800.w,d0
            rts

; prise « joystick 3 » : directions sur D4-D7, tir sur BUSY (GPIP bit 0)
src2        move.w  sr,-(a7)
            or.w    #$0700,sr
            bsr.s   psgin
            move.b  $fffffa01.w,d1
            move.w  (a7)+,sr
            lsr.b   #4,d0
            btst    #0,d1
            bra.s   fire

; prise « joystick 4 » : directions sur D0-D3, tir sur STROBE (bit 5 du
; port A du PSG). Le jeu met STROBE à 0 : on le remet à 1, sinon le tir
; serait toujours vu appuyé. Sélection et lecture deux fois : sous Hatari,
; la valeur lue est figée à la sélection.
src3        move.w  sr,-(a7)
            or.w    #$0700,sr
            bsr.s   psgin
            move.b  #14,$ffff8800.w
            move.b  $ffff8800.w,d1
            move.b  #14,$ffff8800.w
            move.b  $ffff8800.w,d1          ; bit 5 = tir, 0 = appuyé
            move.b  d1,d2
            bset    #5,d2
            move.b  d2,$ffff8802.w
            move.w  (a7)+,sr
            andi.b  #$0f,d0
            btst    #5,d1
fire        bne.s   .nf
            bset    #4,d0
.nf         rts

; Manettes Jaguar (ports étendus du STE). $FF9202 en écriture : lignes de
; sélection, actives à 0 (port A bits 0-3, port B bits 4-7) ; en lecture :
; directions (A bits 8-11, B bits 12-15), actives à 0. $FF9200 : Pause et
; A/B/C/Option selon la ligne (A bits 0-1, B bits 2-3), actifs à 0.
; Sur la machine réelle, lire $FF9202 masque les boutons dans la lecture
; suivante de $FF9200 : on lit $FF9200 d'abord (VERSIONS.md section 12).
; Tir = A, B, C ou Pause (lignes 0, 1, 2).
srcpa       moveq   #0,d2
            bra.s   pad
srcpb       moveq   #4,d2
pad         move.w  #$fffe,d1
            rol.w   d2,d1                   ; ligne 0 du port choisi
            move.w  d1,$ffff9202.w
            move.w  $ffff9200.w,d4          ; boutons d'abord
            move.w  $ffff9202.w,d0          ; puis directions
            rol.w   #1,d1                   ; ligne 1 : B
            move.w  d1,$ffff9202.w
            and.w   $ffff9200.w,d4
            rol.w   #1,d1                   ; ligne 2 : C
            move.w  d1,$ffff9202.w
            and.w   $ffff9200.w,d4
            move.w  #$ffff,$ffff9202.w
            lsr.w   #8,d0
            lsr.w   d2,d0
            andi.b  #$0f,d0
            lsr.w   #1,d2
            lsr.w   d2,d4
            not.b   d4
            andi.b  #3,d4                   ; <> 0 : un bouton est appuyé
            beq.s   .np
            bset    #4,d0
.np         rts

; ----------------------------------------------------------------------------
; blinka / blinkb : les épreuves bonus écrivent $14 dans $1314[joueur]
; (clignotement du poing). Il n'y a que 2 cases : pour le joueur 2 ce serait
; $1316, un drapeau d'état du jeu. On n'écrit que pour les joueurs 0 et 1.
; blinka remplace, en $DFF8 : move.b #$14,d0 / lea $1314.w,a0 / move.b d0,(a0,d2.w)
; blinkb remplace, en $EF4A : lea $1314.w,a0 / move.b #$14,(a0,d2.w)
; ----------------------------------------------------------------------------
blinka      move.b  #$14,d0
            lea     $1314.w,a0
            bra.s   blnk
            ; Épreuve B : le jeu met la couleur 1 (écrite par le raster depuis
            ; $1022) à $700 (rouge) pour toute l'épreuve. C'est la couleur de
            ; la veste du bleu : pendant le tour du joueur 3, on la remet à $007.
blinkb      lea     $1314.w,a0
            move.w  #$700,$1022.w
            cmpi.b  #2,d2
            bcs.s   blnk
            move.w  #$007,$1022.w
blnk        cmpi.b  #2,d2
            bcc.s   .r
            move.b  #$14,(a0,d2.w)
.r          rts

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
; f3key : F3 ($7316 saute ici). Comme F1 et F2 ($7364-$73A6) : partie à
; 3 joueurs, avec la même condition ($1006 >= $19), puis demande de nouvelle
; partie ($135F, traitée par l'interruption VBL en $1C56).
; ----------------------------------------------------------------------------
f3key       cmpi.b  #6,CTL+2                ; joueur 3 sans joystick : F3 ne fait rien
            beq.s   .r
            moveq   #0,d0
            move.b  $1006.w,d0
            cmpi.w  #$19,d0
            blt.s   .r
            move.b  #1,P1.w
            move.b  #1,P2.w
            move.b  #1,P3.w
            clr.w   gamesec
            jmp     $7390                   ; $135F = 1, touches effacées
.r          jmp     $73cc

; ----------------------------------------------------------------------------
; f5key : F5 ($7322 saute ici) : musique marche / arrêt, l'ancienne action
; de F3 ($731E-$733B dans le jeu d'origine).
; ----------------------------------------------------------------------------
f5key       tst.b   $100e.w
            beq.s   .on
            jsr     $1706.w                 ; musique coupée
            bra.s   .r
.on         move.b  #1,$100e.w
            jsr     $1734.w                 ; musique remise
.r          jmp     $73a8

; ----------------------------------------------------------------------------
; slashkey : touche « / » du pavé numérique ($732E saute ici), pour les
; essais : sur Mega STE seulement, bascule entre 8 MHz sans cache (réglage
; du chargeur au départ) et 16 MHz avec cache ($FF8E21 : bit 0 = 16 MHz,
; bit 1 = cache). Ailleurs, rien (ce registre n'existe pas).
; ----------------------------------------------------------------------------
slashkey    tst.b   MSTE
            beq.s   .r
            eori.b  #1,FAST
            moveq   #0,d0
            tst.b   FAST
            beq.s   .w
            moveq   #3,d0
.w          move.b  d0,$ffff8e21.w
.r          jmp     $73a8

; ----------------------------------------------------------------------------
; setp12 : remplace « move.b d1,$1007.w / move.b d2,$1008.w » ($7388),
; F1, F2 ou tir sur un joystick : le joueur 3 n'est plus de la partie.
; ----------------------------------------------------------------------------
setp12      move.b  d1,P1.w
            move.b  d2,P2.w
            clr.b   P3.w
            clr.w   gamesec
            rts

; ----------------------------------------------------------------------------
; blinkset : remplace « move.b #$1e,$1314.w / move.b #$1e,$1315.w » ($6CE4),
; début de partie (F_06CD0). Le poing bleu clignote comme les deux autres.
; ----------------------------------------------------------------------------
blinkset    move.b  #$1e,$1314.w
            move.b  #$1e,$1315.w
            move.b  #$1e,blink3
            rts

; ----------------------------------------------------------------------------
; blinkvbl : remplace « moveq #1,d2 / lea $1007.w,a0 » au début de F_07608
; (clignotement des poings, interruption VBL, une image sur 4). Même règle
; que le jeu pour les joueurs 0 et 1 : poing affiché quand le bit 2 du
; compteur est à 0, et donc affiché à la fin.
; ----------------------------------------------------------------------------
blinkvbl    tst.b   blink3
            beq.s   .r
            subq.b  #1,blink3
            tst.b   P3.w
            beq.s   .r
            btst    #2,blink3
            bne.s   .off
            bsr     drawblue
            move.b  #1,fiston
            bra.s   .r
.off        bsr     eraseblue
            clr.b   fiston
.r          moveq   #1,d2
            lea     P1.w,a0
            rts

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
