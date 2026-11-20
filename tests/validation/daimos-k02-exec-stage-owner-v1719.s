; Source-linked K02 native PDP-6 staged EXEC rollback test.
; A failed old VM destroy must not make the staged destructor detach the
; original executable. A committed old VM destruction must return FATAL.

        .text
        .globl main
        .globl exec_load_process
        .globl vm_space_startup
        .globl vm_space_destroy
        .globl exec_replace_current_lowmem

main:
        movei   7,1
test_mode_begin:
        movem   7,test_mode
        setzm   destroy_staged_count
        setzm   destroy_old_count
        setzm   failure_flag
        movei   1,stable_uarea
        lsh     1,022
        iori    1,0400000
        movem   1,process_desc
        movei   1,02000
        movem   1,process_desc+1
        movei   1,012345
        movem   1,swap_states+1
        move    1,[000234567123]
        tlo     1,001000
        movem   1,stable_uarea+066
        setzm   stable_uarea+024
        setzm   proc_rt_owner

        movei   1,launch
        movei   2,5
        movei   3,result
        pushj   17,exec_replace_current
        move    7,test_mode
        caie    7,5
        jrst    test_expect_nonfatal
        camn    1,[-2]
        jrst    test_check_common
        jrst    test_fail
test_expect_nonfatal:
        caie    7,6
        jrst    test_expect_failure
        jumpe   1,test_check_common
        jrst    test_fail
test_expect_failure:
        camn    1,[-1]
        jrst    test_check_common
        jrst    test_fail

test_check_common:
        skipn   failure_flag
        jrst    test_check_swap
        jrst    test_fail
test_check_swap:
        move    1,swap_states+1
        caie    7,6
        jrst    test_check_old_swap
        caie    1,076543
        jrst    test_fail
        jrst    test_check_counts
test_check_old_swap:
        caie    1,012345
        jrst    test_fail
        move    1,stable_uarea+066
        tlne    1,001000
        jrst    test_check_counts
        jrst    test_fail

test_check_counts:
        move    1,destroy_staged_count
        movei   2,1
        caie    7,1
        jrst    test_check_staged_normal
        setz    2,
test_check_staged_normal:
        caie    7,6
        jrst    test_check_staged_count
        setz    2,
test_check_staged_count:
        came    1,2
        jrst    test_fail
        move    1,destroy_old_count
        setz    2,
        caige   7,4
        jrst    test_check_old_count
        movei   2,1
test_check_old_count:
        came    1,2
        jrst    test_fail
        move    1,process_desc+1
        caie    7,5
        jrst    test_check_other_vm
        camn    1,[-1]
        jrst    test_next
        jrst    test_fail
test_check_other_vm:
        caie    7,6
        jrst    test_check_old_vm
        caie    1,03000
        jrst    test_fail
        jrst    test_next
test_check_old_vm:
        caie    1,02000
        jrst    test_fail
test_next:
        aoj     7,
        caile   7,6
        jrst    test_pass
        jrst    test_mode_begin

test_fail:
        move    1,test_mode
        addi    1,0100
        popj    17,
test_pass:
        setz    1,
        popj    17,

; Mode 1 fails before any VM is created.
; Mode 2 fails after creation; its loader-side cleanup refused.
; Mode 3 fails startup.
; Mode 4 refuses old VM release before physical free.
; Mode 5 refuses old backing after VM_NONE publication.
; Mode 6 commits the new image normally.
exec_load_process:
        move    4,test_mode
        caie    4,1
        jrst    mock_load_create
        seto    1,
        popj    17,
mock_load_create:
        movei   5,03000
        movem   5,1(1)
        movei   5,076543
        movem   5,swap_states+1
        move    5,stable_uarea+066
        tlz     5,001000
        movem   5,stable_uarea+066
        caie    4,2
        jrst    mock_load_ok
        seto    1,
        popj    17,
mock_load_ok:
        setz    1,
        popj    17,

vm_space_startup:
        move    5,test_mode
        caie    5,3
        jrst    mock_startup_ok
        seto    1,
        popj    17,
mock_startup_ok:
        setz    1,
        popj    17,

vm_space_destroy:
        caie    1,process_desc
        jrst    mock_destroy_staged
        aos     destroy_old_count
        move    5,swap_states+1
        caie    5,012345
        setom   failure_flag
        move    5,test_mode
        caie    5,4
        jrst    mock_destroy_old_postfree
        seto    1,
        popj    17,
mock_destroy_old_postfree:
        caie    5,5
        jrst    mock_destroy_old_success
        setom   process_desc+1
        seto    1,
        popj    17,
mock_destroy_old_success:
        setom   process_desc+1
        setzm   swap_states+1
        move    5,stable_uarea+066
        tlz     5,001000
        movem   5,stable_uarea+066
        setz    1,
        popj    17,

mock_destroy_staged:
        aos     destroy_staged_count
        move    5,swap_states+1
        caie    5,076543
        setom   failure_flag
        setom   1(1)
        setzm   swap_states+1
        move    5,stable_uarea+066
        tlz     5,001000
        movem   5,stable_uarea+066
        setz    1,
        popj    17,

exec_replace_current_lowmem:
        seto    1,
        popj    17,

        .data
        .globl proc_current_slot
proc_current_slot: .word 1
        .globl proc_current_ptr
proc_current_ptr: .word process_desc
        .globl proc_swap_records
proc_swap_records: .word swap_states
        .globl proc_rt_owner
proc_rt_owner: .word 0
launch: .word 1,,5
        .word 0
        .word 0
        .word 1
        .word 060000000000
        .bss
process_desc: .block 3
swap_states: .block 2
stable_uarea: .block 0410
result: .block 6
test_mode: .block 1
destroy_old_count: .block 1
destroy_staged_count: .block 1
failure_flag: .block 1
        .globl __test_exit
__test_exit: .block 1
