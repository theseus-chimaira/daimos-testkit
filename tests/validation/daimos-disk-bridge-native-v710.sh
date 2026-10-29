#!/bin/sh
# Real PDP-6 instruction execution of both KCORE bridges.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
work=$(mktemp -d "$TMPDIR/daimos-disk-bridge-v710.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
cat > "$work/probe.s" <<'EOF'
.text
.globl main
.globl __test_exit
.globl kret_neg1
main:
    movei 1,0
    movei 2,1
    movei 3,1
    pushj 17,drm236_read_block
    jumpl 1,drm_fallback_ok
    jrst fail
drm_fallback_ok:
    movei 0,service
    hrrm 0,drm236_read_call
    hrrm 0,drm236_write_jump
    hrrm 0,dsk270_read_call
    hrrm 0,dsk270_write_jump
    movei 1,0
    movei 2,1
    movei 3,1
    pushj 17,drm236_read_block
    caie 1,7
    jrst fail
    movei 1,0
    movei 2,1
    movei 3,1
    pushj 17,drm236_write_block
    caie 1,7
    jrst fail
    movei 1,0
    movei 2,1
    movei 3,1
    pushj 17,dsk270_read_sector
    caie 1,7
    jrst fail
    movei 1,0
    movei 2,1
    movei 3,1
    pushj 17,dsk270_write_sector
    caie 1,7
    jrst fail
    setz 1,
    popj 17,
service:
    movei 1,7
    popj 17,
fail:
    movei 1,1
    popj 17,
kret_neg1:
    seto 1,
    popj 17,
.bss
__test_exit: .block 1
EOF
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
  --start 1000 --step-limit 25000 --timeout 15 --workdir "$work/run" \
  --name daimos-disk-bridge-v710 --expect __test_exit=0 \
  "$self/daimos-test-crt0-v1.s" \
  "$DAIMOS_REPO/system/kernel/drivers/dsk270.s" \
  "$DAIMOS_REPO/system/kernel/drivers/drm236.s" "$work/probe.s" \
  > "$work/log" 2>&1 || { cat "$work/log"; exit 1; }
echo 'v710: native PDP-6 DSK270/DRM236 direct read/write PASS'
