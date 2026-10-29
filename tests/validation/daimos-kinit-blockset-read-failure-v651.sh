#!/bin/sh
# Native 96K KINIT: force a real blockset_boot_read failure, keep media CLEAN.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-io-v651.XXXXXX")
passed=0
trap 'if [ "$passed" -eq 1 ]; then rm -rf "$work"; else echo "v651 diagnostics: $work" >&2; fi' EXIT HUP INT TERM
build=${DAIMOS_KINIT_IO_BUILD_V651:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
  BUILD="$build" BOOT_PROFILE=full ROOT=disk COMPILER=gcc \
  BOOT_CORE_WORDS=0300000 SIMH_CPU_KWORDS=96 KINIT_STACK_WATERMARK=1 \
  > "$work/build.log" 2>&1 || { tail -35 "$work/build.log" >&2; exit 1; }
entry=$(awk '$1 == "kinit_enter" {print $2; exit}' "$build/kinit.map")
read_service=$(awk '$1 == "blockset_boot_read" {print $2; exit}' "$build/kinit.map")
watermark=$(awk '$1 == "kinit_stack_highwater" {print $2; exit}' "$build/kcore.map")
case "$entry:$read_service:$watermark" in *[!0-7:]*|::*|:*|*:) echo 'missing linked symbols' >&2; exit 1;; esac
# Check the exact original instructions before injecting a 0/-1 read error.
# Otherwise the test could silently become an unrelated execution fault.
python3 - "$build/kinit.raw.words" "$read_service" <<'PY'
from pathlib import Path
import sys
lines = Path(sys.argv[1]).read_text().splitlines()
index = int(sys.argv[2], 8) - 0o30000 + 3
assert 0 <= index < len(lines)
assert lines[index] != '476040000000'
print('v651 blockset read entry:', oct(int(sys.argv[2], 8)), lines[index])
PY
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/preflight.log" 2>&1 || {
    echo 'v651 requires CLEAN input D6FS' >&2; cat "$work/preflight.log" >&2; exit 1;
}
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
  "$build/boot.ini" "$work/base.ini" 32861 46861
# Patch only live KINIT memory after Stage1 image loading. SETO AC1 and
# POPJ 17 simulate the storage service's error ABI for every read; root
# selection still uses physical controller I/O and remains valid.
awk -v entry="$entry" -v read="$read_service" -v nextaddr="$(printf '%o' "$((0$read_service + 1))")" \
    -v watermark="$watermark" '
  /^go 020$/ {
    print "break " entry; print
    print "deposit " read " 476040000000"
    print "deposit " nextaddr " 263740000000"
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
[ "$rc" -eq 0 ] || { tail -60 "$work/boot.log" >&2; exit 1; }
grep -Fq "Breakpoint, PC: $(printf '%06o' "$((0$entry))")" "$work/boot.log"
grep -Fq '?RT' "$work/boot.log"
grep -q 'HALT instruction' "$work/boot.log"
grep -Eq '^MEM[[:space:]]+96 K' "$work/boot.log"
grep -Eq 'D6FS[[:space:]]+LOADED' "$work/boot.log"
short=$(printf '%o' "$((0$watermark))")
value=$(awk -v addr="$short" '$1 == addr ":" {print $2; exit}' "$work/boot.log")
case "$value" in ''|*[!0-7]*) echo 'missing watermark' >&2; exit 1;; esac
used=$((0$value))
[ "$used" -gt 0 ] && [ "$used" -lt "$((0600))" ] || {
  echo "v651 bad stack high-water: $value" >&2; exit 1;
}
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/postflight.log" 2>&1 || {
  echo 'v651 changed source media' >&2; exit 1;
}
passed=1
printf 'daimos-kinit-blockset-read-failure-v651: PASS (?RT, %o octal / %d words)\n' "$used" "$used"
