#!/usr/bin/env python3
"""Strict physical evidence for already-pending TERM on a DISK owner.

This is a *scoped* 256K guest assertion. It is not full corrupt-bitmap
recovery acceptance, and deliberately ignores v1499's inverted branch
counters. The independently captured pre/post event words are valid.
"""

from pathlib import Path
import re
import runpy
import sys

HERE = Path(__file__).resolve().parent
READ = runpy.run_path(str(HERE / 'daimos-backstore-term-branch-report-v1499.py'))[
    'read_values']
HALF = 0o777777
EXTRA = ('v1494_armed', 'v1494_faults', 'v1494_free_calls',
         'v1494_terms', 'v1494_repairs', 'v1494_slot', 'v1494_first',
         'v1494_blocks', 'v1495_failed_entry', 'v1495_event_returned',
         'f07s_diag_swapin_fail', 'f07s_final_swap_blocks',
         'f07s_final_backstore_used')


def get_extras(addresses, simh):
    mapping = {}
    for line in Path(addresses).read_text().splitlines():
        name, octal = line.split()
        if name in mapping:
            raise ValueError('duplicate mapped field: ' + name)
        mapping[name] = int(octal, 8)
    text = Path(simh).read_text(errors='replace')
    pos = text.rfind('HALT instruction, PC:')
    if pos < 0 or 'Goodbye' not in text[pos:]:
        raise ValueError('no genuine simulator HALT/EXIT')
    text = text[pos:]
    out = {}
    for name in EXTRA:
        if name not in mapping:
            raise ValueError('missing mapped field: ' + name)
        pattern = r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' % mapping[name]
        hits = re.findall(pattern, text)
        if len(hits) != 1:
            raise ValueError('missing/duplicate observation: ' + name)
        out[name] = int(hits[0], 8)
    return out


def verify(data, guest):
    expected = {
        'v1499_events': 2, 'v1499_active': 0,
        'v1499_overflow': 0,
        'v1494_armed': 2, 'v1494_faults': 1,
        'v1494_free_calls': 3, 'v1494_terms': 2,
        'v1494_repairs': 1, 'v1495_failed_entry': 2,
        'v1495_event_returned': 2,
        'f07s_diag_swapin_fail': 2,
        'f07s_final_swap_blocks': 0,
        'f07s_final_backstore_used': 0,
    }
    for field, value in expected.items():
        if data[field] != value:
            raise ValueError('%s=%o expected=%o' % (field, data[field], value))
    if data['v1494_slot'] < 0o10 or not data['v1494_blocks']:
        raise ValueError('no physical user-slot disk allocation')

    for i in (0, 1):
        def field(name):
            return data['v1499_%s_%d' % (name, i)]

        meta = field('pre_meta')
        sched = field('pre_sched') >> 18
        pc = field('pre_pc') >> 18
        fdctl = field('pre_fdctl') >> 18
        if not (meta & 0o400000) or meta & 0o200000:
            raise ValueError('event %d not a stable unlocked u-area' % i)
        if field('pre_vm') & HALF:
            raise ValueError('event %d not a nonresident DISK VM' % i)
        if (sched & 0o700000) != 0o200000 or sched & 0o60000:
            raise ValueError('event %d not runnable without WAIT class' % i)
        if pc & 0o10000:
            raise ValueError('event %d has a user-mode saved return' % i)
        if (fdctl & 0o16) != 0o4:
            raise ValueError('event %d missing prior TERM bit' % i)
        if field('pre_finalize') != 0:
            raise ValueError('event %d had existing FINALIZE' % i)
        if field('event_result') != 0:
            raise ValueError('event %d did not coalesce successfully' % i)
        for name in ('meta', 'vm', 'sched', 'fdctl', 'finalize'):
            if field('pre_' + name) != field('post_' + name):
                raise ValueError('event %d modified %s owner' % (i, name))

    # Count only actual F07 milestones after its initial '<' marker,
    # never SIMH's possible '+uncommitted-changes' startup banner.
    if '<' not in guest:
        raise ValueError('missing actual F07 user start')
    milestones = guest.split('<', 1)[1].split('HALT instruction', 1)[0]
    if milestones.count('+') != 18 or milestones.count('~') != 18:
        raise ValueError('nonexact 18/18 physical F07 child milestones')


def self_test():
    data = dict(v1499_events=2, v1499_active=0, v1499_overflow=0,
                v1494_armed=2, v1494_faults=1, v1494_free_calls=3,
                v1494_terms=2, v1494_repairs=1, v1494_slot=0o10,
                v1494_first=0o2350, v1494_blocks=0o330,
                v1495_failed_entry=2, v1495_event_returned=2,
                f07s_diag_swapin_fail=2,
                f07s_final_swap_blocks=0, f07s_final_backstore_used=0)
    for i in (0, 1):
        vals = dict(meta=(0o156000 << 18) | 0o400401,
                    vm=0o66000 << 18, sched=0o200024 << 18,
                    pc=(0o340000 << 18) | 0o15715,
                    fdctl=(0o4 << 18) | 0o4010, finalize=0)
        for key, val in vals.items():
            data['v1499_pre_%s_%d' % (key, i)] = val
            if key != 'pc':
                data['v1499_post_%s_%d' % (key, i)] = val
        data['v1499_event_result_%d' % i] = 0
    transcript = 'SIMH git abc+dirty header <' + '+' * 18 + '~' * 18 + \
                 'HALT instruction, PC: 1 Goodbye'
    verify(data, transcript)
    negatives = (
        ('v1499_events', 1), ('v1494_terms', 1),
        ('v1494_faults', 0), ('v1494_blocks', 0),
        ('f07s_final_backstore_used', 1),
        ('v1499_pre_pc_0', data['v1499_pre_pc_0'] | (0o10000 << 18)),
        ('v1499_pre_sched_0', data['v1499_pre_sched_0'] | (0o40000 << 18)),
        ('v1499_pre_fdctl_0', data['v1499_pre_fdctl_0'] &
                                  ~(0o4 << 18)),
        ('v1499_pre_vm_0', data['v1499_pre_vm_0'] | 0o20000),
        ('v1499_post_meta_1', data['v1499_post_meta_1'] + 1),
        ('v1499_event_result_1', (1 << 36) - 1),
        ('v1499_pre_finalize_0', 0o400000 << 18),
    )
    count = 0
    for key, changed in negatives:
        bad = dict(data)
        bad[key] = changed
        try:
            verify(bad, transcript)
        except ValueError:
            count += 1
        else:
            raise AssertionError('unsafe mutation accepted: ' + key)
    for guest in ('SIMH no F07', transcript.replace('+' * 18, '+' * 17),
                  transcript.replace('~' * 18, '~' * 17)):
        try:
            verify(data, guest)
        except ValueError:
            count += 1
        else:
            raise AssertionError('bad physical milestone accepted')
    return count


def main():
    if len(sys.argv) == 2 and sys.argv[1] == '--self-test':
        print('v1503: %d wrong owner/event/milestone mutations rejected' %
              self_test())
        return
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1503.py ADDRESSES COMPLETED-SIMH.OUT')
    data = READ(sys.argv[1], sys.argv[2])
    data.update(get_extras(sys.argv[1], sys.argv[2]))
    verify(data, Path(sys.argv[2]).read_text(errors='replace'))
    print('PASS v1503: physical 256K owner %o, backed extent %o/%o' %
          (data['v1494_slot'], data['v1494_first'],
           data['v1494_blocks']))
    print('PASS v1503: two already-pending TERM requests coalesced while '
          'saved PC executive, VM DISK and no WAIT; original owners intact')
    print('PASS v1503: one bitmap fault, three matching frees, one repair, '
          'final swap/BACKSTORE zero and exact F07 18/18')
    print('v1503: %d negative controls PASS' % self_test())
    print('v1503: does NOT prove final TERM delivery or permanent '
          'corruption recovery; full KCORE feature gate remains OPEN')


if __name__ == '__main__':
    main()
