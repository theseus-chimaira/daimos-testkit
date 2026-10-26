; A TSFS root on mount ID 8 has the same provider and local kind as PIPE.
; The full six-bit mount ID must prevent false PIPE reference increments.
        .text
        .globl main
main:
        ; FD0: TSFS provider 7, mount 8, local kind 1, arbitrary index.
        movei   1,7
        lsh     1,036
        movei   2,010
        lsh     2,030
        ior     1,2
        movei   2,1
        lsh     2,022
        ior     1,2
        iori    1,1
        tlo     1,400000              ; FILE_META_READ
        movem   1,child_fd_table

        ; FD1: actual PIPE stream, public mount 0, with a valid object.
        movei   1,pipe_obj
        tlo     1,070001              ; provider 7, mount 0, kind 1
        tlo     1,400000              ; FILE_META_READ
        movem   1,child_fd_table+2

        movei   1,child_fd_table
        pushj   17,pipe_add_refs
        hlrz    3,pipe_obj+3
        caie    3,1                    ; only the real pipe gained a reader
        jrst    test_fail
        hrrz    3,pipe_obj+3
        jumpn   3,test_fail
        setz    1,
        popj    17,
test_fail:
        movei   1,1
        popj    17,

        .bss
child_fd_table: .block 040
pipe_obj:       .block 6
        .globl __test_exit
__test_exit:    .block 1
