; Real provider gateway, reservation list, both PURE scans, loader.
; Mock only process switching, file lookup/stat/data, and VM/attach leaves.
        .text
        .globl main
main:
        movei   1,1
        movem   1,case_v1933
        ; Reserve an executable while a prior physical mutation owns
        ; the lease. The wait oracle must observe no early publication.
        setzm   fs_provider_ready
        move    1,[060301012345]
        movei   2,r1_v1933
        movei   6,032
        movei   7,6
        pushj   17,fs_provider_reg_call
        jumpn   1,fail_v1933
        move    1,waits_v1933
        caie    1,1
        jrst    fail_v1933
        move    1,proc_exec_resv_head_v1933
        caie    1,r1_v1933
        jrst    fail_v1933
        movei   1,2
        movem   1,case_v1933
        move    1,[060301012345]
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    fail_v1933
        move    1,[060301012346]
        pushj   17,proc_swap_backing_busy
        jumpn   1,fail_v1933
        movei   1,3
        pushj   17,proc_swap_mount_busy
        caie    1,1
        jrst    fail_v1933
        movei   1,2
        pushj   17,proc_swap_mount_busy
        jumpn   1,fail_v1933
        ; Actual delayed mutation gateway must now refuse this vnode.
        movei   1,5
        movem   1,case_v1933
        movei   1,mutation_ok_v1933
        hrrm    1,fs_d6fs_service_jump
        move    1,[060301012345]
        movei   6,016
        movei   7,6
        pushj   17,fs_provider_reg_call
        jumpge  1,fail_v1933
        move    1,[060301012345]
        movei   6,013
        movei   7,6
        pushj   17,fs_provider_reg_call
        jumpge  1,fail_v1933
        move    1,[060301012346]
        movei   6,016
        movei   7,6
        pushj   17,fs_provider_reg_call
        jumpn   1,fail_v1933
        move    1,mutation_calls_v1933
        caie    1,1
        jrst    fail_v1933
        ; A quiescing physical mount may not admit a reservation.
        movei   1,3
        movem   1,case_v1933
        movei   1,020000
        movem   1,media_v1933+2
        move    1,[060301012345]
        movei   2,r2_v1933
        movei   6,032
        movei   7,6
        pushj   17,fs_provider_reg_call
        jumpge  1,fail_v1933
        skipe   r2_v1933+1
        jrst    fail_v1933
        setzm   media_v1933+2
        ; A second, independent load may overlap, then the first may
        ; finish out of order without dropping the second dependency.
        movei   1,4
        movem   1,case_v1933
        move    1,[040201076543]
        movei   2,r2_v1933
        movei   6,032
        movei   7,4
        pushj   17,fs_provider_reg_call
        jumpn   1,fail_v1933
        movei   1,r1_v1933
        pushj   17,proc_exec_release_v1933
        move    1,proc_exec_resv_head_v1933
        caie    1,r2_v1933
        jrst    fail_v1933
        skipe   r2_v1933
        jrst    fail_v1933
        move    1,[040201076543]
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    fail_v1933
        move    1,[060301012345]
        pushj   17,proc_swap_backing_busy
        jumpn   1,fail_v1933
        movei   1,r2_v1933
        pushj   17,proc_exec_release_v1933
        skipe   proc_exec_resv_head_v1933
        jrst    fail_v1933
        ; Loader cases: success, lookup failure, STAT failure,
        ; access failure, short header, NOMEM, payload and attach error.
        movei   010,0
load_loop_v1933:
        movem   010,mode_v1933
        movei   1,0100(010)
        movem   1,case_v1933
        movem   17,saved_stack_v1933
        movei   1,descriptor_v1933
        movei   2,1
        movei   3,1
        pushj   17,exec_load_process
        came    17,saved_stack_v1933
        jrst    fail_v1933
        move    2,mode_v1933
        jumpe   2,load_good_v1933
        cain    2,5
        jrst    load_nomem_v1933
        came    1,[-1]
        jrst    fail_v1933
        jrst    load_check_v1933
load_nomem_v1933:
        came    1,[-2]
        jrst    fail_v1933
        jrst    load_check_v1933
load_good_v1933:
        jumpn   1,fail_v1933
load_check_v1933:
        skipe   proc_exec_resv_head_v1933
        jrst    fail_v1933
        aoj     010,
        caig    010,7
        jrst    load_loop_v1933
        setz    1,
        popj    17,
fail_v1933:
        move    1,case_v1933
        popj    17,

mutation_ok_v1933:
        aos     mutation_calls_v1933
        jrst    kret_zero

        .globl proc_wait_event
proc_wait_event:
        skipe   proc_exec_resv_head_v1933
        jrst    invariant_v1933
        aos     waits_v1933
        setom   fs_provider_ready
        popj    17,
        .globl proc_wakeup_event
proc_wakeup_event:
        popj    17,

; All data/VM boundaries reached by loader must see the reservation.
; Preserve request ACs used by the mock leaves.
check_live_v1933:
        push    17,1
        push    17,2
        push    17,3
        move    1,[060301012345]
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    invariant_v1933
        movei   1,3
        pushj   17,proc_swap_mount_busy
        caie    1,1
        jrst    invariant_v1933
        pop     17,3
        pop     17,2
        pop     17,1
        popj    17,
invariant_v1933:
        ; Report an executed native assertion, not a timeout.
        move    1,case_v1933
        movem   1,__test_exit
        halt    .
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        jrst    invariant_v1933
        .globl file_lookup_path
file_lookup_path:
        move    3,mode_v1933
        caie    3,1
        jrst    lookup_ok_v1933
        jrst    kret_neg1
lookup_ok_v1933:
        move    1,[060301012345]
        movem   1,(2)
        jrst    kret_zero
        .globl vfs_stat
vfs_stat:
        pushj   17,check_live_v1933
        move    3,mode_v1933
        caie    3,2
        jrst    stat_ok_v1933
        jrst    kret_neg1
stat_ok_v1933:
        movei   3,2
        movem   3,(2)
        movei   3,5                    ; DXR1: 2 header + 2 image + 1 map
        movem   3,3(2)
        jrst    kret_zero
        .globl file_check_access
file_check_access:
        pushj   17,check_live_v1933
        move    3,mode_v1933
        caie    3,3
        jrst    kret_zero
        jrst    kret_neg1
        .globl file_check_root
file_check_root:
        jrst    kret_zero
        .globl vfs_read_words
vfs_read_words:
        pushj   17,check_live_v1933
        move    1,mode_v1933
        caie    1,4
        jrst    header_ok_v1933
        jrst    kret_neg1
header_ok_v1933:
        move    1,[0447062,,0]
        movem   1,(3)
        move    1,[2,,0]
        movem   1,1(3)
        movei   1,2
        popj    17,
        .globl vm_space_create
vm_space_create:
        pushj   17,check_live_v1933
        move    3,mode_v1933
        caie    3,5
        jrst    create_ok_v1933
        jrst    kret_neg1
create_ok_v1933:
        move    3,[04000,,02000]
        movem   3,1(1)
        jrst    kret_zero
        .globl vm_space_load_file
vm_space_load_file:
        pushj   17,check_live_v1933
        move    3,mode_v1933
        caie    3,6
        jrst    kret_zero
        jrst    kret_neg1
        .globl proc_swap_attach
proc_swap_attach:
        pushj   17,check_live_v1933
        move    3,mode_v1933
        caie    3,7
        jrst    kret_zero
        jrst    kret_neg1
        .globl vm_space_destroy
vm_space_destroy:
        pushj   17,check_live_v1933
        setom   1(1)
        jrst    kret_zero
        .globl d6codec_decode_vfs_v1458
d6codec_decode_vfs_v1458:
        jrst    invariant_v1933
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
proc_current_slot: .word 2
        .globl proc_current_ptr
proc_current_ptr: .word 0
        .globl file_table
file_table: .word 0
        .globl fs_provider_ready
fs_provider_ready: .word 1
        .globl fs_provider_wait_event_v917
fs_provider_wait_event_v917: .word 1
        .globl proc_high_slot
proc_high_slot: .word 1
        .globl proc_table
        .globl proc_swap_records
proc_table: .word 0
proc_swap_records: .word 0
        .globl vfs_mount_limit
vfs_mount_limit: .word 4
        .globl vfs_mount_root_base
vfs_mount_root_base: .word roots_v1933
roots_v1933:
        .word 0
        .word 040201000001
        .word 060301000001
        .word 0
        .globl dtfs_media_base
dtfs_media_base: .word media_v1933
        .globl proc_rt_owner
proc_rt_owner: .word 0
        .bss
        .globl vfs_mount_policy
vfs_mount_policy: .block 1
media_v1933: .block 4
r1_v1933: .block 2
r2_v1933: .block 2
case_v1933: .block 1
mode_v1933: .block 1
waits_v1933: .block 1
mutation_calls_v1933: .block 1
saved_stack_v1933: .block 1
descriptor_v1933: .block 3
        .globl __test_exit
__test_exit: .block 1
