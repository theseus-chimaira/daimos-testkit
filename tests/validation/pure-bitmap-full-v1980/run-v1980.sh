#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-bitmap-full-v1980.XXXXXX")
trap 'echo "v1980 evidence: $work"' EXIT
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/drivers -I$src/modules -I$PDP10_PREFIX/include"
compile() {
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@"
}
flags='-DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 -DDAIMOS_PURE_DROP_ONLY_V1611=1 -DDAIMOS_PBM_PREFIX_V1978=1 -DDAIMOS_PBM_COMMIT_V1979=1'
faults='-Dmm_pin=pin_v1978 -Dmm_unpin=unpin_v1978 -Dmm_pure_rebase_pinned_v1381=rebase_v1978 -Dpbmd_encode_v1977=encode_v1978 -Dmm_pure_bitmap_commit_v1979=commit_mm_v1979'
compile $flags $faults "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile "$src/proc/proc_pure_bitmap_directory_v1977.c" -o "$work/codec.s"
restore_flags='-DDAIMOS_PURE_FULL_V1391=1 -DDAIMOS_PBM_RESTORE_V1980=1 -Dmm_pin=pin_v1980 -Dmm_unpin=unpin_v1980 -Dmm_free=free_v1980 -Dmm_alloc_aligned_noreclaim=alloc_v1980 -Dpbmd_decode_v1977=decode_v1980 -Dpbmd_verify_v1979=verify_v1980 -Dmm_pure_bitmap_finish_v1664=finish_v1980'
compile $restore_flags "$src/proc/proc_pure_ram_restore_v1391.c" -o "$work/restore.s"
python3 - "$here" "$work" <<'PYTEST'
from pathlib import Path
import sys
h,w=map(Path,sys.argv[1:]);s=(h.parent/'pure-bitmap-prefix-v1978/test-native-v1978.c').read_text()
a='int main(void)';assert s.count(a)==1
(w/'test-v1980.c').write_text(s.replace(a,'int old_main_v1978(void)')+'\n'+(h.parent/'pure-bitmap-commit-v1979/test-native-v1979.c').read_text().replace(a,'int old_main_v1979(void)')+'\n'+(h/'test-native-v1980.c').read_text())
PYTEST
compile "$work/test-v1980.c" -o "$work/test.s"
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
        --examine diag_case_v1980 --examine diag_cases_v1980 --examine diag_rc_v1980 --examine diag_bad_v1980 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/pi.s" "$3" \
        "$src/mm/mm_pdp6.s" "$src/mm/mm_pure_rebase_v1381.s" "${MM_LEAF:-$src/mm/mm_pure_bitmap_commit_v1979.s}" \
        "$src/proc/proc_storage_runtime_v30.s" "$work/codec.s" \
        "$src/proc/proc_pure_bitmap_walk_v1977.s" "$work/legacy.s" "$work/test.s" "${RESTORE_LEAF:-$work/restore.s}" \
        "$src/mm/mm_pure_bitmap_finish_v1664.s" "$src/proc/exec_image_common_v1386.s" \
        "$work/backing-v1980.s" "$work/fixed-v1980.s" "$src/core/d6block_vfs_fixed_v1458.s" \
        "$kit/tests/validation/exec-image-common-v1386/pure-media-unused-v1925.s"
}
for machine in pdp6 ka10; do
    run_guest "$machine" "full-$machine-v1980" "$work/drop.s"
    grep -A1 'EXAMINE__ diag_cases_v1980' "$work/full-$machine-v1980/full-$machine-v1980.out"
done
# Each mutant must reach a native assertion; compile/link errors are not
# evidence that an unsafe implementation was detected.
python3 - "$src/proc/proc_pure_ram_restore_v1391.c" "$work" <<'PYMUT'
from pathlib import Path
import sys
p,w=map(Path,sys.argv[1:]);s=p.read_text();head,tail=s.split('#ifdef DAIMOS_PBM_RESTORE_V1980\n',1)
variants=[
 ('no-compare','rc = pbmd_verify_v1979(target + skip, raw, source, encoded);','rc = MM_OK;'),
 ('trust-finish','if (owners == 2 && pbr_identity_ok_v1980(slot, &id)) {','if (rc == MM_OK) {'),
 ('no-pin-proof','if (proc_pure_full_owners_v1917(slot, source, encoded, 0UL, id.words, 1U, 0U) != 1) {','if (rc != MM_OK) {'),
 ('no-post-io-identity','if (!pbr_identity_ok_v1980(slot, &id) ||\n            proc_pure_full_owners_v1917(slot, source, encoded, target, id.words, 1U, 1U) != 3)\n                goto uncertain;\n        if (rc != MM_OK)','if (proc_pure_full_owners_v1917(slot, source, encoded, target, id.words, 1U, 1U) != 3)\n                goto uncertain;\n        if (rc != MM_OK)'),
 ('no-post-io-owner','if (!pbr_identity_ok_v1980(slot, &id) ||\n            proc_pure_full_owners_v1917(slot, source, encoded, target, id.words, 1U, 1U) != 3)\n                goto uncertain;\n        if (rc != MM_OK)','if (!pbr_identity_ok_v1980(slot, &id))\n                goto uncertain;\n        if (rc != MM_OK)'),
 ('ignore-target-free','if (proc_pure_full_owners_v1917(slot, source, encoded, target, id.words, 1U, 0U) != 1)\n                        goto uncertain;','if (0) goto uncertain;'),
]
for name,old,new in variants:
    assert tail.count(old)==1,(name,tail.count(old))
    (w/(name+'.c')).write_text(head+'#ifdef DAIMOS_PBM_RESTORE_V1980\n'+tail.replace(old,new,1))
PYMUT
for mutant in no-compare trust-finish no-pin-proof no-post-io-identity no-post-io-owner ignore-target-free; do
    compile $restore_flags "$work/$mutant.c" -o "$work/$mutant.s"
    RESTORE_LEAF="$work/$mutant.s"
    if run_guest pdp6 "$mutant-v1980" "$work/drop.s" >"$work/$mutant.log" 2>&1; then
        echo "FAIL: $mutant accepted"; exit 1
    fi
    grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
    echo "PASS: $mutant rejected"
done
