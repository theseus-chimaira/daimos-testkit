; Exercise the real RUN credential-publication slice with all four
; providers, both mount extension bits and both SIDL rollback states.
        .text
        .globl main
        .globl publish_v1924
main:
        movei   010,cases_v1924
        movei   011,020
run_next_v1924:
        move    1,(010)
        movem   1,parent_v1924+040
        move    1,1(010)
        movem   1,desc_v1924+2
        movei   7,parent_v1924
        movei   013,desc_v1924
        movei   014,child_v1924
        pushj   17,publish_v1924
        move    1,child_v1924+066
        came    1,2(010)
        jrst    run_fail_v1924
        move    1,parent_v1924+040
        came    1,(010)
        jrst    run_fail_v1924
        move    1,desc_v1924+2
        came    1,1(010)
        jrst    run_fail_v1924
        addi    010,3
        sojg    011,run_next_v1924
        setz    1,
        popj    17,
run_fail_v1924:
        move    1,011
        popj    17,
        .bss
parent_v1924: .block 041
child_v1924: .block 070
desc_v1924: .block 3
        .globl __test_exit
__test_exit: .block 1
