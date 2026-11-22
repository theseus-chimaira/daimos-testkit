#!/usr/bin/env python3
"""Instrument copied v1796 PDP-6 VFS and fatal FILE/HUP ownership.

The VFS SYNC refusal is deliberately a synthetic -5 return at the
existing provider-dispatch boundary, NOT organic D6FS media damage.
Every guest call still uses normal file_close_entry and FILE slots.
Only use a versioned copied kernel tree; never patch production.
"""
from pathlib import Path
import sys


def replace_one(text, old, new):
    if text.count(old) != 1:
        raise ValueError('anchor count %d for %r' %
                         (text.count(old), old[:100]))
    return text.replace(old, new, 1)


def fixture(kernel):
    if kernel.name != 'kernel' or 'v1796' not in str(kernel):
        raise ValueError('expected copied versioned v1796 kernel tree')
    vfs = kernel / 'fs/vfs.s'
    proc = kernel / 'proc/proc_pdp6.s'
    source = vfs.read_text()
    source = replace_one(source, '''vfs_sync:
        ldb     7,[POINT 6,1,5]''', '''vfs_sync:
        ; v1796 scratch: refuse only INIT's RUN child PID 2 FD6 vnode.
        .globl  proc_current_slot
        push    17,2
        move    2,proc_current_slot
        caie    2,2
        jrst    k04_sync_real_v1796
        move    2,file_table
        jumpe   2,k04_sync_real_v1796
        move    2,014(2)              ; FD6's actual packed vnode
        jumpe   2,k04_sync_real_v1796
        tlz     2,700070             ; canonical vnode identity
        came    1,2
        jrst    k04_sync_real_v1796
        aos     k04_sync_calls_v1796
        move    2,file_table
        move    2,-2(2)              ; original private u-area FDCTL
        trnn    2,4                  ; PROC_FATAL_CLOSE_BIT
        aos     k04_sync_mismatch_v1796
        move    2,k04_sync_calls_v1796
        caile   2,012                ; ten injected refused syncs
        jrst    k04_sync_accepted_v1796
        aos     k04_sync_refused_v1796
        pop     17,2
        movni   1,5                  ; synthetic VFS_SYNC -5 only
        popj    17,
k04_sync_accepted_v1796:
        aos     k04_sync_delegated_v1796
        jrst    k04_sync_real_v1796
k04_sync_real_v1796:
        pop     17,2
        ldb     7,[POINT 6,1,5]''')
    source += '''
; v1796 scratch VFS provider refusal diagnostics only.
        .bss
        .globl  k04_sync_calls_v1796
k04_sync_calls_v1796:      .block 1
        .globl  k04_sync_refused_v1796
k04_sync_refused_v1796:    .block 1
        .globl  k04_sync_delegated_v1796
k04_sync_delegated_v1796:  .block 1
        .globl  k04_sync_mismatch_v1796
k04_sync_mismatch_v1796:   .block 1
'''
    vfs.write_text(source)

    s = proc.read_text()
    s = replace_one(s, '''proc_session_teardown:
        push    17,010''', '''proc_session_teardown:
        ; v1796 scratch observe HUP sequencing after FILE success.
        .globl  k04_sync_calls_v1796
        push    17,1
        move    1,proc_current_slot
        caie    1,2
        jrst    k04_session_normal_v1796
        aos     k04_session_calls_v1796
        move    1,k04_sync_calls_v1796
        caie    1,013                 ; eleven calls: 10 errors + success
        aos     k04_session_bad_v1796
        move    1,file_table
        jumpe   1,k04_session_bad_fd_v1796
        skipn   014(1)                ; exact FD6 cleared on accepted SYNC
        jrst    k04_session_normal_v1796
k04_session_bad_fd_v1796:
        aos     k04_session_bad_v1796
k04_session_normal_v1796:
        pop     17,1
        push    17,010''')
    s += '''
; v1796 scratch session ordering witnesses; no permanent KCORE words.
        .bss
        .globl  k04_session_calls_v1796
k04_session_calls_v1796:    .block 1
        .globl  k04_session_bad_v1796
k04_session_bad_v1796:      .block 1
'''
    proc.write_text(s)
    print('v1796 disposable provider refusal and FILE/HUP ordering hooks')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: fixture-v1796.py COPIED_KERNEL_DIR')
    fixture(Path(sys.argv[1]))
