; Test the exact production EXEC staged replacement transaction, with
; injected loader, startup and old-VM teardown failures.  In addition to
; swap-backing and PURE mount-bit rollback, cover RT owner preservation,
; acquisition rollback and release at successful non-RT commit.
        .text
        .globl main
        .globl exec_load_process
        .globl vm_space_startup
        .globl vm_space_destroy
        .globl exec_replace_current_lowmem
main:
        movei   7,1                    ; full verified transaction matrix
test_modes:
        movem   7,test_mode
        movei   1,stable_uarea
        lsh     1,022                 ; descriptor meta LH u-area base
        iori    1,0400000             ; PROC_F_UAREA in RH
        movem   1,process_desc
        movei   1,012345
        movem   1,swap_states+1
        move    1,[000234567123]
        ; Cases 1-3 begin with old fifth bit 1; all later cases start at 0.
        caige   7,4
        tlo     1,001000
        movem   1,stable_uarea+066
        setzm   stable_uarea+024
        ; Mode 3 fails old-VM destruction after the user mapping hold is
        ; cleared. Verify that the production path restores that hold.
        caie    7,3
        jrst    test_mapping_ready
        movei   1,2
        movem   1,stable_uarea+024
test_mapping_ready:
        setzm   proc_rt_owner
        caige   7,7
        jrst    test_owner_ready
        movei   1,1
        movem   1,proc_rt_owner
test_owner_ready:
        movei   1,launch
        movei   2,5
        movei   3,result
        pushj   17,exec_replace_current
        move    4,test_mode
        caige   4,4
        jrst    verify_failure
        caie    4,6
        jrst    test_failure_mode7
        jrst    verify_failure
test_failure_mode7:
        caie    4,7
        jrst    verify_success
        jrst    verify_failure
verify_success:
        jumpn   1,test_fail
        move    5,swap_states+1
        caie    5,076543              ; successful EXEC installs new backing
        jrst    test_fail
        move    5,stable_uarea+066
        caie    4,5
        jrst    verify_commit_bit_clear
        tlne    5,001000              ; new mount 26 bit installed at commit
        jrst    test_next
        jrst    test_fail
verify_commit_bit_clear:
        tlne    5,001000
        jrst    test_fail
        jrst    test_next

verify_failure:
        camn    1,[-1]
        jrst    check_old_restored
        movei   1,0101
        popj    17,
check_old_restored:
        move    5,swap_states+1
        caie    5,012345              ; old backing restored
        jrst    fail_backing
        move    5,stable_uarea+066
        caile   4,3
        jrst    check_failure_mapping
        tlne    5,001000              ; old fifth slot bit restored
        jrst    check_failure_mapping
        jrst    fail_mount
check_failure_mapping:
        caie    4,3
        jrst    test_next
        move    5,stable_uarea+024
        trne    5,2                     ; old launch mapping hold restored
        jrst    test_next
        jrst    fail_mapping
test_next:
        ; AC7 may be clobbered by the production EXEC transaction.
        move    7,test_mode
        move    5,proc_rt_owner
        movei   6,0                    ; new claim rolled back / old released
        cain    7,7
        movei   6,1                    ; failed EXEC preserves existing owner
        came    5,6
        jrst    fail_owner
        move    5,stable_uarea+066
        tlz     5,001000
        came    5,[000234567123]       ; credentials unchanged throughout
        jrst    fail_credentials
        aoj     7,
        caile   7,010                  ; modes 1 through 8
        jrst    test_pass
        jrst    test_modes
test_pass:
        setz    1,
        popj    17,
test_fail:
        move    1,test_mode
        addi    1,0200
        popj    17,
fail_backing:
        movei   1,0102
        popj    17,
fail_mount:
        movei   1,0103
        popj    17,
fail_mapping:
        movei   1,0104
        popj    17,
fail_credentials:
        movei   1,0105
        popj    17,
fail_owner:
        movei   1,0106
        popj    17,

; Mock the source of a staged image, NOT the production EXEC transaction.
; Mode 1: load fails after writing new slot bit and record.
; Mode 2: startup fails, then staged destruction clears the bit.
; Mode 3: old VM destruction fails and staged destruction clears the bit.
; Mode 4: successful new mount <=16 (bit 0).
; Mode 5: successful new mount >16 (bit 1).
; Mode 6: new RT claim + startup failure must release that claim.
; Mode 7: existing RT owner + startup failure must retain that owner.
; Mode 8: existing RT owner + successful non-RT EXEC must release owner.
exec_load_process:
        movei   4,076543
        movem   4,swap_states+1
        move    4,stable_uarea+066
        tlz     4,001000
        move    5,test_mode
        caie    5,5
        jrst    exec_mock_attach_done
        tlo     4,001000
exec_mock_attach_done:
        movem   4,stable_uarea+066
        movei   4,02000
        movem   4,1(1)                  ; staged.vm_state
        caie    5,1
        jrst    exec_mock_load_success
        seto    1,
        popj    17,
exec_mock_load_success:
        ; The loader establishes an RT owner on the first RT-required load,
        ; unless it was already owned by the current slot.
        caie    5,6
        jrst    exec_mock_rt_loaded
        movei   4,1
        movem   4,proc_rt_owner
exec_mock_rt_loaded:
        caie    5,6
        jrst    exec_mock_try7
        movei   1,1
        popj    17,
exec_mock_try7:
        caie    5,7
        jrst    exec_mock_no_rt
        movei   1,1
        popj    17,
exec_mock_no_rt:
        setz    1,
        popj    17,

vm_space_startup:
        move    5,test_mode
        caie    5,2
        jrst    exec_mock_startup_mode6
        seto    1,
        popj    17,
exec_mock_startup_mode6:
        caie    5,6
        jrst    exec_mock_startup_mode7
        seto    1,
        popj    17,
exec_mock_startup_mode7:
        caie    5,7
        jrst    exec_mock_startup_ok
        seto    1,
        popj    17,
exec_mock_startup_ok:
        setz    1,
        popj    17,

vm_space_destroy:
        move    5,test_mode
        caie    5,3
        jrst    exec_mock_destroy_ok
        caie    1,process_desc
        jrst    exec_mock_destroy_ok
        seto    1,
        popj    17,
exec_mock_destroy_ok:
        setzm   swap_states+1
        move    5,stable_uarea+066
        tlz     5,001000               ; detach clears fifth mount bit
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
        .word 060000000000             ; single SIXBIT character
        .bss
process_desc: .block 3
swap_states: .block 2
stable_uarea: .block 0410
result: .block 6
test_mode: .block 1
        .globl __test_exit
__test_exit: .block 1
