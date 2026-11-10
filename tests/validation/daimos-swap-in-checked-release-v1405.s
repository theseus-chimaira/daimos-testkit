; Native PDP-6 production swap-in transaction with real bitmap verifier/free.
; The MM/backend read stubs expose typed ABI calls, not transaction policy.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        movei   1,1                    ; valid executable backing identity
        movem   1,__uarea+0406
        movei   1,2
        pushj   17,proc_swap_in
        camn    1,[-1]
        jrst    check_refused_v1405
        jrst    fail_v1405
check_refused_v1405:
        move    1,__rollback_calls_v1405
        caie    1,1
        jrst    fail_v1405
        skipn   __publish_calls_v1405
        jrst    check_refused_owner_v1405
        jrst    fail_v1405
check_refused_owner_v1405:
        move    1,__record+2
        came    1,[1,,010]
        jrst    fail_v1405
        move    1,__uarea+0406
        caie    1,1
        jrst    fail_v1405
        move    1,__descriptor+7
        came    1,[02000,,0]
        jrst    fail_v1405
        move    1,__descriptor+6
        trne    1,0200000
        jrst    fail_v1405
        move    1,__bitmap_v1405
        caie    1,0376
        jrst    fail_v1405
        move    1,backstore_blocks_used
        caie    1,010
        jrst    fail_v1405
        move    1,proc_swap_blocks_used
        caie    1,010
        jrst    fail_v1405
        move    1,__mode_v1405
        caie    1,1
        jrst    fail_v1405

        ; Restore the missing bitmap bit and retry the SAME DISK process.
        movei   1,0776
        movem   1,__bitmap_v1405
        movei   1,2
        pushj   17,proc_swap_in
        jumpn   1,fail_retry_v1405
        move    1,__publish_calls_v1405
        caie    1,1
        jrst    fail_v1405
        skipn   __rollback_calls_v1405
        jrst    fail_v1405
        skipn   __bitmap_v1405
        jrst    check_success_owner_v1405
        jrst    fail_v1405
check_success_owner_v1405:
        skipn   backstore_blocks_used
        jrst    check_success_process_v1405
        jrst    fail_v1405
check_success_process_v1405:
        skipn   proc_swap_blocks_used
        jrst    check_success_record_v1405
        jrst    fail_v1405
check_success_record_v1405:
        move    1,__record+2
        caie    1,1
        jrst    fail_v1405
        skipn   __uarea+0406
        jrst    check_success_vm_v1405
        jrst    fail_v1405
check_success_vm_v1405:
        move    1,__descriptor+7
        came    1,[02000,,0306000]
        jrst    fail_v1405
        skipn   __mode_v1405
        jrst    check_success_payload_v1405
        jrst    fail_v1405
check_success_payload_v1405:
        move    1,0306000
        came    1,[012345670123]
        jrst    fail_v1405
        move    1,0307777
        came    1,[076543210765]
        jrst    fail_v1405
        move    1,__invariant_calls_v1405
        jumpn   1,fail_v1405
        setz    1,
        jrst    done_v1405
fail_v1405:
        movei   1,1
        jrst    done_v1405
fail_retry_v1405:
        movei   1,2
done_v1405:
        movem   1,__test_exit
        jrst    4,0

        .globl mm_alloc_aligned
mm_alloc_aligned:
        ; PUSHJ saves its return PC at (17): the caller's result pointer,
        ; pushed before the allocation preference, is at -2(17).
        move    5,-2(17)
        movei   6,0306000
        movem   6,(5)
        setz    1,
        popj    17,
        .globl mm_pin
mm_pin:
        aos     __pins_v1405
        setz    1,
        popj    17,
        .globl mm_unpin
mm_unpin:
        sos     __pins_v1405
        setz    1,
        popj    17,
        .globl mm_free
mm_free:
        aos     __rollback_calls_v1405
        setz    1,
        popj    17,
        .globl backstore_read
backstore_read:
        aos     __read_calls_v1405
        movem   1,__read_first_v1405
        movem   2,__read_count_v1405
        movem   3,__read_base_v1405
        caie    1,1
        jrst    read_fail_v1405
        caie    2,010
        jrst    read_fail_v1405
        caie    3,0306000
        jrst    read_fail_v1405
        move    4,[012345670123]
        movem   4,(3)
        move    4,[076543210765]
        movem   4,01777(3)
        setz    1,
        popj    17,
read_fail_v1405:
        aos     __read_bad_v1405
        seto    1,
        popj    17,
        .globl proc_storage_expect_v30
proc_storage_expect_v30:
        aos     __expect_calls_v1405
        caie    1,2
        jrst    store_fail_v1405
        caie    2,1
        jrst    store_fail_v1405
        move    1,__mode_v1405
        caie    1,1
        jrst    store_fail_v1405
        setz    1,
        popj    17,
        .globl proc_storage_publish_v30
proc_storage_publish_v30:
        caie    1,2
        jrst    store_fail_v1405
        caie    2,1
        jrst    store_fail_v1405
        jumpn   3,store_fail_v1405
        setzm   __mode_v1405
        aos     __publish_calls_v1405
        setz    1,
        popj    17,
store_fail_v1405:
        aos     __store_bad_v1405
        seto    1,
        popj    17,
        .globl proc_swap_reload_pure
proc_swap_reload_pure:
        seto    1,
        popj    17,
        .globl fs_zero_words
fs_zero_words:
        seto    1,
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos     __invariant_calls_v1405
        halt    .

        .data
        .globl proc_table
proc_table: .word __descriptor
        .globl proc_swap_records
proc_swap_records: .word __record
        .globl backstore_bitmap
backstore_bitmap: .word __bitmap_v1405
        .globl backstore_blocks
backstore_blocks: .word 020
        .globl backstore_blocks_used
backstore_blocks_used: .word 010
        .globl backstore_enabled
backstore_enabled: .word 1
        .globl proc_swap_blocks_used
proc_swap_blocks_used: .word 010
        .globl kconst_1_1
kconst_1_1: .word 1,,1
        .globl kconst_2_2
kconst_2_2: .word 2,,2
        .globl kconst_7_7
kconst_7_7: .word 7,,7
__record: .word 0
        .word 0
        .word 1,,010
__descriptor: .block 6
        .word __uarea,,0400000
        .word 02000,,0
        .word 0200000000000
__mode_v1405: .word 1
__bitmap_v1405: .word 0376
        .globl __rollback_calls_v1405
__rollback_calls_v1405: .word 0
        .globl __publish_calls_v1405
__publish_calls_v1405: .word 0
        .globl __invariant_calls_v1405
__invariant_calls_v1405: .word 0
__pins_v1405: .word 0
        .globl __read_first_v1405
__read_first_v1405: .word 0
        .globl __read_count_v1405
__read_count_v1405: .word 0
        .globl __read_base_v1405
__read_base_v1405: .word 0
        .globl __read_calls_v1405
__read_calls_v1405: .word 0
        .globl __read_bad_v1405
__read_bad_v1405: .word 0
        .globl __expect_calls_v1405
__expect_calls_v1405: .word 0
        .globl __store_bad_v1405
__store_bad_v1405: .word 0
        .bss
__uarea: .block 0410
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
