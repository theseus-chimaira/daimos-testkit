.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 move 1,[010000,,0]     ; v925 fixture: saved user return
 movem 1,__uarea+020
 ; 010 is excluded; 2 is currently running; 4 is realtime protected;
 ; 7 has a pinned extent. The largest eligible resident is slot 3.
 movei 1,010
 setz 2,
 pushj 17,proc_oom_select_v863
 caie 1,3
 jrst fail_1
 ; v924: slot 3 is the otherwise preferred victim, but its private
 ; event wait means its kernel stack has not unwound.
 move 1,[040000,,0]
 iorm 1,__table+013
 movei 1,010
 setz 2,
 pushj 17,proc_oom_select_v863
 camn 1,[-1]
 jrst v924_waiter_protected
 jrst fail_8
v924_waiter_protected:
 move 1,[040000,,0]
 andcam 1,__table+013
 move 1,[060000,,0]
 iorm 1,__table+013
 movei 1,010
 setz 2,
 pushj 17,proc_oom_select_v863
 camn 1,[-1]
 jrst v924_intr_safe
 jrst fail_8
v924_intr_safe:
 move 1,[060000,,0]
 andcam 1,__table+013
 ; A fatal-close continuation cannot be killed while it owns a private
 ; kernel stack, even if it would otherwise free the largest RAM span.
 movei 1,4
 iorm 1,__uarea+024
 movei 1,010
 setz 2,
 pushj 17,proc_oom_select_v863
 camn 1,[-1]
 jrst owner_retry_done_v879
 jrst fail_8
owner_retry_done_v879:
 setzm __uarea+024
 ; Slot 3 is now holding the serialized filesystem provider lease.
 ; The selector must not kill the process that could release this lock.
 move 1,[4,,0]
 movem 1,fs_provider_ready
 movei 1,010
 setz 2,
 pushj 17,proc_oom_select_v863
 camn 1,[-1]
 jrst owner_rejected_v866
 jrst fail_1
owner_rejected_v866:
 ; A busy legacy/unknown-owner word also fails closed.
 setzm fs_provider_ready
 movei 1,010
 setz 2,
 pushj 17,proc_oom_select_v863
 camn 1,[-1]
 jrst unknown_rejected_v866
 jrst fail_1
unknown_rejected_v866:
 movei 1,1
 movem 1,fs_provider_ready
 ; Lock slot 8 as well, then excluding 3 leaves no resident.
 movei 1,0200000
 iorm 1,__table+030
 movei 1,3
 setz 2,
 pushj 17,proc_oom_select_v863
 camn 1,[-1]
 jrst test_current
 jrst fail_2
test_current:
 ; Without the current-slot exclusion, slot 2 becomes eligible.
 setzm proc_current_slot
 movei 1,3
 setz 2,
 pushj 17,proc_oom_select_v863
 caie 1,2
 jrst fail_3
 ; Releasing RT protection exposes the largest eligible resident.
 setzm proc_rt_owner
 movei 1,010
 setz 2,
 pushj 17,proc_oom_select_v863
 caie 1,4
 jrst fail_4
 ; In backing mode, choose the largest *swapped* span, slot 6.
 movei 1,010
 movei 2,1
 pushj 17,proc_oom_select_v863
 caie 1,6
 jrst fail_5
 ; Transition-locked swap slot 6 is ineligible, so choose slot 5.
 movei 1,0200000
 iorm 1,__table+022
 movei 1,010
 movei 2,1
 pushj 17,proc_oom_select_v863
 caie 1,5
 jrst fail_6
 ; No eligible swapped victim is a bounded, explicit -1.
 movei 1,0200000
 iorm 1,__table+017
 movei 1,010
 movei 2,1
 pushj 17,proc_oom_select_v863
 camn 1,[-1]
 jrst test_invalid
 jrst fail_7
test_invalid:
 movei 1,010
 movei 2,2
 pushj 17,proc_oom_select_v863
 camn 1,[-1]
 jrst pass
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
 jrst done
fail_8: movei 1,010
done: movem 1,__test_exit
 jrst 4,0

.globl kret_neg1
kret_neg1: seto 1,
 popj 17,
.globl mm_is_pinned
mm_is_pinned:
 caie 1,05000
 jrst not_pinned
 movei 1,1
 popj 17,
not_pinned:
 setz 1,
 popj 17,
.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl fs_provider_ready
fs_provider_ready: .word 1
.globl proc_table
proc_table: .word __table
.globl proc_high_slot
proc_high_slot: .word 011
.globl proc_current_slot
proc_current_slot: .word 2
.globl proc_rt_owner
proc_rt_owner: .word 4
.globl proc_swap_records
proc_swap_records: .word __records
__records:
 .word 0
 .word 0
 .word 1
 .word 1
 .word 1
 .word 010,,5
 .word 020,,7
 .word 1
 .word 1
__table:
 .block 6
 ; slot 2: current process
 .word __uarea,,0400000
 .word 04000,,02000
 .word 0200000,,0
 ; slot 3: ordinary sleeping resident
 .word __uarea,,0400000
 .word 06000,,03000
 .word 0300000,,0
 ; slot 4: protected realtime owner
 .word __uarea,,0400000
 .word 010000,,04000
 .word 0200000,,0
 ; slot 5: swapped out, 5 sectors
 .word __uarea,,0400000
 .word 04000,,0
 .word 0600000,,0
 ; slot 6: swapped out, 7 sectors
 .word __uarea,,0400000
 .word 04000,,0
 .word 0300000,,0
 ; slot 7: largest resident, but pinned
 .word __uarea,,0400000
 .word 012000,,05000
 .word 0200000,,0
 ; slot 010: excluded owner
 .word __uarea,,0400000
 .word 014000,,06000
 .word 0200000,,0
.bss
__uarea: .block 060
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
