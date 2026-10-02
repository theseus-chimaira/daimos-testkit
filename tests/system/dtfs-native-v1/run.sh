#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${PTY_RUN:?PTY_RUN must be set}"
: "${HOST_CHECK:?HOST_CHECK must be set}"

TESTKIT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
HARNESS="$TESTKIT_ROOT/tools/daimos-simh-harness-v4.sh"
SIMH=${SIMH_PDP6:-$PDP10_PREFIX/bin/pdp6}
BUILD_ROOT=${BUILD_ROOT:-$TESTKIT_ROOT/build}
WORK="$BUILD_ROOT/tests/system/dtfs-native-v1"
TAPE="$WORK/dtfs-native-v1.dt"
INI_NEW="$WORK/kinit-dtfs-native-new-v1.ini"
INI_EXIST="$WORK/kinit-dtfs-native-existing-v1.ini"
MEDIA_FILL="$WORK/media-fill-v1"
ROOT_TEMPLATE="$WORK/root-template.dsk"
PRISTINE_BUILD="$WORK/pristine-root"
PRISTINE_INI="$PRISTINE_BUILD/boot.ini"

rm -rf "$WORK"
mkdir -p "$WORK" "$TESTKIT_ROOT/reports"
rm -f "$TAPE"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$MEDIA_FILL" \
    "$TESTKIT_ROOT/tests/system/dtfs-native-v1/media-fill-v1.c"

# Build a private pristine root image.  The generic runtime probes mutate their
# root D6FS and halt without a clean unmount, so cloning the caller's boot image
# would make this persistence test depend on Makefile target order.
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$PRISTINE_BUILD" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null
ROOT_SOURCE=$(awk '$1 == "attach" && $2 == "-q" && $3 == "dsk0" { print $4; exit }' "$PRISTINE_INI")
test -n "$ROOT_SOURCE"
cp "$ROOT_SOURCE" "$ROOT_TEMPLATE"

sed -e 's/set dtc disabled/set dtc enabled/' \
    -e "/^go 020/i\\
set dtc dct=04\\
attach -n -q dtc0 $TAPE" "$PRISTINE_INI" > "$INI_NEW"
sed -e 's/set dtc disabled/set dtc enabled/' \
    -e "/^go 020/i\\
set dtc dct=04\\
attach -q dtc0 $TAPE" "$PRISTINE_INI" > "$INI_EXIST"

run_phase()
{
    phase=$1
    probes="$TESTKIT_ROOT/probes/daimos-dtfs-native-$phase-v1.txt"
    report="$TESTKIT_ROOT/reports/daimos-dtfs-native-$phase-v1.md"
    base_ini=$INI_EXIST
    if [ "$phase" = a ]; then
        base_ini=$INI_NEW
    fi
    root_disk="$WORK/root-$phase.dsk"
    ini="$WORK/kinit-dtfs-native-$phase-v1.ini"
    cp "$ROOT_TEMPLATE" "$root_disk"
    sed "s|^attach -q dsk0 .*|attach -q dsk0 $root_disk|" "$base_ini" > "$ini"
    "$HARNESS" --daimos-repo "$DAIMOS_REPO" --dofile "$ini" \
        --simh "$SIMH" --pty-run "$PTY_RUN" --login ROOT --probes "$probes" \
        --work-dir "$WORK/run-$phase" --boot-timeout 60 --timeout 30 \
        --markdown-report "$report"
}

run_phase a
run_phase b
run_phase c
run_phase d
"$HOST_CHECK" dtfs "$TAPE"
run_phase e
"$HOST_CHECK" dtfs "$TAPE"
"$MEDIA_FILL" "$TAPE"
"$HOST_CHECK" dtfs "$TAPE"
run_phase f
"$HOST_CHECK" dtfs "$TAPE"
echo 'DTFS native runtime/persistence test PASS'
