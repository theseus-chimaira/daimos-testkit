        .text
        .globl main
        .globl __test_exit
        .globl fs_provider_reg_call
        .globl fs_mres_no_service
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl fs_provider_ready
.globl proc_current_slot
        .globl kconst_7_7
main:
        movei 0,provider_oracle
        hrrm 0,fs_dtfs_service_jump
        hrrm 0,fs_d6fs_service_jump
        hrrm 0,fs_tsfs_service_jump
        hrrm 0,fs_memfs_service_jump
        ; The current process is slot 2; the lease owner is slot+1=3.
        ; A recursive call must return -5 without sleeping or unlocking.
        move 0,[3,,0]
        movem 0,fs_provider_ready
        setzm wait_count
        movei 1,011
        movei 2,022
        movei 3,033
        movei 4,044
        movei 5,055
        movei 6,066
        movei 7,5
        movem 17,__saved_sp_v915
        pushj 17,fs_provider_reg_call
        camn 17,__saved_sp_v915
        jrst self_sp_ok_v915
        jrst fail
self_sp_ok_v915:
        caie 2,022
        jrst fail
        caie 3,033
        jrst fail
        caie 4,044
        jrst fail
        caie 5,055
        jrst fail
        caie 6,066
        jrst fail
        caie 7,1                  ; provider number adjusted to index
        jrst fail
        camn 1,[-5]
        jrst self_refused_v915
        jrst fail
self_refused_v915:
        move 0,fs_provider_ready
        camn 0,[3,,0]
        jrst self_lock_kept_v915
        jrst fail
self_lock_kept_v915:
        skipn wait_count
        jrst self_no_wait_v915
        jrst fail
self_no_wait_v915:
        ; Verify normal contention from a different process still waits.
        movei 1,3
        movem 1,proc_current_slot
        movei 1,4
        movem 1,__expected_owner_v915
        movei 1,011
        movei 2,022
        movei 3,033
        movei 4,044
        movei 5,055
        movei 6,066
        movei 7,5
        pushj 17,fs_provider_reg_call
        caie 1,012345
        jrst fail
        move 0,wait_count
        caie 0,1
        jrst fail
        skipn fs_provider_ready
        jrst fail
        ; Restore the original slot-2 owner for the older v866 checks.
        movei 1,2
        movem 1,proc_current_slot
        movei 1,3
        movem 1,__expected_owner_v915
        setzm fs_provider_ready
        setzm wait_count
        movei 1,011
        movei 2,022
        movei 3,033
        movei 4,044
        movei 5,055
        movei 6,066
        movei 7,5
        pushj 17,fs_provider_reg_call
        caie 1,012345
        jrst fail
        move 0,wait_count
        caie 0,1
        jrst fail
        skipn fs_provider_ready
        jrst fail
        ; Physical providers D6FS and TSFS use the same serialized path.
        ; A free lock must dispatch without waiting.
        movei 010,6
physical_loop:
        setzm wait_count
        movei 1,011
        movei 2,022
        movei 3,033
        movei 4,044
        movei 5,055
        movei 6,066
        move 7,010
        pushj 17,fs_provider_reg_call
        caie 1,012345
        jrst fail
        skipn fs_provider_ready
        jrst fail
        skipn wait_count
        jrst physical_next
        jrst fail
physical_next:
        aoj 010,
        caig 010,7
        jrst physical_loop
        ; A missing physical service must still release the provider lease.
        movei 0,fs_mres_no_service
        hrrm 0,fs_tsfs_service_jump
        movei 7,7
        pushj 17,fs_provider_reg_call
        jumpge 1,fail
        skipn fs_provider_ready
        jrst fail
        movei 0,provider_oracle
        hrrm 0,fs_tsfs_service_jump
        ; Invalid providers fail without entering serialization.
        movei 7,3
        pushj 17,fs_provider_reg_call
        jumpge 1,fail
        movei 7,010
        pushj 17,fs_provider_reg_call
        jumpge 1,fail
        ; MEMFS direct call must not acquire the provider lock.
        setzm wait_count
        movei 1,011
        movei 2,022
        movei 3,033
        movei 4,044
        movei 5,055
        movei 6,066
        movei 7,4
        pushj 17,fs_provider_reg_call
        caie 1,012345
        jrst fail
        skipn fs_provider_ready
        jrst fail
        skipn wait_count
        jrst memfs_missing_test_v432
        jrst fail
memfs_missing_test_v432:
        ; The direct MEMFS slot may be unbound. Its normal trampoline
        ; returns -1 without claiming or releasing the provider lease.
        movei 0,fs_mres_no_service
        hrrm 0,fs_memfs_service_jump
        movei 7,4
        pushj 17,fs_provider_reg_call
        jumpge 1,fail
        skipn fs_provider_ready
        jrst fail
        skipn wait_count
        jrst success
        jrst fail
fail:
        movei 1,1
        popj 17,
success:
        setz 1,
        popj 17,
provider_oracle:
        ; Physical providers must hold the lease as owner_slot+1,,0.
        ; MEMFS index zero bypasses the lock.
        jumpn 7,oracle_locked_v866
        hrrz 0,fs_provider_ready
        jumpe 0,fail
        jrst oracle_arguments_v866
oracle_locked_v866:
        hrrz 0,fs_provider_ready
        jumpn 0,fail
        hlrz 0,fs_provider_ready
        camn 0,__expected_owner_v915
        jrst oracle_arguments_v866
        jrst fail
oracle_arguments_v866:
        caie 1,011
        jrst fail
        caie 2,022
        jrst fail
        caie 3,033
        jrst fail
        caie 4,044
        jrst fail
        caie 5,055
        jrst fail
        caie 6,066
        jrst fail
        movei 1,012345
        popj 17,
proc_wait_event:
        aos wait_count
        setom fs_provider_ready
        movei 1,0777
        movei 2,0777
        movei 3,0777
        movei 4,0777
        movei 5,0777
        movei 6,0777
        movei 7,0777
        popj 17,
proc_wakeup_event:
        popj 17,
fs_mres_no_service:
        seto 1,
        popj 17,
.globl kret_neg5
kret_neg5:
        movni 1,5
        popj 17,
        .data
        .globl fs_provider_wait_event_v917
fs_provider_wait_event_v917: .word 1
kconst_7_7:
        .word 7,,7
proc_current_slot: .word 2
__expected_owner_v915: .word 3
__saved_sp_v915: .word 0
        .bss
fs_provider_ready:
        .block 1
wait_count:
        .block 1
__test_exit:
        .block 1
