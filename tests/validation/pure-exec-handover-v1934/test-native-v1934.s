; Test the exact production EXEC staged replacement transaction, with
; injected loader, startup and old-VM teardown failures.  In addition to
; swap-backing and PURE mount/provider identity rollback, cover RT owner preservation,
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
        move    1,old_packed_v1934
        movem   1,swap_states+1
        move    1,[04000,,02000]
        movem   1,process_desc+1
        movsi   1,0200000
        movem   1,process_desc+2
        move    1,[010234567123]       ; old provider 4, original credentials
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
        cail    7,7
        caile   7,010
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
        cain    4,7
        jrst    verify_failure
        cain    4,011
        jrst    verify_failure
        jrst    verify_success
verify_success:
        jumpn   1,test_fail
        move    5,swap_states+1
        came    5,new_packed_v1934              ; successful EXEC installs new backing
        jrst    test_fail
        move    5,stable_uarea+066
        ldb     6,[POINT 3,5,7]
        caie    6,6                     ; new provider
        jrst    fail_credentials
        caie    4,5
        jrst    verify_commit_bit_clear
        tlne    5,001000              ; new extended mount bit installed at commit
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
        came    5,old_packed_v1934              ; old backing restored
        jrst    fail_backing
        move    5,stable_uarea+066
        ldb     6,[POINT 3,5,7]
        caie    6,4                     ; old provider restored
        jrst    fail_credentials
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
        skipe   proc_exec_resv_head_v1933
        jrst    fail_holds_v1934
        pushj   17,check_final_v1934
        ; AC7 may be clobbered by the production EXEC transaction.
        move    7,test_mode
        move    5,proc_rt_owner
        movei   6,0                    ; new claim rolled back / old released
        cain    7,7
        movei   6,1                    ; failed EXEC preserves existing owner
        came    5,6
        jrst    fail_owner
        move    5,stable_uarea+066
        tlz     5,017000
        came    5,[000234567123]       ; credentials unchanged throughout
        jrst    fail_credentials
        aoj     7,
        caile   7,011                  ; modes 1 through 9
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
        move    5,test_mode
        cain    5,011
        jrst    load_nomem_v1934
        move    4,new_packed_v1934
        movem   4,swap_states+1
        move    4,stable_uarea+066
        tlz     4,017000
        tlo     4,014000               ; replacement provider 6
        move    5,test_mode
        caie    5,5
        jrst    exec_mock_attach_done
        tlo     4,001000
exec_mock_attach_done:
        movem   4,stable_uarea+066
        pushj   17,check_both_v1934
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

load_nomem_v1934:
        ; No new image or backing was published.
        pushj   17,check_old_v1934
        movni   1,2
        popj    17,

vm_space_startup:
        pushj   17,check_both_v1934
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
        pushj   17,check_both_v1934
        ; The original record AND original provider must be installed
        ; before old-VM destroy; staged destroy must see the new pair.
        move    4,stable_uarea+066
        ldb     4,[POINT 3,4,7]
        caie    1,process_desc
        jrst    exec_mock_destroy_new_v1924
        caie    4,4
        jrst    exec_mock_bad_identity_v1924
        jrst    exec_mock_destroy_check_v1924
exec_mock_destroy_new_v1924:
        caie    4,6
        jrst    exec_mock_bad_identity_v1924
exec_mock_destroy_check_v1924:
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
        tlz     5,017000               ; detach clears backing identity
        movem   5,stable_uarea+066
        move    5,test_mode
        cain    5,1
        jrst    destroy_old_only_v1934
        pushj   17,check_both_v1934
        jrst    destroy_checked_v1934
destroy_old_only_v1934:
        pushj   17,check_old_v1934
destroy_checked_v1934:
        setz    1,
        popj    17,

exec_mock_bad_identity_v1924:
        ; Fail the guest directly, not merely simulate an MM refusal.
        movei   1,0777
        movem   1,__test_exit
        halt    .

exec_replace_current_lowmem:
        ; Fallback has not yet destroyed the original image. It owns
        ; its subsequent lifetime; the outer hold must already be gone.
        skipe   proc_exec_resv_head_v1933
        jrst    fail_holds_v1934
        pushj   17,check_old_v1934
        seto    1,
        popj    17,

; Use real busy scanners for every callback. Preserve the ABI registers
; since these probes represent a foreign mutation/unmount attempt.
check_both_v1934:
        pushj   17,check_old_v1934
        push    17,1
        push    17,2
        push    17,3
        push    17,4
        push    17,5
        push    17,6
        pushj   17,new_node_v1934
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    fail_holds_v1934
        pushj   17,new_mount_v1934
        pushj   17,proc_swap_mount_busy
        caie    1,1
        jrst    fail_holds_v1934
        jrst    restore_probe_v1934
check_old_v1934:
        push    17,1
        push    17,2
        push    17,3
        push    17,4
        push    17,5
        push    17,6
        pushj   17,old_node_v1934
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    fail_holds_v1934
        pushj   17,old_mount_v1934
        pushj   17,proc_swap_mount_busy
        caie    1,1
        jrst    fail_holds_v1934
restore_probe_v1934:
        pop     17,6
        pop     17,5
        pop     17,4
        pop     17,3
        pop     17,2
        pop     17,1
        popj    17,
old_mount_v1934:
        movei   1,1
        move    2,test_mode
        caige   2,4
        movei   1,021
        popj    17,
new_mount_v1934:
        movei   1,2
        move    2,test_mode
        cain    2,5
        movei   1,022
        popj    17,
old_node_v1934:
        pushj   17,old_mount_v1934
        lsh     1,030
        ior     1,[040001012345]
        popj    17,
new_node_v1934:
        pushj   17,new_mount_v1934
        lsh     1,030
        ior     1,[060001076543]
        popj    17,
check_final_v1934:
        move    4,test_mode
        caige   4,4
        jrst    final_old_v1934
        caie    4,6
        cain    4,7
        jrst    final_old_v1934
        cain    4,011
        jrst    final_old_v1934
        pushj   17,new_node_v1934
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    fail_holds_v1934
        pushj   17,old_mount_v1934
        pushj   17,proc_swap_mount_busy
        jumpn   1,fail_holds_v1934
        popj    17,
final_old_v1934:
        pushj   17,old_node_v1934
        pushj   17,proc_swap_backing_busy
        caie    1,1
        jrst    fail_holds_v1934
        pushj   17,new_mount_v1934
        pushj   17,proc_swap_mount_busy
        jumpn   1,fail_holds_v1934
        popj    17,
fail_holds_v1934:
        movei   1,0700
        add     1,test_mode
        movem   1,__test_exit
        halt    .
        .globl vfs_dtfs_owner_admit_v1562
vfs_dtfs_owner_admit_v1562:
        setz    1,
        popj    17,
        .globl kret_zero
kret_zero:
        setz    1,
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        jrst    fail_holds_v1934

        .data
        .globl proc_high_slot
proc_high_slot: .word 2
        .globl proc_table
proc_table: .word process_desc-3
        .globl vfs_mount_limit
vfs_mount_limit: .word 022
        .globl vfs_mount_root_base
vfs_mount_root_base: .word roots_v1934
roots_v1934:
        .word 040101000001
        .word 060201000001
        .block 016
        .word 042101000001
        .word 062201000001
old_packed_v1934: .word 0016000012345
new_packed_v1934: .word 0014001076543
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
