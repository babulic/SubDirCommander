# Create every deterministic disk and binary fixture used by the VICE tests.
# Usage: test/mkdisks.sh [repository-root] [output-directory]
set -eu

root=${1:-"$(cd "$(dirname "$0")/.." && pwd)"}
out=${2:-/tmp/t}
mkdir -p "$out"

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "missing required tool: $1" >&2
        exit 1
    }
}

need c1541
need 64tass

# SMALLSEQ contains a NUL byte.  SEQFILE fills 100 blocks so disk-full and
# partial-file cleanup are tested without a hand-prepared disk image.
printf 'A\000B\377C\015' > "$out/smallseq.bin"
dd if=/dev/zero of="$out/seq.bin" bs=254 count=100 2>/dev/null
dd if=/dev/zero of="$out/fill.bin" bs=254 count=500 2>/dev/null

64tass -q --cbm-prg -DADDR=49152 -o "$out/mlc000.prg" "$root/test/mlt.asm"
64tass -q --cbm-prg -DADDR=4096 -o "$out/ml1000.prg" "$root/test/mlt.asm"
64tass -q -C --long-branch --cbm-prg -l "$out/sdc39.lbl" \
    -o "$out/sdc39ml.prg" "$root/ml/sdc39.asm"

# Current BASIC and ML commanders on independent images.
cp "$root/original/fb.d64" "$out/fb.d64"
cp "$out/fb.d64" "$out/fb39.d64"
c1541 -attach "$out/fb39.d64" \
    -delete "SubDirCommand.37" \
    -delete "SubDirCommand.38" \
    -delete "SubDirCommand.39" \
    -delete "unformat.dsk.ib3" \
    -delete "files (un)locker" \
    -write "$root/dist/SubDirCommand.39.prg" "SubDirCommand.39" >/dev/null 2>&1

cp "$out/fb39.d64" "$out/fbml.d64"
c1541 -attach "$out/fbml.d64" \
    -delete "%SubDirCommand38" \
    -delete "%SubDirCommand39" \
    -delete "ex.simon's basic" \
    -write "$root/dist/%SubDirCommand39.prg" "%SubDirCommand39" >/dev/null 2>&1
cp "$out/fbml.d64" "$out/fbml2.d64"
c1541 -attach "$out/fbml2.d64" \
    -delete "oxford pascal" \
    -write "$out/seq.bin" "seqfile,s" >/dev/null 2>&1

# A paged source disk.  Tests intentionally rely on entries 50--52 being
# MLC000, ML1000 and SMALLSEQ after two page-downs.
c1541 -attach "$root/dist/fb.d64" -read "oxford pascal" "$out/oxford.prg" >/dev/null 2>&1
c1541 -format "big source,39" d64 "$out/big2.d64" >/dev/null 2>&1
i=0
while [ "$i" -lt 50 ]; do
    name=$(printf 'file%02d' "$i")
    c1541 -attach "$out/big2.d64" -write "$out/mlc000.prg" "$name" >/dev/null 2>&1
    i=$((i + 1))
done
c1541 -attach "$out/big2.d64" \
    -write "$out/mlc000.prg" "mlc000" \
    -write "$out/ml1000.prg" "ml1000" \
    -write "$out/smallseq.bin" "smallseq,s" >/dev/null 2>&1
i=53
while [ "$i" -le 57 ]; do
    name=$(printf 'pad%02d' "$i")
    c1541 -attach "$out/big2.d64" -write "$out/mlc000.prg" "$name" >/dev/null 2>&1
    i=$((i + 1))
done
c1541 -attach "$out/big2.d64" \
    -write "$out/seq.bin" "seqfile,s" \
    -write "$out/oxford.prg" "oxford pascal" >/dev/null 2>&1

# A target too full for Oxford Pascal but with room for SMALLSEQ.
c1541 -format "full target,39" d64 "$out/full9.d64" \
    -write "$out/smallseq.bin" "smallseq,s" \
    -write "$out/fill.bin" "fill" >/dev/null 2>&1

# Test scripts mutate these working images; runall rebuilds them before each
# scenario so tests do not depend on their execution order.
cp "$out/fb39.d64" "$out/fb39w.d64"
cp "$out/fbml.d64" "$out/fbmlw.d64"
cp "$out/full9.d64" "$out/full9w.d64"
cp "$out/big2.d64" "$out/big9.d64"
