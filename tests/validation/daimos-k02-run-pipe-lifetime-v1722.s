; K02 source-linked PDP-6 RUN-to-FILE/PIPE ownership transaction.
; Test-only external services model MM_ERR_BUSY and VFS_SYNC. The actual
; RUN fdmap, PIPE ref acquisition/close and FILE close-all logic is linked.

        .text
        .globl  main
main:
        ; Parent owns one anonymous PIPE reader and one writer.
        move    1,[0470001,,pipe_obj]
        movem   1,parent_uarea+026
        move    1,[0270001,,pipe_obj]
        movem   1,parent_uarea+030
        move    1,[1,,1]
        movem   1,pipe_obj+3
        movei   1,4                    ; private fatal-FILE close witness
        movem   1,parent_uarea+024
        movem   1,child_uarea+024

        ; Parent fd2 is TSFS mount 8, same provider and local-kind bits
        ; as PIPE but NEVER an owner of the separate PIPE reference count.
        movei   1,7
        lsh     1,036
        movei   2,010
        lsh     2,030
        ior     1,2
        movei   2,1
        lsh     2,022
        ior     1,2
        iori    1,fake_pipe
        tlo     1,0400000
        movem   1,parent_uarea+032

        ; A malformed duplicate destination rejects after one partial
        ; descriptor copy but BEFORE any reference has been acquired.
        movei   014,child_uarea
        movei   015,fdmap_invalid
        movei   3,2
        setz    4,
        pushj   17,proc_run_map_loop
        camn    1,[-1]
        jrst    check_failed_map
        jrst    fail_1
check_failed_map:
        move    1,pipe_obj+3
        camn    1,[1,,1]
        jrst    clear_unpublished
        jrst    fail_2
clear_unpublished:
        ; The caller discards speculative FILE words; there is no owned
        ; PIPE count to decrement on an unpublished RUN failure.
        movei   1,child_uarea+026
        movei   2,040
clear_unpublished_loop:
        setzm   (1)
        aoj     1,
        sojg    2,clear_unpublished_loop

        ; Valid child mapping: fd0 and fd1 share the parent reader,
        ; fd2 owns a copy of the writer, fd3 inherits the TSFS vnode.
        movei   014,child_uarea
        movei   015,fdmap_valid
        movei   3,4
        setz    4,
        pushj   17,proc_run_map_loop
        jumpe   1,check_child_map
        jrst    fail_3
check_child_map:
        move    1,child_uarea+026
        came    1,parent_uarea+026
        jrst    fail_4
        move    1,child_uarea+030
        came    1,parent_uarea+026
        jrst    fail_4
        move    1,child_uarea+032
        came    1,parent_uarea+030
        jrst    fail_4
        move    1,child_uarea+034
        came    1,parent_uarea+032
        jrst    fail_4

        movei   1,child_uarea+026
        pushj   17,pipe_add_refs
        move    1,pipe_obj+3
        camn    1,[3,,2]
        jrst    check_false_tsfs
        jrst    fail_5
check_false_tsfs:
        skipn   fake_pipe+3
        jrst    child_close
        jrst    fail_6

child_close:
        ; Child EXIT: closes both duplicate readers and its writer once.
        ; TSFS sync refuses after PIPE closes have already committed.
        ; Retain only the TSFS FILE entry across that independent failure.
        movei   1,child_uarea+026
        pushj   17,file_close_all_at_v865
        camn    1,[-1]
        jrst    child_refused
        jrst    fail_7
child_refused:
        move    1,pipe_obj+3
        camn    1,[1,,1]
        jrst    check_child_mm
        jrst    fail_10
check_child_mm:
        skipn   mm_calls
        jrst    check_child_sync
        jrst    fail_11
check_child_sync:
        move    1,sync_calls
        caie    1,1
        jrst    fail_12
        move    1,child_uarea+034
        came    1,parent_uarea+032
        jrst    fail_27
        skipn   child_uarea+026
        jrst    check_child_fd1
        jrst    fail_30
check_child_fd1:
        skipn   child_uarea+030
        jrst    check_child_fd2
        jrst    fail_31
check_child_fd2:
        skipn   child_uarea+032
        jrst    check_child_witness
        jrst    fail_32
check_child_witness:
        move    1,child_uarea+067
        camn    1,[043,,0777773]       ; first failing FD3, VFS -5
        jrst    child_retry
        jrst    fail_33

child_retry:
        movei   1,child_uarea+026
        pushj   17,file_close_all_at_v865
        jumpe   1,child_closed
        jrst    fail_34
child_closed:
        skipn   child_uarea+034
        jrst    check_child_retry_witness
        jrst    fail_35
check_child_retry_witness:
        skipn   child_uarea+067
        jrst    check_child_retry_refs
        jrst    fail_36
check_child_retry_refs:
        move    1,pipe_obj+3
        camn    1,[1,,1]
        jrst    check_child_retry_sync
        jrst    fail_37
check_child_retry_sync:
        move    1,sync_calls
        caie    1,2
        jrst    fail_40

parent_close:
        ; Parent EXIT: closing its reader leaves one writer. The final
        ; writer then refuses exact MM release. FILE must retain that FD
        ; and the PIPE counts unchanged for another teardown pass.
        movei   1,parent_uarea+026
        pushj   17,file_close_all_at_v865
        camn    1,[-1]
        jrst    check_parent_failed
        jrst    fail_13
check_parent_failed:
        skipn   parent_uarea+026
        jrst    check_parent_writer
        jrst    fail_14
check_parent_writer:
        move    1,parent_uarea+030
        camn    1,[0270001,,pipe_obj]
        jrst    check_parent_refs
        jrst    fail_15
check_parent_refs:
        move    1,pipe_obj+3
        camn    1,[0,,1]
        jrst    check_mm_refusal
        jrst    fail_16
check_mm_refusal:
        move    1,mm_calls
        caie    1,1
        jrst    fail_17
        move    1,last_mm_error
        camn    1,[-5]
        jrst    check_parent_witness
        jrst    fail_20
check_parent_witness:
        move    1,parent_uarea+067
        camn    1,[041,,0777773]       ; FD1, exact MM_ERR_BUSY -5
        jrst    retry_parent
        jrst    fail_41

retry_parent:
        ; Only the still-owned writer should be replayed after release
        ; becomes possible. The closed reader and TSFS fd stay closed.
        movei   1,parent_uarea+026
        pushj   17,file_close_all_at_v865
        jumpe   1,check_final_clear
        jrst    fail_21
check_final_clear:
        skipn   parent_uarea+030
        jrst    check_final_counts
        jrst    fail_22
check_final_counts:
        move    1,mm_calls
        caie    1,2
        jrst    fail_23
        move    1,sync_calls
        caie    1,3
        jrst    fail_24
        move    1,signal_calls
        caie    1,1
        jrst    fail_25
        skipn   parent_uarea+067
        jrst    check_fake
        jrst    fail_42
check_fake:
        skipn   fake_pipe+3
        jrst    pass
        jrst    fail_26

pass:
        setz    1,
        popj    17,
fail_1: movei 1,1
        popj 17,
fail_2: movei 1,2
        popj 17,
fail_3: movei 1,3
        popj 17,
fail_4: movei 1,4
        popj 17,
fail_5: movei 1,5
        popj 17,
fail_6: movei 1,6
        popj 17,
fail_7: movei 1,7
        popj 17,
fail_10: movei 1,010
        popj 17,
fail_11: movei 1,011
        popj 17,
fail_12: movei 1,012
        popj 17,
fail_13: movei 1,013
        popj 17,
fail_14: movei 1,014
        popj 17,
fail_15: movei 1,015
        popj 17,
fail_16: movei 1,016
        popj 17,
fail_17: movei 1,017
        popj 17,
fail_20: movei 1,020
        popj 17,
fail_21: movei 1,021
        popj 17,
fail_22: movei 1,022
        popj 17,
fail_23: movei 1,023
        popj 17,
fail_24: movei 1,024
        popj 17,
fail_25: movei 1,025
        popj 17,
fail_26: movei 1,026
        popj 17,
fail_27: movei 1,027
        popj 17,
fail_30: movei 1,030
        popj 17,
fail_31: movei 1,031
        popj 17,
fail_32: movei 1,032
        popj 17,
fail_33: movei 1,033
        popj 17,
fail_34: movei 1,034
        popj 17,
fail_35: movei 1,035
        popj 17,
fail_36: movei 1,036
        popj 17,
fail_37: movei 1,037
        popj 17,
fail_40: movei 1,040
        popj 17,
fail_41: movei 1,041
        popj 17,
fail_42: movei 1,042
        popj 17,

        .globl mm_free
mm_free:
        aos     mm_calls
        caie    1,pipe_obj
        jrst    bad_mm
        caie    2,3
        jrst    bad_mm
        caie    3,5
        jrst    bad_mm
        move    5,mm_calls
        caie    5,1
        jrst    good_mm
        movni   1,5                    ; real MM_ERR_BUSY identity
        movem   1,last_mm_error
        popj    17,
good_mm:
        setz    1,
        popj    17,
bad_mm:
        movni   1,4
        movem   1,last_mm_error
        popj    17,

        .globl pipe_signal_event
pipe_signal_event:
        aos     signal_calls
        popj    17,

        .globl file_node_from_fd
file_node_from_fd:
        move    1,(1)
        tlz     1,0700070
        popj    17,
        .globl kret_zero
kret_zero: setz 1,
        popj 17,
        .globl kret_neg1
kret_neg1: seto 1,
        popj 17,
        .globl vfs_sync
vfs_sync:
        aos     sync_calls
        move    5,sync_calls
        caie    5,1
        jrst    vfs_sync_ok
        movni   1,5                    ; refuse child's first TSFS close
        popj    17,
vfs_sync_ok:
        setz    1,
        popj    17,

        .data
        .globl file_table
file_table: .word parent_uarea+026
        .globl pipe_fifo_head
pipe_fifo_head: .word 0
fdmap_invalid:
        .word 0,,0
        .word 0,,1
fdmap_valid:
        .word 0,,0
        .word 1,,0
        .word 2,,1
        .word 3,,2

        .bss
parent_uarea: .block 070
child_uarea: .block 070
pipe_obj: .block 016
fake_pipe: .block 016
mm_calls: .block 1
last_mm_error: .block 1
sync_calls: .block 1
signal_calls: .block 1
        .globl __test_exit
__test_exit: .block 1
