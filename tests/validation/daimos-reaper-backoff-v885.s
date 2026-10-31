.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Each failed service round doubles a shared retry interval.
 move 1,[0400020,,0377]
 movem 1,proc_finish_last_tick_v881
 movei 6,040
 movei 7,5
loop:
 pushj 17,proc_finish_backoff_advance_v885
 hlrz 2,proc_finish_last_tick_v881
 move 3,6
 iori 3,0400000
 came 2,3
 jrst fail_1
 move 2,proc_finish_last_tick_v881
 andi 2,0177777
 caie 2,0377
 jrst fail_2
 lsh 6,1
 sojg 7,loop
 ; Cap at 01000 ticks, rather than overflowing the LH retry field.
 movei 6,01000
 movem 6,__cap
 movei 7,4
cap_loop:
 pushj 17,proc_finish_backoff_advance_v885
 hlrz 2,proc_finish_last_tick_v881
 caie 2,0401000
 jrst fail_3
 sojg 7,cap_loop
 ; On success the pending high bit disappears.  A service pass
 ; must clear all stale interval bits, but preserve timer epoch.
 movsi 2,0400000
 andcam 2,proc_finish_last_tick_v881
 pushj 17,proc_finish_backoff_advance_v885
 hlrz 2,proc_finish_last_tick_v881
 jumpe 2,check_epoch
 jrst fail_4
check_epoch:
 hrrz 2,proc_finish_last_tick_v881
 caie 2,0377
 jrst fail_5
 ; A newly pending owner is allowed to start back at 020 ticks.
 move 2,[0400020,,01234]
 movem 2,proc_finish_last_tick_v881
 pushj 17,proc_finish_backoff_advance_v885
 hlrz 2,proc_finish_last_tick_v881
 caie 2,0400040
 jrst fail_6
 ; A freshly deferred process resets an old saturated shared delay.
 ; A *repeated* MM failure on the same owner must retain that delay.
 move 2,[0401000,,0377]
 movem 2,proc_finish_last_tick_v881
 movei 12,__ptable
 movei 11,012345
 pushj 17,proc_finish_defer_uarea_v881
 hlrz 2,proc_finish_last_tick_v881
 caie 2,0400020
 jrst fail_7
 move 2,__uarea+067
 tlne 2,0400000
 jrst check_saved_status
 jrst fail_8
check_saved_status:
 hrrz 2,__uarea+067
 caie 2,012345
 jrst fail_9
 move 2,[0401000,,0377]
 movem 2,proc_finish_last_tick_v881
 pushj 17,proc_finish_defer_uarea_v881
 hlrz 2,proc_finish_last_tick_v881
 caie 2,0401000
 jrst fail_10
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
done: movem 1,__test_exit
 jrst 4,0
.globl proc_finish_fail
proc_finish_fail:
 popj 17,
.data
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
__cap: .word 0
__ptable: .word __uarea,,0400000
.bss
__uarea: .block 0410
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
