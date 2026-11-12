; v1518: source-linked DTFS physical failure invalidates directory and
; both clean BCACHE identities.  This is not replacement-tape validation.
        .text
        .globl  main
        .globl  dtfs_dtc_read
        .globl  dtfs_dtc_write
        .globl  dtfs_load
        .globl  bcache_state
        .globl  bcache_workspace_tag
        .globl  dtfs_cache_mount
        .globl  dtfs_media_base
        .globl  dtfs_dir
        .globl  fs_block_workspace
        .globl  kconst_2_2
        .globl  kret_zero
        .globl  kret_one
        .globl  kret_neg1
        .globl  mm_alloc_aligned_noreclaim
        .globl  mm_free
        .globl  test_raw_read_v1518
        .globl  test_raw_write_v1518
        .globl  __test_exit
        .globl  dtfs_identity_revalidate_v1522
        .globl  vfs_mount_root_base
        .globl  vfs_mount_limit

; V1518 tests only the original physical-failure/clean-cache ABI.
; Its 128-word media stub does not implement v1522 DTVOL1; the separate
; v1522 native test exercises the genuine revalidation helper and flags.
dtfs_identity_revalidate_v1522:
        jrst    kret_zero

main:
        setzm   dtfs_cache_mount
        setzm   physical_reads_v1518
        setzm   physical_writes_v1518
        movei   4,1
        movem   4,stage_v1518
        movei   4,cache_slab_v1518
        movem   4,bcache_state
        setom   bcache_workspace_tag
        setom   cache_slab_v1518
        movei   4,3                    ; DTC3 is secondary DTFS mount 2
        movem   4,dtfs_media_words_v1518+1
        movei   4,0111
        movem   4,generation_v1518
        setom   media_online_v1518

        ; First load fetches the actual directory block, then caches it.
        move    1,[050201000000]
        pushj   17,dtfs_load
        jumpn   1,fail_v1518
        move    4,dtfs_cache_mount
        caie    4,2
        jrst    fail_v1518
        move    4,dtfs_dir_words_v1518
        caie    4,0111
        jrst    fail_v1518
        move    4,physical_reads_v1518
        caie    4,1
        jrst    fail_v1518

        ; A later physical read of a different uncached block fails.
        ; The directory and both clean cache tags must become invalid.
        movei   4,2
        movem   4,stage_v1518
        setzm   media_online_v1518
        movei   1,3
        movei   2,0145
        movei   3,fs_block_workspace
        pushj   17,dtfs_dtc_read
        camn    1,[-1]
        jrst    read_failed_v1518
        jrst    fail_v1518
read_failed_v1518:
        skipn   dtfs_cache_mount
        jrst    read_caches_v1518
        jrst    fail_v1518
read_caches_v1518:
        move    4,bcache_workspace_tag
        came    4,[-1]
        jrst    fail_v1518
        move    4,cache_slab_v1518
        came    4,[-1]
        jrst    fail_v1518

        ; The same mounted DTFS must perform real I/O, not accept the
        ; stale in-memory directory or a stale BCACHE hit as success.
        movei   4,3
        movem   4,stage_v1518
        move    1,[050201000000]
        pushj   17,dtfs_load
        camn    1,[-1]
        jrst    offline_checked_v1518
        jrst    fail_v1518
offline_checked_v1518:
        move    4,physical_reads_v1518
        caie    4,3                    ; first, failed block, failed dir
        jrst    fail_v1518

        ; The SAME medium returns. This test does not assert a replaced
        ; tape can safely reuse previous open vnodes or directory state.
        movei   4,4
        movem   4,stage_v1518
        setom   media_online_v1518
        move    1,[050201000000]
        pushj   17,dtfs_load
        jumpn   1,fail_v1518
        move    4,physical_reads_v1518
        caie    4,4
        jrst    fail_v1518
        move    4,dtfs_dir_words_v1518
        caie    4,0111
        jrst    fail_v1518

        ; A write failure may have partially modified the on-media block.
        ; All clean tags are already invalidated on write entry; the
        ; shared in-memory directory identity must also be discarded.
        movei   4,5
        movem   4,stage_v1518
        setzm   media_online_v1518
        movei   1,3
        movei   2,0144
        movei   3,dtfs_dir_words_v1518
        pushj   17,dtfs_dtc_write
        camn    1,[-1]
        jrst    write_failed_v1518
        jrst    fail_v1518
write_failed_v1518:
        skipn   dtfs_cache_mount
        jrst    write_caches_v1518
        jrst    fail_v1518
write_caches_v1518:
        move    4,bcache_workspace_tag
        came    4,[-1]
        jrst    fail_v1518
        move    4,cache_slab_v1518
        came    4,[-1]
        jrst    fail_v1518
        move    4,physical_writes_v1518
        caie    4,1
        jrst    fail_v1518
        move    1,[050201000000]
        pushj   17,dtfs_load
        camn    1,[-1]
        jrst    retry_write_checked_v1518
        jrst    fail_v1518
retry_write_checked_v1518:
        move    4,physical_reads_v1518
        caie    4,5
        jrst    fail_v1518

        ; A successful write likewise invalidates clean BCACHE slots,
        ; but does not poison the directory state when it completed.
        movei   4,6
        movem   4,stage_v1518
        setom   media_online_v1518
        move    1,[050201000000]
        pushj   17,dtfs_load
        jumpn   1,fail_v1518
        movei   1,3
        movei   2,0144
        movei   3,dtfs_dir_words_v1518
        pushj   17,dtfs_dtc_write
        jumpn   1,fail_v1518
        move    4,dtfs_cache_mount
        caie    4,2
        jrst    fail_v1518
        move    4,physical_writes_v1518
        caie    4,2
        jrst    fail_v1518
        move    4,cache_slab_v1518
        came    4,[-1]
        jrst    fail_v1518
        setz    1,
        popj    17,

fail_v1518:
        move    1,stage_v1518
        popj    17,

; The source-linked MINIT read/write JRST slots in this test are patched
; only to these deterministic raw-device callbacks. Physical errors and
; correct caching are handled by production DTFS and BCACHE source.
test_raw_read_v1518:
        aos     physical_reads_v1518
        move    4,1
        caie    4,3
        jrst    kret_neg1
        skipn   media_online_v1518
        jrst    kret_neg1
        move    4,generation_v1518
        movem   4,(3)
        jrst    kret_zero
test_raw_write_v1518:
        aos     physical_writes_v1518
        move    4,1
        caie    4,3
        jrst    kret_neg1
        skipn   media_online_v1518
        jrst    kret_neg1
        jrst    kret_zero

; Pre-seed the BCACHE slab: MM allocation/reclaim is not under test here.
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
dtfs_dir: .word dtfs_dir_words_v1518
dtfs_media_base: .word dtfs_media_words_v1518
dtfs_cache_mount: .word 0
vfs_mount_root_base: .word 0
vfs_mount_limit: .word 0
dtfs_media_words_v1518: .block 4

        .bss
dtfs_dir_words_v1518: .block 0200
fs_block_workspace: .block 0200
cache_slab_v1518: .block 0201
media_online_v1518: .block 1
generation_v1518: .block 1
physical_reads_v1518: .block 1
physical_writes_v1518: .block 1
stage_v1518: .block 1
__test_exit: .block 1
