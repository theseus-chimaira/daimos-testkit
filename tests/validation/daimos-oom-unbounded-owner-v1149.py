#!/usr/bin/env python3
"""B07: an OOM-relevant busy owner has no forced-reclamation deadline.

This checks the current extracted PDP-6 owner, provider and slot-0
paths. A retry interval may saturate, but the retry lifetime does not.
The native v885/v1102 tests separately execute the real instructions.
"""

import os
import re
from pathlib import Path

root = Path(os.environ['DAIMOS_REPO']) / 'system/kernel'
proc = (root / 'proc/proc_pdp6.s').read_text()
provider = (root / 'fs/fs_mres.s').read_text()


def section(source, begin, end):
    assert source.count(begin) == 1, ('missing/duplicate start', begin)
    part = source.split(begin, 1)[1]
    assert end in part, ('missing end', end)
    return part.split(end, 1)[0]


def code(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return '\n'.join(line.split(';', 1)[0] for line in text.splitlines())


def required(text, *instructions):
    for ins in instructions:
        assert ins in text, ('missing safety instruction', ins)


def forbidden(text, *symbols):
    for symbol in symbols:
        assert not re.search(r'\b' + re.escape(symbol) + r'\b', text), (
            'unexpected forced release operation', symbol)


def audit(p, f):
    owner = code(section(p, 'proc_fatal_close_current_v879:',
                         'proc_fatal_close_no_owner_v879:'))
    retry = owner.split('proc_fatal_close_retry_v879:', 1)[1].split(
        'proc_fatal_close_done_v879:', 1)[0]
    required(retry,
             'pushj   17,file_close_all',
             'jumpn   1,proc_fatal_close_wait_v995',
             'pushj   17,proc_session_teardown',
             'jumpe   1,proc_fatal_close_done_v879',
             'pushj   17,proc_sleep_ticks',
             'jumpn   1,proc_fatal_close_sleep_fail_v885',
             'caige   1,01000',
             'lsh     1,1',
             'movem   1,(17)',
             'jrst    proc_fatal_close_retry_v879')
    forbidden(retry, 'mm_free', 'proc_slot_discard', 'proc_finish_slot',
              'vm_space_destroy', 'fs_provider_unlock', 'proc_exit_current')
    done = owner.split('proc_fatal_close_done_v879:', 1)[1]
    required(done, 'pop     17,2', 'pop     17,1',
             'jrst    proc_exit_current')

    remote = code(section(p, 'proc_event_fatal_other_defer_term_v926:',
                          'proc_event_fatal_close_busy_v879:'))
    required(remote, 'iorm    2,PROC_FDCTL_OFFSET(1)',
             'jrst    evt_def_done_v1090')
    forbidden(remote, 'file_close_all', 'proc_finish_slot',
              'proc_slot_discard', 'vm_space_destroy', 'mm_free',
              'fs_provider_unlock')

    lock = code(section(f, 'fs_provider_lock_foreign_v1078:',
                        '\nfs_provider_unlock:'))
    required(lock, 'trnn    1,04',
             'jrst    fs_provider_lock_refuse_v917',
             'jrst    kret_neg5',
             'pushj   17,proc_wait_event',
             'jrst    fs_provider_lock_retry')
    forbidden(lock, 'mm_free', 'proc_finish_slot',
              'proc_slot_discard', 'vm_space_destroy',
              'fs_provider_unlock')
    assert 'setom   fs_provider_ready' not in lock
    assert 'setzm   fs_provider_ready' not in lock

    reaper = code(section(p, 'proc_finish_service_result_v892:',
                          'proc_finish_service_next_v881:'))
    required(reaper, 'jumpn   1,proc_finish_service_failed_v1102',
             'proc_finish_service_failed_v1102:', 'ior     11,4')
    backoff = code(section(p, 'proc_finish_backoff_advance_v885:',
                           '\n        .bss'))
    required(backoff, 'caige   4,01000', 'lsh     4,1',
             'hrlm    4,proc_finish_last_tick_v881', 'popj    17,')


audit(proc, provider)


def mutate(source, before, after):
    assert source.count(before) == 1, ('invalid negative control', before)
    return source.replace(before, after, 1)


mutations = {
    'owner-stop-at-cap': (
        mutate(proc, '        jrst    proc_fatal_close_retry_v879\n',
               '        jrst    proc_exit_current\n'), provider),
    'owner-retry-threshold': (
        mutate(proc, '        caige   1,01000               ; cap',
               '        caige   1,1                   ; cap'), provider),
    'owner-force-free': (
        mutate(proc, 'proc_fatal_close_wait_v995:\n',
               'proc_fatal_close_wait_v995:\n        pushj   17,mm_free\n'),
        provider),
    'foreign-release': (
        mutate(proc, 'proc_event_fatal_other_defer_term_v926:\n',
               'proc_event_fatal_other_defer_term_v926:\n'
               '        pushj   17,proc_finish_slot\n'), provider),
    'provider-steal': (
        proc, mutate(provider, 'fs_provider_lock_foreign_v1078:\n',
                     'fs_provider_lock_foreign_v1078:\n'
                     '        setom   fs_provider_ready\n')),
    'provider-force-unlock': (
        proc, mutate(provider,
                     '        jrst    fs_provider_lock_refuse_v917\n'
                     'fs_provider_lock_refuse_v917:',
                     '        jrst    fs_provider_unlock\n'
                     'fs_provider_lock_refuse_v917:')),
    'slot0-invert-failure': (
        mutate(proc, '        jumpn   1,proc_finish_service_failed_v1102',
               '        jumpe   1,proc_finish_service_failed_v1102'),
        provider),
    'slot0-reset-delay': (
        mutate(proc, '        caige   4,01000\n',
               '        caige   4,1\n'), provider),
}

for name, (p, f) in mutations.items():
    try:
        audit(p, f)
    except (AssertionError, ValueError):
        print('v1149: rejected unsafe mutation', name)
    else:
        raise SystemExit('v1149: unsafe mutation passed: ' + name)

print('v1149: unbounded owner lifetime, capped delay, provider lease '
      'and slot-0 fail-closed retry contract PASS')
