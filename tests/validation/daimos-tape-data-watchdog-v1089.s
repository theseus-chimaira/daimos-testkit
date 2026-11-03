; Native PDP-6 test for the real tape watchdog tick leaf.
; Controller I/O is executed in a disposable emulator without media.
        .text
        .globl main
        .globl __test_exit
        .globl tape_watchdog_tick_v1089
        .globl storage_state
        .globl dtc_search_retries
        .globl mfsdev_storage_errors
        .globl dtc_forget_motion
        .globl tape_transfer_wakeup

main:
        setzm   error_v1089
        setzm   wake_count_v1089
        setzm   stop_count_v1089
        setzm   mfsdev_storage_errors
        setzm   mfsdev_storage_errors+1
        ; Polled DTC search and idle state are not data-transfer timers.
        movei   0,2
        movem   0,dtc_search_retries
        movei   0,0200
        movem   0,storage_state
        pushj   17,tape_watchdog_tick_v1089
        move    0,dtc_search_retries
        caie    0,2
        jrst    fail_v1089
        setzm   storage_state
        pushj   17,tape_watchdog_tick_v1089
        move    0,dtc_search_retries
        caie    0,2
        jrst    fail_v1089
        ; DSK read -3 is owned by another module and must not be aged.
        movni   0,3
        movem   0,storage_state
        pushj   17,tape_watchdog_tick_v1089
        move    0,dtc_search_retries
        caie    0,2
        jrst    fail_v1089

        ; DTC read: no early wake, then error after the exact two ticks.
        setom   storage_state
        pushj   17,tape_watchdog_tick_v1089
        move    0,dtc_search_retries
        caie    0,1
        jrst    fail_v1089
        skipn   wake_count_v1089
        jrst    dtc_pending_v1089
        jrst    fail_v1089
dtc_pending_v1089:
        pushj   17,tape_watchdog_tick_v1089
        move    0,storage_state
        caie    0,7
        jrst    fail_v1089
        move    0,wake_count_v1089
        caie    0,1
        jrst    fail_v1089
        move    0,stop_count_v1089
        caie    0,1
        jrst    fail_v1089
        move    0,mfsdev_storage_errors
        caie    0,1
        jrst    fail_v1089
        pushj   17,tape_watchdog_tick_v1089
        move    0,wake_count_v1089
        caie    0,1                   ; no second completion
        jrst    fail_v1089

        ; DTC write -6 also owns the DTC error counter.
        movni   0,6
        movem   0,storage_state
        movei   0,1
        movem   0,dtc_search_retries
        pushj   17,tape_watchdog_tick_v1089
        move    0,mfsdev_storage_errors
        caie    0,2
        jrst    fail_v1089

        ; MTC read -2 and write -5 have the other device error counter.
        movni   0,2
        movem   0,storage_state
        movei   0,1
        movem   0,dtc_search_retries
        pushj   17,tape_watchdog_tick_v1089
        move    0,mfsdev_storage_errors+1
        caie    0,1
        jrst    fail_v1089
        movni   0,5
        movem   0,storage_state
        movei   0,1
        movem   0,dtc_search_retries
        pushj   17,tape_watchdog_tick_v1089
        move    0,mfsdev_storage_errors+1
        caie    0,2
        jrst    fail_v1089
        move    0,wake_count_v1089
        caie    0,4
        jrst    fail_v1089
        move    0,stop_count_v1089
        caie    0,4
        jrst    fail_v1089

        ; An already-completed request cannot be failed by a later tick.
        movei   0,1
        movem   0,storage_state
        setzm   dtc_search_retries
        pushj   17,tape_watchdog_tick_v1089
        move    0,wake_count_v1089
        caie    0,4
        jrst    fail_v1089
        setz    1,
        popj    17,
fail_v1089:
        movei   1,1
        popj    17,

dtc_forget_motion:
        aos     stop_count_v1089
        popj    17,
tape_transfer_wakeup:
        aos     wake_count_v1089
        popj    17,

        .data
storage_state: .word 0
dtc_search_retries: .word 0
mfsdev_storage_errors: .block 3
wake_count_v1089: .word 0
stop_count_v1089: .word 0
error_v1089: .word 0
        .bss
__test_exit: .block 1
