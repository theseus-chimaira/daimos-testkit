#!/bin/sh
# Compare the FULL current native KCC phase closure against host KCC.
# All rebuilt DXRs and disk images remain under TMPDIR; none are installed.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS tree}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
KCC_REPO=${KCC_REPO:-$HOME/git/kcc}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/kcc-native-refresh-v1373"
daimos=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
kcc_repo=$(CDPATH= cd -- "$KCC_REPO" && pwd -P)
work="$TMPDIR/kcc-native-refresh-v1373"
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1371="$TMPDIR/d6codec-fulldist-v1371"
native="$work/current-native-v1373"
host="$work/current-host-v1373"
mkdir -p "$work" "$native" "$host"

if [ "${V1373_REUSE_VERIFIED_V1371:-0}" != 1 ]; then
    echo 'V1373 PHASE 1: repeat full grouped kernel/distribution boot acceptance'
    if ! DAIMOS_REPO="$daimos" sh \
        "$testkit/tests/validation/d6codec-fulldist-v1371/run-v1371.sh" \
        > "$work/prerequisite-v1371.log" 2>&1; then
        tail -70 "$work/prerequisite-v1371.log" >&2
        exit 1
    fi
else
    echo 'V1373 PHASE 1: verify previous full grouped root acceptance'
    test -s "$v1371/boot-runtime-v1371.out"
    grep -F 'V1371FULL' "$v1371/boot-runtime-v1371.out" >/dev/null
fi

echo 'V1373 PHASE 2A: build current host KCC before its native phases'
if ! make -j2 -C "$kcc_repo" \
    "HOST_BUILD_DIR=$host" "KCC=$host/kcc" "$host/kcc" \
    > "$work/host-build-v1373.log" 2>&1; then
    tail -70 "$work/host-build-v1373.log" >&2
    exit 1
fi
"$host/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DHOST_DAIMOS=1 -DHOST_UNIX=0 -I"$kcc_repo" \
    -I"$kcc_repo/self/include" \
    -H"$kcc_repo/self/include" -S \
    "$kcc_repo/cccode.c" -o "$work/cccode-abi-v1373.s" \
    > "$work/cccode-abi-v1373.log" 2>&1
python3 - "$work/cccode-abi-v1373.s" <<'PY'
from pathlib import Path
import re
import sys
asm = Path(sys.argv[1]).read_text()
if 'code1:\n' not in asm or 'codr1:\n' not in asm:
    raise SystemExit('v1373: missing nested-code1 test entry')
body = asm.split('code1:\n', 1)[1].split('\ncodr1:\n', 1)[0]
if not (re.search(r'\bpush\s+17,1\b', body, re.I) and
        re.search(r'\bpushj\s+17,vrtoreal\b', body, re.I) and
        re.search(r'\bpop\s+17,\d+', body, re.I) and
        re.search(r'\bmove\s+1,\d+', body, re.I)):
    raise SystemExit('v1373: code1 loses op across nested vrtoreal call')
print('V1373_NESTED_CALL_ABI_PASS incoming AC1 preserved across vrtoreal')
PY

echo 'V1373 PHASE 2B: build native KCC and all four phases using fixed host'
if ! make -j2 -C "$kcc_repo" \
    "NATIVE_BUILD_DIR=$native" \
    "NATIVE_DAIMOS_LIBC_ROOT=$native/daimos-libc" \
    "DAIMOS_REPO=$daimos" "PDP10_PREFIX=$PDP10_PREFIX" \
    "KCC=$host/kcc" \
    "$native/KCC.dxr" "$native/KCPP.dxr" \
    "$native/KPARSE.dxr" "$native/KGEN.dxr" "$native/KOPT.dxr" \
    > "$work/build-v1373.log" 2>&1; then
    tail -65 "$work/build-v1373.log" >&2
    exit 1
fi
for name in KCC KCPP KPARSE KGEN KOPT; do
    dxrcheck "$native/$name.dxr"
done
echo 'V1373_CURRENT_NATIVE_KCC_LINK_PASS images=5'

echo 'V1373 PHASE 3: stage independent host C-SIX input and golden output'
csix -e "$here/fixture-v1373.c" "$work/fixture-v1373.s6"
"$host/kcc" -Pgnu99 -O -x=pdp6 -m=gas -S \
    "$here/fixture-v1373.c" -o "$work/fixture-host-v1373.s"
"$host/kcc" -Pgnu99 -O -x=pdp6 -m=gas -S \
    "$here/abi-nested-call-v1373.c" -o "$work/nested-host-v1373.s"
csix -e "$here/abi-nested-call-v1373.c" "$work/nested-v1373.s6"
das -F -C -O "$work/nested-v1373.dobj" "$work/nested-host-v1373.s"
native_lib="$v1370/userland-build/userland/d6lz/libc"
dlink --daimos-uuo-relax -b 020 -o "$work/nested-v1373.dxr" \
    -M "$work/nested-v1373.map" "$native_lib/crt0.dobj" \
    "$native_lib/syscall.dobj" "$native_lib/syscall_helpers.dobj" \
    "$native_lib/u.dobj" "$work/nested-v1373.dobj"
dxrcheck "$work/nested-v1373.dxr"
if ! grep -i 'movei.*1,012345' "$work/fixture-host-v1373.s" >/dev/null; then
    echo 'v1373: host KCC did not emit reference MOVEI instruction' >&2
    exit 1
fi
python3 - "$work/fixture-host-v1373.s" "$work/fixture-host-v1373.a7" \
    "$work/nested-host-v1373.s" "$work/nested-host-v1373.a7" <<'PY'
import struct
import sys
from pathlib import Path
for source, target in ((sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])):
    raw = Path(source).read_bytes()
    words = []
    for offset in range(0, len(raw), 5):
        word = 0
        for slot, ch in enumerate(raw[offset:offset+5]):
            if ch > 127:
                raise SystemExit('host assembler output not ASCII7')
            word |= ch << (29 - slot * 7)
        words.append(word)
    Path(target).write_bytes(struct.pack('<' + 'Q'*len(words), *words))
    print('V1373_GOLDEN_PACKED7_PASS words=%d input=%s' % (len(words), Path(source).name))
PY

echo 'V1373 PHASE 4: build grouped full root with only five KCC replacements'
export V1372_NORMAL_BUILD="$v1371/normal-build"
if ! python3 -B "$here/build_root_v1373.py" \
    "$daimos" "$testkit" "$work" "$native" \
    "$work/fixture-v1373.s6" "$work/fixture-host-v1373.a7" \
    "$work/nested-v1373.s6" "$work/nested-host-v1373.a7" \
    "$work/nested-v1373.dxr" \
    > "$work/root-v1373.log" 2>&1; then
    tail -65 "$work/root-v1373.log" >&2
    exit 1
fi
grep -E '^V1373_.*PASS' "$work/root-v1373.log"
python3 - "$v1370/boot-grouped-v1370.simh" \
    "$work/boot-v1373.simh" "$v1370" \
    "$work/disk-pristine-v1373" <<'PY'
from pathlib import Path
import sys
source, target, old, disk = sys.argv[1:]
cfg = Path(source).read_text()
marker = old + '/disk-grouped-v1370/'
if cfg.count(marker) != 4 or cfg.count('grouped-kinit-v1370.dta') != 1:
    raise SystemExit('v1373: grouped SIMH boot config mismatch')
Path(target).write_text(cfg.replace(marker, disk + '/'))
PY

cat > "$work/probes-v1373" <<'EOF'
probe fresh-kcc-compile-v1373
command /OPTION/BASE/EXEC/KCC -Pgnu99 -O -x=pdp6 -m=gas -S -O /SCRATCH/V1373-CURRENT.A7 /CONFIG/V1373.C; ECHO KCCSTATUS:$?
contains KCCSTATUS:0
timeout 220
end
probe fresh-kcc-host-byte-equality-v1373
command CMP /SCRATCH/V1373-CURRENT.A7 /CONFIG/V1373-GOLD.A7; ECHO GOLDSTATUS:$?
contains GOLDSTATUS:0
timeout 65
end
probe fresh-kcpp-v1373
command /OPTION/BASE/LIBEXEC/KCC/KCPP -R=/SCRATCH/V1373.KPT /CONFIG/V1373.C; ECHO CPPSTATUS:$?
contains CPPSTATUS:0
timeout 100
end
probe fresh-kparse-v1373
command /OPTION/BASE/LIBEXEC/KCC/KPARSE -R=/SCRATCH/V1373.KIR /SCRATCH/V1373.KPT; ECHO PARSESTATUS:$?
contains PARSESTATUS:0
timeout 130
end
probe fresh-kgen-v1373
command /OPTION/BASE/LIBEXEC/KCC/KGEN -R=/SCRATCH/V1373.KP2 /SCRATCH/V1373.KIR; ECHO GENSTATUS:$?
contains GENSTATUS:0
timeout 170
end
probe fresh-kpcode2-header-v1373
command HEXDUMP /SCRATCH/V1373.KP2
contains 104105062000
timeout 55
end
probe fresh-kopt-v1373
command /OPTION/BASE/LIBEXEC/KCC/KOPT -R=/SCRATCH/V1373-REPLAY.A7 /SCRATCH/V1373.KP2; ECHO OPTSTATUS:$?
contains OPTSTATUS:0
timeout 100
end
probe fresh-kopt-host-byte-equality-v1373
command CMP /SCRATCH/V1373-REPLAY.A7 /CONFIG/V1373-GOLD.A7; ECHO REPLAYSTATUS:$?
contains REPLAYSTATUS:0
timeout 65
end
probe fresh-nested-abi-execute-v1373
command /SYSTEM/EXEC/V1373ABI; ECHO ABISTATUS:$?
contains ABISTATUS:0
timeout 60
end
EOF

echo 'V1373 PHASE 5: native PDP-6 current compiler output vs independent host'
if ! sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$daimos" --dofile "$work/boot-v1373.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$work/probes-v1373" --isolate-media \
    --work-dir "$work/native-v1373" \
    --markdown-report "$work/report-v1373.md" \
    --boot-timeout 115 --timeout 240 > "$work/native-v1373.log" 2>&1; then
    tail -70 "$work/native-v1373.log" >&2
    tail -70 "$work/native-v1373/simh.log" >&2
    exit 1
fi
cat "$work/native-v1373.log"
if grep '^FAIL' "$work/native-v1373/results.tsv" >/dev/null; then
    echo 'v1373: native compiler phase mismatch' >&2
    exit 1
fi
test "$(grep -c '^PASS' "$work/native-v1373/results.tsv")" -eq 9
echo 'PASS v1373: corrected nested-call ABI and native KCC single-function codegen; global-symbol KIR failure remains separate'
