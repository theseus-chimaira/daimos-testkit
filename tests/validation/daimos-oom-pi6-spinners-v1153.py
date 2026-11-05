#!/usr/bin/env python3
"""E07: observe real PI6 and user progress across mixed MM failures.

Only the disposable v1144 kernel is instrumented. The actual MM
refusals, private FS provider wait, and physical release paths are
unchanged; no synthetic clock advances or return codes are inserted.
"""

from pathlib import Path
import sys

root = Path(sys.argv[1])
mm = root / 'mm/mm_pdp6.s'
proc = root / 'proc/proc_pdp6.s'


def patch(path, old, new):
    content = path.read_text()
    assert content.count(old) == 1, ('v1153: invalid instrumentation anchor', old)
    path.write_text(content.replace(old, new, 1))


# Pipe MM_BUSY is the first of four genuinely pinned resource failures
# in the combined guest. Capture the real qualified clock and independent
# sleeper count on that first fault, not on an unrelated MM free.
patch(mm, '        aos     daimos_pipe_busy_v1144\n', '''        aos     daimos_pipe_busy_v1144
        skipn   daimos_pipe_busy_v1144
        jrst    daimos_pi6_other_busy_v1153
        skipn   daimos_pi6_first_tick_v1153
        jrst    daimos_pi6_capture_first_v1153
        jrst    daimos_pi6_other_busy_v1153
daimos_pi6_capture_first_v1153:
        move    0,proc_timer_clock
        movem   0,daimos_pi6_first_tick_v1153
        move    0,daimos_test_bystander_v924
        movem   0,daimos_pi6_first_user_v1153
daimos_pi6_other_busy_v1153:
''')
source = mm.read_text()
mm.write_text('''        .globl proc_timer_clock
        .globl daimos_test_bystander_v924
        .globl daimos_pi6_first_tick_v1153
        .globl daimos_pi6_first_user_v1153
''' + source)


# The already-tested slot-5 publication witness fires once, strictly
# after PIPE/DPY/VM/u-area release, giving an exact endpoint.
patch(proc, '        aos     daimos_publish_checks_v1144\n',
      '''        aos     daimos_publish_checks_v1144
        move    0,proc_timer_clock
        movem   0,daimos_pi6_final_tick_v1153
        move    0,daimos_test_bystander_v924
        movem   0,daimos_pi6_final_user_v1153
''')
source = proc.read_text()
assert source.count('proc_timer_clock:\n        .block 1\n') == 1
proc.write_text('''        .globl proc_timer_clock
''' + source + '''
        .bss
        .globl daimos_pi6_first_tick_v1153
daimos_pi6_first_tick_v1153: .block 1
        .globl daimos_pi6_final_tick_v1153
daimos_pi6_final_tick_v1153: .block 1
        .globl daimos_pi6_first_user_v1153
daimos_pi6_first_user_v1153: .block 1
        .globl daimos_pi6_final_user_v1153
daimos_pi6_final_user_v1153: .block 1
''')
