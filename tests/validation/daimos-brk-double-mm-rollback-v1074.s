; Source-linked PDP-6 BRK rollback double-failure regression.
; The test replaces only the two callable MM/exit stubs. The rollback
; instructions themselves come from the production vm_pdp6.s source.
        .text
        .globl main
main:
        ; Missing/wrong old extent: clean up new and preserve MM -4.
        movei 1,0
        movem 1,__new_result
        movem 1,__invariants
        movem 1,__free_calls
        movem 1,__cause
        movni 1,4
        pushj 17,run_case
        move 1,__cause
        camn 1,[-4]
        jrst first_clean
        jrst fail
first_clean:
        move 1,__free_calls
        caie 1,1
        jrst fail
        skipn __invariants
        jrst second_case
        jrst fail

second_case:
        ; Pinned old extent: a successful rollback reports MM -5.
        setzm __free_calls
        setzm __cause
        movni 1,5
        pushj 17,run_case
        move 1,__cause
        camn 1,[-5]
        jrst second_clean
        jrst fail
second_clean:
        move 1,__free_calls
        caie 1,1
        jrst fail
        skipn __invariants
        jrst third_case
        jrst fail

third_case:
        ; Both frees reject: old code returned and leaked the new extent.
        ; Production must instead enter the storage-invariant HALT target.
        setzm __free_calls
        setzm __cause
        movni 1,5
        movem 1,__new_result
        pushj 17,run_case
        move 1,__invariants
        caie 1,1
        jrst fail
        move 1,__free_calls
        caie 1,1
        jrst fail
        skipn __cause
        jrst success
        jrst fail
success:
        setzm __test_exit
        halt
fail:
        movei 1,1
        movem 1,__test_exit
        halt

; Enter the actual rollback at its original stack layout: (17) is the
; provisional base, -004(17) is a reusable stack local. PUSHJ return
; lives one word below those scratch values.
run_case:
        add 17,[5,,5]
        movei 0,040000
        movem 0,(17)
        jrst vm_brk_rollback_new_v1074

        .globl mm_free
mm_free:
        move 0,1
        camn 0,[040000]
        jrst free_expected_base
        movei 1,2
        jrst error_record
free_expected_base:
        move 0,2
        caie 0,1
        jrst wrong_free_args
        move 0,3
        caie 0,2
        jrst wrong_free_args
        aos __free_calls
        move 1,__new_result
        popj 17,
wrong_free_args:
        movei 1,2
error_record:
        movem 1,__invariants
        popj 17,

; Simulate the existing production invariant HALT with a witness. This
; hook is only in the test executable and is never part of DAIMOS KCORE.
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos __invariants
        sub 17,[5,,5]
        popj 17,

        .globl vm_brk_fail_cause_pi_v999
vm_brk_fail_cause_pi_v999:
        movem 2,__cause
        sub 17,[5,,5]
        popj 17,

        .data
        .globl proc_current_slot
proc_current_slot: .word 2
        .bss
__new_result: .block 1
__invariants: .block 1
__free_calls: .block 1
__cause: .block 1
        .globl __test_exit
__test_exit: .block 1
