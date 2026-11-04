; v1109: the genuine VM destroy calls the real MEMFS provider gateway,
; real owned-XIP lookup, and physical MM unpin. The DISK detach hook is
; only a counted resident backing stage; no VM or MM decision is faked.
        .text
main:
        movei   17,__stack-1
        hrli    17,-0400
        move    1,[03000005]         ; MM extent exists but is unpinned
        movem   1,mm_extents+1
        movei   1,__vm_v1109
        movei   2,2                   ; slot owner
        pushj   17,vm_space_destroy
        camn    1,[-1]
        jrst    check_failed_v1109
        jrst    fail_1_v1109
check_failed_v1109:
        move    1,__vm_v1109+1
        camn    1,[04000,,__extent]
        jrst    check_ref_v1109
        jrst    fail_2_v1109
check_ref_v1109:
        move    1,memfs_xip_refs
        camn    1,[1,,1]
        jrst    check_no_commit_v1109
        jrst    fail_3_v1109
check_no_commit_v1109:
        skipn   __detach_v1109
        jrst    check_no_fallback_v1109
        jrst    fail_4_v1109
check_no_fallback_v1109:
        skipn   __fallback_v1109
        jrst    repair_v1109
        jrst    fail_5_v1109
repair_v1109:
        movei   1,__extent
        pushj   17,mm_pin
        jumpn   1,fail_6_v1109
        movei   1,__vm_v1109
        movei   2,2
        pushj   17,vm_space_destroy
        jumpn   1,fail_7_v1109
        move    1,__vm_v1109+1
        camn    1,[-1]
        jrst    check_released_v1109
        jrst    fail_8_v1109
check_released_v1109:
        skipn   memfs_xip_refs
        jrst    check_mm_v1109
        jrst    fail_9_v1109
check_mm_v1109:
        move    1,mm_extents+1
        camn    1,[03000005]
        jrst    check_detach_v1109
        jrst    fail_10_v1109
check_detach_v1109:
        move    1,__detach_v1109
        caie    1,1
        jrst    fail_11_v1109
        skipn   __fallback_v1109
        jrst    check_provider_v1109
        jrst    fail_12_v1109
check_provider_v1109:
        move    1,__dispatch_calls
        caie    1,2
        jrst    fail_13_v1109
        move    1,fs_provider_ready
        camn    1,[3,,0]
        jrst    check_no_wait_v1109
        jrst    fail_14_v1109
check_no_wait_v1109:
        skipn   __wait_calls
        jrst    success_v1109
        jrst    fail_15_v1109
success_v1109:
        setz    1,
        jrst    done_v1109
fail_1_v1109: movei 1,1
        jrst done_v1109
fail_2_v1109: movei 1,2
        jrst done_v1109
fail_3_v1109: movei 1,3
        jrst done_v1109
fail_4_v1109: movei 1,4
        jrst done_v1109
fail_5_v1109: movei 1,5
        jrst done_v1109
fail_6_v1109: movei 1,6
        jrst done_v1109
fail_7_v1109: movei 1,7
        jrst done_v1109
fail_8_v1109: movei 1,010
        jrst done_v1109
fail_9_v1109: movei 1,011
        jrst done_v1109
fail_10_v1109: movei 1,012
        jrst done_v1109
fail_11_v1109: movei 1,013
        jrst done_v1109
fail_12_v1109: movei 1,014
        jrst done_v1109
fail_13_v1109: movei 1,015
        jrst done_v1109
fail_14_v1109: movei 1,016
        jrst done_v1109
fail_15_v1109: movei 1,017
done_v1109:
        movem   1,__test_exit
        jrst    4,0

        .globl proc_storage_expect_v30
proc_storage_expect_v30:
        caie    1,2                   ; exact process slot
        jrst    fail_storage_v1109
        jumpn   2,fail_storage_v1109
        setz    1,
        popj    17,
fail_storage_v1109:
        seto    1,
        popj    17,

        .globl proc_swap_detach
proc_swap_detach:
        caie    1,2
        jrst    fail_storage_v1109
        aos     __detach_v1109
        setz    1,
        popj    17,

        .globl mm_free
mm_free:
        aos     __fallback_v1109
        movni   1,4                    ; wrong MM_TYPE_PROCESS owner
        popj    17,

        .data
        .globl kconst_2_2
kconst_2_2: .word 2,,2
__vm_v1109: .word 0
        .word 04000,,__extent
        .word 0
__detach_v1109: .word 0
__fallback_v1109: .word 0
