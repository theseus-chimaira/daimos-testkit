; Native PDP-6 v1090: defer TERM on a serialized provider *waiter*.
; The original holder never returns. Only an undispatched waiter is
; allowed to stop waiting and return -5 on its own kernel stack.
        .text
        .globl main
        .globl __test_exit
        .globl fs_provider_reg_call
        .globl fs_provider_ready
        .globl fs_provider_wait_event_v917
        .globl fs_d6fs_service_jump
        .globl fs_dtfs_service_jump
        .globl fs_tsfs_service_jump
        .globl fs_memfs_service_jump
        .globl proc_event_fatal_other_defer_term_v926
        .globl proc_current_slot
        .globl file_table
        .globl proc_runq_add
        .globl proc_event_fatal_other_done_v883
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl fs_mres_no_service
        .globl kret_neg5
        .globl kconst_7_7
        .globl target_ctl_v1090
        .globl target_desc_v1090
        .globl runq_count_v1090
        .globl stage_v1090
        .globl service_count_v1090

        .equ PROC_FDCTL_OFFSET,024
        .equ PROC_WAIT_EVENT_LH,020000
        .equ PROC_STATE_RUN,0200000
        .equ PROC_STATE_SLEEP,0300000
        .equ PROC_STATE_STOP,0600000
        .equ PROC_STATE_LH_MASK,0700000

main:
        movei   0,provider_v1090
        hrrm    0,fs_dtfs_service_jump
        hrrm    0,fs_d6fs_service_jump
        hrrm    0,fs_tsfs_service_jump
        hrrm    0,fs_memfs_service_jump
        movei   0,4
        movem   0,proc_current_slot
        movei   0,owner_fds_v1090
        movem   0,file_table
        movei   0,target_uarea_v1090
        hrlm    0,target_desc_v1090
        setzm   service_count_v1090
        setzm   wait_count_v1090
        setzm   wake_count_v1090
        setzm   runq_count_v1090
        movei   0,1
        movem   0,stage_v1090
        move    0,[3,,0]              ; slot 2 owns the live lease
        movem   0,fs_provider_ready
        setzm   fs_provider_wait_event_v917
        ; The target is already asleep on the FS lease before TERM.
        movei   0,fs_provider_wait_event_v917
        hrli    0,0320000             ; SLEEP + WAIT_EVENT
        movem   0,target_desc_v1090+2
        setzm   target_ctl_v1090
        pushj   17,send_term_v1090
        jumpn   1,fail_v1090
        move    0,target_ctl_v1090
        tlne    0,04                  ; pending TERM in existing FDCTL
        jrst    term_recorded_v1090
        jrst    fail_v1090
term_recorded_v1090:
        move    0,target_desc_v1090+2
        camn    0,[0200000,,0]       ; RUN, no wait event or wait class
        jrst    target_run_v1090
        jrst    fail_v1090
target_run_v1090:
        move    0,runq_count_v1090
        caie    0,1
        jrst    fail_v1090
        move    0,fs_provider_ready
        came    0,[3,,0]
        jrst    fail_v1090
        ; The resumed waiter sees pending TERM before attempting dispatch.
        ; Its own request frame is discarded; the holder remains untouched.
        movei   0,target_fds_v1090
        movem   0,file_table
        movem   17,original_sp_v1090
        pushj   17,args_v1090
        pushj   17,fs_provider_reg_call
        camn    1,[-5]
        jrst    term_busy_v1090
        jrst    fail_v1090
term_busy_v1090:
        move    0,17
        came    0,original_sp_v1090
        jrst    fail_v1090
        move    0,fs_provider_ready
        came    0,[3,,0]
        jrst    fail_v1090
        skipn   wait_count_v1090
        jrst    no_wait_v1090
        jrst    fail_v1090
no_wait_v1090:
        skipn   service_count_v1090
        jrst    other_event_v1090
        jrst    fail_v1090

other_event_v1090:
        ; Other kernel event waits cannot be canceled by this narrow path.
        movei   0,2
        movem   0,stage_v1090
        setzm   target_ctl_v1090
        setzm   runq_count_v1090
        movei   0,other_event_word_v1090
        hrli    0,0320000
        movem   0,target_desc_v1090+2
        pushj   17,send_term_v1090
        jumpn   1,fail_v1090
        skipn   runq_count_v1090
        jrst    other_not_woken_v1090
        jrst    fail_v1090
other_not_woken_v1090:
        move    0,target_desc_v1090+2
        camn    0,[0320000,,other_event_word_v1090]
        jrst    stopped_v1090
        jrst    fail_v1090

stopped_v1090:
        ; Job-control STOP retains its private wait continuation.
        movei   0,3
        movem   0,stage_v1090
        setzm   target_ctl_v1090
        movei   0,fs_provider_wait_event_v917
        hrli    0,0620000
        movem   0,target_desc_v1090+2
        pushj   17,send_term_v1090
        jumpn   1,fail_v1090
        skipn   runq_count_v1090
        jrst    stopped_not_woken_v1090
        jrst    fail_v1090
stopped_not_woken_v1090:
        move    0,target_desc_v1090+2
        camn    0,[0620000,,fs_provider_wait_event_v917]
        jrst    interrupted_v1090
        jrst    fail_v1090

interrupted_v1090:
        ; v1261: WAIT_INTR is safe to interrupt after a fatal event.
        ; The owner unwinds the private wait frame before termination.
        movei   0,4
        movem   0,stage_v1090
        setzm   target_ctl_v1090
        setzm   runq_count_v1090
        movei   0,fs_provider_wait_event_v917
        hrli    0,0360000             ; SLEEP + WAIT_INTR
        movem   0,target_desc_v1090+2
        pushj   17,send_term_v1090
        jumpn   1,fail_v1090
        move    0,runq_count_v1090
        caie    0,1
        jrst    fail_v1090
interrupted_woken_v1261:
        move    0,target_desc_v1090+2
        camn    0,[0200000,,0]
        jrst    child_wait_v1090
        jrst    fail_v1090

child_wait_v1090:
        ; WAIT_CHILD cannot be woken even with the same synthetic RH.
        movei   0,5
        movem   0,stage_v1090
        setzm   target_ctl_v1090
        setzm   runq_count_v1090
        movei   0,fs_provider_wait_event_v917
        hrli    0,0340000             ; SLEEP + WAIT_CHILD
        movem   0,target_desc_v1090+2
        pushj   17,send_term_v1090
        jumpn   1,fail_v1090
        skipn   runq_count_v1090
        jrst    child_not_woken_v1090
        jrst    fail_v1090
child_not_woken_v1090:
        move    0,target_desc_v1090+2
        camn    0,[0340000,,fs_provider_wait_event_v917]
        jrst    free_fatal_close_v1090
        jrst    fail_v1090

free_fatal_close_v1090:
        ; A process already doing fatal FILE cleanup must still acquire
        ; a FREE lease; do not confuse the fatal-close bit with pending TERM.
        move    0,[4,,4]              ; old TERM plus fatal-close owner
        movem   0,target_ctl_v1090
        setom   fs_provider_ready
        movei   0,6
        movem   0,stage_v1090
        pushj   17,args_v1090
        pushj   17,fs_provider_reg_call
        caie    1,012345
        jrst    fail_v1090
        move    0,service_count_v1090
        caie    0,1
        jrst    fail_v1090
        move    0,wake_count_v1090
        caie    0,1
        jrst    fail_v1090
        move    0,fs_provider_ready
        camn    0,[-1]
        jrst    success_v1090
        jrst    fail_v1090
success_v1090:
        setz    1,
        popj    17,
fail_v1090:
        move    1,stage_v1090
        popj    17,

send_term_v1090:
        movei   010,4
        movei   011,1                 ; SYS_EVENT_TERM
        movei   012,target_desc_v1090
        pushj   17,proc_event_fatal_other_defer_term_v926
        popj    17,
args_v1090:
        movei   1,011
        movei   2,022
        movei   3,033
        movei   4,044
        movei   5,055
        movei   6,066
        movei   7,6                   ; D6FS
        popj    17,
provider_v1090:
        aos     service_count_v1090
        move    0,fs_provider_ready
        camn    0,[5,,0]              ; the current slot 4 owns it
        jrst    provider_ok_v1090
        jrst    fail_v1090
provider_ok_v1090:
        movei   1,012345
        popj    17,
proc_runq_add:
        caie    1,4
        jrst    fail_v1090
        aos     runq_count_v1090
        popj    17,
proc_event_fatal_other_done_v883:
        setz    1,
        popj    17,
proc_wait_event:
        aos     wait_count_v1090
        ; Only an erroneous path can enter this test-only fake wait.
        setom   fs_provider_ready
        popj    17,
proc_wakeup_event:
        aos     wake_count_v1090
        popj    17,
fs_mres_no_service:
        seto    1,
        popj    17,
kret_neg5:
        movni   1,5
        popj    17,

        .data
kconst_7_7: .word 7,,7
proc_current_slot: .word 4
file_table: .word 0
fs_provider_ready: .word 1
fs_provider_wait_event_v917: .word 1
target_desc_v1090: .block 3
owner_ctl_v1090: .word 0
owner_pad_v1090: .word 0
owner_fds_v1090: .word 0
target_uarea_v1090: .block 024
target_ctl_v1090: .word 0
target_pad_v1090: .word 0
target_fds_v1090: .word 0
other_event_word_v1090: .word 0
original_sp_v1090: .word 0
service_count_v1090: .word 0
wait_count_v1090: .word 0
wake_count_v1090: .word 0
runq_count_v1090: .word 0
stage_v1090: .word 0
        .bss
__test_exit: .block 1
