#!/bin/sh
# Native PDP6 source-extracted ORIGINAL MM free+pin and idle PREVM retry.
set -eu
: "${DAIMOS_REPO:?source-matched DAIMOS kernel checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=${V1900_FINALIZER_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-terminal-finalizer-v1900.XXXXXX")}
mkdir -p "$work"
python3 "$kit/tests/validation/pure-terminal-finalizer-v1681/build-native-v1681.py" \
    "$DAIMOS_REPO" "$kit" "$work"
python3 "$kit/tests/validation/pure-parent-helper-v1807/extract-v1807.py" \
    "$DAIMOS_REPO" "$work/production-parent-v1807.s"
python3 "$kit/tests/validation/pure-pi-leaves-v1807/extract-v1807.py" \
    "$DAIMOS_REPO" "$work/production-pi-v1807.s"
python3 "$here/prepare-finalizer-v1900.py" "$work"
inc="-I$src/proc -I$src/core -I$src/mm -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$src/proc/vm_pdp6_swap.c" -o "$work/actual-detach.s" \
    >"$work/compile.log" 2>&1 || {
        tail -55 "$work/compile.log" >&2
        exit 1
    }
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 350000 --timeout 45 \
    --workdir "$work/guest" --name daimos-k05-terminal-finalizer-v1900 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/original-finalizer.s" "$work/original-vm-destroy.s" \
    "$work/production-parent-v1807.s" "$work/production-pi-v1807.s" \
    "$work/original-mm.s" "$work/original-pure-term.s" \
    "$work/actual-detach.s" "$src/proc/proc_storage_runtime_v30.s" \
    "$work/term-entry.s" "$work/test-fixture.s" \
    >"$work/native.log" 2>&1 || {
        tail -70 "$work/native.log" >&2
        echo "FAIL v1900 actual original-MM dual-owner finalizer: $work" >&2
        exit 1
    }
echo "PASS v1900: original native MM pin/unpin/free BOTH owners, FINALIZE+PREVM backoff, VM_NONE, zombie: $work"
