.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Resident PURE slot 1 on public mount 17, same low bits as mount 1.
 setz 1,
 lsh 1,022
 movei 2,0700
 lsh 2,026
 ior 1,2
 iori 1,012345
 movem 1,__record+1
 move 1,[001000,,0]
 movem 1,__uarea+066
 movei 1,021
 pushj 17,proc_swap_mount_busy
 caie 1,1
 jrst fail_1
 movei 1,1
 pushj 17,proc_swap_mount_busy
 jumpn 1,fail_2
 ; Swapped PURE uses same record in stable u-area.
 move 1,__record+1
 movem 1,__uarea+0406
 move 1,[04000,,0]
 movem 1,__ptable+4
 move 1,[010,,010]
 movem 1,__record+1
 movei 1,021
 pushj 17,proc_swap_mount_busy
 caie 1,1
 jrst fail_3
 ; Other slot sharing low four bits must not match.
 movei 1,1
 pushj 17,proc_swap_mount_busy
 jumpn 1,fail_4
 ; Non-PURE resident process should not pin mount.
 setzm __uarea+0406
 move 1,[04000,,02000]
 movem 1,__ptable+4
 setz 1,
 lsh 1,022
 iori 1,012345
 movem 1,__record+1
 movei 1,021
 pushj 17,proc_swap_mount_busy
 jumpn 1,fail_4
 setz 1,
 jrst done
fail_1: movei 1,1
 jrst done
fail_2: movei 1,2
 jrst done
fail_3: movei 1,3
 jrst done
fail_4: movei 1,4
done: movem 1,__test_exit
 jrst 4,0
.data
.globl proc_table
proc_table: .word __ptable
.globl proc_high_slot
proc_high_slot: .word 2
.globl proc_swap_records
proc_swap_records: .word __record
__record: .word 0
 .word 0
__ptable:
 .block 3
 .word __uarea,,0400000
 .word 04000,,02000
 .word 0300000,,0
__uarea: .block 0410
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
