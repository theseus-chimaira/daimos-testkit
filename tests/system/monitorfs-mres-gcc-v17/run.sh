#!/bin/sh
# GCC PDP-6 lowmem MonitorFS MRES integration acceptance test.
set -eu
: "${TMPDIR:?Set TMPDIR to a private temporary directory}"
: "${DAIMOS_REPO:?Set DAIMOS_REPO}"
: "${PDP10_PREFIX:?Set PDP10_PREFIX}"
: "${PTY_RUN:?Set PTY_RUN}"
: "${TCP_RUN:?Set TCP_RUN for lowmem DCS0 login}"
root=$(cd "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/daimos-monitorfs-mres-gcc-v17-$$"
mkdir -p "$work"
echo "MonitorFS MRES v17 test build: $work"
if ! make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BOOT_PROFILE=lowmem COMPILER=gcc MONITORFS_MRES_ENABLED=1 \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD="$work/build" \
    > "$work/build.log" 2>&1; then
    tail -35 "$work/build.log" >&2
    exit 1
fi
if ! sh "$root/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/build/boot.ini" \
    --pty-run "$PTY_RUN" --tcp-run "$TCP_RUN" --dcs-port 1101 \
    --login ROOT \
    --probes "$root/probes/daimos-monitorfs-mres-v17.txt" \
    --work-dir "$work/harness" --markdown-report "$work/report.md" \
    > "$work/harness.log" 2>&1; then
    tail -35 "$work/harness.log" >&2
    echo "MonitorFS MRES test artifacts preserved in $work" >&2
    exit 1
fi
cat "$work/harness.log"
rm -rf "$work"
