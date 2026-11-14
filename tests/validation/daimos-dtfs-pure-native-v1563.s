; Native v1563: compiled proc_swap_attach and real VFS DTFS admission.
; Stub only process table and boot mount/media words.
        .text
        .globl main
        .globl proc_swap_attach
        .globl proc_table
        .globl proc_swap_records
        .globl vfs_mount_root_base
        .globl vfs_mount_limit
        .globl dtfs_media_base
        .globl __test_exit

main:
        movei   010,cases_v1563
        movei   011,case_count_v1563
case_next_v1563:
        move    1,1(010)
        movem   1,roots_v1563
        move    1,2(010)
        movem   1,media_v1563
        move    1,3(010)
        jumpe   1,case_no_uarea_v1563
        move    1,[uarea_v1563,,0400000]
        jrst    case_meta_ready_v1563
case_no_uarea_v1563:
        setz    1,
case_meta_ready_v1563:
        movem   1,procs_v1563+3
        move    1,4(010)
        movem   1,procs_v1563+5
        move    1,5(010)
        movem   1,uarea_v1563+066
        move    1,6(010)
        movem   1,records_v1563+1
        movei   1,1                     ; target proc slot
        move    2,(010)                ; exact vnode
        movei   3,0700                  ; PURE text words
        movei   4,1                     ; PURE
        pushj   17,proc_swap_attach
        came    1,7(010)
        jrst    case_bad_status_v1563
        move    1,records_v1563+1
        came    1,010(010)
        jrst    case_bad_v1563
        move    1,uarea_v1563+066
        came    1,011(010)
        jrst    case_bad_v1563
        move    1,procs_v1563+5
        came    1,012(010)
        jrst    case_bad_v1563
        addi    010,013                ; 11 decimal words per case
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
proc_swap_records: .word records_v1563
vfs_mount_root_base: .word roots_v1563
vfs_mount_limit: .word 1
dtfs_media_base: .word media_v1563
procs_v1563: .block 6
records_v1563: .block 2
roots_v1563: .block 1
media_v1563: .block 1
uarea_v1563: .block 0410
        .globl cases_v1563
        .globl case_count_v1563
        .bss
__test_exit: .block 1
