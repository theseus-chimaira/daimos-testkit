; v1108: MEMFS owns an XIP base even when the MM pin count is wrong.
; A failed physical unpin must not drop the ref or acquire a foreign
; serialized provider lease. A genuine mm_pin repairs the extent.
        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        move 1,[03000005]        ; same extent, pin field cleared
        movem 1,mm_extents+1
        movei 1,__extent
        movei 6,026
        movei 7,4
        pushj 17,fs_provider_reg_call
        camn 1,[-4]
        jrst check_ref_v1108
        jrst fail_1_v1108
check_ref_v1108:
        move 1,memfs_xip_refs
        camn 1,[1,,1]
        jrst check_mm_v1108
        jrst fail_2_v1108
check_mm_v1108:
        move 1,mm_extents+1
        camn 1,[03000005]
        jrst repair_v1108
        jrst fail_3_v1108
repair_v1108:
        movei 1,__extent
        pushj 17,mm_pin
        jumpn 1,fail_4_v1108
        move 1,mm_extents+1
        camn 1,[013000005]
        jrst retry_v1108
        jrst fail_5_v1108
retry_v1108:
        movei 1,__extent
        movei 6,026
        movei 7,4
        pushj 17,fs_provider_reg_call
        caie 1,1
        jrst fail_6_v1108
        skipn memfs_xip_refs
        jrst check_released_mm_v1108
        jrst fail_7_v1108
check_released_mm_v1108:
        move 1,mm_extents+1
        camn 1,[03000005]
        jrst check_repeat_v1108
        jrst fail_8_v1108
check_repeat_v1108:
        movei 1,__extent
        movei 6,026
        movei 7,4
        pushj 17,fs_provider_reg_call
        jumpn 1,fail_9_v1108
        move 1,__dispatch_calls
        caie 1,3
        jrst fail_10_v1108
        move 1,fs_provider_ready
        camn 1,[3,,0]
        jrst check_nowait_v1108
        jrst fail_11_v1108
check_nowait_v1108:
        skipn __wait_calls
        jrst success_v1108
        jrst fail_12_v1108
success_v1108:
        setz 1,
        jrst done_v1108
fail_1_v1108: movei 1,1
        jrst done_v1108
fail_2_v1108: movei 1,2
        jrst done_v1108
fail_3_v1108: movei 1,3
        jrst done_v1108
fail_4_v1108: movei 1,4
        jrst done_v1108
fail_5_v1108: movei 1,5
        jrst done_v1108
fail_6_v1108: movei 1,6
        jrst done_v1108
fail_7_v1108: movei 1,7
        jrst done_v1108
fail_8_v1108: movei 1,010
        jrst done_v1108
fail_9_v1108: movei 1,011
        jrst done_v1108
fail_10_v1108: movei 1,012
        jrst done_v1108
fail_11_v1108: movei 1,013
        jrst done_v1108
fail_12_v1108: movei 1,014
done_v1108:
        movem 1,__test_exit
        jrst 4,0

; This test service only vets the XIP operation/register convention.
; The complete XIP release body and MM unpin come from production.
        .globl xip_service_v1086
xip_service_v1086:
        aos __dispatch_calls
        caie 6,026
        jrst fail_service_v1086
        jumpe 7,xip_service_valid_v1086
fail_service_v1086:
        halt .
xip_service_valid_v1086:
        jrst memfs_mres_reg_dispatch

        .globl memfs_mres_mount
memfs_mres_mount:
        halt .                  ; unrelated operation must not run
        .globl memfs_mres_xip_admit
memfs_mres_xip_admit:
        halt .
        .globl memfs_mres_space
memfs_mres_space:
        halt .
        .globl fs_mres_context_vector_dispatch
fs_mres_context_vector_dispatch:
        halt .

        .globl proc_wait_event
proc_wait_event:
        aos __wait_calls
        halt .                   ; a slot-0 clock wait is forbidden
        .globl proc_wakeup_event
proc_wakeup_event:
        halt .                   ; no provider lease may be released
        .globl fs_mres_no_service
fs_mres_no_service:
        seto 1,
        popj 17,
        .globl kret_neg5
kret_neg5:
        movni 1,5
        popj 17,

        .data
        .globl proc_current_slot
proc_current_slot: .word 0
        .globl file_table
file_table: .word 0
        .globl fs_provider_ready
fs_provider_ready: .word 3,,0
        .globl fs_provider_wait_event_v917
fs_provider_wait_event_v917: .word 0
        .globl kconst_7_7
kconst_7_7: .word 7,,7
        .globl memfs_mres_fs
memfs_mres_fs: .word __nodes
        .word 0
        .word 0
__nodes:
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word __extent,,0
        .block 7*3
        .globl memfs_mres_vector
memfs_mres_vector: .word 0
        .globl memfs_xip_refs
memfs_xip_refs: .word 1,,1
        .block 3
        .globl mm_extents
mm_extents: .word 016,,__extent
        .word 013000005
        .globl mm_extent_count
mm_extent_count: .word 1
__dispatch_calls: .word 0
__wait_calls: .word 0
__extent: .block 016
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
