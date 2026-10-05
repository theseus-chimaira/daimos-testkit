        .set root_target,060001010003
        .text
        .globl  main
        .globl  fs_mres_vector_dispatch
        .globl  kret_neg1
        .globl  vfs_mount
        .globl  vfs_mount_prevalidated
        .globl  mm_alloc
        .globl  mm_free
        .globl  fs_backing_direct_read
        .globl  fs_backing_direct_write
        .globl  d6fs_mres_vector
        .globl  d6fs_active_reader
        .globl  d6fs_reader_slots
        .globl  d6fs_provider_toggle_state
        .globl  d6fs_provider_space
        .globl  __test_exit

main:
        ; Existing boot root occupies public mount id 1 / slot 0.
        movei   1,root_reader
        movem   1,d6fs_reader_slots
        movem   1,d6fs_active_reader
        movei   2,1
        movem   2,root_reader+1
        move    2,[1,,0100]
        movem   2,root_reader+017       ; distinct root backing identity
        movei   2,01000
        movem   2,root_reader+020

        ; Mount a second independently backed D6FS through production
        ; FS_MRES_OP_MOUNT_UNIT.  AC4 is intentionally unused.
        movei   1,secondary_handoff
        movei   2,root_target
        movei   3,1                     ; VFS_MOUNT_RDONLY
        setz    4,
        movei   6,022                   ; FS_MRES_OP_MOUNT_UNIT
        pushj   17,d6fs_mres_dispatch
        jumpn   1,multimount_fail

        move    1,d6fs_reader_slots+1
        caie    1,secondary_reader
        jrst    multimount_fail
        move    1,d6fs_active_reader
        caie    1,secondary_reader
        jrst    multimount_fail

        ; Filesystem identity and physical backing are independent.
        move    1,secondary_reader+4    ; fs_uuid[0]
        came    1,[012345670123]
        jrst    multimount_fail
        move    1,secondary_reader+5    ; fs_uuid[1]
        came    1,[076543210765]
        jrst    multimount_fail
        move    1,secondary_reader+014  ; super A block
        caie    1,020
        jrst    multimount_fail
        move    1,secondary_reader+015  ; super B block
        caie    1,021
        jrst    multimount_fail
        move    1,secondary_reader+017  ; DRM set mask 0,2,3 + common base
        came    1,[0600015,,0400]
        jrst    multimount_fail
        move    1,secondary_reader+020  ; backing capacity
        caie    1,02000
        jrst    multimount_fail
        move    1,secondary_reader+016  ; trusted callbacks replaced marker
        came    1,[fs_backing_direct_read,,fs_backing_direct_write]
        jrst    multimount_fail

        ; Runtime state receives mount id 2; root state remains untouched.
        move    1,secondary_reader+1
        andi    1,0277
        caie    1,0202                  ; mount id 2, selected copy B
        jrst    multimount_fail
        move    1,root_reader+1
        andi    1,077
        caie    1,1
        jrst    multimount_fail
        move    1,root_reader+017
        came    1,[1,,0100]
        jrst    multimount_fail

        ; Normal vnode dispatch independently selects both contexts.
        movei   1,1
        lsh     1,030
        movei   6,1
        pushj   17,d6fs_mres_dispatch
        caie    1,root_reader
        jrst    multimount_fail
        movei   1,2
        lsh     1,030
        movei   6,1
        pushj   17,d6fs_mres_dispatch
        caie    1,secondary_reader
        jrst    multimount_fail

        setz    1,
        popj    17,

multimount_fail:
        movei   1,1
        popj    17,

; mm_alloc fifth argument is basep at -1(17) after PUSHJ's return word.
mm_alloc:
        move    5,-1(17)
        movei   6,secondary_reader
        movem   6,(5)
        setz    1,
        popj    17,

mm_free:
        setz    1,
        popj    17,

; vfs_mount sixth argument is rootp at -2(17).  Allocate public mount id 2.
vfs_mount:
vfs_mount_prevalidated:
        move    5,-2(17)
        move    6,[060201000003]
        movem   6,(5)
        movei   7,1                     ; zero-based VFS slot 1
        setz    1,
        popj    17,

fs_mres_vector_dispatch:
        move    1,d6fs_active_reader
        popj    17,

kret_neg1:
        seto    1,
        popj    17,

; Remount opcode is not exercised by this oracle.
d6fs_provider_toggle_state:
        seto    1,
        popj    17,

; SPACE is outside this mount-isolation oracle.
d6fs_provider_space:
        seto    1,
        popj    17,

fs_backing_direct_read:
        setz    1,
        popj    17,
fs_backing_direct_write:
        setz    1,
        popj    17,

        .data
secondary_handoff:
        .word   7                       ; alloc cursor
        .word   0330200                 ; packed summary start + copy B
        .word   012                     ; sequence
        .word   0                       ; clean state / cache tag
        .word   012345670123            ; UUID 0
        .word   076543210765            ; UUID 1
        .word   02000                   ; total blocks
        .word   3                       ; root FCB
        .word   040                     ; FCB start
        .word   010                     ; FCB count
        .word   060                     ; freemap start
        .word   2                       ; freemap blocks
        .word   020                     ; super A block
        .word   021                     ; super B block
        .word   044066263602            ; D6FS_MOUNT_MAGIC
        .word   0600015,,0400           ; DRM INTERLEAVE set mask,,base
        .word   02000                   ; backing capacity

d6fs_mres_vector:
        .word   0

        .bss
d6fs_active_reader:
        .block  1
d6fs_reader_slots:
        .block  4
root_reader:
        .block  021
secondary_reader:
        .block  021
__test_exit:
        .block  1
