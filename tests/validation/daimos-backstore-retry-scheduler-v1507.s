; Native PDP-6 source-linked service and scheduler retry acceptance.
; Slot 2: physically corrupt checked BACKSTORE bitmap; slot 3: a second
; nonresident invalid image; slot 1: runnable resident bystander.
; No process-state or resident allocation changes are made by this test.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        movei   1,4
        movem   1,proc_high_slot
        movei   1,1
        movem   1,__uarea+0406

        move    1,[__uarea1_v1507,,0400000]
        movem   1,__descriptor+3
        move    1,[02000,,0305000]
        movem   1,__descriptor+4
        move    1,[0200077,,2]
        movem   1,__descriptor+5
        move    1,[0200000,,3]
        movem   1,__descriptor+010
        move    1,[__uarea3_v1507,,0400000]
        movem   1,__descriptor+011
        move    1,[02000,,0]
        movem   1,__descriptor+012
        move    1,[0200030,,0]
        movem   1,__descriptor+013
        movei   1,1
        movem   1,proc_runq_head

        ; The first failed restore is a real corrupt checked-free rollback.
        movei   1,1
        movem   1,stage_v1507
        movei   1,0402
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        camn    1,[-1]
        jrst    first_failed_v1507
        jrst    failed_v1507
first_failed_v1507:
        move    1,__uarea+067
        tlne    1,040000
        jrst    first_epoch_v1507
        jrst    failed_v1507
first_epoch_v1507:
        hrrz    1,1
        jumpn   1,failed_v1507
        move    1,proc_sched_cursor
        caie    1,2
        jrst    failed_v1507

        ; The higher-priority failing owner must not suppress a healthy
        ; nonresident slot. Both normal and realtime selection are real.
        movei   1,2
        movem   1,stage_v1507
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        jumpn   1,failed_v1507
        move    1,proc_sched_cursor
        caie    1,0403
        jrst    failed_v1507
        movei   1,2
        movem   1,proc_rt_owner
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        jumpn   1,failed_v1507
        move    1,proc_sched_cursor
        caie    1,0403
        jrst    failed_v1507
        setzm   proc_rt_owner

        ; Genuine global allocation pressure remains a global cooldown.
        movei   1,3
        movem   1,stage_v1507
        movei   1,0100
        movem   1,proc_swap_pressure_ticks
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        caie    1,1
        jrst    failed_v1507
        setzm   proc_swap_pressure_ticks

        ; A second (different) real swap-in refusal must not replace the
        ; first owner's deadline. It fails before reading any payload,
        ; since the second owner's executable backing is invalid.
        movei   1,4
        movem   1,stage_v1507
        movei   1,0403
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        camn    1,[-1]
        jrst    second_failed_v1507
        jrst    failed_v1507
second_failed_v1507:
        move    1,__uarea+067
        tlne    1,040000
        jrst    second_epoch_v1507
        jrst    failed_v1507
second_epoch_v1507:
        move    1,__uarea3_v1507+067
        tlne    1,040000
        jrst    both_blocked_v1507
        jrst    failed_v1507
both_blocked_v1507:
        ; While both DISK owners are delayed, the real resident bystander
        ; must run rather than spin in slot-0 swap service.
        movei   1,5
        movem   1,stage_v1507
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        caie    1,1
        jrst    failed_v1507
        movei   1,2
        movem   1,proc_rt_owner
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        caie    1,1
        jrst    failed_v1507
        movei   1,3
        movem   1,proc_rt_owner
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        caie    1,1
        jrst    failed_v1507
        setzm   proc_rt_owner

        ; Real PI6 clock advances the 17-bit epoch. No service retries
        ; occur before the 0100-tick delay expires.
        movei   1,6
        movem   1,stage_v1507
        movei   10,077
ticks_before_expiry_v1507:
        pushj   17,proc_sched_pi_tick
        sojg    10,ticks_before_expiry_v1507
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        caie    1,1
        jrst    failed_v1507
        pushj   17,proc_sched_pi_tick
        move    1,proc_timer_clock
        caie    1,0100
        jrst    failed_v1507
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        jumpn   1,failed_v1507
        move    1,proc_sched_cursor
        caie    1,0402
        jrst    failed_v1507
        ; An expired retry must be retired, not periodically reactivated
        ; by a later wrap of the 17-bit timer epoch.
        move    1,__uarea+067
        tlne    1,040000
        jrst    failed_v1507
        movei   1,3
        movem   1,proc_rt_owner
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        jumpn   1,failed_v1507
        move    1,proc_sched_cursor
        caie    1,0403
        jrst    failed_v1507
        move    1,__uarea3_v1507+067
        tlne    1,040000
        jrst    failed_v1507
        setzm   proc_rt_owner

        ; After explicit correction, that same DISK owner can restore.
        movei   1,7
        movem   1,stage_v1507
        movei   1,0776
        movem   1,__bitmap_v1405
        movei   1,0402
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        caie    1,01002
        jrst    failed_v1507
        move    1,__record+2
        caie    1,1
        jrst    failed_v1507
        skipn   backstore_blocks_used
        jrst    verify_account_v1507
        jrst    failed_v1507
verify_account_v1507:
        skipn   proc_swap_blocks_used
        jrst    verify_no_false_v1507
        jrst    failed_v1507
verify_no_false_v1507:
        move    1,__uarea+067
        tlne    1,040000
        jrst    failed_v1507
        move    1,event_calls_v1493
        caie    1,2
        jrst    failed_v1507
        move    1,__rollback_calls_v1405
        caie    1,1
        jrst    failed_v1507
        move    1,__publish_calls_v1405
        caie    1,1
        jrst    failed_v1507
        skipn   __invariant_calls_v1405
        jrst    wrap_begin_v1507
        jrst    failed_v1507

wrap_begin_v1507:
        ; Re-arm only the second DISK owner shortly before epoch wrap.
        ; It must remain excluded for precisely 0100 clock ticks, with
        ; normal and realtime selection still admitting resident jobs.
        movei   1,010
        movem   1,stage_v1507
        movei   1,0377770
        movem   1,proc_timer_clock
        movei   1,0403
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        camn    1,[-1]
        jrst    wrap_failed_v1507
        jrst    failed_v1507
wrap_failed_v1507:
        move    1,__uarea3_v1507+067
        tlne    1,040000
        jrst    wrap_epoch_v1507
        jrst    failed_v1507
wrap_epoch_v1507:
        hrrz    1,1
        caie    1,0377770
        jrst    failed_v1507
        movei   1,3
        movem   1,proc_rt_owner
        movei   10,077
wrap_ticks_v1507:
        pushj   17,proc_sched_pi_tick
        sojg    10,wrap_ticks_v1507
        movei   1,011
        movem   1,stage_v1507
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        caie    1,2
        jrst    failed_v1507
        pushj   17,proc_sched_pi_tick
        move    1,proc_timer_clock
        caie    1,0400070
        jrst    failed_v1507
        setz    1,
        pushj   17,proc_select_runnable_pdp6
        jumpn   1,failed_v1507
        move    1,proc_sched_cursor
        caie    1,0403
        jrst    failed_v1507
        move    1,__uarea3_v1507+067
        tlne    1,040000
        jrst    failed_v1507
        move    1,event_calls_v1493
        caie    1,3
        jrst    failed_v1507
        jrst    passed_v1507
failed_v1507:
        movei   1,1
        jrst    exit_v1507
passed_v1507:
        setz    1,
exit_v1507:
        movem   1,__test_exit
        jrst    4,0

        .data
        .globl proc_rt_owner
proc_rt_owner: .word 0
        .globl proc_runq_head
proc_runq_head: .word 0
        .globl proc_sched_age_phase
proc_sched_age_phase: .word 0
        .globl proc_current_slot
proc_current_slot: .word 0
        .globl proc_timer_clock
proc_timer_clock: .word 0
        .globl proc_timer_next
proc_timer_next: .word 0
        .globl proc_high_slot
proc_high_slot: .word 0
        .globl proc_sched_cursor
proc_sched_cursor: .word 0
        .globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .word 0
        .globl stage_v1507
stage_v1507: .word 0
        .globl event_calls_v1493
event_calls_v1493: .word 0
        .globl event_slot_v1493
event_slot_v1493: .word 0
        .globl event_kind_v1493
event_kind_v1493: .word 0
        .globl unexpected_exchange_v1493
unexpected_exchange_v1493: .word 0
        .bss
__uarea1_v1507: .block 0410
__uarea3_v1507: .block 0410
