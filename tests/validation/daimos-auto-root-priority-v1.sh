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
        # Preserve all three boot transcripts when investigating a fallback
        # failure; the ordinary regression still removes transient media.
        if [ "${DAIMOS_AUTO_ROOT_KEEP_WORK:-0}" != 1 ]; then
                rm -rf "$WORK"
        fi
}
trap cleanup 0 1 2 3 15
mkdir -p "$WORK"

# Exercise root selection through a real login session, as the root-class
# matrix does.  The harness and INITTAB must agree about that contract:
# launch LOGIN and supply --login ROOT below.  Running DSH directly would
# bypass authentication, while LOGIN without --login leaves DSH unreachable.
printf '%s\n' '1:RESPAWN:/SYSTEM/EXEC/LOGIN' > "$INITTAB"
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
# Drum D6FS roots are a *four-member set*.  Copying only member zero leaves
# the other three slots holding unrelated blank media from the AUTO build;
# boot discovery then correctly rejects the incomplete membership mask.
# Preserve the entire set from the independently formatted drum root.
for unit in 0 1 2 3; do
        cp "$BUILD_DRUM/drum/dsk$unit.dsk" "$BUILD/drum/dsk$unit.dsk"
done

run_case()
{
        name=$1
        expected=$2
        ini=$3
        probes=$WORK/probes-$name
        boot_timeout=300
        command_timeout=15
        # A fallback TSFS root performs long physical tape seeks for LOGIN,
        # DSH and CAT.  The 120-second CAT allowance timed out after DSH
        # was already running; repeating the exact probe against the same
        # image with a 360-second allowance passed and printed ROOTCLASS TAPE.
        # Limit this adjustment to the actual tape-root transport.
        if [ "$expected" = TAPE ]; then
                boot_timeout=600
                command_timeout=360
        fi

        cat > "$probes" <<EOT
probe auto-root-$name
command CAT /CONFIG/SYSTEM
contains ROOTCLASS $expected
end
EOT
        if PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR" \
            "$HARNESS" --daimos-repo "$DAIMOS_REPO" --dofile "$ini" \
            --pty-run "$PTY_RUN" --tcp-run "$TCP_RUN" --dcs-port "$dcs_port" \
            --boot-timeout "$boot_timeout" --timeout "$command_timeout" \
            --login ROOT --probes "$probes" \
            --work-dir "$WORK/run-$name" --markdown-report "$WORK/$name.md" >/dev/null
        then
                :
        else
                rc=$?
                printf '%s\n' "auto-root-$name: FAIL (rc=$rc)" >&2
                if [ -f "$WORK/run-$name/dcs0.log" ]; then
                        tail -60 "$WORK/run-$name/dcs0.log" >&2
                fi
                if [ -f "$WORK/run-$name/simh.log" ]; then
                        printf '%s\n' "--- SIMH $name ---" >&2
                        tail -100 "$WORK/run-$name/simh.log" >&2
                fi
                if [ -f "$WORK/$name.md" ]; then
                        cat "$WORK/$name.md" >&2
                fi
                exit "$rc"
        fi
        printf '%s\n' "auto-root-$name: PASS (selected $expected)"
}

# AUTO must prefer DSK while all three root classes are available.
run_case all DISK "$BUILD/boot.ini"

# Make the entire DSK root class unavailable: the other three units may have
# readable D6FS media, and AUTO is entitled to select any valid unit.
sed '/^attach -q dsk[0-3] /d' "$BUILD/boot.ini" > "$WORK/no-dsk.ini"
run_case no-dsk TAPE "$WORK/no-dsk.ini"

# Remove all DTC units as well.  An alternate TSFS volume on DTC1..3 can
# legitimately win AUTO over DRM, even if it lacks a complete boot tree.
# Only an absent DTC class makes this an unambiguous drum fallback test.
sed -e '/^attach -q dsk[0-3] /d' -e '/^attach -q dtc[0-3] /d' \
    "$BUILD/boot.ini" > "$WORK/drm-only.ini"
run_case drm-only DRUM "$WORK/drm-only.ini"

printf '%s\n' 'auto-root-priority: PASS (DSK -> DTC -> DRM)'
