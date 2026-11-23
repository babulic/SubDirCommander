set -e
cd /tmp/t
root=$(cd "$(dirname "$0")/.." && pwd)
cp fb.d64 fb39.d64
c1541 -attach fb39.d64 -delete "SubDirCommand.37" -delete "SubDirCommand.38" -write "$root/dist/SubDirCommand.39.prg" "SubDirCommand.39" >/dev/null 2>&1
cp fb39.d64 fbml.d64
c1541 -attach fbml.d64 -delete "%SubDirCommand38" -write "$root/dist/%SubDirCommand39.prg" "%SubDirCommand39" >/dev/null 2>&1
cp fb39.d64 fbml2.d64
c1541 -attach fbml2.d64 -delete "ex.simon's basic" -delete "%SubDirCommand38" -write "$root/dist/%SubDirCommand39.prg" "%SubDirCommand39" -write seq.bin "seqfile,s" >/dev/null 2>&1
