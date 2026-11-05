#!/usr/bin/env python3
"""Disposable PDP-6 hooks: true OOM while a foreign FS lease is held.

No production files are modified. This fixture suspends one real provider
call after acquiring its original lease, and later resumes the same stack.
"""

from pathlib import Path
import sys

root = Path(sys.argv[1])
enabled = sys.argv[2] == '1'


def patch(rel, old, new):
    p = root / rel
    source = p.read_text()
    assert source.count(old) == 1, ('v1150: nonunique hook', rel, old)
    p.write_text(source.replace(old, new, 1))


fs = 'fs/fs_mres.s'
proc = 'proc/proc_pdp6.s'
dispatch = 'proc/syscall_dispatch_pdp6.s'

patch(fs, '''        ; The missing-service trampoline already returns -1 normally.
        ; Invoke it under the same lease and use the common unlock path.''',
'''        ; Only in this disposable guest: slot 6 retains the *real*
        ; gateway lease while sleeping on its private executive stack.
        ; Return through the original fs_provider_unlock, never steal it.
        move    0,proc_current_slot
        caie    0,6
        jrst    daimos_test_fs_normal_v1150
        skipn   daimos_test_armed_v1150
        jrst    daimos_test_fs_normal_v1150
        aos     daimos_test_holder_enter_v1150
        move    0,fs_provider_ready
        movem   0,daimos_test_holder_lease_v1150
daimos_test_hold_loop_v1150:
        skipn   daimos_test_release_v1150
        jrst    daimos_test_hold_wait_v1150
        aos     daimos_test_holder_return_v1150
        seto    1,
        jrst    fs_provider_unlock
daimos_test_hold_wait_v1150:
        movei   1,daimos_test_hold_event_v1150
        pushj   17,proc_wait_event
        jrst    daimos_test_hold_loop_v1150
daimos_test_fs_normal_v1150:
        ; The missing-service trampoline already returns -1 normally.
        ; Invoke it under the same lease and use the common unlock path.''')

patch(fs, '''fs_provider_lock_sleep_v915:
        movei   1,fs_provider_wait_event_v917''',
'''fs_provider_lock_sleep_v915:
        move    0,proc_current_slot
        caie    0,4                   ; pre-dispatch waiter G
        jrst    daimos_test_wait_other_v1150
        aos     daimos_test_predispatch_v1150
daimos_test_wait_other_v1150:
        caie    0,3                   ; OOM owner normal EXIT case
        jrst    daimos_test_sleep_normal_v1150
        aos     daimos_test_ordinary_wait_v1150
daimos_test_sleep_normal_v1150:
        movei   1,fs_provider_wait_event_v917''')

patch(fs, '''fs_provider_lock_foreign_v1078:
        ; Fatal FILE close is already on the owner's private retry path.''',
'''fs_provider_lock_foreign_v1078:
        move    0,proc_current_slot
        caie    0,3                   ; only OOM requester
        jrst    daimos_test_foreign_other_v1150
        aos     daimos_test_fatal_busy_v1150
daimos_test_foreign_other_v1150:
        ; Fatal FILE close is already on the owner's private retry path.''')

p = root / fs
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_test_armed_v1150
daimos_test_armed_v1150: .block 1
        .globl daimos_test_holder_enter_v1150
daimos_test_holder_enter_v1150: .block 1
        .globl daimos_test_holder_lease_v1150
daimos_test_holder_lease_v1150: .block 1
        .globl daimos_test_holder_return_v1150
daimos_test_holder_return_v1150: .block 1
        .globl daimos_test_release_v1150
daimos_test_release_v1150: .block 1
        .globl daimos_test_hold_event_v1150
daimos_test_hold_event_v1150: .block 1
        .globl daimos_test_predispatch_v1150
daimos_test_predispatch_v1150: .block 1
        .globl daimos_test_fatal_busy_v1150
daimos_test_fatal_busy_v1150: .block 1
        .globl daimos_test_ordinary_wait_v1150
daimos_test_ordinary_wait_v1150: .block 1
''')

patch(proc, '''proc_sleep_ticks:
        hrrz    1,1''',
'''proc_sleep_ticks:
        move    0,proc_current_slot
        caie    0,1
        jrst    daimos_test_not_init_v1150
        setom   daimos_test_armed_v1150
        skipn   daimos_test_real_oom_v1150
        jrst    daimos_test_sleep_normal_v1150
        skipn   daimos_test_release_v1150
        jrst    daimos_test_maybe_release_v1150
        jrst    daimos_test_sleep_normal_v1150
daimos_test_maybe_release_v1150:
''' + ('''        move    0,daimos_test_fatal_busy_v1150
        caige   0,2
        jrst    daimos_test_sleep_normal_v1150
''' if enabled else '''        skipn   daimos_test_ordinary_wait_v1150
        jrst    daimos_test_sleep_normal_v1150
''') + '''        ; This is the *only* test-owned provider completion signal.
        ; Slot 6 returns on its private stack and unlocks normally.
        setom   daimos_test_release_v1150
        setom   daimos_test_hold_event_v1150
        push    17,1
        movei   1,daimos_test_hold_event_v1150
        pushj   17,proc_wakeup_event
        pop     17,1
        jrst    daimos_test_sleep_normal_v1150
daimos_test_not_init_v1150:
        caie    0,5                   ; unrelated runnable spinner
        jrst    daimos_test_sleep_normal_v1150
        skipn   daimos_test_holder_enter_v1150
        jrst    daimos_test_sleep_normal_v1150
        skipn   daimos_test_predispatch_v1150
        jrst    daimos_test_sleep_normal_v1150
        aos     daimos_test_spinner_v1150
daimos_test_sleep_normal_v1150:
        hrrz    1,1''')

p = root / proc
p.write_text('''        .globl daimos_test_armed_v1150
        .globl daimos_test_real_oom_v1150
        .globl daimos_test_release_v1150
        .globl daimos_test_hold_event_v1150
        .globl daimos_test_fatal_busy_v1150
        .globl daimos_test_ordinary_wait_v1150
        .globl daimos_test_holder_enter_v1150
        .globl daimos_test_predispatch_v1150
        .globl proc_wakeup_event
''' + p.read_text() + '''
        .bss
        .globl daimos_test_spinner_v1150
daimos_test_spinner_v1150: .block 1
''')

patch(dispatch, '''native_sys_brk:
        move    1,2
        pushj   17,vm_space_brk_current''',
'''native_sys_brk:
        move    1,2
        pushj   17,vm_space_brk_current
        ; AC1=-1 AND original AC2=-1 are required before counting a
        ; physical OOM. Preserve both production syscall result ACs.
        move    6,proc_current_slot
        caie    6,3
        jrst    daimos_test_brk_done_v1150
        camn    1,[-1]
        jrst    daimos_test_brk_cause_v1150
        jrst    daimos_test_brk_done_v1150
daimos_test_brk_cause_v1150:
        camn    2,[-1]
        jrst    daimos_test_brk_real_v1150
        jrst    daimos_test_brk_done_v1150
daimos_test_brk_real_v1150:
        aos     daimos_test_real_oom_v1150
        move    6,fs_provider_ready
        movem   6,daimos_test_lease_at_oom_v1150
        camn    6,[7,,0]              ; holder slot 6, owner encoded +1
        jrst    daimos_test_brk_waiter_v1150
        setom   daimos_test_error_v1150
daimos_test_brk_waiter_v1150:
        move    6,proc_table
        hrrz    7,016(6)             ; slot 4, scheduler word RH event
        caie    7,fs_provider_wait_event_v917
        setom   daimos_test_error_v1150
        hlrz    7,016(6)
        andi    7,0700000
        caie    7,0300000            ; SLEEP
        setom   daimos_test_error_v1150
        hrrz    7,024(6)             ; slot 6, private hold event
        caie    7,daimos_test_hold_event_v1150
        setom   daimos_test_error_v1150
daimos_test_brk_done_v1150:''')

p = root / dispatch
p.write_text('''        .globl fs_provider_ready
        .globl fs_provider_wait_event_v917
        .globl daimos_test_hold_event_v1150
        .globl proc_table
''' + p.read_text() + '''
        .bss
        .globl daimos_test_real_oom_v1150
daimos_test_real_oom_v1150: .block 1
        .globl daimos_test_lease_at_oom_v1150
daimos_test_lease_at_oom_v1150: .block 1
        .globl daimos_test_error_v1150
daimos_test_error_v1150: .block 1
''')
