.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Existing pinned line: free refuses without losing the pointer.
 movei 1,0
 movei 2,__line
 pushj 17,proc_tty_line_base_set
 movei 1,0
 pushj 17,proc_tty_line_try_reset_v897
 camn 1,[-5]                  ; pinned MM extent is retryable BUSY
 jrst check_pin_retained
 jrst fail_1
check_pin_retained:
 movei 1,0
 pushj 17,proc_tty_line_base_get
 caie 1,__line
 jrst fail_2
 move 1,mm_extent_count
 caie 1,1
 jrst fail_3
 ; Successful physical unpin allows a retry without reallocation.
 movei 1,__line
 pushj 17,mm_unpin
 jumpe 1,check_unpinned
 jrst fail_4
check_unpinned:
 movei 1,0
 pushj 17,proc_tty_line_try_reset_v897
 jumpe 1,check_freed
 jrst fail_5
check_freed:
 movei 1,0
 pushj 17,proc_tty_line_base_get
 jumpe 1,check_count
 jrst fail_6
check_count:
 skipn mm_extent_count
 jrst check_owner_bad
 jrst fail_7
 ; Wrong MM owner is not busy: do not remove another owner's span.
check_owner_bad:
 movei 1,1
 movem 1,mm_extent_count
 move 4,[03002001]
 movem 4,mm_extents+1
 ; Prove the real MM rejects the wrong owner before the C wrapper.
 movei 1,__line
 movei 2,3
 movei 3,02000
 pushj 17,mm_free
 camn 1,[-4]
 jrst owner_free_rejected
 jrst fail_19
owner_free_rejected:
 movei 1,0
 movei 2,__line
 pushj 17,proc_tty_line_base_set
 movei 1,0
 pushj 17,proc_tty_line_try_reset_v897
 camn 1,[-4]                  ; owner mismatch is INVALID, not BUSY
 jrst check_owner_retained
 jrst fail_8
check_owner_retained:
 movei 1,0
 pushj 17,proc_tty_line_base_get
 caie 1,__line
 jrst fail_9
 move 4,[03002000]
 movem 4,mm_extents+1
 movei 1,0
 pushj 17,proc_tty_line_try_reset_v897
 jumpe 1,check_owner_freed
 jrst fail_10
check_owner_freed:
 skipn mm_extent_count
 jrst check_missing
 jrst fail_11
 ; A missing extent never discards the existing pointer.
check_missing:
 movei 1,0
 movei 2,__line
 pushj 17,proc_tty_line_base_set
 movei 1,0
 pushj 17,proc_tty_line_try_reset_v897
 camn 1,[-4]                  ; missing MM extent is INVALID
 jrst check_missing_base
 jrst fail_12
check_missing_base:
 movei 1,0
 pushj 17,proc_tty_line_base_get
 caie 1,__line
 jrst fail_13
 setz 1,
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
 jrst done
fail_13: movei 1,015
 jrst done
fail_19: movei 1,023
done: movem 1,__test_exit
 jrst 4,0
.data
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
