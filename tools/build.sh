#!/bin/sh
# Rebuild both programs, dist/fb.d64 and SubDirCommand.39.d64 from the sources.
# Needs VICE (petcat, c1541) and 64tass.
set -e
cd "$(dirname "$0")/.."
mkdir -p dist web/public/files

for f in basic/SubDirCommand.39.txt; do
    awk '{n=$1+0; if (n<=last) {print FILENAME": line "n" out of order"; exit 1} last=n}' "$f"
done
petcat -w2 -o dist/SubDirCommand.39.prg -- basic/SubDirCommand.39.txt
64tass -q -C --long-branch --cbm-prg -o dist/%SubDirCommand39.prg ml/sdc39.asm

cp original/fb.d64 dist/fb.d64
c1541 -attach dist/fb.d64 \
    -delete "SubDirCommand.37" \
    -delete "SubDirCommand.38" \
    -delete dc64 \
    -delete unformat.dsk.ib3 \
    -write dist/SubDirCommand.39.prg "SubDirCommand.39" \
    -delete "%SubDirCommand38" \
    -write dist/%SubDirCommand39.prg "%SubDirCommand39"

# Slim download disk: both programs only, always kept in dist/ and on the site.
c1541 -format "subdir commander,39" d64 dist/SubDirCommand.39.d64 \
    -write dist/SubDirCommand.39.prg "SubDirCommand.39" \
    -write dist/%SubDirCommand39.prg "%SubDirCommand39"
cp dist/SubDirCommand.39.prg web/public/files/SubDirCommand.39.prg
cp dist/%SubDirCommand39.prg web/public/files/SubDirCommand39-ml.prg
cp dist/SubDirCommand.39.d64 web/public/files/SubDirCommand.39.d64

c1541 -attach dist/fb.d64 -dir
c1541 -attach dist/SubDirCommand.39.d64 -dir
