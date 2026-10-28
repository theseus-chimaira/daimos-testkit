#!/bin/sh
# Force superblock validation failure after successful disk root discovery.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kinit-d6fs-fail-v649.XXXXXX")
passed=0
trap 'if [ "$passed" -eq 1 ]; then rm -rf "$work"; else echo "v649 diagnostics: $work" >&2; fi' EXIT HUP INT TERM
build=${DAIMOS_KINIT_D6FS_BUILD_V649:-$work/build}
PATH="$PDP10_PREFIX/bin:$PATH" make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
  BUILD="$build" BOOT_PROFILE=full ROOT=disk COMPILER=gcc \
  BOOT_CORE_WORDS=0300000 SIMH_CPU_KWORDS=96 KINIT_STACK_WATERMARK=1 \
  > "$work/build.log" 2>&1 || { tail -30 "$work/build.log" >&2; exit 1; }
address=$(awk '$1 == "kinit_stack_highwater" { print $2; exit }' "$build/kcore.map")
case "$address" in ''|*[!0-7]*) echo 'missing stack-watermark symbol' >&2; exit 1;; esac
"$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$build/disk" > "$work/preflight.log" 2>&1 || {
    echo 'v649 requires CLEAN input diskset' >&2; cat "$work/preflight.log" >&2; exit 1;
}
cp -a "$build/disk" "$work/disk"
# Preserve valid member descriptors, root selector and the disk layout.
# Corrupt only both D6FS superblock magic words in isolated media.
python3 - "$work/disk" <<'PY'
import os, struct, sys
root = sys.argv[1]
def read_word(member, sector, index):
    with open(os.path.join(root, 'dsk%d.dsk' % member), 'rb') as f:
        f.seek((sector * 128 + index) * 8)
        return struct.unpack('<Q', f.read(8))[0]
base_word = read_word(0, 0, 7)
base = base_word >> 18
assert base > 0
for index in (8, 9):
    logical = read_word(0, 0, index)
    assert logical > 0
    member = logical % 4
    sector = base + logical // 4
    path = os.path.join(root, 'dsk%d.dsk' % member)
    with open(path, 'r+b') as f:
        f.seek(sector * 128 * 8)
        original = struct.unpack('<Q', f.read(8))[0]
        assert original != 0
        f.seek(sector * 128 * 8)
        f.write(struct.pack('<Q', 0))
    print('v649: superblock', oct(logical), 'member', member,
          'sector', oct(sector), 'magic', oct(original), '-> 0')
PY
"$(dirname "$0")/../lib/daimos-simh-headless.sh" \
  "$build/boot.ini" "$work/base.ini" 32849 46849
sed "s|$build/disk/|$work/disk/|g" "$work/base.ini" > "$work/failure.ini"
awk -v address="$address" '/^exit$/ {print "examine " address} {print}' \
  "$work/failure.ini" > "$work/run.ini"
set +e
(cd "$build" && TERM=dumb timeout -k 2s 45s "$PDP10_PREFIX/bin/pdp6" \
  "$work/run.ini") > "$work/boot.log" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ] || { tail -40 "$work/boot.log" >&2; exit 1; }
grep -Fq '?RT' "$work/boot.log"
grep -q 'HALT instruction' "$work/boot.log"
grep -Eq '^MEM[[:space:]]+96 K' "$work/boot.log"
grep -Eq 'D6FS[[:space:]]+LOADED' "$work/boot.log"
short=$(printf '%o' "$((0$address))")
value=$(awk -v addr="$short" '$1 == addr ":" {print $2; exit}' "$work/boot.log")
case "$value" in ''|*[!0-7]*) echo 'missing high-water reading' >&2; exit 1;; esac
used=$((0$value))
if [ "$used" -le 0 ] || [ "$used" -ge "$((0600))" ]; then
    echo "v649 stack bound exceeded: $value" >&2; exit 1
fi
passed=1
printf 'daimos-kinit-d6fs-mount-failure-v649: PASS (?RT, %o octal / %d words)\n' "$used" "$used"
