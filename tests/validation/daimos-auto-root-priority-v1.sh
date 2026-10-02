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
WORK=$TMPDIR/daimos-auto-root-priority-v1-$$
BUILD=$WORK/build
BUILD_TAPE=$WORK/build-tape
BUILD_DRUM=$WORK/build-drum
INITTAB=$WORK/inittab-dcs0
SYSTEM_DISK=$WORK/system-disk
SYSTEM_TAPE=$WORK/system-tape
SYSTEM_DRUM=$WORK/system-drum

cleanup()
{
        rm -rf "$WORK"
}
trap cleanup 0 1 2 3 15
mkdir -p "$WORK"

printf '%s\n' '1:RESPAWN:/SYSTEM/EXEC/DSH' > "$INITTAB"
cat > "$SYSTEM_DISK" <<'EOT'
# DAIMOS SYSTEM POLICY V1
# ROOTCLASS DISK
SWAP = AUTO
LOGSTORE = AUTO
EOT
cat > "$SYSTEM_TAPE" <<'EOT'
# DAIMOS SYSTEM POLICY V1
# ROOTCLASS TAPE
SWAP = AUTO
LOGSTORE = AUTO
EOT
cat > "$SYSTEM_DRUM" <<'EOT'
# DAIMOS SYSTEM POLICY V1
# ROOTCLASS DRUM
SWAP = AUTO
LOGSTORE = AUTO
EOT

dcs_port=$((23000 + ($$ % 1000)))
ge_port=$((dcs_port + 4000))

# Build three complete production roots.  Only /CONFIG/SYSTEM differs, carrying
# a comment marker used by the probe below.  This deliberately avoids a second,
# hand-maintained list of files required for a bootable root filesystem.
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$BOOT_DIR" image \
    BUILD="$BUILD" PDP10_PREFIX="$PDP10_PREFIX" BOOT=ptr ROOT=auto \
    SYSTEM_INITTAB_TEXT="$INITTAB" SYSTEM_SYSTEM_TEXT="$SYSTEM_DISK" \
    SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$BOOT_DIR" image \
    BUILD="$BUILD_TAPE" PDP10_PREFIX="$PDP10_PREFIX" BOOT=ptr ROOT=tape \
    SYSTEM_INITTAB_TEXT="$INITTAB" SYSTEM_SYSTEM_TEXT="$SYSTEM_TAPE" \
    SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$BOOT_DIR" image \
    BUILD="$BUILD_DRUM" PDP10_PREFIX="$PDP10_PREFIX" BOOT=ptr ROOT=drum \
    SYSTEM_INITTAB_TEXT="$INITTAB" SYSTEM_SYSTEM_TEXT="$SYSTEM_DRUM" \
    SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

# The AUTO build supplies the DSK root and simulator configuration.  Replace its
# empty alternate-root media with complete roots produced by the normal builder.
cp "$BUILD_TAPE/media/dtc0.tap" "$BUILD/media/dtc0.tap"
cp "$BUILD_DRUM/media/dr0.drm" "$BUILD/media/dr0.drm"

run_case()
{
        name=$1
        expected=$2
        ini=$3
        probes=$WORK/probes-$name

        cat > "$probes" <<EOT
probe auto-root-$name
command CAT /CONFIG/SYSTEM
contains ROOTCLASS $expected
end
EOT
        PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR" \
            "$HARNESS" --daimos-repo "$DAIMOS_REPO" --dofile "$ini" \
            --pty-run "$PTY_RUN" --tcp-run "$TCP_RUN" --dcs-port "$dcs_port" \
            --boot-timeout 300 --probes "$probes" \
            --work-dir "$WORK/run-$name" --markdown-report "$WORK/$name.md" >/dev/null
        printf '%s\n' "auto-root-$name: PASS (selected $expected)"
}

# AUTO must prefer DSK while all three root classes are available.
run_case all DISK "$BUILD/boot.ini"

# Remove DSK; AUTO must fall back to the TSFS root on DTC.
sed '/^attach -q dsk0 /d' "$BUILD/boot.ini" > "$WORK/no-dsk.ini"
run_case no-dsk TAPE "$WORK/no-dsk.ini"

# Remove DTC as well; DRM is then the remaining supported root class.
sed -e '/^attach -q dsk0 /d' -e '/^attach -q dtc0 /d' \
    "$BUILD/boot.ini" > "$WORK/drm-only.ini"
run_case drm-only DRUM "$WORK/drm-only.ini"

printf '%s\n' 'auto-root-priority: PASS (DSK -> DTC -> DRM)'
