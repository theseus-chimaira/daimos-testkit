#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

TESTKIT_ROOT=${TESTKIT_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)}
BUILD_ROOT=${BUILD_ROOT:-$TESTKIT_ROOT/build}
KERNEL_BUILD=${KERNEL_BUILD:-$BUILD_ROOT/tests/system/kernel}
PTY_RUN=${PTY_RUN:-$BUILD_ROOT/tools/pty-run-v1}
TCP_RUN=${TCP_RUN:-$BUILD_ROOT/tools/tcp-run-v1}
LOGSTORE=${LOGSTORE:-$PDP10_PREFIX/bin/logstore}
HARNESS=$TESTKIT_ROOT/tools/daimos-simh-harness-v4.sh
WATCH_OUTPUT=$TESTKIT_ROOT/tools/watch-output.sh
PROBES=$TESTKIT_ROOT/tests/system/d6fs-hdd-v2/probes-v1.txt
MKDSK=${MKDSK:-$PDP10_PREFIX/bin/mkdsk}
MKD6FS=${MKD6FS:-$PDP10_PREFIX/bin/mkd6fs}
S6TEXT=${S6TEXT:-$PDP10_PREFIX/bin/s6text}
SIMH_PDP6=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
WORK=$TMPDIR/daimos-d6fs-recovery-v1-$$
dcs_port=$((29000 + ($$ % 1000)))
REPORT=${D6FS_RECOVERY_REPORT:-$TESTKIT_ROOT/reports/d6fs-recovery-v1.md}
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
    PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR"

"$MKDSK" -n 1 -m clean -p "$KERNEL_BUILD/kinit.d6lz.words" \
    -o "$WORK/disk" --d6fs-layout --logstore-blocks 0400 \
    --swap-tail-blocks 0200
"$MKD6FS" -n 1 -d "$WORK/disk" \
    -D /TEMP:0777 \
    -D /SYSTEM:0555 -D /SYSTEM/EXEC:0555 -D /CONFIG:0755 \
    -f "/SYSTEM/INIT:$KERNEL_BUILD/userland-build/userland/init.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/LOGIN:$KERNEL_BUILD/userland-build/userland/login.d6lz.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/DSH:$KERNEL_BUILD/userland-build/userland/dsh.d6lz.dxr:555:dxr" \
    -f "/CONFIG/INITTAB:$INITTAB_S6REC:644:binwords" \
    -f "/CONFIG/PASSWD:$PASSWD_S6REC:600:binwords"
"$LOGSTORE" -n 1 -d "$WORK/disk" --init >/dev/null

# For a clean one-member DBC image the D6FS physical base is sector 1.
# mkdsk places the one-block badmap immediately after the LOGSTORE region,
# followed by super A and super B.
payload_words=$(wc -l < "$KERNEL_BUILD/kinit.d6lz.words" | tr -d ' ')
boot_blocks=$(( (payload_words + 127) / 128 ))
super_a=$(( boot_blocks + 0400 + 1 ))
phys_a=$((super_a + 1))
# Corrupt only the first word/magic of super A.  Super B must remain enough to
# mount and the first writable transition should reconstruct the alternate.
printf '\0\0\0\0\0\0\0\0' | dd of="$WORK/disk/dsk0.dsk" bs=8 \
    seek=$((phys_a * 128)) conv=notrunc 2>/dev/null
dd if="$WORK/disk/dsk0.dsk" of="$WORK/boot-before.bin" bs=1024 \
    count=$((boot_blocks + 1)) status=none

sed -e "s|set -q -n log .*|set -q -n log $WORK/simh.log|" \
    -e "s|attach -q dsk0 .*|attach -q dsk0 $WORK/disk/dsk0.dsk|" \
    -e "s|attach -q dcs0 .*|attach -q dcs0 $dcs_port|" \
    -e '/^attach -q ge0 /d' \
    "$KERNEL_BUILD/boot.ini" > "$WORK/kinit.ini"

TMPDIR="$TMPDIR" PDP10_PREFIX="$PDP10_PREFIX" \
    "$HARNESS" --daimos-repo "$DAIMOS_REPO" --dofile "$WORK/kinit.ini" \
    --pty-run "$PTY_RUN" --tcp-run "$TCP_RUN" --dcs-port "$dcs_port" \
    --boot-timeout 180 --login ROOT --probes "$PROBES" --work-dir "$WORK/run" \
    --markdown-report "$REPORT"

dd if="$WORK/disk/dsk0.dsk" of="$WORK/boot-after.bin" bs=1024 \
    count=$((boot_blocks + 1)) status=none
if ! cmp -s "$WORK/boot-before.bin" "$WORK/boot-after.bin"; then
        echo 'd6fs-recovery-v1: bootstream changed during writable mount' >&2
        cmp -l "$WORK/boot-before.bin" "$WORK/boot-after.bin" | head -20 >&2 || true
        exit 1
fi

"$LOGSTORE" -n 1 -d "$WORK/disk" --dump > "$WORK/d6log.out"
if grep -q 'valid=1' "$WORK/d6log.out"; then
        cat "$WORK/d6log.out" >&2
        echo 'd6fs-hdd-v2: clean boot created a LOGSTORE record' >&2
        exit 1
fi

# The harness terminates SIMH without a clean filesystem unmount.  The mounted
# filesystem must therefore now have a newer DIRTY superblock and reject a
# second writable boot rather than silently recovering it.  Current KINIT
# reports root mount/validation failure as ?RT.
STDBUF=${STDBUF:-stdbuf} "$WATCH_OUTPUT" -f 6 -t 3 \
    "$SIMH_PDP6" "$WORK/kinit.ini" "$WORK/dirty-reboot.simh.log" \
    "$WORK/dirty-reboot.log" '?RT' >/dev/null
if grep 'DSH V1' "$WORK/dirty-reboot.log" >/dev/null 2>&1; then
        echo 'd6fs-recovery-v1: DIRTY filesystem reached DSH' >&2
        exit 1
fi

echo 'D6FS dual-superblock recovery test PASS'
