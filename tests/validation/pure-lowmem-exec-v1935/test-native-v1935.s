; Native destructive EXEC: actual loader, attach, gateway, reservation,
; mapping hold and busy scans. Controlled allocation, transfer and startup.
        .text
        .globl main
main:
        movei   010,0
case_loop:
        movem   010,mode
        movei   1,0100(010)
        movem   1,case_no
        move    1,[uarea,,0400123]
        movem   1,descriptor
        move    1,[04000,,02000]
        movem   1,descriptor+1
        move    1,[0200345,,0]
        movem   1,descriptor+2
        move    1,[000234567123]
        movem   1,uarea+066
        movei   1,2
        movem   1,uarea+024
        setzm   records+1
        setzm   freed
        setzm   proc_rt_owner
        movem   17,saved_stack
        movei   1,launch
        movei   2,5
        setz    3,
        movei   4,result
        pushj   17,exec_replace_current_lowmem
        came    17,saved_stack
        jrst    fail
        move    5,mode
        jumpe   5,check_success
        came    1,[-2]
        jrst    fail
        jrst    check_failure
check_success:
        jumpn   1,fail
        move    1,result
        caie    1,021
        jrst    fail
        move    1,records+1
        came    1,expected_record
        jrst    fail
        move    1,[060301012345]
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    fail
        movei   1,3
        pushj   17,proc_swap_mount_busy
        caie    1,1
        jrst    fail
        move    1,uarea+066
        came    1,[014234567123]
        jrst    fail
        jrst    common
check_failure:
        skipe   records+1
        jrst    fail
        move    1,descriptor+1
        came    1,[-1]
        jrst    fail
common:
        move    1,descriptor
        came    1,[uarea,,0400123]
        jrst    fail
        move    1,descriptor+2
        came    1,[0200345,,0]
        jrst    fail
        skipe   uarea+024
        jrst    fail
        skipe   proc_exec_resv_head_v1933
        jrst    fail
        move    1,freed
        caie    1,1
        jrst    fail
        aoj     010,
        caig    010,6
        jrst    case_loop
        setz    1,
        popj    17,
fail:
        move    1,case_no
        movem   1,__test_exit
        halt    .
check_live:
        push    17,1
        move    1,descriptor
        came    1,[uarea,,0400123]
        jrst    fail
        move    1,descriptor+2
        came    1,[0200345,,0]
        jrst    fail
        move    1,uarea+024
        trnn    1,2
        jrst    fail
        pop     17,1
        popj    17,
        .globl mm_alloc
mm_alloc:
        move    5,-1(17)
        movei   6,launch_copy
        movem   6,(5)
        jrst    kret_zero
        .globl mm_free
mm_free:
        caie    1,launch_copy
        jrst    fail
        aos     freed
        jrst    kret_zero
        .globl fs_copy_words
fs_copy_words:
        hrl     2,1
        addi    3,launch_copy-1
        blt     2,(3)
        popj    17,
        .globl proc_slot_ptr
proc_slot_ptr:
        movei   1,descriptor
        popj    17,
        .globl proc_wait_event
proc_wait_event:
        jrst    fail
        .globl proc_wakeup_event
proc_wakeup_event:
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        jrst    fail
        .globl file_lookup_path
file_lookup_path:
        pushj   17,check_live
        move    3,mode
        caie    3,1
        jrst    lookup_ok
        jrst    kret_neg1
lookup_ok:
        move    1,[060301012345]
        movem   1,(2)
        jrst    kret_zero
        .globl vfs_stat
vfs_stat:
        pushj   17,check_live
        move    3,mode
        caie    3,2
        jrst    stat_ok
        jrst    kret_neg1
stat_ok:
        movei   3,2
        movem   3,(2)
        movei   3,010                  ; DXR2: 3 + 4 + 1
        movem   3,3(2)
        jrst    kret_zero
        .globl file_check_access
file_check_access:
        .globl file_check_root
file_check_root:
        jrst    kret_zero
        .globl vfs_read_words
vfs_read_words:
        pushj   17,check_live
        move    1,mode
        caie    1,3
        jrst    header_ok
        jrst    kret_neg1
header_ok:
        jumpn   2,tx2
        move    1,[0447062,,1]
        movem   1,(3)
        move    1,[4,,0200000]
        movem   1,1(3)
        movei   1,2
        popj    17,
tx2:
        move    1,[2,,0647022]
        movem   1,(3)
        movei   1,1
        popj    17,
        .globl vm_space_create
vm_space_create:
        pushj   17,check_live
        move    3,mode
        caie    3,4
        jrst    create_ok
        jrst    kret_neg1
create_ok:
        move    3,[04000,,03000]
        movem   3,1(1)
        jrst    kret_zero
        .globl vm_space_load_file
vm_space_load_file:
        pushj   17,check_live
        move    3,mode
        caie    3,5
        jrst    kret_zero
        jrst    kret_neg1
        .globl vm_space_destroy
vm_space_destroy:
        caie    1,descriptor
        jrst    fail
        setom   1(1)
        setzm   records+1
        move    3,uarea+066
        tlz     3,017000
        movem   3,uarea+066
        jrst    kret_zero
        .globl vm_space_startup
vm_space_startup:
        pushj   17,check_live
        move    1,records+1
        came    1,expected_record
        jrst    fail
        move    1,[060301012345]
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    fail
        move    1,mode
        caie    1,6
        jrst    startup_ok
        jrst    kret_neg1
startup_ok:
        movei   1,01000
        movem   1,3(4)
        jrst    kret_zero
        .globl d6codec_decode_vfs_v1458
d6codec_decode_vfs_v1458:
        jrst    fail
        .globl fs_mres_no_service
        .globl kret_neg1
        .globl kret_neg5
        .globl kret_zero
fs_mres_no_service:
kret_neg1:
        seto    1,
        popj    17,
kret_neg5:
        movni   1,5
        popj    17,
kret_zero:
        setz    1,
        popj    17,
        .data
        .globl kconst_1_1
        .globl kconst_7_7
kconst_1_1: .word 1,,1
kconst_7_7: .word 7,,7
        .globl proc_current_slot
proc_current_slot: .word 1
        .globl proc_current_ptr
proc_current_ptr: .word descriptor
        .globl file_table
file_table: .word 0
        .globl fs_provider_ready
fs_provider_ready: .word 1
        .globl fs_provider_wait_event_v917
fs_provider_wait_event_v917: .word 1
        .globl proc_high_slot
proc_high_slot: .word 2
        .globl proc_table
proc_table: .word descriptor-3
        .globl proc_swap_records
proc_swap_records: .word records
        .globl vfs_mount_limit
vfs_mount_limit: .word 4
        .globl vfs_mount_root_base
vfs_mount_root_base: .word roots
roots:
        .word 0
        .word 0
        .word 060301000001
        .word 0
        .globl dtfs_media_base
dtfs_media_base: .word media
        .globl proc_rt_owner
proc_rt_owner: .word 0
expected_record: .word 000042012345
launch: .word 1,,5
        .word 0
        .word 0
        .word 1
        .word 060000000000
        .bss
        .globl vfs_mount_policy
vfs_mount_policy: .block 1
media: .block 4
descriptor: .block 3
uarea: .block 0410
records: .block 2
launch_copy: .block 020
result: .block 6
mode: .block 1
case_no: .block 1
saved_stack: .block 1
freed: .block 1
        .globl __test_exit
__test_exit: .block 1
