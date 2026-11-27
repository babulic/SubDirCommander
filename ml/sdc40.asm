; %SubDirCommand.40 - machine language SubDirCommander 2026 for the C64.
; Same screen, keys and commands as the BASIC SubDirCommand.40.
; Build: 64tass --cbm-prg -o sdc40ml.prg sdc40.asm
;
; Memory: code and work variables from $0801. Directory entries live in the
; RAM under the BASIC ROM ($A000-$BFFF, 32 bytes each). The free BASIC RAM
; between the end of the code and $A000 is the buffer for drive-to-drive
; copies. Programs are started the way a user would type LOAD and RUN, so
; BASIC sets its own pointers.

        .cpu "6502"

        .enc "pet"
        .cdef " @", $20
        .cdef "az", $41
        .cdef "AZ", $c1
        .cdef "[[", $5b
        .cdef "]]", $5d
        .cdef "^^", $5e
        .cdef "__", $5f

; KERNAL
READST  = $ffb7
SETLFS  = $ffba
SETNAM  = $ffbd
OPEN    = $ffc0
CLOSE   = $ffc3
CHKIN   = $ffc6
CHKOUT  = $ffc9
CLRCHN  = $ffcc
CHRIN   = $ffcf
CHROUT  = $ffd2
LOAD    = $ffd5
STOP    = $ffe1
GETIN   = $ffe4
STATUS  = $90
JIFFY   = $a2
FA      = $ba
NDX     = $c6
KEYD    = $0277
RPTFLG  = $028a
COLOR   = $0286
TXTTAB  = $2b

SCR     = $0400
COLRAM  = $d800

C_BLUE  = 6
C_LBLU  = 14
C_GRY2  = 12
C_CYAN  = 3
C_YEL   = 7
C_WHT   = 1

LISTW   = 27            ; width of the list column
PANELC  = 27            ; first column of the key panel
ROW0    = 2             ; first list row
NROWS   = 22
DIRBUF  = $a000
ENTSZ   = 32
TXTMAX  = 29            ; directory text bytes kept per entry
MAXENT  = 242           ; 11 pages of 22, an index fits in a byte
BUFEND  = $a0           ; copy buffer ends below $A000

; zero page: BASIC temporaries and $FB-$FE, free while we run
zp1     = $fb
zp2     = $fd
scr     = $22
col     = $24
zp3     = $26

; --------------------------------------------------------------------------
        * = $0801
        .word basend, 2026
        .null $9e, format("%d", start)
basend  .word 0

start   tsx
        stx savesp
        ldx #zpend-ZPVARS-1     ; keep BASIC's copy (its JMP at $54 lives here)
-       lda ZPVARS,x
        sta bsave,x
        dex
        bpl -
        jsr scrinit
        lda FA
        cmp #8
        bcc defdrv
        cmp #12
        bcc setdrv
defdrv  lda #8
setdrv  sta dev
        lda #$ff
        sta last

; ---------------------------------------------------------------- drive menu
seldrv  jsr closeall
        jsr cls
        lda #0
        sta oslen
        jsr drawrow0
        lda #1
        sta row
        lda #<s_seldrv
        ldx #>s_seldrv
        jsr msgrow
        lda dev
        jsr numfield
        lda #15
        sta incol
        jsr lineinput
        bcc +
        jmp exitapp
+       jsr parsenum
        cmp #8
        bcc seldef
        cmp #12
        bcs seldef
        sta dev
        jmp relist
seldef  lda #8
        sta dev
        jmp seldrv

; ------------------------------------------------------- read and show list
relist  jsr getos
        bcs fatal
        jsr drawframe
        jsr readdir
        bcs fatal
        lda #0
        sta pos
        sta top
        jsr drawlist
        jmp main

fatal   jsr showerr
        jmp seldrv

; ------------------------------------------------------------- key dispatch
main    jsr getkey
        cmp #$85                ; F1..F8 act like the digit keys
        bcc +
        cmp #$8d
        bcs +
        tax
        lda fkeys-$85,x
+       ldx #0
-       cmp keytab,x
        beq +
        inx
        inx
        inx
        ldy keytab,x
        bne -
        jmp main
+       lda keytab+2,x
        pha
        lda keytab+1,x
        pha
        rts

keytab  .byte $11
        .word kdown-1
        .byte $91
        .word kup-1
        .byte $1d
        .word kright-1
        .byte $9d
        .word kleft-1
        .byte "1"
        .word seldrv-1
        .byte "2"
        .word cvalid-1
        .byte "3"
        .word crename-1
        .byte "4"
        .word ccopy-1
        .byte "5"
        .word cstart-1
        .byte "6"
        .word cdelete-1
        .byte "7"
        .word crun-1
        .byte $0d
        .word crun-1
        .byte "8"
        .word cload-1
        .byte "9"
        .word cmove-1
        .byte "0"
        .word cformat-1
        .byte "n"
        .word cmkdir-1
        .byte "N"
        .word cmkdir-1
        .byte " "
        .word cmark-1
        .byte "*"
        .word cmarkall-1
        .byte $5e
        .word cdup-1
        .byte $5f
        .word exitapp-1
        .byte 0

fkeys   .text "13572468"

; ------------------------------------------------------------- cursor keys
kdown   jsr haslist
        lda pos
        cmp last
        bcs nomove
        sta oldpos
        inc pos
        lda pos
        sec
        sbc top
        cmp #NROWS
        bcc movehl
        lda top
        clc
        adc #NROWS
        sta top
        jmp redraw

kup     jsr haslist
        lda pos
        beq nomove
        sta oldpos
        dec pos
        lda pos
        cmp top
        bcs movehl
        lda top
        sec
        sbc #NROWS
        sta top
        jmp redraw

kright  jsr haslist
        lda top
        clc
        adc #NROWS
        sta zp3
        lda last
        cmp zp3
        bcc tolast
        lda zp3
        sta top
        lda pos
        clc
        adc #NROWS
        bcs pdlast
        cmp last
        bcc pdset
pdlast  lda last
pdset   sta pos
        jmp redraw
tolast  lda last
        jmp jumpto

kleft   jsr haslist
        lda top
        beq tofirst
        sec
        sbc #NROWS
        sta top
        lda pos
        sec
        sbc #NROWS
        sta pos
        jmp redraw
tofirst lda #0
jumpto  cmp pos
        beq nomove
        ldx pos
        stx oldpos
        sta pos
movehl  lda oldpos
        jsr drawent
        lda pos
        jsr drawent
nomove  jmp main

redraw  jsr drawlist
        jmp main

; Return to main (dropping the caller) when no directory is loaded.
haslist ldx last
        inx
        bne +
        pla
        pla
        jmp main
+       rts

; -------------------------------------------------------------- ^, validate
cdup    jsr cmdi
        .text "cd:"
        .byte $5f, 0            ; CD:←  (left arrow, parent directory)
        lda #0                  ; CD changes the DOS context, not the device.
        sta oslen               ; Do not reuse an image's cached CBM title.
        jmp dosfolder

cvalid  jsr haslist
        lda bfree+1
        cmp #>3161
        bcc +
        bne nomove
        lda bfree
        cmp #<3161
        bcs nomove
+       jsr msgi
        .null "Validating disk ..."
        jsr cmdi
        .null "v"
dosrelist
        jsr doscmd
        bcs +
        jsr waitdev
        bcs +
        jmp relist
+       jmp fatal

; ------------------------------------------------------------- 5 start adr
cstart  jsr parseprg
        bcs nomove
        lda ro
        ora hostf
        bne nomove
        lda type
        cmp #"p"
        bne nomove
        jsr getstart
        bcs fatalj
        jsr msgi
        .null "Start From: "
        jsr decsa
        jmp main
fatalj  jmp fatal

; --------------------------------------------------------------- 3 rename
crename jsr parsefile
        bcs restore
        jsr safeold
        bcs restore
        jsr isdir
        bcc renameok
        jsr folderok
        bcs folderbad
        jsr rootok
        bcs folderbad
renameok
        jsr msgi
        .null "Rename to:"
        lda #11
        jsr namefield
        bcs restore
        jsr takename
        bcs restore
        lda newlen
        beq restore
        jsr samename
        bcs restore
        jsr msgi
        .null "Renaming ..."
        jsr cmdi
        .null "r:"
        jsr cmdnew
        lda #"="
        jsr cmdchr
        jsr cmdname
        jsr doscmd
        bcs fatalj
        jsr waitdev
        bcs fatalj
        lda pos
        jsr getent
        jsr newtext
        lda pos
        jsr putent
restore lda pos
        jsr drawent
        jmp main

; --------------------------------------------------------------- 6 delete
cdelete lda #0
        sta ismv
        jsr countmk
        bcs delall
        jmp delone
delall  jsr msgi
        .null "Delete marked ? y/n"
        jsr flushk
        jsr getkey
        and #$7f
        cmp #"y"
        bne nomove
        lda #0
        sta walk
delloop lda last
        cmp #$ff
        beq ddone
        lda walk
        cmp last
        bcs ddone
        jsr getent
        lda ent+31
        beq delnext
        lda walk
        sta pos
        jsr parsefile
        bcs delnext
        lda ro
        ora locked
        bne delnext
        jsr safeold
        bcs delnext
        jsr cmdi
        .null "s:"
        jsr cmdname
        jsr doscmd
        bcs fatalj
delnext inc walk
        bne delloop
ddone   jmp relist
delone  jsr parsefile
        bcs restore
        jsr isdir
        bcs crmdir
        lda locked
        bne restore
        jsr safeold
        bcs restore
        jsr msgi
        .null "Delete item ? y/n"
        jsr flushk
        jsr getkey
        and #$7f
        cmp #"y"
        bne restore
        jsr cmdi
        .null "s:"
        jsr cmdname
        jsr doscmd
        bcs fatalj
        jsr waitdev
        bcs fatalj
        lda pos
        jsr getent
        lda ent
        clc
        adc bfree
        sta bfree
        lda ent+1
        adc bfree+1
        sta bfree+1
        bcc +
        lda #$ff                ; a root reports at most 65535 blocks free
        sta bfree
        sta bfree+1
+       lda #0
        sta ent
        sta ent+1
        lda #8
        sta ent+2
        ldx #7
-       lda s_deleted,x
        sta ent+3,x
        dex
        bpl -
        lda pos
        jsr putent
        jsr setbfree
        jmp redraw

; ----------------------------------------------------------------- 4 copy
ccopy   lda #0
        sta ismv
        jsr countmk
        bcc +
        jmp fileall
+       jsr parsefile
        bcs restore
        jsr safeold
        bcs restore
        lda blocks
        ora blocks+1
        beq restore
        jsr msgi
        .null "Copy to:"
        lda #9
        jsr namefield
        bcs restore
        jsr takename
        bcs restore
        jsr msgi
        .null "Target drive:"
        lda dev
        jsr numfield
        lda #14
        sta incol
        jsr lineinput
        bcs restore2
        jsr parsenum
        cmp #8
        bcc restore2
        cmp #12
        bcs restore2
        sta tdev
        jsr rootpair
        bcs fatalc
        lda newlen
        bne +
        jsr oldtonew
+       lda tdev
        cmp dev
        bne xdev
        jsr samename
        bcs restore2
        jsr msgi
        .null "Copying ..."
        jsr copysame
        bcs fatalc
        lda ovskip
        bne restore2
        jsr waitdev
        bcs fatalc
        lda last
        cmp #MAXENT-1
        bcs restore2
        jsr getent              ; blocks free line moves down one
        inc last
        lda last
        jsr putent
        lda pos
        jsr getent
        jsr newtext
        ldx last
        dex
        txa
        jsr putent
        lda bfree
        sec
        sbc blocks
        sta bfree
        lda bfree+1
        sbc blocks+1
        sta bfree+1
        jsr setbfree
        jmp redraw
restore2
        jmp restore
fatalc  jmp fatal

xdev    jsr xcopy
        bcs fatalc
        jmp restore

; ----------------------------------------------------------------- 9 move
cmove   lda #1
        sta ismv
        jsr countmk
        bcc +
        jmp fileall
+       jsr parsefile
        bcs nomove
        jsr safeold
        bcs nomove
        lda blocks
        ora blocks+1
        beq nomove
        jsr msgi
        .null "Move to:"
        lda #9
        jsr namefield
        bcs nomove
        jsr takename
        bcs nomove
        jsr msgi
        .null "Target drive:"
        lda dev
        jsr numfield
        lda #14
        sta incol
        jsr lineinput
        bcs nomove
        jsr parsenum
        cmp #8
        bcc nomove
        cmp #12
        bcs nomove
        sta tdev
        jsr rootpair
        bcs fatalc
        lda newlen
        bne +
        jsr oldtonew
+       lda tdev
        cmp dev
        bne mvx
        jsr samename
        bcs nomove
        jsr msgi
        .null "Moving ..."
        jsr movesame
        bcs fatalc
        lda ovskip
        bne nomove
        jsr waitdev
        bcs fatalc
        jmp relist
mvx     jsr xcopy
        bcs fatalc
        lda ovskip
        bne nomove
        jsr cmdi
        .null "s:"
        jsr cmdname
        jmp dosrelist

flushk  lda #0
        sta NDX
        lda #8
        jsr delay
        lda #0
        sta NDX
        rts

; Carry set when at least one file is marked.
countmk lda last
        cmp #$ff
        beq cmno
        lda #0
        sta walk
cmloop  lda walk
        cmp last
        bcs cmno
        jsr getent
        lda ent+31
        bne cmyes
        inc walk
        bne cmloop
cmno    clc
        rts
cmyes   sec
        rts

; Copy or move every marked file. ismv selects the wording and,
; for a move, scratches the source after a successful copy.
fileall jsr msgi
        .null "Target drive:"
        lda dev
        jsr numfield
        lda #14
        sta incol
        jsr lineinput
        bcs nomove
        jsr parsenum
        cmp #8
        bcc nomove
        cmp #12
        bcs nomove
        cmp dev
        beq nomove              ; same names need another drive
        sta tdev
        lda #0
        sta walk
faloop  lda walk
        cmp last
        bcs fadone
        jsr getent
        lda ent+31
        beq fanext
        lda walk
        sta pos
        jsr parsefile
        bcs fanext
        jsr safeold
        bcs fanext
        jsr rootpair
        bcs fatalc
        jsr oldtonew
        jsr xcopy
        bcs fatalc
        lda ovskip
        bne fanext
        lda ismv
        beq fanext
        jsr cmdi
        .null "s:"
        jsr cmdname
        jsr doscmd
        bcs fatalc
fanext  inc walk
        bne faloop
fadone  jmp relist

; ---------------------------------------------------------------- N format
cformat jsr msgi
        .null "Disk name:"
        lda #13
        jsr namefield
        bcs nomove
        jsr takename
        bcs nomove
        lda newlen
        beq nomove
        jsr msgi
        .null "Disk ID:"
        lda #0
        sta inlen
        sta inmode
        sta infresh
        lda #2
        sta inmax
        lda #19
        sta incol
        jsr lineinput
        bcs nomove
        lda inlen
        sta idlen
        ldx #0
-       cpx idlen
        beq +
        lda inbuf,x
        sta idbuf,x
        inx
        bne -
+       jsr msgi
        .null "New disk on drive "
        lda dev
        ldx #0
        jsr decout
        jsr stri
        .null "? y/n"
        jsr flushk
        jsr getkey
        and #$7f
        cmp #"y"
        bne nomove
        jsr msgi
        .null "Formatting ..."
        jsr cmdi
        .null "n:"
        jsr cmdnew
        lda idlen
        bne +
        lda cbmdrv
        bne nosend
        lda #2
        sta idlen
        lda #"0"
        sta idbuf
        sta idbuf+1
+       lda idlen
        beq nosend
        lda #","
        jsr cmdchr
        ldy #0
-       cpy idlen
        beq nosend
        lda idbuf,y
        jsr cmdchr
        iny
        bne -
nosend  jmp dosasyncrelist

; ------------------------------------------------------- M / R directories
cmkdir  jsr folderok
        bcs folderbad
        jsr rootok
        bcs folderbad
        jsr msgi
        .null "Make dir:"
        lda #10
        jsr namefield
        bcs nomove
        jsr takename
        bcs nomove
        lda newlen
        beq nomove
        jsr cmdi
        .null "md:"
        jsr cmdnew
        jmp dosfolder

crmdir  jsr parsefile
        bcs nomove
        jsr safeold
        bcs nomove
        jsr isdir
        bcc nomove
        jsr folderok
        bcs folderbad
        jsr rootok
        bcs folderbad
        jsr msgi
        .null "Delete item ? y/n"
        jsr flushk
        jsr getkey
        and #$7f
        cmp #"y"
        bne nomove
        jsr cmdi
        .null "rd:"
        jsr cmdname
        jmp dosfolder

; --------------------------------------------------------------- marking
cmark   jsr parsefile
        bcs nomove
        jsr markable
        bcc nomove
        lda pos
        jsr getent
        lda ent+31
        eor #1
        sta ent+31
        lda pos
        jsr putent
        lda pos
        jsr drawent
        jmp main

cmarkall
        jsr haslist
        lda #0
        sta zp3
        tax
mkscan  cpx last
        beq mkdec
        txa
        jsr getent
        lda ent+31
        beq mknext
        inc zp3
mknext  inx
        bne mkscan
mkdec   lda #1
        ldx zp3
        beq mkset
        lda #0
mkset   sta zp3
        ldx #0
mkapply cpx last
        beq mkdone
        txa
        pha
        jsr getent
        jsr markable
        bcc mkskip
        lda zp3
        sta ent+31
        pla
        pha
        jsr putent
mkskip  pla
        tax
        inx
        bne mkapply
mkdone  jmp redraw

; Carry set when the entry in ent is a PRG, SEQ or USR file.
markable
        ldx #0
-       cpx ent+2
        bcs mkno
        lda ent+3,x
        inx
        cmp #$22
        bne -
-       cpx ent+2
        bcs mkno
        lda ent+3,x
        inx
        cmp #$22
        bne -
-       cpx ent+2
        bcs mkno
        lda ent+3,x
        cmp #" "
        bne +
        inx
        bne -
+       cmp #"p"
        beq mkyes
        cmp #"s"
        beq mkyes
        cmp #"u"
        beq mkyes
mkno    clc
        rts
mkyes   sec
        rts

; --------------------------------------------------------- 7 / 8 run, load
crun    lda #1
        .byte $2c
cload   lda #0
        sta runflag
        jsr parseprg
        bcc +
        jmp main
+       lda isamp
        beq notamp
        lda type
        cmp #"u"
        bne notamp
        lda #0                  ; "&name" runs a USR file inside the drive
        sta cmdlen
        jsr cmdname
        jsr opencmd             ; no status read: the utility owns the drive
        bcs ampbad
        jsr waitdev
        php
        jsr closeall
        plp
        bcs ampbad
        jmp relist
ampbad  jmp fatal
notamp  lda hostf
        beq +
        jsr nothost
        jsr showerr
        jmp redraw
+       lda ro
        beq +
        jsr cmdi
        .null "cd:"
        jsr cmdname
        lda #0                  ; mounted image: refresh the firmware title
        sta oslen
        jmp dosfolder
+       jsr getstart
        bcc +
        jmp fatal
+       lda #0
        sta ldml
        lda saddr
        cmp #$01
        bne +
        lda saddr+1
        cmp #$08
        bne +
        jmp handoff
+               inc ldml
        lda saddr+1             ; >= $A000, including 51200 ($C800):
        cmp #$a0                ; the file cannot cover this program
        bcs direct
        lda blocks+1            ; end estimate = start + blocks * 254
        bne slow
        lda #0
        sta zp1+1
        lda blocks
        asl
        sta zp1
        rol zp1+1
        lda #0
        sec
        sbc zp1
        sta zp2
        lda blocks
        sbc zp1+1
        sta zp2+1
        lda zp2
        clc
        adc saddr
        sta eaddr
        lda zp2+1
        adc saddr+1
        sta eaddr+1
        bcs slow
        lda saddr+1             ; come back only when clear of code and I/O
        cmp #>bufstart
        bcc slow
        lda eaddr+1
        cmp #$d0
        bcc direct
        bne slow
        lda eaddr
        beq direct
slow    jmp handoff

; ML that stays clear of the commander is loaded here and may come back.
direct          jsr msgi
        .null "Loading from "
        jsr decsa
        jsr setname
        lda #1
        ldx dev
        ldy #1
        jsr SETLFS
        lda #0
        jsr LOAD
        bcc +
        jsr kerr
        jmp fatal
+       stx eaddr
        sty eaddr+1
        jsr READST
        and #$bf
        beq +
        jsr sterr
        jmp fatal
+       lda runflag
        beq ldok
        ldx #zpend-ZPVARS-1
-       lda ZPVARS,x
        sta zsave,x
        dex
        bpl -
        jsr zpbasic
        jsr callml
        ldx #zpend-ZPVARS-1
-       lda zsave,x
        sta ZPVARS,x
        dex
        bpl -
        jsr scrinit
        jsr msgi
        .null "Ran OK, press any key ..."
        jsr getkey
        jsr dirhit
        bcs relistj
        jsr drawframe
        jsr drawhdr
        jmp redraw
ldok    jsr dirhit
        bcs relistj
        jsr msgi
        .null "Loaded OK"
        jsr getkey
        jmp redraw
relistj jmp relist

; Carry set when the loaded range touched the directory under BASIC ROM.
dirhit  lda eaddr+1
        cmp #$a0
        bcc dhno
        lda saddr+1
        cmp #$c0
        bcs dhno
        sec
        rts
dhno    clc
        rts

callml  lda saddr
        sec
        sbc #1
        tax
        lda saddr+1
        sbc #0
        pha
        txa
        pha
        lda #$37
        sta $01
        rts

; Hand the program to BASIC: LOAD"name",dev[,1] on screen, RETURN plus RUN
; or SYS in the keyboard buffer, an empty BASIC program, back to READY.
handoff jsr closeall
        lda #0
        sta RPTFLG
        lda #$80
        sta hoff
        ldy #1                  ; KEYD+0 is the RETURN for the LOAD line
        lda runflag
        beq hokb
        ldx #0
        lda ldml
        beq +
        ldx #3
+       lda #3
        sta kcount
-       lda s_rs,x
        sta KEYD,y
        inx
        iny
        dec kcount
        bne -
        lda ldml
        beq +
        sty kcount
        lda saddr
        ldx saddr+1
        jsr num2dec
        ldy kcount
        ldx #0
-       lda decbuf,x
        sta KEYD,y
        iny
        inx
        cpx declen
        bne -
+       lda #$0d
        sta KEYD,y
        iny
hokb    sty kcount
        lda #$0d
        sta KEYD
        lda #C_WHT
        sta COLOR
        lda #$93
        jsr CHROUT
        jsr stri
        .null "Load"
        lda runflag
        beq +
        jsr stri
        .null " & "
        ldy #1
-       lda KEYD,y
        cmp #$0d
        beq +
        jsr CHROUT
        iny
        bne -
+       lda #C_LBLU
        sta COLOR
        jsr stri
        .null $0d, $11, "load", $22
        ldy #0
-       cpy namelen
        beq +
        lda namebuf,y
        jsr CHROUT
        iny
        bne -
+       jsr stri
        .null $22, ","
        lda dev
        ldx #0
        jsr decout
        lda ldml
        beq +
        jsr stri
        .null ",1"
+       lda #$13
        jsr CHROUT
        lda kcount
        sta NDX
        ldy #0
        tya
        sta (TXTTAB),y
        iny
        sta (TXTTAB),y
        jmp leave

; ------------------------------------------------------------------ exit
exitapp lda #0
        sta RPTFLG
        lda #C_LBLU
        sta COLOR
        lda #$93
        jsr CHROUT
leave   jsr closeall
        lda #$37
        sta $01
        jsr zpbasic
        ldx savesp
        txs
        rts

; Put BASIC's zero page bytes back.
zpbasic ldx #zpend-ZPVARS-1
-       lda bsave,x
        sta ZPVARS,x
        dex
        bpl -
        rts

; ========================================================== drive commands
; Wait until the current drive answers again (after UI, CD, copy...).
waitdev jmp waitopen

delay   clc
        adc JIFFY
-       cmp JIFFY
        bne -
        rts

; Version for the header. X? is the pi1541 and SD2IEC query. Anything
; else is asked with UI, and only CBM DOS is initialized, with plain "i".
getos   lda oslen
        beq +
        lda osdev
        cmp dev
        beq gosok
+       lda #0
        sta cbmdrv
        jsr cmdi
        .null "x?"
        jsr opcmd
        bcs gosx
        ldx #15
        jsr readstat
        php
        jsr cl15
        plp
        bcs gosx          ; I/O failure only. 31 and 73 are answers.
        jsr osgood
        bcs gotype
        jsr cmdi
        .null "ui"
        jsr opcmd
        bcs gosx
        lda #30
        jsr delay
        ldx #15
        jsr readstat
        php
        jsr cl15
        plp
        bcs gosx
        jsr takeos
gotype  jsr cbmchk
        bne gosok
        jsr cmdi
        .null "i"
        jsr dosnp
        bcs gosx
        jsr waitdev
gosok   clc
gosx    rts

; Carry set when the status is a version line and osbuf now holds it.
osgood  lda errnum
        cmp #73
        beq +
        cmp #30
        bcs osno
+       jsr takeos
        lda errnum
        cmp #73
        beq osyes
        lda oslen
        cmp #4
        bcs osyes
osno    lda #0
        sta oslen
        clc
        rts
osyes   sec
        rts

; Text between the first and second comma, spaces out to the header width.
takeos  ldx #0
-       lda statbuf,x
        beq +
        inx
        cmp #","
        bne -
        lda statbuf,x
        cmp #" "
        bne +
        inx
+       ldy #0
-       lda statbuf,x
        beq +
        cmp #","
        beq +
        sta osbuf,y
        inx
        iny
        cpy #LISTW
        bne -
+       sty oslen
        lda #" "
-       cpy #LISTW
        bcs +
        sta osbuf,y
        iny
        bne -
+       lda dev
        sta osdev
        rts

; cbmdrv = 1 and Z set for CBM, a copied ROM, or JiffyDOS.
cbmchk  lda #0
        sta cbmdrv
        ldx #2
-       lda osbuf
        cmp cbmtab,x
        bne +
        lda osbuf+1
        cmp cbmtab+3,x
        bne +
        lda osbuf+2
        cmp cbmtab+6,x
        bne +
        inc cbmdrv
        lda #0
        rts
+       dex
        bpl -
        rts

cbmtab  .text "ccj"
        .text "boi"
        .text "mpf"

; Send cmdbuf on the command channel and read the reply.
; Carry set on a DOS error (>= 2) or I/O error, message in statbuf.
doscmd  jsr opencmd
        bcs +
dosread ldx #15
        jsr readwait
        php
        jsr cl15
        plp
        bcs +
        jmp errchk
+       rts

; Carry set when errnum is a DOS error. 73 is the version line: pi1541 keeps
; it after X?/UI until the next command, even across a successful OPEN.
errchk  lda errnum
        cmp #73
        beq +
        cmp #2
        rts
+       clc
        rts

cl15    lda #15
        jsr CLOSE
        jmp CLRCHN

; Some command-channel operations (N:, CD:, MD:, RD:) complete only after
; their initial OPEN has returned.  Close, wait for the next ordinary
; OPEN/CLOSE to work, then read the resulting DOS status.
dosasync
        jsr opencmd
        bcs dfbad
        jsr cl15
        jsr waitopen
        bcs dfbad
        lda #0
        sta cmdlen
        jsr doscmd
        bcs dfbad
        rts

; CD/MD/RD share the asynchronous protocol. A 1541 has none of these
; commands, while KFF is stopped earlier by folderok.
dosfolder
        jsr dosasync
        bcs dfbad
        jmp relist

; Pi1541 N: creates and enters a new image asynchronously as well.
dosasyncrelist
        jsr dosasync
        bcs dfbad
        jmp relist
dfbad   jmp folderbad

; KFF's virtual disk has no MD/RD implementation and returns an empty
; command-channel response.  Do not pretend that this did anything.  The
; narrow tag test leaves SD2IEC and pi1541 commands entirely probe-free.
folderok
        ldx #0
-       lda osbuf,x
        cmp kfftag,x
        bne fokok
        inx
        cpx #3
        bne -
        lda #<e_nofold
        ldx #>e_nofold
        jmp seterr
fokok   clc
        rts

; A directory entry is a real SD2IEC/Pi folder.  Disk-image filenames are
; openable too, but remain ordinary files for Rename/Delete/Copy/Move.
isdir   lda type
        cmp #"d"
        bne idirno
        lda type+1
        cmp #"i"
        bne idirno
        sec
        rts
idirno  clc
        rts

; Folder commands are valid only at a virtual device root.  A mounted image
; identifies itself as CBM/COP/JIF DOS and must retain its disk semantics.
rootok  lda cbmdrv
        beq rootyes
        jsr erri
        .null "Root device only !"
rootyes clc
        rts

; A root folder or disk image (ro) may be copied or moved only to another
; virtual root, never into an opened disk; plain C64 files go anywhere.
; `getos` is deliberately reused: it performs the X?/UI distinction that the
; main list uses, then the next relist refreshes the source header because
; OSDEV differs.
rootpair
        lda cbmdrv
        bne rppass
        lda ro
        beq rppass
        lda tdev
        cmp dev
        beq rppass
        lda dev
        pha
        lda tdev
        sta dev
        lda #0
        sta oslen
        jsr getos
        bcs rpbad
        lda cbmdrv
        bne rpbad
        pla
        sta dev
rppass  clc
        rts
rpbad   pla
        sta dev
        jsr erri
        .null "Target root only !"

nothost jsr erri
        .null "Not a C64 program !"

folderbad
        jsr showerr
        jmp relist

kfftag  .text "kun"

; OPEN/CLOSE probe. A listen with no bytes keeps these drives waiting.
waitopen
        lda cbmdrv
        bne +
        lda #20
        jsr delay
+       lda #13
        sta tries
wotry   lda #0              ; keep cmdlen: opencmd sends cmdbuf after this probe
        sta STATUS
        lda #15
        ldx dev
        ldy #15
        jsr SETLFS
        lda #0
        jsr SETNAM
        jsr OPEN
        bcs wofail
        jsr cl15
        lda STATUS
        bmi wofail
        clc
        rts
wofail  jsr cl15
        lda #20
        jsr delay
        dec tries
        bne wotry
        jmp devnp

opencmd
        jsr waitopen
        bcc opcmd
        rts
opcmd   lda #15
        ldx dev
        ldy #15
        jmp opfile
dosnp   jsr opcmd
        bcs dosnx
        jmp dosread
dosnx   rts

; pi1541 answers no ATN while it writes a closed file to SD or redraws its
; browser after S:, R:, N:, MD: or RD:. Retry only "device not present".
readwait
        lda #25
        sta tries
-       txa
        pha
        jsr readstat
        pla
        tax
        bcc +
        lda STATUS
        bpl +
        lda #20
        jsr delay
        dec tries
        bne -
        sec
+       rts

; Read the status line of the command channel open as file X.
readstat
        jsr CHKIN
        bcc +
        jsr CLRCHN
        jmp kerr
+       ldy #0
        sty STATUS
rs1     jsr CHRIN
        cmp #$0d
        beq rs2
        cpy #40
        bcs +
        sta statbuf,y
        iny
+       lda STATUS
        beq rs1
rs2     lda #0
        sta statbuf,y
        lda STATUS
        pha
        jsr CLRCHN
        pla
        and #$83
        beq +
        sta STATUS
        jmp sterr
+       lda statbuf
        and #$0f
        asl
        sta errnum
        asl
        asl
        adc errnum
        sta errnum
        lda statbuf+1
        and #$0f
        adc errnum
        sta errnum
        clc
        rts

; ---------------------------------------------------------- start address
; Open the selected PRG and read its load address. Carry set on error.
getstart
        lda namelen
        sta cmdlen
        ldx #15
-       lda namebuf,x
        sta cmdbuf,x
        dex
        bpl -
        lda #1
        ldx dev
        ldy #0
        jsr opfile
        bcs gsx
        ldx #1
        jsr CHKIN
        lda #0
        sta STATUS
        jsr CHRIN
        sta saddr
        jsr CHRIN
        sta saddr+1
        lda STATUS
        pha
        jsr CLRCHN
        lda #1
        jsr CLOSE
        pla
        and #$b2
        beq +
        sta STATUS
        jmp sterr
+       clc
gsx     rts

; Filename of the selected entry for SETNAM.
setname lda namelen
        ldx #<namebuf
        ldy #>namebuf
        jmp SETNAM

; ----------------------------------------------------------- directory read
readdir lda #$ff
        sta last
        sta pos
        lda #0
        sta top
        sta hdrlen
        jsr cmdi
        .null "$"
        lda #2
        ldx dev
        ldy #0
        jsr opfile
        bcc +
        rts
+       ldx #2
        jsr CHKIN
        lda #0
        sta STATUS
        sta eof
        jsr rdb
        jsr rdb
        lda #1
        sta first
rdline  lda eof
        bne rddone
        jsr rdb
        sta zp3
        jsr rdb
        ora zp3
        beq rddone
        lda eof
        bne rddone
        jsr rdb
        sta ent
        jsr rdb
        sta ent+1
        ldy #0
rdtxt   jsr rdb
        beq rdtend
        cpy #TXTMAX
        bcs +
        sta ent+3,y
        iny
+       lda eof
        beq rdtxt
rdtend  sty ent+2
        lda first
        beq rdent
        lda #0
        sta first
        tay
        tax
-       cpy ent+2               ; header, without its reverse-on code
        beq +
        lda ent+3,y
        iny
        cmp #$12
        beq -
        sta hdr,x
        inx
        bne -
+       stx hdrlen
        jsr drawhdr
        jmp rdline
rdent   lda #0
        sta ent+31              ; not marked
        ldx last
        inx
        cpx #MAXENT
        bcs rdline
        stx last
        txa
        jsr putent
        lda last
        cmp #NROWS
        bcs rdline
        jsr drawent
        jmp rdline
rddone  lda STATUS
        sta zp3
        jsr CLRCHN
        lda #2
        jsr CLOSE
        lda last
        cmp #$ff
        bne +
        lda zp3
        and #$83
        sta STATUS
        jmp sterr
+       jsr getent
        lda ent
        sta bfree
        lda ent+1
        sta bfree+1
        lda ent+3
        cmp #" "
        beq +
        jsr setbfree            ; one space after the number, as LIST shows it
+       clc
        rts

; Read a byte, flag end of file. Z reflects the byte.
rdb     jsr CHRIN
        pha
        lda STATUS
        beq +
        lda #1
        sta eof
+       pla
        rts

; Rewrite the blocks free line (index last) from bfree.
setbfree
        lda bfree
        sta ent
        lda bfree+1
        sta ent+1
        ldy #0
-       lda s_bfree,y
        beq +
        sta ent+3,y
        iny
        bne -
+       sty ent+2
        lda last
        jmp putent

; --------------------------------------------------------- entry storage
; Copy entry A from the RAM under BASIC ROM to ent.
getent  jsr entaddr
        ldy #ENTSZ-1
        lda #$36
        sta $01
-       lda (zp1),y
        sta ent,y
        dey
        bpl -
        lda #$37
        sta $01
        rts

putent  jsr entaddr
        ldy #ENTSZ-1
-       lda ent,y
        sta (zp1),y
        dey
        bpl -
        rts

entaddr pha
        lsr
        lsr
        lsr
        clc
        adc #>DIRBUF
        sta zp1+1
        pla
        pha
        asl
        asl
        asl
        asl
        asl
        sta zp1
        pla
        rts

; Parse the selected entry: name, type, flags. Carry set if no file name.
; parseprg also wants something runnable: a dir, an image, an & file or a
; PRG with blocks.
parsefile
        lda #0
        .byte $2c
parseprg
        lda #1
        sta spmode
        ldx last
        inx
        beq pfno
        lda pos
        jsr getent
        lda ent
        sta blocks
        lda ent+1
        sta blocks+1
        lda #0
        sta ro
        sta locked
        sta isamp
        sta namelen
        ldx #0
-       cpx ent+2
        beq pfno
        lda ent+3,x
        inx
        cmp #$22
        bne -
        stx qpos
        ldy #0
-       cpx ent+2
        beq pfno
        lda ent+3,x
        inx
        cmp #$22
        beq +
        cpy #16
        bcs -
        sta namebuf,y
        iny
        bne -
+       sty namelen
        tya
        beq pfno
        lda namebuf
        cmp #"&"
        bne +
        inc isamp
+       ldx qpos                ; type at name+18, lock flag at name+21
        ldy #0
-       lda ent+3+18,x
        sta type,y
        inx
        iny
        cpy #3
        bne -
        lda ent+3+18,x
        cmp #"<"
        bne +
        inc locked
+       lda type
        cmp #"d"
        bne +
        lda type+1
        cmp #"i"
        bne +
        inc ro
+       jsr imgext
        lda spmode
        beq pfok
        lda isamp
        ora ro
        bne pfok
        lda type
        cmp #"p"
        bne pfno
        lda blocks
        ora blocks+1
        beq pfno
pfok    clc
        rts
pfno    sec
        rts

; Only at a device root does a name extension mean anything: a mountable
; image (SD2IEC D64/D41/D71/D81/DNP/M2I, pi1541 G64/T64) opens with CD,
; .prg is a program, any other extension (CRT, SID ...) is a host file
; that is never loaded or started. Inside a CBM disk a dot is just a dot.
imgext  lda #0
        sta hostf
        lda cbmdrv
        bne imgx
        lda namelen
        sec
        sbc #2
        bcc imgx
        tax
        ldy #3                  ; extension of 1, 2 or 3 characters
-       cpx #1
        bcc imgx
        lda namebuf,x
        cmp #"."
        beq imgdot
        dex
        dey
        bne -
imgx    rts
imgdot  cpy #1
        bne imghost
        ldx namelen
        ldy #8
-       lda namebuf-3,x
        and #$7f
        cmp imgtab,y
        bne +
        lda namebuf-2,x
        and #$7f
        cmp imgtab+9,y
        bne +
        lda namebuf-1,x
        and #$7f
        cmp imgtab+18,y
        bne +
        cpy #8
        beq imgx
        inc ro
        rts
+       dey
        bpl -
imghost inc hostf
        rts

imgtab  .text "dddddgtmp"
        .text "6478n662r"
        .text "4111p44ig"

; Directory text of a renamed/copied entry in ent: same layout, newname
; padded to the 16 character name field.
newtext ldx qpos
        ldy #0
-       cpy newlen
        beq +
        lda newname,y
        sta ent+3,x
        inx
        iny
        bne -
+       lda #$22
        sta ent+3,x
        inx
        lda #" "
-       cpy #16
        beq +
        sta ent+3,x
        inx
        iny
        bne -
+       rts

; Typed name (inbuf) -> newname.
takename
        ldx #15
-       lda inbuf,x
        sta newname,x
        dex
        bpl -
        lda inlen
        sta newlen
        jmp safenew

; Carry is set for a DOS command delimiter.  Names are deliberately not
; quoted here: DOS commands use the delimiters as syntax, not file data.
safeold ldx #0
-       cpx namelen
        beq safegood
        lda namebuf,x
        jsr unsafe
        bcs safebad
        inx
        bne -

safenew ldx #0
-       cpx newlen
        beq safegood
        lda newname,x
        jsr unsafe
        bcs safebad
        inx
        bne -

safegood
        clc
        rts
safebad sec
        rts

unsafe  cmp #":"
        beq safebad
        cmp #","
        beq safebad
        cmp #"="
        beq safebad
        cmp #$22
        beq safebad
        clc
        rts

; Carry set when newname equals the selected name.
samename
        lda newlen
        cmp namelen
        bne +
        tax
-       dex
        bmi same
        lda newname,x
        cmp namebuf,x
        beq -
+       clc
        rts
same    sec
        rts

oldtonew
        ldx #15
-       lda namebuf,x
        sta newname,x
        dex
        bpl -
        lda namelen
        sta newlen
        rts

; FILE EXISTS is the only point at which Copy/Move asks whether to replace
; the target.  Any key other than Y skips this one item; the batch loop then
; continues and a Move never scratches its source.
askover lda #0
        sta ovskip
        jsr currow
        lda row
        jsr rowptr
        ldx #0
        lda #" "
-       sta line,x
        inx
        cpx #40
        bne -
        ldx #0
-       lda overpre,x
        beq +
        sta line,x
        inx
        bne -
+       lda #$22
        sta line,x
        inx
        ldy #0
-       cpy newlen
        beq +
        lda newname,y
        sta line,x
        inx
        iny
        bne -
+       lda #$22
        sta line,x
        inx
        ldy #0
-       lda overpost,y
        beq +
        sta line,x
        inx
        iny
        bne -
+       jsr putwide            ; full 40 cells fit a 16-char target + y/n
        jsr flushk
        jsr getkey
        and #$7f
        cmp #"y"
        beq overyes
        inc ovskip
overyes jsr drawpanel          ; restore the right panel covered by the prompt
        clc
        rts

scratchnew
        jsr cmdi
        .null "s:"
        jsr cmdnew
        jmp doscmd

copysame
        lda #0
        sta ovskip
copyagain
        jsr cmdi
        .null "c:"
        jsr cmdnew
        lda #"="
        jsr cmdchr
        jsr cmdname
        jsr doscmd
        bcc sameok
        lda errnum
        cmp #63
        bne samebad
        jsr askover
        lda ovskip
        bne sameok
        jsr scratchnew
        bcs samebad
        jmp copyagain
samebad sec
        rts
sameok  clc
        rts

movesame
        lda #0
        sta ovskip
moveagain
        jsr cmdi
        .null "r:"
        jsr cmdnew
        lda #"="
        jsr cmdchr
        jsr cmdname
        jsr doscmd
        bcc moveok
        lda errnum
        cmp #63
        bne movebad
        jsr askover
        lda ovskip
        bne moveok
        jsr scratchnew
        bcs movebad
        jmp moveagain
movebad sec
        rts
moveok  clc
        rts

; ------------------------------------------------------ inline texts
; cmdi, stri and erri take the 0-terminated text that follows the JSR.
; cmdi: text -> cmdbuf. stri: print it after the last message.
; erri: text -> statbuf, then return to our caller's caller with carry set.
cmdi    pla
        sta zp2
        pla
        sta zp2+1
        ldy #0
-       iny
        lda (zp2),y
        sta cmdbuf-1,y
        bne -
        dey
        sty cmdlen
        iny
inlret  tya
        clc
        adc zp2
        tax
        lda zp2+1
        adc #0
        pha
        txa
        pha
        rts

stri    pla
        sta zp2
        pla
        sta zp2+1
        ldy #0
-       iny
        lda (zp2),y
        beq inlret
        jsr chrout2
        jmp -

erri    pla
        sta zp2
        pla
        sta zp2+1
        ldy #0
-       iny
        lda (zp2),y
        sta statbuf-1,y
        bne -
        sec
        rts

; ------------------------------------------------------ command buffer
; cmdset: A/X = text, Y = length. cmdchr appends A.
cmdset  sta zp2
        stx zp2+1
        sty cmdlen
        dey
-       lda (zp2),y
        sta cmdbuf,y
        dey
        bpl -
        rts

cmdchr  ldx cmdlen
        sta cmdbuf,x
        inc cmdlen
        rts

cmdname ldy #0
-       cpy namelen
        beq +
        lda namebuf,y
        jsr cmdchr
        iny
        bne -
+       rts

cmdnew  ldy #0
-       cpy newlen
        beq +
        lda newname,y
        jsr cmdchr
        iny
        bne -
+       rts

; Open file A on device X, secondary Y, with cmdbuf/cmdlen as the name.
opfile  jsr SETLFS
        lda cmdlen
        ldx #<cmdbuf
        ldy #>cmdbuf
        jsr SETNAM
        jsr OPEN
        bcc +
        jmp kerr
+       rts

; ====================================================== drive to drive copy
; Copies the selected PRG/SEQ/USR file from dev to tdev as newname,
; through the free BASIC RAM. Carry set with a message on failure.
xcopy   lda #0
        sta ovskip
        lda type
        ldx #2
-       cmp okty,x
        beq +
        dex
        bpl -
        jsr erri
        .null "Only prg/seq/usr files !"
+       lda dev
        pha
        lda tdev
        sta dev
        jsr waitopen
        bcs xtargetbad
        pla
        sta dev
        lda ismv
        beq xcopymsg
        jsr msgi
        .null "Moving to drive "
        jmp xdrvnum
xtargetbad
        pla
        sta dev
        sec
        rts
xcopymsg
        jsr msgi
        .null "Copying to drive "
xdrvnum lda tdev
        ldx #0
        jsr decout
        jsr stri
        .null " ..."
        lda #0                  ; source: 1 = command channel, 2 = file
        sta cmdlen
        lda #1
        ldx dev
        ldy #15
        jsr opfile
        bcs xfail
        jsr xname
        jsr cmdname
        lda #<s_cr
        ldx #>s_cr
        jsr xtype
        lda #2
        ldx dev
        ldy #2
        jsr opfile
        bcs xfail
        ldx #1
        jsr readwait
        bcs xfail
        jsr errchk
        bcs xfail
xtarget lda #0                  ; target: 4 = command channel, 3 = file
        sta cmdlen
        lda #4
        ldx tdev
        ldy #15
        jsr opfile
        bcs xfail
        jsr xname
        jsr cmdnew
        lda #<s_cw
        ldx #>s_cw
        jsr xtype
        lda #3
        ldx tdev
        ldy #3
        jsr opfile
        bcs xfail
        ldx #4
        jsr readwait
        bcs xfail
        jsr errchk
        bcc xwrite
        lda errnum
        cmp #63
        bne xfail
        lda #3
        jsr CLOSE
        jsr askover
        lda ovskip
        bne xskip
        jsr xscratch
        bcs xfail
        jmp xtarget
xskip  jsr closeall
        clc
        rts
xwrite
        jsr xloop
        ror xbad                ; bit 7: transfer failed
        lda #3
        jsr CLOSE
        ldx #4
        jsr readwait
        bcs +
        jsr errchk
+       bcs xclean              ; DOS error after the write, message kept
        bit xbad
        bpl xok
        lda #<e_abort
        ldx #>e_abort
        jsr seterr
xclean  lda #0                  ; remove the partial file; it is closed,
        sta cmdlen              ; so S: frees its blocks without V
        jsr cmdi
        .null "s:"
        jsr cmdnew
        jsr xsend
        bcs xfail
        ldx #40                 ; the S: reply must not replace the message
-       lda statbuf,x
        sta bufstart,x
        dex
        bpl -
        ldx #4
        jsr readwait
        ldx #40
-       lda bufstart,x
        sta statbuf,x
        dex
        bpl -
xfail   jsr closeall
        sec
        rts
xok     jsr closeall
        clc
        rts

xname   lda #0
        sta cmdlen
        rts

; File 4 is the already-open target command channel.  Scratch only after Y;
; this is portable across the virtual devices, unlike an implicit @ overwrite.
xscratch
        jsr cmdi
        .null "s:"
        jsr cmdnew
        jsr xsend
        bcs +
        ldx #4
        jsr readwait
        bcs +
        jsr errchk
        bcs +
        lda #4                 ; xtarget reopens the target command channel.
        jsr CLOSE               ; Do not OPEN an already-open logical file.
        clc
+       rts

; Send cmdbuf as one command on the target command channel (file 4).
; Carry set when the drive never listens; output must not reach the screen.
xsend   lda #25
        sta tries
-       ldx #4
        jsr CHKOUT
        bcc +
        jsr CLRCHN
        lda #20
        jsr delay
        dec tries
        bne -
        sec
        rts
+       ldy #0
-       lda cmdbuf,y
        jsr CHROUT
        iny
        cpy cmdlen
        bne -
        lda #$0d
        jsr CHROUT
        jsr CLRCHN
        clc
        rts

xtype   sta zp2
        stx zp2+1
        lda #","
        jsr cmdchr
        lda type
        jsr cmdchr
        ldy #0
-       lda (zp2),y
        beq +
        jsr cmdchr
        iny
        bne -
+       rts

okty    .text "psu"

; Move file 2 to file 3 in chunks. Carry set on error or RUN/STOP.
xloop   lda #0
        sta eof
        sta xbad
xfill   jsr CLRCHN
        lda #0
        sta STATUS
        ldx #2
        jsr CHKIN
        bcs xerr
        lda #<bufstart
        sta zp1
        lda #>bufstart
        sta zp1+1
        ldy #0
xrd     jsr CHRIN
        sta (zp1),y
        lda STATUS
        bne xst
        iny
        bne xrd
        jsr STOP
        beq xerr
        inc zp1+1
        lda zp1+1
        cmp #BUFEND
        bne xrd
        beq xflush
xst     and #$bf
        bne xerr
        inc eof
        iny
        bne xflush
        inc zp1+1
xflush  sty zp1
        jsr CLRCHN
        lda #0
        sta STATUS
        ldx #3
        jsr CHKOUT
        bcs xerr
        lda $9a                 ; refuse to print the file on the screen
        cmp tdev
        bne xerr
        lda #<bufstart
        sta zp2
        lda #>bufstart
        sta zp2+1
        ldy #0
xwl     lda zp2+1
        cmp zp1+1
        bne +
        cpy zp1
        beq xwd
+       lda (zp2),y
        jsr CHROUT
        iny
        bne xwl
        inc zp2+1
        bne xwl
xwd     lda STATUS
        bne xerr
        lda eof
        beq xfill
        jsr CLRCHN
        clc
        rts
xerr    jsr CLRCHN
        sec
        rts

closeall
        lda #3
        jsr CLOSE
        lda #2
        jsr CLOSE
        lda #4
        jsr CLOSE
        lda #1
        jsr CLOSE
        lda #15
        jsr CLOSE
        jmp CLRCHN

; ================================================================ errors
; Messages for showerr: statbuf holds the text, carry set on return.
devnp   lda #<e_devnp
        ldx #>e_devnp
seterr  sta zp2
        stx zp2+1
        ldy #0
-       lda (zp2),y
        sta statbuf,y
        beq +
        iny
        bne -
+       sec
        rts

kerr    cmp #5
        beq devnp
        jsr erri
        .null "I/O error !"

sterr   lda STATUS
        bmi devnp
        and #$02
        beq +
        jsr erri
        .null "Timeout !"
+       lda #<e_rd
        ldx #>e_rd
        jmp seterr

; Show statbuf on rows 2 and 3 and wait for a key.
showerr jsr closeall
        lda #ROW0
        jsr rowptr
        lda #" "
        sta line
        ldx #0
-       lda statbuf,x
        beq +
        sta line+1,x
        inx
        cpx #LISTW-1
        bne -
+       inx
        jsr padline
        lda #C_WHT
        ldx #$80
        jsr putline
        lda #ROW0+1
        jsr rowptr
        ldx #LISTW-1
-       lda s_press,x
        sta line,x
        dex
        bpl -
        lda #C_WHT
        ldx #$80
        jsr putline
        jmp getkey

; ================================================================ screen
scrinit lda #C_BLUE
        sta $d021
        lda #C_LBLU
        sta $d020
        sta COLOR
        lda #$37
        sta $01
        lda #0
        sta hoff
        lda #40
        sta maxcol
        jsr CLRCHN
        lda #$0e
        jsr CHROUT
        lda #$80
        sta RPTFLG
        rts

cls     ldx #0
-       lda #" "
        sta SCR,x
        sta SCR+$100,x
        sta SCR+$200,x
        sta SCR+$2e8,x
        lda #C_LBLU
        sta COLRAM,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$2e8,x
        inx
        bne -
        rts

; Clear the screen and draw row 0 and the key panel.
drawframe
        jsr cls
        jsr drawrow0
drawpanel
        lda #<panel
        sta zp2
        lda #>panel
        sta zp2+1
dpnext  ldy #0
        lda (zp2),y
        bmi dpend
        jsr rowptr
        ldy #1
        lda (zp2),y
        sta rvs
        lda zp2
        clc
        adc #2
        sta zp2
        bcc +
        inc zp2+1
+       lda #PANELC
        sta xcol
        lda #40
        sta maxcol
        lda #C_GRY2
        sta tcol
        jsr putrich
        jmp dpnext
dpend   rts

; Row 0 is the gray title, same colour as the help headers. The disk
; name is on row 1.
drawrow0
        lda #0
        jsr rowptr
        ldx #LISTW-1
        lda oslen
        beq dtitle
-       lda osbuf,x
        sta line,x
        dex
        bpl -
        bmi row0put
dtitle  lda s_title,x
        sta line,x
        dex
        bpl dtitle
row0put lda #C_GRY2
        ldx #$80
        jmp putline

; Row 1: disk header in reverse light blue.
drawhdr lda #1
        jsr rowptr
        lda #" "
        sta line
        sta line+1
        ldx #0
-       cpx hdrlen
        beq +
        cpx #LISTW-2
        beq +
        lda hdr,x
        sta line+2,x
        inx
        bne -
+       inx
        inx
        jsr padline
        lda #C_LBLU
        ldx #$80
        jmp putline

; All 22 list rows of the current page.
drawlist
        lda #0
        sta drow
dlnext  lda top
        clc
        adc drow
        bcs dlblank
        ldx last
        cpx #$ff
        beq dlblank
        cmp last
        beq dlent
        bcc dlent
dlblank lda drow
        clc
        adc #ROW0
        jsr rowptr
        ldx #0
        jsr padline
        lda #C_LBLU
        ldx #0
        jsr putline
        jmp dlinc
dlent   jsr drawent
dlinc   inc drow
        lda drow
        cmp #NROWS
        bne dlnext
        rts

; Draw entry A on its row, highlighted when it is the cursor entry.
drawent sta didx
        sec
        sbc top
        clc
        adc #ROW0
        jsr rowptr
        lda didx
        jsr getent
        lda ent
        ldx ent+1
        jsr num2dec
        jsr fldwidth
        ldx #0
        lda fldw
        sec
        sbc declen
        bcc deccopy
        beq deccopy
        tay
-       lda #" "
        sta line,x
        inx
        dey
        bne -
deccopy ldy #0
-       lda decbuf,y
        sta line,x
        inx
        iny
        cpy declen
        bne -
        jsr alignrest
        jsr padline
        lda didx
        cmp pos
        bne +
        lda ent+31
        beq curplain
        lda #C_YEL
        ldx #$80
        jmp putline
curplain
        lda #C_CYAN
        ldx #$80
        jmp putline
+       lda ent+31
        beq plain
        lda #C_YEL
        ldx #0
        jmp putline
plain   lda #C_LBLU
        ldx #0
        jmp putline

; Screen and colour pointers for row A (row * 40). 16-bit, so a row
; past the window cannot land in zero page or on the CIA.
rowptr  cmp #25
        bcc +
        lda #24
+       tax
        lda #0
        sta scr+1
        txa
        asl
        rol scr+1
        asl
        rol scr+1
        asl
        rol scr+1               ; row * 8
        sta scr
        pha
        lda scr+1
        pha
        lda scr
        asl
        rol scr+1
        asl
        rol scr+1               ; row * 32
        sta scr
        pla
        tax
        pla
        clc
        adc scr
        sta scr
        txa
        adc scr+1
        sta scr+1
        lda scr
        clc
        adc #<SCR
        sta scr
        sta col
        lda scr+1
        adc #>SCR
        sta scr+1
        clc
        adc #>(COLRAM-SCR)
        sta col+1
        rts

; Fill line from X to LISTW with spaces.
padline lda #" "
-       cpx #LISTW
        bcs +
        sta line,x
        inx
        bne -
+       rts

; Block-count field, same widths as the BASIC directory reader.
fldwidth
        ldy #3
        lda ent+1
        cmp #>1000
        bcc fwset
        bne fw1k
        lda ent
        cmp #<1000
        bcc fwset
fw1k    ldy #4
        lda ent+1
        cmp #>10000
        bcc fwset
        bne fw10k
        lda ent
        cmp #<10000
        bcc fwset
fw10k   ldy #5
fwset   sty fldw
        rts

; X is the column after the right-aligned count. A quoted file keeps
; the quote on column 5: one space when the field is 3 columns, none
; when it is 4. Text with no quote is appended as stored.
alignrest
        ldy #0
arscan  cpy ent+2
        beq arraw
        lda ent+3,y
        cmp #$22
        beq arfile
        cmp #" "
        beq arnext
        cmp #$12
        bne arraw
arnext  iny
        bne arscan
arfile  lda fldw
        cmp #4
        bcs arcopy
        cpx #LISTW
        bcs ardone
        lda #" "
        sta line,x
        inx
        jmp arcopy
arraw   ldy #0
arcopy  cpy ent+2
        beq ardone
        cpx #LISTW
        bcs ardone
        lda ent+3,y
        sta line,x
        inx
        iny
        bne arcopy
ardone  rts

; Write line (PETSCII, LISTW wide) to the row at scr in colour A,
; X = $80 for reverse.
putline stx rvs
        sta tcol
        ldy #LISTW-1
-       lda line,y
        jsr p2s
        ora rvs
        sta (scr),y
        lda tcol
        sta (col),y
        dey
        bpl -
        rts

; Write all 40 screen cells from LINE in reverse white.  ASKOVER uses this
; instead of the 27-cell list field so the target name is never omitted.
putwide ldy #39
-       lda line,y
        jsr p2s
        ora #$80
        sta (scr),y
        lda #C_WHT
        sta (col),y
        dey
        bpl -
        rts

; Text at (scr)+xcol from (zp2) up to the 0; the first rvs characters
; are reversed. Past maxcol the rest is consumed and not stored, so a
; long line cannot wrap into the next row or the program.
putrich ldy #0
        lda (zp2),y
        inc zp2
        bne +
        inc zp2+1
+       tax
        beq prend
        jsr p2s
        ldx rvs
        beq +
        ora #$80
        dec rvs
+       ldy xcol
        cpy maxcol
        bcs putrich
        sta (scr),y
        lda tcol
        sta (col),y
        inc xcol
        bne putrich
prend   rts

; PETSCII to screen code.
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

; ------------------------------------------------- messages on a list row
currow  lda pos
        sec
        sbc top
        clc
        adc #ROW0
        cmp #ROW0
        bcs +
        lda #ROW0               ; pos was above the window
+       cmp #ROW0+NROWS
        bcc +
        lda #ROW0+NROWS-1       ; keep the message on the list
+       sta row
        rts

; Message on the cursor row; the text follows the JSR.
msgi    pla
        sta zp2
        pla
        sta zp2+1
        inc zp2
        bne +
        inc zp2+1
+       jsr currow
        lda zp2
        ldx zp2+1
        jsr msgrow
        lda zp2
        sec
        sbc #1
        tax
        lda zp2+1
        sbc #0
        pha
        txa
        pha
        rts

; Clear the list part of row and print text A/X there in white.
msgrow  sta zp2
        stx zp2+1
        lda row
        jsr rowptr
        ldx #0
        jsr padline
        lda #C_WHT
        ldx #0
        jsr putline
        lda #0
        sta xcol
        sta rvs
        lda #LISTW
        sta maxcol
        lda #C_WHT
        sta tcol
        jmp putrich


chrout2 bit hoff
        bmi +
        sty zp3
        jsr p2s
        ldy xcol
        cpy maxcol
        bcs chdrop
        sta (scr),y
        lda #C_WHT
        sta (col),y
        inc xcol
chdrop  ldy zp3
        rts
+       jmp CHROUT

hexsa   lda saddr
        ldx saddr+1
hex16   pha
        txa
        jsr hexout
        pla
hexout  pha
        lsr
        lsr
        lsr
        lsr
        jsr +
        pla
        and #$0f
+       tax
        lda hexdig,x
        jmp chrout2

hexdig  .text "0123456789ABCDEF"

; Start address as "2049 ($0801)" after the last message.
decsa   lda saddr
        ldx saddr+1
        jsr decout
        jsr stri
        .null " ($"
        jsr hexsa
        lda #")"
        jmp chrout2

; Decimal A (lo) / X (hi) at the cursor.
decout  jsr num2dec
        ldy #0
-       lda decbuf,y
        jsr chrout2
        iny
        cpy declen
        bne -
        rts

; A/X -> decbuf without leading zeros, declen.
num2dec sta zp3
        stx zp3+1
        lda #0
        sta declen
        ldx #4
nd1     lda #"0"
        sta ndig
nd2     lda zp3
        sec
        sbc pow10lo,x
        tay
        lda zp3+1
        sbc pow10hi,x
        bcc nd3
        sta zp3+1
        sty zp3
        inc ndig
        bne nd2
nd3     lda ndig
        cpx #0
        beq nd4
        cmp #"0"
        bne nd4
        ldy declen
        beq nd5
nd4     ldy declen
        sta decbuf,y
        inc declen
nd5     dex
        bpl nd1
        rts

pow10lo .byte <1, <10, <100, <1000, <10000
pow10hi .byte >1, >10, >100, >1000, >10000

; Digits of A as the default of a 2 character numeric field.
numfield
        ldx #0
        jsr num2dec
        ldx declen
        stx inlen
        dex
-       lda decbuf,x
        sta inbuf,x
        dex
        bpl -
        lda #1
        sta infresh
        sta inmode
        lda #2
        sta inmax
        rts

; Empty 16 character name field at column A.
namefield
        sta incol
        lda #0
        sta inlen
        sta inmode
        sta infresh
        lda #16
        sta inmax
        jmp lineinput

; Number typed in inbuf -> A (0 when empty).
parsenum
        lda #0
        ldx #0
-       cpx inlen
        beq +
        sta zp3
        asl
        asl
        adc zp3
        asl
        sta zp3
        lda inbuf,x
        and #$0f
        clc
        adc zp3
        inx
        bne -
+       rts

; Line editor on row (row) from column incol, up to inmax characters.
; inmode 1 = digits only. With infresh set the first key replaces the
; default. RETURN: carry clear. RUN/STOP: carry set.
lineinput
        lda #C_WHT
        sta COLOR
        sta tcol
        lda row
        jsr rowptr
        ldy #LISTW-1
        lda #C_WHT
-       sta (col),y
        dey
        bpl -
liloop  jsr infield
        jsr getkey
        cmp #$0d
        beq inret
        cmp #$03
        beq inesc
        cmp #$14
        bne +
        lda #0
        sta infresh
        lda inlen
        beq liloop
        dec inlen
        jmp liloop
+       ldx inmode
        beq +
        cmp #"0"
        bcc liloop
        cmp #"9"+1
        bcs liloop
        bcc inadd
+       cmp #$22
        beq liloop
        cmp #$20
        bcc liloop
        cmp #$80
        bcc inadd
        cmp #$a0
        bcc liloop
inadd   ldx infresh
        beq +
        ldx #0
        stx inlen
        stx infresh
+       ldx inlen
        cpx inmax
        bcs liloop
        sta inbuf,x
        inc inlen
        jmp liloop
inret   lda #" "
        jsr infld0
        clc
        rts
inesc   sec
        rts

infield lda #$a0
infld0  sta zp3
        ldy incol
        ldx #0
-       cpx inlen
        beq +
        lda inbuf,x
        jsr p2s
        sta (scr),y
        lda #C_WHT
        sta (col),y
        iny
        inx
        bne -
+       cpy #LISTW
        bcs +
        lda zp3
        sta (scr),y
        lda #C_WHT
        sta (col),y
        iny
+       lda #" "
-       cpy #LISTW
        bcs +
        sta (scr),y
        iny
        bne -
+       rts

getkey  jsr GETIN
        beq getkey
        rts

; ================================================================ text
s_title .text "   SubDirCommander 2026    "
s_seldrv
        .null " Select drive:"
s_press .text " PRESS ANY KEY ...         "
s_rs    .text "runsys"
s_deleted
        .text " deleted"
s_bfree .null " blocks free."
s_cr    .null ",r"
s_cw    .null ",w"
overpre .null "Rewrite target "
overpost
        .null "? y/n"
e_devnp .null "Device is not present !"
e_rd    .null "Read error !"
e_abort .null "Copy aborted !"
e_nofold
        .null "No folders on KFF !"

; Key panel: row, then rich text.
panel
        .byte 1, 13
        .null "Numeric Keys:"
        .byte 2, 1
        .null "1 List Drive"
        .byte 3, 1
        .null "2 ValidateDsk"
        .byte 4, 1
        .null "3 RenameFl/Fd"
        .byte 5, 1
        .null "4 Copy File/s"
        .byte 6, 1
        .null "5 Start From"
        .byte 7, 1
        .null "6 DeleteFl/Fd"
        .byte 8, 1
        .null "7 Run / Open"
        .byte 9, 1
        .null "8 Load / Open"
        .byte 10, 1
        .null "9 Move File/s"
        .byte 11, 1
        .null "0 New/FormDsk"
        .byte 12, 13
        .null "SD2IEC Keys: "
        .byte 13, 1
        .null "^ Go Level Up"
        .byte 14, 1
        .null "N New Folder"
        .byte 15, 1
        .null ""
        .byte 15, 13
        .null "CRSR Keys:   "
        .byte 16, 3
        .null "U/D Move CRSR"
        .byte 17, 3
        .null "L/R Page UpDn"
        .byte 18, 13
        .null "Other Keys:  "
        .byte 19, 3
        .null "Spc Mark File"
        .byte 20, 1
        .null "* Mark All F."
        .byte 21, 4
        .null "Ret. Run/Open"
        .byte 22, 1
        .null "_ Exit Appl."
        .byte $ff

; ============================================================ variables
; Hot variables in the BASIC area of zero page ($4B-$72). The KERNAL does
; not use it; BASIC's bytes (including its function JMP at $54) are saved at
; start and put back on exit and while a loaded program runs.
ZPVARS  = $4b
        .virtual ZPVARS
dev     .byte ?
tdev    .byte ?
pos     .byte ?
oldpos  .byte ?
top     .byte ?
last    .byte ?
row     .byte ?
xcol    .byte ?
tcol    .byte ?
rvs     .byte ?
hoff    .byte ?
eof     .byte ?
errnum  .byte ?
namelen .byte ?
newlen  .byte ?
inlen   .byte ?
inmax   .byte ?
incol   .byte ?
inmode  .byte ?
infresh .byte ?
declen  .byte ?
cmdlen  .byte ?
ndig    .byte ?
didx    .byte ?
drow    .byte ?
kcount  .byte ?
qpos    .byte ?
ro      .byte ?
locked  .byte ?
isamp   .byte ?
spmode  .byte ?
runflag .byte ?
ldml    .byte ?
first   .byte ?
tries   .byte ?
xbad    .byte ?
bfree   .word ?
blocks  .word ?
zpend
        .endv
        .cerror zpend > $73, "zero page variables overrun CHRGET"

        .virtual
savesp  .byte ?
saddr   .word ?
eaddr   .word ?
zsave   .fill zpend - ZPVARS
bsave   .fill zpend - ZPVARS
type    .fill 3
namebuf .fill 16
newname .fill 16
inbuf   .fill 17
idlen   .byte ?
idbuf   .fill 2
ismv    .byte ?
hostf   .byte ?
ovskip  .byte ?
walk    .byte ?
decbuf  .fill 6
fldw    .byte ?
maxcol  .byte ?
cmdbuf  .fill 48
statbuf .fill 42
oslen   .byte ?
osdev   .byte ?
cbmdrv  .byte ?
osbuf   .fill LISTW
hdrlen  .byte ?
hdr     .fill 32
line    .fill 40
ent     .fill ENTSZ
        .align 256
bufstart
        .endv
