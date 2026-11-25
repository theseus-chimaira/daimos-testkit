; Actual gateway, RO policy, backing scanner and D6FS unlink leaf.
; Controlled wait publishes a foreign owner or RO policy at resume.
        .text
        .globl main
main:
        movei   1,provider_v1932
        hrrm    1,fs_d6fs_service_jump
        hrrm    1,fs_dtfs_service_jump
        movei   010,013
op_loop_v1932:
        movei   011,5
provider_loop_v1932:
        movei   012,0
case_loop_v1932:
        move    1,010
        lsh     1,6
        ior     1,011
        lsh     1,3
        ior     1,012
        movem   1,case_v1932
        setzm   record_v1932+1
        setzm   vfs_mount_policy
        setzm   dispatches_v1932
        setzm   wakes_v1932
        setzm   waits_v1932
        setzm   fs_provider_ready
        setzm   fs_provider_wait_event_v917
        move    1,011
        lsh     1,036
        ior     1,[000301012345]
        movem   1,node_v1932
        move    1,node_v1932
        movei   2,022
        movei   3,033
        movei   4,044
        movei   5,055
        move    6,010
        move    7,011
        movem   17,stack_v1932
        pushj   17,fs_provider_reg_call
        came    17,stack_v1932
        jrst    fail_v1932
        caie    012,1                 ; exact owner appears
        cain    012,2                 ; RO policy changes
        jrst    refused_v1932
        caie    1,012345
        jrst    fail_v1932
        move    1,dispatches_v1932
        caie    1,1
        jrst    fail_v1932
        jrst    check_release_v1932
refused_v1932:
        jumpge  1,fail_v1932
        skipe   dispatches_v1932
        jrst    fail_v1932
check_release_v1932:
        skipn   fs_provider_ready
        jrst    fail_v1932
        skipn   fs_provider_wait_event_v917
        jrst    fail_v1932
        move    1,wakes_v1932
        caie    1,1
        jrst    fail_v1932
        move    1,waits_v1932
        caie    1,1
        jrst    fail_v1932
        aoj     012,
        caig    012,3
        jrst    case_loop_v1932
        aoj     011,
        caig    011,6
        jrst    provider_loop_v1932
        caie    010,013
        jrst    unlink_cases_v1932
        movei   010,016
        jrst    op_loop_v1932
unlink_cases_v1932:
        ; Actual child is 012345; parent index 07 is not its identity.
        movei   1,07001
        movem   1,case_v1932
        move    1,[0700]
        lsh     1,026
        ior     1,[2,,012345]
        movem   1,record_v1932+1
        setzm   fcb_calls_v1932
        move    1,[060301000007]
        movei   2,0777
        pushj   17,d6fs_provider_unlink
        jumpge  1,fail_v1932
        skipe   fcb_calls_v1932
        jrst    fail_v1932
        movei   1,07002
        movem   1,case_v1932
        aos     record_v1932+1
        move    1,[060301000007]
        movei   2,0777
        pushj   17,d6fs_provider_unlink
        jumpge  1,fail_v1932
        move    1,fcb_calls_v1932
        caie    1,1
        jrst    fail_v1932
        setz    1,
        popj    17,
fail_v1932:
        move    1,case_v1932
        popj    17,
provider_v1932:
        aos     dispatches_v1932
        came    1,node_v1932
        jrst    kret_neg1
        caie    2,022
        jrst    kret_neg1
        caie    3,033
        jrst    kret_neg1
        caie    4,044
        jrst    kret_neg1
        caie    5,055
        jrst    kret_neg1
        came    6,010
        jrst    kret_neg1
        movei   1,012345
        popj    17,
        .globl proc_wait_event
proc_wait_event:
        aos     waits_v1932
        caie    012,2
        jrst    wait_owner_v1932
        movei   1,4
        movem   1,vfs_mount_policy
        jrst    wait_done_v1932
wait_owner_v1932:
        jumpe   012,wait_done_v1932
        movei   1,0700
        lsh     1,026
        ior     1,[2,,012345]
        cain    012,3
        addi    1,1
        movem   1,record_v1932+1
wait_done_v1932:
        setom   fs_provider_ready
        movei   1,0777
        move    2,1
        move    3,1
        move    4,1
        move    5,1
        move    6,1
        move    7,1
        popj    17,
        .globl proc_wakeup_event
proc_wakeup_event:
        aos     wakes_v1932
        popj    17,
        .globl d6fs_provider_scan_slot
d6fs_provider_scan_slot:
        movei   1,2
        movem   1,(3)
        movei   1,012345
        movem   1,7(4)
        jrst    kret_zero
        .globl d6fs_reader_fcb
d6fs_reader_fcb:
        aos     fcb_calls_v1932
        jrst    kret_neg1
        .globl fs_copy_words
        .globl fs_zero_words
        .globl d6fs_provider_dirent
        .globl d6fs_provider_write_dirent
        .globl d6fs_reader_put_fcb
        .globl d6fs_provider_free_file_tail
fs_copy_words:
fs_zero_words:
d6fs_provider_dirent:
d6fs_provider_write_dirent:
d6fs_reader_put_fcb:
d6fs_provider_free_file_tail:
        halt    .
        .globl fs_mres_no_service
        .globl kret_neg1
        .globl kret_zero
        .globl kret_neg5
fs_mres_no_service:
kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,
kret_neg5:
        movni   1,5
        popj    17,
        .data
        .globl kconst_7_7
kconst_7_7: .word 7,,7
        .globl proc_current_slot
proc_current_slot: .word 2
        .globl file_table
file_table: .word 0
        .globl fs_provider_ready
fs_provider_ready: .word 1
        .globl fs_provider_wait_event_v917
fs_provider_wait_event_v917: .word 1
        .globl proc_table
proc_table: .word ptable_v1932
        .globl proc_high_slot
proc_high_slot: .word 2
        .globl proc_swap_records
proc_swap_records: .word record_v1932
ptable_v1932:
        .block 3
        .word uarea_v1932,,0400000
        .word 04000,,02000
        .word 0300000,,0
        .globl vfs_mount_limit
vfs_mount_limit: .word 4
        .globl vfs_mount_root_base
vfs_mount_root_base: .word roots_v1932
roots_v1932:
        .word 0
        .word 0
        .word 060301000007
        .word 0
        .globl d6fs_active_reader
d6fs_active_reader: .word 040000
        .bss
        .globl vfs_mount_policy
vfs_mount_policy: .block 1
record_v1932: .block 2
uarea_v1932: .block 0410
case_v1932: .block 1
stack_v1932: .block 1
node_v1932: .block 1
dispatches_v1932: .block 1
waits_v1932: .block 1
wakes_v1932: .block 1
fcb_calls_v1932: .block 1
        .globl __test_exit
__test_exit: .block 1
