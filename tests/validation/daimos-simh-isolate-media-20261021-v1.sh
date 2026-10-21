#!/bin/sh
# Host contract: simulator runs must never mutate the built root fixture.
set -eu
: "${TMPDIR:=$HOME/tmp}"
here=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
work=$TMPDIR/daimos-simh-isolate-media-20261021-v1-$$
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
printf 'CLEAN BASE\n' > "$work/dsk0.dsk"
printf 'DRUM BASE\n' > "$work/dr0.dsk"
cat > "$work/boot.ini" <<EOF
set cpu 256k
attach -q dsk0 $work/dsk0.dsk
attach -q dr0 $work/dr0.dsk
attach -q dcs0 1101
EOF
tool=$here/tools/daimos-simh-isolate-media-20261021-v1.sh
sh "$tool" "$work/boot.ini" "$work/first.ini" "$work/first"
grep -F "attach -q dsk0 $work/first/dsk0-dsk0.dsk" \
    "$work/first.ini" >/dev/null
grep -F "attach -q dr0 $work/first/dr0-dr0.dsk" \
    "$work/first.ini" >/dev/null
grep -F 'attach -q dcs0 1101' "$work/first.ini" >/dev/null
printf 'DIRTY\n' > "$work/first/dsk0-dsk0.dsk"
printf 'MODIFIED\n' > "$work/first/dr0-dr0.dsk"
sh "$tool" "$work/boot.ini" "$work/second.ini" "$work/second"
printf 'CLEAN BASE\n' > "$work/expect-dsk"
printf 'DRUM BASE\n' > "$work/expect-drum"
cmp "$work/expect-dsk" "$work/dsk0.dsk"
cmp "$work/expect-dsk" "$work/second/dsk0-dsk0.dsk"
cmp "$work/expect-drum" "$work/dr0.dsk"
cmp "$work/expect-drum" "$work/second/dr0-dr0.dsk"
printf 'SIMH media isolation v1: PASS (root, drum, TCP, second boot)\n'
