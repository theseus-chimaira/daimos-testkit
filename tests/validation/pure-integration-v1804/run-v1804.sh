#!/bin/sh
# Source-level gates for the isolated DAIMOS RAW PURE consolidation v1804.
# This does not constitute physical acceptance of the integrated kernel.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the v1804 candidate checkout}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR DAIMOS_REPO
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)

test -f "$DAIMOS_REPO/system/kernel/proc/syscall_dispatch_pdp6.s"
test -f "$DAIMOS_REPO/system/kernel/proc/proc_pure_ram_restore_v1391.c"

echo "v1804: requester-only K03 OOM source contract"
python3 "$testkit/tests/validation/daimos-k03-policy-contract-v1802.py"

echo "v1804: read-only K04 historical physical witness verifier"
sh "$testkit/tests/validation/daimos-k04-closure-regression-v1801.sh"

echo "v1804: source-linked original RAW/FULL two-owner native test"
sh "$testkit/tests/validation/pure-multiowner-source-v1684/run-v1684.sh"

echo "v1804: source gates PASS (physical integrated guest NOT tested)"
