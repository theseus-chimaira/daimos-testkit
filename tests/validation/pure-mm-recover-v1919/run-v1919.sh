#!/bin/sh
# Source-linked native deferred ownership gate. No production-code rewrites.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-mm-recover-v1919.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" = 1 ]; then echo "v1919 work: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$kit/tests/validation/pure-ram-lifecycle-v1377 -I$kit/tests/validation/pure-ram-registryfree-v1379 -I$kit/tests/validation/pure-ram-inplace-v1381"
compile() {
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@"
}
faults='-Dmm_pin=pin_fault_v1919 -Dmm_unpin=unpin_fault_v1919 -Dmm_pure_rebase_pinned_v1381=rebase_fault_v1919 -Dmm_pure_release_prefix_v1384=release_fault_v1919 -Dmm_pure_commit_prefix_v1384=commit_fault_v1919'
compile -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 $faults "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile -DDAIMOS_SWAPLESS_PREFIX_V1384=1 $faults "$src/proc/proc_pure_restore_v1384.c" -o "$work/prefix.s"
compile -DDAIMOS_PURE_FULL_V1391=1 "$src/proc/proc_pure_ram_restore_v1391.c" -o "$work/full.s"
compile $faults -Dexec_image_prefix_backing_v1386=prefix_fault_v1919 "$src/proc/proc_pure_service_pdp6_v1612.c" -o "$work/service.s"
# Make the test-only idle armer overwrite escrow just like real KCORE.
python3 - "$kit" "$here" "$work" <<'PY'
from pathlib import Path
import sys
kit, here, work = map(Path, sys.argv[1:])
s = (kit/'tests/validation/pure-service-v1611/test-native-v1611.c').read_text()
a = '        ++pure_test_recover_arm_calls_v1902;\n        return 0;'
assert s.count(a) == 1
s = s.replace(a, '        ++pure_test_recover_arm_calls_v1902;\n        ((kword_t *)(unsigned long)uarea)[PROC_FINALIZE_OFFSET] = PROC_SWAP_RETRY_TAG_V1507;\n        return 0;')
a = 'int\nmain(void)\n'
assert s.count(a) == 1
s = s.replace(a, 'int\nretired_main_v1919(void)\n')
(work/'test.c').write_text('#define DAIMOS_TEST_PURE_ROLLBACK_V1395 1\n' + (kit/'tests/validation/pure-ram-prefix-v1384/test-native-v1384.c').read_text() + '\n' + s + '\n' + (here/'test-native-v1919.c').read_text())
PY
compile -DDAIMOS_TEST_PURE_SERVICE_V1612=1 \
    -Dproc_pure_mres_reclaim_v1611=proc_pure_mres_reclaim_v1612 \
    -Dproc_pure_mres_service_v1611=proc_pure_mres_service_v1612 \
    "$work/test.c" -o "$work/test.s"
run_guest() {
    name=$1
    service=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/drop.s" "$work/prefix.s" "$work/full.s" "$service" \
        "$src/mm/mm_pure_rebase_v1381.s" "$src/mm/mm_pure_expand_v1384.s" \
        "$src/proc/proc_storage_runtime_v30.s" "$src/drivers/device_state.s" "$work/test.s"
}
run_guest pure-mm-recover-v1919 "$work/service.s"
echo 'PASS v1919 deferred DROP/PREFIX recovery'

# Prove that the native assertions reject each unsafe production decision.
python3 - "$src/proc/proc_pure_service_pdp6_v1612.c" "$work" <<'PY'
from pathlib import Path
import sys
src, work = map(Path, sys.argv[1:])
s = src.read_text()
mutants = {
    'no-drop-arm': ('                                ppure_recover_arm_v1902(slot);\n', ''),
    'allow-held-pin': ('        if (!proc_pure_owner_v1918(slot, type, base, words, 0U)) {', '        if (!proc_pure_owner_v1918(slot, type, base, words, 0U) &&\n            !proc_pure_owner_v1918(slot, type, base, words, 1U)) {'),
    'trust-pin-reply': ('        (void)mm_pin(base);', '        if (mm_pin(base) != MM_OK) return 0;'),
    'ignore-kind': ('(kind != PROC_PURE_PREFIX_TAG_V1919 ||\n                     !ppure_prefix_recover_v1919(slot, source, raw, words))', '(!ppure_prefix_recover_v1919(slot, source, raw, words))'),
    'foreign-source': ('source, raw, 0U) &&\n                    (kind !=', '0UL, raw, 0U) &&\n                    (kind !='),
}
for name, (old, new) in mutants.items():
    assert s.count(old) == 1, name
    (work / (name + '.c')).write_text(s.replace(old, new, 1))
PY
for name in no-drop-arm allow-held-pin trust-pin-reply ignore-kind foreign-source; do
    compile $faults -Dexec_image_prefix_backing_v1386=prefix_fault_v1919 "$work/$name.c" -o "$work/$name.s"
    if run_guest "$name" "$work/$name.s" >"$work/$name.log" 2>&1; then
        echo "FAIL: unsafe $name accepted" >&2
        exit 1
    fi
    if ! grep -F 'FAIL: __test_exit' "$work/$name.log"; then
        cat "$work/$name.log"
        echo "FAIL: $name failed for a non-assertion reason" >&2
        exit 1
    fi
    echo "PASS: $name rejected"
done
