#!/bin/sh
# Test installed integrated host DLINK, not historical standalone sources.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/dlink-rh18-test-v1977.XXXXXX")
trap 'echo "v1977 RH18 evidence: $work"' EXIT
bin="$PDP10_PREFIX/bin"
"$bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 30 --workdir "$work/guest" --name rh18-wrap-v1977 \
    --expect __test_exit=0 "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$here/main-v1977.s" "$here/probe-v1977.s" "$here/external-v1977.s"
"$bin/pdp10-objdump" -r "$work/guest/p10run-003-probe-v1977.dobj" > "$work/relocs.txt"
cat "$work/relocs.txt"
grep 'type=1 target=.data addend=777777,,700000' "$work/relocs.txt"
grep 'type=2 symbol=rh18_external_v1977 addend=777777,,700000' "$work/relocs.txt"
# Positive RH18 overflow and negative LH18 must still be rejected.
cat > "$work/positive-v1977.s" <<'ASM'
.text
.globl start
start: move 1,target+0377777
       halt
.data
target: .word 0
ASM
cat > "$work/lh-v1977.s" <<'ASM'
.text
.globl start
start: halt
.data
target: .word target-0100000,,0
ASM
for guard in positive lh; do
    "$bin/das" -C -O "$work/$guard.dobj" "$work/$guard-v1977.s"
    base=020
    [ "$guard" != positive ] || base=0777000
    if "$bin/dlink" -b "$base" -o "$work/$guard.dxr" "$work/$guard.dobj" > "$work/$guard.log" 2>&1; then
        echo "FAIL: $guard relocation accepted"; exit 1
    fi
    grep 'RH18 relocation overflow' "$work/$guard.log"
done
echo 'PASS: negative local/symbol RH18, positive and LH18 guards'
