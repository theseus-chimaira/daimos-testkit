#!/usr/bin/env python3
"""Scratch-only real-MM VM_NONE+DISCARD session-member fault fixture.

Usage: fixture-v1799.py COPIED_V1799_KERNEL

The RUN failure occurs only after inherited session construction.
The u-area MM pin is real; vm_space_destroy and mm_free are original.
This generator does not create fake process-table/finalizer state.
"""
from pathlib import Path
import sys


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('source drift at %r: %d' %
                         (old[:100], text.count(old)))
    return text.replace(old, new, 1)


def generate(kernel):
    if kernel.name != 'kernel' or 'v1799' not in str(kernel):
        raise ValueError('requires copied v1799 kernel tree')
    run_file = kernel / 'proc/proc_run.s'
    s = run_file.read_text()
    s = once(s, '''        pushj   17,proc_child_hierarchy
        jumpn   1,proc_run_hierarchy_bad

        skipn   7,file_table''',
             '''        pushj   17,proc_child_hierarchy
        jumpn   1,proc_run_hierarchy_bad
        ; v1799: the inherited session is now real and stable.
        ; Only the first PID3 construction fails after hierarchy.
        caie    012,3
        jrst    k04_run_after_hierarchy_v1799
        skipn   k04_run_injected_v1799
        jrst    k04_run_inject_v1799
k04_run_after_hierarchy_v1799:
        skipn   7,file_table''')
    s = once(s, 'proc_run_hierarchy_bad:\n',
             '''k04_run_inject_v1799:
        setom   k04_run_injected_v1799
        jrst    proc_run_hierarchy_bad
proc_run_hierarchy_bad:
''')
    s += '''
; v1799 scratch-only first RUN failure after session inheritance.
        .bss
        .globl  k04_run_injected_v1799
k04_run_injected_v1799:  .block 1
'''
    run_file.write_text(s)

    proc_file = kernel / 'proc/proc_pdp6.s'
    s = proc_file.read_text()
    s = once(s, '''        push    17,10
        move    10,2
        addi    1,01000                ; PROC_UAREA_MM_OWNER_BASE''',
             '''        push    17,10
        move    10,2
        ; v1799: pin the real PID3 rollback u-area, not its VM.
        caie    1,3
        jrst    k04_uarea_real_v1799
        skipn   k04_uarea_done_v1799
        jrst    k04_uarea_active_v1799
        jrst    k04_uarea_real_v1799
k04_uarea_active_v1799:
        skipn   5,k04_uarea_base_v1799
        jrst    k04_uarea_first_v1799
        came    5,4
        jrst    k04_uarea_bad_v1799
        aos     5,k04_uarea_calls_v1799
        caige   5,014               ; twelve real free attempts
        jrst    k04_uarea_prepare_v1799
        move    1,4
        pushj   17,mm_unpin
        jumpn   1,k04_uarea_bad_v1799
        setzm   k04_uarea_base_v1799
        setom   k04_uarea_done_v1799
        jrst    k04_uarea_prepare_v1799
k04_uarea_first_v1799:
        move    1,4
        pushj   17,mm_pin
        jumpn   1,k04_uarea_bad_v1799
        hlrz    4,(10)
        movem   4,k04_uarea_base_v1799
        movei   5,1
        movem   5,k04_uarea_calls_v1799
k04_uarea_prepare_v1799:
        movei   1,3
        hlrz    4,(10)
        jrst    k04_uarea_real_v1799
k04_uarea_bad_v1799:
        movni   1,4
        pop     17,10
        popj    17,
k04_uarea_real_v1799:
        addi    1,01000                ; PROC_UAREA_MM_OWNER_BASE''')
    s = once(s, '''proc_session_teardown_deliver_v905:
        move    1,011''',
             '''proc_session_teardown_deliver_v905:
        ; v1799: count actual HUP delivery to DISCARD member.
        caie    010,2
        jrst    k04_discard_deliver_real_v1799
        caie    011,3
        jrst    k04_discard_deliver_real_v1799
        aos     k04_discard_deliver_v1799
        move    5,1(012)
        camn    5,[-1]               ; VM_SPACE_NONE
        jrst    k04_discard_vmnone_v1799
        aos     k04_discard_bad_v1799
        jrst    k04_discard_deliver_real_v1799
k04_discard_vmnone_v1799:
        hlrz    5,(012)
        move    5,PROC_FINALIZE_OFFSET(5)
        and     5,[0600000,,0]      ; FINALIZE|DISCARD, not EXIT
        came    5,[0600000,,0]
        aos     k04_discard_bad_v1799
        aos     k04_discard_seen_v1799
k04_discard_deliver_real_v1799:
        move    1,011''')
    s = once(s, '''proc_session_teardown_fail:
        seto    1,''',
             '''proc_session_teardown_fail:
        caie    010,2
        jrst    k04_discard_fail_real_v1799
        aos     k04_discard_fails_v1799
        move    5,proc_tty_records
        andi    5,0377
        caie    5,2
        aos     k04_discard_bad_v1799
k04_discard_fail_real_v1799:
        seto    1,''')
    s = once(s, '''proc_session_teardown_ok:
        setz    1,''',
             '''proc_session_teardown_ok:
        caie    010,2
        jrst    k04_discard_ok_real_v1799
        aos     k04_discard_success_v1799
        move    5,proc_tty_records
        andi    5,0377
        jumpe   5,k04_discard_ok_real_v1799
        aos     k04_discard_bad_v1799
k04_discard_ok_real_v1799:
        setz    1,''')
    s += '''
; v1799 scratch-only real MM and DISCARD/HUP ordering witnesses.
        .bss
        .globl  k04_uarea_base_v1799
k04_uarea_base_v1799:       .block 1
        .globl  k04_uarea_calls_v1799
k04_uarea_calls_v1799:      .block 1
        .globl  k04_uarea_done_v1799
k04_uarea_done_v1799:       .block 1
        .globl  k04_discard_deliver_v1799
k04_discard_deliver_v1799:  .block 1
        .globl  k04_discard_seen_v1799
k04_discard_seen_v1799:     .block 1
        .globl  k04_discard_fails_v1799
k04_discard_fails_v1799:    .block 1
        .globl  k04_discard_success_v1799
k04_discard_success_v1799:  .block 1
        .globl  k04_discard_bad_v1799
k04_discard_bad_v1799:      .block 1
'''
    proc_file.write_text(s)
    print('v1799 scratch real MM u-area pin and post-hierarchy RUN '
          'rollback/HUP instrumentation installed')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: fixture-v1799.py COPIED_KERNEL')
    generate(Path(sys.argv[1]))
