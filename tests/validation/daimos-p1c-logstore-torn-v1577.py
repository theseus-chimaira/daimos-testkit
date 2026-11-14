#!/usr/bin/env python3
"""Inject one physical, uncommitted LOGSTORE record per cold boot.

Modify only a disposable copy of the real production LOGSTORE MRES.
The injection writes the *entire* physical backing block with its
commit trailer cleared, then returns an I/O error to the original
logstore_append caller. No synthetic write is counted as physical.
"""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: daimos-p1c-logstore-torn-v1577.py INPUT OUTPUT')

src = Path(sys.argv[1]).read_text()
old = ('        pushj   17,logstore_write\n'
       '        jumpn   1,logstore_append_done\n')
assert src.count(old) == 1, 'production LOGSTORE append site changed'
src = src.replace(old, ('        pushj   17,daimos_test_logstore_torn_v1577\n'
                        '        jumpn   1,logstore_append_done\n'), 1)

anchor = '        .bss\nlogstore_mres_state:\n'
assert src.count(anchor) == 1, 'production LOGSTORE BSS layout changed'
hook = '''; v1577 disposable physical-media fault. Only the test's two unique
; event codes are eligible, and only the FIRST attempt per cold boot.
; Real LOGSTORE direct/blockset backing write remains unchanged.
; On that first attempt, physically write a record with its commit
; trailer zero, restore the caller scratch, and report failure.
; The production cursor must NOT advance, and retry must re-write
; the same slot with a valid committed record.
daimos_test_logstore_torn_v1577:
        move    0,4(4)                  ; event code in caller record
        caie    0,0157601
        jrst    daimos_test_logstore_other_v1577
        jrst    daimos_test_logstore_marker_v1577
daimos_test_logstore_other_v1577:
        caie    0,0157602
        jrst    logstore_write          ; unrelated system log event
daimos_test_logstore_marker_v1577:
        skipe   daimos_test_logstore_faults_v1577
        jrst    logstore_write          ; allow normal physical retry
        setom   daimos_test_logstore_faults_v1577
        push    17,4                    ; preserve original user block
        move    0,0177(4)
        push    17,0                    ; save original commit trailer
        setzm   0177(4)                 ; physically uncommitted record
        pushj   17,logstore_write      ; genuine Type-236 DMA operation
        pop     17,0
        pop     17,4
        movem   0,0177(4)               ; restore caller scratch
        jumpn   1,daimos_test_logstore_torn_error_v1577
        aos     daimos_test_logstore_physical_v1577
daimos_test_logstore_torn_error_v1577:
        seto    1,                       ; completion-error witness
        popj    17,

'''
src = src.replace(anchor, hook + anchor, 1)
src += '''\n; v1577 test-only optional-MRES counters; no permanent KCORE RAM.
        .globl daimos_test_logstore_faults_v1577
        .globl daimos_test_logstore_physical_v1577
daimos_test_logstore_faults_v1577: .block 1
daimos_test_logstore_physical_v1577: .block 1
'''
Path(sys.argv[2]).write_text(src)
print('v1577: physical uncommitted LOGSTORE MRES injection installed')
