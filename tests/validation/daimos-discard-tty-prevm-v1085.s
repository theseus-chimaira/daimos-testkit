; A failed last-member TTY release during unpublished RUN rollback must
; keep the child VM and any u-area for the permanent idle retry owner.
        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,2
        pushj 17,proc_slot_discard
        camn 1,[-1]
        jrst check_tty_first_v1085
        ; The original bug reports success despite a refused final
        ; TTY/MM free. Distinguish that historical violation from any
        ; unrelated unexpected return before checking the orphan.
        jumpe 1,check_historical_orphan_v1085
        jrst fail_2_v1085
check_historical_orphan_v1085:
        move 1,__tty_calls
        caie 1,1
        jrst fail_5_v1085
        move 1,__vm_calls
        caie 1,1
        jrst fail_5_v1085
        move 1,__release_calls
        caie 1,1
        jrst fail_5_v1085
        skipn __ptable+6
        jrst historical_orphan_v1085
        jrst fail_5_v1085
check_tty_first_v1085:
        move 1,__tty_calls
        caie 1,1
        jrst fail_3_v1085
        skipn __tty_bad_args_v1085
        jrst check_vm_first_v1085
        jrst fail_4_v1085
check_vm_first_v1085:
        skipn __vm_calls
        jrst check_no_uarea_free_v1085
        ; A pre-v1085 destroy has already dropped the only session
        ; owner. Require the original VM and U-area to be gone as
        ; proof of the concrete old error, not merely a test mismatch.
        move 1,__vm_calls
        caie 1,1
        jrst fail_5_v1085
        move 1,__release_calls
        caie 1,1
        jrst fail_5_v1085
        skipn __ptable+6
        jrst historical_orphan_v1085
        jrst fail_5_v1085
historical_orphan_v1085:
        movei 1,1
        jrst done_v1085
check_no_uarea_free_v1085:
        skipn __release_calls
        jrst check_slot_live_v1085
        jrst fail_6_v1085
check_slot_live_v1085:
        move 1,__ptable+6
        trnn 1,0200000       ; TRANSITION must remain owned
        jrst fail_7_v1085
        trnn 1,0400000       ; U-area still present
        jrst fail_8_v1085
        move 1,__ptable+7
        camn 1,[04000,,020000] ; VM must not be destroyed
        jrst check_sidl_v1085
        jrst fail_9_v1085
check_sidl_v1085:
        move 1,__ptable+010
        trnn 1,02            ; SIDL VM retry marker
        jrst fail_10_v1085
        move 1,proc_finish_last_tick_v881
        tlnn 1,0400000       ; existing shared retry clock armed
        jrst fail_11_v1085

        ; MM pin now releasable. The reaper retries the same TTY,
        ; then destroys the VM and releases the u-area just once.
        pushj 17,proc_finish_service_v881
        jumpe 1,check_committed_v1085
        jrst fail_12_v1085
check_committed_v1085:
        skipn __ptable+6
        jrst check_sched_freed_v1085
        jrst fail_13_v1085
check_sched_freed_v1085:
        skipn __ptable+7
        jrst check_count_v1085
        jrst fail_14_v1085
check_count_v1085:
        skipn __ptable+010
        jrst check_tty_twice_v1085
        jrst fail_15_v1085
check_tty_twice_v1085:
        move 1,__tty_calls
        caie 1,2
        jrst fail_16_v1085
        move 1,__vm_calls
        caie 1,1
        jrst fail_17_v1085
        move 1,__release_calls
        caie 1,1
        jrst fail_18_v1085
        skipn __hup_calls
        jrst verify_no_adopt_v1085
        jrst fail_19_v1085
verify_no_adopt_v1085:
        skipn __notify_calls
        jrst verify_no_notify_v1085
        jrst fail_20_v1085
verify_no_notify_v1085:
        skipn __adopt_calls
        jrst retry_noop_v1085
        jrst fail_21_v1085
retry_noop_v1085:
        pushj 17,proc_finish_service_v881
        move 1,__tty_calls
        caie 1,2
        jrst fail_22_v1085
        move 1,__release_calls
        caie 1,1
        jrst fail_23_v1085
        setz 1,
        jrst done_v1085

fail_2_v1085: movei 1,2
        jrst done_v1085
fail_3_v1085: movei 1,3
        jrst done_v1085
fail_4_v1085: movei 1,4
        jrst done_v1085
fail_5_v1085: movei 1,5
        jrst done_v1085
fail_6_v1085: movei 1,6
        jrst done_v1085
fail_7_v1085: movei 1,7
        jrst done_v1085
fail_8_v1085: movei 1,010
        jrst done_v1085
fail_9_v1085: movei 1,011
        jrst done_v1085
fail_10_v1085: movei 1,012
        jrst done_v1085
fail_11_v1085: movei 1,013
        jrst done_v1085
fail_12_v1085: movei 1,014
        jrst done_v1085
fail_13_v1085: movei 1,015
        jrst done_v1085
fail_14_v1085: movei 1,016
        jrst done_v1085
fail_15_v1085: movei 1,017
        jrst done_v1085
fail_16_v1085: movei 1,020
        jrst done_v1085
fail_17_v1085: movei 1,021
        jrst done_v1085
fail_18_v1085: movei 1,022
        jrst done_v1085
fail_19_v1085: movei 1,023
        jrst done_v1085
fail_20_v1085: movei 1,024
        jrst done_v1085
fail_21_v1085: movei 1,025
        jrst done_v1085
fail_22_v1085: movei 1,026
        jrst done_v1085
fail_23_v1085: movei 1,027
done_v1085:
        movem 1,__test_exit
        jrst 4,0
