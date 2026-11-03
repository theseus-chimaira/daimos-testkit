; A provisional named FIFO cannot discard its last retry owner when
; the real PDP-6 MM refuses the interrupted OPEN's last-reference free.
        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        ; First abort: a physical MM pin prevents the final free.
        ; The real FILE layer must commit a user-visible descriptor.
        movei 1,__path
        movei 2,1
        pushj 17,file_open
        jumpe 1,pinned_open_kept_v1084
        jrst fail_1_v1084
pinned_open_kept_v1084:
        move 1,__fdtable
        camn 1,[0470001,,__pipe]
        jrst pinned_fd_published_v1084
        jrst fail_1_v1084
pinned_fd_published_v1084:
        move 1,__pipe+3
        camn 1,[1,,0]
        jrst pinned_refs_v1084
        jrst fail_2_v1084
pinned_refs_v1084:
        move 1,pipe_fifo_head
        caie 1,__pipe
        jrst fail_3_v1084
        move 1,mm_extent_count
        caie 1,1
        jrst fail_4_v1084
        move 1,__wait_calls
        caie 1,1
        jrst fail_5_v1084
        ; A second refusal through the descriptor close also retains
        ; the same owner and reader count.
        movei 1,__fdtable
        pushj 17,file_close_entry_v865
        ; PIPE close exposes the checked refusal as -1, while MM
        ; itself returned its physical-pin error -5.
        camn 1,[-1]
        jrst pinned_fd_retry_v1084
        jrst fail_6_v1084
pinned_fd_retry_v1084:
        move 1,__pipe+3
        camn 1,[1,,0]
        jrst unpin_v1084
        jrst fail_7_v1084
unpin_v1084:
        movei 1,__pipe
        pushj 17,mm_unpin
        jumpn 1,fail_8_v1084
        movei 1,__fdtable
        pushj 17,file_close_entry_v865
        jumpe 1,freed_v1084
        jrst fail_9_v1084
freed_v1084:
        skipn __fdtable
        jrst freed_fd_v1084
        jrst fail_9_v1084
freed_fd_v1084:
        skipn mm_extent_count
        jrst verify_unlinked_v1084
        jrst fail_10_v1084
verify_unlinked_v1084:
        skipn pipe_fifo_head
        jrst reset_for_normal_v1084
        jrst fail_11_v1084
reset_for_normal_v1084:
        ; A normal interrupted OPEN with an unpinned object must
        ; retain traditional failure behavior and not publish an FD.
        movei 1,1
        movem 1,mm_extent_count
        move 1,[016,,__pipe]
        movem 1,mm_extents
        move 1,[03000005]
        movem 1,mm_extents+1
        setzm __pipe
        setzm __pipe+3
        movei 1,__pipe
        movem 1,pipe_fifo_head
        movei 1,__path
        movei 2,1
        pushj 17,file_open
        camn 1,[-1]
        jrst normal_abort_v1084
        jrst fail_12_v1084
normal_abort_v1084:
        skipn __fdtable
        jrst normal_fd_cleared_v1084
        jrst fail_12_v1084
normal_fd_cleared_v1084:
        skipn pipe_fifo_head
        jrst normal_unlinked_v1084
        jrst fail_13_v1084
normal_unlinked_v1084:
        skipn mm_extent_count
        jrst normal_freed_v1084
        jrst fail_14_v1084
normal_freed_v1084:
        move 1,__wait_calls
        caie 1,2
        jrst fail_15_v1084
        setz 1,
        jrst done_v1084
fail_1_v1084:
        ; The historical negative result is accepted only when the
        ; allocation is still pinned and counted but FILE has already
        ; forgotten the one descriptor which could retry its release.
        skipn __fdtable
        jrst fail_1_fd_gone_v1084
        jrst fail_1_unexpected_v1084
fail_1_fd_gone_v1084:
        move 1,mm_extent_count
        caie 1,1
        jrst fail_1_unexpected_v1084
        move 1,pipe_fifo_head
        caie 1,__pipe
        jrst fail_1_unexpected_v1084
        move 1,__pipe+3
        camn 1,[1,,0]
        jrst fail_1_leak_v1084
        jrst fail_1_unexpected_v1084
fail_1_leak_v1084:
        movei 1,1
        jrst done_v1084
fail_1_unexpected_v1084:
        movei 1,040
        jrst done_v1084
fail_2_v1084: movei 1,2
        jrst done_v1084
fail_3_v1084: movei 1,3
        jrst done_v1084
fail_4_v1084: movei 1,4
        jrst done_v1084
fail_5_v1084: movei 1,5
        jrst done_v1084
fail_6_v1084: movei 1,6
        jrst done_v1084
fail_7_v1084: movei 1,7
        jrst done_v1084
fail_8_v1084: movei 1,010
        jrst done_v1084
fail_9_v1084: movei 1,011
        jrst done_v1084
fail_10_v1084: movei 1,012
        jrst done_v1084
fail_11_v1084: movei 1,013
        jrst done_v1084
fail_12_v1084: movei 1,014
        jrst done_v1084
fail_13_v1084: movei 1,015
        jrst done_v1084
fail_14_v1084: movei 1,016
        jrst done_v1084
fail_15_v1084: movei 1,017
done_v1084:
        movem 1,__test_exit
        jrst 4,0

        .globl pipe_wait_event
pipe_wait_event:
        aos __wait_calls
        seto 1,
        popj 17,
        .globl pipe_signal_event
pipe_signal_event:
        popj 17,
        .globl pipe_alloc
pipe_alloc:
        setz 1,
        popj 17,

; Source-linked FILE OPEN works with a real file table. The only
; stubs are filesystem pathname/stat/access providers, which supply
; a stable named-FIFO vnode and VFS_TYPE_FIFO without allocating.
        .globl file_lookup_path
file_lookup_path:
        movei 3,__vnode
        movem 3,(2)
        setz 1,
        popj 17,
        .globl vfs_stat
vfs_stat:
        movei 3,7
        movem 3,(2)
        setz 1,
        popj 17,
        .globl file_access_stat
file_access_stat:
        setz 1,
        popj 17,
        .globl file_parent_path
file_parent_path:
        seto 1,
        popj 17,
        .globl file_parent_write_access_v367
file_parent_write_access_v367:
        seto 1,
        popj 17,
        .globl vfs_create
vfs_create:
        seto 1,
        popj 17,
        .globl vfs_truncate
vfs_truncate:
        seto 1,
        popj 17,
        .globl file_node_from_fd
file_node_from_fd:
        move 1,(1)
        tlz 1,700070
        popj 17,
        .globl vfs_sync
vfs_sync:
        seto 1,
        popj 17,
        .globl kret_neg1
kret_neg1:
        seto 1,
        popj 17,
        .globl kret_zero
kret_zero:
        setz 1,
        popj 17,

        .data
        .globl file_table
file_table: .word __fdtable
__fdtable: .block 040
__path: .word 0
        .globl pipe_fifo_head
pipe_fifo_head: .word __pipe
__vnode: .word 0
__pipe: .word 0
        .word __vnode
        .word 0
        .word 0
        .block 012
        .globl mm_extents
mm_extents: .word 016,,__pipe
        .word 013000005
        .globl mm_extent_count
mm_extent_count: .word 1
__wait_calls: .word 0
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
