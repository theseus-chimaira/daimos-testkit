#!/usr/bin/env python3
"""Instrument only a copied PDP-6 kernel to exercise last-session TTY release."""
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
physical_chain = len(sys.argv) > 2 and sys.argv[2] == '1'
pi6_owner = len(sys.argv) > 3 and sys.argv[3] == '1'
if pi6_owner and not physical_chain:
    raise SystemExit('v1147: physical TTY/VM/u-area mode required')

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
        ; The prior session teardown may already have detached TTY0.
        ; Restore a genuine test-owned session before allocating its
        ; pinned line: a detached TTY is not an owner-retention case.
        move    4,proc_tty_records(013)
        andcmi  4,0377
        move    5,010
        andi    5,0377
        ior     4,5
        movem   4,proc_tty_records(013)
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

# Arm the physical TTY test at the owner-side HUP preflight. v991
# moved this BEFORE proc_exit_current; the old v969 late arm is no
# longer a usable canonical-buffer refusal trigger. This common hook
# covers both the single-resource v969 and chained v1124 guests.
patch('''proc_session_teardown:
        push    17,010''',
    '''proc_session_teardown:
        move    4,proc_current_slot
        caie    4,1                   ; only the original INIT session
        jrst    daimos_test_tty_normal_v1124
        skipn   daimos_test_pin_attempt_v969
        jrst    daimos_test_tty_arm_v1124
        skipn   daimos_test_pin_retried_v969
        jrst    daimos_test_tty_retry_v1124
        jrst    daimos_test_tty_normal_v1124
daimos_test_tty_arm_v1124:
        setom   daimos_test_pin_armed_v969
        jrst    daimos_test_tty_normal_v1124
daimos_test_tty_retry_v1124:
        ; The first EXIT returned -1 without changing the session.
        push    17,1
        push    17,2
        move    4,proc_tty_records
        andi    4,0377
        caie    4,1
        jrst    daimos_test_tty_bad_v1124
        movei   1,0
        pushj   17,proc_tty_line_base_get
        camn    1,daimos_test_pin_base_v969
        jrst    daimos_test_tty_retain_v1124
        jrst    daimos_test_tty_bad_v1124
daimos_test_tty_retain_v1124:
        aos     daimos_test_pin_retained_v969
        pushj   17,mm_unpin
        jumpn   1,daimos_test_tty_bad_v1124
        aos     daimos_test_pin_retried_v969
        jrst    daimos_test_tty_finish_v1124
daimos_test_tty_bad_v1124:
        setom   daimos_test_pin_error_word_v969
daimos_test_tty_finish_v1124:
        pop     17,2
        pop     17,1
daimos_test_tty_normal_v1124:
        push    17,010''')

if physical_chain:
    # All VM and u-area recovery is performed by the real clock-driven
    # PREVM/POSTVM finalizer, never by a manual EXIT retry.
    # Observe only the production allocator's physical BUSY branch.
    # Compare against the actual bases recorded at allocation/pin.
    mm = Path(sys.argv[1]).parent.parent / 'mm/mm_pdp6.s'
    ms = mm.read_text()
    old = '''mm_free_busy:
        movni   1,5'''
    new = '''mm_free_busy:
        move    4,daimos_test_pin_base_v969
        camn    4,5
        aos     daimos_test_tty_busy_v1124
        move    4,daimos_test_vm_base_v1124
        camn    4,5
        aos     daimos_test_vm_busy_v1124
        move    4,daimos_test_uarea_base_v1124
        camn    4,5
        aos     daimos_test_uarea_busy_v1124
        movni   1,5'''
    assert ms.count(old) == 1, 'v1124: nonunique real MM_BUSY branch'
    ms = ms.replace(old, new, 1)
    if pi6_owner:
        # Record the actual qualified PI6 clock at each physical MM_BUSY
        # path. No synthetic timer increment or retry result is allowed.
        for owner, counter in (('pin', 'tty'), ('vm', 'vm'),
                               ('uarea', 'uarea')):
            marker = ('        aos     daimos_test_%s_busy_v1124\n' %
                      ('tty' if owner == 'pin' else owner))
            assert ms.count(marker) == 1, ('v1147: busy hook', marker)
            ms = ms.replace(
                marker,
                marker + '        move    6,proc_timer_clock\n'
                '        movem   6,daimos_test_tick_%s_v1147\n' % counter,
                1)
        ms = ('''        .globl proc_timer_clock
        .globl daimos_test_tick_tty_v1147
        .globl daimos_test_tick_vm_v1147
        .globl daimos_test_tick_uarea_v1147
''' + ms)
    ms = '''        .globl daimos_test_pin_base_v969
        .globl daimos_test_vm_base_v1124
        .globl daimos_test_uarea_base_v1124
        .globl daimos_test_tty_busy_v1124
        .globl daimos_test_vm_busy_v1124
        .globl daimos_test_uarea_busy_v1124
''' + ms
    mm.write_text(ms)

    s += '''
        .bss
        .globl daimos_test_tty_busy_v1124
daimos_test_tty_busy_v1124: .block 1
        .globl daimos_test_vm_busy_v1124
daimos_test_vm_busy_v1124: .block 1
        .globl daimos_test_vm_base_v1124
daimos_test_vm_base_v1124: .block 1
        .globl daimos_test_vm_pin_v1124
daimos_test_vm_pin_v1124: .block 1
        .globl daimos_test_vm_retained_v1124
daimos_test_vm_retained_v1124: .block 1
        .globl daimos_test_vm_unpin_v1124
daimos_test_vm_unpin_v1124: .block 1
        .globl daimos_test_vm_destroyed_v1124
daimos_test_vm_destroyed_v1124: .block 1
        .globl daimos_test_uarea_base_v1124
daimos_test_uarea_base_v1124: .block 1
        .globl daimos_test_uarea_busy_v1124
daimos_test_uarea_busy_v1124: .block 1
        .globl daimos_test_uarea_pin_v1124
daimos_test_uarea_pin_v1124: .block 1
        .globl daimos_test_uarea_retained_count_v1124
daimos_test_uarea_retained_count_v1124: .block 1
        .globl daimos_test_uarea_unpin_v1124
daimos_test_uarea_unpin_v1124: .block 1
        .globl daimos_test_final_v1124
daimos_test_final_v1124: .block 1
'''

    # v991 moved HUP preflight BEFORE proc_exit_current. The original
    # v969 arm point is therefore too late on modern DAIMOS. Exercise
    # the real current-process EXIT syscall, including its first -1
    # return and a fresh user-issued retry, rather than reattaching
    # TTY only after that preflight has already completed.
    patch('''proc_exit_current:
        ; Arm only on the actual INIT EXIT, not earlier TTY detach.
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_arm_skip_v969
        setom   daimos_test_pin_armed_v969
daimos_test_arm_skip_v969:
        move    3,1                    ; preserve low 18-bit exit status''',
    '''proc_exit_current:
        ; Owner-side HUP has now succeeded on the SECOND user EXIT.
        ; The normal finalizer is about to destroy this exact VM.
        move    4,proc_current_slot
        caie    4,1
        jrst    daimos_test_vm_arm_done_v1124
        push    17,1
        move    4,proc_table
        addi    4,PROC_WORDS
        move    1,1(4)
        hrrz    1,1
        jumpe   1,daimos_test_vm_arm_bad_v1124
        movem   1,daimos_test_vm_base_v1124
        pushj   17,mm_pin
        jumpn   1,daimos_test_vm_arm_bad_v1124
        aos     daimos_test_vm_pin_v1124
        jrst    daimos_test_vm_arm_finish_v1124
daimos_test_vm_arm_bad_v1124:
        setom   daimos_test_pin_error_word_v969
daimos_test_vm_arm_finish_v1124:
        pop     17,1
daimos_test_vm_arm_done_v1124:
        move    3,1                    ; preserve low 18-bit exit status''')

    # A synchronous terminal failure would bypass the real retry clock.
    # Mark it as a failed test; expected recovery runs in slot zero.
    start = s.index('proc_exit_release_failed:\n')
    end = s.index(
        '        ; A failed release is not the normal last-process shutdown.',
        start)
    s = s[:start] + '''proc_exit_release_failed:
        setom   daimos_test_pin_error_word_v969
        halt    1
        jrst    .-1
''' + s[end:]

    # The VM refusal is handled by the real clock-driven slot-0 PREVM
    # reaper, not by proc_exit_release_failed. Release the first pin
    # at the next *actual* service entry, then pin the still-owned
    # u-area so the next real MM free fails at POSTVM instead. These
    # hooks make no synthetic allocator or service return codes.
    patch('''proc_finish_service_v881:
        push    17,10''',
    '''proc_finish_service_v881:
        skipn   daimos_test_vm_busy_v1124
        jrst    daimos_test_service_normal_v1124
        skipn   daimos_test_vm_unpin_v1124
        jrst    daimos_test_service_vm_v1124
        skipn   daimos_test_uarea_busy_v1124
        jrst    daimos_test_service_normal_v1124
        skipn   daimos_test_uarea_unpin_v1124
        jrst    daimos_test_service_uarea_v1124
        jrst    daimos_test_service_normal_v1124
daimos_test_service_vm_v1124:
        ; VM is still published; the process is quarantined in PREVM.
        move    4,proc_table
        addi    4,PROC_WORDS
        move    5,1(4)
        camn    5,[-1]
        jrst    daimos_test_service_bad_v1124
        aos     daimos_test_vm_retained_v1124
        move    1,daimos_test_vm_base_v1124
        pushj   17,mm_unpin
        jumpn   1,daimos_test_service_bad_v1124
        aos     daimos_test_vm_unpin_v1124
        ; This exact u-area must survive until after VM deletion.
        move    4,proc_table
        addi    4,PROC_WORDS
        hlrz    1,(4)
        jumpe   1,daimos_test_service_bad_v1124
        movem   1,daimos_test_uarea_base_v1124
        pushj   17,mm_pin
        jumpn   1,daimos_test_service_bad_v1124
        aos     daimos_test_uarea_pin_v1124
        jrst    daimos_test_service_normal_v1124
daimos_test_service_uarea_v1124:
        ; VM must now be NONE, but u-area cannot be reaped until
        ; its own exact physical MM_BUSY has been resolved.
        move    4,proc_table
        addi    4,PROC_WORDS
        move    5,1(4)
        camn    5,[-1]
        jrst    daimos_test_service_vm_none_v1124
        jrst    daimos_test_service_bad_v1124
daimos_test_service_vm_none_v1124:
        aos     daimos_test_vm_destroyed_v1124
        hlrz    5,(4)
        camn    5,daimos_test_uarea_base_v1124
        jrst    daimos_test_service_uarea_owned_v1124
        jrst    daimos_test_service_bad_v1124
daimos_test_service_uarea_owned_v1124:
        aos     daimos_test_uarea_retained_count_v1124
        move    1,daimos_test_uarea_base_v1124
        pushj   17,mm_unpin
        jumpn   1,daimos_test_service_bad_v1124
        aos     daimos_test_uarea_unpin_v1124
        jrst    daimos_test_service_normal_v1124
daimos_test_service_bad_v1124:
        setom   daimos_test_pin_error_word_v969
daimos_test_service_normal_v1124:
        push    17,10''')

    # Halt only after the real slot-0 retry has committed and the
    # terminal descriptor, TTY session and canonical base are empty.
    patch('''proc_finish_service_result_v892:
        jumpn   1,proc_finish_service_failed_v1102''',
    '''proc_finish_service_result_v892:
        caie    10,1
        jrst    daimos_test_service_result_normal_v1124
        jumpn   1,daimos_test_service_result_normal_v1124
        skipn   daimos_test_uarea_unpin_v1124
        jrst    daimos_test_service_result_normal_v1124
        move    4,proc_table
        addi    4,PROC_WORDS
        hlrz    5,(4)
        jumpn   5,daimos_test_service_result_bad_v1124
        move    4,proc_tty_records
        andi    4,0377
        jumpn   4,daimos_test_service_result_bad_v1124
        movei   1,0
        pushj   17,proc_tty_line_base_get
        jumpn   1,daimos_test_service_result_bad_v1124
        aos     daimos_test_final_v1124
        halt
        jrst    .-1
daimos_test_service_result_bad_v1124:
        setom   daimos_test_pin_error_word_v969
        halt    1
        jrst    .-1
daimos_test_service_result_normal_v1124:
        jumpn   1,proc_finish_service_failed_v1102''')

    if pi6_owner:
        # Save the final clock after the real slot-0 finalizer commits.
        # The analysis verifies this is later than the MM refusal phases.
        patch('''        aos     daimos_test_final_v1124
        halt''',
              '''        aos     daimos_test_final_v1124
        move    6,proc_timer_clock
        movem   6,daimos_test_tick_final_v1147
        halt''')

        # After a genuine TTY MM_BUSY, count sleeping syscalls from an
        # unrelated, runnable non-INIT user. That process has already
        # acknowledged NEWSESSION; no other child remains from setup.
        # No kernel counter is advanced by a synthetic clock tick.
        patch('''proc_sleep_ticks:
        hrrz    1,1''',
              '''proc_sleep_ticks:
        move    4,proc_current_slot
        jumpe   4,daimos_pi6_sleep_original_v1147
        caie    4,1
        jrst    daimos_pi6_sleep_other_v1147
        jrst    daimos_pi6_sleep_original_v1147
daimos_pi6_sleep_other_v1147:
        skipn   daimos_test_tty_busy_v1124
        jrst    daimos_pi6_sleep_original_v1147
        aos     daimos_test_bystander_sleeps_v1147
daimos_pi6_sleep_original_v1147:
        hrrz    1,1''')

        s += '''
        .bss
        .globl daimos_test_tick_tty_v1147
daimos_test_tick_tty_v1147: .block 1
        .globl daimos_test_tick_vm_v1147
daimos_test_tick_vm_v1147: .block 1
        .globl daimos_test_tick_uarea_v1147
daimos_test_tick_uarea_v1147: .block 1
        .globl daimos_test_tick_final_v1147
daimos_test_tick_final_v1147: .block 1
        .globl daimos_test_bystander_sleeps_v1147
daimos_test_bystander_sleeps_v1147: .block 1
'''

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
