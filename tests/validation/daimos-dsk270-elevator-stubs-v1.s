; Link-only KCORE stubs for executing dsk_enqueue from the real dsk_io.s.
        .text
        .globl pdp10_pi_handler_return
        .globl pdp10_pi_dispatch_done
        .globl proc_wait_event
        .globl proc_wakeup_event
pdp10_pi_dispatch_done:
pdp10_pi_handler_return: popj 17,
proc_wait_event:     setz 1,
                        popj 17,
proc_wakeup_event:   popj 17,

        .bss
        .globl proc_table
        .globl proc_current_slot
proc_table:          .block 4
proc_current_slot:   .block 1
