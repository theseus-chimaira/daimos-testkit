; v1129: VM_SPACE_NONE is an exact full-word sentinel, not a physical base.
; Call the genuine VM destructor twice; neither call may free MM/XIP.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        movei   1,__descriptor
        movei   2,2
        pushj   17,vm_space_destroy
        jumpn   1,fail_1
        move    1,__descriptor+1
        camn    1,[-1]
        jrst    first_none
        jrst    fail_2
first_none:
        move    1,__detach_calls
        caie    1,1
        jrst    fail_3
        skipn   __mm_calls
        jrst    first_mm_ok
        jrst    fail_4
first_mm_ok:
        skipn   __fs_calls
        jrst    second_destroy
        jrst    fail_5
second_destroy:
        movei   1,__descriptor
        movei   2,2
        pushj   17,vm_space_destroy
        jumpn   1,fail_6
        move    1,__detach_calls
        caie    1,2
        jrst    fail_7
        skipn   __mm_calls
        jrst    second_mm_ok
        jrst    fail_8
second_mm_ok:
        skipn   __fs_calls
        jrst    check_second_none
        jrst    fail_9
check_second_none:
        move    1,__descriptor+1
        camn    1,[-1]
        jrst    storage_reject
        jrst    fail_10
storage_reject:
        setom   __invalid_mode
        movei   1,__descriptor
        movei   2,2
        pushj   17,vm_space_destroy
        camn    1,[-1]
        jrst    check_reject
        jrst    fail_11
check_reject:
        move    1,__detach_calls
        caie    1,2
        jrst    fail_12
        skipn   __mm_calls
        jrst    check_fs_reject
        jrst    fail_13
check_fs_reject:
        skipn   __fs_calls
        jrst    success
        jrst    fail_14
success:
        setz    1,
        jrst    done
fail_1: movei 1,1
        jrst done
fail_2: movei 1,2
        jrst done
fail_3: movei 1,3
        jrst done
fail_4: movei 1,4
        jrst done
fail_5: movei 1,5
        jrst done
fail_6: movei 1,6
        jrst done
fail_7: movei 1,7
        jrst done
fail_8: movei 1,010
        jrst done
fail_9: movei 1,011
        jrst done
fail_10: movei 1,012
        jrst done
fail_11: movei 1,013
        jrst done
fail_12: movei 1,014
        jrst done
fail_13: movei 1,015
        jrst done
fail_14: movei 1,016
done:
        movem   1,__test_exit
        jrst    4,0

        .globl proc_storage_expect_v30
proc_storage_expect_v30:
        caie    1,2
        jrst    storage_bad
        skipn   __invalid_mode
        jrst    storage_ok
storage_bad:
        seto    1,
        popj    17,
storage_ok:
        jumpe   2,storage_good
        seto    1,
        popj    17,
storage_good:
        setz    1,
        popj    17,

        .globl proc_swap_detach
proc_swap_detach:
        caie    1,2
        jrst    storage_bad
        aos     __detach_calls
        setz    1,
        popj    17,

        .globl fs_provider_reg_call
fs_provider_reg_call:
        aos     __fs_calls
        seto    1,
        popj    17,

        .globl mm_free
mm_free:
        aos     __mm_calls
        movni   1,4
        popj    17,

        .data
        .globl kconst_2_2
kconst_2_2: .word 2,,2
__descriptor: .word 0
        .word -1
        .word 0
__invalid_mode: .word 0
__detach_calls: .word 0
__mm_calls: .word 0
__fs_calls: .word 0
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
