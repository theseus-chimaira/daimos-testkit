; Native PDP-6 test for the exact F07 v1494 service stack witness.
; The service's pending slot is below PUSHJ's return PC and three
; registers saved by the real diagnostic leaf.
        .text
        .globl main
main:
        movei   1,process_table_v1712
        movem   1,proc_table
        movei   1,swap_records_v1712
        movem   1,proc_swap_records
        movei   1,010
        movem   1,daimos_v1494_slot
        move    1,[0250,,033]
        movem   1,swap_records_v1712+010
        move    1,[uarea_v1712,,0200000]
        movem   1,process_table_v1712+030
        move    1,[0100000,,0]
        movem   1,uarea_v1712+067
        movei   1,0250
        movem   1,daimos_v1494_first
        movei   1,033
        movem   1,daimos_v1494_blocks

        ; This reproduces the caller's pending-slot word immediately
        ; below the PUSHJ return PC. A wrong -3(17) offset cannot see it.
        movei   1,010
        push    17,1
        pushj   17,daimos_v1494_term_witness
        sub     17,[1,,1]
        move    1,daimos_v1494_terms
        caie    1,1
        jrst    fail1_v1712
        skipn   daimos_v1494_errors
        jrst    test_wrong_slot_v1712
        jrst    fail2_v1712

test_wrong_slot_v1712:
        ; The witness must not count a different pending owner.
        movei   1,011
        push    17,1
        pushj   17,daimos_v1494_term_witness
        sub     17,[1,,1]
        move    1,daimos_v1494_terms
        caie    1,1
        jrst    fail3_v1712
        skipn   daimos_v1494_errors
        jrst    test_missing_prevm_v1712
        jrst    fail4_v1712

test_missing_prevm_v1712:
        ; Do not fabricate the PREVM marker: if it is truly absent,
        ; the original witness must count a failed integrity assertion.
        setzm   uarea_v1712+067
        movei   1,010
        push    17,1
        pushj   17,daimos_v1494_term_witness
        sub     17,[1,,1]
        move    1,daimos_v1494_terms
        caie    1,2
        jrst    fail5_v1712
        move    1,daimos_v1494_errors
        caie    1,1
        jrst    fail6_v1712
        setz    1,
        popj    17,

fail1_v1712: movei 1,1
        popj 17,
fail2_v1712: movei 1,2
        popj 17,
fail3_v1712: movei 1,3
        popj 17,
fail4_v1712: movei 1,4
        popj 17,
fail5_v1712: movei 1,5
        popj 17,
fail6_v1712: movei 1,6
        popj 17,

        .bss
        .globl __test_exit
        .globl proc_table
        .globl proc_swap_records
        .globl daimos_v1494_slot
        .globl daimos_v1494_first
        .globl daimos_v1494_blocks
        .globl daimos_v1494_terms
        .globl daimos_v1494_errors
proc_table: .block 1
proc_swap_records: .block 1
daimos_v1494_slot: .block 1
daimos_v1494_first: .block 1
daimos_v1494_blocks: .block 1
daimos_v1494_terms: .block 1
daimos_v1494_errors: .block 1
process_table_v1712: .block 060
swap_records_v1712: .block 030
uarea_v1712: .block 0100
__test_exit: .block 1
