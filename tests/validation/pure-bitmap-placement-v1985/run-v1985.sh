#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
if [ "${PURE_IDLE_RECOVER_V1990:-0}" = 1 ]; then
    export PURE_FULL_ESCROW_V1989=1
    [ "${PURE_PREVM_V1988:-0}" != 1 ] || { echo 'Conflicting test modes' >&2; exit 1; }
fi
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/pure-bitmap-placement-v1985.XXXXXX")
trap 'echo "v1985 evidence: $work"' EXIT
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/drivers -I$src/modules -I$PDP10_PREFIX/include"
compile() {
    case ${PURE_TEST_COMPILER_V1984:-kcc} in
        kcc) "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc -S "$@" ;;
        gcc) "$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=gnu99 -Os -march=pdp6 -mcpu=pdp6 $inc -S "$@" ;;
        *) echo 'Invalid PURE_TEST_COMPILER_V1984' >&2; return 1 ;;
    esac
}
flags='-DDAIMOS_PBM_PLACE_V1985=1 -DDAIMOS_SWAPLESS_PURE_RAM_V1381=1 -DDAIMOS_PURE_DROP_ONLY_V1611=1 -DDAIMOS_PBM_PREFIX_V1978=1 -DDAIMOS_PBM_COMMIT_V1979=1'
faults='-Dmm_pin=pin_v1978 -Dmm_unpin=unpin_v1978 -Dmm_pure_rebase_pinned_v1381=rebase_v1978 -Dpbmd_encode_v1977=encode_v1978 -Dmm_pure_bitmap_commit_v1979=commit_mm_v1979 -Dmm_pure_bitmap_place_v1985=place_mm_v1985'
compile $flags $faults "$src/proc/proc_pure_ram_v1381.c" -o "$work/drop.s"
compile "$src/proc/proc_pure_bitmap_directory_v1977.c" -o "$work/codec.s"
restore_flags='-DDAIMOS_PBM_PLACE_V1985=1 -DDAIMOS_PURE_FULL_V1391=1 -DDAIMOS_PBM_RESTORE_V1980=1 -DDAIMOS_PBM_TERM_V1982=1 -Dmm_pin=pin_v1980 -Dmm_unpin=unpin_v1980 -Dmm_free=free_dispatch_v1985 -Dmm_alloc_aligned_noreclaim=alloc_v1980 -Dpbmd_decode_v1977=decode_v1980 -Dpbmd_verify_v1979=verify_v1980 -Dmm_pure_bitmap_finish_v1664=finish_v1980'
compile $restore_flags "$src/proc/proc_pure_ram_restore_v1391.c" -o "$work/restore.s"
if [ "${PURE_FULL_ESCROW_V1989:-0}" = 1 ]; then
    staged_flags='-DDAIMOS_PBM_PLACE_V1985=1 -DDAIMOS_PURE_FULL_V1391=1 -DDAIMOS_PBM_RESTORE_V1980=1 -DDAIMOS_PBM_TERM_V1982=1 -DDAIMOS_PBM_FULL_ESCROW_V1989=1 -Dmm_pin=pin_v1989 -Dmm_unpin=unpin_v1989 -Dmm_free=free_v1989 -Dmm_alloc_aligned_noreclaim=alloc_v1989 -Dpbmd_decode_v1977=decode_v1989 -Dpbmd_verify_v1979=verify_v1989 -Dmm_pure_bitmap_finish_v1664=finish_v1989'
    idle_flags=
    if [ "${PURE_IDLE_RECOVER_V1990:-0}" = 1 ]; then
        idle_flags=-DDAIMOS_PBM_IDLE_RECOVER_V1990=1
        staged_flags="$staged_flags $idle_flags"
    fi
    compile $staged_flags "$src/proc/proc_pure_ram_restore_v1391.c" -o "$work/restore-v1989.s"
    python3 - "$src" "$work" <<'PYLAYOUT'
from pathlib import Path
import sys
src,w=map(Path,sys.argv[1:]);s=(src/'proc/proc_pure_ram_restore_v1391.c').read_text()
a=s.index('static int\npbr_heap_ok_v1989('); b=s.index('/* Shared synchronous/deferred rollback.',a)
(w/'layout-v1989.inc').write_text(s[a:b],encoding='ascii')
PYLAYOUT
    "${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -I"$src/proc" -I"$src/core" -I"$work" $idle_flags \
        "$here/../pure-directory-recovery-v1989/test-layout-v1989.c" -o "$work/layout-v1989"
    "$work/layout-v1989"
fi
python3 - "$here" "$work" <<'PYTEST'
from pathlib import Path
import os,sys
h,w=map(Path,sys.argv[1:]);s=(h.parent/'pure-bitmap-prefix-v1978/test-native-v1978.c').read_text()
a='int main(void)';assert s.count(a)==1
import re
parts=[s.replace(a,'int old_main_v1978(void)'),(h.parent/'pure-bitmap-commit-v1979/test-native-v1979.c').read_text().replace(a,'int old_main_v1979(void)')]
parts.append('static kword_t placed_base_v1985;')
for version,group in [(1980,'full'),(1982,'terminal')]:
    p=h.parent/('pure-bitmap-%s-v%d'%(group,version))/('test-native-v%d.c'%version)
    t=p.read_text().replace(a,'int old_main_v%d(void)'%version)
    t=re.sub(r'\bBASE\b','placed_base_v1985',t)
    if version==1980:
        t=t.replace('if(image[i]!=packed_copy[i])','if(((kword_t *)placed_base_v1985)[i]!=packed_copy[i])')
    # The terminal retirement helper's neighbor is at the original APR end.
    if version==1982: t=t.replace('==placed_base_v1985+WORDS','==BASE+WORDS')
    parts.append(t)
t=(h/'test-native-v1985.c').read_text()
if os.environ.get('PURE_PREVM_V1988')=='1':
    t=t.replace(a,'int old_main_v1985(void)')+'\n'+(h.parent/'pure-directory-prevm-v1988/test-native-v1988.c').read_text()
    parts[1]=parts[1].replace('int proc_pure_recover_arm_v1902(kword_t area)','int fixture_arm_v1988(kword_t area)')
if os.environ.get('PURE_FULL_ESCROW_V1989')=='1':
    t=t.replace(a,'int old_main_v1985(void)')+'\n'+(h.parent/'pure-directory-recovery-v1989/test-native-v1989.c').read_text()
if os.environ.get('PURE_IDLE_RECOVER_V1990')=='1':
    t=t.replace(a,'int old_main_v1989(void)')+'\n'+(h.parent/'pure-directory-idle-v1990/test-native-v1990.c').read_text()
    parts[1]=parts[1].replace('int proc_pure_recover_arm_v1902(kword_t area)','int fixture_arm_v1990(kword_t area)')
    # Do not link the unused historical main bodies: the combined
    # fixture must end below the original physical test arenas.
    for i,version in enumerate((1978,1979,1980,1982)):
        parts[i]=parts[i].split('int old_main_v%d(void)'%version,1)[0]
    t=t.split('int old_main_v1985(void)',1)[0]+'\n'+t[t.index('/* Real placed bitmap FULL and explicit deferred rollback;'):]
parts.append(t)
(w/'test-v1980.c').write_text('\n'.join(parts))
PYTEST
compile -DTEST_VM_TERM_V1982=1 ${idle_flags:-} "$work/test-v1980.c" -o "$work/test-vm.s"
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
if [ "${PURE_IDLE_RECOVER_V1990:-0}" = 1 ]; then
    # Link complete service and original RAW PREFIX alongside directory.
    sed -n '/^int legacy_gate_v1978(/,$p' "$work/legacy-v1978.c" > "$work/legacy-gate-v1990.c"
    cat "$src/proc/proc_pure_service_pdp6_v1612.c" "$work/legacy-gate-v1990.c" > "$work/service-v1990.c"
    service_flags='-DDAIMOS_PBM_V1667=0 -DDAIMOS_PBM_COMMIT_V1979=1 -DDAIMOS_PBM_RESTORE_V1980=1 -DDAIMOS_PBM_FULL_ESCROW_V1989=1 -DDAIMOS_PBM_IDLE_RECOVER_V1990=1 -Dexec_image_full_bounded_v1391=load20'
    compile $service_flags "$work/service-v1990.c" -o "$work/legacy.s"
    compile -DDAIMOS_SWAPLESS_PREFIX_V1384=1 "$src/proc/proc_pure_restore_v1384.c" -o "$work/prefix-v1990.s"
else
    compile -DDAIMOS_PBM_V1667=0 -DDAIMOS_PBM_COMMIT_V1979=1 "$work/legacy-v1978.c" -o "$work/legacy.s"
fi
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
    if [ "${PURE_PREVM_V1988:-0}" = 1 ]; then
        prevm_examine="--examine diag_case_v1988 --examine diag_cases_v1988"
    else
        prevm_examine=
    fi
    if [ "${PURE_FULL_ESCROW_V1989:-0}" = 1 ]; then
        prevm_examine="--examine diag_case_v1989 --examine diag_cases_v1989 --examine diag_recover_v1989 --examine diag_bad_v1989"
    fi
    if [ "${PURE_IDLE_RECOVER_V1990:-0}" = 1 ]; then
        prevm_examine="$prevm_examine --examine diag_case_v1990 --examine diag_cases_v1990"
    fi
    "$PDP10_PREFIX/bin/p10run" --machine "$guest_machine" --mode deposit --exec-mode go \
        --start 1000 --timeout 90 --workdir "$work/$guest_name" --name "$guest_name" --expect __test_exit=0 \
        --examine diag_case_v1985 --examine diag_cases_v1985 --examine diag_cases_v1980 --examine diag_cases_v1982 --examine diag_rc_v1980 $prevm_examine \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/pi.s" "$guest_drop" \
        "$src/mm/mm_pdp6.s" "$src/mm/mm_pure_rebase_v1381.s" "${MM_LEAF:-$work/mm-place.s}" \
        "$src/proc/proc_storage_runtime_v30.s" "$work/codec.s" \
        "$src/proc/proc_pure_bitmap_walk_v1977.s" "${SERVICE_LEAF:-$work/legacy.s}" "${TEST_LEAF:-$work/test.s}" "$work/detach.s" "$work/terminal.s" "$work/prevm.s" "${VM_LEAF:-$work/vm.s}" "$src/core/ret.s" "${RESTORE_LEAF:-$work/restore.s}" \
        "$src/mm/mm_pure_bitmap_finish_v1664.s" "$src/proc/exec_image_common_v1386.s" \
        "$work/backing-v1980.s" "$work/fixed-v1980.s" "$src/core/d6block_vfs_fixed_v1458.s" \
        "$kit/tests/validation/exec-image-common-v1386/pure-media-unused-v1925.s" "$@"
}
{ printf '.equ DAIMOS_PBM_PLACE_V1985,1\n'; cat "$src/mm/mm_pure_bitmap_commit_v1979.s"; } > "$work/mm-place.s"
TEST_LEAF="$work/test-vm.s"
VM_LEAF="$work/vm-staged.s"
if [ "${PURE_IDLE_RECOVER_V1990:-0}" = 1 ]; then
    RESTORE_LEAF="$work/restore-v1989.s"
    python3 "$here/../pure-directory-idle-v1990/extract-v1990.py" "$src" "$work"
    for machine in pdp6 ka10; do
        run_guest "$machine" "idle-$machine-v1990" "$work/drop.s" "$work/idle-v1990.s" "$work/prefix-v1990.s" "$src/mm/mm_pure_expand_v1384.s"
        grep -A1 -E 'EXAMINE__ diag_(cases|recover)_v1989|EXAMINE__ diag_cases_v1990' "$work/idle-$machine-v1990/idle-$machine-v1990.out"
    done
    python3 "$here/../pure-directory-idle-v1990/mutate-v1990.py" "$src" "$work"
    for mutant in no-arm no-route clobber-cursor raw-to-bitmap rearm-every-retry early-retry no-backoff scan-hold; do
        SERVICE_LEAF="$work/legacy.s"
        RESTORE_LEAF="$work/restore-v1989.s"
        idle_leaf="$work/idle-v1990.s"
        case "$mutant" in
            no-arm|no-route|clobber-cursor|raw-to-bitmap)
                compile $service_flags "$work/$mutant.c" -o "$work/$mutant.s"
                SERVICE_LEAF="$work/$mutant.s";;
            rearm-every-retry)
                compile $staged_flags "$work/$mutant.c" -o "$work/$mutant.s"
                RESTORE_LEAF="$work/$mutant.s";;
            *) idle_leaf="$work/$mutant.s";;
        esac
        if run_guest pdp6 "$mutant-v1990" "$work/drop.s" "$idle_leaf" "$work/prefix-v1990.s" "$src/mm/mm_pure_expand_v1384.s" >"$work/$mutant.log" 2>&1; then
            echo "FAIL: $mutant accepted"; exit 1
        fi
        grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
        echo "PASS: $mutant rejected"
    done
    exit 0
fi
if [ "${PURE_FULL_ESCROW_V1989:-0}" = 1 ]; then
    RESTORE_LEAF="$work/restore-v1989.s"
    for machine in pdp6 ka10; do
        run_guest "$machine" "recovery-$machine-v1989" "$work/drop.s"
        grep -A1 -E 'EXAMINE__ diag_(cases|recover)_v1989' "$work/recovery-$machine-v1989/recovery-$machine-v1989.out"
    done
    python3 "$here/../pure-directory-recovery-v1989/mutate-v1989.py" "$src/proc/proc_pure_ram_restore_v1391.c" "$work"
    for mutant in lose-length lose-current-brk retain-authority no-pair-proof no-free-proof no-source-proof no-version-tag no-post-identity no-heap-proof; do
        compile $staged_flags "$work/$mutant.c" -o "$work/$mutant.s"
        RESTORE_LEAF="$work/$mutant.s"
        if run_guest pdp6 "$mutant-v1989" "$work/drop.s" >"$work/$mutant.log" 2>&1; then
            echo "FAIL: $mutant accepted"; exit 1
        fi
        grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
        echo "PASS: $mutant rejected"
    done
    exit 0
fi
if [ "${PURE_PREVM_V1988:-0}" = 1 ]; then
    # Link complete actual finalizer, reaper, parent and u-area guards.
    python3 "$here/../pure-directory-prevm-v1988/extract-v1988.py" "$src" "$work"
    for machine in pdp6 ka10; do
        run_guest "$machine" "prevm-$machine-v1988" "$work/drop.s" "$work/finalizer-v1988.s"
        grep -A1 'EXAMINE__ diag_cases_v1988' "$work/prevm-$machine-v1988/prevm-$machine-v1988.out"
    done
    python3 "$here/../pure-directory-prevm-v1988/mutate-native-v1988.py" "$work/finalizer-v1988.s"
    for mutant in ignore-vm-refusal no-prevm no-span-escrow no-backoff no-stack-guard no-user-pc no-wait-guard no-file-guard; do
        if run_guest pdp6 "$mutant-v1988" "$work/drop.s" "$work/$mutant.s" >"$work/$mutant.log" 2>&1; then
            echo "FAIL: $mutant accepted"; exit 1
        fi
        grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
        echo "PASS: $mutant rejected"
    done
    exit 0
fi
for machine in pdp6 ka10; do
    run_guest "$machine" "placement-$machine-v1985" "$work/drop.s"
    grep -A1 'EXAMINE__ diag_cases_v1985' "$work/placement-$machine-v1985/placement-$machine-v1985.out"
done
# Actual negative controls: each must reach a native assertion.
python3 - "$src" "$work" <<'PYMUT'
from pathlib import Path
import sys
s,w=map(Path,sys.argv[1:]);a=(w/'mm-place.s').read_text();c=(s/'proc/proc_pure_ram_v1381.c').read_text()
variants=[
 ('no-copy',a,'        blt     4,(7)\n','        jfcl\n'),
 ('no-overlap-proof',a,'        camge   4,7                    ; every intervening extent above target\n        jrst    mbc_bad_v1979','        jfcl'),
 ('no-shift',a,'        jrst    mbc_place_shift_one_v1985\n','        jrst    mbc_place_store_v1985\n'),
 ('no-target-alignment',a,'        trne    15,0177\n        jrst    mbc_bad_v1979','        jfcl'),
 ('trust-place-reply',c,'if (proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS, target, encoded, 0U)) {','if (rc == MM_OK) {'),
 ('no-target-escrow',c,'u[PROC_FINALIZE_OFFSET] = PROC_PURE_BITMAP_PLACE_V1985(target, encoded);','u[PROC_FINALIZE_OFFSET] = 0UL;'),
]
for name,source,old,new in variants:
    assert source.count(old)==1,(name,source.count(old))
    (w/(name+('.c' if source==c else '.s'))).write_text(source.replace(old,new,1))
PYMUT
for mutant in no-copy no-overlap-proof no-shift no-target-alignment trust-place-reply no-target-escrow; do
    drop="$work/drop.s"
    MM_LEAF="$work/mm-place.s"
    if [ -f "$work/$mutant.c" ]; then
        compile $flags $faults "$work/$mutant.c" -o "$work/$mutant.s"
        drop="$work/$mutant.s"
    else
        MM_LEAF="$work/$mutant.s"
    fi
    if run_guest pdp6 "$mutant-v1985" "$drop" >"$work/$mutant.log" 2>&1; then
        echo "FAIL: $mutant accepted"; exit 1
    fi
    grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
    echo "PASS: $mutant rejected"
done
