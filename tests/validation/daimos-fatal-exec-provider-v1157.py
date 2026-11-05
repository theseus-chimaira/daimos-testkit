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
      '''        ; v1157: park only the foreign slot-4 owner, AFTER it has
        ; acquired the real filesystem provider gateway lease.
        move    0,proc_current_slot
        caie    0,4
        jrst    daimos_e10_normal_v1157
        aos     daimos_e10_holder_enter_v1157
        move    0,fs_provider_ready
        movem   0,daimos_e10_holder_lease_v1157
        ; Wake the unfinished, private-stack RUN fdmap failure only
        ; after the original filesystem gateway lease is occupied.
        setom   daimos_e10_run_event_v1157
        movei   1,daimos_e10_run_event_v1157
        pushj   17,proc_wakeup_event
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

patch('fs/fs_mres.s',
      '''fs_provider_lock_foreign_v1078:
        ; Fatal FILE close is already on the owner's private retry path.''',
      '''fs_provider_lock_foreign_v1078:
        move    0,proc_current_slot
        caie    0,2                   ; actual fatal EXEC owner
        jrst    daimos_e10_other_closer_v1157
        aos     daimos_e10_foreign_busy_v1157
daimos_e10_other_closer_v1157:
        ; Fatal FILE close is already on the owner's private retry path.''')

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
        .globl daimos_e10_run_armed_v1157
daimos_e10_run_armed_v1157: .block 1
        .globl daimos_e10_run_event_v1157
daimos_e10_run_event_v1157: .block 1
        .globl daimos_e10_foreign_busy_v1157
daimos_e10_foreign_busy_v1157: .block 1
''')

# FILE_CLOSE_ALL continues past a refused FD0 and would otherwise
# close FD3 before the holder is admitted. Keep this *real* D6FS FILE
# live during the staging window only; after the holder enters, use
# the original vfs_sync unmodified so its actual foreign-lock refusal
# is mandatory for acceptance. This never fabricates the final event.
patch('fs/file_runtime.s',
      '''daimos_test_vfs_call_v890:
        pushj   17,vfs_sync''',
      '''daimos_test_vfs_call_v890:
        move    0,proc_current_slot
        caie    0,2
        jrst    daimos_e10_sync_real_v1157
        move    0,file_table
        addi    0,6                 ; FD 3: two words per descriptor
        came    0,010               ; real descriptor being closed
        jrst    daimos_e10_sync_real_v1157
        skipn   daimos_e10_holder_enter_v1157
        jrst    daimos_e10_stage_fd3_v1157
        aos     daimos_e10_fd3_after_v1157
daimos_e10_sync_real_v1157:
        pushj   17,vfs_sync
        jrst    daimos_e10_sync_done_v1157
daimos_e10_stage_fd3_v1157:
        aos     daimos_e10_fd3_stage_v1157
        movni   1,5                ; temporary, pre-holder staging
daimos_e10_sync_done_v1157:''')

p = root / 'fs/file_runtime.s'
p.write_text('''        .globl daimos_e10_holder_enter_v1157
''' + p.read_text() + '''
        .bss
        .globl daimos_e10_fd3_stage_v1157
daimos_e10_fd3_stage_v1157: .block 1
        .globl daimos_e10_fd3_after_v1157
daimos_e10_fd3_after_v1157: .block 1
''')

patch('proc/proc_run.s',
      '''proc_run_fdmap_bad:
        move    5,proc_current_slot''',
      '''proc_run_fdmap_bad:
        ; The late unpublished RUN has already reached its real
        ; fdmap failure. The foreign holder was admitted beforehand;
        ; wake it now, and keep this RUN owner on its private stack.
        move    0,proc_current_slot
        caie    0,1
        jrst    daimos_e10_run_regular_v1157
        setom   daimos_e10_run_armed_v1157
daimos_e10_run_wait_v1157:
        skipn   daimos_e10_holder_enter_v1157
        jrst    daimos_e10_run_sleep_v1157
        jrst    daimos_e10_run_regular_v1157
daimos_e10_run_sleep_v1157:
        movei   1,daimos_e10_run_event_v1157
        pushj   17,proc_wait_event
        jrst    daimos_e10_run_wait_v1157
daimos_e10_run_regular_v1157:
        move    5,proc_current_slot''')

p = root / 'proc/proc_run.s'
p.write_text('''        .globl daimos_e10_run_armed_v1157
        .globl daimos_e10_run_event_v1157
        .globl daimos_e10_holder_enter_v1157
        .globl proc_wait_event
''' + p.read_text())

patch('proc/syscall_dispatch_pdp6.s',
      '''native_sys_brk:
        move    1,2
        pushj   17,vm_space_brk_current''',
      '''native_sys_brk:
        camn    2,[0777750]
        jrst    daimos_e10_probe_v1157
        camn    2,[0777751]
        jrst    daimos_e10_resume_v1157
        camn    2,[0777752]
        jrst    daimos_e10_armed_probe_v1157
        camn    2,[0777753]
        jrst    daimos_e10_busy_probe_v1157
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
        .globl daimos_e10_run_armed_v1157
        .globl daimos_e10_foreign_busy_v1157
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
        camn    1,[5,,0]
        jrst    daimos_e10_ready_v1157
daimos_e10_not_ready_v1157:
        setz    1,
        popj    17,
daimos_e10_ready_v1157:
        movei   1,1
        popj    17,
daimos_e10_armed_probe_v1157:
        skipn   daimos_e10_run_armed_v1157
        jrst    daimos_e10_not_ready_v1157
        movei   1,1
        popj    17,
daimos_e10_busy_probe_v1157:
        move    1,daimos_e10_foreign_busy_v1157
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
