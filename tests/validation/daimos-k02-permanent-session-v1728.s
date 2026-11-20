.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
session_loop_v1728:
 movei 1,1
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 camn 1,[-1]
 jrst session_refused_v1728
 jrst fail_1_v1728
session_refused_v1728:
 move 1,proc_tty_records+3
 camn 1,[0777777777777]
 jrst session_tty_held_v1728
 jrst fail_2_v1728
session_tty_held_v1728:
 move 1,__u3+042
 caie 1,012345
 jrst fail_3_v1728
 move 1,__u2+067
 tlne 1,0400000
 jrst session_finalized_held_v1728
 jrst fail_4_v1728
session_finalized_held_v1728:
 aos __attempts
 move 1,__attempts
 caie 1,5
 jrst session_loop_v1728
 move 1,__closes
 caie 1,5
 jrst fail_5_v1728
 skipn __wrong_target
 jrst session_owners_preserved_v1728
 jrst fail_6_v1728
session_owners_preserved_v1728:
 skipn __finalizers
 jrst session_guard_v1728
 jrst fail_7_v1728

 ; The refusing member now has an irreversible owner-stack fatal close.
 ; It must not be reclosed or finalized by any foreign session HUP.
session_guard_v1728:
 movei 1,04
 iorm 1,__u3+024
session_guard_loop_v1728:
 movei 1,1
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 camn 1,[-1]
 jrst guard_refused_v1728
 jrst fail_10_v1728
guard_refused_v1728:
 aos __guard_attempts
 move 1,__guard_attempts
 caie 1,3
 jrst session_guard_loop_v1728
 move 1,__closes
 caie 1,5
 jrst fail_11_v1728
 move 1,__u3+024
 trne 1,04
 jrst guard_bit_held_v1728
 jrst fail_12_v1728
guard_bit_held_v1728:
 move 1,__u3+042
 caie 1,012345
 jrst fail_13_v1728
 move 1,proc_tty_records+3
 camn 1,[0777777777777]
 jrst guard_tty_held_v1728
 jrst fail_14_v1728
guard_tty_held_v1728:
 skipn __tty_releases
 jrst guard_no_tty_commit_v1728
 jrst fail_15_v1728
guard_no_tty_commit_v1728:
 skipn __finalizers
 jrst guard_no_finalize_v1728
 jrst fail_16_v1728
guard_no_finalize_v1728:
 skipn __wrong_target
 jrst pass_v1728
 jrst fail_17_v1728

pass_v1728: setz 1,
 jrst done_v1728
fail_1_v1728: movei 1,1
 jrst done_v1728
fail_2_v1728: movei 1,2
 jrst done_v1728
fail_3_v1728: movei 1,3
 jrst done_v1728
fail_4_v1728: movei 1,4
 jrst done_v1728
fail_5_v1728: movei 1,5
 jrst done_v1728
fail_6_v1728: movei 1,6
 jrst done_v1728
fail_7_v1728: movei 1,7
 jrst done_v1728
fail_10_v1728: movei 1,010
 jrst done_v1728
fail_11_v1728: movei 1,011
 jrst done_v1728
fail_12_v1728: movei 1,012
 jrst done_v1728
fail_13_v1728: movei 1,013
 jrst done_v1728
fail_14_v1728: movei 1,014
 jrst done_v1728
fail_15_v1728: movei 1,015
 jrst done_v1728
fail_16_v1728: movei 1,016
 jrst done_v1728
fail_17_v1728: movei 1,017
done_v1728:
 movem 1,__test_exit
 jrst 4,0

; Test-only permanently refusing FILE close. Both callers are actual
; production source-linked process/session event delivery procedures.
.globl file_close_all_at_v865
file_close_all_at_v865:
 aos __closes
 move 4,[__u3+026]
 camn 1,4
 jrst provider_owner_ok_v1728
 setom __wrong_target
provider_owner_ok_v1728:
 move 4,__u3+042
 caie 4,012345
 setom __wrong_target
 seto 1,
 popj 17,
.globl file_close_all
file_close_all:
 aos __wrong_target
 seto 1,
 popj 17,
.globl proc_event_nonfatal
proc_event_nonfatal:
 aos __wrong_target
 seto 1,
 popj 17,
.globl proc_finish_slot
proc_finish_slot:
 aos __finalizers
 seto 1,
 popj 17,
.globl proc_fatal_close_current_v879
proc_fatal_close_current_v879:
 aos __finalizers
 seto 1,
 popj 17,
.globl proc_runq_add
proc_runq_add:
 aos __wrong_target
 seto 1,
 popj 17,
.globl fs_provider_wait_event_v917
fs_provider_wait_event_v917:
 popj 17,
.globl proc_tty_line_try_reset_v897
proc_tty_line_try_reset_v897:
 aos __tty_releases
 setz 1,
 popj 17,
.globl kret_neg1
kret_neg1:
 seto 1,
 popj 17,

.data
.globl proc_current_slot
proc_current_slot: .word 1
.globl proc_table
proc_table: .word __ptable
.globl proc_high_slot
proc_high_slot: .word 4
.globl proc_tty_records
proc_tty_records:
 .block 3
 .word 0777777777777
 .block 025-4
__leader_ctl: .word 050000000010
__ptable:
 .block 3
 .word __u1,,0400000
 .word 0
 .word 0200000,,0
 ; Slot2 is irrevocably finalized with VM_NONE, so never re-HUP it.
 .word __u2,,0600000
 .word -1
 .word 0200000,,0
 ; Slot3 retains its stable u-area and FILE FD6.
 .word __u3,,0400000
 .word 0
 .word 0200000,,0
__u1: .block 070
__u2:
 .block 024
 .word 010
 .block 067-025
 .word 0400000,,0
__u3:
 .block 020
 .word 010000,,0
 .block 3
 .word 010
 .block 042-025
 .word 012345
 .block 070-043
__attempts: .word 0
__guard_attempts: .word 0
__closes: .word 0
__wrong_target: .word 0
__finalizers: .word 0
__tty_releases: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
