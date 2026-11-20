#!/usr/bin/env python3
"""K03 requester OOM and irreversible owner teardown source contract.

This is a mutation-checked static gate, not a physical OOM test.  It
deliberately does not assert eventual progress of a rejecting provider.
"""

import os
from pathlib import Path


root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
dispatch = (root / 'proc/syscall_dispatch_pdp6.s').read_text()
proc = (root / 'proc/proc_pdp6.s').read_text()


def between(source, first, last):
    assert source.count(first) == 1, first
    return source.split(first, 1)[1].split(last, 1)[0]


def validate(disp, process):
    brk = between(disp, 'native_sys_brk:', '; Root may rebind')
    fatal = between(process, 'proc_fatal_close_current_v879:',
                    'proc_fatal_close_no_owner_v879:')
    exit_owner = between(process, 'proc_exit_current:',
                         'proc_exit_release_failed:')
    finish = between(process, 'proc_finish_common_v932:',
                     'proc_finish_restore:')
    checks = (
        '.equ    PROC_OOM_BRK_ENABLED_V1000,1' in brk,
        'camn    1,[-1]' in brk,
        'camn    2,[-1]' in brk,
        'jrst    proc_fatal_close_current_v879' in brk,
        (brk.find('camn    2,[-1]') >= 0 and
         brk.find('jrst    proc_fatal_close_current_v879') >= 0 and
         brk.find('camn    2,[-1]') < brk.find(
             'jrst    proc_fatal_close_current_v879')),
        fatal.index('pushj   17,file_close_all') < fatal.index(
            'pushj   17,proc_session_teardown') < fatal.index(
            'jrst    proc_exit_current'),
        'jumpn   1,proc_fatal_close_wait_v995' in fatal,
        'jumpe   1,proc_fatal_close_done_v879' in fatal,
        'pushj   17,proc_sleep_ticks' in fatal,
        'caige   1,01000               ; cap at 512 ticks' in fatal,
        'jrst    proc_fatal_close_retry_v879' in fatal,
        'PROC_FINALIZE_MARK_LH+PROC_FINALIZE_PREVM_LH' in exit_owner,
        (exit_owner.find('movem   6,PROC_FINALIZE_OFFSET(5)') >= 0 and
         exit_owner.find('pushj   17,mach_pi_disable') < exit_owner.find(
             'movem   6,PROC_FINALIZE_OFFSET(5)') < exit_owner.find(
             'move    17,mach_kernel_stack_base')),
        'pushj   17,proc_tty_release_session' in finish,
        'pushj   17,vm_space_destroy' in finish,
        'jumpn   1,proc_finish_prevm_fail_v1081' in finish,
        'pushj   17,proc_finish_mark_pending_v892' in finish,
        'pushj   17,proc_uarea_release' in finish,
        'jumpn   1,proc_finish_defer_uarea_v881' in finish,
        'PROC_FINALIZE_MARK_LH+PROC_FINALIZE_PREVM_LH' in finish,
    )
    return all(checks)


assert validate(dispatch, proc), 'current K03 owner contract failed'
mutations = (
    ('dispatch', 'PROC_OOM_BRK_ENABLED_V1000,1',
     'PROC_OOM_BRK_ENABLED_V1000,0'),
    ('dispatch', 'camn    2,[-1]', 'camn    2,[-2]'),
    ('dispatch', 'jrst    proc_fatal_close_current_v879',
     'jrst    proc_exit_current'),
    ('proc', 'jumpn   1,proc_fatal_close_wait_v995',
     'jumpe   1,proc_fatal_close_wait_v995'),
    ('proc', 'jumpe   1,proc_fatal_close_done_v879',
     'jumpn   1,proc_fatal_close_done_v879'),
    ('proc', 'caige   1,01000               ; cap at 512 ticks',
     'caige   1,010000               ; cap at 512 ticks'),
    ('proc', 'movem   6,PROC_FINALIZE_OFFSET(5)',
     'setzm   PROC_FINALIZE_OFFSET(5)'),
    ('proc', 'jumpn   1,proc_finish_prevm_fail_v1081',
     'jumpe   1,proc_finish_prevm_fail_v1081'),
    ('proc', 'jumpn   1,proc_finish_defer_uarea_v881',
     'jumpe   1,proc_finish_defer_uarea_v881'),
)
for target, old, new in mutations:
    original = dispatch if target == 'dispatch' else proc
    assert old in original, ('missing mutation anchor', old)
    changed = original.replace(old, new, 1)
    args = (changed, proc) if target == 'dispatch' else (dispatch, changed)
    assert not validate(*args), ('unsafe mutation accepted', old)

print('v1731: requester-only BRK, private FILE/HUP retry, atomic PREVM '
      'handoff, VM/u-area quarantine; 9 unsafe mutations rejected PASS')
print('v1731: source contract only; no physical or permanent-refusal '
      'reclamation claim')
