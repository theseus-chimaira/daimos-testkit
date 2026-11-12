; v1519: execute the real optional DTFS MOUNT_UNIT native-media gate.
; The VFS publisher and physical tape are isolated at their normal ABIs.
        .text
        .globl  main
        .globl  dtfs_mount_unit
        .globl  dtfs_dtc_read_jump
        .globl  dtfs_cache_mount
        .globl  fs_block_workspace
        .globl  bcache_invalidate_all
        .globl  bcache_state
        .globl  bcache_workspace_tag
        .globl  vfs_mount_prevalidated
        .globl  vfs_current_owner
        .globl  dtfs_patch_media
        .globl  kret_zero
        .globl  kconst_1_1
        .globl  kconst_2_2
        .globl  kconst_3_3
        .globl  tsfs_file_shape_base
        .globl  tsfs_extent_media_base
        .globl  __test_exit

main:
        setzm   raw_reads_v1519
        setzm   published_v1519
        setzm   patched_v1519
        movei   4,cache_slab_v1519
        movem   4,bcache_state
        setom   media_online_v1519
        pushj   17,valid_media_v1519

        movei   4,1
        movem   4,stage_v1519
        pushj   17,try_mount_v1519
        jumpn   1,fail_v1519
        move    4,raw_reads_v1519
        caie    4,2                   ; directory + legacy block zero
        jrst    fail_v1519
        move    4,published_v1519
        caie    4,1
        jrst    fail_v1519
        move    4,patched_v1519
        caie    4,1
        jrst    fail_v1519

        ; The workspace still contains the validated first tape.  Change
        ; the physical medium to the same format with a wrong magic.
        ; Bypassing the direct raw read must not allow the stale buffer.
        movei   4,2
        movem   4,stage_v1519
        setzm   media_dir_v1519+0177
        pushj   17,reseed_stale_v1519
        pushj   17,try_mount_v1519
        camn    1,[-1]
        jrst    check_bad_magic_v1519
        jrst    fail_v1519
check_bad_magic_v1519:
        pushj   17,check_refusal_v1519
        jumpn   1,fail_v1519

        ; Restore format then corrupt its reserved owner for block zero.
        movei   4,3
        movem   4,stage_v1519
        pushj   17,valid_media_v1519
        setzm   media_dir_v1519
        pushj   17,try_mount_v1519
        camn    1,[-1]
        jrst    check_bad_owner0_v1519
        jrst    fail_v1519
check_bad_owner0_v1519:
        pushj   17,check_refusal_v1519
        jumpn   1,fail_v1519

        ; Corrupt the directory's own reserved allocation tag.
        movei   4,4
        movem   4,stage_v1519
        pushj   17,valid_media_v1519
        setzm   media_dir_v1519+014
        pushj   17,try_mount_v1519
        camn    1,[-1]
        jrst    check_bad_dir_owner_v1519
        jrst    fail_v1519
check_bad_dir_owner_v1519:
        pushj   17,check_refusal_v1519
        jumpn   1,fail_v1519

        ; Three terminal native owner tags must match precisely.
        movei   4,5
        movem   4,stage_v1519
        pushj   17,valid_media_v1519
        setzm   media_dir_v1519+0122
        pushj   17,try_mount_v1519
        camn    1,[-1]
        jrst    check_bad_trailer_v1519
        jrst    fail_v1519
check_bad_trailer_v1519:
        pushj   17,check_refusal_v1519
        jumpn   1,fail_v1519

        ; An ordinary physical read error is not a lost-media verdict.
        ; It still must not publish a mount or cached clean identity.
        movei   4,6
        movem   4,stage_v1519
        pushj   17,valid_media_v1519
        setzm   media_online_v1519
        pushj   17,try_mount_v1519
        camn    1,[-1]
        jrst    check_offline_v1519
        jrst    fail_v1519
check_offline_v1519:
        pushj   17,check_refusal_v1519
        jumpn   1,fail_v1519

        ; Same tape returns: a fresh successful read must now permit
        ; publication.  This does NOT authenticate a different tape.
        movei   4,7
        movem   4,stage_v1519
        setom   media_online_v1519
        pushj   17,try_mount_v1519
        jumpn   1,fail_v1519
        move    4,published_v1519
        caie    4,2
        jrst    fail_v1519
        move    4,patched_v1519
        caie    4,2
        jrst    fail_v1519
        move    4,raw_reads_v1519
        caie    4,011                 ; two physical reads on valid mount
        jrst    fail_v1519
        setz    1,
        popj    17,

try_mount_v1519:
        movei   4,0777
        movem   4,returned_root_v1519
        movei   1,3                    ; DTC unit 3, independent of root
        move    2,[060101000000]       ; known prevalidated target
        movei   3,011                  ; native DTFS, read-only
        movei   4,returned_root_v1519
        pushj   17,dtfs_mount_unit
        popj    17,

check_refusal_v1519:
        move    4,published_v1519
        caie    4,1
        jrst    check_refusal_bad_v1519
        move    4,patched_v1519
        caie    4,1
        jrst    check_refusal_bad_v1519
        move    4,returned_root_v1519
        caie    4,0777
        jrst    check_refusal_bad_v1519
        skipn   dtfs_cache_mount
        jrst    check_refusal_cache_v1519
        jrst    check_refusal_bad_v1519
check_refusal_cache_v1519:
        move    4,bcache_workspace_tag
        came    4,[-1]
        jrst    check_refusal_bad_v1519
        move    4,cache_slab_v1519
        came    4,[-1]
        jrst    check_refusal_bad_v1519
        setz    1,
        popj    17,
check_refusal_bad_v1519:
        movei   1,1
        popj    17,

reseed_stale_v1519:
        move    4,[3,,0144]
        movem   4,bcache_workspace_tag
        movem   4,cache_slab_v1519
        move    4,[0446446632021]
        movem   4,fs_block_workspace+0177
        movei   4,2
        movem   4,dtfs_cache_mount
        popj    17,

valid_media_v1519:
        move    4,[0740000000000]      ; owner block 0 = 036
        movem   4,media_dir_v1519
        move    4,[0360000000]         ; owner block 0144 = 036
        movem   4,media_dir_v1519+014
        move    4,[0167572]            ; terminal three tags = 035
        movem   4,media_dir_v1519+0122
        move    4,[0446446632021]
        movem   4,media_dir_v1519+0177
        popj    17,

fail_v1519:
        move    1,stage_v1519
        popj    17,

; Actual raw DTC jump target patched at the same instruction that MINIT
; patches in production.  Validate exact physical unit and directory RBN.
dtfs_dtc_read_jump:
        jrst    test_raw_read_v1519
test_raw_read_v1519:
        aos     raw_reads_v1519
        caie    1,3
        jrst    physical_fail_v1519
        caie    3,fs_block_workspace
        jrst    physical_fail_v1519
        skipn   media_online_v1519
        jrst    physical_fail_v1519
        move    4,3
        caie    2,0144
        jrst    physical_identity_v1519
        hrli    4,media_dir_v1519
        jrst    physical_copy_v1519
physical_identity_v1519:
        jumpe   2,physical_identity_copy_v1519
        jrst    physical_fail_v1519
physical_identity_copy_v1519:
        hrli    4,media_id_v1519
physical_copy_v1519:
        move    5,3
        addi    5,0177
        blt     4,(5)
        jrst    kret_zero
physical_fail_v1519:
        seto    1,
        popj    17,

; The VFS publisher is the only test-controlled boundary.  It MUST NOT
; run for an invalid tape, and receives the public ROOT node only after
; the production validation of the physical native directory.
vfs_mount_prevalidated:
        aos     published_v1519
        move    4,-2(17)               ; sixth argument rootp
        move    5,[050201000000]       ; valid DTFS ROOT, public mount 2
        movem   5,(4)
        jrst    kret_zero
vfs_current_owner:
        setz    1,
        popj    17,
dtfs_patch_media:
        aos     patched_v1519
        popj    17,
kret_zero:
        setz    1,
        popj    17,

        .data
kconst_1_1: .word 1,,1
kconst_2_2: .word 2,,2
kconst_3_3: .word 3,,3
dtfs_cache_mount: .word 0
tsfs_file_shape_base: .word shape_slabs_v1519
tsfs_extent_media_base: .word extent_slabs_v1519
        .bss
media_dir_v1519: .block 0200
media_id_v1519: .block 0200
shape_slabs_v1519: .block 010
extent_slabs_v1519: .block 010
fs_block_workspace: .block 0200
bcache_state: .block 1
bcache_workspace_tag: .block 1
cache_slab_v1519: .block 0201
media_online_v1519: .block 1
raw_reads_v1519: .block 1
published_v1519: .block 1
patched_v1519: .block 1
returned_root_v1519: .block 1
stage_v1519: .block 1
__test_exit: .block 1
