#!/usr/bin/env python3
"""Observe genuine clean D6FS BCACHE during original LOGSTORE torn commit.

Instrument disposable KCORE cache words and the existing v1577
source-authentic LOGSTORE torn-record injector. No provider calls, MM
allocation, D6FS records, cache tags or physical I/O are synthesized.
"""

from pathlib import Path
import sys


def one(source, original, replacement, label):
    assert source.count(original) == 1, '%s source anchor changed' % label
    return source.replace(original, replacement, 1)


def instrument(root):
    cache = root / 'storage/bcache_pdp6.s'
    code = cache.read_text()
    labels = ('primed', 'nonzero', 'slab', 'key', 'physical',
              'failure_observed', 'retry_observed', 'failure_differences',
              'retry_differences', 'failure_hit', 'retry_hit',
              'failure_fetch_differences', 'retry_fetch_differences')
    storage = ('\n; v1590 disposable physical mixed-provider cache witnesses.\n'
               + ''.join('        .globl daimos_v1590_%s\n'
                         'daimos_v1590_%s: .block 1\n' % (name, name)
                         for name in labels))
    code = one(code,
               'bcache_workspace_tag: .block 1\n',
               'bcache_workspace_tag: .block 1\n' + storage,
               'original KCORE BCACHE layout')
    cache.write_text('        .globl bcache_state\n' + code)

    logstore = root / 'storage/logstore_runtime.s'
    code = logstore.read_text()
    before = ('        setom   daimos_test_logstore_faults_v1577\n'
              '        push    17,4                    ; preserve original user block\n')
    after = ('        setom   daimos_test_logstore_faults_v1577\n'
             '        pushj   17,daimos_v1590_capture_before\n'
             '        push    17,4                    ; preserve original user block\n')
    code = one(code, before, after, 'original first eligible torn commit')

    before = ('daimos_test_logstore_torn_error_v1577:\n'
              '        seto    1,                       ; completion-error witness\n')
    after = ('daimos_test_logstore_torn_error_v1577:\n'
             '        pushj   17,daimos_v1590_check_failure\n'
             '        seto    1,                       ; completion-error witness\n')
    code = one(code, before, after,
               'original post-physical-write logical refusal')

    before = ('        skipe   daimos_test_logstore_faults_v1577\n'
              '        jrst    logstore_write          ; allow normal physical retry\n')
    after = ('        skipe   daimos_test_logstore_faults_v1577\n'
             '        jrst    daimos_v1590_original_retry\n')
    code = one(code, before, after, 'same-slot original LOGSTORE retry')

    anchor = '; v1577 disposable physical-media fault. Only the test\'s two unique\n'
    helpers = '''; Observers preserve the caller-scratch record pointer (AC4)
; and all other live LOGSTORE arguments. Only actual original-cache
; ownership, tag and complete 128-word contents may satisfy the test.
daimos_v1590_original_retry:
        pushj   17,logstore_write
        jumpn   1,daimos_v1590_retry_done
        push    17,1
        pushj   17,daimos_v1590_check_retry
        pop     17,1
daimos_v1590_retry_done:
        popj    17,

daimos_v1590_capture_before:
        push    17,4
        push    17,5
        push    17,6
        push    17,7
        hrrz    4,bcache_state
        jumpe   4,daimos_v1590_capture_done
        movem   4,daimos_v1590_slab
        move    5,(4)
        camn    5,[-1]
        jrst    daimos_v1590_capture_done
        movem   5,daimos_v1590_key
        lsh     5,-030
        andi    5,07700
        caie    5,01000              ; genuine root D6FS source class
        jrst    daimos_v1590_capture_done
        movei   5,daimos_v1590_expected
        movei   6,1(4)
        hrl     5,6
        movei   6,daimos_v1590_expected+0177
        blt     5,(6)
        movei   7,0200
        movei   4,daimos_v1590_expected
daimos_v1590_nonzero_loop:
        skipn   (4)
        jrst    daimos_v1590_nonzero_next
        aos     daimos_v1590_nonzero
daimos_v1590_nonzero_next:
        aoj     4,
        sojg    7,daimos_v1590_nonzero_loop
        aos     daimos_v1590_primed
daimos_v1590_capture_done:
        pop     17,7
        pop     17,6
        pop     17,5
        pop     17,4
        popj    17,

daimos_v1590_check_failure:
        push    17,4
        push    17,5
        movei   4,daimos_v1590_failure_differences
        movei   5,daimos_v1590_failure_fetch_differences
        pushj   17,daimos_v1590_compare
        move    4,daimos_test_logstore_physical_v1577
        movem   4,daimos_v1590_physical
        aos     daimos_v1590_failure_observed
        pop     17,5
        pop     17,4
        popj    17,

daimos_v1590_check_retry:
        push    17,4
        push    17,5
        movei   4,daimos_v1590_retry_differences
        movei   5,daimos_v1590_retry_fetch_differences
        pushj   17,daimos_v1590_compare
        aos     daimos_v1590_retry_observed
        pop     17,5
        pop     17,4
        popj    17,

; AC4/5 point at original zero-initialized per-phase counters.
; Read the private cache WITHOUT touching the workspace tag. A fetch
; into a separate 128-word scratch must remain a clean private hit.
daimos_v1590_compare:
        push    17,1
        push    17,2
        push    17,3
        push    17,4
        push    17,5
        push    17,6
        push    17,7
        push    17,010
        push    17,011
        move    010,4
        move    011,5
        hrrz    4,bcache_state
        came    4,daimos_v1590_slab
        aos     (010)
        jumpe   4,daimos_v1590_compare_fetch
        move    5,(4)
        came    5,daimos_v1590_key
        aos     (010)
        movei   5,daimos_v1590_expected
        movei   6,1(4)
        movei   7,0200
daimos_v1590_compare_words:
        move    1,(5)
        camn    1,(6)
        jrst    daimos_v1590_compare_next
        aos     (010)
daimos_v1590_compare_next:
        aoj     5,
        aoj     6,
        sojg    7,daimos_v1590_compare_words
daimos_v1590_compare_fetch:
        move    1,daimos_v1590_key
        movei   2,daimos_v1590_readback
        pushj   17,bcache_fetch
        ; Logically separate two call sites, same original read-only ABI.
        movei   3,daimos_v1590_failure_fetch_differences
        came    011,3
        jrst    daimos_v1590_record_retry_hit
        movem   1,daimos_v1590_failure_hit
        jrst    daimos_v1590_fetch_compare
daimos_v1590_record_retry_hit:
        movem   1,daimos_v1590_retry_hit
daimos_v1590_fetch_compare:
        movei   5,daimos_v1590_expected
        movei   6,daimos_v1590_readback
        movei   7,0200
daimos_v1590_fetch_words:
        move    1,(5)
        camn    1,(6)
        jrst    daimos_v1590_fetch_next
        aos     (011)
daimos_v1590_fetch_next:
        aoj     5,
        aoj     6,
        sojg    7,daimos_v1590_fetch_words
        pop     17,011
        pop     17,010
        pop     17,7
        pop     17,6
        pop     17,5
        pop     17,4
        pop     17,3
        pop     17,2
        pop     17,1
        popj    17,

'''
    code = one(code, anchor, helpers + anchor, 'original LOGSTORE helpers')
    code += '''\n; v1590 test-only LOGSTORE MRES data; no installed RAM.
        .globl daimos_v1590_expected
daimos_v1590_expected: .block 0200
        .globl daimos_v1590_readback
daimos_v1590_readback: .block 0200
'''
    header = ('        .globl bcache_state\n'
              '        .globl bcache_fetch\n'
              '        .globl daimos_test_logstore_physical_v1577\n'
              + ''.join('        .globl daimos_v1590_%s\n' % name
                        for name in labels))
    logstore.write_text(header + code)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: daimos-p1c-live-cache-logfault-v1590.py KERNEL')
    instrument(Path(sys.argv[1]))
    print('v1590: real physical LOGSTORE fault/retry while D6FS cache valid')
