#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
: "${PTY_RUN:?PTY_RUN must be set}"
: "${TCP_RUN:?TCP_RUN must be set}"

TESTKIT_ROOT=${TESTKIT_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)}
HARNESS=$TESTKIT_ROOT/tools/daimos-simh-harness-v4.sh
BOOT_DIR=$DAIMOS_REPO/system/boot/pdp6
WORK=$TMPDIR/daimos-boot-source-matrix-v1-$$
BUILD=$WORK/build
PROBES=$WORK/probes

cleanup()
{
        rm -rf "$WORK"
}
trap cleanup 0 1 2 3 15
mkdir -p "$WORK"

cat > "$PROBES" <<'EOF'
probe boot-source-login
command ECHO BOOTOK
contains BOOTOK
end
EOF

case_no=0
for boot in dsk drm dtc mtc ptr; do
        case_no=$((case_no + 1))
        dcs_port=$((15000 + ($$ % 1000) * 8 + case_no))
        ge_port=$((dcs_port + 4000))

        # Each harness shutdown intentionally leaves a writable D6FS root
        # DIRTY.  Rebuild only mutable media/config between cases while
        # retaining KINIT, KCORE and userland objects in the shared build.
        rm -rf "$BUILD/disk" "$BUILD/media" "$BUILD/boot.ini" \
            "$BUILD"/.boot-media-* "$BUILD"/boot-commands-*.simh

        make -C "$BOOT_DIR" image \
            BUILD="$BUILD" PDP10_PREFIX="$PDP10_PREFIX" \
            BOOT="$boot" ROOT=auto \
            SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

        PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR" \
            "$HARNESS" --daimos-repo "$DAIMOS_REPO" \
            --dofile "$BUILD/boot.ini" --pty-run "$PTY_RUN" \
            --tcp-run "$TCP_RUN" --dcs-port "$dcs_port" \
            --boot-timeout 180 --login ROOT --probes "$PROBES" \
            --work-dir "$WORK/run-$boot" \
            --markdown-report "$WORK/$boot.md" >/dev/null
        printf '%s\n' "boot-source-$boot: PASS (compressed KINIT -> AUTO DSK/D6FS -> login)"
done

printf '%s\n' 'boot-source-matrix: PASS'
