; Source-linked kernel reaper: a live PREVM owner with a runq link
; whose value has bit 02 must not be mistaken for a SIDL discard.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        pushj   17,proc_finish_service_v881
        jumpn   1,fail_1_v1107
        move    1,__finish_calls
        caie    1,1
        jrst    fail_2_v1107
        move    1,__discard_calls
        caie    1,1
        jrst    fail_3_v1107
        skipn   __ptable+3
        jrst    check_sidl_v1107
        jrst    fail_4_v1107
check_sidl_v1107:
        skipn   __ptable+6
        jrst    check_kick_v1107
        jrst    fail_5_v1107
check_kick_v1107:
        skipn   proc_sched_kick
        jrst    fail_6_v1107
        setz    1,
        jrst    done_v1107
fail_1_v1107: movei 1,1
        jrst    done_v1107
fail_2_v1107: movei 1,2
        jrst    done_v1107
fail_3_v1107: movei 1,3
        jrst    done_v1107
fail_4_v1107: movei 1,4
        jrst    done_v1107
fail_5_v1107: movei 1,5
        jrst    done_v1107
fail_6_v1107: movei 1,6
done_v1107:
        movem   1,__test_exit
        jrst    4,0

        .globl proc_finish_slot
proc_finish_slot:
        caie    1,1
        jrst    bad_finish_v1107
        aos     __finish_calls
        setzm   __ptable+3
        setz    1,
        popj    17,
bad_finish_v1107:
        seto    1,
        popj    17,

        .globl proc_slot_discard
proc_slot_discard:
        caie    1,2
        jrst    bad_discard_v1107
        aos     __discard_calls
        setzm   __ptable+6
        setz    1,
        popj    17,
bad_discard_v1107:
        seto    1,
        popj    17,

        .globl proc_has_live_user
proc_has_live_user:
        movei   1,1
        popj    17,

        .data
        .globl proc_table
proc_table: .word __ptable
        .globl proc_high_slot
proc_high_slot: .word 3
        .globl proc_sched_kick
proc_sched_kick: .word 0
        .globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0400020,,02000
__ptable:
        .block 3
        ; Live SLEEP/DISK owner (not SIDL), runq successor slot 2.
        .word __uarea,,0600000
        .word 04000,,0
        .word 0200024,,2
        ; Unpublished RUN slot with a genuine SIDL discard flag.
        .word 0200000
        .word 0
        .word 0100000,,2
__uarea:
        .block 067
        .word 0500000,,020
__finish_calls: .word 0
__discard_calls: .word 0
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
