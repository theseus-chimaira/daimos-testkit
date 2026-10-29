; Native PDP-6 late swap rollback: failed MM free after successful unpin.
        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 10,1
        movei 11,__proc
        movei 12,__record
        movei 13,02000
        movei 15,2
        movei 16,012345
        movei 1,__uarea
        hrli 1,__uarea
        iori 1,0200000
        movem 1,__proc
        movei 1,02000
        hrlm 1,__proc+1
        hrrm 1,__proc+1
        movei 1,077
        movem 1,__record
        movei 1,040
        movem 1,__uarea+0406
        movei 1,010
        movem 1,__first
        movei 1,0200
        movem 1,backstore_blocks
        ; Emulate the two existing stack locals (first, skip) used here.
        push 17,[0]
        push 17,[010]
        ; Actual production code from the successful-write continuation.
        jrst swap_mmfree_failure_probe
        .globl probe_restored
probe_restored:
        camn 1,[-1]
        jrst check_state
        movei 1,1
        jrst finish
check_state:
        move 1,__record
        caie 1,077
        jrst fail
        move 1,__proc+1
        hrrz 1,1
        caie 1,02000
        jrst fail
        move 1,__proc
        trne 1,0200000
        jrst fail
        skipn __backing_freed
        jrst fail
        skipn __unpinned
        jrst fail
        skipn __uarea+0406
        jrst pass
fail:
        movei 1,2
        jrst finish
pass:
        setz 1,
finish:
        movem 1,__test_exit
        jrst 4,0
        .globl mm_unpin
mm_unpin:
        aos __unpinned
        setz 1,
        popj 17,
        .globl mm_free
mm_free:
        seto 1,
        popj 17,
        .globl backstore_free
backstore_free:
        aos __backing_freed
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        movei 1,3
        popj 17,
        .globl proc_storage_publish_v30
proc_storage_publish_v30:
        movei 1,4
        popj 17,
        .bss
        .globl __test_exit
__test_exit: .block 1
        .globl backstore_blocks
backstore_blocks: .block 1
        .globl proc_swap_blocks_used
proc_swap_blocks_used: .block 1
__proc: .block 3
__record: .block 1
__uarea: .block 0500
__first: .block 1
__backing_freed: .block 1
__unpinned: .block 1
__stack: .block 0400
