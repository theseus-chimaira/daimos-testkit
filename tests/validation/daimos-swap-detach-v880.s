.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,__descriptor
 movei 2,2
 pushj 17,vm_space_destroy
 camn 1,[-1]
 jrst failed_ok
 jrst fail_1
failed_ok:
 move 1,__descriptor+1
 camn 1,[04000,,0]
 jrst retained_ok
 jrst fail_2
retained_ok:
 move 1,__detach_calls
 caie 1,1
 jrst fail_3
 ; The backing release is now accepted. Only then may VM become NONE.
 setzm __fail_detach
 movei 1,__descriptor
 movei 2,2
 pushj 17,vm_space_destroy
 jumpe 1,committed
 jrst fail_4
committed:
 move 1,__descriptor+1
 camn 1,[-1]
 jrst check_count
 jrst fail_5
check_count:
 move 1,__detach_calls
 caie 1,2
 jrst fail_6
 ; DISK mode with a nonzero physical base must fail preflight, without
 ; calling the backing-release operation.
 move 1,[04000,,030000]
 movem 1,__descriptor+1
 movei 1,__descriptor
 movei 2,2
 pushj 17,vm_space_destroy
 camn 1,[-1]
 jrst bad_base_ok
 jrst fail_7
bad_base_ok:
 move 1,__detach_calls
 caie 1,2
 jrst fail_8
pass: setz 1,
 jrst done
fail_1: movei 1,1
 jrst done
fail_2: movei 1,2
 jrst done
fail_3: movei 1,3
 jrst done
fail_4: movei 1,4
 jrst done
fail_5: movei 1,5
 jrst done
fail_6: movei 1,6
 jrst done
fail_7: movei 1,7
 jrst done
fail_8: movei 1,010
done: movem 1,__test_exit
 jrst 4,0

.globl proc_storage_expect_v30
proc_storage_expect_v30:
 caie 2,1
 jrst storage_no
 setz 1,
 popj 17,
storage_no:
 seto 1,
 popj 17,
.globl proc_swap_detach
proc_swap_detach:
 aos __detach_calls
 skipn __fail_detach
 jrst detach_ok
 seto 1,
 popj 17,
detach_ok:
 setz 1,
 popj 17,
.globl fs_provider_reg_call
fs_provider_reg_call:
 seto 1,
 popj 17,
.globl mm_free
mm_free:
 setz 1,
 popj 17,
.data
.globl kconst_2_2
kconst_2_2: .word 2,,2
__descriptor:
 .word 0
 .word 04000,,0
 .word 0200000,,0
__fail_detach: .word 1
__detach_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
