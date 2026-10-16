; Exact PDP-6 RUN fd-map loop: inherited two-bit mount extension on source
; descriptor 7 is copied to child descriptor 5, preserving the two-word FILE.
        .text
        .globl main
main:
        move    5,[006002000017]      ; arbitrary packed parent node
        movem   5,parent_fd_table+016 ; parent fd7 word 0
        movei   5,012345
        movem   5,parent_fd_table+017 ; full source word offset
        movei   5,3
        lsh     5,016                 ; extension bits for parent fd7
        movem   5,parent_fd_table+041
        movei   014,child_uarea
        movei   015,fdmap
        movei   3,1
        setz    4,
        pushj   17,proc_run_map_loop
        jumpn   1,check_copy_fail      ; loop returns zero on success
        move    5,parent_fd_table+016
        came    5,child_uarea+040     ; 026 + 2*5 = 040 octal
        jrst    check_copy_fail
        move    5,parent_fd_table+017
        came    5,child_uarea+041
        jrst    check_copy_fail
        move    5,child_uarea+067
        caie    5,06000              ; extension 3 at 2*fd5 = bit 10
        jrst    check_copy_fail
        setz    1,
        popj    17,
check_copy_fail:
        movei   1,1
        popj    17,

        .data
        .globl file_table
file_table: .word parent_fd_table
fdmap:       .word 5,,7

        .bss
parent_fd_table: .block 042
child_uarea:    .block 070
        .globl __test_exit
__test_exit:     .block 1
