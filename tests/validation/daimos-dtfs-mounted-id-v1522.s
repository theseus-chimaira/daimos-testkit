; Real DTFS/BCACHE PDP-6 source harness for mounted-media identity.
; Only the raw controller, MM mount slab and production KCORE return
; helpers are fixture-controlled. The actual error marker, shared
; identity validator, directory loader, FSINFO and sync are linked.
        .text
        .globl main
        .globl dtfs_dtc_read
        .globl dtfs_dtc_write
        .globl dtfs_load
        .globl dtfs_sync
        .globl dtfs_space
        .globl dtfs_cache_mount
        .globl dtfs_media_base
        .globl dtfs_dir
        .globl fs_block_workspace
        .globl bcache_state
        .globl bcache_workspace_tag
        .globl vfs_mount_root_base
        .globl vfs_mount_limit
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base
        .globl kconst_2_2
        .globl kret_zero
        .globl kret_one
        .globl kret_neg1
        .globl mm_alloc_aligned_noreclaim
        .globl mm_free
        .globl dtfs_is_root
        .globl dtfs_is_file
        .globl dtfs_owner
        .globl test_raw_read_v1522
        .globl test_raw_write_v1522
        .globl __test_exit

main:
        movei   4,cache_slab_v1522
        movem   4,bcache_state
        setom   cache_slab_v1522
        setom   bcache_workspace_tag
        setom   online_v1522
        move    4,id_block_v1522
        xor     4,id_block_v1522+1
        xor     4,id_block_v1522+2
        setcm   4,4
        movem   4,id_block_v1522+3
        move    4,id_block_v1522+1
        movem   4,shape_v1522+1
        movem   4,shape_v1522+2
        move    4,id_block_v1522+2
        movem   4,extent_v1522+1
        movem   4,extent_v1522+2
        movei   4,3
        movem   4,media_v1522+1
        movem   4,media_v1522+2
        movem   4,media_v1522+3       ; D6FS slot must NOT be tagged

        ; Ordinary first mount use reads physical directory and caches it.
        movei   4,1
        movem   4,stage_v1522
        move    1,[050101000000]      ; legacy initial mount is valid
        pushj   17,dtfs_load
        jumpn   1,fail_v1522
        move    1,[050201000000]
        pushj   17,dtfs_load
        jumpn   1,fail_v1522
        move    4,dtfs_cache_mount
        caie    4,2
        jrst    fail_v1522
        move    1,[050201000000]
        pushj   17,dtfs_space
        jumple  1,fail_v1522          ; healthy FSINFO must work
        move    1,[050201000000]
        pushj   17,dtfs_sync
        jumpn   1,fail_v1522

        ; An uncached read on physical DTC3 fails. Both DTFS mounts on
        ; DTC3 become suspect; DTC0 and a D6FS slot using media word
        ; 3 must not be poisoned by a unit-only or slot-only guess.
        movei   4,2
        movem   4,stage_v1522
        setzm   online_v1522
        movei   1,3
        movei   2,0145
        movei   3,fs_block_workspace
        pushj   17,dtfs_dtc_read
        camn    1,[-1]
        jrst    check_read_mark_v1522
        jrst    fail_v1522
check_read_mark_v1522:
        move    4,media_v1522+1
        trnn    4,0200000
        jrst    fail_v1522
        move    4,media_v1522+2
        trnn    4,0200000
        jrst    fail_v1522
        move    4,media_v1522
        trne    4,0600000
        jrst    fail_v1522
        move    4,media_v1522+3
        trne    4,0600000
        jrst    fail_v1522
        skipn   dtfs_cache_mount
        jrst    check_failure_visible_v1522
        jrst    fail_v1522

        ; FSINFO and SYNC must not advertise the cached old directory.
check_failure_visible_v1522:
        movei   4,3
        movem   4,stage_v1522
        move    1,[050201000000]
        pushj   17,dtfs_space
        camn    1,[-1]
        jrst    check_sync_v1522
        jrst    fail_v1522
check_sync_v1522:
        move    1,[050201000000]
        pushj   17,dtfs_sync
        camn    1,[-1]
        jrst    same_media_v1522
        jrst    fail_v1522

        ; Same stamped medium returns. Native RBN0 is read physically;
        ; both complete saved ID halves must match before cache refill.
same_media_v1522:
        movei   4,4
        movem   4,stage_v1522
        setom   online_v1522
        move    1,[050201000000]
        pushj   17,dtfs_load
        jumpn   1,fail_v1522
        move    4,media_v1522+1
        trne    4,0600000
        jrst    fail_v1522
        move    4,dtfs_cache_mount
        caie    4,2
        jrst    fail_v1522

        ; Mount 3 remains suspect. A DIFFERENT valid stamped tape
        ; has matching magic/padding, but a different high ID.
        movei   4,5
        movem   4,stage_v1522
        aos     id_block_v1522+1
        pushj   17,checksum_v1522
        move    1,[050301000000]
        pushj   17,dtfs_load
        camn    1,[-1]
        jrst    check_replacement_v1522
        jrst    fail_v1522
check_replacement_v1522:
        move    4,media_v1522+2
        trnn    4,0200000
        jrst    fail_v1522
        move    4,dtfs_cache_mount
        caie    4,2                     ; must not publish mount 3
        jrst    fail_v1522

        ; A distinct replacement changing ONLY the low half must also
        ; fail. This is an independent oracle for the second 36 bits.
        movei   4,6
        movem   4,stage_v1522
        sos     id_block_v1522+1
        aos     id_block_v1522+2
        pushj   17,checksum_v1522
        move    1,[050301000000]
        pushj   17,dtfs_load
        camn    1,[-1]
        jrst    check_low_replacement_v1522
        jrst    fail_v1522
check_low_replacement_v1522:
        move    4,media_v1522+2
        trnn    4,0200000
        jrst    fail_v1522

        ; Return exact original identity; both previous mismatches
        ; preserved the mounted owner and the independent other mount.
        movei   4,7
        movem   4,stage_v1522
        sos     id_block_v1522+2
        pushj   17,checksum_v1522
        move    1,[050301000000]
        pushj   17,dtfs_load
        jumpn   1,fail_v1522
        move    4,media_v1522+2
        trne    4,0600000
        jrst    fail_v1522

        ; A partial physical WRITE is more serious than a read fault.
        ; Returning the same identity is not an atomic repair protocol.
        movei   4,010
        movem   4,stage_v1522
        setzm   online_v1522
        movei   1,3
        movei   2,0144
        movei   3,dir_block_v1522
        pushj   17,dtfs_dtc_write
        camn    1,[-1]
        jrst    check_write_mark_v1522
        jrst    fail_v1522
check_write_mark_v1522:
        move    4,media_v1522+1
        trnn    4,0400000
        jrst    fail_v1522
        move    4,media_v1522+2
        trnn    4,0400000
        jrst    fail_v1522
        setom   online_v1522
        move    1,[050201000000]
        pushj   17,dtfs_load
        camn    1,[-1]
        jrst    check_dirty_sync_v1522
        jrst    fail_v1522
check_dirty_sync_v1522:
        move    1,[050301000000]
        pushj   17,dtfs_sync
        camn    1,[-1]
        jrst    check_dirty_space_v1522
        jrst    fail_v1522
check_dirty_space_v1522:
        move    1,[050201000000]
        pushj   17,dtfs_space
        camn    1,[-1]
        jrst    check_unrelated_v1522
        jrst    fail_v1522

        ; An unrelated unattached physical unit cannot flag root
        ; mounts on another unit, nor clear old uncertain state.
check_unrelated_v1522:
        movei   4,011
        movem   4,stage_v1522
        movei   1,7
        movei   2,0146
        movei   3,fs_block_workspace
        pushj   17,dtfs_dtc_read
        camn    1,[-1]
        jrst    check_unrelated_flags_v1522
        jrst    fail_v1522
check_unrelated_flags_v1522:
        move    4,media_v1522
        trne    4,0600000
        jrst    fail_v1522
        move    4,media_v1522+3
        trne    4,0600000
        jrst    fail_v1522

        ; A legacy zero-ID DTFS mount can operate initially but must
        ; never be implicitly reattached after a physical read error.
        movei   4,012
        movem   4,stage_v1522
        setzm   online_v1522
        movei   1,0
        movei   2,0145
        movei   3,fs_block_workspace
        pushj   17,dtfs_dtc_read
        camn    1,[-1]
        jrst    legacy_return_v1522
        jrst    fail_v1522
legacy_return_v1522:
        setom   online_v1522
        move    1,[050101000000]
        pushj   17,dtfs_load
        camn    1,[-1]
        jrst    check_legacy_v1522
        jrst    fail_v1522
check_legacy_v1522:
        move    4,media_v1522
        trnn    4,0200000
        jrst    fail_v1522
        setz    1,
        popj    17,

checksum_v1522:
        move    4,id_block_v1522
        xor     4,id_block_v1522+1
        xor     4,id_block_v1522+2
        setcm   4,4
        movem   4,id_block_v1522+3
        popj    17,
fail_v1522:
        move    1,stage_v1522
        popj    17,

; Original controller signature with only media bytes/availability
; supplied by the fixture. The cache and mounted identity policy
; are the actual production source, not replacements.
test_raw_read_v1522:
        aos     raw_reads_v1522
        ; Real physical tape routines may clobber AC4..AC7. Force AC6
        ; away from the saved mount slot to verify its stack lifetime.
        movei   6,0777777
        move    4,1
        caie    4,3
        jrst    check_raw_unit_zero_v1522
        jrst    raw_unit_valid_v1522
check_raw_unit_zero_v1522:
        jumpe   4,raw_unit_valid_v1522
        jrst    kret_neg1
raw_unit_valid_v1522:
        skipn   online_v1522
        jrst    kret_neg1
        jumpe   2,raw_id_v1522
        caie    2,0144
        jrst    kret_neg1
        move    4,[dir_block_v1522,,0]
        hrr     4,3
        blt     4,0177(3)
        jrst    kret_zero
raw_id_v1522:
        jumpe   1,raw_legacy_v1522
        move    4,[id_block_v1522,,0]
        hrr     4,3
        blt     4,0177(3)
        jrst    kret_zero
raw_legacy_v1522:
        move    4,[zero_block_v1522,,0]
        hrr     4,3
        blt     4,0177(3)
        jrst    kret_zero
test_raw_write_v1522:
        aos     raw_writes_v1522
        skipn   online_v1522
        jrst    kret_neg1
        jrst    kret_zero
dtfs_is_root:
        jrst    kret_one
dtfs_is_file:
        jrst    kret_zero
dtfs_owner:
        jrst    kret_zero
mm_alloc_aligned_noreclaim:
mm_free:
        jrst    kret_neg1
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
kconst_2_2: .word 2,,2
vfs_mount_root_base: .word mount_roots_v1522
vfs_mount_limit: .word 4
dtfs_media_base: .word media_v1522
tsfs_file_shape_base: .word shape_v1522
tsfs_extent_media_base: .word extent_v1522
dtfs_dir: .word dir_cache_v1522
dtfs_cache_mount: .word 0
mount_roots_v1522:
        .word   050101000000          ; DTFS physical DTC0, legacy
        .word   050201000000          ; DTFS physical DTC3, ID stamped
        .word   050301000000          ; DTFS physical DTC3, ID stamped
        .word   060401000000          ; unrelated D6FS with unit value 3
media_v1522: .block 4
shape_v1522: .block 4
extent_v1522: .block 4
id_block_v1522:
        .word 0446466575421
        .word 0123456701234
        .word 0654321076543
        .word 0
        .block 0174
zero_block_v1522: .block 0200
dir_block_v1522:
        .word 0111
        .block 0177

        .bss
dir_cache_v1522: .block 0200
fs_block_workspace: .block 0200
cache_slab_v1522: .block 0201
bcache_workspace_tag: .block 1
bcache_state: .block 1
online_v1522: .block 1
raw_reads_v1522: .block 1
raw_writes_v1522: .block 1
stage_v1522: .block 1
__test_exit: .block 1
