#!/usr/bin/env python3
"""Pin existing resident process images in a disposable F07 test only.

No allocator failure, MM descriptor, process state or backing block is
fabricated. The real mm_pin/mm_unpin code is used, and every pin newly
owned by the fixture is tracked for exact release. Requires an already
injected v1323 test-only BRK hook; never edit the production checkout.
"""

from pathlib import Path
import sys


def inject(root):
    path = root / 'proc/syscall_dispatch_pdp6.s'
    text = path.read_text()
    compare = ('native_sys_brk:\n'
               '        caie    2,0777762            ; test-only pressure prepare')
    assert text.count(compare) == 1, 'expected disposable BRK hook'
    text = text.replace(compare,
                        'native_sys_brk:\n'
                        '        hrrz    0,2\n'
                        '        caie    0,0777762            ; LH carries excluded PID',
                        1)
    start = 'daimos_f07_prepare_v1204:\n'
    end = '\n        .bss\n        .globl daimos_f07_count_v1204\n'
    assert text.count(start) == 1 and text.count(end) == 1
    prefix, tail = text.split(start, 1)
    _, suffix = tail.split(end, 1)
    body = '''daimos_f07_prepare_v1204:
        ; Original held-provider stage; test INIT owns this request.
        skipn   daimos_f07_count_v1204
        jrst    daimos_f07_pin_lease_v1326
        jrst    daimos_f07_bad_v1204
daimos_f07_pin_lease_v1326:
        move    6,fs_provider_ready
        camn    6,[7,,0]
        jrst    daimos_f07_pin_owner_v1326
        jrst    daimos_f07_bad_v1204
daimos_f07_pin_owner_v1326:
        skipn   daimos_test_holder_enter_v1150
        jrst    daimos_f07_bad_v1204
        skipn   daimos_test_predispatch_v1150
        jrst    daimos_f07_bad_v1204
        ; The high half of test-only BRK names the OOM requester.
        ; It must be able to terminate independently of this fixture.
        hlrz    6,2
        jumpe   6,daimos_f07_bad_v1204
        caml    6,proc_high_slot
        jrst    daimos_f07_bad_v1204
        camn    6,proc_current_slot
        jrst    daimos_f07_bad_v1204
        push    17,010
        push    17,011
        push    17,012
        push    17,013
        push    17,014
        move    014,6                ; excluded requester slot
        movei   010,1                ; process slot, never slot zero
        move    011,proc_table
        addi    011,3
daimos_f07_pin_next_v1326:
        caml    010,proc_high_slot
        jrst    daimos_f07_pin_done_v1326
        camn    010,014
        jrst    daimos_f07_pin_skip_v1326
        move    6,(011)
        trnn    6,0400000           ; stable UAREA descriptor
        jrst    daimos_f07_pin_skip_v1326
        trne    6,0200000           ; live transition is ineligible
        jrst    daimos_f07_pin_skip_v1326
        hrrz    013,1(011)          ; real resident MM base
        jumpe   013,daimos_f07_pin_skip_v1326
        move    1,013
        pushj   17,mm_is_pinned
        jumpn   1,daimos_f07_pin_skip_v1326
        move    1,013
        pushj   17,mm_pin
        jumpn   1,daimos_f07_pin_fail_v1326
        move    1,daimos_f07_count_v1204
        caige   1,0100              ; 64-entry inherited test array
        jrst    daimos_f07_pin_record_v1326
        jrst    daimos_f07_pin_fail_v1326
daimos_f07_pin_record_v1326:
        movem   013,daimos_f07_bases_v1204(1)
        aos     daimos_f07_count_v1204
daimos_f07_pin_skip_v1326:
        addi    011,3
        aoja    010,daimos_f07_pin_next_v1326
daimos_f07_pin_done_v1326:
        move    1,daimos_f07_count_v1204
        caige   1,2                 ; require independent residents
        jrst    daimos_f07_pin_fail_v1326
        movem   1,daimos_f07_prepared_v1204
        setz    1,
        jrst    daimos_f07_pin_restore_v1326
daimos_f07_pin_fail_v1326:
        setom   daimos_f07_error_v1204
        pushj   17,daimos_f07_cleanup_v1204
        seto    1,
daimos_f07_pin_restore_v1326:
        pop     17,014
        pop     17,013
        pop     17,012
        pop     17,011
        pop     17,010
        popj    17,

daimos_f07_release_v1204:
        skipg   daimos_f07_prepared_v1204
        jrst    daimos_f07_bad_v1204
        push    17,010
        pushj   17,daimos_f07_cleanup_v1204
        pop     17,010
        popj    17,

; Reverse exact temporary pins before the owning processes can exit.
; Never forget a base when mm_unpin reports an unexpected failure.
daimos_f07_cleanup_v1204:
        push    17,010
        move    010,daimos_f07_count_v1204
daimos_f07_cleanup_next_v1326:
        jumpe   010,daimos_f07_cleanup_done_v1326
        soj     010,
        move    1,daimos_f07_bases_v1204(010)
        pushj   17,mm_unpin
        jumpn   1,daimos_f07_cleanup_fail_v1326
        setzm   daimos_f07_bases_v1204(010)
        movem   010,daimos_f07_count_v1204
        aos     daimos_f07_freed_v1204
        jrst    daimos_f07_cleanup_next_v1326
daimos_f07_cleanup_fail_v1326:
        setom   daimos_f07_error_v1204
        seto    1,
        pop     17,010
        popj    17,
daimos_f07_cleanup_done_v1326:
        setz    1,
        pop     17,010
        popj    17,

daimos_f07_bad_v1204:
        setom   daimos_f07_error_v1204
        seto    1,
        popj    17,
'''
    text = prefix + body + end + suffix
    required = ('.globl mm_pin\n', '.globl mm_unpin\n',
                '.globl mm_is_pinned\n', '.globl proc_table\n',
                '.globl proc_high_slot\n',
                '.globl proc_current_slot\n')
    missing = ''.join(label for label in required if label not in text)
    if missing:
        text = missing + text
    assert text.count('daimos_f07_prepare_v1204:') == 1
    assert text.count('daimos_f07_release_v1204:') == 1
    assert text.count('daimos_f07_cleanup_v1204:') == 1
    path.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1326.py DISPOSABLE-KERNEL-ROOT')
    inject(Path(sys.argv[1]))
