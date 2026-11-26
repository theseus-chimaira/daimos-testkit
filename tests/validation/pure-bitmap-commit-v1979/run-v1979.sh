#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-bitmap-commit-v1979.XXXXXX")
trap 'echo "v1979 evidence: $work"' EXIT
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/drivers -I$src/modules -I$PDP10_PREFIX/include"
compile() {
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@"
}
flags='-DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 -DDAIMOS_PURE_DROP_ONLY_V1611=1 -DDAIMOS_PBM_PREFIX_V1978=1 -DDAIMOS_PBM_COMMIT_V1979=1'
faults='-Dmm_pin=pin_v1978 -Dmm_unpin=unpin_v1978 -Dmm_pure_rebase_pinned_v1381=rebase_v1978 -Dpbmd_encode_v1977=encode_v1978 -Dmm_pure_bitmap_commit_v1979=commit_mm_v1979'
compile $flags $faults "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile "$src/proc/proc_pure_bitmap_directory_v1977.c" -o "$work/codec.s"
python3 - "$here" "$work" <<'PYTEST'
from pathlib import Path
import sys
h,w=map(Path,sys.argv[1:]);s=(h.parent/'pure-bitmap-prefix-v1978/test-native-v1978.c').read_text()
a='int main(void)';assert s.count(a)==1
(w/'test-v1979.c').write_text(s.replace(a,'int old_main_v1978(void)')+'\n'+(h/'test-native-v1979.c').read_text())
PYTEST
compile "$work/test-v1979.c" -o "$work/test.s"
# Execute the actual private legacy RAW unlock/recovery predicates.
# Extract unchanged functions, not a second implementation of the gates.
python3 - "$src/proc/proc_pure_service_pdp6_v1612.c" "$work/legacy-v1978.c" <<'PYGATE'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
a=s.index('static int\nppure_retryable_v1612(')
b=s.index('/* Service only an explicitly requested',a)
header=s[:s.index('/* PI-excluded retry proof')]
c=s.index('/* Roll back a PREFIX full-span claim',a)
d=s.index('/* Keep malformed MM tables out',c)
# No live service dispatcher is built for this independent predicate test.
Path(sys.argv[2]).write_text(header+s[a:c]+s[d:b]+"""
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
compile -DDAIMOS_PBM_V1667=0 -DDAIMOS_PBM_COMMIT_V1979=1 "$work/legacy-v1978.c" -o "$work/legacy.s"
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
        --examine diag_case_v1979 --examine diag_cases_v1979 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/pi.s" "$3" \
        "$src/mm/mm_pdp6.s" "$src/mm/mm_pure_rebase_v1381.s" "${MM_LEAF:-$src/mm/mm_pure_bitmap_commit_v1979.s}" \
        "$src/proc/proc_storage_runtime_v30.s" "$work/codec.s" \
        "$src/proc/proc_pure_bitmap_walk_v1977.s" "$work/legacy.s" "$work/test.s"
}
for machine in pdp6 ka10; do
    run_guest "$machine" "commit-$machine-v1979" "$work/drop.s"
    grep -A1 'EXAMINE__ diag_cases_v1979' "$work/commit-$machine-v1979/commit-$machine-v1979.out"
done
# Each mutant must reach a native assertion, not merely fail to build.
python3 - "$src" "$work" <<'PYMUT'
from pathlib import Path
import sys
s,w=map(Path,sys.argv[1:]);c=(s/'proc/proc_pure_ram_v1381.c').read_text();a=(s/'mm/mm_pure_bitmap_commit_v1979.s').read_text()
for name,source,old,new in [
    ('unsafe-no-compare',c,'if (pbmd_verify_v1979(base + skip, words - skip, base, encoded) != MM_OK)','if (0)'),
    ('unsafe-trust-reply',c,'if (proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS, base, encoded, 0U)) {','if (rc == MM_OK) {'),
    ('unsafe-release-pin',a,'hrli    3,4                    ; PACKED_PROCESS, zero pins','hrli    3,014                  ; incorrectly retain pin'),
    ('unsafe-mm-owner',a,'jumpge  14,mbc_bad_v1979       ; second user owner','jrst    mbc_next_owner_v1979\nmbc_next_owner_v1979:'),
    ('unsafe-mm-capacity',a,'camle   13,4\n        jrst    mbc_bad_v1979',''),
    ('unsafe-mm-pins',a,'caie    4,011                  ; exactly one pin, PROCESS\n        jrst    mbc_busy_v1979',''),
]:
    assert source.count(old)==1,(name,old)
    # Ignore a second same-slot owner, not the first one's other checks.
    if name=='unsafe-mm-owner': new='jumpge  14,mbc_next_v1979'
    (w/(name+('.c' if source==c else '.s'))).write_text(source.replace(old,new,1))
PYMUT
for mutant in unsafe-no-compare unsafe-trust-reply unsafe-release-pin unsafe-mm-owner unsafe-mm-capacity unsafe-mm-pins; do
    drop="$work/drop.s"
    MM_LEAF="$src/mm/mm_pure_bitmap_commit_v1979.s"
    if [ -f "$work/$mutant.c" ]; then
        compile $flags $faults "$work/$mutant.c" -o "$work/$mutant.s"
        drop="$work/$mutant.s"
    else
        MM_LEAF="$work/$mutant.s"
    fi
    if run_guest pdp6 "$mutant-v1979" "$drop" >"$work/$mutant.log" 2>&1; then
        echo "FAIL: $mutant accepted"; exit 1
    fi
    grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
    echo "PASS: $mutant rejected"
done
