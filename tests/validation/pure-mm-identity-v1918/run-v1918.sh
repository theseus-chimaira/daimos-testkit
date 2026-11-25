#!/bin/sh
# Source-linked native fault tests for exact DROP/PREFIX identity.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-mm-identity-v1918.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" = 1 ]; then echo "v1918 work: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$testkit/tests/validation/pure-ram-lifecycle-v1377 -I$testkit/tests/validation/pure-ram-registryfree-v1379 -I$testkit/tests/validation/pure-ram-inplace-v1381"
compile() {
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@"
}
compile -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 \
    -Dmm_pure_rebase_pinned_v1381=rebase_reply_v1918 \
    -Dmm_unpin=unpin_reply_v1918 \
    "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile -DDAIMOS_SWAPLESS_PREFIX_V1384=1 \
    -Dmm_pure_claim_prefix_v1384=claim_reply_v1918 \
    -Dmm_pure_commit_prefix_v1384=commit_reply_v1918 \
    -Dmm_pure_release_prefix_v1384=release_reply_v1918 \
    -Dmm_unpin=unpin_reply_v1918 \
    "$src/proc/proc_pure_restore_v1384.c" -o "$work/prefix.s"
{
    printf '#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n'
    cat "$here/../pure-ram-prefix-v1384/test-native-v1384.c"
    cat "$here/test-native-v1918.c"
} > "$work/test.c"
compile "$work/test.c" -o "$work/test.s"
run_guest() {
    name=$1
    drop=$2
    prefix=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" \
        --expect __test_exit=0 \
        "$testkit/tests/validation/daimos-test-crt0-v1.s" \
        "$drop" "$prefix" \
        "$src/mm/mm_pure_rebase_v1381.s" \
        "$src/mm/mm_pure_expand_v1384.s" \
        "$src/proc/proc_storage_runtime_v30.s" \
        "$src/drivers/device_state.s" "$work/test.s"
}
run_guest pure-mm-identity-v1918 "$work/drop.s" "$work/prefix.s"

# Reintroduce each unsafe decision in private production-source copies.
# A compile/link/timeout failure is NOT a successful mutation test.
python3 - "$src/proc" "$work" <<'PYMUT'
from pathlib import Path
import sys
src, work = map(Path, sys.argv[1:])
s = (src / 'proc_pure_ram_v1381.c').read_text()
old = 'if (proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS, suffix,'
assert s.count(old) == 1
(work / 'unsafe-drop.c').write_text(s.replace(old, 'if (rc == MM_OK && proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS, suffix,', 1))
s = (src / 'proc_pure_restore_v1384.c').read_text()
old = ('        if (!proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS,\n'
       '            suffix, raw, 1U))\n'
       '                goto uncertain;\n'
       'raw_unpin:')
assert s.count(old) == 1
(work / 'unsafe-release.c').write_text(s.replace(old, 'raw_unpin:', 1))
PYMUT
compile -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 \
    -Dmm_pure_rebase_pinned_v1381=rebase_reply_v1918 \
    -Dmm_unpin=unpin_reply_v1918 \
    "$work/unsafe-drop.c" -o "$work/unsafe-drop.s"
compile -DDAIMOS_SWAPLESS_PREFIX_V1384=1 \
    -Dmm_pure_claim_prefix_v1384=claim_reply_v1918 \
    -Dmm_pure_commit_prefix_v1384=commit_reply_v1918 \
    -Dmm_pure_release_prefix_v1384=release_reply_v1918 \
    -Dmm_unpin=unpin_reply_v1918 \
    "$work/unsafe-release.c" -o "$work/unsafe-release.s"
reject() {
    name=$1
    shift
    if run_guest "$name" "$@" >"$work/$name.log" 2>&1; then
        echo "FAIL: $name accepted" >&2
        exit 1
    fi
    if ! grep -F 'FAIL: __test_exit' "$work/$name.log"; then
        cat "$work/$name.log"
        echo "FAIL: $name failed for a non-assertion reason" >&2
        exit 1
    fi
    echo "PASS: $name rejected"
}
reject unsafe-drop-v1918 "$work/unsafe-drop.s" "$work/prefix.s"
reject unsafe-release-v1918 "$work/drop.s" "$work/unsafe-release.s"
echo 'PASS v1918 six DROP/PREFIX faults, seven geometry cases and two unsafe mutants'
