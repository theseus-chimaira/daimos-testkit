/*
 * Focused AAP-PDP6 execution harness for the production DAIMOS CLK/APR MRES.
 * The harness supplies only the PI6 frame and process-exit hooks required by
 * clk_io.s, then generates a real user-mode pushdown overflow.
 */
        .text
        .globl  _start
        .globl  pdp10_pi_level6
        .globl  pdp10_pi_sp_save
        .globl  mach_kernel_sp
        .globl  pdp10_pi_handler_return
        .globl  proc_sched_pi_tick
        .globl  proc_sched_pi_resched
        .globl  proc_sched_kick
        .globl  storage_clock_tick
        .globl  file_close_all
        .globl  proc_exit_current
        .globl  __test_result
        .globl  clk_pi_service

_start:
        move    17,[0777700,,kernel_stack-1]
        movem   17,mach_kernel_sp
        setzm   __test_result

        /* Install the standard PDP-6 level-6 JSR vector at low-core 054. */
        move    1,[jsr pdp10_pi_level6]
        movem   1,000054

        /* Identity-like 2K-word user map beginning at logical 020. */
        move    1,[0002000,,000000]
        movem   1,apr_map
        datao   0000,apr_map

        /* Enable PI globally, enable PI6, and assign APR/clock to level 6. */
        cono    0004,002202
        cono    0000,002006

        move    17,[0777700,,user_stack-1]
        jrst    1,user_start

user_start:
        /* AOB of this PDP reaches C1 and raises PDP-6 APR PDL overflow. */
        move    16,[0777777,,000100]
        push    16,[0]
        movei   1,2
        movem   1,__test_result
        halt    .

/* Minimal spelling of the production PI6 save/switch/dismiss contract. */
pdp10_pi_level6:
        .word   0
        movem   17,pdp10_pi_sp_save+012
        move    1,pdp10_pi_level6
        tlne    1,010000
        move    17,mach_kernel_sp
        pushj   17,clk_pi_service
        move    17,pdp10_pi_sp_save+012
        jrst    012,@pdp10_pi_level6

pdp10_pi_handler_return:
        popj    17,
proc_sched_pi_tick:
        popj    17,
proc_sched_pi_resched:
        popj    17,
storage_clock_tick:
        popj    17,
file_close_all:
        popj    17,

/* Reaching here proves the production handler dismissed PI6 before teardown. */
proc_exit_current:
        movei   1,1
        movem   1,__test_result
        halt    .

        .data
apr_map:        .word 0

        .bss
proc_sched_kick: .block 1
mach_kernel_sp:  .block 1
pdp10_pi_sp_save: .block 020
__test_result:   .block 1
kernel_stack:    .block 0100
user_stack:      .block 0100
