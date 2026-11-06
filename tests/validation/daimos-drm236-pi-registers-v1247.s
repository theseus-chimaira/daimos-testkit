; Real DRM completion/promotion leaf: PI return register AC3 and interrupted
; AC4..AC6 must survive even when a pending DMA is started in the handler.
        .text
        .globl main
        .globl drm236_finish_active_v1079
        .globl drm236_active_request
        .globl drm236_pending_request
        .globl mfsdev_drm_reads
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl pdp10_pi_dispatch_done
        .globl proc_table
        .globl __test_exit

main:
        movei   0,request_a_v1247
        hrli    0,0454
        movem   0,drm236_active_request
        movei   0,request_b_v1247
        movem   0,drm236_pending_request
        setzm   request_a_v1247+2
        setzm   request_b_v1247+2
        setzm   wake_calls_v1247
        setzm   mfsdev_drm_reads

        movei   2,1                    ; successful drum completion
        movei   3,011111              ; PI2 return stub, opaque to driver
        movei   4,022222              ; caller-owned register
        movei   5,033333
        movei   6,044444
        pushj   17,drm236_finish_active_v1079
        caie    3,011111
        jrst    failed_3_v1247
        caie    4,022222
        jrst    failed_4_v1247
        caie    5,033333
        jrst    failed_5_v1247
        caie    6,044444
        jrst    failed_6_v1247
        move    0,request_a_v1247+2
        caie    0,1
        jrst    failed_other_v1247
        move    0,drm236_active_request
        camn    0,[0454,,request_b_v1247]
        jrst    check_pending_v1247
        jrst    failed_other_v1247
check_pending_v1247:
        skipn   drm236_pending_request
        jrst    check_wakeup_v1247
        jrst    failed_other_v1247
check_wakeup_v1247:
        move    0,wake_calls_v1247
        caie    0,1
        jrst    failed_other_v1247
        move    0,mfsdev_drm_reads
        caie    0,1
        jrst    failed_other_v1247

        ; A second completion with no pending DMA must also preserve the
        ; caller's PI return stub and all unsaved user registers.
        movei   2,1
        pushj   17,drm236_finish_active_v1079
        caie    3,011111
        jrst    failed_3_v1247
        caie    4,022222
        jrst    failed_4_v1247
        caie    5,033333
        jrst    failed_5_v1247
        caie    6,044444
        jrst    failed_6_v1247
        skipn   drm236_active_request
        jrst    check_complete_v1247
        jrst    failed_other_v1247
check_complete_v1247:
        move    0,wake_calls_v1247
        caie    0,2
        jrst    failed_other_v1247
        setz    1,
        popj    17,

failed_3_v1247:
        movei   0,1
        jrst    failed_v1247
failed_4_v1247:
        movei   0,2
        jrst    failed_v1247
failed_5_v1247:
        movei   0,3
        jrst    failed_v1247
failed_6_v1247:
        movei   0,4
        jrst    failed_v1247
failed_other_v1247:
        movei   0,5
failed_v1247:
        move    1,0
        popj    17,

proc_wait_event:
        seto    1,
        popj    17,
proc_wakeup_event:
        aos     wake_calls_v1247
        popj    17,
pdp10_pi_dispatch_done:
        popj    17,

        .data
proc_table: .word 1
request_a_v1247:
        .word 0,,buffer_v1247
        .word 0230                    ; READ
        .word 0
request_b_v1247:
        .word 0,,buffer_v1247
        .word 0230
        .word 0
wake_calls_v1247: .word 0

        .bss
buffer_v1247: .block 0200
__test_exit: .block 1
