#!/bin/sh
# Source-linked PDP6 KCC exact target-base escrow and foreign owner safety.
set -eu
: "${DAIMOS_REPO:?original DAIMOS source checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=${V1906_NATIVE_WORK:-$(mktemp -d "$TMPDIR/daimos-k05-foreign-target-v1906-native.XXXXXX")}
mkdir -p "$work"
if [ -n "${V1906_NATIVE_BASE:-}" ]; then
    base=$V1906_NATIVE_BASE
    echo "v1906: source-built current v1612 KCC native base: $base"
else
    echo '=== v1906: compile and execute current PDP6 KCC v1612 baseline ==='
    KEEP_TEST=1 sh "$kit/tests/validation/pure-service-v1612/run-v1612.sh" \
        >"$work/historical-v1612.log" 2>&1 || {
            tail -85 "$work/historical-v1612.log" >&2
            exit 1
        }
    base=$(sed -n 's/^v1612 work: //p' "$work/historical-v1612.log" | tail -1)
fi
if [ ! -f "$base/test-v1611.c" ] || [ ! -f "$base/service-v1611.s" ]; then
    echo 'FAIL v1906: source-linked native baseline evidence missing' >&2
    exit 1
fi
echo "v1906 actual KCC v1612 compiled base: $base"

# Keep old fixture intact. Extend its MM test response with an explicitly
# controlled PROCESS refusal and a completed deletion with lost success
# reply. The recovery C and original PDP6 MM-rebase/claim ASM are NEVER
# rewritten. The test-only armer fills the existing u-area retry tag;
# full-system KCORE arm/clock are verified by the physical controller.
python3 - "$base/test-v1611.c" \
    "$kit/tests/validation/pure-ram-inplace-v1381/test-native-v1381.c" \
    "$here/test-native-v1906.c" \
    "$work/test-native-v1381.c" "$work/test-native-v1906.c" <<'PYV1906'
from pathlib import Path
import sys

def once(text,old,new):
    if text.count(old)!=1:
        raise SystemExit('FAIL v1906 historical MM fixture drift: '+old[:58])
    return text.replace(old,new,1)

old=Path(sys.argv[2]).read_text('ascii')
old=once(old,
    'static unsigned int free_count_v1381;\n',
    'static unsigned int free_count_v1381;\n'
    'static int refuse_target_free_v1902;\n'
    'static int false_target_reply_v1902;\n')
old=once(old,
    '        ++free_count_v1381;\n'
    '        return mm_free_fixture_v1381(base, type, owner);\n',
    '        int rc;\n'
    '        ++free_count_v1381;\n'
    '        if (type == MM_TYPE_PROCESS && base == RESTORE &&\n'
    '            refuse_target_free_v1902)\n'
    '                return MM_ERR_BUSY;\n'
    '        rc = mm_free_fixture_v1381(base, type, owner);\n'
    '        if (type == MM_TYPE_PROCESS && base == RESTORE &&\n'
    '            false_target_reply_v1902 && rc == MM_OK) {\n'
    '                false_target_reply_v1902 = 0;\n'
    '                return MM_ERR_BUSY;\n'
    '        }\n'
    '        return rc;\n')
Path(sys.argv[4]).write_text(old,encoding='ascii')
old=Path(sys.argv[1]).read_text('ascii')
old=once(old,
    'int\nmain(void)\n{\n        int rc;\n',
    'int\noriginal_v1612_main_v1902(void)\n{\n        int rc;\n')
old=once(old,
    '        ++pure_test_recover_arm_calls_v1902;\n'
    '        return 0;\n',
    '        ++pure_test_recover_arm_calls_v1902;\n'
    '        ((kword_t *)(unsigned long)uarea)[PROC_FINALIZE_OFFSET] =\n'
    '            PROC_SWAP_RETRY_TAG_V1507;\n'
    '        return 0;\n')
test=Path(sys.argv[3]).read_text('ascii')
old=once(old,
    '#include "test-native-v1381.c"',
    '#include "'+str(Path(sys.argv[4]).resolve())+'"')
Path(sys.argv[5]).write_text(
    old+'\n'+test,encoding='ascii')
PYV1906

inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include -I$kit/tests/validation/pure-ram-lifecycle-v1377 -I$kit/tests/validation/pure-ram-registryfree-v1379 -I$kit/tests/validation/pure-ram-inplace-v1381"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_TEST_PURE_SERVICE_V1612=1 \
    -Dproc_pure_mres_reclaim_v1611=proc_pure_mres_reclaim_v1612 \
    -Dproc_pure_mres_service_v1611=proc_pure_mres_service_v1612 \
    $inc -S "$work/test-native-v1906.c" -o "$work/test-native-v1906.s" \
    >"$work/test.compile.log" 2>&1 || {
        tail -85 "$work/test.compile.log" >&2
        exit 1
    }
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 60 \
    --workdir "$work/guest" --name daimos-k05-foreign-target-v1906 \
    --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" \
    "$base/proc_pure_ram_v1381.s" \
    "$base/proc_pure_restore_v1384.s" \
    "$base/proc_pure_ram_restore_v1391.s" \
    "$base/service-v1611.s" \
    "$src/mm/mm_pure_rebase_v1381.s" \
    "$src/mm/mm_pure_expand_v1384.s" \
    "$src/proc/proc_storage_runtime_v30.s" \
    "$src/drivers/device_state.s" \
    "$work/test-native-v1906.s" >"$work/native.log" 2>&1 || {
        tail -85 "$work/native.log" >&2
        echo "FAIL v1906: original KCC PDP6 escrow recovery: $work" >&2
        exit 1
    }
echo 'PASS v1906 PDP6 KCC exact escrow, genuine target free, lost reply and foreign owner fail-closed'
echo "v1906 KCC native evidence: $work"
