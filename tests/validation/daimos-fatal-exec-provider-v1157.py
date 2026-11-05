#!/usr/bin/env python3
"""Hold a real foreign FS lease during APR/EXEC/RUN in a copied kernel.

The original owner resumes on its private stack through the production
unlock path. A test-only BRK selector observes readiness and signals
completion; it does not change any ordinary BRK/EXEC/FILE behavior.
"""

from pathlib import Path
import sys

root = Path(sys.argv[1])

def patch(rel, before, after):
    p = root / rel
    s = p.read_text()
    assert s.count(before) == 1, ('v1157 anchor', rel, s.count(before))
    p.write_text(s.replace(before, after, 1))

patch('fs/fs_mres.s',
      '''        ; The missing-service trampoline already returns -1 normally.
        ; Invoke it under the same lease and use the common unlock path.''',
      '''        ; v1157: park only the foreign slot-3 owner, AFTER it has
        ; acquired the real filesystem provider gateway lease.
        move    0,proc_current_slot
        caie    0,3
        jrst    daimos_e10_normal_v1157
        aos     daimos_e10_holder_enter_v1157
        move    0,fs_provider_ready
        movem   0,daimos_e10_holder_lease_v1157
daimos_e10_holder_loop_v1157:
        skipn   daimos_e10_release_v1157
        jrst    daimos_e10_holder_wait_v1157
        aos     daimos_e10_holder_return_v1157
        seto    1,
        jrst    fs_provider_unlock
daimos_e10_holder_wait_v1157:
        movei   1,daimos_e10_holder_event_v1157
        pushj   17,proc_wait_event
        jrst    daimos_e10_holder_loop_v1157
daimos_e10_normal_v1157:
        ; The missing-service trampoline already returns -1 normally.
        ; Invoke it under the same lease and use the common unlock path.''')

p = root / 'fs/fs_mres.s'
p.write_text(p.read_text() + '''
        .bss
        .globl daimos_e10_holder_enter_v1157
daimos_e10_holder_enter_v1157: .block 1
        .globl daimos_e10_holder_lease_v1157
daimos_e10_holder_lease_v1157: .block 1
        .globl daimos_e10_holder_return_v1157
daimos_e10_holder_return_v1157: .block 1
        .globl daimos_e10_holder_event_v1157
daimos_e10_holder_event_v1157: .block 1
        .globl daimos_e10_release_v1157
daimos_e10_release_v1157: .block 1
''')

patch('proc/syscall_dispatch_pdp6.s',
      '''native_sys_brk:
        move    1,2
        pushj   17,vm_space_brk_current''',
      '''native_sys_brk:
        camn    2,[0777750]
        jrst    daimos_e10_probe_v1157
        camn    2,[0777751]
        jrst    daimos_e10_resume_v1157
        move    1,2
        pushj   17,vm_space_brk_current''')

p = root / 'proc/syscall_dispatch_pdp6.s'
p.write_text(p.read_text() + '''
        .text
        .globl daimos_e10_holder_enter_v1157
        .globl daimos_e10_holder_lease_v1157
        .globl daimos_e10_holder_return_v1157
        .globl daimos_e10_holder_event_v1157
        .globl daimos_e10_release_v1157
        .globl fs_provider_ready
        .globl proc_wakeup_event
daimos_e10_probe_v1157:
        skipn   daimos_e10_holder_enter_v1157
        jrst    daimos_e10_not_ready_v1157
        skipn   daimos_e10_holder_return_v1157
        jrst    daimos_e10_probe_lease_v1157
        jrst    daimos_e10_not_ready_v1157
daimos_e10_probe_lease_v1157:
        move    1,fs_provider_ready
        camn    1,[4,,0]
        jrst    daimos_e10_ready_v1157
daimos_e10_not_ready_v1157:
        setz    1,
        popj    17,
daimos_e10_ready_v1157:
        movei   1,1
        popj    17,
daimos_e10_resume_v1157:
        skipn   daimos_e10_holder_enter_v1157
        jrst    daimos_e10_resume_fail_v1157
        skipn   daimos_e10_holder_return_v1157
        jrst    daimos_e10_resume_ok_v1157
daimos_e10_resume_fail_v1157:
        seto    1,
        popj    17,
daimos_e10_resume_ok_v1157:
        setom   daimos_e10_release_v1157
        setom   daimos_e10_holder_event_v1157
        movei   1,daimos_e10_holder_event_v1157
        pushj   17,proc_wakeup_event
        setz    1,
        popj    17,
''')
