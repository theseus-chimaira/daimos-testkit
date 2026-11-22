#!/usr/bin/env python3
"""Build scratch-only K04 v1798 physical session-HUP fault witnesses.

Input A: a copied v1798 production kernel tree to modify.
Input B: v1796's already accepted copied VFS SYNC fixture source.
All changes stay under versioned scratch trees. No actual MM/FILE
production code is modified by this test generator.
"""
from pathlib import Path
import sys


def once(source, before, after):
    if source.count(before) != 1:
        raise ValueError('anchor drift: count=%d, %s' %
                         (source.count(before), before[:90]))
    return source.replace(before, after, 1)


def generate_v1798(kernel, prior_vfs):
    if kernel.name != 'kernel' or 'v1798' not in str(kernel):
        raise ValueError('expected copied v1798 scratch kernel')
    vfs_file = kernel / 'fs/vfs.s'
    source = prior_vfs.read_text()
    if source.count('k04_sync_calls_v1796') < 3:
        raise ValueError('v1796 accepted VFS fixture missing')
    source = once(source,
                  '        caie    2,2\n'
                  '        jrst    k04_sync_real_v1796',
                  '        caie    2,3\n'
                  '        jrst    k04_sync_real_v1796')
    source = source.replace('v1796', 'v1798')
    source = source.replace("INIT's RUN child PID 2 FD6",
                            "INIT's session member PID 3 FD6")
    vfs_file.write_text(source)

    proc_file = kernel / 'proc/proc_pdp6.s'
    source = proc_file.read_text()
    source = once(source,
                  'proc_session_teardown:\n        push    17,010',
                  '''proc_session_teardown:
        ; v1798: count only a real PID2 leader's HUP preflight.
        caie    1,2
        jrst    k04_hup_enter_real_v1798
        aos     k04_hup_calls_v1798
k04_hup_enter_real_v1798:
        push    17,010''')
    source = once(source,
                  '''proc_session_teardown_deliver_v905:
        move    1,011''',
                  '''proc_session_teardown_deliver_v905:
        ; Witness actual attempts to signal the live session member.
        caie    011,3
        jrst    k04_hup_deliver_real_v1798
        aos     k04_hup_targets_v1798
        move    5,(012)
        trnn    5,0400000             ; stable u-area required
        jrst    k04_hup_deliver_real_v1798
        hlrz    5,5
        move    5,PROC_FDCTL_OFFSET(5)
        trne    5,04                 ; fatal private FILE owner
        aos     k04_hup_protected_v1798
k04_hup_deliver_real_v1798:
        move    1,011''')
    source = once(source,
                  '''proc_session_teardown_fail:
        seto    1,''',
                  '''proc_session_teardown_fail:
        caie    010,2
        jrst    k04_hup_fail_real_v1798
        aos     k04_hup_fails_v1798
        move    5,proc_tty_records    ; CTY0 session owner must persist
        andi    5,0377               ; RH also holds foreground PGRP
        caie    5,2
        aos     k04_hup_bad_v1798
k04_hup_fail_real_v1798:
        seto    1,''')
    source = once(source,
                  '''proc_session_teardown_ok:
        setz    1,''',
                  '''proc_session_teardown_ok:
        caie    010,2
        jrst    k04_hup_ok_real_v1798
        aos     k04_hup_success_v1798
        move    5,proc_tty_records
        andi    5,0377               ; cleared after final HUP/TTY reset
        jumpe   5,k04_hup_ok_real_v1798
        aos     k04_hup_bad_v1798
k04_hup_ok_real_v1798:
        setz    1,''')
    source += '''
; v1798 scratch HUP/TTY ordering witnesses, no production kernel RAM.
        .bss
        .globl  k04_hup_calls_v1798
k04_hup_calls_v1798:      .block 1
        .globl  k04_hup_fails_v1798
k04_hup_fails_v1798:      .block 1
        .globl  k04_hup_success_v1798
k04_hup_success_v1798:    .block 1
        .globl  k04_hup_bad_v1798
k04_hup_bad_v1798:        .block 1
        .globl  k04_hup_targets_v1798
k04_hup_targets_v1798:    .block 1
        .globl  k04_hup_protected_v1798
k04_hup_protected_v1798:  .block 1
'''
    proc_file.write_text(source)
    print('v1798 scratch PID3 FD6 synthetic SYNC refusal and '
          'PID2 HUP/TTY witnesses installed')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: fixture-v1798.py KERNEL_DIR V1796_VFS_S')
    generate_v1798(Path(sys.argv[1]), Path(sys.argv[2]))
