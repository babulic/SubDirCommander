; Read the open directory in logical file 1 into BASIC arrays M$ and MK%.
; SYS 49152. Every M$() string is already 27 characters long.
; $02/$03 = number of lines stored. Carry set when the read fails.
; MK%() is 0 for a PRG, SEQ or USR file and -1 for anything else.

CHKIN   = $ffc6
CHRIN   = $ffcf
CLRCHN  = $ffcc
status  = $90
arytab  = $2f
count   = $02
ptr     = $fb
el      = $fd
scan    = $f7
arr     = $f9
dst     = $f5
tmp     = $f6
maxl    = 27

        * = $c000

read    lda #0
        sta count
        sta count+1
        sta status
        ldx #1
        jsr CHKIN
        bcs stop
        jsr getb                ; load address
        jsr getb
        jsr getb                ; header line link
        jsr getb
        jsr getb                ; header line number
        jsr getb
        jsr getline
        jsr showhead
next    lda status
        and #$bf
        bne stop
        jsr getb
        sta link
        jsr getb
        ora link
        beq ok                  ; no further line
        jsr getb
        sta blocks
        jsr getb
        sta blocks+1
        jsr getline
        jsr store
        bcc next
ok      jsr CLRCHN
        ldx #2
        ldy #0
        clc
        jsr $fff0
        clc
        rts
stop    jsr CLRCHN
        sec
        rts

showhead
        ldx #1
        ldy #0
        clc
        jsr $fff0
        lda #$12
        jsr $ffd2
        ldy #0
sh      cpy buflen
        beq shx
        cpy #26
        beq shx
        lda buf,y
        cmp #$12
        beq shn
        jsr $ffd2
shn     iny
        bne sh
shx     lda #$92
        jsr $ffd2
        lda #$0d
        jmp $ffd2

getb    jsr CHRIN
        rts

getline ldy #0
gl      jsr getb
        beq gld
        cpy #29
        bcs gl
        sta buf,y
        iny
        bne gl
gld     sty buflen
        rts

store   jsr find
        lda #$4d
        ldx #$80
        jsr named
        bcs full
        lda #3
        jsr element
        ldy #0
        lda (el),y
        cmp #maxl
        bne skip
        iny
        lda (el),y
        sta ptr
        iny
        lda (el),y
        sta ptr+1
        jsr putnum              ; Y = characters used
        sty used
        lda #0
        sta src
        ldy #0
qscan   cpy buflen
        beq putfree
        lda buf,y
        cmp #$22
        beq files
        iny
        bne qscan
files   ldy used
copy    cpy #maxl
        beq typed
        ldx src
        cpx buflen
        beq pad
        lda buf,x
        inc src
        cmp #$12
        beq copy
        sta (ptr),y
        iny
        bne copy
pad     lda #' '
        sta (ptr),y
        iny
        cpy #maxl
        bne pad
typed   jsr markof
skip    inc count
        bne +
        inc count+1
+       lda count+1
        bne full
        lda count
        cmp #<501
        bcs full
        clc
        rts
full    sec
        rts

putfree ldy used
        ldx #0
pf      lda ftxt,x
        beq pad2
        cpy #maxl
        beq +
        sta (ptr),y
        iny
        inx
        bne pf
pad2    lda #' '
        cpy #maxl
        beq +
        sta (ptr),y
        iny
        bne pad2
+       rts

ftxt    .byte $20,$42,$4c,$4f,$43,$4b,$53,$20,$46,$52,$45,$45,$2e,0

; Decimal number and a trailing space. Returns the length in X.
putnum  lda blocks
        sta num
        lda blocks+1
        sta num+1
        ldy #0
pd      ldx #0
ps      lda num
        sec
        sbc tlo,y
        pha
        lda num+1
        sbc thi,y
        bcc pdone
        sta num+1
        pla
        sta num
        inx
        bne ps
pdone   pla
        txa
        ora #'0'
        sta digs,y
        iny
        cpy #5
        bne pd
        ldy #0
sk      lda digs,y
        cmp #'0'
        bne wr
        cpy #4
        beq wr
        iny
        bne sk
wr      lda #0
        sta dst
wdig    lda digs,y
        sty tmp
        ldy dst
        sta (ptr),y
        inc dst
        ldy tmp
        iny
        cpy #5
        bne wdig
        ldy dst
        rts

tlo     .byte <10000, <1000, <100, <10, <1
thi     .byte >10000, >1000, >100, >10, >1

; Type letter after the closing quote: P, S or U can be marked.
markof  jsr find
        lda #$cd
        ldx #$cb
        jsr named
        bcs mr
        lda #2
        jsr element
        ldy #0
        ldx #0
q1      cpx #maxl
        beq mneg
        lda (ptr),y
        iny
        inx
        cmp #$22
        bne q1
q2      cpx #maxl
        beq mneg
        lda (ptr),y
        iny
        inx
        cmp #$22
        bne q2
qs      cpx #maxl
        beq mneg
        lda (ptr),y
        cmp #' '
        bne qt
        iny
        inx
        bne qs
qt              cmp #$50
        beq mzero
        cmp #$53
        beq mzero
        cmp #$55
        beq mzero
mneg    lda #$ff
        .byte $2c
mzero   lda #0
        ldy #0
        sta (el),y
        iny
        sta (el),y
mr      rts

; el = arr + count * A (A is 2 or 3).
element sta width
        lda count
        sta acc
        lda count+1
        sta acc+1
        asl acc
        rol acc+1
        lda width
        cmp #2
        beq addbase
        lda acc
        clc
        adc count
        sta acc
        lda acc+1
        adc count+1
        sta acc+1
addbase lda acc
        clc
        adc arr
        sta el
        lda acc+1
        adc arr+1
        sta el+1
        rts

find    lda arytab
        sta scan
        lda arytab+1
        sta scan+1
        rts

; A/X = the array name to find. Sets arr to its first element.
named   sta want
        stx want+1
nl      ldy #0
        lda (scan),y
        iny
        cmp want
        bne step
        lda (scan),y
        cmp want+1
        beq hit
step    ldy #2
        lda (scan),y
        tax
        iny
        lda (scan),y
        clc
        adc scan+1
        sta scan+1
        txa
        adc scan
        sta scan
        bcc +
        inc scan+1
+       lda scan+1
        cmp $32
        bcc nl
        bne miss
        lda scan
        cmp $31
        bcc nl
miss    sec
        rts
hit     lda scan
        clc
        adc #7
        sta arr
        lda scan+1
        adc #0
        sta arr+1
        clc
        rts

want    .byte 0
        .byte 0
num     .word 0
src     .byte 0
width   .byte 0
acc     .word 0
used    .byte 0
link    .byte 0
blocks  .word 0
buflen  .byte 0
digs    .fill 5
buf     .fill 29
