#!/usr/bin/env python3
"""Synchronize F07 spinner TERM with five real scheduled sleeps.

The v1343 independent release occurs before the old INIT-triggered
provider release. On a fast completion INIT can TERM the spinner after
only four observed sleeps. This disposable-only observer requires the
unchanged original v1150 >=5 threshold through actual user scheduling.
No kernel MM/PI6/provider behavior or counter value is modified.
"""

from pathlib import Path
import sys


def inject(root, guest):
    path = root / 'proc/syscall_dispatch_pdp6.s'
    source = path.read_text()
    anchor = '''daimos_f07_normal_v1204:
        move    1,2
        pushj   17,vm_space_brk_current'''
    if source.count(anchor) != 1:
        raise ValueError('v1348 original test-only BRK fallback moved')
    replacement = '''daimos_f07_normal_v1204:
        caie    2,0777755         ; test-only read spinner progress
        jrst    daimos_f07_original_brk_v1348
        move    0,proc_current_slot
        caie    0,1               ; INIT alone observes the counter
        jrst    kret_neg1
        move    1,daimos_test_spinner_v1150
        popj    17,
daimos_f07_original_brk_v1348:
        move    1,2
        pushj   17,vm_space_brk_current'''
    source = source.replace(anchor, replacement, 1)
    source = '        .globl daimos_test_spinner_v1150\n' + source
    path.write_text(source)

    text = guest.read_text()
    anchor = '''        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
                SYS_EVENT_ARG((unsigned int)spinner, SYS_EVENT_TERM)) != 0)
                fail('q');'''
    if text.count(anchor) != 1:
        raise ValueError('v1348 original spinner TERM/WAIT moved')
    replacement = '''        /* v1348 disposable guest only: the v1343 independent provider
         * release can let INIT reach TERM before the historical v1150
         * five-sleep witness. Poll only the original source-linked
         * counter, and allow the real scheduled spinner to execute
         * enough SLEEP syscalls. Never fake the counter or bypass
         * the strict postflight threshold. */
        for (probe = 0U; probe < 01000U; ++probe) {
                word = dsys_brk(0777755UL);
                if (word >= 5UL && word < 0100000UL)
                        break;
                if (dsys_sleep(010U) != 0)
                        fail('p');
        }
        if (probe == 01000U)
                fail('Y');
''' + anchor
    guest.write_text(text.replace(anchor, replacement, 1))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1348.py DISPOSABLE-KERNEL-ROOT GUEST-C')
    inject(Path(sys.argv[1]), Path(sys.argv[2]))
