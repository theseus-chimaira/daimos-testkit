#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
storage="$DAIMOS_REPO/system/kernel/drivers/dsk_io.s"
work="$TMPDIR/daimos-dsk270-elevator-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

# ADJSP is not a PDP-6 instruction.  DAS accepts the generic PDP-10 opcode,
# where the PDP-6 executes it as MUUO 104, so reject it in this PDP-6 driver.
if grep -Eiq '(^|[[:space:]])adjsp([[:space:]]|$)' "$storage"; then
        echo 'dsk270-elevator: PDP-10-only ADJSP in PDP-6 storage path' >&2
        exit 1
fi

PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 1000000 --timeout 10 \
        --workdir "$work/run" --name daimos-dsk270-elevator \
        --expect __test_exit=0 --expect fail_id=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dsk270-elevator-v1.s" \
        "$storage" \
        "$DAIMOS_REPO/system/kernel/storage/storage_router.s" \
        "$DAIMOS_REPO/system/kernel/drivers/device_state.s" \
        "$DAIMOS_REPO/system/kernel/core/ret.s" \
        "$self/daimos-dsk270-elevator-stubs-v1.s" >/dev/null

printf '%s\n' 'dsk270-elevator: PASS (production one-way selector on PDP-6)'
