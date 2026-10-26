; Native PDP-6 nested scheduling oracle for the shared provider lease.
; The waiter must not dispatch until the current owner releases the lease.
        .text
        .globl main
        .globl __test_exit
        .globl fs_provider_reg_call
        .globl fs_mres_no_service
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl fs_provider_ready
        .globl fs_block_workspace
        .globl kconst_7_7
main:
        movei 0,provider_oracle
        hrrm 0,fs_dtfs_service_jump
        hrrm 0,fs_d6fs_service_jump
        hrrm 0,fs_tsfs_service_jump
        setzm fs_provider_ready
        setzm wait_count
        setzm provider_count
        movei 0,012345
        movem 0,fs_block_workspace
        movei 1,011
        movei 2,022
        movei 3,033
        movei 4,044
        movei 5,055
        movei 6,066
        movei 7,6
        pushj 17,fs_provider_reg_call
        caie 1,012346
        jrst test_fail
        move 0,wait_count
        caie 0,1
        jrst test_fail
        move 0,provider_count
        caie 0,1
        jrst test_fail
        move 0,fs_block_workspace
        caie 0,012345
        jrst test_fail
        skipn fs_provider_ready
        jrst test_fail
        setz 1,
        popj 17,
test_fail:
        movei 1,1
        popj 17,
provider_oracle:
        caie 1,011
        jrst test_fail
        caie 2,022
        jrst test_fail
        caie 3,033
        jrst test_fail
        caie 4,044
        jrst test_fail
        caie 5,055
        jrst test_fail
        caie 6,066
        jrst test_fail
        move 0,fs_block_workspace
        caie 0,012345
        jrst test_fail
        aos provider_count
        movei 1,012346
        popj 17,
proc_wait_event:
        aos wait_count
        ; Simulated scheduling of another process: it may clobber ACs,
        ; but must not write the leased buffer or dispatch the provider.
        move 0,fs_block_workspace
        caie 0,012345
        jrst test_fail
        skipn provider_count
        jrst wait_release
        jrst test_fail
wait_release:
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
        .data
kconst_7_7: .word 7,,7
        .bss
fs_provider_ready: .block 1
fs_block_workspace: .block 0200
wait_count: .block 1
provider_count: .block 1
__test_exit: .block 1
