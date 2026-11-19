; Integrated PDP6 terminal-finalizer with actual original MM pin/unpin.
; A foreign request ends the already-PACKED sleeping process slot 2.
; Three attempts execute original FINALIZE+PREVM with the real MM pin.
; User return, backing, source and mode are never forged as success.
        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        ; Reuse real v881 process slot 2, but make VM nonresident.
        move 1,[010000,,0]
        movem 1,__uarea+020
        move 1,[02000,,0]
        movem 1,__ptable+7
        movei 1,__records_v1681
        movem 1,proc_swap_records
        movei 1,__modes_v1681
        movem 1,proc_storage_runtime_v29
        movei 1,4
        movem 1,proc_storage_runtime_v29+1
        movei 1,040
        movem 1,__modes_v1681
        move 1,[V1681_BACKING_WORD]
        movem 1,__records_v1681+2
        movem 1,__uarea+0406
        movei 1,1
        movem 1,mm_extent_count
        move 1,[01400,,050400]
        movem 1,mm_extents
        move 1,[4,,2]
        movem 1,mm_extents+1
        movei 1,050400
        pushj 17,mm_pin
        jumpn 1,fail_1_v1681
        ; First finalization must fail due to original pin guard.
        movei 1,2
        movei 2,012345
        pushj 17,proc_finish_slot
        camn 1,[-1]
        jrst first_v1681
        jrst fail_2_v1681
first_v1681:
        move 1,__ptable+6
        trnn 1,0200000           ; TRANSITION
        jrst fail_3_v1681
        move 1,__ptable+7
        came 1,[02000,,0]       ; exactly original absent APR
        jrst fail_4_v1681
        move 1,__uarea+067
        tlnn 1,0400000           ; FINALIZE
        jrst fail_5_v1681
        tlnn 1,0100000           ; PREVM
        jrst fail_6_v1681
        hrrz 1,1
        caie 1,012345
        jrst fail_7_v1681
        move 1,proc_finish_last_tick_v881
        tlnn 1,0400000           ; pending timer retry
        jrst fail_8_v1681
        move 1,mm_extent_count
        caie 1,1
        jrst fail_9_v1681
        move 1,mm_extents+1
        came 1,[014,,2]         ; exact original type + PIN=1 + owner
        jrst fail_10_v1681
        move 1,__records_v1681+2
        came 1,[V1681_BACKING_WORD]
        jrst fail_11_v1681
        move 1,__release_calls
        jumpn 1,fail_12_v1681
        ; Original idle-stack finalizer retry still refuses.
        pushj 17,proc_finish_service_v881
        jumpn 1,fail_13_v1681
        move 1,mm_extents+1
        came 1,[014,,2]
        jrst fail_14_v1681
        move 1,__hup_calls
        caie 1,1
        jrst fail_15_v1681
        ; Original timer/backoff advancement is invoked separately in
        ; this test harness (not a physical PI6 scheduler clock).
        pushj 17,proc_finish_backoff_advance_v885
        move 1,proc_finish_last_tick_v881
        hlrz 1,1
        andi 1,0377777
        caie 1,040              ; initial 020 -> 040 after failure
        jrst fail_29_v1681
        ; The original MM unpin is the only release event.
        movei 1,050400
        pushj 17,mm_unpin
        jumpn 1,fail_16_v1681
        move 1,mm_extents+1
        came 1,[4,,2]
        jrst fail_17_v1681
        pushj 17,proc_finish_service_v881
        jumpn 1,fail_18_v1681
        ; VM has committed; uarea fixture refuses its first cleanup.
        move 1,__ptable+7
        camn 1,[-1]
        jrst vm_done_v1681
        jrst fail_19_v1681
vm_done_v1681:
        skipn mm_extent_count
        jrst final_check_v1681
        jrst fail_20_v1681
final_check_v1681:
        skipn __records_v1681+2
        jrst check_mode_v1681
        jrst fail_21_v1681
check_mode_v1681:
        skipn __modes_v1681
        jrst check_release_v1681
        jrst fail_22_v1681
check_release_v1681:
        move 1,__release_calls
        caie 1,1
        jrst fail_23_v1681
        ; Additional idle retries do not re-enter VM or detach.
        pushj 17,proc_finish_service_v881
        jumpn 1,fail_24_v1681
        pushj 17,proc_finish_service_v881
        caie 1,1
        jrst fail_25_v1681
        move 1,__hup_calls
        caie 1,1
        jrst fail_26_v1681
        move 1,__runq_calls
        caie 1,1
        jrst fail_27_v1681
        skipn mm_extent_count
        jrst clear_retry_v1681
        jrst fail_28_v1681
clear_retry_v1681:
        pushj 17,proc_finish_backoff_advance_v885
        move 1,proc_finish_last_tick_v881
        hlrz 1,1
        jumpn 1,fail_30_v1681
pass_v1681: setz 1,
        jrst done_v1681
fail_1_v1681: movei 1,1
        jrst done_v1681
fail_2_v1681: movei 1,2
        jrst done_v1681
fail_3_v1681: movei 1,3
        jrst done_v1681
fail_4_v1681: movei 1,4
        jrst done_v1681
fail_5_v1681: movei 1,5
        jrst done_v1681
fail_6_v1681: movei 1,6
        jrst done_v1681
fail_7_v1681: movei 1,7
        jrst done_v1681
fail_8_v1681: movei 1,010
        jrst done_v1681
fail_9_v1681: movei 1,011
        jrst done_v1681
fail_10_v1681: movei 1,012
        jrst done_v1681
fail_11_v1681: movei 1,013
        jrst done_v1681
fail_12_v1681: movei 1,014
        jrst done_v1681
fail_13_v1681: movei 1,015
        jrst done_v1681
fail_14_v1681: movei 1,016
        jrst done_v1681
fail_15_v1681: movei 1,017
        jrst done_v1681
fail_16_v1681: movei 1,020
        jrst done_v1681
fail_17_v1681: movei 1,021
        jrst done_v1681
fail_18_v1681: movei 1,022
        jrst done_v1681
fail_19_v1681: movei 1,023
        jrst done_v1681
fail_20_v1681: movei 1,024
        jrst done_v1681
fail_21_v1681: movei 1,025
        jrst done_v1681
fail_22_v1681: movei 1,026
        jrst done_v1681
fail_23_v1681: movei 1,027
        jrst done_v1681
fail_24_v1681: movei 1,030
        jrst done_v1681
fail_25_v1681: movei 1,031
        jrst done_v1681
fail_26_v1681: movei 1,032
        jrst done_v1681
fail_27_v1681: movei 1,033
        jrst done_v1681
fail_28_v1681: movei 1,034
        jrst done_v1681
fail_29_v1681: movei 1,035
        jrst done_v1681
fail_30_v1681: movei 1,036
        jrst done_v1681
done_v1681:
        movem 1,__test_exit
        jrst 4,0
