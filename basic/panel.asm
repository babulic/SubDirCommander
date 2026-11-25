; Help panel for the BASIC SubDirCommander.
; Rows 1-23, from column 27, go straight into screen and colour RAM.
; A short row stops before column 39, so that cell stays as the clear
; left it. The caller clears the screen first, including the file list.
;
; build40.py supplies HELPER_ADDR=$9930, where this image becomes a protected
; 4.0 resident helper.

        .cpu "6502"
        .enc "pet"
        .cdef " @", $20
        .cdef "az", $41
        .cdef "AZ", $c1
        .cdef "[[", $5b
        .cdef "]]", $5d
        .cdef "^^", $5e
        .cdef "__", $5f

        .weak
HELPER_ADDR = $c5b0
        .endweak

        * = HELPER_ADDR

ptr     = $fb
scr     = $fd
C_GRY2  = 12

draw    lda #$43                ; row 1, column 27 ($0443)
        sta scr
        lda #$04
        sta scr+1
        lda #<rows
        sta ptr
        lda #>rows
        sta ptr+1
next    ldy #0
        lda (ptr),y
        bmi done
        sta rvsn
        inc ptr
        bne +
        inc ptr+1
+       ldy #0
char    lda (ptr),y
        beq eol
        jsr p2s
        ldx rvsn
        beq put
        ora #$80
        dec rvsn
put     sta (scr),y
        lda scr+1
        pha
        clc
        adc #$d4
        sta scr+1
        lda #C_GRY2
        sta (scr),y
        pla
        sta scr+1
        iny
        bne char
eol     iny
        tya
        clc
        adc ptr
        sta ptr
        bcc +
        inc ptr+1
+       lda scr
        clc
        adc #40
        sta scr
        bcc next
        inc scr+1
        jmp next
done    rts

rvsn    .byte 0

; PETSCII to a lowercase-mode screen code.
p2s     cmp #$20
        bcc p2sc
        cmp #$40
        bcc p2sx
        cmp #$60
        bcc p2s40
        cmp #$80
        bcc p2s20
        cmp #$a0
        bcc p2sc
        cmp #$c0
        bcc p2s40
        cmp #$ff
        beq +
        and #$7f
        rts
+       lda #$5e
        rts
p2s20   sec
        sbc #$20
        rts
p2s40   sec
        sbc #$40
p2sx    rts
p2sc    and #$1f
        ora #$40
        rts

; Reverse count, then the text. $FF ends the list. The count is how
; many leading characters are inverse, same as the ML panel.
rows    .byte 13
        .null "Numeric Keys:"
        .byte 1
        .null "1 List Drive"
        .byte 1
        .null "2 Validate Dr"
        .byte 1
        .null "3 Rename File"
        .byte 1
        .null "4 Copy File/s"
        .byte 1
        .null "5 Start From"
        .byte 1
        .null "6 Del. File/s"
        .byte 1
        .null "7 Run / Open"
        .byte 1
        .null "8 Load / Open"
        .byte 1
        .null "9 Move File/s"
        .byte 1
        .null "0 Format Disk"
        .byte 13
        .null "SD2IEC Keys: "
        .byte 1
        .null "^ Go Level Up"
        .byte 1
        .null "N New Folder"
        .byte 1
        .null "R Remove Fold"
        .byte 13
        .null "CRSR Keys:   "
        .byte 3
        .null "U/D Move CRSR"
        .byte 3
        .null "L/R Page UpDn"
        .byte 13
        .null "Other Keys:  "
        .byte 3
        .null "Spc Mark File"
        .byte 1
        .null "* Mark All F."
        .byte 4
        .null "Ret. Run/Open"
        .byte 1
        .null "_ Exit Appl."
        .byte $ff
