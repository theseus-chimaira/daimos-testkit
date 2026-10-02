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
WORK=$TMPDIR/daimos-d6fs-hdd-multi-v1-$$
REPORT_DIR=${D6FS_HDD_MULTI_REPORT_DIR:-$TESTKIT_ROOT/reports/d6fs-hdd-multi-v1}
INITTAB=$WORK/inittab-dcs0
INITTAB_S6REC=$WORK/inittab-dcs0.s6rec
PASSWD_S6REC=$WORK/passwd.s6rec

cleanup()
{
        rm -rf "$WORK"
}
trap cleanup 0 1 2 3 15
mkdir -p "$WORK" "$REPORT_DIR" "$BUILD_ROOT/tools"
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

# Build the common kernel/userland payload once.  Each case below gets fresh
# media because a writable D6FS mount deliberately leaves it DIRTY if SIMH is
# terminated rather than cleanly unmounted.
make -C "$TESTKIT_ROOT/tests/system/kernel" image \
    DAIMOS_REPO="$DAIMOS_REPO" BUILD="$KERNEL_BUILD" \
    PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR"

make_ini()
{
        n=$1
        diskdir=$2
        ini=$3
        simhlog=$4
        dcs_port=$5
        awk -v n="$n" -v diskdir="$diskdir" -v simhlog="$simhlog" \
            -v dcs_port="$dcs_port" '
            /^set -q -n log / { print "set -q -n log " simhlog; next }
            /^attach -q dcs0 / { print "attach -q dcs0 " dcs_port; next }
            /^attach -q ge0 / { next }
            /^attach -q dsk0 / {
                    for (i = 0; i < n; ++i)
                            printf "attach -q dsk%d %s/dsk%d.dsk\n", i, diskdir, i
                    next
            }
            { print }
        ' "$KERNEL_BUILD/boot.ini" > "$ini"
}

run_case()
{
        name=$1
        n=$2
        sectors=$3
        diskdir=$WORK/$name-disk
        ini=$WORK/$name.ini
        simhlog=$WORK/$name.simh.log
        rundir=$WORK/$name-run
        report=$REPORT_DIR/$name.md
        dcs_port=$((20000 + ($$ % 7000) + n * 10))

        mkdir -p "$diskdir"
        if [ -n "$sectors" ]; then
                "$MKDSK" -n "$n" -m clean -p "$KERNEL_BUILD/kinit.d6lz.words" \
                    -o "$diskdir" --d6fs-layout --logstore-blocks 0400 \
                    --swap-tail-blocks 0200 --member-sectors "$sectors"
        else
                "$MKDSK" -n "$n" -m clean -p "$KERNEL_BUILD/kinit.d6lz.words" \
                    -o "$diskdir" --d6fs-layout --logstore-blocks 0400 \
                    --swap-tail-blocks 0200
        fi
        "$MKD6FS" -n "$n" -d "$diskdir" \
            -D /TEMP:0777 \
            -D /SYSTEM:0555 -D /SYSTEM/EXEC:0555 -D /CONFIG:0755 \
            -f "/SYSTEM/INIT:$KERNEL_BUILD/userland-build/userland/init.dxr:555:dxr" \
            -f "/SYSTEM/EXEC/LOGIN:$KERNEL_BUILD/userland-build/userland/login.d6lz.dxr:555:dxr" \
            -f "/SYSTEM/EXEC/DSH:$KERNEL_BUILD/userland-build/userland/dsh.d6lz.dxr:555:dxr" \
            -f "/CONFIG/INITTAB:$INITTAB_S6REC:644:binwords" \
            -f "/CONFIG/PASSWD:$PASSWD_S6REC:600:binwords"
        "$LOGSTORE" -n "$n" -d "$diskdir" --init >/dev/null
        make_ini "$n" "$diskdir" "$ini" "$simhlog" "$dcs_port"
        TMPDIR="$TMPDIR" PDP10_PREFIX="$PDP10_PREFIX" \
            "$HARNESS" --daimos-repo "$DAIMOS_REPO" --dofile "$ini" \
            --pty-run "$PTY_RUN" --tcp-run "$TCP_RUN" --dcs-port "$dcs_port" \
            --boot-timeout 180 --login ROOT --probes "$PROBES" --work-dir "$rundir" \
            --markdown-report "$report"
        "$LOGSTORE" -n "$n" -d "$diskdir" --dump > "$WORK/$name.d6log.out"
        if grep -q 'valid=1' "$WORK/$name.d6log.out"; then
                cat "$WORK/$name.d6log.out" >&2
                echo "d6fs-hdd-multi-v1: $name clean boot created a LOGSTORE record" >&2
                exit 1
        fi
}

run_case dsk2-equal 2 ""
run_case dsk4-equal 4 ""

# V0.9 D6FS roots deliberately support homogeneous equal-size INTERLEAVE
# only.  Unequal member windows belong to the generic CONCAT mapper and are
# not a supported root layout, so KINIT must reject this set rather than
# silently truncating or inventing an unequal-zone striping policy.
diskdir=$WORK/dsk3-unequal-disk
mkdir -p "$diskdir"
"$MKDSK" -n 3 -m clean -p "$KERNEL_BUILD/kinit.d6lz.words" \
    -o "$diskdir" --d6fs-layout --logstore-blocks 0400 \
    --swap-tail-blocks 0200 --member-sectors "02000,01400,01000"
"$MKD6FS" -n 3 -d "$diskdir" \
    -D /TEMP:0777 \
    -D /SYSTEM:0555 -D /SYSTEM/EXEC:0555 -D /CONFIG:0755 \
    -f "/SYSTEM/INIT:$KERNEL_BUILD/userland-build/userland/init.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/LOGIN:$KERNEL_BUILD/userland-build/userland/login.d6lz.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/DSH:$KERNEL_BUILD/userland-build/userland/dsh.d6lz.dxr:555:dxr" \
    -f "/CONFIG/INITTAB:$INITTAB_S6REC:644:binwords" \
    -f "/CONFIG/PASSWD:$PASSWD_S6REC:600:binwords"
"$LOGSTORE" -n 3 -d "$diskdir" --init >/dev/null
dcs_port=$((27000 + ($$ % 1000)))
make_ini 3 "$diskdir" "$WORK/dsk3-unequal.ini" "$WORK/dsk3-unequal.simh.log" "$dcs_port"
STDBUF=${STDBUF:-stdbuf} "$WATCH_OUTPUT" -f 6 -t 10 \
    "$SIMH_PDP6" "$WORK/dsk3-unequal.ini" "$WORK/dsk3-unequal.simh.log" \
    "$WORK/dsk3-unequal.log" '?RT' >/dev/null

# A required member missing from the Stage1 set must fail before KINIT.  This
# verifies the diskset is never silently mounted degraded.
diskdir=$WORK/dsk2-missing-disk
mkdir -p "$diskdir"
"$MKDSK" -n 2 -m clean -p "$KERNEL_BUILD/kinit.d6lz.words" \
    -o "$diskdir" --d6fs-layout --logstore-blocks 0400 \
    --swap-tail-blocks 0200
"$MKD6FS" -n 2 -d "$diskdir" \
    -D /TEMP:0777 \
    -D /SYSTEM:0555 -D /SYSTEM/EXEC:0555 -D /CONFIG:0755 \
    -f "/SYSTEM/INIT:$KERNEL_BUILD/userland-build/userland/init.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/LOGIN:$KERNEL_BUILD/userland-build/userland/login.d6lz.dxr:555:dxr" \
    -f "/SYSTEM/EXEC/DSH:$KERNEL_BUILD/userland-build/userland/dsh.d6lz.dxr:555:dxr" \
    -f "/CONFIG/INITTAB:$INITTAB_S6REC:644:binwords" \
    -f "/CONFIG/PASSWD:$PASSWD_S6REC:600:binwords"
"$LOGSTORE" -n 2 -d "$diskdir" --init >/dev/null
dcs_port=$((28000 + ($$ % 1000)))
awk -v disk="$diskdir/dsk0.dsk" -v simhlog="$WORK/dsk2-missing.simh.log" \
    -v dcs_port="$dcs_port" '
    /^set -q -n log / { print "set -q -n log " simhlog; next }
    /^attach -q dcs0 / { print "attach -q dcs0 " dcs_port; next }
    /^attach -q ge0 / { next }
    /^attach -q dsk0 / { print "attach -q dsk0 " disk; next }
    { print }
' "$KERNEL_BUILD/boot.ini" > "$WORK/dsk2-missing.ini"
STDBUF=${STDBUF:-stdbuf} "$WATCH_OUTPUT" -f 6 -t 3 \
    "$SIMH_PDP6" "$WORK/dsk2-missing.ini" "$WORK/dsk2-missing.simh.log" \
    "$WORK/dsk2-missing.log" '?B' >/dev/null

echo 'D6FS HDD multi-member runtime test PASS'
