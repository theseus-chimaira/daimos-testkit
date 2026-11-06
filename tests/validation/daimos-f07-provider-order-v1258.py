#!/usr/bin/env python3
"""Deterministically order the *test-only* foreign provider lease.

Under 24 live PDP-6 processes, the historical 010- versus 0200-tick
user delays do not guarantee which process enters the serialized provider
first. A guest where gateway PID 4 acquires the lease before holder PID 6
cannot exercise the requested PID-6 owner/OOM failure matrix.

This injection is applied only to disposable V1207_TEST_SWAPSLOTS guests,
after the original v1150 provider/held-owner probe was installed. No
production filesystem, scheduler, or pipe behavior is modified.
"""

from pathlib import Path


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('v1258: ambiguous provider fixture anchor')
    return source.replace(old, new, 1)


def inject(root):
    path = Path(root) / 'fs/fs_mres.s'
    source = path.read_text()

    source = replace_once(source, '''fs_provider_lock_retry:
        ; A foreign fatal event may wake a waiter before the provider lease''',
'''fs_provider_lock_retry:
        ; v1258 disposable held-provider ordering: the gateway cannot
        ; acquire the real provider lease before the intended PID 6 holder.
        ; Do not gate the initial RUN loader before INIT arms the test.
        move    0,proc_current_slot
        caie    0,4
        jrst    daimos_f07_gate_pass_v1258
        skipn   daimos_test_armed_v1150
        jrst    daimos_f07_gate_pass_v1258
        skipn   daimos_test_holder_enter_v1150
        jrst    daimos_f07_gate_wait_v1258
        jrst    daimos_f07_gate_pass_v1258
daimos_f07_gate_wait_v1258:
        movei   1,daimos_f07_gate_event_v1258
        pushj   17,proc_wait_event
        jrst    fs_provider_lock_retry
daimos_f07_gate_pass_v1258:
        ; A foreign fatal event may wake a waiter before the provider lease''')

    source = replace_once(source, '''        aos     daimos_test_holder_enter_v1150
        move    0,fs_provider_ready''',
'''        aos     daimos_test_holder_enter_v1150
        ; The holder owns the original serialized lease at this point.
        ; Publish that fact before waking PID 4 to contend normally.
        setom   daimos_f07_gate_event_v1258
        push    17,1
        movei   1,daimos_f07_gate_event_v1258
        pushj   17,proc_wakeup_event
        pop     17,1
        move    0,fs_provider_ready''')

    source += '''
        .bss
        .globl daimos_f07_gate_event_v1258
daimos_f07_gate_event_v1258: .block 1
'''
    path.write_text(source)
