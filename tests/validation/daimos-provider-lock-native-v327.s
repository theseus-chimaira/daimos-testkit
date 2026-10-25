        .text
        .globl main
        .globl __test_exit
        .globl fs_provider_reg_call
        .globl fs_mres_no_service
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl fs_provider_ready
        .globl kconst_7_7
main:
        movei 0,provider_oracle
        hrrm 0,fs_dtfs_service_jump
        hrrm 0,fs_d6fs_service_jump
        hrrm 0,fs_tsfs_service_jump
        hrrm 0,fs_memfs_service_jump
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
        jrst success
fail:
        movei 1,1
        popj 17,
success:
        setz 1,
        popj 17,
provider_oracle:
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
        .data
kconst_7_7:
        .word 7,,7
        .bss
fs_provider_ready:
        .block 1
wait_count:
        .block 1
__test_exit:
        .block 1
