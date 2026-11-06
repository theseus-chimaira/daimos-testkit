; Native PDP-6 boundary regression: test both exact-all-words-dirty cases.
; An old CAIG scan reads one word beyond the reserved stack and reports
; a bogus highwater of capacity+1. The correct CAIGE scan terminates at
; precisely the first out-of-range address without dereferencing it.
        .text
        .globl main
main:
        movei   17,__test_stack-1
        hrli    17,-0400
        movei   1,__idle_stack
        movem   1,mach_kernel_stack_base
        pushj   17,kernel_idle_stack_watermark_scan
        move    1,kernel_idle_stack_highwater
        caie    1,0400
        jrst    test_fail_idle_full

        movei   1,__idle_stack+7
        movem   1,__idle_stack+7
        setzm   kernel_idle_stack_highwater
        pushj   17,kernel_idle_stack_watermark_scan
        move    1,kernel_idle_stack_highwater
        caie    1,7
        jrst    test_fail_idle_sentinel

        movei   1,__private_area
        pushj   17,proc_stack_watermark_scan
        move    1,proc_stack_highwater
        caie    1,0315
        jrst    test_fail_private_full

        movei   1,__private_area+0100
        movem   1,__private_area+0100
        setzm   proc_stack_highwater
        movei   1,__private_area
        pushj   17,proc_stack_watermark_scan
        move    1,proc_stack_highwater
        caie    1,010
        jrst    test_fail_private_sentinel

        setzm   __test_exit
        jrst    4,0
test_fail_idle_full:
        movei   1,1
        jrst    test_fail
test_fail_idle_sentinel:
        movei   1,2
        jrst    test_fail
test_fail_private_full:
        movei   1,3
        jrst    test_fail
test_fail_private_sentinel:
        movei   1,4
test_fail:
        movem   1,__test_exit
        jrst    4,0

        .bss
        .globl mach_kernel_stack_base
mach_kernel_stack_base: .block 1
        .globl proc_stack_highwater
proc_stack_highwater: .block 1
        .globl kernel_idle_stack_highwater
kernel_idle_stack_highwater: .block 1
__idle_stack: .block 0400
__idle_guard: .block 1
__private_area: .block 0406
__private_guard: .block 1
        .globl __test_exit
__test_exit: .block 1
__test_stack: .block 0400
