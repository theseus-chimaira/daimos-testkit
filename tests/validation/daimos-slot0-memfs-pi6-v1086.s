; Real MEMFS provider, XIP release, and PDP-6 MM unpin in slot 0.
; The serialized provider's lease is intentionally held by a foreign
; process: the VM XIP operation must use MEMFS's direct dispatch and
; must not consult or wait on that lease or a scheduler clock tick.
        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__extent
        movei 6,026              ; FS_MRES_OP_XIP_RELEASE
        movei 7,4                ; MEMFS, unshared direct path
        pushj 17,fs_provider_reg_call
        caie 1,1
        jrst fail_1_v1086
        skipn memfs_xip_refs
        jrst check_pin_v1086
        jrst fail_2_v1086
check_pin_v1086:
        move 1,mm_extents+1
        camn 1,[03000005]        ; MM pin count went from 1 to 0
        jrst check_lock_v1086
        jrst fail_3_v1086
check_lock_v1086:
        move 1,fs_provider_ready
        camn 1,[3,,0]           ; foreign owner still owns the lease
        jrst check_wait_v1086
        jrst fail_4_v1086
check_wait_v1086:
        skipn __wait_calls
        jrst check_dispatch_v1086
        jrst fail_5_v1086
check_dispatch_v1086:
        move 1,__dispatch_calls
        caie 1,1
        jrst fail_6_v1086

        ; Repeat a released XIP base. It is not MEMFS-owned anymore,
        ; so return zero without touching the MM extent or lease.
        movei 1,__extent
        movei 6,026
        movei 7,4
        pushj 17,fs_provider_reg_call
        jumpn 1,fail_7_v1086
        move 1,__dispatch_calls
        caie 1,2
        jrst fail_8_v1086

        ; The same slot-0 caller entering a foreign-held serialized
        ; provider must refuse immediately (-5), never sleep or unlock.
        movei 1,__extent
        movei 6,026
        movei 7,5
        pushj 17,fs_provider_reg_call
        camn 1,[-5]
        jrst check_foreign_v1086
        jrst fail_9_v1086
check_foreign_v1086:
        move 1,fs_provider_ready
        camn 1,[3,,0]
        jrst check_no_wait_v1086
        jrst fail_10_v1086
check_no_wait_v1086:
        skipn __wait_calls
        jrst success_v1086
        jrst fail_11_v1086
success_v1086:
        setz 1,
        jrst done_v1086
fail_1_v1086: movei 1,1
        jrst done_v1086
fail_2_v1086: movei 1,2
        jrst done_v1086
fail_3_v1086: movei 1,3
        jrst done_v1086
fail_4_v1086: movei 1,4
        jrst done_v1086
fail_5_v1086: movei 1,5
        jrst done_v1086
fail_6_v1086: movei 1,6
        jrst done_v1086
fail_7_v1086: movei 1,7
        jrst done_v1086
fail_8_v1086: movei 1,010
        jrst done_v1086
fail_9_v1086: movei 1,011
        jrst done_v1086
fail_10_v1086: movei 1,012
        jrst done_v1086
fail_11_v1086: movei 1,013
done_v1086:
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
