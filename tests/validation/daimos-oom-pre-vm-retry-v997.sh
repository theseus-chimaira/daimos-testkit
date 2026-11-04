# Booted 256K regression: reject first VM destroy, retry from slot zero.
# The second injection rejects the first u-area MM free; no production hooks.
# v1098 fixed an actual unarmed retry-clock bug exposed by this diagnostic:
# EXIT prepublished FINALIZE+PREVM without yet arming proc_finish_last_tick.
# The repaired full-system guest now verifies VM and u-area recovery,
# deferred TERM, descendant EXIT/CHLD, live provider lease and bystander.
# KEEP_TEST=1 preserves the disposable image and counters for diagnosis.
# All fault hooks and witnesses are confined to a disposable kernel copy.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-oom-pre-vm-retry-v997.XXXXXX")
integrated=${DAIMOS_V1103_MULTISTAGE:-0}
case "$integrated" in 0|1) ;; *) echo 'v1103: invalid stage selector' >&2; exit 2 ;; esac
physical_vm=${DAIMOS_V1106_PHYSICAL_VM:-0}
case "$physical_vm" in 0|1) ;; *) echo 'v1106: invalid VM selector' >&2; exit 2 ;; esac
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
printf 'v924: isolated work %s\n' "$work"
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel" "$integrated" "$physical_vm" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
integrated = sys.argv[2] == '1'
physical_vm = sys.argv[3] == '1'
def patch(rel, old, new):
    path = root / rel
    source = path.read_text()
    if source.count(old) != 1:
        raise SystemExit('v924: nonunique kernel injection anchor ' + rel)
    path.write_text(source.replace(old, new, 1))

# The FS serialized gateway is a real production code path; the test
# suspends slot 3 after it acquires the genuine lease, before dispatch.
patch('fs/fs_mres.s',
      '''        sub     17,kconst_7_7
        ; The missing-service trampoline already returns -1 normally.''',
      '''        sub     17,kconst_7_7
        move    0,proc_current_slot
        caie    0,3                   ; child H, slot 3 only
        jrst    daimos_test_fs_normal_v924
        skipn   daimos_test_armed_v924
        jrst    daimos_test_fs_normal_v924
        aos     daimos_test_enter_v924
        move    0,fs_provider_ready
        movem   0,daimos_test_held_lease_v924
        hlrz    0,fs_provider_ready
        caie    0,4                   ; slot 3 + 1
        setom   daimos_test_error_v924
        ; Suspend on a private, never-signaled event with lease held.
        ; There is no forced unlock, timeout, or provider transaction.
daimos_test_hold_loop_v924:
        movei   1,daimos_test_hold_event_v924
        pushj   17,proc_wait_event
        jrst    daimos_test_hold_loop_v924
daimos_test_fs_normal_v924:
        ; The missing-service trampoline already returns -1 normally.''')
patch('fs/fs_mres.s',
      '''fs_provider_lock_sleep_v915:
        movei   1,fs_provider_wait_event_v917''',
      '''fs_provider_lock_sleep_v915:
        move    0,proc_current_slot
        caie    0,4                   ; child W, slot 4 only
        jrst    daimos_test_wait_other_v924
        skipn   daimos_test_armed_v924
        jrst    daimos_test_wait_other_v924
        aos     daimos_test_wait_v924
        move    0,fs_provider_ready
        movem   0,daimos_test_wait_lease_v924
        hlrz    0,fs_provider_ready
        caie    0,4
        setom   daimos_test_error_v924
daimos_test_wait_other_v924:
        movei   1,fs_provider_wait_event_v917''')
p = root / 'fs/fs_mres.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_armed_v924
daimos_test_armed_v924: .block 1
        .globl daimos_test_enter_v924
daimos_test_enter_v924: .block 1
        .globl daimos_test_wait_v924
daimos_test_wait_v924: .block 1
        .globl daimos_test_held_lease_v924
daimos_test_held_lease_v924: .block 1
        .globl daimos_test_wait_lease_v924
daimos_test_wait_lease_v924: .block 1
        .globl daimos_test_final_lease_v924
daimos_test_final_lease_v924: .block 1
        .globl daimos_test_hold_event_v924
daimos_test_hold_event_v924: .block 1
        .globl daimos_test_bystander_v924
daimos_test_bystander_v924: .block 1
        .globl daimos_test_error_v924
daimos_test_error_v924: .block 1
''')
# Arm only after INIT launches all four initial child processes.
# An unrelated running child proves scheduler progress during both waits.
patch('proc/proc_pdp6.s',
      '''proc_sleep_ticks:
        hrrz    1,1''',
      '''proc_sleep_ticks:
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_sleep_other_v924
        setom   daimos_test_armed_v924
daimos_test_sleep_other_v924:
        caie    4,2
        jrst    daimos_test_sleep_normal_v924
        skipn   daimos_test_enter_v924
        jrst    daimos_test_sleep_normal_v924
        skipn   daimos_test_wait_v924
        jrst    daimos_test_sleep_normal_v924
        aos     daimos_test_bystander_v924
daimos_test_sleep_normal_v924:
        hrrz    1,1''')
# Count real fatal-event refusal for suspended provider continuations.
patch('proc/proc_pdp6.s',
      '''        move    1,2(012)
        tlne    1,PROC_WAIT_LH_MASK
        jrst    proc_event_fatal_other_defer_term_v926''',
      '''        move    1,2(012)
        tlne    1,PROC_WAIT_LH_MASK
        jrst    daimos_test_fatal_refused_v924
        jrst    daimos_test_fatal_normal_v924
daimos_test_fatal_refused_v924:
        aos     daimos_test_fatal_count_v924
        move    0,2(012)
        and     0,[060000,,0]
        camn    0,[040000,,0]         ; exactly WAIT_CHILD, not INTR
        aos     daimos_test_child_refused_v924
        jrst    proc_event_fatal_other_defer_term_v926
daimos_test_fatal_normal_v924:''')
# Locate slot-6 process finalization and the failure branch. The exiting
# current slot is cleared by proc_exit_finish before this entry, so inspect
# the slot argument rather than proc_current_slot.
patch('proc/proc_pdp6.s',
      """proc_finish_common_v932:
        add     17,kconst_7_7""",
      """proc_finish_common_v932:
        caie    1,6
        jrst    daimos_test_finish_other_v931
        aos     daimos_test_finish_v931
daimos_test_finish_other_v931:
        add     17,kconst_7_7""")
patch('proc/proc_pdp6.s',
      """proc_finish_fail:
        seto    1,""",
      """proc_finish_fail:
        move    0,10
        caie    0,6
        jrst    daimos_test_fail_other_v931
        aos     daimos_test_fail_v931
daimos_test_fail_other_v931:
        seto    1,""")
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + """
        .bss
        .globl daimos_test_finish_v931
daimos_test_finish_v931: .block 1
        .globl daimos_test_fail_v931
daimos_test_fail_v931: .block 1
""")
# Refuse exactly two closes of one real FILE descriptor. The target
# descriptor entry remains nonzero on both refusals. Other descriptors
# close normally through the unchanged production path.
patch('fs/file_runtime.s',
      """file_close_entry_v865:
        push    17,010""",
      """file_close_entry_v865:
        push    17,2
        move    2,proc_current_slot
        caie    2,5
        jrst    daimos_test_entry_normal_v936
        skipn   daimos_test_entry_addr_v936
        movem   1,daimos_test_entry_addr_v936
        move    2,daimos_test_entry_addr_v936
        came    1,2
        jrst    daimos_test_entry_normal_v936
        skipn   (1)
        setom   daimos_test_entry_error_v936
        aos     daimos_test_close_calls_v936
        move    2,daimos_test_close_calls_v936
        caig    2,2
        jrst    daimos_test_entry_refuse_v936
daimos_test_entry_normal_v936:
        pop     17,2
        push    17,010
        jrst    file_close_entry_cont_v936
daimos_test_entry_refuse_v936:
        aos     daimos_test_close_refusals_v936
        pop     17,2
        seto    1,
        popj    17,
file_close_entry_cont_v936:""")
p = root / 'fs/file_runtime.s'
p.write_text(p.read_text() + """
        .bss
        .globl daimos_test_close_calls_v936
daimos_test_close_calls_v936: .block 1
        .globl daimos_test_close_refusals_v936
daimos_test_close_refusals_v936: .block 1
        .globl daimos_test_entry_addr_v936
daimos_test_entry_addr_v936: .block 1
        .globl daimos_test_entry_error_v936
daimos_test_entry_error_v936: .block 1
""")
# Count real VM and u-area release calls for the dying WAIT_CHILD owner.
# Both routines receive the owner slot in AC2 and AC1, respectively.
patch('proc/vm_pdp6.s',
      """vm_space_destroy:
        push    17,1""",
      """vm_space_destroy:
        caie    2,5
        jrst    daimos_test_vm_other_v937
        aos     daimos_test_vm_calls_v937
        move    0,daimos_test_vm_calls_v937
        caie    0,1
        jrst    daimos_test_vm_other_v937
        ; Synthetic first VM rejection before any MM deletion.
        ; The live process has already left its private kernel stack.
        seto    1,
        popj    17,
daimos_test_vm_other_v937:
        push    17,1""")
p = root / 'proc/vm_pdp6.s'
p.write_text(p.read_text() + """
        .bss
        .globl daimos_test_vm_calls_v937
daimos_test_vm_calls_v937: .block 1
""")
if physical_vm:
    # Use the *actual* process VM extent and the original MM allocator.
    # A physical pin on the first fatal VM attempt must yield -5, not a
    # fabricated failure before the VM cleanup path. Slot-0's second
    # attempt unpins the same base, allowing one true MM deletion and
    # one real swap-detach/VM_NONE publication.
    patch('proc/vm_pdp6.s',
          '''        caie    0,1
        jrst    daimos_test_vm_other_v937
        ; Synthetic first VM rejection before any MM deletion.
        ; The live process has already left its private kernel stack.
        seto    1,
        popj    17,
daimos_test_vm_other_v937:''',
          '''        caie    0,1
        jrst    daimos_test_vm_second_v1106
        push    17,1
        push    17,2
        hrrz    1,1(1)               ; live VM base, not u-area
        movem   1,daimos_test_vm_base_v1106
        jumpe   1,daimos_test_vm_pin_bad_v1106
        pushj   17,mm_pin
        jumpn   1,daimos_test_vm_pin_bad_v1106
        aos     daimos_test_vm_pins_v1106
        jrst    daimos_test_vm_restore_v1106
daimos_test_vm_pin_bad_v1106:
        aos     daimos_test_vm_errors_v1106
        jrst    daimos_test_vm_restore_v1106
daimos_test_vm_second_v1106:
        caie    0,2
        jrst    daimos_test_vm_other_v937
        push    17,1
        push    17,2
        move    1,daimos_test_vm_base_v1106
        jumpe   1,daimos_test_vm_unpin_bad_v1106
        pushj   17,mm_unpin
        jumpn   1,daimos_test_vm_unpin_bad_v1106
        aos     daimos_test_vm_unpins_v1106
        jrst    daimos_test_vm_restore_v1106
daimos_test_vm_unpin_bad_v1106:
        aos     daimos_test_vm_errors_v1106
daimos_test_vm_restore_v1106:
        pop     17,2
        pop     17,1
        jrst    daimos_test_vm_other_v937
daimos_test_vm_other_v937:''')
    patch('proc/vm_pdp6.s',
          '''vm_space_destroy_detach:
        move    1,(17)''',
          '''vm_space_destroy_detach:
        move    0,(17)
        caie    0,5
        jrst    daimos_test_vm_detach_other_v1106
        aos     daimos_test_vm_detach_v1106
daimos_test_vm_detach_other_v1106:
        move    1,(17)''')
    p = root / 'proc/vm_pdp6.s'
    p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_vm_base_v1106
daimos_test_vm_base_v1106: .block 1
        .globl daimos_test_vm_pins_v1106
daimos_test_vm_pins_v1106: .block 1
        .globl daimos_test_vm_unpins_v1106
daimos_test_vm_unpins_v1106: .block 1
        .globl daimos_test_vm_errors_v1106
daimos_test_vm_errors_v1106: .block 1
        .globl daimos_test_vm_detach_v1106
daimos_test_vm_detach_v1106: .block 1
''')
patch('proc/proc_pdp6.s',
      """proc_uarea_release:
        hrrz    3,(2)""",
      """proc_uarea_release:
        caie    1,5
        jrst    daimos_test_uarea_other_v937
        aos     daimos_test_uarea_calls_v937
daimos_test_uarea_other_v937:
        hrrz    3,(2)""")
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + """
        .bss
        .globl daimos_test_uarea_calls_v937
daimos_test_uarea_calls_v937: .block 1
""")
# Reject a real MM free at the allocator boundary, not at the caller.
# Type 3 is dynamic kernel memory; slot 5 uses owner 01000+5 (octal).
# Only the first matching call is refused; all others execute unchanged.
patch('mm/mm_pdp6.s',
      """mm_free:
        move    5,1""",
      """mm_free:
        caie    2,3
        jrst    daimos_test_mm_other_v939
        caie    3,01005
        jrst    daimos_test_mm_other_v939
        aos     daimos_test_mm_calls_v939
        move    0,daimos_test_mm_calls_v939
        caie    0,1
        jrst    daimos_test_mm_other_v939
        aos     daimos_test_mm_refusals_v939
        movni   1,5
        popj    17,
daimos_test_mm_other_v939:
        move    5,1""")
p = root / 'mm/mm_pdp6.s'
p.write_text(p.read_text() + """
        .bss
        .globl daimos_test_mm_calls_v939
daimos_test_mm_calls_v939: .block 1
        .globl daimos_test_mm_refusals_v939
daimos_test_mm_refusals_v939: .block 1
""")
if physical_vm:
    patch('mm/mm_pdp6.s',
          '''mm_free:
        caie    2,3''',
          '''mm_free:
        caie    2,1                   ; MM_TYPE_PROCESS
        jrst    daimos_test_vm_mm_other_v1106
        caie    3,5                   ; exact dying slot-5 VM owner
        jrst    daimos_test_vm_mm_other_v1106
        move    0,daimos_test_vm_base_v1106
        came    0,1
        jrst    daimos_test_vm_mm_other_v1106
        aos     daimos_test_vm_mm_calls_v1106
daimos_test_vm_mm_other_v1106:
        caie    2,3''')
    patch('mm/mm_pdp6.s',
          '''mm_free_busy:
        movni   1,5''',
          '''mm_free_busy:
        move    4,daimos_test_vm_base_v1106
        camn    4,5
        aos     daimos_test_vm_mm_busy_v1106
        movni   1,5''')
    patch('mm/mm_pdp6.s',
          '''        pushj   17,mm_delete
        setz    1,
        popj    17,
mm_free_inval:''',
          '''        move    4,daimos_test_vm_base_v1106
        camn    4,5
        aos     daimos_test_vm_mm_frees_v1106
        pushj   17,mm_delete
        setz    1,
        popj    17,
mm_free_inval:''')
    p = root / 'mm/mm_pdp6.s'
    p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_vm_mm_calls_v1106
daimos_test_vm_mm_calls_v1106: .block 1
        .globl daimos_test_vm_mm_busy_v1106
daimos_test_vm_mm_busy_v1106: .block 1
        .globl daimos_test_vm_mm_frees_v1106
daimos_test_vm_mm_frees_v1106: .block 1
''')
if integrated:
    # The final C-child PIPE read descriptor owns an MM dynamic extent
    # with the normal PIPE owner 5. Only the first physical free is
    # rejected. All later requests execute the unmodified mm_free.
    patch('mm/mm_pdp6.s',
          '''mm_free:
        caie    2,3''',
          '''mm_free:
        caie    2,3
        jrst    daimos_test_pipe_other_v1103
        caie    3,5
        jrst    daimos_test_pipe_other_v1103
        move    0,proc_current_slot
        caie    0,5
        jrst    daimos_test_pipe_other_v1103
        skipn   daimos_test_pipe_base_v1103
        movem   1,daimos_test_pipe_base_v1103
        move    0,daimos_test_pipe_base_v1103
        came    0,1
        setom   daimos_test_pipe_error_v1103
        move    0,3(1)               ; no reader, one writer
        camn    0,[0,,1]
        jrst    daimos_test_pipe_refs_ok_v1103
        setom   daimos_test_pipe_error_v1103
daimos_test_pipe_refs_ok_v1103:
        aos     daimos_test_pipe_calls_v1103
        move    0,daimos_test_pipe_calls_v1103
        caie    0,1
        jrst    daimos_test_pipe_other_v1103
        aos     daimos_test_pipe_refusals_v1103
        movni   1,5
        popj    17,
daimos_test_pipe_other_v1103:
        caie    2,3''')
    p = root / 'mm/mm_pdp6.s'
    p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_pipe_base_v1103
daimos_test_pipe_base_v1103: .block 1
        .globl daimos_test_pipe_calls_v1103
daimos_test_pipe_calls_v1103: .block 1
        .globl daimos_test_pipe_refusals_v1103
daimos_test_pipe_refusals_v1103: .block 1
        .globl daimos_test_pipe_error_v1103
daimos_test_pipe_error_v1103: .block 1
''')
    # This is a deliberate HUP stage refusal, not physical TTY HUP.
    # Real member delivery and partial retry are covered by v907.
    patch('proc/proc_pdp6.s',
          '''proc_session_teardown:
        push    17,010''',
          '''proc_session_teardown:
        move    0,proc_current_slot
        caie    0,5
        jrst    daimos_test_hup_normal_v1103
        aos     daimos_test_hup_calls_v1103
        move    0,daimos_test_hup_calls_v1103
        caie    0,1
        jrst    daimos_test_hup_normal_v1103
        aos     daimos_test_hup_refusals_v1103
        seto    1,
        popj    17,
daimos_test_hup_normal_v1103:
        push    17,010''')
    p = root / 'proc/proc_pdp6.s'
    p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_hup_calls_v1103
daimos_test_hup_calls_v1103: .block 1
        .globl daimos_test_hup_refusals_v1103
daimos_test_hup_refusals_v1103: .block 1
''')
# Stage witnesses reside only in the disposable kernel.
patch('proc/proc_pdp6.s',
      '''proc_notify_parent:
        jumpe   1,proc_notify_parent_done''',
      '''proc_notify_parent:
        caie    1,5
        jrst    daimos_test_notify_other_v929
        aos     daimos_test_chld_v929
daimos_test_notify_other_v929:
        jumpe   1,proc_notify_parent_done''')
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_chld_v929
daimos_test_chld_v929: .block 1
''')
patch('proc/mach_user_pdp6.s',
      '''proc_deferred_term_check_v926:
        push 17,2''',
      '''proc_deferred_term_check_v926:
        push 17,2
        move 2,proc_current_slot
        caie 2,5
        jrst daimos_test_owner_other_v929
        aos daimos_test_owner_v929
daimos_test_owner_other_v929:
        pop 17,2
        push 17,2''')
p = root / 'proc/mach_user_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_owner_v929
daimos_test_owner_v929: .block 1
''')
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_fatal_count_v924
daimos_test_fatal_count_v924: .block 1
        .globl daimos_test_child_refused_v924
daimos_test_child_refused_v924: .block 1
''')
patch('proc/proc_pdp6.s',
      '''proc_exit_current:
        move    3,1''',
      '''proc_exit_current:
        move    4,proc_current_slot
        caie    4,6
        jrst    daimos_test_exit_not6_v930
        aos     daimos_test_exit_v930
daimos_test_exit_not6_v930:
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_exit_other_v924
        move    4,fs_provider_ready
        movem   4,daimos_test_final_lease_v924
        halt
        jrst    .-1
daimos_test_exit_other_v924:
        move    3,1''')
p = root / 'proc/proc_pdp6.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_exit_v930
daimos_test_exit_v930: .block 1
''')
PY
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
incs=""
for d in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
extra_cflags=''
if [ "$integrated" = 1 ]; then
    extra_cflags=-DDAIMOS_V1103_MULTISTAGE=1
fi
# shellcheck disable=SC2086
"$cc" -std=c89 -Os $extra_cflags $incs -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-mixed-fatal-retry-v978.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
build="$work/build/system/boot/pdp6"
printf 'v924: assembling disposable 256K PDP-6 image\n'
PATH="$PDP10_PREFIX/bin:$PATH" "${MAKE:-make}" \
    -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    >"$work/build.log" 2>&1 || {
        tail -90 "$work/build.log" >&2
        echo "v924: image build failed: $work" >&2
        exit 1
    }
for name in mm_calls mm_refusals vm_calls uarea_calls close_calls close_refusals entry_error chld owner exit finish fail armed enter wait held_lease wait_lease final_lease \
    hold_event bystander error; do
    case "$name" in
        mm_calls|mm_refusals) sym="daimos_test_${name}_v939" ;;
        vm_calls|uarea_calls) sym="daimos_test_${name}_v937" ;;
        close_calls|close_refusals) sym="daimos_test_${name}_v936" ;;
        entry_error) sym="daimos_test_entry_error_v936" ;;
        chld|owner) sym="daimos_test_${name}_v929" ;;
        exit) sym="daimos_test_exit_v930" ;;
        finish|fail) sym="daimos_test_${name}_v931" ;;
        *) sym="daimos_test_${name}_v924" ;;
    esac
    addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
    test -n "$addr" || { echo "v924: missing $sym" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
if [ "$integrated" = 1 ]; then
    for name in pipe_base pipe_calls pipe_refusals pipe_error hup_calls hup_refusals; do
        sym="daimos_test_${name}_v1103"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1103: missing $sym" >&2; exit 1; }
        printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$physical_vm" = 1 ]; then
    for name in base pins unpins errors detach mm_calls mm_busy mm_frees; do
        sym="daimos_test_vm_${name}_v1106"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
        test -n "$addr" || { echo "v1106: missing $sym" >&2; exit 1; }
        printf 'vm_%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
sym=daimos_test_fatal_count_v924
addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
test -n "$addr" || { echo "v924: missing fatal counter" >&2; exit 1; }
printf '%s %s\n' fatal_count "$addr" >> "$work/addresses"
sym=daimos_test_child_refused_v924
addr=$(awk -v s="$sym" '$1 == s {print $2}' "$build/kcore.map")
test -n "$addr" || { echo "v924: missing child refusal counter" >&2; exit 1; }
printf '%s %s\n' child_refused "$addr" >> "$work/addresses"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' \
    "$build/boot.ini"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$build/boot.ini"
done < "$work/addresses"
printf 'exit\n' >> "$build/boot.ini"
printf 'v997: injected VM and u-area release retries with held provider\n'
set +e
(cd "$build"; TERM=dumb timeout -k 2s 90s stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) >"$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -90 "$work/simh.out" >&2
    echo "v924: simulator failed ($rc): $work" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" "$integrated" "$physical_vm" <<'PY'
from pathlib import Path
import re
import sys
out = Path(sys.argv[2]).read_text(errors='replace')
integrated = sys.argv[3] == '1'
physical_vm = sys.argv[4] == '1'
seen = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    name, addr = line.split()
    values = re.findall(r'(?im)^\s*0*' + re.escape(addr.lstrip('0')) +
                        r'\s*:\s*([0-7]+)\b', out)
    if not values:
        raise SystemExit('v924: missing MM/FS sample '+name+'\n'+out[-1700:])
    seen[name] = int(values[-1],8)
if seen['mm_calls'] != 2 or seen['mm_refusals'] != 1 or seen['vm_calls'] != 2 or seen['uarea_calls'] != 2 or seen['entry_error'] != 0 or seen['close_calls'] != 3 or seen['close_refusals'] != 2 or seen['finish'] < 1 or seen['fail'] != 0 or seen['exit'] < 1 or seen['chld'] < 1 or seen['owner'] < 1 or \
        seen['armed'] == 0 or seen['enter'] < 1 or seen['wait'] < 1 or \
        seen['hold_event'] != 0 or seen['error'] != 0 or \
        seen['held_lease'] != (4 << 18) or \
        seen['wait_lease'] != (4 << 18) or \
        seen['final_lease'] != (4 << 18) or \
        seen['bystander'] < 1 or seen['fatal_count'] != 3 or \
        seen['child_refused'] != 1:
    raise SystemExit('v924: provider ownership/waiter/scheduler violation: '+
                     str(seen)+'\n'+out[-2400:])
if 'HALT' not in out or '<HWCD' not in out or 'H' not in out or \
        'W' not in out or 'C' not in out or \
        'D' not in out or 'P' not in out or \
        re.search(r'S{3,}', out) is None or '!' in out:
    raise SystemExit('v924: guest markers/independent work failed: '+
                     out[-2000:])
if integrated:
    if not seen['pipe_base'] or seen['pipe_calls'] != 2 or \
            seen['pipe_refusals'] != 1 or seen['pipe_error'] != 0 or \
            seen['hup_calls'] != 2 or seen['hup_refusals'] != 1:
        raise SystemExit('v1103: PIPE/HUP stage ownership/count violation: '+
                         str(seen)+'\n'+out[-2300:])
    print('v1103: real PIPE MM_BUSY, injected HUP refusal, VM and u-area '
          'retries, held provider, CHLD and bystander PASS:', seen)
if physical_vm:
    for name, expected in dict(vm_pins=1, vm_unpins=1,
                               vm_mm_calls=2, vm_mm_busy=1,
                               vm_mm_frees=1, vm_detach=1,
                               vm_errors=0).items():
        if seen[name] != expected:
            raise SystemExit('v1106: '+name+'='+str(seen[name])+
                             ' expected '+str(expected)+'\n'+out[-2500:])
    if not seen['vm_base']:
        raise SystemExit('v1106: no real process VM base recorded')
    print('v1106: physical VM pin/MM_BUSY, actual MM release and '
          'one swap detach, uarea retry, foreign provider, CHLD, '
          'bystander PASS:', seen)
print('v997: pre-VM refusal then post-VM u-area retry PASS:', seen)
PY
