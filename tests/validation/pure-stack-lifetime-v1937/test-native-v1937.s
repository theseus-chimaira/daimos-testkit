; Actual stack-owner scanner, EXIT, DISCARD, u-area release and fatal
; event. Resource callbacks record or refuse unexpected destruction.
        .text
        .globl main
main:
        movei   1,1
        movem   1,case_no
        movei   1,foreign_record
        movem   1,proc_exec_resv_head_v1933
        movei   1,victim+070
        movem   1,foreign_record
        setzm   victim+070
        movei   1,victim
        pushj   17,proc_exec_stack_busy_v1937
        came    1,[-5]
        jrst    fail
        movei   1,unrelated
        pushj   17,proc_exec_stack_busy_v1937
        jumpn   1,fail
        ; A two-word record whose last word overlaps the extent.
        movei   1,victim-1
        movem   1,foreign_record
        movei   1,victim
        pushj   17,proc_exec_stack_busy_v1937
        came    1,[-5]
        jrst    fail
        movei   1,victim+070
        movem   1,foreign_record
        ; Foreign finish with a saved user return and empty FILEs.
        movei   1,2
        movem   1,case_no
        movei   1,2
        movei   2,01234
        pushj   17,proc_finish_slot
        came    1,[-1]
        jrst    fail
        skipe   destructive
        jrst    fail
        ; A marked owner-side retry must also refuse before teardown.
        movei   1,3
        movem   1,case_no
        movei   1,0200000
        iorm    1,descriptor
        move    1,[0500000,,01234]
        movem   1,victim+067
        movei   1,2
        movei   2,01234
        pushj   17,proc_finish_slot_owner_v932
        came    1,[-1]
        jrst    fail
        skipe   destructive
        jrst    fail
        move    1,[victim,,0400401]
        movem   1,descriptor
        setzm   victim+067
        ; An unpublished child rollback cannot discard a reserved stack.
        movei   1,4
        movem   1,case_no
        move    1,[0100000,,0]
        movem   1,descriptor+2
        movei   1,2
        pushj   17,proc_slot_discard
        came    1,[-1]
        jrst    fail
        skipe   destructive
        jrst    fail
        move    1,[0200000,,0]
        movem   1,descriptor+2
        ; Exact MM boundary refuses before calling the allocator.
        movei   1,5
        movem   1,case_no
        movei   1,2
        movei   2,descriptor
        pushj   17,proc_uarea_release
        came    1,[-5]
        jrst    fail
        skipe   destructive
        jrst    fail
        move    1,descriptor
        came    1,[victim,,0400401]
        jrst    fail
        ; Fatal foreign HUP must queue on owner, not close any FILE.
        movei   1,6
        movem   1,case_no
        movei   1,2
        movei   2,2
        pushj   17,proc_event_apply
        jumpn   1,fail
        skipe   destructive
        jrst    fail
        move    1,victim+024
        tlnn    1,010
        jrst    fail
        ; Unrelated head survives when owner unwinds its reservation.
        setzm   foreign_record
        movei   1,victim
        pushj   17,proc_exec_stack_busy_v1937
        jumpn   1,fail
        movei   1,7
        movem   1,case_no
        movei   1,2
        movei   2,descriptor
        pushj   17,proc_uarea_release
        jumpn   1,fail
        move    1,destructive
        caie    1,1
        jrst    fail
        move    1,descriptor
        came    1,[0401]
        jrst    fail
        ; A legitimate nonreturning handoff cannot abandon a published
        ; stack record. The invariant leaf must be reached before PI.
        movei   1,010
        movem   1,case_no
        move    1,[victim,,0400401]
        movem   1,descriptor
        movei   1,victim+070
        movem   1,foreign_record
        movei   1,01234
        jrst    proc_exit_current
fail:
        move    1,case_no
        movem   1,__test_exit
        halt    .
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        move    1,case_no
        caie    1,010
        jrst    fail
        move    1,destructive
        caie    1,1
        jrst    fail
        move    1,descriptor
        came    1,[victim,,0400401]
        jrst    fail
        setzm   __test_exit
        halt    .
        .globl mach_pi_disable
mach_pi_disable:
        jrst    fail
        .globl proc_exit_finish
        .globl proc_idle_loop
proc_exit_finish:
proc_idle_loop:
        jrst    fail
        .globl mm_free
mm_free:
        aos     destructive
        caie    1,victim
        jrst    fail
        caie    2,3
        jrst    fail
        caie    3,01002
        jrst    fail
        jrst    kret_zero
        .globl proc_session_teardown
        .globl proc_tty_release_session
        .globl vm_space_destroy
        .globl proc_scope_id
        .globl file_close_all_at_v865
        .globl file_close_all
proc_session_teardown:
proc_tty_release_session:
vm_space_destroy:
proc_scope_id:
file_close_all_at_v865:
file_close_all:
        aos     destructive
        jrst    kret_neg1
        .globl proc_fatal_close_current_v879
        .globl proc_runq_add
        .globl proc_runq_remove
        .globl proc_adopt_children_pdp6
        .globl proc_notify_parent
        .globl proc_trim_high
        .globl proc_event_nonfatal
proc_fatal_close_current_v879:
proc_runq_add:
proc_runq_remove:
proc_adopt_children_pdp6:
proc_notify_parent:
proc_trim_high:
proc_event_nonfatal:
        jrst    fail
        .globl kret_zero
        .globl kret_one
        .globl kret_neg1
kret_zero:
        setz    1,
        popj    17,
kret_one:
        movei   1,1
        popj    17,
kret_neg1:
        seto    1,
        popj    17,
        .data
        .globl proc_table
proc_table: .word descriptor-6
        .globl proc_high_slot
proc_high_slot: .word 3
        .globl proc_current_slot
proc_current_slot: .word 1
        .globl proc_current_ptr
proc_current_ptr: .word descriptor
        .globl proc_rt_owner
proc_rt_owner: .word 2
        .globl proc_timer_clock
proc_timer_clock: .word 0
        .globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
        .globl kconst_7_7
kconst_7_7: .word 7,,7
        .globl fs_provider_wait_event_v917
fs_provider_wait_event_v917: .word 0
        .globl file_table
file_table: .word victim+026
        .globl mach_kernel_stack_base
mach_kernel_stack_base: .word 0
descriptor:
        .word victim,,0400401
        .word 04000,,02000
        .word 0200000,,0
        .word 0
victim:
        .block 020
        .word 010000,,0
        .block 0410-021
foreign_record: .word 0
        .word 060301012345
unrelated: .block 0410
        .bss
case_no: .block 1
destructive: .block 1
        .globl __test_exit
__test_exit: .block 1
