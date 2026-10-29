#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
work=$(mktemp -d "$TMPDIR/daimos-badmap-native-v705.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
cat > "$work/test.s" <<'EOF'
.text
.globl main
.globl __test_exit
.globl badmap_state
.globl badmap_base_map_call
.globl badmap_map_block
main:
    movei 2,1
    movem 2,badmap_state+2
    movei 2,3
    movem 2,badmap_state+3
    movei 2,0100
    movem 2,badmap_state+7
    movei 2,0200
    movem 2,badmap_state+010
    movei 1,4
    pushj 17,badmap_map_block
    caie 1,3
    jrst fail
    caie 2,0104
    jrst fail
    movei 2,blockset_stub
    hrrm 2,badmap_base_map_call
    movei 1,4
    pushj 17,badmap_map_block
    caie 1,3
    jrst fail
    caie 2,077
    jrst fail
    setz 1,
    popj 17,
blockset_stub:
    movei 1,3
    movei 2,077
    popj 17,
fail:
    movei 1,1
    popj 17,
.globl kret_neg1
kret_neg1:
    seto 1,
    popj 17,
.bss
__test_exit: .block 1
EOF
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 20000 --timeout 15 \
  --workdir "$work/run" --name daimos-badmap-native-v705 --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" \
  "$DAIMOS_REPO/system/kernel/storage/badmap_dispatch.s" \
  "$work/test.s" > "$work/log" 2>&1 || { cat "$work/log"; exit 1; }
echo 'v705: native PDP-6 singleton and direct-patched BLOCKSET mapper PASS'
