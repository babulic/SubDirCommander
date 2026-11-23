; Move the BASIC DATA pointer ($41/$42) forward by the number of items in X.
; Does not collect the values. The next READ continues at the following item.
; SYS 50432. The count is in $FB (0 does nothing).
;
; This used to sit at $02A7, the RS-232 output buffer. That buffer is only
; 89 bytes ($02A7-$02FF). The routine is 170, so it ran through the BASIC
; and KERNAL vectors at $0300, including IRQ at $0314, and into the copy
; helper at $033C. The first drive select then died with a corrupted IRQ.
; $C500 is the gap after the directory reader ($C000-$C43F) and before the
; hex decoder ($C800), which the directory header later overwrites.
; The help panel follows this routine at $C5B0 and ends before $C800.

        * = $c500

        ldx $fb
        beq done
next    jsr one
        dex
        bne next
done    rts

; Leave $41/$42 on the comma, colon or zero that ends one item.
one     ldy #0
        lda ($41),y
        cmp #','
        beq from1
        cmp #':'
        beq find
        cmp #0
        bne from0
find    jsr findd
from1   ldy #1
        bne class
from0   ldy #0
class   lda ($41),y
        cmp #$22
        beq quoted
plain   lda ($41),y
        beq setp
        cmp #','
        beq setp
        cmp #':'
        beq setp
        iny
        bne plain
quoted  iny
qloop   lda ($41),y
        beq setp
        cmp #$22
        beq qend
        iny
        bne qloop
qend    iny
        jmp plain
setp    tya
        clc
        adc $41
        sta $41
        bcc setok
        inc $42
setok   rts

; Sit on the next DATA token. Enter on a colon or a line-ending zero.
findd   ldy #0
        lda ($41),y
        bne atcol
        iny
        lda ($41),y
        iny
        ora ($41),y
        beq setok
        ldy #5
        bne chkt
atcol   ldy #1
chkt    lda ($41),y
        cmp #$83
        beq move
        cmp #$8f
        beq remln
scan    lda ($41),y
        beq move
        cmp #':'
        beq move
        cmp #$22
        bne scann
qsk     iny
        lda ($41),y
        beq move
        cmp #$22
        bne qsk
scann   iny
        bne scan
remln   iny
        lda ($41),y
        bne remln
move    tya
        clc
        adc $41
        sta $41
        bcc moved
        inc $42
moved   ldy #0
        lda ($41),y
        cmp #$83
        beq setok
        cmp #0
        beq findd
        cmp #':'
        beq findd
        rts
