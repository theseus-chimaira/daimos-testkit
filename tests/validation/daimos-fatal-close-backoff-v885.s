.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 move 1,[010000,,0]     ; v925 fixture: saved user return
 movem 1,__uarea+020
 movei 1,0400001
 pushj 17,proc_fatal_close_current_v879
 move 1,__close_calls
 caie 1,017                 ; 016 octal (14) rejections then success
 jrst fail_1
 move 1,__sleep_calls
 caie 1,016
 jrst fail_2
 skipn __event_busy
 jrst fail_3
 skipn __stack_preserved
 jrst fail_4
 skipn __fatal_seen
 jrst fail_5
 skipn __event_closed
 jrst check_entry
 jrst fail_6
check_entry:
 skipn __fd
 jrst check_exit
 jrst fail_7
check_exit:
 move 1,__exit_calls
 caie 1,1
 jrst fail_8
 move 1,__exit_status
 caie 1,0400001
 jrst fail_9
 skipn __max_delay_seen
 jrst fail_15                 ; interval reached the 01000 cap
 move 1,__expected_delay
 caie 1,01000
 jrst fail_16
 ; The owner bit stays in the u-area until finalization, not removed
 ; on transient retry success. A second process would still be excluded.
 move 1,__uarea+024
 trnn 1,04
 jrst fail_10
 ; Second fatal cleanup without a close error must not yield at all.
 movei 1,012345
 pushj 17,proc_fatal_close_current_v879
 move 1,__close_calls
 caie 1,020
 jrst fail_11
 move 1,__sleep_calls
 caie 1,016
 jrst fail_12
 move 1,__exit_calls
 caie 1,2
 jrst fail_13
 move 1,__exit_status
 caie 1,012345
 jrst fail_14
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
 jrst done
fail_13: movei 1,015
 jrst done
fail_14: movei 1,016
 jrst done
fail_15: movei 1,017
 jrst done
fail_16: movei 1,020
done: movem 1,__test_exit
 jrst 4,0

.globl file_close_all
file_close_all:
 aos __close_calls
 skipg __fail_remaining
 jrst close_ok
 sos __fail_remaining
 seto 1,
 popj 17,
close_ok:
 setzm __fd
 setz 1,
 popj 17,

.globl proc_sleep_ticks
proc_sleep_ticks:
 aos __sleep_calls
 move 3,__expected_delay
 came 1,3                     ; exact exponential sequence required
 jrst sleep_ret_bad
 caie 1,01000
 jrst sleep_check_next_v885
 setom __max_delay_seen
sleep_check_next_v885:
 caige 3,01000
 lsh 3,1
 movem 3,__expected_delay
 move 1,__uarea+024
 trne 1,04
 setom __fatal_seen
 move 1,-2(17)                 ; v885 keeps retry delay above exit status
 caie 1,0400001
 jrst sleep_ret_bad
 setom __stack_preserved
 ; Model another process delivering TERM to our sleeping continuation.
 movei 1,1
 movem 1,proc_current_slot
 movei 1,2
 movei 2,1
 pushj 17,proc_event_apply
 camn 1,[-1]
 setom __event_busy
 movei 1,2
 movem 1,proc_current_slot
 setz 1,
 popj 17,
sleep_ret_bad:
 seto 1,
 popj 17,

.globl file_close_all_at_v865
file_close_all_at_v865:
 aos __event_closed
 setz 1,
 popj 17,
.globl proc_finish_slot
proc_finish_slot:
 aos __event_closed
 setz 1,
 popj 17,
.globl proc_event_nonfatal
proc_event_nonfatal:
 seto 1,
 popj 17,
.globl proc_exit_current
proc_exit_current:
 aos __exit_calls
 movem 1,__exit_status
 popj 17,
.globl kret_neg1
kret_neg1: seto 1,
 popj 17,

.data
.globl proc_current_slot
proc_current_slot: .word 2
.globl proc_table
proc_table: .word __ptable
__ptable: .block 6
 .word __uarea,,0400000
 .word 0
 .word 0200000,,0
__uarea: .block 024
 .word 0
 .word 0
__fd: .word 0777
 .block 0410-027
.globl file_table
file_table: .word __fd
__fail_remaining: .word 016
__expected_delay: .word 1
__max_delay_seen: .word 0
__close_calls: .word 0
__sleep_calls: .word 0
__event_closed: .word 0
__event_busy: .word 0
__stack_preserved: .word 0
__fatal_seen: .word 0
__exit_calls: .word 0
__exit_status: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
