#!/bin/sh
# GCC PDP-6 lowmem DECtape root boot smoke test (no interactive login).
# Requires installed mktsfs, mkdt, compiler and PDP-6 simulator utilities.
set -eu
: "${TMPDIR:?Set TMPDIR to a private temporary directory}"
: "${DAIMOS_REPO:?Set DAIMOS_REPO}"
: "${PTY_RUN:?Set PTY_RUN}"
: "${PDP10_PREFIX:?Set PDP10_PREFIX}"
simh=${SIMH_PDP6:-${PDP6_SIMH:-pdp6}}
members=${TSFS_ROOT_MEMBERS:-1}
case "$members" in 1|2|3) ;; *) echo "invalid TSFS_ROOT_MEMBERS=$members" >&2; exit 2 ;; esac
work="$TMPDIR/daimos-tsfs-gcc-lowmem-v20-$$"
mkdir -p "$work"

for monitorfs in 0 1; do
    build="$work/build-$monitorfs"
    log="$work/boot-$monitorfs.log"
    make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BOOT_PROFILE=lowmem ROOT=tape BOOT=dtc COMPILER=gcc \
        TSFS_ROOT_MEMBERS="$members" \
        MONITORFS_MRES_ENABLED="$monitorfs" \
        PDP10_PREFIX="$PDP10_PREFIX" BUILD="$build" \
        > "$work/build-$monitorfs.log" 2>&1 || {
            tail -30 "$work/build-$monitorfs.log" >&2
            exit 1
        }
    # INIT currently does not guarantee an interactive DCS LOGIN prompt.
    # A timeout is expected after verifying the INIT boot milestone.
    timeout 25 "$PTY_RUN" "$simh" "$build/boot.ini" > "$log" 2>&1 || :
    if ! grep -q 'DTFS *LOADED' "$log" ||
        ! grep -q 'INIT V1' "$log" ||
        grep -q 'HALT instruction' "$log" ||
        grep -q '?RT' "$log"; then
        echo "TSFS lowmem smoke failed (MonitorFS MRES=$monitorfs): $log" >&2
        tail -35 "$log" >&2
        exit 1
    fi
    echo "TSFS lowmem INIT smoke passed ($members members, MonitorFS MRES=$monitorfs)"
done

echo "Boot transcripts preserved at $work"
