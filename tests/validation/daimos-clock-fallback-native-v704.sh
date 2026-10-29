#!/bin/sh
# Execute unbound calendar fallback routines on a real PDP-6 instruction model.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-clock-native-v704.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
cat > "$work/probe.s" <<'EOF'
.text
.globl main
.globl __test_exit
.globl wall_time36
.globl wall_clock_set
main:
    movei 1,012345
    pushj 17,wall_time36
    jumpn 1,fail
    movei 1,012345
    pushj 17,wall_clock_set
    jumpl 1,ok
fail:
    movei 1,1
    popj 17,
ok:
    setz 1,
    popj 17,
.bss
__test_exit: .block 1
EOF
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
    --start 1000 --step-limit 20000 --timeout 15 --workdir "$work/run" \
    --name daimos-clock-fallback-v704 --expect __test_exit=0 \
    "$self/daimos-test-crt0-v1.s" \
    "$DAIMOS_REPO/system/kernel/drivers/pclk_gateway.s" "$work/probe.s" \
    > "$work/test.log" 2>&1 || { cat "$work/test.log"; exit 1; }
echo 'v704: native PDP-6 TIME36 zero and SETTIME -1 defaults PASS'
