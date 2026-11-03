; PDP-6 source-linked clock/DRM runtime watchdog exercise.
; No active hardware is required: timeout must finish the real private
; request descriptor and promote one pending descriptor exactly once.
        .text
        .globl main
        .globl drm236_watchdog_tick_v1079
        .globl storage_clock_tick
        .globl storage_clock_dsk_jump
        .globl storage_clock_drm_jump
        .globl drm236_active_request
        .globl drm236_pending_request
        .globl mfsdev_storage_errors
        .globl proc_table
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl pdp10_pi_dispatch_done
        .globl __test_exit

main:
        movei   0,dsk_tick_oracle_v1079
        hrrm    0,storage_clock_dsk_jump
        movei   0,drm236_watchdog_tick_v1079
        hrrm    0,storage_clock_drm_jump
        setzm   tick_calls_v1079
        setzm   wakes_v1079
        setzm   wrong_wake_v1079
        setzm   mfsdev_storage_errors+5
        setzm   drm236_one_v1079+2
        setzm   drm236_two_v1079+2
        move    0,[3,,drm236_one_v1079]
        movem   0,drm236_active_request
        movei   0,drm236_two_v1079
        movem   0,drm236_pending_request

        ; The countdown must remain live for both nonterminal ticks.
        pushj   17,storage_clock_tick
        pushj   17,storage_clock_tick
        hlrz    0,drm236_active_request
        caie    0,1
        jrst    fail_early_v1079
        skipn   drm236_one_v1079+2
        jrst    first_not_done_v1079
        jrst    fail_early_v1079
first_not_done_v1079:
        skipn   wakes_v1079
        jrst    first_expire_v1079
        jrst    fail_early_v1079

first_expire_v1079:
        ; Failing active request is completed, then one FIFO waiter
        ; is promoted and gets a *fresh* 300-tick deadline.
        pushj   17,storage_clock_tick
        move    0,drm236_one_v1079+2
        camn    0,[-1]
        jrst    first_status_v1079
        jrst    fail_first_v1079
first_status_v1079:
        move    0,drm236_active_request
        camn    0,[0454,,drm236_two_v1079]
        jrst    first_owner_v1079
        jrst    fail_first_v1079
first_owner_v1079:
        skipn   drm236_pending_request
        jrst    first_queue_v1079
        jrst    fail_first_v1079
first_queue_v1079:
        move    0,wakes_v1079
        caie    0,1
        jrst    fail_first_v1079
        move    0,mfsdev_storage_errors+5
        caie    0,1
        jrst    fail_first_v1079

        ; Advance exactly 299 ticks; no early second completion.
        movei   7,0453
second_wait_v1079:
        pushj   17,storage_clock_tick
        sojg    7,second_wait_v1079
        hlrz    0,drm236_active_request
        caie    0,1
        jrst    fail_second_v1079
        skipn   drm236_two_v1079+2
        jrst    second_expire_v1079
        jrst    fail_second_v1079
second_expire_v1079:
        pushj   17,storage_clock_tick
        move    0,drm236_two_v1079+2
        camn    0,[-1]
        jrst    second_status_v1079
        jrst    fail_second_v1079
second_status_v1079:
        skipn   drm236_active_request
        jrst    second_idle_v1079
        jrst    fail_second_v1079
second_idle_v1079:
        move    0,wakes_v1079
        caie    0,2
        jrst    fail_second_v1079
        move    0,mfsdev_storage_errors+5
        caie    0,2
        jrst    fail_second_v1079
        skipn   wrong_wake_v1079
        jrst    no_double_v1079
        jrst    fail_second_v1079

no_double_v1079:
        ; Further clock ticks must not complete already released stacks.
        pushj   17,storage_clock_tick
        pushj   17,storage_clock_tick
        move    0,wakes_v1079
        caie    0,2
        jrst    fail_final_v1079
        move    0,mfsdev_storage_errors+5
        caie    0,2
        jrst    fail_final_v1079
        move    0,tick_calls_v1079
        caie    0,0461                ; 3 + 300 + 2 = 305 ticks
        jrst    fail_final_v1079
        setz    1,
        popj    17,
fail_early_v1079:
        movei   1,1
        popj    17,
fail_first_v1079:
        movei   1,2
        popj    17,
fail_second_v1079:
        movei   1,3
        popj    17,
fail_final_v1079:
        movei   1,4
        popj    17,

dsk_tick_oracle_v1079:
        aos     tick_calls_v1079
        popj    17,

proc_wait_event:
        seto    1,
        popj    17,
proc_wakeup_event:
        movei   0,drm236_one_v1079+2
        camn    0,1
        jrst    wake_one_v1079
        movei   0,drm236_two_v1079+2
        camn    0,1
        jrst    wake_two_v1079
        aos     wrong_wake_v1079
        popj    17,
wake_one_v1079:
        aos     wakes_v1079
        popj    17,
wake_two_v1079:
        aos     wakes_v1079
        popj    17,
pdp10_pi_dispatch_done:
        popj    17,

        .data
proc_table: .word 1
drm236_one_v1079:
        .word   0,,buffer_v1079
        .word   0230
        .word   0
drm236_two_v1079:
        .word   0,,buffer_v1079
        .word   0220
        .word   0
tick_calls_v1079: .word 0
wakes_v1079: .word 0
wrong_wake_v1079: .word 0
        .bss
buffer_v1079: .block 0200
__test_exit: .block 1
