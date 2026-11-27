; Native gap regression. Stack canaries are physical word addresses.
        .text
        .globl main
main:
        movei 17,test_stack-1
        hrli 17,-0400
        movei 1,idle
        movem 1,mach_kernel_stack_base
        movei 2,idle+1
        movei 3,0377
fill_idle:
        movem 2,(2)
        aoj 2,
        sojg 3,fill_idle
        movei 2,private+071
        movei 3,0315
fill_private:
        movem 2,(2)
        aoj 2,
        sojg 3,fill_private
        ; Leave the first word untouched, write deep into each stack.
        setzm idle+0140
        setzm private+070+0170
        pushj 17,kernel_idle_stack_watermark_scan
        move 1,kernel_idle_stack_highwater
        caie 1,0140
        jrst fail_idle_gap
        movei 1,private
        pushj 17,proc_stack_watermark_scan
        move 1,proc_stack_highwater
        caie 1,0170
        jrst fail_private_gap
        ; A shallower new stack must not reduce the historical maximum.
        movei 2,idle+0140
        movem 2,(2)
        pushj 17,kernel_idle_stack_watermark_scan
        move 1,kernel_idle_stack_highwater
        caie 1,0140
        jrst fail_monotonic
        movei 2,private+070+0170
        movem 2,(2)
        movei 1,private
        pushj 17,proc_stack_watermark_scan
        move 1,proc_stack_highwater
        caie 1,0170
        jrst fail_monotonic
        ; Empty scans do not read the reserved base or either guard.
        setzm kernel_idle_stack_highwater
        setzm proc_stack_highwater
        pushj 17,kernel_idle_stack_watermark_scan
        skipn kernel_idle_stack_highwater
        jrst empty_private
        jrst fail_empty
empty_private:
        movei 1,private
        pushj 17,proc_stack_watermark_scan
        skipe proc_stack_highwater
        jrst fail_empty
        ; The very last legal words are writable, guards are not.
        setzm idle+0377
        setzm private+0405
        pushj 17,kernel_idle_stack_watermark_scan
        move 1,kernel_idle_stack_highwater
        caie 1,0377
        jrst fail_bounds
        movei 1,private
        pushj 17,proc_stack_watermark_scan
        move 1,proc_stack_highwater
        caie 1,0315
        jrst fail_bounds
        setzm __test_exit
        jrst 4,0
fail_idle_gap:
        movei 1,1
        jrst fail
fail_private_gap:
        movei 1,2
        jrst fail
fail_monotonic:
        movei 1,3
        jrst fail
fail_empty:
        movei 1,4
        jrst fail
fail_bounds:
        movei 1,5
fail:
        movem 1,__test_exit
        jrst 4,0

        .bss
        .globl mach_kernel_stack_base
mach_kernel_stack_base: .block 1
        .globl proc_stack_highwater
proc_stack_highwater: .block 1
        .globl kernel_idle_stack_highwater
kernel_idle_stack_highwater: .block 1
idle: .block 0400
idle_guard: .block 1
private: .block 0406
private_guard: .block 2
        .globl __test_exit
__test_exit: .block 1
test_stack: .block 0400
