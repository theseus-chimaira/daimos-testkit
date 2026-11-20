; Test the actual PDP-6 destructive low-memory EXEC entry and its ownership.
; No replacement of the production transaction; only external services are
; simulated. A failed old-VM detach after VM_NONE must be fatal, and a
; failed in-place loader must not destroy the original u-area descriptor.

        .text
        .globl main
main:
        movei   7,1
test_begin:
        movem   7,test_mode
        setzm   test_failure
        setzm   alloc_calls
        setzm   free_calls
        setzm   destroy_calls
        setzm   load_calls
        setzm   startup_calls
        setzm   release_calls
        setzm   hold_calls
        movei   1,stable_uarea
        lsh     1,022
        iori    1,0400000
        movem   1,expected_meta
        movem   1,process_desc
        movei   1,02000
        movem   1,process_desc+1
        movei   1,2
        movem   1,stable_uarea+024
        setzm   stable_uarea+0406
        setzm   stable_uarea+0407
        setzm   proc_rt_owner

        movei   1,launch
        movei   2,5
        setz    3,
        movei   4,result
        pushj   17,exec_replace_current_lowmem

        move    7,test_mode
        caie    7,5
        jrst    check_not_success
        jumpe   1,check_common
        jrst    test_bad
check_not_success:
        caie    7,1
        jrst    check_not_precommit
        camn    1,[-1]
        jrst    check_common
        jrst    test_bad
check_not_precommit:
        caie    7,7
        jrst    check_fatal
        camn    1,[-1]
        jrst    check_common
        jrst    test_bad
check_fatal:
        camn    1,[-2]
        jrst    check_common
        jrst    test_bad

check_common:
        skipn   test_failure
        jrst    check_meta
        jrst    test_bad
check_meta:
        move    1,process_desc
        came    1,expected_meta
        jrst    test_bad
        move    1,stable_uarea+024
        andi    1,2
        movei   2,0
        caie    7,1
        jrst    check_map_alloc
        movei   2,2
check_map_alloc:
        caie    7,7
        jrst    check_map
        movei   2,2
check_map:
        came    1,2
        jrst    test_bad

        move    1,free_calls
        movei   2,1
        caie    7,7
        jrst    check_free
        setz    2,
check_free:
        came    1,2
        jrst    test_bad
        move    1,destroy_calls
        movei   2,1
        caie    7,7
        jrst    check_destroy_extra
        setz    2,
check_destroy_extra:
        caie    7,6
        jrst    check_destroy
        movei   2,2
check_destroy:
        came    1,2
        jrst    test_bad

        move    1,load_calls
        movei   2,1
        caie    7,1
        jrst    check_load2
        setz    2,
check_load2:
        caie    7,2
        jrst    check_load7
        setz    2,
check_load7:
        caie    7,7
        jrst    check_load
        setz    2,
check_load:
        came    1,2
        jrst    test_bad
        move    1,hold_calls
        movei   2,0
        caie    7,1
        jrst    check_hold
        movei   2,1
check_hold:
        came    1,2
        jrst    test_bad
        move    1,release_calls
        movei   2,1
        caie    7,7
        jrst    check_release
        setz    2,
check_release:
        came    1,2
        jrst    test_bad

        move    1,process_desc+1
        caie    7,1
        jrst    check_vm7
        caie    1,02000
        jrst    test_bad
        jrst    test_next
check_vm7:
        caie    7,7
        jrst    check_vm5
        caie    1,02000
        jrst    test_bad
        jrst    test_next
check_vm5:
        caie    7,5
        jrst    check_vm_gone
        caie    1,03000
        jrst    test_bad
        jrst    test_next
check_vm_gone:
        camn    1,[-1]
        jrst    test_next
        jrst    test_bad

test_next:
        aoj     7,
        caile   7,7
        jrst    test_good
        jrst    test_begin
test_bad:
        move    1,test_mode
        addi    1,0100
        popj    17,
test_good:
        setz    1,
        popj    17,

; Modes 1/2: old destruction refuses before/after VM_NONE publication.
; Mode 3: old destroyed, loader refuses before any replacement exists.
; Mode 4: loader refuses after metadata has been scrubbed by rollback.
; Mode 5: old destroyed, replacement loaded and started successfully.
; Mode 6: replacement loads, startup fails, replacement VM is destroyed.
; Mode 7: allocation of the transient launch-copy fails before destruction.
        .globl mm_alloc
mm_alloc:
        aos     alloc_calls
        move    6,test_mode
        caie    6,7
        jrst    alloc_ok
        seto    1,
        popj    17,
alloc_ok:
        ; PUSHJ placed its return PC at (17); caller's fifth argument is
        ; one word below it. Never treat a return PC as an output pointer.
        move    6,-1(17)               ; fifth argument: kword_t *basep
        movei   5,launch_copy
        movem   5,(6)
        setz    1,
        popj    17,

        .globl fs_copy_words
fs_copy_words:
        move    4,1
        move    5,2
        move    6,3
copy_loop:
        jumpe   6,copy_done
        move    7,(4)
        movem   7,(5)
        addi    4,1
        addi    5,1
        sojg    6,copy_loop
copy_done:
        popj    17,

        .globl mm_free
mm_free:
        aos     free_calls
        caie    1,launch_copy
        setom   test_failure
        caie    2,3
        setom   test_failure
        caie    3,013
        setom   test_failure
        setz    1,
        popj    17,

        .globl proc_slot_ptr
proc_slot_ptr:
        caie    1,1
        setom   test_failure
        movei   1,process_desc
        popj    17,

        .globl vm_user_mapping_release
vm_user_mapping_release:
        aos     release_calls
        move    5,stable_uarea+024
        andcmi  5,2
        movem   5,stable_uarea+024
        popj    17,

        .globl vm_user_mapping_hold
vm_user_mapping_hold:
        aos     hold_calls
        move    5,stable_uarea+024
        iori    5,2
        movem   5,stable_uarea+024
        popj    17,

        .globl vm_space_destroy
vm_space_destroy:
        aos     destroy_calls
        caie    1,process_desc
        setom   test_failure
        caie    2,1
        setom   test_failure
        move    6,destroy_calls
        caie    6,1
        jrst    destroy_new
        move    6,test_mode
        caie    6,1
        jrst    destroy_old_post
        seto    1,
        popj    17,
destroy_old_post:
        setom   process_desc+1
        caie    6,2
        jrst    destroy_old_success
        seto    1,
        popj    17,
destroy_old_success:
        setz    1,
        popj    17,
destroy_new:
        setom   process_desc+1
        setz    1,
        popj    17,

        .globl exec_load_process
exec_load_process:
        aos     load_calls
        caie    1,process_desc
        setom   test_failure
        caie    2,1
        setom   test_failure
        move    6,test_mode
        caie    6,3
        jrst    loader_partial
        seto    1,
        popj    17,
loader_partial:
        ; Simulate the production loader replacing META with the entry,
        ; and clearing its left half during an unsuccessful inner rollback.
        movei   5,01234
        movem   5,process_desc
        caie    6,4
        jrst    loader_success
        setom   process_desc+1
        seto    1,
        popj    17,
loader_success:
        movei   5,03000
        movem   5,process_desc+1
        movei   5,076543
        movem   5,swap_states+1
        setz    1,
        popj    17,

        .globl vm_space_startup
vm_space_startup:
        aos     startup_calls
        move    6,test_mode
        caie    6,6
        jrst    startup_ok
        seto    1,
        popj    17,
startup_ok:
        movei   5,3
        movem   5,3(4)                 ; fourth startup result: stack
        setz    1,
        popj    17,

        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt    5
        jrst    .-1

        .data
        .globl kconst_1_1
kconst_1_1: .word 1,,1
        .globl proc_current_slot
proc_current_slot: .word 1
        .globl proc_rt_owner
proc_rt_owner: .word 0
        .globl swap_states
swap_states: .block 2
launch: .word 1,,5
        .word 0
        .word 0
        .word 1
        .word 060000000000
        .bss
process_desc: .block 3
stable_uarea: .block 0410
launch_copy: .block 020
result: .block 6
expected_meta: .block 1
test_mode: .block 1
test_failure: .block 1
alloc_calls: .block 1
free_calls: .block 1
destroy_calls: .block 1
load_calls: .block 1
startup_calls: .block 1
release_calls: .block 1
hold_calls: .block 1
        .globl __test_exit
__test_exit: .block 1
