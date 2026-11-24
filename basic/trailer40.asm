; Binary transport trailer for BASIC SubDirCommander 4.0.
;
; The PRG loader places this immediately after the BASIC $0000 terminator.
; BASIC line 1 first lowers MEMSIZ to $97F0 and executes CLR.  Only then it
; SYSes trailer_entry, which copies every payload to RAM BASIC cannot use.
; This file is assembled once the build knows TRAILER_ADDR.

        .cpu "6502"

        .weak
TRAILER_ADDR = 0
        .endweak
        .if TRAILER_ADDR == 0
        .error "TRAILER_ADDR must be supplied by tools/build40.py"
        .endif

COPY_DEST = $97f0
PANEL_DEST = $9930
DIR_DEST = $9b20

src = $fb
dst = $fd
len = $f7

        * = TRAILER_ADDR

trailer_entry
        lda #<copy_blob
        sta src
        lda #>copy_blob
        sta src+1
        lda #<COPY_DEST
        sta dst
        lda #>COPY_DEST
        sta dst+1
        lda #<(copy_end-copy_blob)
        sta len
        lda #>(copy_end-copy_blob)
        sta len+1
        jsr copy

        lda #<panel_blob
        sta src
        lda #>panel_blob
        sta src+1
        lda #<PANEL_DEST
        sta dst
        lda #>PANEL_DEST
        sta dst+1
        lda #<(panel_end-panel_blob)
        sta len
        lda #>(panel_end-panel_blob)
        sta len+1
        jsr copy

        lda #<dir_blob
        sta src
        lda #>dir_blob
        sta src+1
        lda #<DIR_DEST
        sta dst
        lda #>DIR_DEST
        sta dst+1
        lda #<(dir_end-dir_blob)
        sta len
        lda #>(dir_end-dir_blob)
        sta len+1
        jsr copy
        rts

; Copy LEN bytes from SRC to DST.  It is used only by the bootstrap before
; BASIC creates variables, arrays or strings, so these zero-page scratch
; bytes cannot corrupt program state.
copy    ldy #0
-       lda (src),y
        sta (dst),y
        inc src
        bne +
        inc src+1
+       inc dst
        bne +
        inc dst+1
+       sec
        lda len
        sbc #1
        sta len
        lda len+1
        sbc #0
        sta len+1
        ora len
        bne -
        rts

copy_blob
        .binary "../build40/copyhelper.bin"
copy_end
panel_blob
        .binary "../build40/panel.bin"
panel_end
dir_blob
        .binary "../build40/dirread.bin"
dir_end
