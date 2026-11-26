#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-bitmap-prefix-v1978.XXXXXX")
trap 'echo "v1978 evidence: $work"' EXIT
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/drivers -I$src/modules -I$PDP10_PREFIX/include"
compile() {
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@"
}
flags='-DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 -DDAIMOS_PURE_DROP_ONLY_V1611=1 -DDAIMOS_PBM_PREFIX_V1978=1'
faults='-Dmm_pin=pin_v1978 -Dmm_unpin=unpin_v1978 -Dmm_pure_rebase_pinned_v1381=rebase_v1978 -Dpbmd_encode_v1977=encode_v1978'
compile $flags $faults "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile "$src/proc/proc_pure_bitmap_directory_v1977.c" -o "$work/codec.s"
compile "$here/test-native-v1978.c" -o "$work/test.s"
# Execute the actual private legacy RAW unlock/recovery predicates.
# Extract unchanged functions, not a second implementation of the gates.
python3 - "$src/proc/proc_pure_service_pdp6_v1612.c" "$work/legacy-v1978.c" <<'PYGATE'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
a=s.index('static int\nppure_retryable_v1612(')
b=s.index('/* The permanent armer',a)
header=s[:s.index('/* PI-excluded retry proof')]
# No live service dispatcher is built for this independent predicate test.
Path(sys.argv[2]).write_text(header+s[a:b]+"""
int legacy_gate_v1978(unsigned int slot, unsigned int mode)
{
        struct proc *p;
        kword_t *u, raw, words;
        if (ppure_recover_preflight_v1902(slot, &p, &u, &raw, &words))
                return 1;
        if (ppure_unlock_v1917(slot, &proc_table[slot], mode))
                return 2;
        return 0;
}
""")
PYGATE
compile -DDAIMOS_PBM_V1667=0 "$work/legacy-v1978.c" -o "$work/legacy.s"
# Source-link the actual machine PI gate, not a C mock.
{
    printf '.text\n.globl mach_pi_disable\n.globl mach_pi_restore\n.globl proc_swap_storage_invariant_v30\nproc_swap_storage_invariant_v30:\n halt .\n'
    sed -n '/^mach_pi_disable:/,/^mach_pi_restore:/p' "$src/core/kcore_pi_pdp6.s"
    sed -n '/^mach_pi_restore:/,+3p' "$src/core/kcore_pi_pdp6.s" | sed '1d'
    printf '\n.globl pi_state_v1978\npi_state_v1978:\n coni 0004,1\n popj 17,\n'
} > "$work/pi.s"
run_guest() {
    "$PDP10_PREFIX/bin/p10run" --machine "$1" --mode deposit --exec-mode go \
        --start 1000 --timeout 90 --workdir "$work/$2" --name "$2" --expect __test_exit=0 \
        --examine diag_case_v1978 --examine diag_rc_v1978 --examine diag_cases_v1978 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/pi.s" "$3" \
        "$src/mm/mm_pdp6.s" "$src/mm/mm_pure_rebase_v1381.s" \
        "$src/proc/proc_storage_runtime_v30.s" "$work/codec.s" \
        "$src/proc/proc_pure_bitmap_walk_v1977.s" "$work/legacy.s" "$work/test.s"
}
for machine in pdp6 ka10; do
    run_guest "$machine" "prefix-$machine-v1978" "$work/drop.s"
    grep -A1 'EXAMINE__ diag_cases_v1978' "$work/prefix-$machine-v1978/prefix-$machine-v1978.out"
done
# Negative controls exercise the actual candidate, not reimplemented logic.
python3 - "$src/proc/proc_pure_ram_v1381.c" "$work" <<'PYMUT'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
w=Path(sys.argv[2])
for name, old, new in [
    ('unsafe-admission', '            !(u[PROC_CRED_OFFSET] & PROC_SWAP_MUTABLE_V1976) ||\n', ''),
    ('unsafe-uarea', 'MM_EXTENT_OWNER(e) == 01000U + slot &&', '1 &&'),
    ('unsafe-pin', '    if (!proc_pure_owner_v1918(slot, MM_TYPE_PROCESS, base, words, 1U)) {', '    if (0) {'),
    ('unsafe-dirty-tag', 'u[PROC_FINALIZE_OFFSET] = PROC_PURE_BITMAP_ESCROW_V1978(suffix);', 'u[PROC_FINALIZE_OFFSET] = PROC_PURE_INPLACE_ESCROW_V1919(suffix, PROC_PURE_DROP_TAG_V1919);'),
    ('unsafe-cancel', '''        if (!proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS, suffix,
            words - skip, 1U))
                return MM_ERR_BUSY;''', '''        if (!proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS, suffix,
            words - skip, 1U)) {
                (void)mm_unpin(base);
                return MM_ERR_BUSY;
        }'''),
    ('unsafe-token', '            proc_swap_records[slot].state != lease->backing)', '            0)'),
]:
    assert s.count(old)==1,(name,old)
    (w/(name+'.c')).write_text(s.replace(old,new,1))
PYMUT
for mutant in unsafe-admission unsafe-uarea unsafe-pin unsafe-dirty-tag unsafe-cancel unsafe-token; do
    compile $flags $faults "$work/$mutant.c" -o "$work/$mutant.s"
    if run_guest pdp6 "$mutant-v1978" "$work/$mutant.s" >"$work/$mutant.log" 2>&1; then
        echo "FAIL: $mutant accepted"; exit 1
    fi
    grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
    echo "PASS: $mutant rejected"
done
