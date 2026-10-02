        .text
        .globl pdp10_pi_dispatch_done
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl drm236_read_block
        .globl drm_test_inject_pending
        .globl drm_test_nested_result
pdp10_pi_dispatch_done:
        popj 17,
proc_wait_event:
        ; The online test can request one nested DRM read while the caller's
        ; transfer is active.  This forces the production one-entry FIFO path:
        ; the nested call must queue, sleep here, and be started directly by
        ; the first transfer's PI completion.
        skipn drm_test_inject_pending
        jrst wait_event_loop
        setzm drm_test_inject_pending
        push 17,1
        movei 1,1
        movei 2,2
        movei 3,drm_test_nested_buffer
        pushj 17,drm236_read_block
        movem 1,drm_test_nested_result
        pop 17,1
wait_event_loop:
        skipn (1)
        jrst wait_event_loop
        setz 1,
        popj 17,
proc_wakeup_event:
        popj 17,

        .bss
        .globl proc_table
        .globl proc_current_slot
proc_table:        .block 1
proc_current_slot: .block 1

        .bss
        .globl drm_test_inject_pending
        .globl drm_test_nested_result
drm_test_inject_pending: .block 1
drm_test_nested_result:  .block 1
drm_test_nested_buffer:  .block 0200
