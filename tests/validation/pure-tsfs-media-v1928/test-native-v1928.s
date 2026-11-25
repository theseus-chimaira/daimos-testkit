; Actual TSFS mount and media proof; controlled physical read callback.
        .text
        .globl main
main:
        movei   1,handoff_v1928
        setz    2,
        movei   3,1
        movei   4,root_out_v1928
        pushj   17,tsfs_mount_set
        jumpn   1,mount_fail_v1928
        move    1,root_out_v1928
        came    1,[070101000000]
        jrst    mount_fail_v1928
        move    1,media_v1928
        came    1,handoff_v1928
        jrst    mount_fail_v1928
        move    1,map_v1928
        came    1,handoff_v1928+1
        jrst    mount_fail_v1928
        move    1,extent_v1928
        came    1,handoff_v1928+2
        jrst    mount_fail_v1928
        setz    5,
mount_id_v1928:
        move    1,tsfs_identity_v1928(5)
        came    1,handoff_v1928+3(5)
        jrst    mount_fail_v1928
        aoj     5,
        caige   5,5
        jrst    mount_id_v1928
        ; Root publication must not be overwritten by a second mount.
        movei   1,handoff_v1928
        setz    2,
        movei   3,1
        movei   4,root_out_v1928
        pushj   17,tsfs_mount_set
        jumpge  1,mount_fail_v1928
        movei   010,cases_v1928
        movei   011,1
case_loop_v1928:
        move    1,(010)
        ; Keep the suspect bit through retries; only the proof may clear.
        move    2,map_v1928
        and     2,[040000000000]
        ior     1,2
        movem   1,map_v1928
        movei   1,2(010)
        movem   1,records_v1928
        movei   1,04444
        movem   1,bcache_workspace_tag
        movem   1,cache_tag_v1928
        movem   1,dtfs_cache_mount
        move    1,[070102012345]
        pushj   17,tsfs_pure_media_v1928
        came    1,1(010)
        jrst    case_fail_v1928
        move    2,(010)
        jumpge  1,case_map_v1928
        tlo     2,040000
case_map_v1928:
        came    2,map_v1928
        jrst    case_fail_v1928
        skipn   dtfs_cache_mount
        jrst    case_tags_v1928
        jrst    case_fail_v1928
case_tags_v1928:
        move    1,bcache_workspace_tag
        came    1,[-1]
        jrst    case_fail_v1928
        move    1,cache_tag_v1928
        came    1,[-1]
        jrst    case_fail_v1928
        setz    5,
case_identity_v1928:
        move    1,tsfs_identity_v1928(5)
        came    1,handoff_v1928+3(5)
        jrst    case_fail_v1928
        aoj     5,
        caige   5,5
        jrst    case_identity_v1928
        addi    010,022
        aoj     011,
        caig    011,case_count_v1928
        jrst    case_loop_v1928
        setz    1,
        popj    17,
mount_fail_v1928:
        movei   1,0777
        popj    17,
case_fail_v1928:
        move    1,011
        popj    17,

        .globl dtfs_dtc_read_jump
dtfs_dtc_read_jump:
        jrst    raw_v1928
raw_v1928:
        caile   1,7
        jrst    kret_neg1
        cail    2,1
        caile   2,2
        jrst    kret_neg1
        caie    3,fs_block_workspace
        jrst    kret_neg1
        lsh     1,1
        add     1,2
        add     1,records_v1928
        move    4,-1(1)
        jumpe   4,kret_neg1
        caie    4,1
        jrst    raw_copy_v1928
        jrst    kret_zero              ; falsely reports success
raw_copy_v1928:
        hrl     4,4
        hrri    4,fs_block_workspace
        blt     4,fs_block_workspace+0177
        jrst    kret_zero

        .globl vfs_mount_prevalidated
vfs_mount_prevalidated:
        move    5,[070101000000]
        movem   5,vfs_namespace_root
        move    4,-2(17)
        movem   5,(4)
        jrst    kret_zero
        .globl bcache_reclaim
bcache_reclaim:
        jrst    kret_zero
        .globl kret_zero
        .globl kret_neg1
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,
        .data
handoff_v1928:
        .word 1,,4
        .word 0004100000050
        .word 1,,5
        .word 01234567
        .word 07654321
        .word 7
        .word 3
        .word 0123456701234
        .globl kconst_1_1
        .globl kconst_2_2
kconst_1_1: .word 1,,1
kconst_2_2: .word 2,,2
        .globl vfs_mount_limit
vfs_mount_limit: .word 4
        .globl dtfs_media_base
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base
dtfs_media_base: .word media_v1928
tsfs_file_shape_base: .word map_v1928
tsfs_extent_media_base: .word extent_v1928
        .globl bcache_state
bcache_state: .word cache_tag_v1928
        .bss
        .globl fs_block_workspace
        .globl dtfs_cache_mount
        .globl bcache_workspace_tag
        .globl vfs_namespace_root
        .globl __test_exit
fs_block_workspace: .block 0200
dtfs_cache_mount: .block 1
bcache_workspace_tag: .block 1
cache_tag_v1928: .block 1
vfs_namespace_root: .block 1
media_v1928: .block 4
map_v1928: .block 4
extent_v1928: .block 4
root_out_v1928: .block 1
records_v1928: .block 1
__test_exit: .block 1
