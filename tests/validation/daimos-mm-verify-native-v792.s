.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,02000
 movei 2,1
 movei 3,04000
 pushj 17,mm_process_verify_pinned_v792
 jumpn 1,fail_first
 movei 1,02000
 movei 2,2
 movei 3,04000
 pushj 17,mm_process_verify_pinned_v792
 camn 1,[-1]
 jrst check_pin
 jrst fail
check_pin:
 setzm mm_extents+1
 movei 1,02000
 movei 2,1
 movei 3,04000
 pushj 17,mm_process_verify_pinned_v792
 camn 1,[-1]
 jrst pass
 jrst fail
pass: setz 1,
 jrst done
fail_first: movei 1,2
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.data
.globl mm_extent_count
mm_extent_count: .word 1
.globl mm_extents
mm_extents: .word 04000,,02000
 .word 011000001
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400
