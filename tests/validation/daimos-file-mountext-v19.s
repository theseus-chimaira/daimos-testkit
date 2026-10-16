; Exercise the production FILE mount-extension leaves on the PDP-6.
; Mount IDs 2 and 26 have identical three low bits, provider, kind, index;
; only the u-area map can distinguish their canonical vnodes.
        .text
        .globl  main
        .globl  kret_zero
        .globl  kret_neg1
        .globl  pipe_add_ref
        .globl  pipe_close_ref
        .globl  vfs_sync
        .globl  dpy_write_words_jump
main:
        movei   0,1
        movem   0,stage
        movei   1,6
        lsh     1,036                  ; D6FS provider
        movei   2,032
        lsh     2,030                  ; public mount ID 26
        ior     1,2
        movei   2,2
        lsh     2,022                  ; local regular vnode kind
        ior     1,2
        iori    1,012345
        movem   1,original26
        movei   2,3                    ; readable and writable
        setz    3,
        pushj   17,file_new_fd
        jumpn   1,test_fail            ; fd 0
        movei   0,011
        movem   0,stage
        movei   1,fd_table
        pushj   17,file_node_from_fd
        move    4,1
        xor     4,original26
        jumpn   4,test_fail_xor
        movei   0,012
        movem   0,stage
        move    4,fd_table+041
        andi    4,3
        caie    4,3                    ; 26 >> 3 = 3
        jrst    test_fail
        movei   0,2
        movem   0,stage

        move    1,original26
        move    2,[007700000000]       ; six mount bits (vnode bits 24..29)
        andcm   1,2
        movei   2,2
        lsh     2,030
        ior     1,2                    ; same node on mount ID 2
        movem   1,original2
        movei   2,3
        setz    3,
        pushj   17,file_new_fd
        caie    1,1
        jrst    test_fail
        movei   0,021
        movem   0,stage
        movei   1,fd_table+2
        pushj   17,file_node_from_fd
        move    4,1
        xor     4,original2
        jumpn   4,test_fail_xor
        movei   0,3
        movem   0,stage

        ; Mark both descriptors as regular so FLOCK is available. They must
        ; never affect each other's lock state despite equal low mount bits.
        movsi   4,010
        iorm    4,fd_table
        iorm    4,fd_table+2
        setz    1,                      ; lock fd0 exclusively
        movei   2,2
        pushj   17,file_lock
        jumpn   1,test_fail
        move    4,fd_table
        tlnn    4,000020               ; fd0 is locked
        jrst    test_fail
        move    4,fd_table+2
        tlne    4,000020               ; fd1 remains regular and unlocked
        jrst    test_fail
        movei   0,4
        movem   0,stage

        setz    1,                      ; dup fd0 to fd2
        pushj   17,file_dup
        caie    1,2
        jrst    test_fail
        movei   1,fd_table+4
        pushj   17,file_node_from_fd
        came    1,original26
        jrst    test_fail
        movei   0,5
        movem   0,stage

        ; Duplicate into fd3 using DUP2; copy must replace stale extension.
        move    1,original2
        movei   2,3
        setz    3,
        pushj   17,file_new_fd
        caie    1,3
        jrst    test_fail
        setz    1,
        movei   2,3
        pushj   17,file_dup2
        caie    1,3
        jrst    test_fail
        movei   1,fd_table+6
        pushj   17,file_node_from_fd
        came    1,original26
        jrst    test_fail
        movei   0,6
        movem   0,stage

        setz    1,
        pushj   17,file_close
        jumpn   1,test_fail
        move    4,fd_table+041
        andi    4,3
        jumpn   4,test_fail            ; fd0 bits cleared on close
        movei   1,fd_table+4
        pushj   17,file_node_from_fd
        came    1,original26           ; duplicate still intact
        jrst    test_fail
        movei   0,7
        movem   0,stage

        ; Mount 2's ordinary descriptor must not be changed by unmount 26.
        movei   1,032                  ; public mount ID 26
        pushj   17,file_unlock_mount
        move    4,fd_table+2
        tlnn    4,000010               ; mount 2 still regular
        jrst    test_fail
        move    4,fd_table+4
        tlne    4,000030               ; mount 26 lock/regular state cleared
        jrst    test_fail

        ; TSFS root shares provider 7 / kind 1 with PIPE, but is mounted
        ; at public ID 8. Closing it must call VFS sync, never PIPE cleanup.
        movei   0,010
        movem   0,stage
        movei   1,7
        lsh     1,036
        movei   2,010
        lsh     2,030
        ior     1,2
        movei   2,1
        lsh     2,022
        ior     1,2
        iori    1,027
        movem   1,tsfs_root8
        movei   2,1
        movei   3,1
        pushj   17,file_new_fd
        caie    1,0                    ; fd0 was just closed
        jrst    test_fail
        setz    1,
        pushj   17,file_close
        jumpn   1,test_fail
        skipe   pipe_close_count
        jrst    test_fail
        move    4,tsfs_root8
        came    4,last_synced
        jrst    test_fail

        setz    1,
        popj    17,
test_fail:
        move    1,stage
        popj    17,
test_fail_xor:
        move    1,4                    ; report the missing/corrupt vnode bits
        popj    17,
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,
pipe_add_ref:
dpy_write_words_jump:
        setz    1,
        popj    17,
pipe_close_ref:
        aos     pipe_close_count
        setz    1,
        popj    17,
vfs_sync:
        movem   1,last_synced
        setz    1,
        popj    17,

        .data
        .globl file_table
file_table: .word fd_table

        .bss
fd_table: .block 042                ; 16*2 words; map at +041
original26: .block 1
original2: .block 1
tsfs_root8: .block 1
last_synced: .block 1
pipe_close_count: .block 1
stage: .block 1
        .globl __test_exit
__test_exit: .block 1
