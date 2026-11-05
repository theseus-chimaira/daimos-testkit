#!/usr/bin/env python3
"""E07: witness clock and separate user progress over DISK retry.

Only the copied v1122 PDP-6 kernel is modified. The DISK bitmap
fault, real verifier, and slot-0 recovery remain production code.
"""

from pathlib import Path
import sys

root = Path(sys.argv[1])


def patch(path, before, after):
    source = path.read_text()
    assert source.count(before) == 1, ('v1154 anchor', str(path), before)
    path.write_text(source.replace(before, after, 1))


# The real DISK allocation verifier is called twice: the first call
# is refused with the deliberately corrupted bit, the second commits.
# Record the actual PI6 clock at both boundaries without advancing it.
backstore = root / 'storage/backstore.s'
patch(backstore, '        aos     daimos_test_swap_verify_v1107\n',
      '''        aos     daimos_test_swap_verify_v1107
        move    0,daimos_test_swap_verify_v1107
        caie    0,1
        jrst    daimos_pi6_swap_second_v1154
        move    0,proc_timer_clock
        movem   0,daimos_pi6_swap_first_v1154
        move    0,daimos_pi6_user_sleeps_v1154
        movem   0,daimos_pi6_user_first_v1154
        jrst    daimos_pi6_swap_resume_v1154
daimos_pi6_swap_second_v1154:
        move    0,proc_timer_clock
        movem   0,daimos_pi6_swap_last_v1154
        move    0,daimos_pi6_user_sleeps_v1154
        movem   0,daimos_pi6_user_last_v1154
daimos_pi6_swap_resume_v1154:
''')
source = backstore.read_text()
backstore.write_text('''        .globl proc_timer_clock
        .globl daimos_pi6_swap_first_v1154
        .globl daimos_pi6_swap_last_v1154
        .globl daimos_pi6_user_sleeps_v1154
        .globl daimos_pi6_user_first_v1154
        .globl daimos_pi6_user_last_v1154
''' + source)


proc = root / 'proc/proc_pdp6.s'
patch(proc, '''proc_sleep_ticks:
        hrrz    1,1''',
      '''proc_sleep_ticks:
        move    0,proc_current_slot
        caie    0,5                   ; unrelated independent sleeper
        jrst    daimos_pi6_sleep_other_v1154
        skipn   daimos_test_swap_verify_v1107
        jrst    daimos_pi6_sleep_other_v1154
        move    0,daimos_test_swap_verify_v1107
        caige   0,2                   ; only while DISK retry is pending
        aos     daimos_pi6_user_sleeps_v1154
daimos_pi6_sleep_other_v1154:
        hrrz    1,1''')
source = proc.read_text()
assert source.count('proc_timer_clock:\n        .block 1\n') == 1
proc.write_text('''        .globl daimos_test_swap_verify_v1107
        .globl proc_timer_clock
''' + source + '''
        .bss
        .globl daimos_pi6_swap_first_v1154
daimos_pi6_swap_first_v1154: .block 1
        .globl daimos_pi6_swap_last_v1154
daimos_pi6_swap_last_v1154: .block 1
        .globl daimos_pi6_user_sleeps_v1154
daimos_pi6_user_sleeps_v1154: .block 1
        .globl daimos_pi6_user_first_v1154
daimos_pi6_user_first_v1154: .block 1
        .globl daimos_pi6_user_last_v1154
daimos_pi6_user_last_v1154: .block 1
''')
