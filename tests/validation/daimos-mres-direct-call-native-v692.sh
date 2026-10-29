#!/bin/sh
# Verify PDP-6 PUSHJ address-field patching and absent-service fallback.
set -eu
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mres-direct-native-v692.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
cat > "$work/probe.s" <<'EOF'
.text
.globl main
.globl __test_exit
main:
    pushj 17,sys_optional_call
    jumpl 1,probe_absent_ok
    jrst fail
probe_absent_ok:
    movei 2,success_target
    hrrm 2,sys_optional_call
    pushj 17,sys_optional_call
    caie 1,012345
    jrst fail
    setz 1,
    popj 17,
fail:
    movei 1,1
    popj 17,
sys_optional_call:
    pushj 17,absent_service
    popj 17,
absent_service:
    seto 1,
    popj 17,
success_target:
    movei 1,012345
    popj 17,
.bss
__test_exit: .block 1
EOF
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
 --start 1000 --step-limit 20000 --timeout 15 --workdir "$work/run" \
 --name daimos-mres-direct-call-native-v692 --expect __test_exit=0 \
 "$self/daimos-test-crt0-v1.s" "$work/probe.s" > "$work/log" 2>&1 || {
   cat "$work/log"; exit 1;
 }
echo 'v692 PDP-6 direct PUSHJ patch, default failure and installed target: PASS'
