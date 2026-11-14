; P1-C v1579: source-linked PDP-6 MEMFS snapshot and BACKSTORE allocator.
; The actual snapshot mount/shutdown and allocator are linked by the runner.
; Only the physical read/write endpoint and MEMFS node contents are doubles.
; A process run is allocated after the invalid commit-header write, and a
; second run during metadata publication. Neither may touch the snapshot.

        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        movei   1,__bitmap
        movei   2,01000                ; 512 backing sectors
        pushj   17,backstore_init
        movei   1,1
        movem   1,backstore_enabled

        ; Existing process owns sector zero before the snapshot reserves its
        ; high-address 38-sector run. All allocations use the real allocator.
        movei   1,1
        setz    2,
        movei   3,__old
        pushj   17,backstore_alloc
        jumpn   1,fail
        skipn   __old
        jrst    initial_ok
        jrst    fail
initial_ok:
        movei   1,memfs_mres_fs
        movei   2,2                   ; MEMFS_MOUNT_PERSIST
        pushj   17,memfs_snapshot_mount
        jumpn   1,fail
        move    1,snapshot_span
        hrlz    2,1
        ; A complete 4,096-word MEMFS pool requires 32 DATA sectors, five
        ; metadata sectors and one commit sector (38 total).
        hlrz    2,snapshot_span
        caie    2,0732                ; first = 512 - 38 = 474
        jrst    fail
        hrrz    2,snapshot_span
        caie    2,046                 ; 38 decimal
        jrst    fail
        move    2,backstore_blocks_used
        caie    2,047                 ; original owner + snapshot
        jrst    fail

        pushj   17,memfs_snapshot_shutdown
        jumpn   1,fail
        move    2,__phase
        caie    2,3                   ; invalid header, metadata, commit
        jrst    fail
        move    2,backstore_blocks_used
        caie    2,0223                ; 1 + 38 + 90 + 18 = 147
        jrst    fail
        move    2,__first
        caie    2,1
        jrst    fail
        move    2,__second
        caie    2,0133                ; first + 90 = 91
        jrst    fail
        pushj   17,check_bitmap_full
        jumpn   1,fail

        ; Release only the temporary process owners after successful
        ; commit. The original process and the snapshot remain allocated.
        movei   1,1
        movei   2,0132                ; 90 decimal
        pushj   17,backstore_free
        jumpn   1,fail
        movei   1,0133                ; 91 decimal
        movei   2,022                 ; 18 decimal
        pushj   17,backstore_free
        jumpn   1,fail
        move    2,backstore_blocks_used
        caie    2,047                 ; 1 + 38
        jrst    fail
        pushj   17,check_bitmap_after
        jumpn   1,fail
        move    2,__invalidates
        caie    2,2                   ; mount read and shutdown
        jrst    fail
        move    2,__reads
        caie    2,1                   ; cold mount header read only
        jrst    fail
        jrst    success

; For every backing sector, reconstruct the expected ownership directly
; from the physical block number. This rejects both leaks and overlap.
check_bitmap_full:
        movei   3,0154                ; 108, last temporary process block
        jrst    check_bitmap
check_bitmap_after:
        setz    3,                    ; only original block zero below 474
check_bitmap:
        setz    010,
bitmap_loop:
        move    4,010
        idivi   4,044                 ; word index and bit 0..35
        movei   6,1
        lsh     6,0(5)
        move    7,__bitmap(4)
        and     7,6
        setz    1,
        camle   010,3
        jrst    bitmap_high
        movei   1,1
bitmap_high:
        caige   010,0732
        jrst    bitmap_compare
        movei   1,1
bitmap_compare:
        jumpe   1,bitmap_expect_clear
        jumpe   7,bitmap_fail
        jrst    bitmap_next
bitmap_expect_clear:
        jumpn   7,bitmap_fail
bitmap_next:
        addi    010,1
        caige   010,01000
        jrst    bitmap_loop
        setz    1,
        popj    17,
bitmap_fail:
        seto    1,
        popj    17,

; All driver I/O remains test-controlled. The actual caller arguments,
; first/last physical block and source buffers are still authenticated.
        .globl backstore_read
backstore_read:
        movei   4,0777                ; commit header block
        camn    1,4
        caie    2,1
        jrst    io_fail
        movei   4,fs_block_workspace
        camn    3,4
        jrst    read_ok
        jrst    io_fail
read_ok:
        aos     __reads
        setzm   fs_block_workspace    ; no preexisting committed snapshot
        setz    1,
        popj    17,

        .globl backstore_write
backstore_write:
        push    17,010
        push    17,011
        push    17,012
        push    17,013
        push    17,014
        push    17,015
        push    17,016
        move    010,1                 ; physical sector first
        move    011,2                 ; sector count
        move    012,3                 ; producer memory pointer
        move    4,__phase
        jumpe   4,write_invalid
        caie    4,1
        jrst    write_after_invalid
        movei   4,0732
        came    010,4
        jrst    write_fail
        movei   4,5
        came    011,4
        jrst    write_fail
        movei   4,__nodes
        came    012,4
        jrst    write_fail
        movei   1,022                ; 18 process blocks during metadata
        setz    2,
        movei   3,__second
        pushj   17,backstore_alloc
        jumpn   1,write_fail
        movei   4,2
        movem   4,__phase
        jrst    write_ok
write_after_invalid:
        caie    4,2
        jrst    write_fail
        movei   4,0777
        came    010,4
        jrst    write_fail
        movei   4,1
        came    011,4
        jrst    write_fail
        movei   4,fs_block_workspace
        came    012,4
        jrst    write_fail
        move    4,(012)
        came    4,[055464663]        ; committed snapshot magic
        jrst    write_fail
        move    4,1(012)
        caie    4,2
        jrst    write_fail
        move    4,2(012)
        caie    4,0732
        jrst    write_fail
        move    4,3(012)
        caie    4,046
        jrst    write_fail
        move    4,4(012)
        caie    4,010000
        jrst    write_fail
        movei   4,3
        movem   4,__phase
        jrst    write_ok
write_invalid:
        movei   4,0777
        came    010,4
        jrst    write_fail
        movei   4,1
        came    011,4
        jrst    write_fail
        movei   4,fs_block_workspace
        came    012,4
        jrst    write_fail
        skipn   (012)                 ; first header must be invalidated
        jrst    invalid_verified
        jrst    write_fail
invalid_verified:
        movei   1,0132               ; 90 process blocks mid-commit
        setz    2,
        movei   3,__first
        pushj   17,backstore_alloc
        jumpn   1,write_fail
        movei   4,1
        movem   4,__phase
        jrst    write_ok
write_fail:
        seto    1,
        jrst    write_return
write_ok:
        setz    1,
write_return:
        pop     17,016
        pop     17,015
        pop     17,014
        pop     17,013
        pop     17,012
        pop     17,011
        pop     17,010
        popj    17,
io_fail:
        seto    1,
        popj    17,

        .globl bcache_workspace_invalidate
bcache_workspace_invalidate:
        aos     __invalidates
        popj    17,
        .globl memfs_data_ensure
memfs_data_ensure:
        seto    1,                   ; no regular file nodes in this fixture
        popj    17,

success:
        setz    1,
        jrst    finish
fail:
        movei   1,1
finish:
        movem   1,__test_exit
        jrst    4,0

        .data
        .globl memfs_mres_fs
memfs_mres_fs:          .word __nodes
                        .word 010000
                        .word 0

        .bss
        .globl fs_block_workspace
fs_block_workspace:     .block 0200
__nodes:                .block 0700
__bitmap:               .block 017
__old:                  .block 1
__first:                .block 1
__second:               .block 1
__phase:                .block 1
__reads:                .block 1
__invalidates:          .block 1
        .globl __test_exit
__test_exit:            .block 1
__stack:                .block 0400
