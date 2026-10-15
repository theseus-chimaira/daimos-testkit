#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

TESTKIT_ROOT=${TESTKIT_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)}
BUILD_ROOT=${BUILD_ROOT:-$TMPDIR/d6codec-pure-verify-v088-build-$$}
KCC_REPO=${KCC_REPO:-$HOME/git/kcc}
DAS_REPO=${DAS_REPO:-$HOME/git/das}
export KCC_REPO DAS_REPO
D6LZ_HOST=${D6LZ_HOST:-$PDP10_PREFIX/bin/d6lz}
KERNEL_BUILD=${KERNEL_BUILD:-$BUILD_ROOT/tests/system/kernel}
PTY_RUN=${PTY_RUN:-$BUILD_ROOT/tools/pty-run-v1}
TCP_RUN=${TCP_RUN:-$BUILD_ROOT/tools/tcp-run-v1}
LOGSTORE=${LOGSTORE:-$PDP10_PREFIX/bin/logstore}
HARNESS=$TESTKIT_ROOT/tools/daimos-simh-harness-v4.sh
WATCH_OUTPUT=$TESTKIT_ROOT/tools/watch-output.sh
PROBES=$TESTKIT_ROOT/tests/system/d6codec-pure-verify-v088/probes-v088.txt
MKDSK=${MKDSK:-$PDP10_PREFIX/bin/mkdsk}
MKD6FS=${MKD6FS:-$PDP10_PREFIX/bin/mkd6fs}
S6TEXT=${S6TEXT:-$PDP10_PREFIX/bin/s6text}
SIMH_PDP6=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
WORK=$TMPDIR/daimos-d6codec-pure-verify-v088-$$
dcs_port=$((29000 + ($$ % 1000)))
REPORT=${D6CODEC_USERSPACE_V088_REPORT:-$BUILD_ROOT/report-v088.md}
INITTAB=$WORK/inittab-dcs0
INITTAB_S6REC=$WORK/inittab-dcs0.s6rec
PASSWD_S6REC=$WORK/passwd.s6rec

cleanup()
{
        rm -rf "$WORK"
}
trap cleanup 0 1 2 3 15
mkdir -p "$WORK/disk" "$(dirname "$REPORT")" "$BUILD_ROOT/tools"
printf '%s\n' '1:RESPAWN:/SYSTEM/EXEC/LOGIN' > "$INITTAB"
"$S6TEXT" --encode "$INITTAB" "$INITTAB_S6REC"
"$S6TEXT" --encode "$DAIMOS_REPO/userland/config/passwd" "$PASSWD_S6REC"

if [ ! -x "$PTY_RUN" ]; then
        ${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra \
            -o "$PTY_RUN" "$TESTKIT_ROOT/tools/pty-run-v1.c"
fi
if [ ! -x "$TCP_RUN" ]; then
        ${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra \
            -o "$TCP_RUN" "$TESTKIT_ROOT/tools/tcp-run-v1.c"
fi

make -C "$TESTKIT_ROOT/tests/system/kernel" image \
    DAIMOS_REPO="$DAIMOS_REPO" BUILD="$KERNEL_BUILD" \
    PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR" \
    BOOT_PROFILE=full COMPILER=gcc \
    PROC_SWAP_VERIFY_PURE=1 \
    D6LZ_HOST="$D6LZ_HOST"

# Do not accept a smoke result from a build which silently disabled the
# diagnostic verification body. This does not prove that swap invoked it.
grep -q '^proc_swap_verify_pure:' "$KERNEL_BUILD/kcore-asm/proc_swap.s"

"$MKDSK" -n 1 -m clean -p "$KERNEL_BUILD/kinit.d6lz.words" \
    -o "$WORK/disk" --d6fs-layout --logstore-blocks 0400 \
    --swap-tail-blocks 0200
# DSH dispatches external executables.  Supply every
# program exercised by probes-v1.txt, rather than treating "NOT FOUND" as a
# successful file operation on an otherwise empty bootstrap image.
set -- -n 1 -d "$WORK/disk" \
    -D /TEMP:0777 \
    -D /SYSTEM:0555 -D /SYSTEM/EXEC:0555 -D /CONFIG:0755 \
    -f "/SYSTEM/INIT:$KERNEL_BUILD/userland-build/userland/init.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/MOUNTALL:$KERNEL_BUILD/userland-build/userland/mountall.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/LOGIN:$KERNEL_BUILD/userland-build/userland/login.d6lz.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/DSH:$KERNEL_BUILD/userland-build/userland/dsh.d6lz.dxr:555:dxr" \
    -f "/CONFIG/INITTAB:$INITTAB_S6REC:644:binwords" \
    -f "/CONFIG/PASSWD:$PASSWD_S6REC:600:binwords"
for command in TOUCH STAT ECHO CAT CP MV MKDIR RM LS; do
        program=$KERNEL_BUILD/userland-build/userland/program/$command.d6lz.dxr
        if [ ! -s "$program" ]; then
                echo "d6fs-recovery-v1: missing userland command $program" >&2
                exit 1
        fi
        if [ "$command" = LS ]; then
                # Mark a staged copy PURE while retaining its grouped payload.
                # This checks PURE flag admission, not eviction/reload.
                pure="$WORK/ls-pure-v088.dxr"
                python3 "$TESTKIT_ROOT/tests/system/d6codec-pure-verify-v088/mark-pure-v088.py" "$program" "$pure"
                program=$pure
        fi
        # Assert the file executed in the shell is really compressed DXR2.
        python3 "$TESTKIT_ROOT/tests/system/d6codec-pure-verify-v088/check-compressed-v088.py" "$program"
        set -- "$@" -f "/SYSTEM/EXEC/$command:$program:555:dxr"
done
set -- "$@" -f "/SYSTEM/EXEC/D6LZ:$KERNEL_BUILD/userland-build/userland/d6lz.dxr:555:dxr"
"$MKD6FS" "$@"
"$LOGSTORE" -n 1 -d "$WORK/disk" --init >/dev/null

sed -e "s|set -q -n log .*|set -q -n log $WORK/simh.log|" \
    -e "s|attach -q dsk0 .*|attach -q dsk0 $WORK/disk/dsk0.dsk|" \
    -e '/^attach -q dsk[123] /d' \
    -e "s|attach -q dcs0 .*|attach -q dcs0 $dcs_port|" \
    -e '/^attach -q ge0 /d' \
    "$KERNEL_BUILD/boot.ini" > "$WORK/kinit.ini"
"$HARNESS" --daimos-repo "$DAIMOS_REPO" --dofile "$WORK/kinit.ini" \
    --pty-run "$PTY_RUN" --tcp-run "$TCP_RUN" --dcs-port "$dcs_port" \
    --boot-timeout 180 --login ROOT --probes "$PROBES" --work-dir "$WORK/run" \
    --markdown-report "$REPORT"
# Inspect the real on-disk files after the scripted userspace compressor ran.
# The exporter reuses the exact D6FS checker mapping and extent reader.
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -Wno-unused-function -I"$DAIMOS_REPO/tools/host" \
    "$TESTKIT_ROOT/tests/system/d6codec-userspace-v077/export-v077.c" \
    -o "$WORK/export-v088"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
    -I"$DAIMOS_REPO/tools/host" \
    "$TESTKIT_ROOT/tests/system/d6codec-userspace-v077/verify-v077.c" \
    "$DAIMOS_REPO/tools/host/d6codec-group-v071.c" \
    -o "$WORK/verify-v088"
for path in /CONFIG/PASSWD /SYSTEM/INIT; do
    case "$path" in
        /CONFIG/PASSWD) name=PASSWD; compressed=/TEMP/GRP ;;
        /SYSTEM/INIT) name=INIT; compressed=/TEMP/INITGRP ;;
    esac
    "$WORK/export-v088" "$WORK/disk" "$path" "$WORK/$name.source"
    "$WORK/export-v088" "$WORK/disk" "$compressed" "$WORK/$name.grouped"
    "$WORK/verify-v088" "$WORK/$name.source" "$WORK/$name.grouped"
    # Native PDP-6 decode of the exact extracted stream, not regenerated
    # host-compressed data. This catches independent decoder mismatches.
    python3 "$TESTKIT_ROOT/tests/system/d6codec-userspace-v077/make-native-v077.py" \
        "$WORK/$name.source" "$WORK/$name.grouped" "$WORK/$name.native.s"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 20 \
        --workdir "$WORK/native-$name" \
        --name "d6codec-$name-native-v088" --expect __test_exit=0 \
        "$TESTKIT_ROOT/tests/validation/daimos-test-crt0-v1.s" \
        "$WORK/$name.native.s" \
        "$DAIMOS_REPO/system/kernel/core/d6codec_decode_group_v061.s"
done
echo 'PASS d6codec-pure-verify-v088 256K system and extracted host and native decoder parity'
