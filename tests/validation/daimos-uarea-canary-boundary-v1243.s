; Native PDP-6: real proc_run watermark fill may not touch semantic u-area.
        .text
        .globl main
main:
        movei   17,__test_stack-1
        hrli    17,-0400
        movei   014,__uarea
        pushj   17,proc_run_canary_fill_v1243

        movei   1,__uarea+071
        came    1,__uarea+071
        jrst    fail_first
        movei   1,__uarea+0405
        came    1,__uarea+0405
        jrst    fail_last
        skipn   __uarea+0406
        jrst    check_brk_v1243
        movei   1,1
        jrst    fail
check_brk_v1243:
        skipn   __uarea+0407
        jrst    success_v1243
        movei   1,2
        jrst    fail
success_v1243:
        setzm   __test_exit
        jrst    4,0
fail_first:
        movei   1,3
        jrst    fail
fail_last:
        movei   1,4
fail:
        movem   1,__test_exit
        jrst    4,0
        .bss
__uarea: .block 0410
__uarea_guard: .block 1
        .globl __test_exit
__test_exit: .block 1
__test_stack: .block 0400
