; Decode the BASIC string H$ and poke it.
; Destination is kept at $0336/$0337, because BASIC reuses $02 between SYS calls.
; H$ holds PETSCII hex. Lives in the RS-232 buffer, ahead of the copy helper.

        * = $c800

poke    lda $0336
        sta $02
        lda $0337
        sta $03
        jsr findh
        ldy #0
loop    cpy $fd
        bcs done
        lda ($fb),y
        jsr nib
        asl
        asl
        asl
        asl
        sta $fe
        iny
        lda ($fb),y
        jsr nib
        ora $fe
        sty $ff
        ldy #0
        sta ($02),y
        inc $02
        bne next
        inc $03
next    ldy $ff
        iny
        bne loop
done    lda $02
        sta $0336
        lda $03
        sta $0337
        rts

nib     sec
        sbc #$30
        cmp #10
        bcc +
        sbc #7
+       rts

findh   lda $2d
        sta $fb
        lda $2e
        sta $fc
fh      ldy #0
        lda ($fb),y
        cmp #$48                ; H
        bne fnext
        iny
        lda ($fb),y
        cmp #$80                ; one-character string H$
        beq fgot
fnext   lda $fb
        clc
        adc #7
        sta $fb
        bcc +
        inc $fc
+       lda $fc
        cmp $30
        bcc fh
        bne fmiss
        lda $fb
        cmp $2f
        bcc fh
fmiss   lda #0
        sta $fd
        rts
fgot    ldy #2
        lda ($fb),y
        sta $fd
        iny
        lda ($fb),y
        tax
        iny
        lda ($fb),y
        stx $fb
        sta $fc
        rts
