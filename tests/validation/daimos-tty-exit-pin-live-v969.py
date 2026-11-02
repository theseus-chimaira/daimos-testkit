#!/usr/bin/env python3
"""Instrument only a copied PDP-6 kernel to exercise last-session TTY release."""
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()

def patch(old, new):
    global s
    assert s.count(old) == 1, 'nonunique v969 injection anchor'
    s = s.replace(old, new, 1)

patch('''proc_session_teardown_commit_v875:
        ; No member can have an unclosed FD after successful HUP.''',
'''proc_session_teardown_commit_v875:
        ; Inject one MM pin on the real final-session exit path.
        aos     daimos_test_pin_entry_v969
        skipn   daimos_test_pin_armed_v969
        jrst    daimos_test_pin_skip_v969
        setzm   daimos_test_pin_armed_v969
        aos     daimos_test_pin_matched_v969
        move    1,013
        pushj   17,proc_tty_line_ensure
        jumpe   1,daimos_test_pin_error_v969
        movem   1,daimos_test_pin_base_v969
        pushj   17,mm_pin
        jumpn   1,daimos_test_pin_error_v969
        aos     daimos_test_pin_attempt_v969
        jrst    daimos_test_pin_skip_v969
daimos_test_pin_error_v969:
        setom   daimos_test_pin_error_word_v969
daimos_test_pin_skip_v969:
        ; No member can have an unclosed FD after successful HUP.''')

patch('''proc_exit_current:
        move    3,1                    ; preserve low 18-bit exit status''',
'''proc_exit_current:
        ; Arm only on the actual INIT EXIT, not earlier TTY detach.
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_arm_skip_v969
        setom   daimos_test_pin_armed_v969
daimos_test_arm_skip_v969:
        move    3,1                    ; preserve low 18-bit exit status''')

patch('''proc_exit_release_failed:
        ; A failed release is not the normal last-process shutdown.''',
'''proc_exit_release_failed:
        ; The first release must fail before VM/TTY ownership is retired.
        move    1,daimos_test_pin_attempt_v969
        caie    1,1
        jrst    daimos_test_retry_error_v969
        move    1,proc_tty_records
        andi    1,0377
        caie    1,1
        jrst    daimos_test_retry_error_v969
        aos     daimos_test_pin_retained_v969
        movei   1,0
        pushj   17,proc_tty_line_base_get
        camn    1,daimos_test_pin_base_v969
        jrst    daimos_test_retry_base_ok_v969
        jrst    daimos_test_retry_error_v969
daimos_test_retry_base_ok_v969:
        pushj   17,mm_unpin
        jumpn   1,daimos_test_retry_error_v969
        movei   1,1
        setz    2,
        pushj   17,proc_finish_slot_owner_v932
        jumpn   1,daimos_test_retry_error_v969
        move    1,proc_tty_records
        andi    1,0377
        jumpn   1,daimos_test_retry_error_v969
        movei   1,0
        pushj   17,proc_tty_line_base_get
        jumpn   1,daimos_test_retry_error_v969
        aos     daimos_test_pin_retried_v969
        jrst    proc_exit_halt
daimos_test_retry_error_v969:
        setom   daimos_test_pin_error_word_v969
        jrst    proc_exit_halt
        ; A failed release is not the normal last-process shutdown.''')

s += '''
        .bss
        .globl daimos_test_pin_armed_v969
daimos_test_pin_armed_v969: .block 1
        .globl daimos_test_pin_base_v969
daimos_test_pin_base_v969: .block 1
        .globl daimos_test_pin_attempt_v969
daimos_test_pin_attempt_v969: .block 1
        .globl daimos_test_pin_matched_v969
daimos_test_pin_matched_v969: .block 1
        .globl daimos_test_pin_entry_v969
daimos_test_pin_entry_v969: .block 1
        .globl daimos_test_pin_retained_v969
daimos_test_pin_retained_v969: .block 1
        .globl daimos_test_pin_retried_v969
daimos_test_pin_retried_v969: .block 1
        .globl daimos_test_pin_error_word_v969
daimos_test_pin_error_word_v969: .block 1
'''
p.write_text(s)
