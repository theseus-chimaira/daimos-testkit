#!/bin/sh
# Reproducible source-built linked MRES mode switching, no boot/deposits.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/pure-directory-idle-package-v1990.XXXXXX")
trap 'echo "v1990 package evidence: $work"' EXIT
for compiler in ${V1990_COMPILERS:-gcc kcc}; do
    b="$work/$compiler"
    mkdir -p "$b"
    build() {
        make -s -C "$DAIMOS_REPO/system/boot/pdp6" "$b/purev1612-mres.dobj" \
            BUILD="$b" PDP10_PREFIX="$PDP10_PREFIX" ROOT=tape BOOT=dtc \
            BOOT_PROFILE=lowmem COMPILER="$compiler" BOOT_CORE_WORDS=0200000 \
            SIMH_CPU_KWORDS=64 TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
            DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_SWAPLESS_ONLY_V1668=1 "$@"
    }
    for mode in 0 1 0 1; do
        echo "v1990 $compiler directory idle=$mode"
        build DAIMOS_PBM_DIRECTORY_V1983=1 DAIMOS_PBM_IDLE_RECOVER_V1990="$mode" >"$b/build-$mode.log" 2>&1 || {
            tail -80 "$b/build-$mode.log"; exit 1;
        }
        "$PDP10_PREFIX/bin/pdp10-objdump" -h "$b/purev1612-mres.dobj"
        python3 - "$b" "$mode" <<'PY'
from pathlib import Path
import sys
b=Path(sys.argv[1]); mode=int(sys.argv[2])
m={x.split()[0] for x in (b/'pure-mres-v1612.map').read_text().splitlines() if x.split()}
k={x.split()[0] for x in (b/'kcore.map').read_text().splitlines() if x.split()}
names={'proc_pure_bitmap_arm_v1990','proc_pure_bitmap_recover_v1989'}
assert not names&k
assert names<=m if mode else not names&m
for name in ('purev1612-mres.dobj','pure-mres-v1612.map','kcore.dxr'):
    out=b/('mode-%d-'%mode+name)
    if out.exists():
        assert out.read_bytes()==(b/name).read_bytes(),name
    else:
        out.write_bytes((b/name).read_bytes())
assert (b/'mode-0-kcore.dxr').read_bytes()==(b/'kcore.dxr').read_bytes(), 'fixed KCORE changed'
PY
    done
    if build DAIMOS_PBM_DIRECTORY_V1983=0 DAIMOS_PBM_IDLE_RECOVER_V1990=1 >"$b/conflict.log" 2>&1; then
        echo 'FAIL: recovery without directory accepted'; exit 1
    fi
    grep -q 'idle directory recovery requires' "$b/conflict.log"
    if build DAIMOS_PBM_DIRECTORY_V1983=1 DAIMOS_PBM_IDLE_RECOVER_V1990=2 >"$b/invalid.log" 2>&1; then
        echo 'FAIL: invalid recovery flag accepted'; exit 1
    fi
    grep -q 'DAIMOS_PBM_IDLE_RECOVER_V1990 must be 0 or 1' "$b/invalid.log"
    echo "PASS: $compiler package OFF/ON/OFF/ON, unchanged KCORE, invalid modes refused"
done
