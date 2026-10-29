#!/bin/sh
# Fault a genuine KINIT idle-stack mm_alloc call after normal MINIT.
# The executable instruction is modified only in transient SIMH RAM.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-mm-fail-v650.XXXXXX")
passed=0
trap 'if [ "$passed" -eq 1 ]; then rm -rf "$work"; else echo "v650 diagnostics: $work" >&2; fi' EXIT HUP INT TERM
build=${DAIMOS_KINIT_MM_BUILD_V650:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
  BUILD="$build" BOOT_PROFILE=full ROOT=disk COMPILER=gcc \
  BOOT_CORE_WORDS=0300000 SIMH_CPU_KWORDS=96 KINIT_STACK_WATERMARK=1 \
  > "$work/build.log" 2>&1 || { tail -30 "$work/build.log" >&2; exit 1; }
python3 - "$build" "$work/addresses" <<'PY'
from pathlib import Path
import sys

build, output = Path(sys.argv[1]), Path(sys.argv[2])
symbols = {}
for line in (build / 'kinit.map').read_text().splitlines():
    fields = line.split()
    if len(fields) == 2 and fields[0] in (
        'kinit_enter', 'mm_alloc', '__kinit_image_start'):
        symbols[fields[0]] = int(fields[1], 8)
for key in ('kinit_enter', 'mm_alloc', '__kinit_image_start'):
    assert key in symbols, key
lines = (build / 'kinit.raw.words').read_text().splitlines()
call = '%012o' % (0o260740000000 | symbols['mm_alloc'])
# This exact call signature is the idle-stack allocation, not the earlier
# dynamic MINIT allocator. No fixed linked address is assumed.
signature = ['201040000100', '201100000003', '201140000002',
             '201200000000', call]
matches = [i for i in range(len(lines) - len(signature) + 1)
           if lines[i:i+len(signature)] == signature]
assert len(matches) == 1, ('idle-stack mm_alloc callsite', matches)
site = symbols['__kinit_image_start'] + matches[0] - 3
assert site > symbols['kinit_enter']
with output.open('w') as f:
    f.write('ENTRY=%o\nPATCH=%o\n' % (symbols['kinit_enter'], site))
PY
entry=$(sed -n 's/^ENTRY=//p' "$work/addresses")
patch=$(sed -n 's/^PATCH=//p' "$work/addresses")
watermark=$(awk '$1 == "kinit_stack_highwater" {print $2; exit}' "$build/kcore.map")
case "$watermark:$entry:$patch" in *[!0-7:]*|:*|*:) echo 'invalid link addresses' >&2; exit 1;; esac
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/preflight.log" 2>&1 || {
    echo 'v650 requires CLEAN input media' >&2; cat "$work/preflight.log" >&2; exit 1;
}
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
  "$build/boot.ini" "$work/base.ini" 32850 46850
# Break after Stage1 has loaded the KINIT image, before the first instruction
# of kinit_enter. Change idle-stack request from 0100 words to 0777777,
# which exceeds the available 96K and must make mm_alloc return MM_NO_SPACE.
# Do not patch source or persisted boot image; resume only this SIMH instance.
awk -v entry="$entry" -v patch="$patch" -v watermark="$watermark" '
  /^go 020$/ {
    print "break " entry; print
    print "deposit " patch " 201040777777"
    print "nobreak"; print "continue"; next
  }
  /^exit$/ { print "examine " watermark }
  { print }
' "$work/base.ini" > "$work/failure.ini"
set +e
(cd "$build" && TERM=dumb timeout -k 2s 45s "$PDP10_PREFIX/bin/pdp6" \
  "$work/failure.ini") > "$work/boot.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || { tail -50 "$work/boot.log" >&2; exit 1; }
grep -Fq "Breakpoint, PC: $(printf '%06o' "$((0$entry))")" "$work/boot.log"
grep -q 'HALT instruction' "$work/boot.log"
grep -Eq '^MEM[[:space:]]+96 K' "$work/boot.log"
grep -Eq 'D6FS[[:space:]]+LOADED' "$work/boot.log"
if grep -q 'INIT V1\|?RT' "$work/boot.log"; then
    echo 'v650 reached wrong failure path' >&2; exit 1
fi
short=$(printf '%o' "$((0$watermark))")
value=$(awk -v addr="$short" '$1 == addr ":" {print $2; exit}' "$work/boot.log")
case "$value" in ''|*[!0-7]*) echo 'missing high-water sample' >&2; exit 1;; esac
used=$((0$value))
if [ "$used" -le 0 ] || [ "$used" -ge "$((0600))" ]; then
    echo "v650 stack bound exceeded: $value" >&2; exit 1
fi
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/postflight.log" 2>&1 || {
    echo 'v650 unexpectedly modified disk root' >&2; exit 1;
}
passed=1
printf 'daimos-kinit-mm-alloc-failure-v650: PASS (allocation HALT, %o octal / %d words)\n' "$used" "$used"
