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
        raise ValueError('v1259: ambiguous provider fixture anchor')
    return source.replace(old, new, 1)


def inject(root):
    path = Path(root) / 'fs/fs_mres.s'
    proc_path = Path(root) / 'proc/proc_pdp6.s'
    source = path.read_text()
    proc_source = proc_path.read_text()

    source = replace_once(source, '''fs_provider_lock_retry:
        ; A foreign fatal event may wake a waiter before the provider lease''',
'''fs_provider_lock_retry:
        ; v1259 disposable held-provider ordering: the gateway cannot
        ; acquire the real provider lease before the intended PID 6 holder.
        ; Gate only once this gateway has actually entered its post-start
        ; timed sleep. INIT may not have armed the v1150 probe yet.
        move    0,proc_current_slot
        caie    0,4
        jrst    daimos_f07_gate_pass_v1259
        skipn   daimos_f07_gateway_started_v1259
        jrst    daimos_f07_gate_pass_v1259
        skipn   daimos_test_holder_enter_v1150
        jrst    daimos_f07_gate_wait_v1259
        jrst    daimos_f07_gate_pass_v1259
daimos_f07_gate_wait_v1259:
        movei   1,daimos_f07_gate_event_v1259
        pushj   17,proc_wait_event
        jrst    fs_provider_lock_retry
daimos_f07_gate_pass_v1259:
        ; A foreign fatal event may wake a waiter before the provider lease''')

    source = replace_once(source, '''        aos     daimos_test_holder_enter_v1150
        move    0,fs_provider_ready''',
'''        aos     daimos_test_holder_enter_v1150
        ; The holder owns the original serialized lease at this point.
        ; Publish that fact before waking PID 4 to contend normally.
        setom   daimos_f07_gate_event_v1259
        push    17,1
        movei   1,daimos_f07_gate_event_v1259
        pushj   17,proc_wakeup_event
        pop     17,1
        move    0,fs_provider_ready''')

    proc_source = replace_once(proc_source, '''daimos_test_not_init_v1150:
        caie    0,5                   ; unrelated runnable spinner''',
'''daimos_test_not_init_v1150:
        ; PID 4's first timed sleep follows its provider-start PIPE read.
        ; This explicit phase marker, not INIT's timer, gates only its
        ; subsequent provider request. No marker is needed for PID 6.
        caie    0,4
        jrst    daimos_f07_not_gateway_v1259
        setom   daimos_f07_gateway_started_v1259
daimos_f07_not_gateway_v1259:
        caie    0,5                   ; unrelated runnable spinner''')

    source += '''
        .bss
        .globl daimos_f07_gate_event_v1259
daimos_f07_gate_event_v1259: .block 1
        .globl daimos_f07_gateway_started_v1259
daimos_f07_gateway_started_v1259: .block 1
'''
    path.write_text(source)
    proc_path.write_text(proc_source)
