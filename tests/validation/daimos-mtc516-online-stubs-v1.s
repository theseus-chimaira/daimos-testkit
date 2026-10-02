        .text
        .globl pdp10_pi_handler_return
        .globl pdp10_pi_dispatch_done
        .globl kret_ok
        .globl kret_arg
        .globl kret_busy
        .globl kret_neg5
        .globl proc_wait_event
        .globl proc_wakeup_event
pdp10_pi_dispatch_done:
pdp10_pi_handler_return: popj 017,
kret_ok: setz 1,
        popj 017,
kret_arg: seto 1,
        popj 017,
kret_busy: seto 1,
        popj 017,
kret_neg5: move 1,[-5]
        popj 017,
proc_wait_event: setz 1,
        popj 017,
proc_wakeup_event: popj 017,
        .bss
        .globl mfsdev_io_in
        .globl mfsdev_io_out
        .globl mfsdev_storage_errors
        .globl mfsdev_mtc_words_read
        .globl mfsdev_mtc_words_written
        .globl storage_state
        .globl storage_iowd
        .globl storage_count
        .globl proc_table
mfsdev_io_in: .block 020
mfsdev_io_out: .block 020
mfsdev_storage_errors: .block 5
mfsdev_mtc_words_read: .block 1
mfsdev_mtc_words_written: .block 1
storage_state: .block 1
storage_iowd: .block 1
storage_count: .block 1
proc_table: .block 4
