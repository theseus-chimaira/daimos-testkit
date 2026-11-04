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
python3 - "$work/source/system/kernel" "$nested" "$diagnostic" "$dual_timer" "$stage_probe" "$discard_probe" "$layout_probe" "$run_probe" <<'PY'
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
boot="$build/boot.ini"
sed -i -e 's/^set wcnsls .*/set wcnsls disabled/' \
    -e 's/^set ocnsls .*/set ocnsls disabled/' -e '/^exit$/d' "$boot"
while read -r name addr; do
    printf 'examine %s\n' "$addr" >> "$boot"
done < "$work/addresses"
printf 'exit\n' >> "$boot"
if [ "$nested" = 1 ]; then
    sim_limit=180s
else
    sim_limit=65s
fi
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
python3 - "$work/addresses" "$work/simh.out" "$nested" "$diagnostic" "$discard_probe" "$layout_probe" "$run_probe" <<'PY'
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
    if not (3 <= counts['vfs_calls'] <= 50 and
            counts['vfs_rejects'] == counts['vfs_calls'] - 1 and
            counts['fd_held'] == counts['vfs_rejects'] and
            counts['passes'] == counts['vfs_calls'] and
            counts['sleeps'] == counts['vfs_rejects'] and
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
    if '<EA' not in output or 'R' not in output:
        raise SystemExit('v1126: missing APR and late-RUN markers: ' +
                         output[-1000:])
    print('v1126: real APR fatal during post-commit EXEC FILE retry; '
          'unpublished post-VM RUN rollback, retained owner and WAIT PASS')
PY
