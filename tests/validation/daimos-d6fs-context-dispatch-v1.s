        .text
        .globl  main
        .globl  fs_mres_vector_dispatch
        .globl  kret_neg1
        .globl  d6fs_mount_validated
        .globl  d6fs_mres_vector
        .globl  d6fs_active_reader
        .globl  d6fs_reader_slots
        .globl  d6fs_provider_toggle_state
        .globl  d6fs_provider_space
        .globl  __test_exit

; Exercise the production O(1) D6FS mount-slot selector on a PDP-6.
main:
        movei   1,reader1
        movem   1,d6fs_reader_slots
        movei   1,reader2
        movem   1,d6fs_reader_slots+1

        ; Mount id 1 selects slot 0.
        movei   1,1
        pushj   17,d6fs_context_call
        caie    1,reader1
        jrst    d6fs_context_fail

        ; Mount id 2 selects slot 1 without aliasing slot 0.
        movei   1,2
        pushj   17,d6fs_context_call
        caie    1,reader2
        jrst    d6fs_context_fail

        ; Empty slot 2 must be rejected.
        movei   1,3
        pushj   17,d6fs_context_call
        jumpge  1,d6fs_context_fail

        ; Public mount id 5 lies outside the four-entry VFS table.
        movei   1,5
        pushj   17,d6fs_context_call
        jumpge  1,d6fs_context_fail

        setz    1,
        popj    17,

d6fs_context_fail:
        movei   1,1
        popj    17,

; AC1 contains the public mount id.  Build a vnode and verify that AC2..AC6
; survive the production selector unchanged.
d6fs_context_call:
        lsh     1,030
        movei   2,022
        movei   3,033
        movei   4,044
        movei   5,055
        movei   6,066
        jrst    d6fs_mres_dispatch

fs_mres_vector_dispatch:
        caie    2,022
        jrst    d6fs_context_fail
        caie    3,033
        jrst    d6fs_context_fail
        caie    4,044
        jrst    d6fs_context_fail
        caie    5,055
        jrst    d6fs_context_fail
        caie    6,066
        jrst    d6fs_context_fail
        move    1,d6fs_active_reader
        popj    17,

; MOUNT_UNIT is not used by this selector-only oracle.
d6fs_mount_validated:
        seto    1,
        popj    17,

kret_neg1:
        seto    1,
        popj    17,

; Remount opcode is not exercised by this oracle.
d6fs_provider_toggle_state:
        seto    1,
        popj    17,

; SPACE is not exercised by this selector-only oracle.
d6fs_provider_space:
        seto    1,
        popj    17,

        .data
d6fs_mres_vector:
        .word   0

        .bss
d6fs_active_reader:
        .block  1
d6fs_reader_slots:
        .block  4
reader1:
        .block  1
reader2:
        .block  1
__test_exit:
        .block  1
