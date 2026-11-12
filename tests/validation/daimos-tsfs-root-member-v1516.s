; Native PDP-6 TSFS root-set unit ownership.  All decisions execute the
; actual optional TSFS source helper, not a reimplemented C predicate.
        .text
        .globl main
        .globl tsfs_root_owns_dtc_unit_v1516
        .globl tsfs_file_shape_base
        .globl vfs_namespace_root
        .globl vfs_mount_limit
        .globl __test_exit

main:
        ; Public TSFS namespace root mount ID 4.  Logical members 0 and 1
        ; are on physical DTC units 0 and 5.  Seven potential padded zero
        ; selectors do not turn unit zero into extra members.
        movei   1,041
        lsh     1,030
        iori    1,050
        movem   1,tsfs_shape_v1516+3
        movei   4,1
        movem   4,stage_v1516
        setz    1,
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        caie    1,1
        jrst    fail_v1516
        movei   1,5
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        caie    1,1
        jrst    fail_v1516
        movei   4,2
        movem   4,stage_v1516
        movei   1,1
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        jumpn   1,fail_v1516
        movei   1,7
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        jumpn   1,fail_v1516

        ; A disk-root system must never call a tape an active TSFS root
        ; member, even when an unrelated TSFS-shaped slab is populated.
        movei   4,3
        movem   4,stage_v1516
        move    4,[060401000000]
        movem   4,vfs_namespace_root
        setz    1,
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        jumpn   1,fail_v1516
        move    4,[070401000000]
        movem   4,vfs_namespace_root

        ; Invalid DTC units and a nonexistent TSFS root mount are errors,
        ; never silent non-members (which could suppress a fatal action).
        movei   4,4
        movem   4,stage_v1516
        movei   1,010
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        camn    1,[-1]
        jrst    bad_unit_negative_v1516
        jrst    fail_v1516
bad_unit_negative_v1516:
        seto    1,
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        camn    1,[-1]
        jrst    bad_mount_v1516
        jrst    fail_v1516
bad_mount_v1516:
        ; Deliberately allocate a plausible but INACCESSIBLE slot 7, so
        ; skipping the published mount limit would falsely accept unit 0.
        movei   4,1
        lsh     4,030
        movem   4,tsfs_shape_v1516+6
        move    4,[070701000000]       ; mount ID 7 exceeds limit 6
        movem   4,vfs_namespace_root
        setz    1,
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        camn    1,[-1]
        jrst    bad_shape_v1516
        jrst    fail_v1516
bad_shape_v1516:
        move    4,[070401000000]
        movem   4,vfs_namespace_root
        setzm   tsfs_shape_v1516+3
        setz    1,
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        camn    1,[-1]
        jrst    single_zero_v1516
        jrst    fail_v1516

single_zero_v1516:
        ; A one-member root at physical unit zero: only bit zero set.
        movei   4,5
        movem   4,stage_v1516
        movei   4,1
        lsh     4,030
        movem   4,tsfs_shape_v1516+3
        setz    1,
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        caie    1,1
        jrst    fail_v1516
        movei   1,5
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        jumpn   1,fail_v1516

        ; Eight physical members occupy all eight unit bits.
        movei   4,6
        movem   4,stage_v1516
        movei   4,0377
        lsh     4,030
        movem   4,tsfs_shape_v1516+3
        setz    5,
all_units_v1516:
        move    1,5
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        caie    1,1
        jrst    fail_v1516
        addi    5,1
        caige   5,010
        jrst    all_units_v1516

        ; No mount shape storage is a hard error, not an absent tape.
        movei   4,7
        movem   4,stage_v1516
        setzm   tsfs_file_shape_base
        setz    1,
        pushj   17,tsfs_root_owns_dtc_unit_v1516
        camn    1,[-1]
        jrst    pass_v1516
        jrst    fail_v1516
pass_v1516:
        setz    1,
        popj    17,
fail_v1516:
        move    1,stage_v1516
        popj    17,

        .data
vfs_namespace_root: .word 070401000000
vfs_mount_limit: .word 6
tsfs_file_shape_base: .word tsfs_shape_v1516
tsfs_shape_v1516: .block 010

        .bss
stage_v1516: .block 1
__test_exit: .block 1
