#!/bin/sh
# Regression for Type-551 multi-transport selection sharing Type-136 channel.
# A nonselected DECtape drive reaching an end zone must not stop another
# selected drive's read in progress. Require a working external-command shell,
# not just the initial DTC/INIT banners.
set -eu

: "${DAIMOS_REPO:?set DAIMOS_REPO to the DAIMOS checkout}"
: "${PDP10_PREFIX:?set PDP10_PREFIX to the cross-toolchain prefix}"
: "${TMPDIR:=$HOME/tmp}"
export TMPDIR

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
testkit=$(CDPATH= cd -- "$self/../.." && pwd -P)
work=${DAIMOS_SIMH_DTC_WORK_V34:-"$TMPDIR/daimos-simh-dtc-selected-v34-$$"}
simh=${SIMH_PDP6:-"$PDP10_PREFIX/bin/pdp6"}
build="$work/build/system/boot/pdp6"

mkdir -p "$work"
if [ -n "${DAIMOS_SIMH_DTC_BOOT_INI_V34:-}" ]; then
    boot_ini=$DAIMOS_SIMH_DTC_BOOT_INI_V34
else
    PATH="$PDP10_PREFIX/bin:$PATH" \
        make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD_ROOT="$work/build" PDP10_PREFIX="$PDP10_PREFIX" \
        BOOT=dtc ROOT=tape DSH_IMAGE_LIMIT=037000 \
        > "$work/build-v34.log" 2>&1 || {
            tail -25 "$work/build-v34.log" >&2
            exit 1
        }
    boot_ini=$build/boot.ini
fi

python3 "$self/daimos-simh-aap-hardware-v24.py" \
    "$boot_ini" "$work/aap-like-v34.ini"

cc -std=c99 -O2 -Wall -Wextra -Werror -o "$work/pty-run-v34" \
    "$testkit/tools/pty-run-v1.c"

"$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$work/aap-like-v34.ini" \
    --simh "$simh" --pty-run "$work/pty-run-v34" \
    --login ROOT --boot-timeout 360 --timeout 240 \
    --probes "$testkit/probes/daimos-three-emulator-boot-v24.txt" \
    --work-dir "$work/runtime-v34" \
    --markdown-report "$work/report-v34.md"

printf 'daimos-simh-dtc-selected-v34: PASS; report %s\n' \
    "$work/report-v34.md"
