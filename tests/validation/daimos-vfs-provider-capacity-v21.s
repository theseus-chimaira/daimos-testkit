; Native PDP-6 D6FS mount-reader dispatch and optional TENEX/ITS personality
; at public mount IDs 10 and 26.  Slot 26 must never alias mount 2/10.
        .text
        .globl main
main:
        ; No MM overflow: the test allocates precisely 26 entries.
        movei   1,readers+031
        movem   1,expected_reader
        movem   1,readers+031
        movei   1,readers+011
        movem   1,readers+011
        movei   1,6
        lsh     1,036                   ; D6FS provider
        movei   2,032
        lsh     2,030                   ; public mount ID 26
        ior     1,2
        movei   6,1
        pushj   17,d6fs_mres_reg_dispatch
        jumpn   1,fail
        move    3,d6fs_active_reader
        came    3,expected_reader
        jrst    fail

        movei   1,6
        lsh     1,036
        movei   2,012
        lsh     2,030
        ior     1,2
        movei   6,1
        pushj   17,d6fs_mres_reg_dispatch
        jumpn   1,fail
        move    3,d6fs_active_reader
        came    3,readers+011
        jrst    fail

        movei   1,6
        lsh     1,036
        movei   2,033
        lsh     2,030                   ; beyond the 26-entry slab
        ior     1,2
        movei   6,1
        pushj   17,d6fs_mres_reg_dispatch
        camn    1,[-1]
        jrst    check_personality
        jrst    fail

check_personality:
        ; Foreign personality tags are in the existing media table, not a
        ; four-slot XCT table.  High half stores owner, RH stores personality.
        movei   1,032                   ; public mount 26
        movei   2,011                   ; TENEX + unit 1
        pushj   17,dtfs_patch_media
        movei   1,012                   ; public mount 10
        movei   2,022                   ; ITS + unit 2
        pushj   17,dtfs_patch_media
        movei   1,1                     ; public mount 1
        movei   2,3                     ; native + unit 3
        pushj   17,dtfs_patch_media

        movei   1,5
        lsh     1,036
        movei   2,032
        lsh     2,030
        ior     1,2
        movem   1,mount26
        pushj   17,dtfs_personality
        caie    1,010
        jrst    fail
        movei   1,5
        lsh     1,036
        movei   2,012
        lsh     2,030
        ior     1,2
        pushj   17,dtfs_personality
        caie    1,020
        jrst    fail
        movei   1,5
        lsh     1,036
        movei   2,1
        lsh     2,030
        ior     1,2
        pushj   17,dtfs_personality
        jumpn   1,fail

        movei   1,5
        lsh     1,036
        movei   2,033
        lsh     2,030
        ior     1,2
        pushj   17,dtfs_personality
        jumpn   1,fail                 ; out-of-range yields no personality
        movei   1,5
        lsh     1,036
        movei   2,033                   ; public mount ID 27
        lsh     2,030
        ior     1,2
        pushj   17,dtfs_space
        camn    1,[-1]
        jrst    check_space26
        jrst    fail

check_space26:
        ; DTFS SPACE must admit slot 26; the native allocation map has
        ; 01101 blocks of 0200 words when every map entry is unallocated.
        move    1,mount26
        pushj   17,dtfs_space
        movei   3,01101
        lsh     3,7
        came    1,3
        jrst    fail
        jumpn   2,fail

        setz    1,
        popj    17,
fail:
        movei   1,1
        popj    17,

        .globl fs_mres_vector_dispatch
fs_mres_vector_dispatch:
        setz    1,
        popj    17,
        .globl d6fs_mount_validated
d6fs_mount_validated:
        .globl d6fs_provider_toggle_state
d6fs_provider_toggle_state:
        .globl d6fs_provider_space
d6fs_provider_space:
        seto    1,
        popj    17,
        .globl kret_neg1
kret_neg1:
        seto    1,
        popj    17,
        .globl bcache_reclaim
bcache_reclaim:
        popj    17,
        .globl dtfs_owner
dtfs_owner:
        setz    1,
        popj    17,

        .data
        .globl d6fs_reader_slots_base
d6fs_reader_slots_base: .word readers
        .globl d6fs_active_reader
d6fs_active_reader: .word 0
        .globl dtfs_media_base
dtfs_media_base: .word media
        .globl vfs_mount_limit
vfs_mount_limit: .word 032            ; 26 decimal mount slots
        .globl d6fs_mres_vector
d6fs_mres_vector: .word 0
        .bss
readers: .block 032
media: .block 032
expected_reader: .block 1
mount26: .block 1
        .globl __test_exit
__test_exit: .block 1
