; v1555: actual PDP-6 central DTFS write veneer fail-closed V2 guard.
; Raw Type-551 DTC and BCACHE/poison boundaries are strict test oracles.
        .text
        .globl main
        .globl __test_exit
        .globl dtfs_dtc_write
        .globl dtfs_dtc_write_jump
        .globl dtfs_mark_unit_suspect_v1522
        .globl bcache_invalidate_all
        .globl vfs_mount_root_base
        .globl vfs_mount_limit
        .globl dtfs_media_base
        .globl dtfs_cache_mount
        .globl kret_zero
        .globl kret_neg1

main:
        movei   010,case_table_v1555
        movei   011,014                  ; 12 distinct physical-write cases
next_case_v1555:
        move    5,(010)
        movem   5,root_v1555
        move    5,1(010)
        movem   5,media_v1555
        move    5,2(010)
        movem   5,root_v1555+1
        move    5,3(010)
        movem   5,media_v1555+1
        move    5,5(010)
        movem   5,raw_fault_v1555
        setzm   raw_calls_v1555
        setzm   flush_calls_v1555
        setzm   poison_calls_v1555
        movei   5,06765
        movem   5,pending_data_v1555

        move    1,4(010)                ; unit argument to real veneer
        movei   2,0145                  ; ordinary DATA block, not RBN0
        movei   3,pending_data_v1555
        pushj   17,dtfs_dtc_write
        came    1,6(010)
        jrst    case_failed_v1555
        move    5,raw_calls_v1555
        came    5,7(010)
        jrst    case_failed_v1555
        move    5,flush_calls_v1555
        came    5,010(010)
        jrst    case_failed_v1555
        move    5,poison_calls_v1555
        came    5,011(010)
        jrst    case_failed_v1555
        move    5,pending_data_v1555
        caie    5,06765                 ; pending DATA never overwritten
        jrst    case_failed_v1555
        addi    010,012                  ; ten words per case
        sojg    011,next_case_v1555
        setz    1,
        popj    17,
case_failed_v1555:
        move    1,011                    ; failing case index is nonzero
        popj    17,

dtfs_dtc_write_jump:
        aos     raw_calls_v1555
        caie    1,3                      ; physical unit under test
        jrst    wrong_io_v1555
        caie    2,0145
        jrst    wrong_io_v1555
        caie    3,pending_data_v1555
        jrst    wrong_io_v1555
        skipn   raw_fault_v1555
        jrst    raw_write_success_v1555
        seto    1,
        popj    17,
raw_write_success_v1555:
        setz    1,
        popj    17,
wrong_io_v1555:
        movei   1,0777                  ; wrong raw ABI must fail
        popj    17,

bcache_invalidate_all:
        aos     flush_calls_v1555
        popj    17,
dtfs_mark_unit_suspect_v1522:
        caie    1,3
        jrst    wrong_poison_v1555
        caie    2,0400000
        jrst    wrong_poison_v1555
        aos     poison_calls_v1555
        popj    17,
wrong_poison_v1555:
        movei   5,0100
        addm    5,poison_calls_v1555
        popj    17,
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
; root0, media0, root1, media1, unit, raw-fault,
; result, raw transfers, BCACHE invalidations, sticky poison.
case_table_v1555:
        .word 050101000000           ; V2 on DTC3, must refuse
        .word 0100003
        .word 0
        .word 0
        .word 3
        .word 0
        .word -1
        .word 0
        .word 0
        .word 0
        .word 050101000000           ; V1 legacy write succeeds
        .word 3
        .word 0
        .word 0
        .word 3
        .word 0
        .word 0
        .word 1
        .word 1
        .word 0
        .word 050101000000           ; V2 on other unit, unrelated write
        .word 0100002
        .word 0
        .word 0
        .word 3
        .word 0
        .word 0
        .word 1
        .word 1
        .word 0
        .word 050101000000           ; V2 on second published slot DTC3
        .word 2
        .word 050201000000
        .word 0100003
        .word 3
        .word 0
        .word -1
        .word 0
        .word 0
        .word 0
        .word 060101000000           ; non-DTFS root cannot poison guard
        .word 0100003
        .word 0
        .word 0
        .word 3
        .word 0
        .word 0
        .word 1
        .word 1
        .word 0
        .word 0                      ; retired mount media tag is stale
        .word 0100003
        .word 0
        .word 0
        .word 3
        .word 0
        .word 0
        .word 1
        .word 1
        .word 0
        .word 050101000000           ; V2 refuses even if raw would error
        .word 0100003
        .word 0
        .word 0
        .word 3
        .word 1
        .word -1
        .word 0
        .word 0
        .word 0
        .word 050101000000           ; V1 physical write error poisons
        .word 3
        .word 0
        .word 0
        .word 3
        .word 1
        .word -1
        .word 1
        .word 1
        .word 1
        .word 050101000000           ; V2 second slot + V1 same unit
        .word 3
        .word 050201000000
        .word 0100003
        .word 3
        .word 0
        .word -1
        .word 0
        .word 0
        .word 0
        .word 050101000000           ; stale V2 in retired second slot
        .word 3
        .word 0
        .word 0100003
        .word 3
        .word 0
        .word 0
        .word 1
        .word 1
        .word 0
        .word 050101000000           ; prearmed V2 also read-only now
        .word 0140003
        .word 0
        .word 0
        .word 3
        .word 0
        .word -1
        .word 0
        .word 0
        .word 0
        .word 050101000000           ; both slots V2, refuse
        .word 0100003
        .word 050201000000
        .word 0100003
        .word 3
        .word 0
        .word -1
        .word 0
        .word 0
        .word 0

vfs_mount_root_base: .word root_v1555
dtfs_media_base: .word media_v1555
dtfs_cache_mount: .word 0
vfs_mount_limit: .word 2
root_v1555: .block 2
media_v1555: .block 2
raw_calls_v1555: .word 0
flush_calls_v1555: .word 0
poison_calls_v1555: .word 0
raw_fault_v1555: .word 0
pending_data_v1555: .block 0200
        .bss
__test_exit: .block 1
