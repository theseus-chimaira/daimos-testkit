.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Install real pinned MM TTY input allocation.
 movei 1,0
 movei 2,__line
 pushj 17,proc_tty_line_base_set
 movei 1,5
 movei 2,1
 pushj 17,proc_tty_release_session
 move 1,proc_tty_records
 andi 1,0377
 caie 1,5
 jrst fail_1
 movei 1,0
 pushj 17,proc_tty_line_base_get
 caie 1,__line
 jrst fail_2
 move 1,mm_extent_count
 caie 1,1
 jrst fail_3
 ; An unrelated session is not allowed to acquire this TTY.
 movei 1,6
 movei 2,1
 pushj 17,proc_tty_release_session
 move 1,proc_tty_records
 andi 1,0377
 caie 1,5
 jrst fail_4
 ; Clear only the physical MM pin, then retry the original owner.
 movei 1,__line
 pushj 17,mm_unpin
 jumpn 1,fail_5
 movei 1,5
 movei 2,1
 pushj 17,proc_tty_release_session
 move 1,proc_tty_records
 andi 1,0377
 jumpn 1,fail_6
 skipn mm_extent_count
 jrst check_base
 jrst fail_7
check_base:
 movei 1,0
 pushj 17,proc_tty_line_base_get
 jumpn 1,fail_8
 ; Wrong MM owner also must retain TTY ownership and the MM extent.
 movei 1,1
 movem 1,mm_extent_count
 move 4,[03002001]
 movem 4,mm_extents+1
 movei 1,0
 movei 2,__line
 pushj 17,proc_tty_line_base_set
 movei 1,5
 movem 1,proc_tty_records
 movei 1,5
 movei 2,1
 pushj 17,proc_tty_release_session
 move 1,proc_tty_records
 andi 1,0377
 caie 1,5
 jrst fail_9
 move 1,mm_extent_count
 caie 1,1
 jrst fail_10
 move 4,[03002000]
 movem 4,mm_extents+1
 movei 1,5
 movei 2,1
 pushj 17,proc_tty_release_session
 move 1,proc_tty_records
 andi 1,0377
 jumpn 1,fail_11
 skipn mm_extent_count
 jrst pass
 jrst fail_12
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
 jrst done
fail_9: movei 1,011
 jrst done
fail_10: movei 1,012
 jrst done
fail_11: movei 1,013
 jrst done
fail_12: movei 1,014
done: movem 1,__test_exit
 jrst 4,0
.globl proc_tty_session_has
proc_tty_session_has:
 setz 1,
 popj 17,
.data
.globl proc_tty_records
proc_tty_records: .word 5
 .block 024
.globl mm_extents
mm_extents: .word 024,,__line
            .word 013002000
.globl mm_extent_count
mm_extent_count: .word 1
.globl proc_tty_line_bases
proc_tty_line_bases: .block 015
.bss
__line: .block 024
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
