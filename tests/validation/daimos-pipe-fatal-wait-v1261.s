; Native PDP-6: fatal events abort an interruptible pipe/FIFO wait
; both at initial entry and when the private wait frame resumes.
        .text
        .globl main
main:
        ; TERM already pending before the event wait is armed.
        movsi   0,04
        movem   0,ctl_v1261
        movei   1,event_v1261
        pushj   17,proc_wait_event_intr
        camn    1,[-1]
        jrst    pre_term_ok_v1261
        movei   1,1
        popj    17,
pre_term_ok_v1261:
        ; The fatal event may instead arrive while the owner sleeps.
        pushj   17,proc_wait_intr_return
        camn    1,[-1]
        jrst    post_term_ok_v1261
        movei   1,2
        popj    17,
post_term_ok_v1261:
        ; Pending PIPE is kept in the low half, not the TERM bitmap.
        movei   0,1
        movem   0,ctl_v1261
        movei   1,event_v1261
        pushj   17,proc_wait_event_intr
        camn    1,[-1]
        jrst    pre_pipe_ok_v1261
        movei   1,3
        popj    17,
pre_pipe_ok_v1261:
        pushj   17,proc_wait_intr_return
        camn    1,[-1]
        jrst    post_pipe_ok_v1261
        movei   1,4
        popj    17,
post_pipe_ok_v1261:
        ; Existing ALRM interruption remains supported.
        movsi   0,0100
        movem   0,ctl_v1261
        movei   1,event_v1261
        pushj   17,proc_wait_event_intr
        camn    1,[-1]
        jrst    pre_alarm_ok_v1261
        movei   1,5
        popj    17,
pre_alarm_ok_v1261:
        pushj   17,proc_wait_intr_return
        camn    1,[-1]
        jrst    post_alarm_ok_v1261
        movei   1,6
        popj    17,
post_alarm_ok_v1261:
        ; Nonfatal bookkeeping must not abort an interruptible wait.
        movsi   0,0400
        movem   0,ctl_v1261
        pushj   17,proc_wait_intr_return
        jumpe   1,nonfatal_ok_v1261
        movei   1,7
        popj    17,
nonfatal_ok_v1261:
        ; Already-signaled events return without any sleep or fatal error.
        setzm   ctl_v1261
        setom   event_v1261
        movei   1,event_v1261
        pushj   17,proc_wait_event_intr
        jumpe   1,pass_v1261
        movei   1,010
        popj    17,
pass_v1261:
        setz    1,
        popj    17,

        .globl kret_zero
kret_zero:
        setz    1,
        popj    17,
        .globl kret_neg1
kret_neg1:
        seto    1,
        popj    17,
        .globl proc_wait_event
proc_wait_event:
        movei   1,011                 ; unreachable for tested state
        popj    17,
        .globl proc_wait_event_common
proc_wait_event_common:
        movei   1,012                 ; cannot sleep in a native test
        popj    17,

        .data
        .globl proc_current_slot
proc_current_slot: .word 3
        .globl file_table
file_table: .word fdp_v1261
ctl_v1261: .word 0
        .word 0
fdp_v1261: .word 0
event_v1261: .word 0

        .bss
        .globl __test_exit
__test_exit: .block 1
