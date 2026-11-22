#!/bin/sh
# Rebuild both programs and dist/fb.d64 from the sources.
# Needs VICE (petcat, c1541) and 64tass.
set -e
cd "$(dirname "$0")/.."
mkdir -p dist

for f in basic/SubDirCommand.3*.txt; do
    awk '{n=$1+0; if (n<=last) {print FILENAME": line "n" out of order"; exit 1} last=n}' "$f"
done
petcat -w2 -o dist/SubDirCommand.38.prg -- basic/SubDirCommand.38.txt
64tass -q -C --long-branch --cbm-prg -o dist/%SubDirCommand38.prg ml/sdc38.asm

cp original/fb.d64 dist/fb.d64
c1541 -attach dist/fb.d64 \
    -delete "SubDirCommand.37" \
    -write dist/SubDirCommand.38.prg "SubDirCommand.38" \
    -write dist/%SubDirCommand38.prg "%SubDirCommand38"
c1541 -attach dist/fb.d64 -dir
