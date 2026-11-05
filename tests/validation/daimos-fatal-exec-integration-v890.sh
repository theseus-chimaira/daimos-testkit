#!/bin/sh
# v890 full-system PDP-6: real post-destroy EXEC fatal and VFS refusal.
# Production sources are NEVER modified; all probes live in a copied kernel.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-fatal-exec-integration-v890.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; fi' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
nested=${DAIMOS_V1126_NESTED:-0}
case "$nested" in 0|1) ;; *) echo 'v1126: invalid nested mode' >&2; exit 2 ;; esac
physical_uarea=${DAIMOS_V1142_PHYSICAL_UAREA:-0}
case "$physical_uarea" in 0|1) ;; *) echo 'v1142: invalid u-area fault mode' >&2; exit 2 ;; esac
e10_provider=${DAIMOS_V1157_PROVIDER:-0}
case "$e10_provider" in 0|1) ;; *) echo 'v1157: invalid provider mode' >&2; exit 2 ;; esac
if [ "$e10_provider" = 1 ] && { [ "$physical_uarea" != 1 ] ||
    [ "${DAIMOS_V1126_NESTED:-0}" != 1 ]; }; then
    echo 'v1157: provider mode requires nested APR/EXEC/RUN and real u-area' >&2
    exit 2
fi
if [ "$physical_uarea" = 1 ] && [ "$nested" != 1 ]; then
    echo 'v1142: physical u-area fault requires nested APR/EXEC/RUN' >&2
    exit 2
fi
diagnostic=${DAIMOS_V1126_DIAG:-0}
case "$diagnostic" in 0|1) ;; *) echo 'v1126: invalid diagnostic mode' >&2; exit 2 ;; esac
dual_timer=${DAIMOS_V1127_DUAL_TIMER:-0}
case "$dual_timer" in 0|1) ;; *) echo 'v1127: invalid timer diagnostic' >&2; exit 2 ;; esac
stage_probe=${DAIMOS_V1128_STAGE:-0}
case "$stage_probe" in 0|1) ;; *) echo 'v1128: invalid finalizer diagnostic' >&2; exit 2 ;; esac
discard_probe=${DAIMOS_V1131_DISCARD_TRACE:-0}
case "$discard_probe" in 0|1) ;; *) echo 'v1131: invalid discard diagnostic' >&2; exit 2 ;; esac
layout_probe=${DAIMOS_V1132_LAYOUT_ONLY:-0}
case "$layout_probe" in 0|1) ;; *) echo 'v1132: invalid layout diagnostic' >&2; exit 2 ;; esac
run_probe=${DAIMOS_V1133_RUN_ONLY:-0}
case "$run_probe" in 0|1) ;; *) echo 'v1133: invalid RUN-only diagnostic' >&2; exit 2 ;; esac
text_pad=${DAIMOS_V1134_TEXT_PLACEMENT:-0}
case "$text_pad" in 0|1) ;; *) echo 'v1134: invalid text-placement diagnostic' >&2; exit 2 ;; esac
return_snapshot=${DAIMOS_V1135_RETURN_SNAPSHOT:-0}
case "$return_snapshot" in 0|1) ;; *) echo 'v1135: invalid return-snapshot diagnostic' >&2; exit 2 ;; esac
break_trace=${DAIMOS_V1136_BREAK_TRACE:-0}
case "$break_trace" in 0|1) ;; *) echo 'v1136: invalid breakpoint diagnostic' >&2; exit 2 ;; esac
sequential_trace=${DAIMOS_V1137_SEQUENTIAL:-0}
case "$sequential_trace" in 0|1) ;; *) echo 'v1137: invalid sequential diagnostic' >&2; exit 2 ;; esac
discard_breaks=${DAIMOS_V1138_DISCARD_BREAKS:-0}
case "$discard_breaks" in 0|1) ;; *) echo 'v1138: invalid discard breakpoint mode' >&2; exit 2 ;; esac
release_breaks=${DAIMOS_V1139_RELEASE_BREAKS:-0}
case "$release_breaks" in 0|1) ;; *) echo 'v1139: invalid release breakpoint mode' >&2; exit 2 ;; esac
if [ "$release_breaks" = 1 ] && [ "$discard_breaks" != 1 ]; then
    echo 'v1139: release breakpoints require discard breakpoints' >&2
    exit 2
fi
if [ "$discard_breaks" = 1 ] && [ "$sequential_trace" = 1 ]; then
    echo 'v1138: cannot combine sequential and stage breakpoints' >&2
    exit 2
fi
if [ "$sequential_trace" = 1 ]; then break_trace=1; fi
if [ "$discard_breaks" = 1 ]; then break_trace=1; fi
if [ "$break_trace" = 1 ] && { [ "$nested" != 1 ] ||
    [ "$return_snapshot" = 1 ] || [ "$text_pad" = 1 ] ||
    [ "$discard_probe" = 1 ] || [ "$layout_probe" = 1 ] ||
    [ "$run_probe" = 1 ]; }; then
    echo 'v1136: breakpoints require otherwise uninstrumented nested guest' >&2
    exit 2
fi
if [ "$return_snapshot" = 1 ] && { [ "$nested" != 1 ] ||
    [ "$text_pad" = 1 ] || [ "$discard_probe" = 1 ] ||
    [ "$layout_probe" = 1 ] || [ "$run_probe" = 1 ]; }; then
    echo 'v1135: snapshot requires otherwise uninstrumented nested guest' >&2
    exit 2
fi
if [ "$text_pad" = 1 ] && { [ "$nested" != 1 ] ||
    [ "$discard_probe" = 1 ] || [ "$layout_probe" = 1 ] ||
    [ "$run_probe" = 1 ]; }; then
    echo 'v1134: text-placement probe requires otherwise uninstrumented nested guest' >&2
    exit 2
fi
if [ "$run_probe" = 1 ] && { [ "$nested" != 1 ] ||
    [ "$discard_probe" = 1 ] || [ "$layout_probe" = 1 ]; }; then
    echo 'v1133: RUN-only probe requires otherwise uninstrumented nested guest' >&2
    exit 2
fi
if [ "$layout_probe" = 1 ] && { [ "$nested" != 1 ] || [ "$discard_probe" = 1 ]; }; then
    echo 'v1132: layout mode requires uninstrumented nested guest' >&2
    exit 2
fi
if [ "$discard_probe" = 1 ] && [ "$nested" != 1 ]; then
    echo 'v1131: discard probe requires nested APR/EXEC/RUN guest' >&2
    exit 2
fi
if [ "$stage_probe" = 1 ] && [ "$dual_timer" != 1 ]; then
    echo 'v1128: finalizer probe requires dual timer diagnostic' >&2
    exit 2
fi
if [ "$dual_timer" = 1 ] && [ "$diagnostic" != 1 ]; then
    echo 'v1127: dual timer samples require diagnostic mode' >&2
    exit 2
fi
mkdir -p "$work/source/system" "$work/user"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 - "$work/source/system/kernel" "$nested" "$diagnostic" "$dual_timer" "$stage_probe" "$discard_probe" "$layout_probe" "$run_probe" "$text_pad" "$physical_uarea" "$e10_provider" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
nested = sys.argv[2] == '1'
diagnostic = sys.argv[3] == '1'
dual_timer = sys.argv[4] == '1'
stage_probe = sys.argv[5] == '1'
discard_probe = sys.argv[6] == '1'
layout_probe = sys.argv[7] == '1'
run_probe = sys.argv[8] == '1'
text_pad = sys.argv[9] == '1'
physical_uarea = sys.argv[10] == '1'
e10_provider = sys.argv[11] == '1'
def patch(rel, old, new):
    path = root / rel
    source = path.read_text()
    if source.count(old) != 1:
        raise SystemExit('v890 isolated hook not unique: ' + rel +
                         ' (' + str(source.count(old)) + ')')
    path.write_text(source.replace(old, new))

# Force only the child's first staged executable load to report NOMEM.
# The production low-memory EXEC path must then destroy its old VM
# itself and return EXEC_REPLACE_FATAL when the second load fails.
patch('proc/exec_lowmem_pdp6.s',
      '        pushj   17,exec_load_process\n'
      '        movem   1,EXEC_R_STAGED+2(17)',
      '''        move    4,proc_current_slot
        caile   4,1
        jrst    daimos_test_stage_nmem_v890
        pushj   17,exec_load_process
        jrst    daimos_test_stage_done_v890
daimos_test_stage_nmem_v890:
        movem   4,daimos_test_owner_v890
        aos     daimos_test_staged_v890
        movni   1,2
daimos_test_stage_done_v890:
        movem   1,EXEC_R_STAGED+2(17)''')
patch('proc/exec_lowmem_pdp6.s',
      'exec_lowmem_old_gone:\n        move    10,EXEC_LM_LAUNCH(17)',
      '''exec_lowmem_old_gone:
        aos     daimos_test_commits_v890
        move    4,1(15)
        camn    4,[-1]                 ; real VM_SPACE_NONE
        jrst    daimos_test_destroyed_v890
        setom   daimos_test_error_v890
daimos_test_destroyed_v890:
        move    10,EXEC_LM_LAUNCH(17)''')
patch('proc/exec_lowmem_pdp6.s',
      '        pushj   17,exec_load_process\n'
      '        move    16,1',
      '''        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_load_normal_v890
        aos     daimos_test_load_fail_v890
        move    4,1(15)                ; VM must remain none
        camn    4,[-1]
        jrst    daimos_test_load_inject_v890
        setom   daimos_test_error_v890
daimos_test_load_inject_v890:
        seto    1,                     ; loader failed after real destroy
        jrst    daimos_test_load_done_v890
daimos_test_load_normal_v890:
        pushj   17,exec_load_process
daimos_test_load_done_v890:
        move    16,1''')

# Confirm that the actual VM teardown set descriptor to none.
patch('proc/vm_pdp6.s',
      '        setom   1(2)                   ; VM_SPACE_NONE',
      '''        setom   1(2)                   ; VM_SPACE_NONE
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_other_vm_v890
        aos     daimos_test_vm_destroy_v890
daimos_test_other_vm_v890:''')

# Mark only the selected owner's FD 0 when calling the actual vfs_sync
# entry. The simulated provider failure occurs *inside* vfs_sync.
patch('fs/file_runtime.s',
      'file_close_vfs:\n        pushj   17,vfs_sync\nfile_close_finish:',
      '''file_close_vfs:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_vfs_call_v890
        move    4,010
        came    4,file_table
        jrst    daimos_test_vfs_call_v890
        setom   daimos_test_vfs_fd0_v890
daimos_test_vfs_call_v890:
        pushj   17,vfs_sync
        setzm   daimos_test_vfs_fd0_v890
file_close_finish:''')
patch('fs/vfs.s', 'vfs_sync:\n        ldb     7,[POINT 6,1,5]',
      '''vfs_sync:
        skipn   daimos_test_vfs_fd0_v890
        jrst    daimos_test_vfs_normal_v890
        aos     daimos_test_vfs_calls_v890
        move    4,daimos_test_vfs_calls_v890
        caig    4,2
        jrst    daimos_test_vfs_reject_v890
        jrst    daimos_test_vfs_normal_v890
daimos_test_vfs_reject_v890:
        aos     daimos_test_vfs_rejects_v890
        movni   1,5                    ; test-only VFS provider refusal
        popj    17,
daimos_test_vfs_normal_v890:
        ldb     7,[POINT 6,1,5]''')

if nested:
    # Allow the original EXEC fatal FILE retry to proceed only after
    # the unrelated APR fault and the fully constructed, unpublished
    # RUN's real post-VM fdmap rejection. This is a test-only handshake.
    patch('fs/vfs.s',
          '''        caig    4,2
        jrst    daimos_test_vfs_reject_v890
        jrst    daimos_test_vfs_normal_v890''',
          '''        caig    4,2
        jrst    daimos_test_vfs_reject_v890
        skipn   daimos_test_late_run_v1126
        jrst    daimos_test_vfs_reject_v890
        jrst    daimos_test_vfs_normal_v890''')
    patch('proc/proc_run.s',
          '''proc_run_fdmap_bad:
        jrst    proc_run_claimed_bad''',
          '''proc_run_fdmap_bad:
        move    5,proc_current_slot
        caie    5,1                   ; only INIT's late failed RUN
        jrst    daimos_test_run_normal_v1126
        aos     daimos_test_late_run_v1126
        skipn   daimos_test_fd_held_v890
        setom   daimos_test_run_error_v1126
        skipn   daimos_test_vfs_rejects_v890
        setom   daimos_test_run_error_v1126
        skipn   daimos_test_exits_v890
        jrst    daimos_test_run_normal_v1126
        setom   daimos_test_run_error_v1126
daimos_test_run_normal_v1126:
        jrst    proc_run_claimed_bad''')
    p = root / 'proc/proc_run.s'
    p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_late_run_v1126
daimos_test_late_run_v1126: .block 1
        .globl daimos_test_run_error_v1126
daimos_test_run_error_v1126: .block 1
''')

    # Trace the real slot-2 EXIT handoff. The first integrated guest
    # reached EXEC FILE close success but its parent continued to see
    # a live child; find whether owner finalization fails, defers its
    # u-area, or actually publishes ZOMB before changing any policy.
    patch('proc/proc_pdp6.s',
          'proc_finish_slot_owner_v932:\n        movei   5,1',
          '''proc_finish_slot_owner_v932:
        caie    1,2
        jrst    v1126_finish_other
        aos     daimos_test_finish_owner_v1126
v1126_finish_other:
        movei   5,1''')
    patch('proc/proc_pdp6.s',
          'proc_finish_fail:\n        seto    1,',
          '''proc_finish_fail:
        caie    10,2
        jrst    v1126_fail_other
        aos     daimos_test_finish_fail_v1126
v1126_fail_other:
        seto    1,''')
    patch('proc/proc_pdp6.s',
          'proc_finish_defer_uarea_v881:\n',
          '''proc_finish_defer_uarea_v881:
        caie    10,2
        jrst    v1126_defer_other
        aos     daimos_test_finish_defer_v1126
v1126_defer_other:
''')
    patch('proc/proc_pdp6.s',
          'proc_finish_zombie:\n        move    1,14',
          '''proc_finish_zombie:
        caie    10,2
        jrst    v1126_zombie_other
        aos     daimos_test_finish_zombie_v1126
v1126_zombie_other:
        move    1,14''')
    p = root / 'proc/proc_pdp6.s'
    p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_finish_owner_v1126
daimos_test_finish_owner_v1126: .block 1
        .globl daimos_test_finish_fail_v1126
daimos_test_finish_fail_v1126: .block 1
        .globl daimos_test_finish_defer_v1126
daimos_test_finish_defer_v1126: .block 1
        .globl daimos_test_finish_zombie_v1126
daimos_test_finish_zombie_v1126: .block 1
''')

# Record real FILE close passes, owned descriptor preservation, and
# read the production GETTEARDOWN diagnostic while the owner is alive.
patch('fs/file_runtime.s',
      '        move    011,1\n        setz    012,                    ; remember any failed close',
      '''        move    011,1
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_pass_other_v890
        aos     daimos_test_passes_v890
daimos_test_pass_other_v890:
        setz    012,                    ; remember any failed close''')
patch('fs/file_runtime.s',
      '        movem   4,1(011)               ; FILE table+041 = u-area 067',
      '''        movem   4,1(011)               ; FILE table+041 = u-area 067
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_no_probe_v890
        jumpn   012,daimos_test_busy_probe_v890
        skipn   1(011)                 ; witness cleared after success
        aos     daimos_test_witness_clear_v890
        move    4,file_table
        skipn   (4)                    ; selected FD 0 finally gone
        aos     daimos_test_fd_clear_v890
        jrst    daimos_test_no_probe_v890
daimos_test_busy_probe_v890:
        move    4,file_table
        skipn   (4)                    ; failed FD must remain owned
        setom   daimos_test_error_v890
        aos     daimos_test_fd_held_v890
        move    2,proc_current_slot
        iori    2,0400
        pushj   17,proc_control_getteardown_v886
        movem   1,daimos_test_query_v890
        move    4,1
        lsh     4,-017
        caie    4,5
        setom   daimos_test_error_v890
daimos_test_no_probe_v890:''')

# Instrument exactly the actual victim's private-stack timer sleep.
patch('proc/proc_pdp6.s',
      'proc_sleep_ticks:\n        hrrz    1,1',
      '''proc_sleep_ticks:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_sleep_normal_v890
        aos     daimos_test_sleeps_v890
        move    5,proc_current_ptr
        move    5,1(5)
        camn    5,[-1]
        jrst    daimos_test_sleep_vm_none_v890
        setom   daimos_test_error_v890
daimos_test_sleep_vm_none_v890:
        move    4,daimos_test_sleeps_v890
        caie    4,1
        jrst    daimos_test_sleep_2_v890
        camn    1,[1]
        jrst    daimos_test_sleep_normal_v890
        setom   daimos_test_error_v890
daimos_test_sleep_2_v890:
        caie    4,2
        jrst    daimos_test_sleep_normal_v890
        camn    1,[2]
        jrst    daimos_test_sleep_normal_v890
        setom   daimos_test_error_v890
daimos_test_sleep_normal_v890:
        hrrz    1,1''')
patch('proc/proc_pdp6.s',
      'proc_exit_current:\n        move    3,1',
      '''proc_exit_current:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_exit_other_v890
        aos     daimos_test_exits_v890
daimos_test_exit_other_v890:
        move    3,1''')

if diagnostic:
    # An obsolete test must not hide a repeated FILE refusal behind a
    # host timeout. Stop only this copied kernel after six actual owner
    # close passes and sample the same existing test counters.
    patch('proc/proc_pdp6.s',
          'proc_fatal_close_retry_v879:\n        pushj   17,file_close_all',
          '''proc_fatal_close_retry_v879:
        move    4,proc_current_slot
        came    4,daimos_test_owner_v890
        jrst    daimos_test_retry_continue_v1126
        move    4,daimos_test_passes_v890
        caige   4,6
        jrst    daimos_test_retry_continue_v1126
        halt                          ; diagnostic snapshot, never production
daimos_test_retry_continue_v1126:
        pushj   17,file_close_all''')
    # Also detect a stranded owner that never reaches six retries.
    # Bound idle iterations independently of the clock: if PI6 stops,
    # the test still HALTs and exposes timer frontier/clock registers.
    patch('proc/proc_pdp6.s',
          '''proc_idle_loop:
        ; Both timer-driven admission''',
          '''proc_idle_loop:
        skipn   daimos_test_staged_v890
        jrst    daimos_test_idle_regular_v1126
        aos     4,daimos_test_idle_loops_v1126
        camge   4,[0200000]
        jrst    daimos_test_idle_regular_v1126
        halt
daimos_test_idle_regular_v1126:
        ; Both timer-driven admission''')
    if dual_timer:
        patch('proc/proc_pdp6.s',
              '''        aos     4,daimos_test_idle_loops_v1126
        camge   4,[0200000]
        jrst    daimos_test_idle_regular_v1126
        halt''',
              '''        aos     4,daimos_test_idle_loops_v1126
        caie    4,0200000
        jrst    daimos_test_idle_second_v1127
        move    5,proc_timer_clock
        movem   5,daimos_test_clock_first_v1127
        move    5,proc_timer_next
        movem   5,daimos_test_frontier_first_v1127
        coni    0004,5
        movem   5,daimos_test_pi_first_v1127
daimos_test_idle_second_v1127:
        camge   4,[02000000]
        jrst    daimos_test_idle_regular_v1126
        coni    0004,5
        movem   5,daimos_test_pi_last_v1127
        move    5,proc_finish_last_tick_v881
        movem   5,daimos_test_finish_pending_v1127
        move    6,proc_table
        move    5,3(6)                ; PID 1 descriptor metadata
        movem   5,daimos_test_parent_meta_v1127
        move    5,5(6)                ; PID 1 scheduler/wait status
        movem   5,daimos_test_parent_sched_v1127
        move    5,6(6)                ; PID 2 descriptor metadata
        movem   5,daimos_test_child_meta_v1127
        hlrz    7,5                   ; stable child u-area
        jumpe   7,daimos_test_no_child_uarea_v1127
        move    5,067(7)              ; stored FILE/finalization witness
        movem   5,daimos_test_child_finalize_v1127
daimos_test_no_child_uarea_v1127:
        move    5,7(6)                ; PID 2 VM state
        movem   5,daimos_test_child_vm_v1127
        move    5,010(6)              ; PID 2 scheduler/WAIT state
        movem   5,daimos_test_child_sched_v1127
        halt''')
    p = root / 'proc/proc_pdp6.s'
    p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_idle_loops_v1126
daimos_test_idle_loops_v1126: .block 1
''')
    if dual_timer:
        p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_clock_first_v1127
daimos_test_clock_first_v1127: .block 1
        .globl daimos_test_frontier_first_v1127
daimos_test_frontier_first_v1127: .block 1
        .globl daimos_test_pi_first_v1127
daimos_test_pi_first_v1127: .block 1
        .globl daimos_test_pi_last_v1127
daimos_test_pi_last_v1127: .block 1
        .globl daimos_test_finish_pending_v1127
daimos_test_finish_pending_v1127: .block 1
        .globl daimos_test_parent_meta_v1127
daimos_test_parent_meta_v1127: .block 1
        .globl daimos_test_parent_sched_v1127
daimos_test_parent_sched_v1127: .block 1
        .globl daimos_test_child_meta_v1127
daimos_test_child_meta_v1127: .block 1
        .globl daimos_test_child_finalize_v1127
daimos_test_child_finalize_v1127: .block 1
        .globl daimos_test_child_vm_v1127
daimos_test_child_vm_v1127: .block 1
        .globl daimos_test_child_sched_v1127
daimos_test_child_sched_v1127: .block 1
''')
    if stage_probe:
        # Distinguish actual TTY, VM and post-VM release refusal paths.
        # AC10 is the retained owner slot; all counters are test-only.
        patch('proc/proc_pdp6.s',
              '''        pushj   17,proc_tty_release_session
        jumpn   1,proc_finish_prevm_fail_v1081''',
              '''        pushj   17,proc_tty_release_session
        jumpe   1,daimos_test_tty_ok_v1128
        caie    10,2
        jrst    daimos_test_tty_ok_v1128
        aos     daimos_test_tty_fail_v1128
        movem   1,daimos_test_tty_error_v1128
daimos_test_tty_ok_v1128:
        jumpn   1,proc_finish_prevm_fail_v1081''')
        patch('proc/proc_pdp6.s',
              '''        pushj   17,vm_space_destroy
        jumpe   1,proc_finish_vm_done''',
              '''        pushj   17,vm_space_destroy
        jumpe   1,proc_finish_vm_done
        caie    10,2
        jrst    proc_finish_prevm_fail_v1081
        aos     daimos_test_vm_fail_v1128
        movem   1,daimos_test_vm_error_v1128
        jrst    proc_finish_prevm_fail_v1081''')
        patch('proc/proc_pdp6.s',
              '''proc_finish_vm_done:
        ; Clear the PREVM stage''',
              '''proc_finish_vm_done:
        caie    10,2
        jrst    daimos_test_vm_done_other_v1128
        aos     daimos_test_vm_done_v1128
daimos_test_vm_done_other_v1128:
        ; Clear the PREVM stage''')
        patch('proc/proc_pdp6.s',
              '''proc_finish_defer_uarea_v881:
        ; VM has been destroyed.''',
              '''proc_finish_defer_uarea_v881:
        caie    10,2
        jrst    daimos_test_defer_other_v1128
        aos     daimos_test_defer_v1128
        movem   1,daimos_test_defer_error_v1128
daimos_test_defer_other_v1128:
        ; VM has been destroyed.''')
        patch('proc/proc_pdp6.s',
              '''proc_finish_zombie:
        move    1,14''',
              '''proc_finish_zombie:
        caie    10,2
        jrst    daimos_test_zombie_other_v1128
        aos     daimos_test_zombie_v1128
daimos_test_zombie_other_v1128:
        move    1,14''')
        p = root / 'proc/proc_pdp6.s'
        labels = ('tty_fail', 'tty_error', 'vm_fail', 'vm_error',
                  'vm_done', 'defer', 'defer_error', 'zombie')
        p.write_text(p.read_text() + '\n        .bss\n' +
                     ''.join('        .globl daimos_test_%s_v1128\n'
                             'daimos_test_%s_v1128: .block 1\n' % (n,n)
                             for n in labels))

if discard_probe:
    # Trace the *real* RUN rollback, not a stubbed allocator/free. Only
    # record after the late fd-map rejection has armed its owner marker.
    # These probes alter no registers and never modify a release result.
    proc_labels = (
        ('slot', 'proc_slot_discard'),
        ('new', 'proc_discard_new_v892'),
        ('live', 'proc_discard_live'),
        ('vm_retry', 'proc_discard_vm_retry_v894'),
        ('prevm_fail', 'proc_discard_prevm_fail_v1085'),
        ('vm_done', 'proc_discard_vm_done'),
        ('uarea_retry', 'proc_discard_retry_uarea_v892'),
        ('uarea_defer', 'proc_discard_defer_uarea_v892'),
        ('ok', 'proc_discard_ok'),
        ('fail', 'proc_discard_fail'),
        ('return', 'proc_discard_return'),
    )
    run_labels = (
        ('claimed', 'proc_run_claimed_bad'),
        ('run_return', 'proc_run_return'),
    )
    for rel, labels in (('proc/proc_pdp6.s', proc_labels),
                        ('proc/proc_run.s', run_labels)):
        for name, label in labels:
            symbol = 'daimos_test_%s_v1131' % name
            skip = 'daimos_test_skip_%s_v1131' % name
            patch(rel, label + ':\n',
                  label + ':\n'
                  '        skipn   daimos_test_late_run_v1126\n'
                  '        jrst    %s\n'
                  '        aos     %s\n'
                  '%s:\n' % (skip, symbol, skip))
        p = root / rel
        p.write_text(p.read_text() + '\n        .bss\n' +
                     ''.join('        .globl daimos_test_%s_v1131\n'
                             'daimos_test_%s_v1131: .block 1\n' % (name,name)
                             for name, _ in labels))

if layout_probe:
    # Deliberately unused, test-only memory layout perturbation.
    # No new instruction, MM operation or successful error return.
    for rel, amount, name in (
        ('proc/proc_pdp6.s', 11, 'proc'),
        ('proc/proc_run.s', 2, 'run'),
    ):
        p = root / rel
        p.write_text(p.read_text() +
                     '\n        .bss\n'
                     '        .globl daimos_test_pad_%s_v1132\n'
                     'daimos_test_pad_%s_v1132: .block %d\n' %
                     (name, name, amount))

if run_probe:
    # Minimal witness on the two unchanged production RUN boundaries.
    # No allocator or rollback state is fabricated, no code padding.
    p = root / 'proc/proc_run.s'
    for name, label in (('claimed', 'proc_run_claimed_bad'),
                        ('returned', 'proc_run_return')):
        anchor = label + ':\n'
        assert p.read_text().count(anchor) == 1, label
        p.write_text(p.read_text().replace(
            anchor, anchor +
            '        aos     daimos_test_run_%s_v1133\n' % name, 1))
    p.write_text(p.read_text() + '\n        .bss\n'
                 '        .globl daimos_test_run_claimed_v1133\n'
                 'daimos_test_run_claimed_v1133: .block 1\n'
                 '        .globl daimos_test_run_returned_v1133\n'
                 'daimos_test_run_returned_v1133: .block 1\n')

if text_pad:
    # Move only the downstream production text: these 043 octal words
    # are unreachable after the explicit JRST above the next label.
    # This is diagnostic code-placement variation, NOT a proposed fix.
    p = root / 'proc/proc_run.s'
    anchor = ('daimos_test_run_normal_v1126:\n'
              '        jrst    proc_run_claimed_bad\n'
              '\n'
              'proc_run_claimed_bad:\n')
    assert p.read_text().count(anchor) == 1
    p.write_text(p.read_text().replace(
        anchor,
        ('daimos_test_run_normal_v1126:\n'
         '        jrst    proc_run_claimed_bad\n\n' +
         '        .word   0\n' * 0o43 +
         'proc_run_claimed_bad:\n'), 1))

if physical_uarea:
    # E10 holds APR slot 3 and provider slot 4 until the late failed
    # RUN, so that real unpublished RUN owns slot 5. The original
    # v1142 guest still uses slot 3 after reaping its APR child.
    mm_owner = '01005' if e10_provider else '01003'
    discard_slot = '5' if e10_provider else '3'
    # Pin the actual allocated u-area for the *late* unpublished child,
    # never a synthetic descriptor. The first real mm_free must return
    # MM_ERR_BUSY; the original discard code must defer the slot. Drop
    # the physical pin only after observing that refusal, so the usual
    # slot-zero finalizer performs the second successful MM release.
    patch('mm/mm_pdp6.s',
          'mm_free:\n        move    5,1',
          '''mm_free:
        caie    2,3                 ; kernel-dynamic u-area
        jrst    daimos_mm_original_v1142
        caie    3,01003             ; exact unpublished RUN u-area owner
        jrst    daimos_mm_original_v1142
        skipn   daimos_test_late_run_v1126
        jrst    daimos_mm_original_v1142
        aos     daimos_mm_calls_v1142
        move    0,daimos_mm_calls_v1142
        caie    0,1
        jrst    daimos_mm_original_v1142
        push    17,1
        push    17,2
        push    17,3
        movem   1,daimos_mm_base_v1142
        pushj   17,mm_pin
        jumpe   1,daimos_mm_pin_good_v1142
        aos     daimos_mm_errors_v1142
        jrst    daimos_mm_pin_restore_v1142
daimos_mm_pin_good_v1142:
        aos     daimos_mm_pins_v1142
daimos_mm_pin_restore_v1142:
        pop     17,3
        pop     17,2
        pop     17,1
daimos_mm_original_v1142:
        move    5,1'''.replace('caie    3,01003',
                             'caie    3,' + mm_owner))
    patch('proc/proc_pdp6.s',
          '''proc_discard_defer_uarea_v892:
        ; The u-area still belongs''',
          '''proc_discard_defer_uarea_v892:
        caie    11,3
        jrst    daimos_discard_original_v1142
        came    1,[-5]              ; verify real MM_ERR_BUSY
        jrst    daimos_discard_wrong_v1142
        aos     daimos_mm_busy_v1142
        move    1,daimos_mm_base_v1142
        pushj   17,mm_unpin
        jumpn   1,daimos_discard_wrong_v1142
        aos     daimos_mm_unpins_v1142
        jrst    daimos_discard_original_v1142
daimos_discard_wrong_v1142:
        aos     daimos_mm_errors_v1142
daimos_discard_original_v1142:
        ; The u-area still belongs'''.replace('caie    11,3',
                                            'caie    11,' + discard_slot))
    p = root / 'mm/mm_pdp6.s'
    labels = ('calls', 'base', 'pins', 'busy', 'unpins', 'errors')
    p.write_text(p.read_text() + '\n        .bss\n' +
                 ''.join('        .globl daimos_mm_%s_v1142\n'
                         'daimos_mm_%s_v1142: .block 1\n' % (n, n)
                         for n in labels))

stats = [
    'owner', 'staged', 'commits', 'vm_destroy', 'load_fail',
    'vfs_fd0', 'vfs_calls', 'vfs_rejects',
    'passes', 'sleeps', 'query', 'fd_held', 'fd_clear',
    'witness_clear', 'exits', 'error'
]
path = root / 'fs/file_runtime.s'
path.write_text(path.read_text() + '\n        .bss\n' +
                ''.join('        .globl daimos_test_%s_v890\n'
                        'daimos_test_%s_v890: .block 1\n' % (n, n)
                        for n in stats))
PY
if [ "$e10_provider" = 1 ]; then
    python3 "$self/daimos-fatal-exec-provider-v1157.py" \
        "$work/source/system/kernel"
fi

cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
"$das" -C -F -O "$work/user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -C -F -O "$work/user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
inc=""
for d in boot core drivers fs ipc mm modules proc storage; do
    inc="$inc -I$DAIMOS_REPO/system/kernel/$d"
done
# shellcheck disable=SC2086
"$cc" -std=c89 -Os -DDAIMOS_V1126_NESTED="$nested" \
    -DDAIMOS_V1142_PHYSICAL_UAREA="$physical_uarea" \
    -DDAIMOS_V1157_PROVIDER="$e10_provider" \
    $inc -I"$DAIMOS_REPO/userland/libc" \
    -S "$self/daimos-fatal-exec-integration-v890.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
libgcc=$("$cc" -print-libgcc-file-name)
"$dlink" -b 020 -o "$work/user/init.dxr" -M "$work/user/init.map" \
    "$work/user/crt0.dobj" "$work/user/syscall.dobj" \
    "$work/user/init.dobj" "$libgcc"
build="$work/build/system/boot/pdp6"
PATH="$PDP10_PREFIX/bin:$PATH" \
    make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" PROC_BOOT_USERS=1 \
    KERNEL_DIR="$work/source/system/kernel" \
    SYSTEM_INIT_DXR="$work/user/init.dxr" SIMH_DPY_MODE=HEADLESS \
    > "$work/build.log" 2>&1 || {
        tail -55 "$work/build.log" >&2
        echo "v890: isolated kernel/image build failed: $work" >&2
        exit 1
    }
map="$build/kcore.map"
for name in owner staged commits vm_destroy load_fail vfs_calls vfs_rejects passes sleeps query \
    fd_held fd_clear witness_clear exits error; do
    symbol="daimos_test_${name}_v890"
    addr=$(awk -v s="$symbol" '$1 == s {print $2}' "$map")
    test -n "$addr" || { echo "v890: no $symbol" >&2; exit 1; }
    printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
done
if [ "$nested" = 1 ]; then
    for name in late_run run_error finish_owner finish_fail \
                finish_defer finish_zombie; do
        symbol="daimos_test_${name}_v1126"
        addr=$(awk -v s="$symbol" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1126: no $symbol" >&2; exit 1; }
        printf '%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$diagnostic" = 1 ]; then
    for name in proc_timer_clock proc_timer_next proc_sched_cursor \
                proc_current_slot daimos_test_idle_loops_v1126; do
        addr=$(awk -v s="$name" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1126: missing $name" >&2; exit 1; }
        printf '%s %s\n' "diag_$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$dual_timer" = 1 ]; then
    for name in clock_first frontier_first pi_first pi_last \
                finish_pending parent_meta parent_sched child_meta \
                child_finalize child_vm child_sched; do
        sym="daimos_test_${name}_v1127"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1127: no $sym" >&2; exit 1; }
        printf '%s %s\n' "dual_$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$stage_probe" = 1 ]; then
    for name in tty_fail tty_error vm_fail vm_error vm_done \
                defer defer_error zombie; do
        sym="daimos_test_${name}_v1128"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1128: no $sym" >&2; exit 1; }
        printf '%s %s\n' "stage_$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$discard_probe" = 1 ]; then
    for name in slot new live vm_retry prevm_fail vm_done \
                uarea_retry uarea_defer ok fail return claimed run_return; do
        sym="daimos_test_${name}_v1131"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1131: no $sym" >&2; exit 1; }
        printf '%s %s\n' "rollback_$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$run_probe" = 1 ]; then
    for name in claimed returned; do
        sym="daimos_test_run_${name}_v1133"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1133: no $sym" >&2; exit 1; }
        printf '%s %s\n' "runprobe_$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$physical_uarea" = 1 ]; then
    for name in calls base pins busy unpins errors; do
        sym="daimos_mm_${name}_v1142"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1142: no $sym" >&2; exit 1; }
        printf '%s %s\n' "physical_$name" "$addr" >> "$work/addresses"
    done
fi
if [ "$e10_provider" = 1 ]; then
    for name in holder_enter holder_lease holder_return release \
                run_armed foreign_busy fd3_stage fd3_after; do
        sym="daimos_e10_${name}_v1157"
        addr=$(awk -v s="$sym" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1157: missing $sym" >&2; exit 1; }
        printf 'e10_%s %s\n' "$name" "$addr" >> "$work/addresses"
    done
    addr=$(awk '$1 == "fs_provider_ready" {print $2}' "$map")
    test -n "$addr" || { echo 'v1157: missing provider lease' >&2; exit 1; }
    printf 'e10_final_lease %s\n' "$addr" >> "$work/addresses"
fi
if [ "$return_snapshot" = 1 ]; then
    # Simulator-only snapshots; unlike source instrumentation these do
    # not change KCORE text, data or the actual syscall return path.
    for name in mach_invalid_uuo_pc mach_invalid_uuo_word \
                mach_syscall_save mach_user_sp mach_kernel_sp \
                proc_current_slot proc_current_ptr proc_table; do
        addr=$(awk -v s="$name" '$1 == s {print $2}' "$map")
        test -n "$addr" || { echo "v1135: missing $name" >&2; exit 1; }
        printf '%s %s\n' "v1135_$name" "$addr" >> "$work/addresses"
    done
fi
boot="$build/boot.ini"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' "$boot"
if [ "$break_trace" = 1 ]; then
    # Two one-shot SIMH execution breakpoints on unchanged production
    # instructions. The second address is three words after the
    # exported claimed_bad entry in the verified compact RUN epilogue.
    claimed=$(awk '$1 == "proc_run_claimed_bad" {print $2; exit}' "$map")
    release=$(awk '$1 == "vm_user_mapping_release" {print $2; exit}' "$map")
    save=$(awk '$1 == "mach_syscall_save" {print $2; exit}' "$map")
    user_sp=$(awk '$1 == "mach_user_sp" {print $2; exit}' "$map")
    kern_sp=$(awk '$1 == "mach_kernel_sp" {print $2; exit}' "$map")
    slot=$(awk '$1 == "proc_current_slot" {print $2; exit}' "$map")
    test -n "$claimed" && test -n "$release" && test -n "$save" &&
        test -n "$user_sp" && test -n "$kern_sp" && test -n "$slot"
    awk -v c="$claimed" -v f="$work/claimed-return-v1136" '
      BEGIN { n=0; for (i=1;i<=length(c);i++) n=n*8+index("01234567",substr(c,i,1))-1;
              printf "%o\n",n+3 > f }'
    return_pc=$(cat "$work/claimed-return-v1136")
    # Reinsert the breakpoint commands before the boot instruction;
    # all address values come from this fresh, linked guest's map.
    if [ "$discard_breaks" = 1 ]; then
        # Reassemble for local-label listings only. Neither object is
        # linked into the guest: the running image is byte-identical.
        { echo '.set PROC_STACK_WATERMARK,0';
          echo '.set KINIT_STACK_WATERMARK,0';
          cat "$work/source/system/kernel/proc/proc_pdp6.s";
        } > "$work/proc-pdp6-v1138.s"
        { echo '.set PROC_STACK_WATERMARK,0';
          cat "$work/source/system/kernel/proc/proc_run.s";
        } > "$work/proc-run-v1138.s"
        "$das" -F -C -L "$work/proc-pdp6-v1138.labels" \
            -O "$work/proc-pdp6-v1138.dobj" "$work/proc-pdp6-v1138.s"
        "$das" -F -C -L "$work/proc-run-v1138.labels" \
            -O "$work/proc-run-v1138.dobj" "$work/proc-run-v1138.s"
        python3 - "$boot" "$map" "$work/proc-pdp6-v1138.labels" \
            "$work/proc-run-v1138.labels" "$work/trace-labels-v1138" \
            "$release_breaks" <<'PY'
from pathlib import Path
import sys

boot, map_path, proc_path, run_path, report = map(Path, sys.argv[1:6])
release_breaks = sys.argv[6] == '1'

def symbols(path):
    pairs = (line.split() for line in path.read_text().splitlines())
    return {parts[0]: int(parts[1], 8) for parts in pairs
            if len(parts) == 2 and all(c in '01234567' for c in parts[1])}

linked = symbols(map_path)
proc, run = symbols(proc_path), symbols(run_path)
folds = {}
for line in map_path.with_name('kcore.fold').read_text().splitlines():
    fields = line.split('\t')
    if len(fields) == 6 and fields[0] == 'FOLD':
        name = Path(fields[1]).name
        folds.setdefault(name, []).append((int(fields[2], 8),
                                            int(fields[5], 8)))

def final_address(labels, anchor, obj):
    start = labels[anchor]
    base = linked[anchor]
    segments = folds.get(obj, [])
    def removed_before(off):
        return sum(count for first, count in segments if first < off)
    def translate(label):
        off = labels[label]
        # A folded-away local label has no instruction to break on.
        if any(first <= off < first + count for first, count in segments):
            return None
        return (base + off - start - removed_before(off) +
                removed_before(start))
    return translate

proc_address = final_address(proc, 'proc_slot_discard', 'proc_pdp6.dobj')
run_address = final_address(run, 'proc_run_block', 'proc_run.dobj')
assert proc_address('proc_uarea_release') == linked['proc_uarea_release']
assert run_address('proc_run_claimed_bad') == linked['proc_run_claimed_bad']
proc_stages = ('proc_slot_discard', 'proc_discard_new_v892',
               'proc_discard_live', 'proc_discard_vm_retry_v894',
               'proc_discard_prevm_fail_v1085', 'proc_discard_vm_done',
               'proc_discard_retry_uarea_v892',
               'proc_discard_defer_uarea_v892', 'proc_discard_ok',
               'proc_discard_fail', 'proc_discard_return',
               'proc_uarea_release')
if release_breaks:
    proc_stages += ('proc_uarea_release_fail',
                    'proc_uarea_release_invalid_v1097',
                    'proc_runq_remove', 'proc_trim_high')
run_stages = ('proc_run_claimed_bad', 'proc_run_return')
stages = [(name, proc_address(name)) for name in proc_stages]
stages += [(name, run_address(name)) for name in run_stages]
if release_breaks:
    stages += [('mm_free', linked['mm_free'])]
    # The first instruction following PUSHJ 17,mm_free in this source.
    stages += [('proc_uarea_mm_return_v1140',
                proc_address('proc_uarea_release') + 0o14)]
folded_out = [name for name, addr in stages if addr is None]
stages = [(name, addr) for name, addr in stages if addr is not None]
sample = ';'.join('examine %s' % name for name in
                  ('PC', '17', '1', '2', '10', '11', '12', '13',
                   '14', '15', '%o' % linked['mach_syscall_save'],
                   '%o' % linked['mach_user_sp'],
                   '%o' % linked['mach_kernel_sp'],
                   '%o' % linked['proc_current_slot']))
script = ''.join('break %o;%s;go\n' % (addr, sample)
                 for name, addr in stages)
original = boot.read_text()
assert original.count('go 020\n') == 1
boot.write_text(original.replace('go 020\n', script + 'go 020\n', 1))
report.write_text(''.join('%s %06o\n' % (name, addr)
                          for name, addr in stages))
print('v1138: folded local labels not used as breakpoints:', folded_out)
PY
    elif [ "$sequential_trace" = 1 ]; then
        python3 - "$boot" "$claimed" "$return_pc" "$save" \
            "$user_sp" "$kern_sp" "$slot" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
claimed, returned, save, user, kernel, slot = sys.argv[2:]
original = p.read_text()
assert original.count('go 020\n') == 1
sample = ''.join('examine %s\n' % name for name in
                 ('PC', '17', save, user, kernel, slot))
script = ('break %s\ngo 020\n' % claimed + sample +
          'break %s\ngo\n' % returned + sample)
p.write_text(original.replace('go 020\n', script, 1))
PY
    else
        sed -i "/^go 020$/i break $claimed;examine PC;examine 17;examine $save;examine $user_sp;examine $kern_sp;examine $slot;go\nbreak $return_pc;examine PC;examine 17;examine $save;examine $user_sp;examine $kern_sp;examine $slot;go" "$boot"
    fi
fi
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$boot"
done < "$work/addresses"
printf 'exit\n' >> "$boot"
if [ "$nested" = 1 ]; then
    sim_limit=180s
else
    sim_limit=65s
fi
if [ "$e10_provider" = 1 ]; then sim_limit=240s; fi
set +e
(cd "$build"; TERM=dumb timeout -k 2s "$sim_limit" stdbuf -o0 -e0 \
    "$PDP10_PREFIX/bin/pdp6" boot.ini) > "$work/simh.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    tail -80 "$work/simh.out" >&2
    echo "v890: SIMH failed ($rc): $work" >&2
    exit 1
fi
python3 - "$work/addresses" "$work/simh.out" "$nested" "$diagnostic" "$discard_probe" "$layout_probe" "$run_probe" "$text_pad" "$return_snapshot" "$break_trace" "$sequential_trace" "${claimed:-}" "${return_pc:-}" "$discard_breaks" "$work/trace-labels-v1138" "$physical_uarea" "$e10_provider" <<'PY'
from pathlib import Path
import re
import sys
names = Path(sys.argv[1]).read_text().splitlines()
output = Path(sys.argv[2]).read_text(errors='replace')
nested = sys.argv[3] == '1'
diagnostic = sys.argv[4] == '1'
discard_probe = sys.argv[5] == '1'
layout_probe = sys.argv[6] == '1'
run_probe = sys.argv[7] == '1'
text_pad = sys.argv[8] == '1'
return_snapshot = sys.argv[9] == '1'
break_trace = sys.argv[10] == '1'
sequential_trace = sys.argv[11] == '1'
discard_breaks = sys.argv[14] == '1'
physical_uarea = sys.argv[16] == '1'
e10_provider = sys.argv[17] == '1'
counts = {}
for line in names:
    name, address = line.split()
    matches = re.findall(r'(?im)^\s*0*' +
                         re.escape(address.lstrip('0')) +
                         r'\s*:\s*([0-7]+)\b', output)
    if not matches:
        raise SystemExit('v890 missing SIMH sample ' + name +
                         ': ' + output[-1600:])
    counts[name] = int(matches[-1], 8)
print('v890 real EXEC post-VM/FILE fault counters:', counts)
e10_markers = False
if e10_provider and '<' in output:
    # APR runs asynchronously on its own process. Its marker A can
    # precede or follow B/R, but must occur while the lease is held,
    # strictly before the original holder's U release marker.
    user_marks = output.split('<', 1)[1].split('HALT', 1)[0]
    positions = {ch: user_marks.find(ch) for ch in 'EABRUH'}
    e10_markers = (user_marks.startswith('E') and
                   all(pos >= 0 for pos in positions.values()) and
                   positions['E'] < positions['B'] < positions['R'] <
                   positions['U'] < positions['H'] and
                   positions['E'] < positions['A'] < positions['U'])
if physical_uarea:
    observed = {n: counts['physical_' + n] for n in
                ('calls', 'base', 'pins', 'busy', 'unpins', 'errors')}
    print('v1142: real unpublished RUN u-area MM counters:', observed)
    if (observed['calls'] != 2 or observed['base'] == 0 or
        observed['pins'] != 1 or observed['busy'] != 1 or
        observed['unpins'] != 1 or observed['errors'] != 0 or
        counts['late_run'] != 1 or counts['run_error'] != 0 or
        counts['finish_zombie'] != 1 or counts['error'] != 0 or
        (not e10_markers if e10_provider else '<EARH' not in output) or
        'UUO 000000000014' in output or
        'HALT' not in output):
        raise SystemExit('v1142: real-MM_BUSY nested rollback failed')
    print('v1142: actual MM pin/BUSY/unpin/deferred RUN discard, '
          'parent return and EXEC WAIT PASS; D13 subcase only')
    if not e10_provider:
        raise SystemExit(0)
if break_trace:
    captures = [line for line in output.splitlines() if line.startswith('PC:')]
    print('v1136: simulator breakpoint PC captures: ' + repr(captures))
    if counts['late_run'] != 1 or 'HALT' not in output:
        raise SystemExit('v1136: late RUN/capture terminal state missing')
    if discard_breaks:
        trace = dict(line.split() for line in Path(sys.argv[15]).read_text().splitlines())
        reverse = {int(addr, 8): name for name, addr in trace.items()}
        pcs = [int(re.search(r'PC:\s*([0-7]+)', line).group(1), 8)
               for line in captures]
        visited = [reverse.get(pc, 'unexpected_%o' % pc) for pc in pcs]
        print('v1138: native rollback stage visits: ' + ','.join(visited))
        if 'proc_run_claimed_bad' not in visited or \
                'proc_slot_discard' not in visited:
            raise SystemExit('v1138: claimed RUN/real discard not visited')
        print('v1138: simulator-only unchanged kernel diagnostic; D13 OPEN')
        raise SystemExit(0)
    if sequential_trace:
        if len(captures) != 2:
            raise SystemExit('v1137: expected exactly two PC samples: ' + repr(captures))
        import re
        pcs = [int(re.search(r'PC:\s*([0-7]+)', line).group(1), 8)
               for line in captures]
        expected_claimed, expected_return = (int(sys.argv[i], 8)
                                               for i in (12, 13))
        if pcs[0] != expected_claimed:
            raise SystemExit('v1137: first breakpoint missed claimed child')
        if pcs[1] == expected_return:
            print('v1137: late discard returned to RUN epilogue; diagnostic only')
        elif pcs[1] == 0 and 'UUO 000000000014' in output:
            print('v1137: late discard did NOT return; next sample is HALT PC=0')
        else:
            raise SystemExit('v1137: unexpected second PC %o, expected %o' %
                             (pcs[1], expected_return))
    print('v1136: breakpoint-only diagnostic; D13 NOT ACCEPTED')
    raise SystemExit(0)
if return_snapshot:
    names = ('mach_invalid_uuo_pc', 'mach_invalid_uuo_word',
             'mach_syscall_save', 'mach_user_sp', 'mach_kernel_sp',
             'proc_current_slot', 'proc_current_ptr', 'proc_table')
    print('v1135: simulator-only return state: ' +
          ', '.join('%s=%012o' % (n, counts['v1135_' + n])
                    for n in names))
    if counts['late_run'] != 1 or 'HALT' not in output:
        raise SystemExit('v1135: RUN rejection/terminal capture missing')
    print('v1135: return-state snapshot only; D13 NOT ACCEPTED')
    raise SystemExit(0)
if text_pad:
    if 'HALT' not in output or counts['late_run'] != 1:
        raise SystemExit('v1134: invalid text-placement snapshot: ' + str(counts))
    print('v1134: text-placement-only diagnostic: markers=%s ZOMB=%d' %
          ('<EARH' if '<EARH' in output else '<EA/no-complete-RUN',
           counts['finish_zombie']))
    print('v1134: code placement diagnostic only; D13 NOT ACCEPTED')
    raise SystemExit(0)
if run_probe:
    if 'HALT' not in output or counts['late_run'] != 1:
        raise SystemExit('v1133: no late RUN boundary: ' + str(counts))
    print('v1133: RUN-only boundary: claimed=%d returned=%d markers=%s' %
          (counts['runprobe_claimed'], counts['runprobe_returned'],
           '<EARH' if '<EARH' in output else '<EA/no-complete-RUN'))
    print('v1133: diagnostic only; D13 NOT ACCEPTED')
    raise SystemExit(0)
if layout_probe:
    if 'HALT' not in output or '<EA' not in output or \
       counts['late_run'] != 1:
        raise SystemExit('v1132: incomplete layout-only trace: '+str(counts))
    print('v1132: layout-only guest markers: ' +
          ('<EARH' if '<EARH' in output else '<EA/no-complete-RUN'))
    print('v1132: BSS-only diagnostic snapshot; D13 NOT ACCEPTED')
    raise SystemExit(0)
if discard_probe:
    if 'HALT' not in output or '<EA' not in output or \
       counts['late_run'] != 1 or counts['rollback_slot'] != 1:
        raise SystemExit('v1131: incomplete rollback trace: ' + str(counts))
    expected = dict(rollback_slot=1, rollback_new=1,
                    rollback_live=1, rollback_vm_retry=1,
                    rollback_prevm_fail=0, rollback_vm_done=1,
                    rollback_uarea_retry=1, rollback_uarea_defer=0,
                    rollback_ok=1, rollback_fail=0,
                    rollback_return=1, rollback_claimed=1,
                    rollback_run_return=1, finish_zombie=1)
    for name, value in expected.items():
        if counts[name] != value:
            raise SystemExit('v1131: %s=%s expected=%s; snapshot=%s' %
                             (name, counts[name], value, counts))
    print('v1131: traced rollback and zombie exactly once; '
          'instrumented guest only, D13 NOT ACCEPTED')
    raise SystemExit(0)
if diagnostic:
    if 'HALT' not in output or '<E' not in output:
        raise SystemExit('v1126: diagnostic did not reach EXEC owner')
    print('v1126: diagnostic-only FILE retry snapshot; NOT acceptance')
    raise SystemExit(0)
expected = dict(staged=1, commits=1, vm_destroy=1, load_fail=1,
                vfs_calls=3, vfs_rejects=2,
                passes=3, sleeps=2, fd_held=2, fd_clear=1,
                witness_clear=1, exits=1, error=0)
if nested:
    for name in ('vfs_calls', 'vfs_rejects', 'passes', 'sleeps', 'fd_held'):
        del expected[name]
    # In E10, FD0's injected refusal ends before the original
    # provider-backed FD3 can succeed. FD3 may require additional
    # complete FILE passes while the foreign lease is occupied, even
    # after FD0 has closed. Thus actual pass/sleep accounting, rather
    # than FD0 VFS-call count, is the authoritative retry identity.
    close_accounting = (
        counts['fd_held'] == counts['sleeps'] ==
            counts['passes'] - 1 and
        counts['vfs_rejects'] == counts['vfs_calls'] - 1 and
        (counts['passes'] >= counts['vfs_calls'] >= 3
         if e10_provider else counts['passes'] == counts['vfs_calls']) and
        (counts['fd_held'] >= counts['vfs_rejects']
         if e10_provider else
         counts['fd_held'] == counts['vfs_rejects'])
    )
    if not (3 <= counts['vfs_calls'] <= 50 and close_accounting and
            counts['late_run'] == 1 and counts['run_error'] == 0 and
            counts['finish_owner'] == 1 and
            counts['finish_fail'] == 0 and
            counts['finish_defer'] == 0 and
            counts['finish_zombie'] == 1):
        raise SystemExit('v1126: post-VM RUN / FILE retry counters: ' +
                         str(counts))
for name, value in expected.items():
    if counts[name] != value:
        raise SystemExit('v890: ' + name + ': ' + str(counts[name]) +
                         ' expected ' + str(value) + '\n' + output[-900:])
if counts['owner'] <= 1 or counts['query'] >> 15 != 5 or \
        counts['query'] & 3 != 1:
    raise SystemExit('v890: wrong private FILE owner or provider error')
if 'HALT' not in output or '<E' not in output or \
        'H' not in output or '!' in output:
    raise SystemExit('v890: user fault/wait/exit sentinel failed: ' +
                     output[-900:])
print('v890: real EXEC destroys VM, replacement loader fails, '
      'VFS refusal twice, retry, FILE ownership, WAIT PASS')
if nested:
    if ((not e10_markers) if e10_provider else
        ('<EA' not in output or 'R' not in output)):
        raise SystemExit('v1126: missing APR and late-RUN markers: ' +
                         output[-1000:])
    print('v1126: real APR fatal during post-commit EXEC FILE retry; '
          'unpublished post-VM RUN rollback, retained owner and WAIT PASS')
if e10_provider:
    expected_e10 = dict(e10_holder_enter=1, e10_holder_lease=5 << 18,
                        e10_holder_return=1, e10_release=(1 << 36) - 1,
                        e10_final_lease=(1 << 36) - 1,
                        e10_run_armed=(1 << 36) - 1)
    for name, value in expected_e10.items():
        if counts[name] != value:
            raise SystemExit('v1157: %s = %s, expected %s' %
                             (name, counts[name], value))
    if counts['e10_foreign_busy'] < 1:
        raise SystemExit('v1157: no real foreign-provider close contention')
    if counts['e10_fd3_stage'] < 1 or counts['e10_fd3_after'] < 1:
        raise SystemExit('v1157: provider-backed FD3 did not survive '
                         'until the real foreign-lock attempt')
    if not e10_markers:
        raise SystemExit('v1157: missing holder/APR/RUN/release markers')
    print('v1157: live foreign provider lease retained through APR, '
          'postcommit EXEC FILE and failed RUN; owner resumes/unlocks PASS')
PY
