; v1818: physical DTFS write ABI must survive the intent gate and cache
; invalidation.  Production dtfs_dtc_write and bcache_invalidate_all are
; extracted by the runner, not duplicated here.
        .text
        .globl  main
        .globl  dtfs_dtc_write
        .globl  dtfs_dtc_write_jump
        .globl  bcache_reclaim
        .globl  bcache_invalidate_all
        .globl  dtfs_intent_mount_gate_v1561
        .globl  dtfs_mark_unit_suspect_v1522
        .globl  kret_neg1
        .globl  dtfs_cache_mount
        .globl  bcache_state
        .globl  bcache_workspace_tag
        .globl  __test_exit

main:
        ; The raw DTC dispatch slot points at our observation sink.
        movei   4,dtfs_write_sink_v1818
        hrrm    4,dtfs_dtc_write_jump
        movei   1,3                     ; data drive, not boot drive
        movei   2,0144                  ; physical directory block
        movei   3,dtfs_write_buf_v1818
        pushj   17,dtfs_dtc_write
        jumpn   1,dtfs_write_fail_v1818
        move    1,dtfs_seen_unit_v1818
        caie    1,3
        jrst    dtfs_write_fail_v1818
        move    1,dtfs_seen_block_v1818
        caie    1,0144
        jrst    dtfs_write_fail_v1818
        movei   1,dtfs_write_buf_v1818
        came    1,dtfs_seen_buf_v1818
        jrst    dtfs_write_fail_v1818
        move    1,dtfs_gate_calls_v1818
        caie    1,1
        jrst    dtfs_write_fail_v1818
        setz    1,
        popj    17,
dtfs_write_fail_v1818:
        movei   1,1
        popj    17,

; An actual mount-gate call can overwrite all argument ACs.  The
; production veneer must restore them from its process stack.
dtfs_intent_mount_gate_v1561:
        aos     dtfs_gate_calls_v1818
        setz    1,
        movei   2,7
        movei   3,0777
        popj    17,

; This is NOT the production invalidator.  The runner substitutes it
; only in a negative control to detect a return to reclaim-in-write.
bcache_reclaim:
        setz    1,
        movei   2,7
        movei   3,0777
        popj    17,

dtfs_write_sink_v1818:
        movem   1,dtfs_seen_unit_v1818
        movem   2,dtfs_seen_block_v1818
        movem   3,dtfs_seen_buf_v1818
        setz    1,
        popj    17,

dtfs_mark_unit_suspect_v1522:
        seto    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .bss
dtfs_write_buf_v1818: .block 0200
dtfs_seen_unit_v1818: .block 1
dtfs_seen_block_v1818: .block 1
dtfs_seen_buf_v1818: .block 1
dtfs_gate_calls_v1818: .block 1
dtfs_cache_mount: .block 1
bcache_state: .block 1
bcache_workspace_tag: .block 1
__test_exit: .block 1
