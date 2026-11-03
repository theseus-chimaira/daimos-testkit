; PDP-6 P0-B: the provider lease is owned until the real call returns.
; Exercise recursive and fatal-foreign requests *inside* the provider call,
; rather than preloading a synthetic already-held lock in the caller.
; All test state is private to this native fixture, not DAIMOS KCORE.
        .text
        .globl main
        .globl __test_exit
        .globl fs_provider_reg_call
        .globl fs_provider_ready
        .globl fs_provider_wait_event_v917
        .globl fs_dtfs_service_jump
        .globl fs_d6fs_service_jump
        .globl fs_tsfs_service_jump
        .globl fs_memfs_service_jump
        .globl proc_current_slot
        .globl file_table
        .globl kconst_7_7
        .globl fs_mres_no_service
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl kret_neg5

main:
        movei   0,provider_v1088
        hrrm    0,fs_dtfs_service_jump
        hrrm    0,fs_d6fs_service_jump
        hrrm    0,fs_tsfs_service_jump
        hrrm    0,fs_memfs_service_jump
        movei   0,owner_fds_v1088
        movem   0,file_table
        setzm   wait_count_v1088
        setzm   wake_count_v1088
        setzm   entry_count_v1088
        setzm   error_v1088
        movei   0,1
        movem   0,stage_v1088
        movei   0,2
        movem   0,proc_current_slot
        setom   fs_provider_ready
        setom   fs_provider_wait_event_v917
        move    0,17
        movem   0,outer_sp_v1088
        pushj   17,args_v1088
        pushj   17,fs_provider_reg_call
        camn    1,[-5]                 ; returning provider reports failure
        jrst    first_result_v1088
        jrst    fail_v1088
first_result_v1088:
        move    0,17
        came    0,outer_sp_v1088
        jrst    fail_v1088
        move    0,fs_provider_ready
        camn    0,[-1]                 ; original call alone unlocked
        jrst    first_unlocked_v1088
        jrst    fail_v1088
first_unlocked_v1088:
        move    0,wake_count_v1088
        caie    0,1
        jrst    fail_v1088
        movei   0,2
        movem   0,stage_v1088
        pushj   17,args_v1088
        pushj   17,fs_provider_reg_call
        caie    1,012345              ; later call succeeds normally
        jrst    fail_v1088
        move    0,wake_count_v1088
        caie    0,2                   ; exactly one wake per return
        jrst    fail_v1088
        move    0,entry_count_v1088
        caie    0,2                   ; neither nested contender entered
        jrst    fail_v1088
        skipn   wait_count_v1088      ; neither refusal may sleep
        jrst    no_wait_v1088
        jrst    fail_v1088
no_wait_v1088:
        skipn   error_v1088
        jrst    success_v1088
        jrst    fail_v1088
success_v1088:
        setz    1,
        popj    17,
fail_v1088:
        movei   1,1
        popj    17,

args_v1088:
        movei   1,011
        movei   2,022
        movei   3,033
        movei   4,044
        movei   5,055
        movei   6,066
        movei   7,6                   ; D6FS, serialized index two
        popj    17,

provider_v1088:
        aos     entry_count_v1088
        move    0,fs_provider_ready
        camn    0,[3,,0]              ; slot 2 owns the live lease
        jrst    provider_owned_v1088
        jrst    fail_v1088
provider_owned_v1088:
        move    0,stage_v1088
        caie    0,1
        jrst    provider_success_v1088
        ; This is a live provider frame, not an unlocked provider stub.
        ; Preserve its stack pointer across two nested refused requests.
        movem   17,provider_sp_v1088
        pushj   17,args_v1088
        pushj   17,fs_provider_reg_call
        camn    1,[-5]                 ; recursive owner cannot wait
        jrst    self_refused_v1088
        jrst    fail_v1088
self_refused_v1088:
        move    0,fs_provider_ready
        came    0,[3,,0]
        jrst    fail_v1088
        move    0,17
        came    0,provider_sp_v1088
        jrst    fail_v1088
        ; Simulate a competing fatal requester at the gateway boundary.
        ; On real hardware the scheduler switches stacks; the gateway
        ; still must not use or release the existing provider frame.
        movei   0,4
        movem   0,proc_current_slot
        movei   0,foreign_fds_v1088
        movem   0,file_table
        pushj   17,args_v1088
        pushj   17,fs_provider_reg_call
        camn    1,[-5]                 ; fatal foreign must fail closed
        jrst    foreign_refused_v1088
        jrst    fail_v1088
foreign_refused_v1088:
        move    0,fs_provider_ready
        came    0,[3,,0]
        jrst    fail_v1088
        move    0,17
        came    0,provider_sp_v1088
        jrst    fail_v1088
        movei   0,2
        movem   0,proc_current_slot
        movei   0,owner_fds_v1088
        movem   0,file_table
        ; Permanent error from provider: the caller owns retry policy.
        ; An error return must still unwind by the real gateway unlock.
        movni   1,5
        popj    17,
provider_success_v1088:
        movei   1,012345
        popj    17,

proc_wait_event:
        ; Any wait here is a bug; if the gateway loops, the runner's
        ; bounded instruction budget also rejects the mutated source.
        aos     wait_count_v1088
        movei   1,1
        popj    17,
proc_wakeup_event:
        aos     wake_count_v1088
        popj    17,
fs_mres_no_service:
        seto    1,
        popj    17,
kret_neg5:
        movni   1,5
        popj    17,

        .data
kconst_7_7: .word 7,,7
proc_current_slot: .word 2
file_table: .word 0
fs_provider_ready: .word 1
fs_provider_wait_event_v917: .word 1
outer_sp_v1088: .word 0
provider_sp_v1088: .word 0
entry_count_v1088: .word 0
wait_count_v1088: .word 0
wake_count_v1088: .word 0
error_v1088: .word 0
stage_v1088: .word 0
owner_ctl_v1088: .word 0
owner_pad_v1088: .word 0
owner_fds_v1088: .word 0
foreign_ctl_v1088: .word 4       ; PROC_FATAL_CLOSE_BIT
foreign_pad_v1088: .word 0
foreign_fds_v1088: .word 0
        .bss
__test_exit: .block 1
