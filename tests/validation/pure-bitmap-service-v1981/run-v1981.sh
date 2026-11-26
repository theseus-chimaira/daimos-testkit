#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-bitmap-service-v1981.XXXXXX")
trap 'echo "v1981 evidence: $work"' EXIT
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
restore_flags='-DDAIMOS_PURE_FULL_V1391=1 -DDAIMOS_PBM_RESTORE_V1980=1 -Dmm_pin=pin_v1980 -Dmm_unpin=unpin_v1980 -Dmm_free=free_v1980 -Dmm_alloc_aligned_noreclaim=alloc_v1980 -Dpbmd_decode_v1977=decode_v1980 -Dpbmd_verify_v1979=verify_v1980 -Dmm_pure_bitmap_finish_v1664=finish_v1980'
compile $restore_flags "$src/proc/proc_pure_ram_restore_v1391.c" -o "$work/restore.s"
python3 - "$here" "$work" <<'PYTEST'
from pathlib import Path
import os,sys
h,w=map(Path,sys.argv[1:]);s=(h.parent/'pure-bitmap-prefix-v1978/test-native-v1978.c').read_text()
a='int main(void)';assert s.count(a)==1
test=s.replace(a,'int old_main_v1978(void)')+'\n'+(h.parent/'pure-bitmap-commit-v1979/test-native-v1979.c').read_text().replace(a,'int old_main_v1979(void)')+'\n'+(h.parent/'pure-bitmap-full-v1980/test-native-v1980.c').read_text().replace(a,'int old_main_v1980(void)').replace('static int load_v1980(', 'int load_v1980(')+'\n'+(h/'test-native-v1981.c').read_text()
if os.environ.get('PURE_SCHED_V1986')=='1':
    test=test.replace(a,'int old_main_v1981(void)')+'\n'+(h.parent/'pure-directory-pi6-v1986/test-native-v1986.c').read_text()
(w/'test-v1980.c').write_text(test)
PYTEST
compile "$work/test-v1980.c" -o "$work/test.s"
# Link the complete production service (not an extracted dispatcher).
service_flags='-DDAIMOS_PBM_V1667=0 -DDAIMOS_PBM_COMMIT_V1979=1 -DDAIMOS_PBM_RESTORE_V1980=1 -Dproc_pure_bitmap_restore_v1980=service_restore_v1981 -Dexec_image_full_bounded_v1391=load_v1980'
cp "$src/proc/proc_pure_service_pdp6_v1612.c" "$work/service-v1981.c"
cat >> "$work/service-v1981.c" <<'C'
int legacy_gate_v1978(unsigned int slot, unsigned int mode)
{
        struct proc *p;
        kword_t *u, raw, words;
        if (ppure_recover_preflight_v1902(slot, &p, &u, &raw, &words)) return 1;
        return ppure_unlock_v1917(slot, &proc_table[slot], mode) ? 2 : 0;
}
C
compile $service_flags "$work/service-v1981.c" -o "$work/service.s"
compile -DDAIMOS_SWAPLESS_PREFIX_V1384=1 "$src/proc/proc_pure_restore_v1384.c" -o "$work/prefix.s"
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
    guest_machine=$1; guest_name=$2; guest_drop=$3; shift 3
    if [ "${PURE_SCHED_V1986:-0}" = 1 ]; then
        selector_examine="--examine diag_case_v1986 --examine diag_cases_v1986"
    else
        selector_examine=
    fi
    "$PDP10_PREFIX/bin/p10run" --machine "$guest_machine" --mode deposit --exec-mode go \
        --start 1000 --timeout 90 --workdir "$work/$guest_name" --name "$guest_name" --expect __test_exit=0 \
        --examine diag_case_v1981 --examine diag_cases_v1981 --examine diag_rc_v1981 $selector_examine \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/pi.s" "$guest_drop" \
        "$src/mm/mm_pdp6.s" "$src/mm/mm_pure_rebase_v1381.s" "${MM_LEAF:-$src/mm/mm_pure_bitmap_commit_v1979.s}" \
        "$src/proc/proc_storage_runtime_v30.s" "$work/codec.s" \
        "$src/proc/proc_pure_bitmap_walk_v1977.s" "${SERVICE_LEAF:-$work/service.s}" "$work/prefix.s" "$src/mm/mm_pure_expand_v1384.s" "$work/test.s" "${RESTORE_LEAF:-$work/restore.s}" \
        "$src/mm/mm_pure_bitmap_finish_v1664.s" "$src/proc/exec_image_common_v1386.s" \
        "$work/backing-v1980.s" "$work/fixed-v1980.s" "$src/core/d6block_vfs_fixed_v1458.s" \
        "$kit/tests/validation/exec-image-common-v1386/pure-media-unused-v1925.s" "$@"
}
if [ "${PURE_SCHED_V1986:-0}" = 1 ]; then
    {
        printf '.text\n.globl proc_sched_resched_select\n.globl proc_sched_tick_select\n'
        sed -n '/^        \.equ    PROC_WORDS,3$/,/^        \.text$/p' "$src/proc/proc_pdp6.s"
        sed -n '/^proc_sched_resched_select:$/,/^\/\*\*$/p' "$src/proc/proc_pdp6.s" | sed '$d'
    } > "$work/selector-v1986.s"
    for machine in pdp6 ka10; do
        run_guest "$machine" "selector-$machine-v1986" "$work/drop.s" "$work/selector-v1986.s"
    done
    python3 "$here/../pure-directory-pi6-v1986/mutate-selector-v1986.py" "$work/selector-v1986.s"
    for mutant in no-ready retain-ready ready-no-transition ready-no-apr ready-no-state normal-no-transition; do
        if run_guest pdp6 "$mutant-v1986" "$work/drop.s" "$work/$mutant.s" >"$work/$mutant.log" 2>&1; then
            echo "FAIL: $mutant accepted"; exit 1
        fi
        grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
        echo "PASS: $mutant rejected"
    done
    exit 0
fi
for machine in pdp6 ka10; do
    run_guest "$machine" "service-$machine-v1981" "$work/drop.s"
    grep -A1 'EXAMINE__ diag_cases_v1981' "$work/service-$machine-v1981/service-$machine-v1981.out"
done
# Execute unsafe source variants, require a native assertion failure.
python3 - "$src" "$work" <<'PYMUT'
from pathlib import Path
import sys
s,w=map(Path,sys.argv[1:]);service=(w/'service-v1981.c').read_text();restore=(s/'proc/proc_pure_ram_restore_v1391.c').read_text()
a='int\nproc_pure_bitmap_unlock_v1981(';pre,tail=restore.split(a,1);unlock,post=tail.split('int\nproc_pure_bitmap_restore_v1980(',1)
variants=[
 ('trust-return',service,'if (!PROC_TRANSITION(p) && VM_PDP6_BASE(p) &&','if (rc == MM_OK && !PROC_TRANSITION(p) && VM_PDP6_BASE(p) &&'),
 ('no-unlock-proof',service,'(void)proc_pure_bitmap_unlock_v1981(slot);','PROC_CLEAR_TRANSITION(p);'),
 ('no-escrow-guard',unlock,'u[PROC_SWAP_BACKING_OFFSET] != backing || u[PROC_FINALIZE_OFFSET] ||','u[PROC_SWAP_BACKING_OFFSET] != backing ||'),
 ('no-owner-guard',unlock,'!pbr_source_v1981(slot, words, skip, &source, &encoded)','0'),
 ('no-mode3-service',service,'bitmap = ppure_mode3_v1667(slot);','bitmap = 0;'),
]
for name,source,old,new in variants:
    assert source.count(old)==1,(name,source.count(old))
    out=source.replace(old,new,1)
    if source==unlock:
        out=pre+a+out+'int\nproc_pure_bitmap_restore_v1980('+post
    (w/(name+'.c')).write_text(out)
PYMUT
for mutant in trust-return no-unlock-proof no-escrow-guard no-owner-guard no-mode3-service; do
    SERVICE_LEAF="$work/service.s" RESTORE_LEAF="$work/restore.s"
    case "$mutant" in
        no-escrow-guard|no-owner-guard)
            compile $restore_flags "$work/$mutant.c" -o "$work/$mutant.s"
            RESTORE_LEAF="$work/$mutant.s" ;;
        *)  compile $service_flags "$work/$mutant.c" -o "$work/$mutant.s"
            SERVICE_LEAF="$work/$mutant.s" ;;
    esac
    if run_guest pdp6 "$mutant-v1981" "$work/drop.s" >"$work/$mutant.log" 2>&1; then
        echo "FAIL: $mutant accepted"; exit 1
    fi
    grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
    echo "PASS: $mutant rejected"
done
