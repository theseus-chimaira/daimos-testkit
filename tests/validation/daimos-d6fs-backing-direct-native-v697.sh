#!/bin/sh
# Compare native PDP-6 execution of baseline and direct D6FS backend calls.
set -eu
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
work="$TMPDIR/daimos-d6fs-direct-native-v697"
mkdir -p "$work"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
for variant in base direct; do
    python3 - "$TMPDIR/daimos-d6fs-direct-ab-v696/fs_backing-$variant-v696.s" \
        "$work/$variant.s" "$variant" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s[s.index('fs_backing_direct_dispatch:'):s.index('fs_backing_direct_root_read_done:')]
names=['fs_backing_direct_read_jump','fs_backing_direct_write_jump',
 'fs_backing_direct_drm_read_jump','fs_backing_direct_drm_write_jump']
if sys.argv[3]=='direct':
 names += ['fs_backing_direct_root_read_call','fs_backing_direct_root_write_call',
 'fs_backing_direct_root_drm_read_call','fs_backing_direct_root_drm_write_call']
out='.text\n.globl main\n.globl fs_backing_direct_dispatch\n'+''.join('.globl '+x+'\n' for x in names)+s
out+='''fs_backing_direct_root_read_done:
    aos mfsdev_d6set_reads
    popj 17,
fs_backing_root_error:
    aos mfsdev_storage_errors+4
    popj 17,
.globl kret_neg1
kret_neg1:
    seto 1,
    popj 17,
.bss
.globl mfsdev_d6set_reads
.globl mfsdev_d6set_writes
.globl mfsdev_storage_errors
mfsdev_d6set_reads: .block 1
mfsdev_d6set_writes: .block 1
mfsdev_storage_errors: .block 5
'''
Path(sys.argv[2]).write_text(out)
PY
    # Root callbacks, backend selection and the fail-closed default are
    # exercised through the actual candidate or baseline instruction stream.
    cat >"$work/test-$variant.s" <<'EOF'
.text
.globl main
.globl __test_exit
main:
    movei 3,kret_neg1
    hrrm 3,fs_backing_direct_read_jump
    hrrm 3,fs_backing_direct_write_jump
    hrrm 3,fs_backing_direct_drm_read_jump
    hrrm 3,fs_backing_direct_drm_write_jump
    movei 1,4
    movei 2,5
    setz 7,
    movei 6,0100000
    pushj 17,fs_backing_direct_dispatch
    jumpl 1,missing_ok
    jrst fail
missing_ok:
    skipn mfsdev_storage_errors+4
    jrst fail
    movei 3,success_service
    hrrm 3,fs_backing_direct_read_jump
    hrrm 3,fs_backing_direct_write_jump
    hrrm 3,fs_backing_direct_drm_read_jump
    hrrm 3,fs_backing_direct_drm_write_jump
    movei 1,4
    setz 7,
    movei 6,0100000
    pushj 17,fs_backing_direct_dispatch
    jumpn 1,fail
    move 2,mfsdev_d6set_reads
    caie 2,1
    jrst fail
    movei 1,4
    movei 7,1
    movei 6,0500000
    pushj 17,fs_backing_direct_dispatch
    jumpn 1,fail
    move 2,mfsdev_d6set_writes
    caie 2,1
    jrst fail
    setz 1,
    popj 17,
success_service:
    setz 1,
    popj 17,
fail:
    movei 1,1
    popj 17,
.bss
__test_exit: .block 1
EOF
    if [ "$variant" = direct ]; then
        # Direct root PUSHJ targets must be patched independently of the
        # ordinary-tail service slots, as KINIT will do at install time.
        sed -i '/hrrm 3,fs_backing_direct_drm_write_jump/a\    hrrm 3,fs_backing_direct_root_read_call\n    hrrm 3,fs_backing_direct_root_write_call\n    hrrm 3,fs_backing_direct_root_drm_read_call\n    hrrm 3,fs_backing_direct_root_drm_write_call' "$work/test-$variant.s"
    fi
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 20000 --timeout 15 \
        --workdir "$work/run-$variant" --name "daimos-d6fs-v697-$variant" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$work/$variant.s" "$work/test-$variant.s" > "$work/$variant.log" 2>&1 || {
            cat "$work/$variant.log"; exit 1;
        }
    echo "v697: $variant PDP-6 root-accounting and missing-backend test PASS"
done
