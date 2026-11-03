; PDP-6 source-linked DRM236 third-concurrent-request regression.
; The active descriptor carries a watchdog LH; the one-slot pending
; FIFO is occupied. A third request must sleep on the active event,
; not repeatedly retry with no wait or index using the countdown LH.
        .text
        .globl main
        .globl drm236_read_block_service
        .globl drm236_active_request
        .globl drm236_pending_request
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl pdp10_pi_dispatch_done
        .globl proc_table
        .globl __test_exit

main:
        setzm failure_v1080
        setzm waits_v1080
        setzm resumed_v1080
        setzm old_desc_v1080+2
        setzm pending_desc_v1080+2
        move    0,[0454,,old_desc_v1080]
        movem   0,drm236_active_request
        movei   0,pending_desc_v1080
        movem   0,drm236_pending_request

        ; The driver allocates its third, private three-word descriptor.
        ; Stub completion happens *only* at proc_wait_event, preserving
        ; the source-linked driver's full queue/retry/claim path.
        movei   1,0100
        movei   2,buffer_v1080
        pushj   17,drm236_read_block_service
        jumpn   1,fail_status_v1080
        move    0,waits_v1080
        caie    0,2
        jrst    fail_count_v1080
        move    0,resumed_v1080
        caie    0,1
        jrst    fail_count_v1080
        skipn   failure_v1080
        jrst    assert_idle_v1080
        jrst    fail_count_v1080
assert_idle_v1080:
        skipn   drm236_active_request
        jrst    assert_pending_v1080
        jrst    fail_count_v1080
assert_pending_v1080:
        skipn   drm236_pending_request
        jrst    success_v1080
        jrst    fail_count_v1080
success_v1080:
        setz    1,
        popj    17,
fail_status_v1080:
        movei   1,1
        popj    17,
fail_count_v1080:
        movei   1,2
        popj    17,

; Test-only clock/hardware event oracle: it checks that the third
; caller *actually* waits for the active and then for its own request.
proc_wait_event:
        aos     waits_v1080
        move    0,waits_v1080
        caie    0,1
        jrst    complete_third_v1080
        movei   2,old_desc_v1080+2
        camn    1,2
        jrst    complete_old_v1080
        setom   failure_v1080
        popj    17,
complete_old_v1080:
        ; Simulate the two older owners completing before retry.
        ; Neither of their private descriptor addresses is reused.
        movei   0,1
        movem   0,old_desc_v1080+2
        movem   0,pending_desc_v1080+2
        setzm   drm236_active_request
        setzm   drm236_pending_request
        setz    1,
        popj    17,
complete_third_v1080:
        move    0,waits_v1080
        caie    0,2
        jrst    bad_wait_v1080
        movei   2,-2(1)
        hrrz    0,drm236_active_request
        camn    0,2
        jrst    verify_deadline_v1080
        jrst    bad_wait_v1080
verify_deadline_v1080:
        hlrz    0,drm236_active_request
        caie    0,0454
        jrst    bad_wait_v1080
        movei   0,1
        movem   0,(1)
        setzm   drm236_active_request
        aos     resumed_v1080
        setz    1,
        popj    17,
bad_wait_v1080:
        setom   failure_v1080
        setz    1,
        popj    17,

proc_wakeup_event:
        popj    17,
pdp10_pi_dispatch_done:
        popj    17,

        .data
        .globl proc_table
proc_table: .word 1
old_desc_v1080:
        .word  0,,buffer_v1080
        .word  0230
        .word  0
pending_desc_v1080:
        .word  0,,buffer_v1080
        .word  0220
        .word  0
failure_v1080: .word 0
waits_v1080: .word 0
resumed_v1080: .word 0
        .bss
buffer_v1080: .block 0200
__test_exit: .block 1
