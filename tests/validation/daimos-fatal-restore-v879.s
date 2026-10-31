.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; VM_SPACE_NONE is -1, not a zero RH base.
 movei 2,__uarea
 pushj 17,proc_restore_kernel_tail
 skipn __vm_activation
 jrst check_no_vm_file
 jrst fail_1
check_no_vm_file:
 move 1,file_table
 caie 1,__uarea+026
 jrst fail_2
 move 1,mach_kernel_sp
 caie 1,0700
 jrst fail_3
 move 1,mach_user_sp
 caie 1,0123
 jrst fail_4
 ; A normal resident image with the fatal bit must restore its APR.
 move 1,[04000,,020000]
 movem 1,__ptable+1
 movei 2,__uarea
 pushj 17,proc_restore_kernel_tail
 move 1,__vm_activation
 caie 1,1
 jrst fail_5
 ; VM_NONE without the fatal cleanup flag must not silently skip APR.
 setzm __uarea+024
 setom __ptable+1
 movei 2,__uarea
 pushj 17,proc_restore_kernel_tail
 move 1,__vm_activation
 caie 1,2
 jrst fail_6
 ; A temporarily blank base is also acceptable for the guarded
 ; fatal private kernel continuation, without an APR reset.
 movei 1,4
 movem 1,__uarea+024
 setzm __ptable+1
 movei 2,__uarea
 pushj 17,proc_restore_kernel_tail
 move 1,__vm_activation
 caie 1,2
 jrst fail_7
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
done: movem 1,__test_exit
 jrst 4,0
.globl vm_activate_current
vm_activate_current:
 aos __vm_activation
 popj 17,
.globl proc_uarea_slot
proc_uarea_slot:
 movei 1,__uarea
 popj 17,
.data
.globl proc_current_slot
proc_current_slot: .word 2
.globl proc_current_ptr
proc_current_ptr: .word __ptable
__ptable: .word __uarea,,0400000
 .word -1
 .word 0200000,,0
.globl pdp10_pi_level6
pdp10_pi_level6: .word 0
.globl mach_kernel_sp
mach_kernel_sp: .word 0
.globl mach_user_sp
mach_user_sp: .word 0
.globl mach_syscall_save
mach_syscall_save: .word 0
.globl file_table
file_table: .word 0
__vm_activation: .word 0
__uarea: .block 020
 .word 0
 .word 0700
 .word 0123
 .word 0456
 .word 04
 .word 0
 .block 0410-026
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
