#!/bin/sh
# Native MAKE recursion scratch, 256K only.  Requires a freshly built
# full-profile image from the source tree named by DAIMOS_REPO.
set -eu

: "${DAIMOS_REPO:?Set DAIMOS_REPO to the source used for the image}"
: "${DAIMOS_MAKE_BOOT_INI:?Set DAIMOS_MAKE_BOOT_INI to the 256K boot ini}"
: "${PDP10_PREFIX:?Set PDP10_PREFIX}"
: "${TMPDIR:=$HOME/tmp}"

here=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
source_file="$DAIMOS_REPO/userland/exec/make.c"
probe="$here/probes/daimos-native-make-lazy-depth-v1054.txt"

# A guest run alone would also pass with the old bulk allocation.
# Require the intended code path in the exact source under test.
grep -Fq 'make_implicit_frames[MAKE_MAX_DEPTH + 1U]' "$source_file"
grep -Fq 'imp = make_implicit_frames[depth];' "$source_file"
grep -Fq 'imp = realloc(0, sizeof(*imp));' "$source_file"
if grep -Fq 'make_implicit_stack' "$source_file"; then
        echo 'FAIL: MAKE still reserves the full implicit scratch stack' >&2
        exit 1
fi

grep -qx 'set cpu 256k' "$DAIMOS_MAKE_BOOT_INI"
grep -qx 'deposit SW 1' "$DAIMOS_MAKE_BOOT_INI"
sh "$here/tests/validation/check-probe-format-v1.sh" "$probe"

work="$TMPDIR/daimos-make-lazy-depth-v1054-$$"
mkdir -p "$work"
cleanup()
{
        if [ "${DAIMOS_MAKE_KEEP_WORK:-0}" != 1 ]; then
                rm -rf "$work"
        else
                echo "MAKE v1054 guest diagnostics retained at $work"
        fi
}
trap cleanup EXIT HUP INT TERM

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror \
    -o "$work/pty-run" "$here/tools/pty-run-v1.c"
PATH="$PDP10_PREFIX/bin:$PATH" \
    "$here/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$DAIMOS_MAKE_BOOT_INI" \
    --pty-run "$work/pty-run" --login ROOT --isolate-media \
    --boot-timeout 90 --timeout 40 --probes "$probe" \
    --work-dir "$work/run" --markdown-report "$work/report.md"
echo 'PASS: MAKE lazy depth and cycle regression in 256K PDP-6 guest'
