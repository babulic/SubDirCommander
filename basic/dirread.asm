; Read the open directory in logical file 1 into BASIC arrays M$ and MK%.
; SYS 49152 enters read. alloc gives every M$() slot a 27-byte body, once.
; $02/$03 = number of lines stored, including the blocks-free line.
; A file line is 27 characters: 4-column block count, quote, 16-character
; name, quote, space, 3-character type, and "<" or a space. The quote is
; always at column 5, so BASIC can load any length of name.
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
maxl    = 27

        * = $c000

read    lda #0
        sta count
        sta count+1
        sta status
        jsr alloc
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
        beq ok                  ; 00 00 after the blocks-free line
        jsr getb
        sta blocks
        jsr getb
        sta blocks+1
        jsr getline
        jsr store
        bcc next
ok      ldy #8                  ; finish the drive's last bytes
-       lda status
        bne +
        jsr CHRIN
        dey
        bne -
+       jsr CLRCHN
        lda #0
        sta status
        lda count
        sta $0334
        lda count+1
        sta $0335
        ldx #2
        ldy #0
        clc
        jsr $fff0
        clc
        rts
stop    jsr CLRCHN
        lda #0
        sta status
        lda count
        sta $0334
        lda count+1
        sta $0335
        sec
        rts

showhead
        lda #14                 ; light blue, same as the title
        sta $0286
        ldx #1
        ldy #0
        clc
        jsr $fff0
        lda #$12
        jsr $ffd2
        ldy #0
        ldx #0
sh      cpy buflen
        beq shx
        cpx #27
        beq shx
        lda buf,y
        cmp #$12
        beq shn
        sta hdrbuf,x
        inx
        jsr $ffd2
shn     iny
        bne sh
shx     lda #$20
-       cpx #27
        beq +
        sta hdrbuf,x
        inx
        bne -
+       lda #$92
        jsr $ffd2
        lda #$0d
        jmp $ffd2

hdrbuf  = $c800

getb    jsr CHRIN
        rts

getline ldy #0
gl      jsr getb
        beq gld
        cpy #40
        bcs gl
        sta buf,y
        iny
        bne gl
gld     sty buflen
        rts

; Write one directory line into M$(count) and bump the count.
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
        jsr putnum
        sty used
        jsr compose
        jsr markof
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

; File line, or blocks free when the raw text has no quote.
compose ldy #0
cq      cpy buflen
        bne +
        jmp free
+       lda buf,y
        cmp #$22
        beq openq
        iny
        bne cq
openq   iny
        ldx #0
nm      cpy buflen
        beq namedone
        lda buf,y
        cmp #$22
        beq namedone
        cmp #$12
        beq nn
        cpx #16
        bcs nn
        sta nbuf,x
        inx
nn      iny
        bne nm
namedone
        stx nlen
        cpy buflen
        beq notype
        iny                     ; step past the closing quote
sp      cpy buflen
        beq notype
        lda buf,y
        cmp #' '
        bne gotty
        iny
        bne sp
gotty   ldx #0
tc      cpx #3
        beq tdone
        cpy buflen
        beq tdone
        lda buf,y
        sta tbuf,x
        iny
        inx
        bne tc
tdone   lda #' '
        cpy buflen
        beq locked
        lda buf,y
        cmp #'<'
        beq locked
        lda #' '
locked  sta lockch
        ldy used
        lda #' '
        sta (ptr),y
        iny
        lda #$22
        sta (ptr),y
        iny
        ldx #0
wn      cpx #16
        beq wq
        lda #' '
        cpx nlen
        bcs +
        lda nbuf,x
+       sta (ptr),y
        iny
        inx
        bne wn
wq      lda #$22
        sta (ptr),y
        iny
        lda #' '
        sta (ptr),y
        iny
        ldx #0
wt      cpx #3
        beq wdone
        lda tbuf,x
        sta (ptr),y
        iny
        inx
        bne wt
wdone   rts

notype  lda #' '
        sta tbuf
        sta tbuf+1
        sta tbuf+2
        sta lockch
        jmp locked

free    ldy used
        ldx #0
pf      lda ftxt,x
        beq frdone
        cpy #maxl
        beq frdone
        sta (ptr),y
        iny
        inx
        bne pf
frdone  lda #' '
-       cpy #maxl
        beq +
        sta (ptr),y
        iny
        bne -
+       rts

ftxt    .byte $20,$42,$4c,$4f,$43,$4b,$53,$20,$46,$52,$45,$45,$2e,0

; Right-align the block count in four columns (five when it needs them).
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
        ldy #1
        lda digs
        cmp #'0'
        beq +
        ldy #0
+       sty first
        lda #5
        sec
        sbc first
        sta field
        ldy first
sk0     lda digs,y
        cmp #'0'
        bne sig
        cpy #4
        beq sig
        iny
        bne sk0
sig     sty start
        lda #5
        sec
        sbc start
        sta ndig
        lda field
        sec
        sbc ndig
        bcs +
        lda #0
+       sta pad
        ldy #0
pspc    lda pad
        beq wdig
        lda #' '
        sta (ptr),y
        iny
        dec pad
        bne pspc
wdig    ldx start
wd      lda digs,x
        sta (ptr),y
        iny
        inx
        cpx #5
        bne wd
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
qt      cmp #$50
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

; Give every M$() slot its own 27-byte body, once.
alloc   jsr find
        lda #$4d
        ldx #$80
        jsr named
        bcs aldone
        ldy #0
        lda (arr),y
        cmp #maxl
        beq aldone
        lda #0
        sta count
        sta count+1
alloop  jsr find
        lda #$4d
        ldx #$80
        jsr named
        bcs aldone
        lda #3
        jsr element
        lda $33
        sec
        sbc #maxl
        sta ptr
        lda $34
        sbc #0
        sta ptr+1
        lda ptr
        cmp $31
        lda ptr+1
        sbc $32
        bcc aldone
        lda ptr
        sta $33
        sta $35
        lda ptr+1
        sta $34
        sta $36
        ldy #0
        lda #maxl
        sta (el),y
        iny
        lda ptr
        sta (el),y
        iny
        lda ptr+1
        sta (el),y
        ldy #maxl-1
        lda #' '
-       sta (ptr),y
        dey
        bpl -
        inc count
        bne +
        inc count+1
+       lda count+1
        bne aldone
        lda count
        cmp #<501
        bcc alloop
aldone  lda #0
        sta count
        sta count+1
        rts

want    .byte 0
        .byte 0
num     .word 0
used    .byte 0
link    .byte 0
blocks  .word 0
buflen  .byte 0
first   .byte 0
field   .byte 0
start   .byte 0
ndig    .byte 0
pad     .byte 0
nlen    .byte 0
lockch  .byte 0
width   .byte 0
acc     .word 0
digs    .fill 5
nbuf    .fill 16
tbuf    .fill 3
buf     .fill 40
