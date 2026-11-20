#!/usr/bin/env python3
"""Fault probes for copied v1729 PDP-6 kernel sources only.

No production code is patched. The source-linked D6FS provider and MM
release routines are real; only designated errors are injected.
"""

from pathlib import Path
import sys


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1729-hook.py COPIED_KERNEL_ROOT')
    root = Path(sys.argv[1])

    def patch(rel, before, after):
        path = root / rel
        source = path.read_text()
        n = source.count(before)
        if n != 1:
            raise SystemExit('v1729: patch anchor %s count %d: %r' %
                             (rel, n, before[:95]))
        path.write_text(source.replace(before, after, 1))

    # The original v907 hook physically pins job1 before fatal HUP.
    # Replace the synthetic second-member refusal with its real event
    # dispatch. The D6FS provider below must reject job2's FILE FD3.
    patch('proc/proc_pdp6.s',
          '''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        jrst    proc_session_teardown_fail''',
          '''daimos_test_fail_second_v907:
        aos     daimos_test_failures_v907
        jrst    daimos_test_deliver_v907''')

    patch('proc/proc_pdp6.s',
          '''proc_session_teardown_fail:
        seto    1,''',
          '''proc_session_teardown_fail:
        move    4,daimos_test_leader_v907
        caie    4,2                     ; exact attached session leader
        jrst    daimos_sess_fail_done_v1729
        aos     daimos_sess_fails_v1729
        move    4,proc_table
        move    5,014(4)               ; job2 slot4 descriptor
        hlrz    5,5
        jumpe   5,daimos_sess_bad_label_v1729
        skipn   034(5)                 ; job2 FD3 still owned
        jrst    daimos_sess_bad_label_v1729
        move    6,024(5)               ; original fatal FILE owner bit
        trnn    6,PROC_FATAL_CLOSE_BIT
        jrst    daimos_sess_bad_label_v1729
        move    5,011(4)               ; job1 slot3 META
        trnn    5,PROC_TRANSITION_RH
        jrst    daimos_sess_bad_label_v1729
        move    5,012(4)               ; job1 VM_NONE
        camn    5,[-1]
        jrst    daimos_sess_fail_done_v1729
daimos_sess_bad_label_v1729:
        aos     daimos_sess_bad_v1729
daimos_sess_fail_done_v1729:
        seto    1,''')

    # A protected private fatal FILE owner is refused before foreign
    # FILE close. Retain a separate count of unsafe deferred delivery
    # so a deferred HUP cannot masquerade as a session refusal.
    patch('proc/proc_pdp6.s',
          '''proc_event_fatal_other:
        ; Once a fatal event is pending''',
          '''proc_event_fatal_other:
        move    4,010
        caie    4,4
        jrst    daimos_foreign_done_v1729
        aos     daimos_foreign_v1729
daimos_foreign_done_v1729:
        ; Once a fatal event is pending''')
    patch('proc/proc_pdp6.s',
          '''proc_event_fatal_other_defer_term_v926:
        hlrz    1,(012)''',
          '''proc_event_fatal_other_defer_term_v926:
        move    4,010
        caie    4,4
        jrst    daimos_defer_done_v1729
        aos     daimos_defer_v1729
daimos_defer_done_v1729:
        hlrz    1,(012)''')
    patch('proc/proc_pdp6.s',
          '''proc_event_fatal_other_close_fail_v867:
        pop     17,012''',
          '''proc_event_fatal_other_close_fail_v867:
        move    4,010
        caie    4,4
        jrst    daimos_closefail_done_v1729
        aos     daimos_closefail_v1729
daimos_closefail_done_v1729:
        pop     17,012''')
    patch('fs/file_runtime.s',
          '''file_close_all_at_v865:
        push    17,010''',
          '''file_close_all_at_v865:
        aos     daimos_fdclose_v1729
        push    17,010''')

    # The owner side of job2's ordinary EXIT and later fatal APR
    # continuation calls the real serialized D6FS provider. The
    # subsequent session-wide HUP must refuse this protected owner.
    patch('fs/d6fs_runtime.s',
          '''d6fs_provider_sync:
        jrst    kret_zero''',
          '''d6fs_provider_sync:
        aos     daimos_syncall_v1729
        ; Target the real owner-side job2 FILE FD3.
        move    2,proc_current_slot
        caie    2,4
        jrst    kret_zero
        move    2,file_table
        jumpe   2,kret_zero
        move    2,06(2)                ; job2 FD3 first descriptor word
        jumpe   2,kret_zero
        tlz     2,700070               ; canonical v417 vnode
        came    1,2
        jrst    kret_zero
        aos     daimos_provcalls_v1729
        hlrz    2,fs_provider_ready
        caie    2,5                     ; owner slot4+1 holds the lease
        aos     daimos_leasebad_v1729
        hrrz    2,fs_provider_ready
        jumpe   2,daimos_leaseok_label_v1729
        aos     daimos_leasebad_v1729
daimos_leaseok_label_v1729:
        aos     daimos_leaseok_v1729
        aos     daimos_provrefuse_v1729
        seto    1,
        popj    17,''')

    # Target slot5 only. Force the first staged loader to return NOMEM,
    # so production takes the actual lowmem path and destroys the old
    # VM; then fail only the replacement loader after real VM_NONE.
    patch('proc/exec_lowmem_pdp6.s',
          '''        pushj   17,exec_load_process
        movem   1,EXEC_R_STAGED+2(17)''',
          '''        move    4,proc_current_slot
        caie    4,5
        jrst    daimos_exec_normal_stage_v1729
        aos     daimos_exec_nmem_v1729
        movni   1,2
        jrst    daimos_exec_stage_done_v1729
daimos_exec_normal_stage_v1729:
        pushj   17,exec_load_process
daimos_exec_stage_done_v1729:
        movem   1,EXEC_R_STAGED+2(17)''')
    patch('proc/exec_lowmem_pdp6.s',
          '''exec_lowmem_old_gone:
        move    10,EXEC_LM_LAUNCH(17)''',
          '''exec_lowmem_old_gone:
        move    4,proc_current_slot
        caie    4,5
        jrst    daimos_exec_postvm_done_v1729
        aos     daimos_exec_postvm_v1729
        move    4,1(15)
        camn    4,[-1]
        jrst    daimos_exec_postvm_done_v1729
        aos     daimos_exec_bad_v1729
daimos_exec_postvm_done_v1729:
        move    10,EXEC_LM_LAUNCH(17)''')
    patch('proc/exec_lowmem_pdp6.s',
          '''        move    1,15
        move    2,14
        move    3,10
        pushj   17,exec_load_process
        move    16,1''',
          '''        move    4,proc_current_slot
        caie    4,5
        jrst    daimos_exec_load_normal_v1729
        aos     daimos_exec_failed_v1729
        seto    1,
        jrst    daimos_exec_load_done_v1729
daimos_exec_load_normal_v1729:
        move    1,15
        move    2,14
        move    3,10
        pushj   17,exec_load_process
daimos_exec_load_done_v1729:
        move    16,1''')

    patch('proc/proc_pdp6.s',
          '''proc_fatal_close_current_v879:
        ; User APR and EXEC fatal traps require a live current u-area.''',
          '''proc_fatal_close_current_v879:
        move    4,proc_current_slot
        caie    4,5
        jrst    daimos_exec_fatal_done_v1729
        aos     daimos_exec_fatal_v1729
        move    4,proc_current_ptr
        move    4,1(4)
        camn    4,[-1]
        jrst    daimos_exec_fatal_done_v1729
        aos     daimos_exec_bad_v1729
daimos_exec_fatal_done_v1729:
        ; User APR and EXEC fatal traps require a live current u-area.''')

    # Fixed resident witnesses. D6FS is movable, so never define the
    # provider counters in its MRES image.
    for rel, names in (
            ('proc/proc_pdp6.s',
             ('sess_fails', 'sess_bad', 'exec_fatal',
              'foreign', 'defer', 'closefail')),
            ('proc/exec_lowmem_pdp6.s',
             ('exec_nmem', 'exec_postvm', 'exec_failed', 'exec_bad')),
            ('fs/fs_mres.s',
             ('provcalls', 'provrefuse', 'leaseok', 'leasebad',
              'fdclose', 'syncall'))):
        path = root / rel
        source = path.read_text()
        for short in names:
            symbol = 'daimos_' + short + '_v1729'
            if symbol + ':' in source:
                raise SystemExit('v1729: duplicate ' + symbol)
            source += ('\n        .bss\n        .globl ' + symbol +
                       '\n' + symbol + ': .block 1\n')
        path.write_text(source)


if __name__ == '__main__':
    main()
