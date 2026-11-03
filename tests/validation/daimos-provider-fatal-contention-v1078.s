; PDP-6: a fatal FILE owner must not sleep behind another provider.
; The gateway under test is extracted from production fs_mres.s.
        .text
        .globl  main
        .globl  __test_exit
        .globl  fs_provider_reg_call
        .globl  fs_provider_ready
        .globl  fs_provider_wait_event_v917
        .globl  fs_dtfs_service_jump
        .globl  fs_d6fs_service_jump
        .globl  fs_tsfs_service_jump
        .globl  fs_memfs_service_jump
        .globl  fs_mres_no_service
        .globl  proc_wait_event
        .globl  proc_wakeup_event
        .globl  proc_current_slot
        .globl  file_table
        .globl  kconst_7_7
        .globl  kret_neg5

main:
        movei   0,1
        movem   0,__stage_v1078
        movei   0,provider_oracle_v1078
        hrrm    0,fs_dtfs_service_jump
        hrrm    0,fs_d6fs_service_jump
        hrrm    0,fs_tsfs_service_jump
        hrrm    0,fs_memfs_service_jump
        movei   0,__file_records_v1078
        movem   0,file_table
        setzm   wait_count_v1078
        setzm   service_count_v1078
        setzm   wakeup_count_v1078
        ; Slot 4 is already in the D6FS provider; slot 2 is fatal.
        move    0,[5,,0]
        movem   0,fs_provider_ready
        setzm   fs_provider_wait_event_v917
        movei   0,4
        movem   0,__fdctl_v1078
        pushj   17,set_args_v1078
        movem   17,__saved_sp_v1078
        pushj   17,fs_provider_reg_call
        movem   1,__fatal_return_v1078
        move    0,wait_count_v1078
        movem   0,__fatal_wait_v1078
        move    0,service_count_v1078
        movem   0,__fatal_service_v1078
        camn    17,__saved_sp_v1078
        jrst    fatal_sp_ok_v1078
        jrst    fail_v1078
fatal_sp_ok_v1078:
        camn    1,[-5]
        jrst    fatal_busy_ok_v1078
        jrst    fail_v1078
fatal_busy_ok_v1078:
        caie    2,022
        jrst    fail_v1078
        caie    3,033
        jrst    fail_v1078
        caie    4,044
        jrst    fail_v1078
        caie    5,055
        jrst    fail_v1078
        caie    6,066
        jrst    fail_v1078
        caie    7,2
        jrst    fail_v1078
        move    0,fs_provider_ready
        camn    0,[5,,0]
        jrst    fatal_lease_ok_v1078
        jrst    fail_v1078
fatal_lease_ok_v1078:
        skipn   wait_count_v1078
        jrst    fatal_no_wait_v1078
        jrst    fail_v1078
fatal_no_wait_v1078:
        skipn   service_count_v1078
        jrst    foreign_normal_v1078
        jrst    fail_v1078

foreign_normal_v1078:
        ; Ordinary foreign callers still wait, recheck, and enter.
        movei   0,2
        movem   0,__stage_v1078
        setzm   __fdctl_v1078
        pushj   17,set_args_v1078
        pushj   17,fs_provider_reg_call
        caie    1,012345
        jrst    fail_v1078
        move    0,wait_count_v1078
        caie    0,1
        jrst    fail_v1078
        move    0,service_count_v1078
        caie    0,1
        jrst    fail_v1078
        skipn   fs_provider_ready
        jrst    fail_v1078

fatal_free_v1078:
        ; Fatal owners may execute a free provider, not reject it.
        movei   0,3
        movem   0,__stage_v1078
        movei   0,4
        movem   0,__fdctl_v1078
        pushj   17,set_args_v1078
        pushj   17,fs_provider_reg_call
        caie    1,012345
        jrst    fail_v1078
        move    0,service_count_v1078
        caie    0,2
        jrst    fail_v1078
        move    0,wait_count_v1078
        caie    0,1
        jrst    fail_v1078

recursive_v1078:
        ; Self-recursion still refuses, independent of fatal status.
        movei   0,4
        movem   0,__stage_v1078
        setzm   __fdctl_v1078
        move    0,[3,,0]
        movem   0,fs_provider_ready
        pushj   17,set_args_v1078
        pushj   17,fs_provider_reg_call
        camn    1,[-5]
        jrst    recursive_ok_v1078
        jrst    fail_v1078
recursive_ok_v1078:
        move    0,fs_provider_ready
        camn    0,[3,,0]
        jrst    finished_v1078
        jrst    fail_v1078
finished_v1078:
        move    0,wakeup_count_v1078
        caie    0,2
        jrst    fail_v1078
        setz    1,
        popj    17,
fail_v1078:
        move    1,__stage_v1078
        popj    17,

set_args_v1078:
        movei   1,011
        movei   2,022
        movei   3,033
        movei   4,044
        movei   5,055
        movei   6,066
        movei   7,6                   ; D6FS, serialized index 2
        popj    17,

provider_oracle_v1078:
        ; There may only be a provider call with its own lease.
        hrrz    0,fs_provider_ready
        jumpn   0,fail_v1078
        hlrz    0,fs_provider_ready
        caie    0,3                   ; current slot 2 + 1
        jrst    fail_v1078
        caie    1,011
        jrst    fail_v1078
        caie    2,022
        jrst    fail_v1078
        caie    3,033
        jrst    fail_v1078
        caie    4,044
        jrst    fail_v1078
        caie    5,055
        jrst    fail_v1078
        caie    6,066
        jrst    fail_v1078
        caie    7,2
        jrst    fail_v1078
        aos     service_count_v1078
        movei   1,012345
        popj    17,

proc_wait_event:
        ; The stub returns the held provider to normal service.
        ; A fatal owner must NEVER invoke this stub in the first case.
        aos     wait_count_v1078
        setom   fs_provider_ready
        setom   fs_provider_wait_event_v917
        movei   1,0777
        movei   2,0777
        movei   3,0777
        movei   4,0777
        movei   5,0777
        movei   6,0777
        movei   7,0777
        popj    17,
proc_wakeup_event:
        aos     wakeup_count_v1078
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
__fdctl_v1078: .word 0
__file_reserved_v1078: .word 0
__file_records_v1078: .word 0
__saved_sp_v1078: .word 0
wait_count_v1078: .word 0
service_count_v1078: .word 0
wakeup_count_v1078: .word 0
__stage_v1078: .word 0
__fatal_return_v1078: .word 0
__fatal_wait_v1078: .word 0
__fatal_service_v1078: .word 0
        .bss
__test_exit: .block 1
