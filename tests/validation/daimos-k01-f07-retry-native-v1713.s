; A source-linked F07 BACKSTORE owner must survive two refused frees.
; Only the third exact physical-run free repairs the injected bitmap.
        .text
        .globl main
main:
        movei   1,process_table_v1713
        movem   1,proc_table
        movei   1,010
        movem   1,daimos_v1494_slot
        move    1,[uarea_v1713,,0200000]
        movem   1,process_table_v1713+030
        setzm   uarea_v1713+067
        move    1,[04,,0]
        movem   1,uarea_v1713+024
        movei   1,0250
        movem   1,daimos_v1494_first
        movei   1,033
        movem   1,daimos_v1494_blocks
        movei   1,bitmap_word_v1713
        movem   1,daimos_v1494_bitmap_addr
        movei   1,010
        movem   1,daimos_v1494_bitmap_saved
        setzm   bitmap_word_v1713
        movei   1,1
        movem   1,daimos_v1494_armed
        setzm   daimos_v1494_free_calls
        setzm   daimos_v1494_repairs
        setzm   daimos_v1494_errors

        ; A different run must not count toward the fault trigger.
        movei   1,0260
        movei   2,033
        pushj   17,backstore_free
        came    1,[-1]
        jrst    fail1_v1713
        skipn   daimos_v1494_free_calls
        jrst    first_v1713
        jrst    fail2_v1713

first_v1713:
        pushj   17,exact_free_v1713
        came    1,[-1]
        jrst    fail3_v1713
        pushj   17,exact_free_v1713
        came    1,[-1]
        jrst    fail4_v1713
        move    1,daimos_v1494_free_calls
        caie    1,2
        jrst    fail5_v1713
        skipn   daimos_v1494_repairs
        jrst    third_v1713
        jrst    fail6_v1713

third_v1713:
        pushj   17,exact_free_v1713
        jumpn   1,fail7_v1713
        move    1,daimos_v1494_free_calls
        caie    1,3
        jrst    fail8_v1713
        move    1,daimos_v1494_repairs
        caie    1,1
        jrst    fail9_v1713
        move    1,daimos_v1494_armed
        caie    1,2
        jrst    fail10_v1713
        move    1,bitmap_word_v1713
        caie    1,010
        jrst    fail11_v1713
        skipn   daimos_v1494_errors
        jrst    one_repair_v1713
        jrst    fail12_v1713

one_repair_v1713:
        ; The single repaired run is now no longer fault-injected.
        pushj   17,exact_free_v1713
        jumpn   1,fail13_v1713
        move    1,daimos_v1494_free_calls
        caie    1,3
        jrst    fail14_v1713
        move    1,daimos_v1494_repairs
        caie    1,1
        jrst    fail15_v1713
        setz    1,
        popj    17,

exact_free_v1713:
        movei   1,0250
        movei   2,033
        pushj   17,backstore_free
        popj    17,

; Only the injector's prelude is source-linked; this test-only tail
; models the actual bitmap contract without a disk or other owners.
        .globl backstore_free_original_v1713
backstore_free_original_v1713:
        skipn   bitmap_word_v1713
        jrst    original_refuse_v1713
        setz    1,
        popj    17,
original_refuse_v1713:
        seto    1,
        popj    17,

fail1_v1713: movei 1,1
        popj 17,
fail2_v1713: movei 1,2
        popj 17,
fail3_v1713: movei 1,3
        popj 17,
fail4_v1713: movei 1,4
        popj 17,
fail5_v1713: movei 1,5
        popj 17,
fail6_v1713: movei 1,6
        popj 17,
fail7_v1713: movei 1,7
        popj 17,
fail8_v1713: movei 1,010
        popj 17,
fail9_v1713: movei 1,011
        popj 17,
fail10_v1713: movei 1,012
        popj 17,
fail11_v1713: movei 1,013
        popj 17,
fail12_v1713: movei 1,014
        popj 17,
fail13_v1713: movei 1,015
        popj 17,
fail14_v1713: movei 1,016
        popj 17,
fail15_v1713: movei 1,017
        popj 17,

        .bss
        .globl __test_exit
        .globl proc_table
        .globl daimos_v1494_slot
        .globl daimos_v1494_first
        .globl daimos_v1494_blocks
        .globl daimos_v1494_bitmap_addr
        .globl daimos_v1494_bitmap_saved
        .globl daimos_v1494_armed
        .globl daimos_v1494_free_calls
        .globl daimos_v1494_repairs
        .globl daimos_v1494_errors
proc_table: .block 1
daimos_v1494_slot: .block 1
daimos_v1494_first: .block 1
daimos_v1494_blocks: .block 1
daimos_v1494_bitmap_addr: .block 1
daimos_v1494_bitmap_saved: .block 1
daimos_v1494_armed: .block 1
daimos_v1494_free_calls: .block 1
daimos_v1494_repairs: .block 1
daimos_v1494_errors: .block 1
bitmap_word_v1713: .block 1
process_table_v1713: .block 060
uarea_v1713: .block 0100
__test_exit: .block 1
