#!/bin/sh
# Validate the documented reversible C-SIX format with packed ASCII7 input
# on the host and under real grouped-format PDP-6 DAIMOS.
set -eu
: "${DAIMOS_REPO:?select the staged DAIMOS checkout}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/daimos-csix-packed7-v1372"
repo=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
work="$TMPDIR/daimos-csix-packed7-v1372"
v1370="$TMPDIR/d6codec-fullboot-v1370"
v1371="$TMPDIR/d6codec-fulldist-v1371"
mkdir -p "$work"

if [ "${V1372_REUSE_VERIFIED_V1371:-0}" != 1 ]; then
    echo 'V1372 PHASE 1: repeat complete grouped cold-boot regression'
    if ! DAIMOS_REPO="$repo" sh \
        "$testkit/tests/validation/d6codec-fulldist-v1371/run-v1371.sh" \
        > "$work/full-boot-v1371.log" 2>&1; then
        tail -70 "$work/full-boot-v1371.log" >&2
        exit 1
    fi
else
    echo 'V1372 PHASE 1: reuse previously verified full grouped cold boot'
    test -s "$v1371/boot-runtime-v1371.out"
    grep -F 'V1371FULL' "$v1371/boot-runtime-v1371.out" >/dev/null
fi

echo 'V1372 PHASE 2: verify host -p input is identical to canonical C-SIX'
cc -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/csix-host-v1372" "$repo/tools/host/csix.c"
python3 - "$here/fixture-v1372.c" "$work" <<'PY'
import struct
from pathlib import Path
import sys
source, target = Path(sys.argv[1]), Path(sys.argv[2])
text = source.read_bytes()
if not text.endswith(b'\n'):
    raise SystemExit('fixture is not newline-terminated')

def pack(data):
    words = []
    for index in range(0, len(data), 5):
        value = 0
        for slot, ch in enumerate(data[index:index + 5]):
            if ch > 127:
                raise ValueError('non-ASCII7 fixture input')
            value |= ch << (29 - 7 * slot)
        words.append(value)
    return struct.pack('<' + 'Q' * len(words), *words)

(target / 'fixture-v1372.p7').write_bytes(pack(text))
(target / 'crlf-v1372.txt').write_bytes(
    b'int\tmain(void)\r\n{\r\n\treturn 7;\r\n}\r\n')
(target / 'crlf-v1372.p7').write_bytes(
    pack((target / 'crlf-v1372.txt').read_bytes()))
(target / 'invalid-v1372.p7').write_bytes(pack(b'int x;\n\x00A'))
(target / 'nonl-v1372.p7').write_bytes(pack(b'int x;'))
(target / 'badword-v1372.p7').write_bytes(pack(text)[:-3])
PY
"$work/csix-host-v1372" -e "$here/fixture-v1372.c" \
    "$work/expected-v1372.s6"
"$work/csix-host-v1372" -e -p "$work/fixture-v1372.p7" \
    "$work/packed-converted-v1372.s6"
cmp "$work/expected-v1372.s6" "$work/packed-converted-v1372.s6"
"$work/csix-host-v1372" -d "$work/packed-converted-v1372.s6" \
    "$work/roundtrip-v1372.c"
cmp "$here/fixture-v1372.c" "$work/roundtrip-v1372.c"
"$work/csix-host-v1372" -e "$work/crlf-v1372.txt" \
    "$work/crlf-expected-v1372.s6"
"$work/csix-host-v1372" -e -p "$work/crlf-v1372.p7" \
    "$work/crlf-packed-v1372.s6"
cmp "$work/crlf-expected-v1372.s6" "$work/crlf-packed-v1372.s6"
"$work/csix-host-v1372" -d "$work/crlf-packed-v1372.s6" \
    "$work/crlf-decoded-v1372.txt"
python3 - "$work/crlf-decoded-v1372.txt" <<'PY'
from pathlib import Path
import sys
actual = Path(sys.argv[1]).read_bytes()
expected = b'int     main(void)\n{\n        return 7;\n}\n'
if actual != expected:
    raise SystemExit('v1372: CRLF/tab canonicalization mismatch')
PY
for name in invalid nonl badword; do
    if "$work/csix-host-v1372" -e -p "$work/$name-v1372.p7" \
        "$work/$name-v1372.s6" > "$work/$name-v1372.log" 2>&1; then
        echo "v1372: accepted malformed packed ASCII7: $name" >&2
        exit 1
    fi
done
echo 'V1372_HOST_CSIX_PASS exact canonical encoding, lossless roundtrip, CRLF/tabs and 3 malformed inputs'

echo 'V1372 PHASE 3: build isolated native C89 CSIX without DAS changes'
native_objs="$v1370/userland-build/userland/d6lz/libc"
for name in crt0 syscall syscall_helpers u; do
    test -s "$native_objs/$name.dobj"
done
set --
for path in \
    system/kernel/boot system/kernel/core system/kernel/drivers \
    system/kernel/fs system/kernel/mm system/kernel/modules \
    system/kernel/proc system/kernel/storage userland/libc; do
    set -- "$@" "-I$repo/$path"
done
set -- "$@" "-I$PDP10_PREFIX/include"
kcc -Pgnu99 -O -x=pdp6 -m=gas "$@" -S \
    "$repo/userland/toolchain/csix_v1372.c" -o "$work/csix-native-v1372.s"
das -F -C -O "$work/csix-native-v1372.dobj" "$work/csix-native-v1372.s"
dlink --daimos-uuo-relax -b 020 \
    -o "$work/csix-native-v1372.dxr" -M "$work/csix-native-v1372.map" \
    "$native_objs/crt0.dobj" "$native_objs/syscall.dobj" \
    "$native_objs/syscall_helpers.dobj" "$native_objs/u.dobj" \
    "$work/csix-native-v1372.dobj"
dxrcheck "$work/csix-native-v1372.dxr"

echo 'V1372 PHASE 4: build full 237-file grouped root with test-only CSIX'
root="$work/full-root-v1372"
mkdir -p "$root"
if ! V1372_NORMAL_BUILD="$v1371/normal-build" python3 -B \
    "$testkit/tests/validation/d6codec-fulldist-v1371/build_full_root_v1371.py" \
    "$repo" "$testkit" "$root" \
    --extra-file "/CONFIG/V1372.A7:$work/fixture-v1372.p7:644:binwords" \
    --extra-file "/CONFIG/V1372.S6:$work/expected-v1372.s6:644:binwords" \
    --extra-file "/CONFIG/V1372-CRLF.A7:$work/crlf-v1372.p7:644:binwords" \
    --extra-file "/CONFIG/V1372-CRLF.S6:$work/crlf-expected-v1372.s6:644:binwords" \
    --extra-file "/CONFIG/V1372-BAD.A7:$work/invalid-v1372.p7:644:binwords" \
    --extra-file "/SYSTEM/EXEC/CSIX:$work/csix-native-v1372.dxr:555:dxr" \
    > "$work/root-v1372.log" 2>&1; then
    tail -65 "$work/root-v1372.log" >&2
    exit 1
fi
grep -E '^V137[12]_(INVENTORY|EXTRA_FILES|ROOT)_PASS' \
    "$work/root-v1372.log"

python3 - "$v1370/boot-grouped-v1370.simh" \
    "$work/boot-v1372.simh" "$v1370" \
    "$root/disk-pristine-v1371" <<'PY'
from pathlib import Path
import sys
source, output, old, new = sys.argv[1:]
ini = Path(source).read_text()
marker = old + '/disk-grouped-v1370/'
if ini.count(marker) != 4 or ini.count('grouped-kinit-v1370.dta') != 1:
    raise SystemExit('v1372: unexpected grouped boot configuration')
Path(output).write_text(ini.replace(marker, new + '/'))
PY

cat > "$work/probes-v1372" <<'EOF'
probe native-csix-v1372
command /SYSTEM/EXEC/CSIX /CONFIG/V1372.A7 /SCRATCH/CONVERTED-V1372.S6; ECHO CSIXSTATUS:$?
contains CSIXSTATUS:0
timeout 110
end
probe native-csix-exact-v1372
command CMP /SCRATCH/CONVERTED-V1372.S6 /CONFIG/V1372.S6; ECHO CMPSTATUS:$?
contains CMPSTATUS:0
timeout 50
end
probe native-csix-readable-v1372
command CAT /SCRATCH/CONVERTED-V1372.S6
contains RETURN 012345
timeout 35
end
probe native-csix-crlf-v1372
command /SYSTEM/EXEC/CSIX /CONFIG/V1372-CRLF.A7 /SCRATCH/CRLF-V1372.S6; ECHO CRLFSTATUS:$?
contains CRLFSTATUS:0
timeout 75
end
probe native-csix-crlf-exact-v1372
command CMP /SCRATCH/CRLF-V1372.S6 /CONFIG/V1372-CRLF.S6; ECHO CRLFCMP:$?
contains CRLFCMP:0
timeout 35
end
probe native-csix-kcc-v1372
command /OPTION/BASE/EXEC/KCC -Pgnu99 -O -x=pdp6 -m=gas -S -O /SCRATCH/OUTPUT-V1372.A7 /SCRATCH/CONVERTED-V1372.S6; ECHO KCCSTATUS:$?
contains KCCSTATUS:0
timeout 220
end
probe native-csix-invalid-v1372
command /SYSTEM/EXEC/CSIX /CONFIG/V1372-BAD.A7 /SCRATCH/INVALID-V1372.S6; ECHO BADSTATUS:$?
contains BADSTATUS:1
timeout 55
end
probe native-csix-invalid-cleanup-v1372
command LS /SCRATCH/INVALID-V1372.S6; ECHO NOFILE:$?
contains NOFILE:1
timeout 40
end
EOF

echo 'V1372 PHASE 5: native packed7 -> canonical editable C-SIX acceptance'
if ! sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$repo" --dofile "$work/boot-v1372.simh" \
    --pty-run "$v1370/pty-run-v1370" --login ROOT \
    --probes "$work/probes-v1372" --isolate-media \
    --work-dir "$work/native-v1372" \
    --markdown-report "$work/report-v1372.md" \
    --boot-timeout 110 --timeout 220 > "$work/native-v1372.log" 2>&1; then
    tail -65 "$work/native-v1372.log" >&2
    tail -65 "$work/native-v1372/simh.log" >&2
    exit 1
fi
cat "$work/native-v1372.log"
test "$(grep -c '^PASS' "$work/native-v1372/results.tsv")" -eq 8
if grep '^FAIL' "$work/native-v1372/results.tsv" >/dev/null; then
    echo 'v1372: unexpected native converter failure' >&2
    exit 1
fi
echo 'PASS v1372: host and PDP-6 native packed ASCII7 -> canonical reversible C-SIX/S6REC'
