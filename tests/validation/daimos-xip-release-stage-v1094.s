; P0-D v1094: real VM/XIP release functions and fault-stage transitions.
; These leaves are extracted verbatim from the production PDP-6 sources.
        .text
        .globl main
        .globl __test_exit
        .globl vm_space_destroy
        .globl memfs_mres_xip_release
        .globl proc_storage_expect_v30
        .globl fs_provider_reg_call
        .globl proc_swap_detach
        .globl mm_free
        .globl memfs_xip_owns_base
        .globl memfs_xip_unpin_base
        .globl kconst_2_2
        .globl provider_result_v1094
        .globl mm_calls_v1094
        .globl detach_calls_v1094
        .globl error_v1094
        .globl stage_v1094
        .globl extent_owned_v1094
        .globl descriptor_v1094
        .globl stage_v1094
        .globl descriptor_v1094
        .globl provider_result_v1094
        .globl provider_calls_v1094
        .globl mm_calls_v1094
        .globl detach_calls_v1094
        .globl extent_owned_v1094
        .globl swap_owned_v1094
        .globl error_v1094

main:
        ; Owned MEMFS XIP: an invalid unpin must not be retried as
        ; MM_TYPE_PROCESS or destroy the slot's VM/backing ownership.
        pushj   17,reset_v1094
        movei   0,1
        movem   0,stage_v1094
        setom   xip_owned_v1094
        setom   unpin_result_v1094
        pushj   17,destroy_v1094
        camn    1,[-1]
        jrst    check_owned_error_v1094
        jrst    fail_v1094
check_owned_error_v1094:
        move    0,provider_result_v1094
        camn    0,[-4]
        jrst    check_owned_still_v1094
        jrst    fail_v1094
check_owned_still_v1094:
        skipn   mm_calls_v1094
        jrst    check_owned_detach_v1094
        jrst    fail_v1094
check_owned_detach_v1094:
        skipn   detach_calls_v1094
        jrst    check_owned_ref_v1094
        jrst    fail_v1094
check_owned_ref_v1094:
        skipn   xip_owned_v1094
        jrst    fail_v1094
        move    0,descriptor_v1094+1
        came    0,[04000,,012000]
        jrst    fail_v1094

        ; Same owned XIP is now repaired. A legitimate owner-side retry
        ; unpins once, detaches once, and finally publishes VM_NONE.
        movei   0,2
        movem   0,stage_v1094
        setzm   unpin_result_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1094
        move    0,descriptor_v1094+1
        camn    0,[-1]
        jrst    check_recovered_v1094
        jrst    fail_v1094
check_recovered_v1094:
        skipn   xip_owned_v1094
        jrst    check_recovered_mm_v1094
        jrst    fail_v1094
check_recovered_mm_v1094:
        skipn   mm_calls_v1094
        jrst    check_recovered_detach_v1094
        jrst    fail_v1094
check_recovered_detach_v1094:
        move    0,detach_calls_v1094
        caie    0,1
        jrst    fail_v1094

        ; A loaded MEMFS returning 0 means the base is a normal process
        ; extent, for which the MM_TYPE_PROCESS fallback is legitimate.
        pushj   17,reset_v1094
        movei   0,3
        movem   0,stage_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1094
        move    0,provider_result_v1094
        jumpn   0,fail_v1094
        pushj   17,check_process_freed_v1094
        jumpn   1,fail_v1094

        ; The unloaded MEMFS gateway returns -1: only this legacy
        ; absence code is permitted to fall back to process MM free.
        pushj   17,reset_v1094
        movei   0,4
        movem   0,stage_v1094
        setzm   provider_mode_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1094
        move    0,provider_result_v1094
        camn    0,[-1]
        jrst    unloaded_allowed_v1094
        jrst    fail_v1094
unloaded_allowed_v1094:
        pushj   17,check_process_freed_v1094
        jumpn   1,fail_v1094

        ; A future MEMFS -5 busy code also denotes an owned release
        ; refusal, not an invitation to try a different MM type.
        pushj   17,reset_v1094
        movei   0,5
        movem   0,stage_v1094
        movei   0,2
        movem   0,provider_mode_v1094
        pushj   17,destroy_v1094
        camn    1,[-1]
        jrst    check_busy_guard_v1094
        jrst    fail_v1094
check_busy_guard_v1094:
        skipn   mm_calls_v1094
        jrst    check_busy_detach_v1094
        jrst    fail_v1094
check_busy_detach_v1094:
        skipn   detach_calls_v1094
        jrst    check_busy_vm_v1094
        jrst    fail_v1094
check_busy_vm_v1094:
        move    0,descriptor_v1094+1
        came    0,[04000,,012000]
        jrst    fail_v1094

        ; MM -4 is not committed: no swap detach, no VM_NONE, and the
        ; owner can retry when its original metadata is repaired.
        pushj   17,reset_v1094
        movei   0,6
        movem   0,stage_v1094
        movni   0,4
        movem   0,mm_result_v1094
        pushj   17,destroy_v1094
        camn    1,[-1]
        jrst    check_mm_invalid_v1094
        jrst    fail_v1094
check_mm_invalid_v1094:
        skipn   detach_calls_v1094
        jrst    check_mm_owner_v1094
        jrst    fail_v1094
check_mm_owner_v1094:
        skipn   extent_owned_v1094
        jrst    fail_v1094
        move    0,descriptor_v1094+1
        came    0,[04000,,012000]
        jrst    fail_v1094
        setzm   mm_result_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1094
        move    0,mm_calls_v1094
        caie    0,2
        jrst    fail_v1094
        move    0,detach_calls_v1094
        caie    0,1
        jrst    fail_v1094

        ; A pinned process MM -5 also retains the original VM/base,
        ; and a later valid release commits only on successful retry.
        pushj   17,reset_v1094
        movei   0,7
        movem   0,stage_v1094
        movni   0,5
        movem   0,mm_result_v1094
        pushj   17,destroy_v1094
        camn    1,[-1]
        jrst    check_mm_busy_v1094
        jrst    fail_v1094
check_mm_busy_v1094:
        skipn   detach_calls_v1094
        jrst    check_mm_busy_owner_v1094
        jrst    fail_v1094
check_mm_busy_owner_v1094:
        skipn   extent_owned_v1094
        jrst    fail_v1094
        setzm   mm_result_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1094
        move    0,mm_calls_v1094
        caie    0,2
        jrst    fail_v1094
        move    0,detach_calls_v1094
        caie    0,1
        jrst    fail_v1094

        ; A disk-backed process has no physical MM base. A failed
        ; swap-bitmap detach retains its original record and VM state.
        pushj   17,reset_v1094
        movei   0,010
        movem   0,stage_v1094
        movei   0,1
        movem   0,storage_mode_v1094
        movni   0,1
        movem   0,detach_result_v1094
        move    0,[04000,,0]
        movem   0,descriptor_v1094+1
        pushj   17,destroy_v1094
        camn    1,[-1]
        jrst    check_disk_refused_v1094
        jrst    fail_v1094
check_disk_refused_v1094:
        skipn   mm_calls_v1094
        jrst    check_disk_owner_v1094
        jrst    fail_v1094
check_disk_owner_v1094:
        skipn   swap_owned_v1094
        jrst    fail_v1094
        move    0,descriptor_v1094+1
        came    0,[04000,,0]
        jrst    fail_v1094
        setzm   detach_result_v1094
        pushj   17,destroy_v1094
        jumpn   1,fail_v1094
        move    0,descriptor_v1094+1
        camn    0,[-1]
        jrst    check_disk_done_v1094
        jrst    fail_v1094
check_disk_done_v1094:
        skipn   swap_owned_v1094
        jrst    check_disk_count_v1094
        jrst    fail_v1094
check_disk_count_v1094:
        move    0,detach_calls_v1094
        caie    0,2
        jrst    fail_v1094
        skipn   error_v1094
        jrst    success_v1094
        jrst    fail_v1094
success_v1094:
        setz    1,
        popj    17,

fail_v1094:
        move    1,stage_v1094
        popj    17,

reset_v1094:
        move    0,[04000,,012000]
        movem   0,descriptor_v1094+1
        movei   0,1
        movem   0,provider_mode_v1094
        setzm   storage_mode_v1094
        setzm   mm_result_v1094
        setzm   detach_result_v1094
        setzm   unpin_result_v1094
        setzm   xip_owned_v1094
        setzm   mm_calls_v1094
        setzm   detach_calls_v1094
        setzm   unpin_calls_v1094
        setzm   provider_calls_v1094
        setzm   provider_result_v1094
        setzm   error_v1094
        setom   extent_owned_v1094
        setom   swap_owned_v1094
        popj    17,

destroy_v1094:
        movei   1,descriptor_v1094
        movei   2,2
        pushj   17,vm_space_destroy
        popj    17,

check_process_freed_v1094:
        move    0,mm_calls_v1094
        caie    0,1
        jrst    bad_process_free_v1094
        move    0,detach_calls_v1094
        caie    0,1
        jrst    bad_process_free_v1094
        skipn   extent_owned_v1094
        jrst    process_extent_free_v1094
        jrst    bad_process_free_v1094
process_extent_free_v1094:
        move    0,descriptor_v1094+1
        camn    0,[-1]
        jrst    good_process_free_v1094
bad_process_free_v1094:
        seto    1,
        popj    17,
good_process_free_v1094:
        setz    1,
        popj    17,

; Stub leafs provide exact MM and backing error codes and maintain their
; resource-owner witnesses. No simulated failure may silently clear one.
proc_storage_expect_v30:
        caie    1,2
        jrst    invariant_v1094
        came    2,storage_mode_v1094
        jrst    absent_storage_v1094
        setz    1,
        popj    17,
absent_storage_v1094:
        seto    1,
        popj    17,

fs_provider_reg_call:
        aos     provider_calls_v1094
        caie    6,026
        jrst    invariant_v1094
        caie    7,4
        jrst    invariant_v1094
        move    0,provider_mode_v1094
        caie    0,1
        jrst    provider_other_v1094
        pushj   17,memfs_mres_xip_release
        movem   1,provider_result_v1094
        popj    17,
provider_other_v1094:
        caie    0,2
        jrst    provider_absent_v1094
        movni   1,5                  ; future owned-busy provider error
        movem   1,provider_result_v1094
        popj    17,
provider_absent_v1094:
        seto    1,                   ; absent MRES service sentinel
        movem   1,provider_result_v1094
        popj    17,

memfs_xip_owns_base:
        caie    1,012000
        jrst    invariant_v1094
        move    1,xip_owned_v1094
        popj    17,
memfs_xip_unpin_base:
        aos     unpin_calls_v1094
        caie    1,012000
        jrst    invariant_v1094
        move    1,unpin_result_v1094
        jumpn   1,unpin_done_v1094
        setzm   xip_owned_v1094
unpin_done_v1094:
        popj    17,

mm_free:
        aos     mm_calls_v1094
        caie    1,012000
        jrst    invariant_v1094
        caie    2,1
        jrst    invariant_v1094
        caie    3,2
        jrst    invariant_v1094
        move    1,mm_result_v1094
        jumpn   1,mm_result_done_v1094
        setzm   extent_owned_v1094
mm_result_done_v1094:
        popj    17,

proc_swap_detach:
        aos     detach_calls_v1094
        caie    1,2
        jrst    invariant_v1094
        move    1,detach_result_v1094
        jumpn   1,detach_result_done_v1094
        setzm   swap_owned_v1094
detach_result_done_v1094:
        popj    17,

invariant_v1094:
        setom   error_v1094
        seto    1,
        popj    17,

        .data
kconst_2_2: .word 2,,2
descriptor_v1094: .word 0
                 .word 04000,,012000
provider_mode_v1094: .word 1
storage_mode_v1094: .word 0
mm_result_v1094: .word 0
detach_result_v1094: .word 0
unpin_result_v1094: .word 0
xip_owned_v1094: .word 0
extent_owned_v1094: .word 0
swap_owned_v1094: .word 0
mm_calls_v1094: .word 0
detach_calls_v1094: .word 0
unpin_calls_v1094: .word 0
provider_calls_v1094: .word 0
provider_result_v1094: .word 0
error_v1094: .word 0
stage_v1094: .word 0
        .bss
__test_exit: .block 1
