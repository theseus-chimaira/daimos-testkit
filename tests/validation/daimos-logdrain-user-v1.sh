#!/bin/sh
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
work="$TMPDIR/daimos-logdrain-user-v1-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"
inc="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/userland/libc -I$DAIMOS_REPO/userland/exec"
# Compile the production LOGDRAIN source with only its entry point renamed.
# The test supplies target-side syscall stubs and invokes that real entry point.
# shellcheck disable=SC2086
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
        -Dmain=logdrain_program_main -S \
        "$DAIMOS_REPO/userland/logstore/logdrain.c" -o "$work/logdrain.s"
# shellcheck disable=SC2086
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S \
        "$DAIMOS_REPO/userland/libc/u.c" -o "$work/u.s"
# shellcheck disable=SC2086
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S \
        "$self/daimos-logdrain-user-v1.c" -o "$work/test.s"
PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$work" \
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 12000000 --timeout 30 \
        --workdir "$work/run" --name daimos-logdrain-user-v1 \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$work/u.s" \
        "$work/logdrain.s" "$work/test.s" >/dev/null
printf '%s\n' 'daimos-logdrain-user-v1: PASS (NULL/file/console/MTC/loss/resume/follow)'
