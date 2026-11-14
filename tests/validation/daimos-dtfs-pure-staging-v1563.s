; v1563: actual production PURE vnode/mount owner scanners on PDP-6.
; Shell driver extracts the real source, with only process memory simulated.
        .text
        .globl main
        .globl __test_exit
        .globl proc_swap_backing_busy
        .globl proc_swap_mount_busy
        .globl proc_table
        .globl proc_high_slot
        .globl proc_swap_records

main:
        movei   010,cases_v1563
        movei   011,case_count_v1563
case_next_v1563:
        setzm   procs_v1563+3
        setzm   procs_v1563+4
        move    1,2(010)               ; exact SIDL/SRUN sched value
        movem   1,procs_v1563+5
        skipn   1,3(010)               ; existing stable u-area?
        jrst    case_no_uarea_v1563
        move    1,[uarea_v1563,,0400000]
        movem   1,procs_v1563+3
case_no_uarea_v1563:
        move    1,4(010)               ; physical resident VM base
        movem   1,procs_v1563+4
        setzm   uarea_v1563+066
        skipn   1,5(010)               ; credential slot extension bit
        jrst    case_cred_done_v1563
        movsi   1,001000              ; bit 27
        movem   1,uarea_v1563+066
case_cred_done_v1563:
        move    1,6(010)               ; current resident backing
        movem   1,records_v1563+1
        move    1,7(010)               ; swapped saved backing
        movem   1,uarea_v1563+0406
        move    1,1(010)               ; mount ID or executable vnode
        skipn   (010)
        jrst    case_mount_v1563
        pushj   17,proc_swap_backing_busy
        jrst    case_return_v1563
case_mount_v1563:
        pushj   17,proc_swap_mount_busy
case_return_v1563:
        came    1,010(010)             ; expected status
        jrst    case_bad_status_v1563
        move    1,records_v1563+1
        came    1,6(010)
        jrst    case_bad_v1563
        move    1,procs_v1563+5
        came    1,2(010)
        jrst    case_bad_v1563
        addi    010,011                ; nine case words (octal 011)
        sojg    011,case_next_v1563
        setz    1,
        popj    17,
case_bad_status_v1563:
        move    1,011
        iori    1,01000
        popj    17,
case_bad_v1563:
        move    1,011
        popj    17,

        .data
proc_table: .word procs_v1563
proc_high_slot: .word 2            ; upper exclusive slot
proc_swap_records: .word records_v1563
procs_v1563: .block 6             ; two three-word descriptors
records_v1563: .block 2
uarea_v1563: .block 0410
        .globl cases_v1563
        .globl case_count_v1563
        .bss
__test_exit: .block 1
