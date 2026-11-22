#!/usr/bin/env python3
"""K03 v1802 source contract: accepted requester OOM, no foreign kill.

This is deliberately a narrow static guard, not a PDP-6 physical test.
"""
import os
from pathlib import Path
import re
import sys


def errors(dispatch, process):
    failures = []
    checks = (
        (dispatch, r'(?m)^\s*\.equ\s+PROC_OOM_BRK_ENABLED_V1000,1\s*$',
         'accepted requester-only OOM must remain enabled'),
        (dispatch, r'(?s)native_sys_brk:\s*move\s+1,2\s*'
         r'pushj\s+17,vm_space_brk_current\s*'
         r'\.equ\s+PROC_OOM_BRK_ENABLED_V1000,1\s*'
         r'\.if\s+PROC_OOM_BRK_ENABLED_V1000\s*'
         r'camn\s+1,\[-1\]\s*'
         r'jrst\s+native_sys_brk_check_cause_v1000\s*'
         r'popj\s+17,\s*'
         r'native_sys_brk_check_cause_v1000:\s*'
         r'camn\s+2,\[-1\]\s*'
         r'jrst\s+native_sys_brk_oom_v1000\s*'
         r'popj\s+17,\s*'
         r'native_sys_brk_oom_v1000:\s*'
         r'movei\s+1,1\s*'
         r'jrst\s+proc_fatal_close_current_v879\s*'
         r'\.endif\s*popj\s+17,',
         'BRK cause or current-owner fatal dispatch changed'),
        (process, r'(?s)proc_swap_victim:\s*.*?'
         r'proc_swap_victim_done:\s*.*?'
         r'proc_swap_victim_return:',
         'swap-only victim selector labels changed'),
    )
    for source, pattern, message in checks:
        if not re.search(pattern, source):
            failures.append(message)
    region = process.split('proc_swap_victim:', 1)[-1].split(
        'proc_swap_victim_return:', 1)[0]
    if re.search(r'\b(?:proc_fatal_close_current_v879|'
                 r'proc_event_apply|proc_finish_slot)\b', region):
        failures.append('swap selector unexpectedly calls fatal teardown')
    return failures


def main():
    root = Path(os.environ.get('DAIMOS_REPO',
                               str(Path.home() / 'git' / 'DAIMOS')))
    dispatch = (root / 'system/kernel/proc/syscall_dispatch_pdp6.s').read_text()
    process = (root / 'system/kernel/proc/proc_pdp6.s').read_text()
    assert not errors(dispatch, process), errors(dispatch, process)
    mutants = (
        (dispatch.replace('PROC_OOM_BRK_ENABLED_V1000,1',
                          'PROC_OOM_BRK_ENABLED_V1000,0', 1), process),
        (dispatch.replace('camn    2,[-1]', 'camn    2,[-2]', 1), process),
        (dispatch.replace('camn    1,[-1]', 'camn    1,[-2]', 1), process),
        (dispatch.replace('jrst    proc_fatal_close_current_v879',
                          'jrst    proc_swap_victim', 1), process),
        (dispatch, process.replace('proc_swap_victim_done:',
                   'pushj   17,proc_fatal_close_current_v879\n'
                   'proc_swap_victim_done:', 1)),
    )
    for index, pair in enumerate(mutants):
        assert errors(*pair), 'unsafe mutant %d escaped' % index
    print('K03 v1802 production requester-only OOM source contract PASS; '
          'five unsafe mutations rejected; no physical execution')


if __name__ == '__main__':
    try:
        main()
    except (OSError, AssertionError) as error:
        print('K03 v1802 FAIL:', error, file=sys.stderr)
        sys.exit(1)
