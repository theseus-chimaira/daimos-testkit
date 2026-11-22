#!/bin/sh
# Actual PDP-6 simulator GO success and forced one-step expiry.
set -eu
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
: "${TOOL_SRC_DIR:?set TOOL_SRC_DIR to current DAIMOS or pdp10-tools source}"
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/toolchain-extern-expiry-simh-v1812.XXXXXX")
trap 'status=$?; if test "$status" -eq 0; then rm -rf "$work"; else echo "v1812: retained failure evidence at $work" >&2; fi' EXIT
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd -P)
sources="$testkit/tests/validation"
cc=${HOST_CC:-cc}

"$cc" -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$work/dlink-v1812" "$TOOL_SRC_DIR/dlink.c" "$TOOL_SRC_DIR/dobj.c"
"$cc" -std=c89 -O2 -Wall -Wextra -Werror \
    -o "$work/p10run-v1812" "$TOOL_SRC_DIR/p10run.c"
PDP10_DLINK="$work/dlink-v1812"
export PDP10_DLINK
mkdir -p "$work/go" "$work/step"

set -- "$sources/daimos-test-crt0-v1.s" \
       "$sources/d6codec-native-v014/test_v014.s" \
       "$sources/d6codec-native-v014/encoder_v014.s" \
       "$sources/d6codec-native-v014/decode_v014.s"

"$work/p10run-v1812" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 20 --workdir "$work/go" \
    --name go-v1812 --expect __test_exit=0 "$@" >"$work/go.log" 2>&1
grep -q 'PASS go-v1812 on pdp6' "$work/go.log"
grep -q '^result=PASS$' "$work/go/go-v1812.report.txt"
echo 'PASS v1812: actual PDP-6 GO completes expected exit'

if "$work/p10run-v1812" --machine pdp6 --mode deposit \
    --exec-mode step --step-limit 1 --start 1000 --timeout 20 \
    --workdir "$work/step" --name step-v1812 \
    --expect __test_exit=0 "$@" >"$work/step.log" 2>&1; then
    echo 'FAIL v1812: one-step guest was accepted as complete' >&2
    exit 1
fi
grep -q 'SIMH output contains: Step expired' "$work/step.log"
grep -q '^result=FAIL$' "$work/step/step-v1812.report.txt"
echo 'PASS v1812: actual PDP-6 one-step expiry rejected'
