; Exercise actual native vfs_create UMASK9 extraction from credential word.
; Deliberately poison old descriptor-extension location to catch regressions.
        .text
        .globl main
        .globl vfs_create_op
        .globl kret_neg2
main:
        setzm   fd_table+040          ; process credentials at u-area 066
        movei   1,077                ; mask group/other permission bits
        dpb     1,[POINT 9,fd_table+040,26]
        movei   1,0777
        movem   1,fd_table+041        ; stale map must never be read
        movei   1,01000              ; arbitrary parent vnode
        movei   2,02000              ; arbitrary name pointer
        movei   3,0666               ; default creation mode
        setz    4,                   ; result pointer unused by stub
        pushj   17,vfs_create
        jumpn   1,test_fail
        move    5,observed_mode
        caie    5,0600               ; 0666 & ~0077 = 0600
        jrst    test_fail
        setz    1,
        popj    17,
test_fail:
        movei   1,1
        popj    17,
vfs_create_op:
        movem   4,observed_mode
        setz    1,
        popj    17,
kret_neg2:
        seto    1,
        popj    17,
        .data
        .globl file_table
file_table: .word fd_table
        .globl kconst_1_1
kconst_1_1: .word 000001000001
        .bss
fd_table: .block 042
observed_mode: .block 1
        .globl __test_exit
__test_exit: .block 1
