#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-bitmap-terminal-v1982.XXXXXX")
trap 'echo "v1982 evidence: $work"' EXIT
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/drivers -I$src/modules -I$PDP10_PREFIX/include"
compile() {
    case ${PURE_TEST_COMPILER_V1984:-kcc} in
        kcc) "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@" ;;
        gcc) "$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 $inc -S "$@" ;;
        *) echo 'Invalid PURE_TEST_COMPILER_V1984' >&2; return 1 ;;
    esac
}
flags='-DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 -DDAIMOS_PURE_DROP_ONLY_V1611=1 -DDAIMOS_PBM_PREFIX_V1978=1 -DDAIMOS_PBM_COMMIT_V1979=1'
faults='-Dmm_pin=pin_v1978 -Dmm_unpin=unpin_v1978 -Dmm_pure_rebase_pinned_v1381=rebase_v1978 -Dpbmd_encode_v1977=encode_v1978 -Dmm_pure_bitmap_commit_v1979=commit_mm_v1979'
compile $flags $faults "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile "$src/proc/proc_pure_bitmap_directory_v1977.c" -o "$work/codec.s"
restore_flags='-DDAIMOS_PURE_FULL_V1391=1 -DDAIMOS_PBM_RESTORE_V1980=1 -DDAIMOS_PBM_TERM_V1982=1 -Dmm_pin=pin_v1980 -Dmm_unpin=unpin_v1980 -Dmm_free=term_free_v1982 -Dmm_alloc_aligned_noreclaim=alloc_v1980 -Dpbmd_decode_v1977=decode_v1980 -Dpbmd_verify_v1979=verify_v1980 -Dmm_pure_bitmap_finish_v1664=finish_v1980'
compile $restore_flags "$src/proc/proc_pure_ram_restore_v1391.c" -o "$work/restore.s"
python3 - "$here" "$work" <<'PYTEST'
from pathlib import Path
import sys
h,w=map(Path,sys.argv[1:]);s=(h.parent/'pure-bitmap-prefix-v1978/test-native-v1978.c').read_text()
a='int main(void)';assert s.count(a)==1
(w/'test-v1980.c').write_text(s.replace(a,'int old_main_v1978(void)')+'\n'+(h.parent/'pure-bitmap-commit-v1979/test-native-v1979.c').read_text().replace(a,'int old_main_v1979(void)')+'\n'+(h.parent/'pure-bitmap-full-v1980/test-native-v1980.c').read_text().replace(a,'int old_main_v1980(void)')+'\n'+(h/'test-native-v1982.c').read_text())
PYTEST
compile "$work/test-v1980.c" -o "$work/test.s"
compile -DTEST_VM_TERM_V1982=1 "$work/test-v1980.c" -o "$work/test-vm.s"
# Source-link the original common detach without duplicate fixture globals.
python3 - "$src/proc/vm_pdp6_swap.c" "$work/detach-v1982.c" <<'PYDETACH'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text();a=s.index('int\nproc_swap_detach(int slot)');b=s.index('\n/**',a)
Path(sys.argv[2]).write_text('#include "proc_swap.h"\n#include "proc_storage_map_v28.h"\nextern int proc_storage_expect_v30(unsigned int,unsigned int);\nextern int proc_swap_term_v1666(int,struct proc *,kword_t);\n'+s[a:b])
PYDETACH
compile "$work/detach-v1982.c" -o "$work/detach.s"
{
    printf '.equ PROC_SWAP_TEXT_SHIFT,026\n.equ PROC_SWAP_TEXT_MASK,037777\n.equ PROC_SWAP_BACKING_OFFSET,0406\n.equ EXEC_USER_ORIGIN,020\n'
    cat "$src/proc/proc_pure_packed_detach_v1609.s"
    printf '.globl proc_swap_term_v1666\nproc_swap_term_v1666:\n jrst proc_pure_term_v1982\n'
} > "$work/terminal.s"
# Both default and explicitly staged VM entry use the same source.
# Neither this test nor the new assembly symbol enables an installed build.
{ printf '.text\n.globl vm_space_destroy\n'; sed -n '/^vm_space_destroy:$/,/^\/\*\*$/p' "$src/proc/vm_pdp6.s" | sed '$d'; } > "$work/vm.s"
{ printf '.equ DAIMOS_PBM_VM_TERM_V1982,1\n'; cat "$work/vm.s"; } > "$work/vm-staged.s"
# Extract original PREVM preservation and actual retry-marker routine.
{
    printf '.text\n.globl prevm_v1982\n.equ PROC_FINALIZE_OFFSET,067\n.equ PROC_FINALIZE_MARK_LH,0400000\n.equ PROC_FINALIZE_PREVM_LH,0100000\n.equ PROC_FINISH_ARMED_LH_V1763,040000\nprevm_v1982:\n push 17,11\n push 17,12\n move 12,1\n move 11,2\n'
    sed -n '/^proc_finish_prevm_fail_v1081:$/,/pushj   17,proc_finish_mark_pending_v892/p' "$src/proc/proc_pdp6.s"
    printf ' pop 17,12\n pop 17,11\n popj 17,\n'
    sed -n '/^proc_finish_mark_pending_v892:$/,/^        popj    17,$/p' "$src/proc/proc_pdp6.s"
} > "$work/prevm.s"
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
# Real backing unpacker and actual resident physical-memory copy leaves.
{
    printf '.text\n.globl proc_swap_unpack_backing\n.equ PROC_SWAP_TEXT_SHIFT,026\n.equ PROC_SWAP_TEXT_MASK,037777\n.equ PROC_SWAP_MOUNT_SHIFT,022\n'
    sed -n '/^proc_swap_unpack_backing:$/,/^proc_swap_reload_pure:$/p' "$src/proc/proc_pure_backing_pdp6.s" | sed '$d'
    printf '.globl fs_zero_words\n.globl fs_copy_words\n'
    sed -n '/^fs_copy_words:$/,/^fs_copy_words_done:$/p' "$src/fs/fs_mres.s"
    printf ' popj 17,\n'
    sed -n '/^fs_zero_words:$/,/^fs_zero_words_done:$/p' "$src/fs/fs_mres.s"
    printf ' popj 17,\n'
} > "$work/backing-v1980.s"
cp "$DAIMOS_REPO/system/stand/pdp6/common/block_decompressor_v1458.inc" "$work/fixed-v1980.s"
cat >> "$work/fixed-v1980.s" <<'ASM'
        .globl install_d6_v1980
install_d6_v1980:
        movei 1,062
        hrli 1,d6b_image_start_v1458
        blt 1,062+(d6b_image_end_v1458-d6b_image_start_v1458)-1
        popj 17,
ASM
run_guest() {
    "$PDP10_PREFIX/bin/p10run" --machine "$1" --mode deposit --exec-mode go \
        --start 1000 --timeout 90 --workdir "$work/$2" --name "$2" --expect __test_exit=0 \
        --examine diag_case_v1982 --examine diag_cases_v1982 --examine diag_rc_v1982 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/pi.s" "$3" \
        "$src/mm/mm_pdp6.s" "$src/mm/mm_pure_rebase_v1381.s" "${MM_LEAF:-$src/mm/mm_pure_bitmap_commit_v1979.s}" \
        "$src/proc/proc_storage_runtime_v30.s" "$work/codec.s" \
        "$src/proc/proc_pure_bitmap_walk_v1977.s" "$work/legacy.s" "${TEST_LEAF:-$work/test.s}" "$work/detach.s" "$work/terminal.s" "$work/prevm.s" "${VM_LEAF:-$work/vm.s}" "$src/core/ret.s" "${RESTORE_LEAF:-$work/restore.s}" \
        "$src/mm/mm_pure_bitmap_finish_v1664.s" "$src/proc/exec_image_common_v1386.s" \
        "$work/backing-v1980.s" "$work/fixed-v1980.s" "$src/core/d6block_vfs_fixed_v1458.s" \
        "$kit/tests/validation/exec-image-common-v1386/pure-media-unused-v1925.s"
}
for machine in pdp6 ka10; do
    run_guest "$machine" "terminal-$machine-v1982" "$work/drop.s"
    grep -A1 'EXAMINE__ diag_cases_v1982' "$work/terminal-$machine-v1982/terminal-$machine-v1982.out"
    TEST_LEAF="$work/test-vm.s" VM_LEAF="$work/vm-staged.s" run_guest "$machine" "vm-terminal-$machine-v1982" "$work/drop.s"
    grep -A1 'EXAMINE__ diag_cases_v1982' "$work/vm-terminal-$machine-v1982/vm-terminal-$machine-v1982.out"
done
TEST_LEAF="$work/test-vm.s"
VM_LEAF="$work/vm-staged.s"
# Negative controls must fail a native assertion, not compilation/linking.
python3 - "$src/proc/proc_pure_ram_restore_v1391.c" "$work" <<'PYMUT'
from pathlib import Path
import sys
p,w=map(Path,sys.argv[1:]);s=p.read_text();head,tail=s.split('#ifdef DAIMOS_PBM_TERM_V1982\n',1)
variants=[
 ('trust-free','(void)mm_free(base, MM_TYPE_PACKED_PROCESS, slot);\n                owners = proc_pure_full_owners_v1917(slot, base, encoded, 0UL, words, 0U, 0U);','owners = mm_free(base, MM_TYPE_PACKED_PROCESS, slot) == MM_OK ? 0 : 1;'),
 ('no-span-escrow','u[PROC_BRK_OFFSET] = (encoded << 18U) | base;','u[PROC_BRK_OFFSET] = 0UL;'),
 ('adopt-length','encoded = u[PROC_BRK_OFFSET] >> 18U;','''encoded = u[PROC_BRK_OFFSET] >> 18U;
                for (i = 0; i < mm_extent_count; ++i)
                        if (MM_EXTENT_OWNER(&mm_extents[i]) == slot &&
                            MM_EXTENT_TYPE(&mm_extents[i]) == MM_TYPE_PACKED_PROCESS &&
                            MM_EXTENT_BASE(&mm_extents[i]) == base)
                                encoded = MM_EXTENT_WORDS(&mm_extents[i]);'''),
 ('no-original-owner','!proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS, base,\n                        encoded, MM_EXTENT_PINS(&mm_extents[i]))','0'),
 ('no-process-proof','pbr_process_v1980(slot, 1U) != p','0'),
 ('no-file-check','if (u[PROC_FILE_TABLE_OFFSET + 2U * i])','if (0)'),
]
for name,old,new in variants:
    assert tail.count(old)==1,(name,tail.count(old))
    (w/(name+'.c')).write_text(head+'#ifdef DAIMOS_PBM_TERM_V1982\n'+tail.replace(old,new,1))
PYMUT
for mutant in trust-free no-span-escrow adopt-length no-original-owner no-process-proof no-file-check; do
    compile $restore_flags "$work/$mutant.c" -o "$work/$mutant.s"
    RESTORE_LEAF="$work/$mutant.s"
    if run_guest pdp6 "$mutant-v1982" "$work/drop.s" >"$work/$mutant.log" 2>&1; then
        echo "FAIL: $mutant accepted"; exit 1
    fi
    grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
    echo "PASS: $mutant rejected"
done
