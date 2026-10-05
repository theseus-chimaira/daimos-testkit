        .text
        .globl  main
        .globl  fs_provider_reg_call
        .globl  fs_mres_vector_dispatch
        .globl  d6fs_mount_validated
        .globl  d6fs_reader_get_block
        .globl  d6fs_reader_write_block
        .globl  bcache_reclaim
        .globl  mm_free
        .globl  kret_zero
        .globl  kret_neg1
        .globl  d6fs_mres_vector
        .globl  d6fs_active_reader
        .globl  d6fs_reader_slots
        .globl  d6fs_provider_space
        .globl  vfs_mount_ro
        .globl  fs_block_workspace
        .globl  __test_exit

main:
        ; One mounted D6FS starts writable on copy A, sequence 5.
        movei   1,reader
        movem   1,d6fs_reader_slots
        movem   1,d6fs_active_reader
        movei   1,0101                  ; mount 1 | WRITABLE, copy A
        movem   1,reader+1
        movei   1,5
        movem   1,reader+2
        movei   1,020
        movem   1,reader+011
        movei   1,021
        movem   1,reader+012
        setzm   vfs_mount_ro
        setzm   write_fail

        ; RW -> RO: publish CLEAN sequence 6 to opposite copy B first.
        setzm   phase
        movei   1,1
        lsh     1,030                   ; vnode on public mount id 1
        pushj   17,vfs_remount
        jumpn   1,remount_fail
        move    1,reader+2
        caie    1,6
        jrst    remount_fail
        move    1,reader+1
        andi    1,0300
        caie    1,0200                  ; RO, copy B
        jrst    remount_fail
        move    1,vfs_mount_ro
        trnn    1,1
        jrst    remount_fail

        ; RO -> RW: publish DIRTY sequence 7 to opposite copy A.
        movei   1,1
        movem   1,phase
        movei   1,1
        lsh     1,030
        pushj   17,vfs_remount
        jumpn   1,remount_fail
        move    1,reader+2
        caie    1,7
        jrst    remount_fail
        move    1,reader+1
        andi    1,0300
        caie    1,0100                  ; RW, copy A
        jrst    remount_fail
        move    1,vfs_mount_ro
        trne    1,1
        jrst    remount_fail

        ; A failed CLEAN publication must leave sequence, copy, writable and
        ; VFS readonly policy unchanged.
        movei   1,2
        movem   1,phase
        movei   1,1
        movem   1,write_fail
        movei   1,1
        lsh     1,030
        pushj   17,vfs_remount
        jumpe   1,remount_fail
        move    1,reader+2
        caie    1,7
        jrst    remount_fail
        move    1,reader+1
        andi    1,0300
        caie    1,0100
        jrst    remount_fail
        move    1,vfs_mount_ro
        trne    1,1
        jrst    remount_fail

        ; Writable unmount reuses the same successful CLEAN publication, then
        ; releases exactly this mount-owned reader/context.
        movei   1,3
        movem   1,phase
        setzm   write_fail
        movei   1,reader
        movem   1,d6fs_active_reader
        movei   1,012345                ; root value is not consumed here
        pushj   17,d6fs_provider_prepare_unmount
        jumpn   1,remount_fail_unmount_call
        move    1,freed_reader
        caie    1,reader
        jrst    remount_fail_freed
        skipn   d6fs_reader_slots
        jrst    remount_slot_clear_ok
        jrst    remount_fail_slot
remount_slot_clear_ok:
        skipn   d6fs_active_reader
        jrst    remount_active_clear_ok
        jrst    remount_fail_active
remount_active_clear_ok:
        move    1,vfs_mount_ro
        trnn    1,1                     ; provider published CLEAN/RO first
        jrst    remount_fail_ro
        setz    1,
        popj    17,

remount_fail_unmount_call:
        skipn   free_seen
        jrst    remount_fail_unmount_write
        movei   1,020
        popj    17,
remount_fail_unmount_write:
        move    1,write_seen
        caie    1,4
        jrst    remount_fail_unmount_no_write
        movei   1,021
        popj    17,
remount_fail_unmount_no_write:
        move    1,get_seen
        caie    1,4
        jrst    remount_fail_no_get
        move    1,write_enter
        caie    1,4
        jrst    remount_fail_no_write_enter
        movei   1,022
        popj    17,
remount_fail_no_get:
        movei   1,023
        popj    17,
remount_fail_no_write_enter:
        movei   1,024
        popj    17,
remount_fail_freed:
        movei   1,011
        popj    17,
remount_fail_slot:
        movei   1,012
        popj    17,
remount_fail_active:
        movei   1,013
        popj    17,
remount_fail_ro:
        movei   1,014
        popj    17,

remount_fail:
        move    1,phase
        addi    1,1
        popj    17,

; Fixed VFS veneer serializes through the normal provider bridge.
fs_provider_reg_call:
        caie    7,6
        jrst    kret_neg1
        jrst    d6fs_mres_dispatch

; This test never enters normal vector dispatch or runtime mount creation.
fs_mres_vector_dispatch:
        jrst    kret_neg1
d6fs_mount_validated:
        jrst    kret_neg1
d6fs_provider_space:
        jrst    kret_neg1

; Production get_block must fetch the opposite A/B copy.  Seed the shared
; block with sentinel metadata that write_block checks remains intact.
d6fs_reader_get_block:
        caie    1,reader
        jrst    get_block_fail
        move    4,phase
        cain    4,1
        jrst    get_expect_a
        ; phases 0,2,3 start on copy A and must target B.
        caie    2,021
        jrst    get_block_fail
        jrst    get_seed
get_expect_a:
        caie    2,020
        jrst    get_block_fail
get_seed:
        move    4,phase
        addi    4,1
        movem   4,get_seen
        move    4,[044066263662]
        movem   4,fs_block_workspace
        move    4,[012345670123]
        movem   4,fs_block_workspace+3
        movei   1,fs_block_workspace
        popj    17,
get_block_fail:
        setz    1,
        popj    17,

; Validate the media state before optionally failing the physical write.
d6fs_reader_write_block:
        move    4,phase
        addi    4,1
        movem   4,write_enter
        caie    1,reader
        jrst    write_block_fail
        caie    3,fs_block_workspace
        jrst    write_block_fail
        move    4,fs_block_workspace
        came    4,[044066263662]
        jrst    write_block_fail
        move    4,fs_block_workspace+3
        came    4,[012345670123]
        jrst    write_block_fail
        move    4,phase
        cain    4,1
        jrst    write_dirty
        ; phases 0,2,3 publish CLEAN.  Phase 2 then forces I/O failure.
        move    5,fs_block_workspace+2
        jumpn   5,write_block_fail
        move    5,fs_block_workspace+1
        cain    4,0
        jrst    write_expect_6
        cain    4,2
        jrst    write_expect_8
        cain    4,3
        jrst    write_expect_8
        jrst    write_block_fail
write_expect_6:
        caie    5,6
        jrst    write_block_fail
        jrst    write_sequence_ok
write_expect_8:
        caie    5,010
        jrst    write_block_fail
        jrst    write_sequence_ok
write_dirty:
        move    5,fs_block_workspace+2
        caie    5,1
        jrst    write_block_fail
        move    5,fs_block_workspace+1
        caie    5,7
        jrst    write_block_fail
write_sequence_ok:
        skipn   write_fail
        jrst    write_block_ok
        seto    1,
        popj    17,
write_block_ok:
        move    1,phase
        addi    1,1
        movem   1,write_seen
        setz    1,
        popj    17,
write_block_fail:
        seto    1,
        popj    17,

bcache_reclaim:
        setz    1,
        popj    17,

mm_free:
        caie    1,reader
        jrst    kret_neg1
        movem   1,freed_reader
        movei   4,1
        movem   4,free_seen
        setz    1,
        popj    17,

kret_zero:
        setz    1,
        popj    17,
kret_neg1:
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
vfs_mount_ro:
        .block  1
fs_block_workspace:
        .block  0200
reader:
        .block  016
phase:
        .block  1
write_fail:
        .block  1
freed_reader:
        .block  1
write_seen:
        .block  1
free_seen:
        .block  1
get_seen:
        .block  1
write_enter:
        .block  1
__test_exit:
        .block  1
