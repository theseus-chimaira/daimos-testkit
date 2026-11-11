#!/usr/bin/env python3
"""Strict fault-specific physical owner-return acceptance, v1504.

Requires the earlier v1503 verified coalesced-TERM/bitmap/F07 boundary
AND an exact single owner-return TERM consumption, private fatal close,
process finish and zombie publication on the selected slot.
"""

from pathlib import Path
import runpy
import sys


HERE = Path(__file__).resolve().parent
V1503 = runpy.run_path(str(HERE / 'daimos-backstore-coalesced-physical-v1503.py'))
V1504 = runpy.run_path(str(HERE / 'daimos-backstore-owner-return-report-v1504.py'))
HALF = 0o777777


def check_owner(d):
    slot = d['v1494_slot']
    if not 0o10 <= slot < 0o100:
        raise ValueError('missing real nonzero F07 target slot')
    if (d['v1504_armed_fdctl'] >> 18) & 0o16 != 0o4:
        raise ValueError('pre-existing TERM missing at corruption time')
    armed_sched = d['v1504_armed_sched'] >> 18
    if ((armed_sched & 0o700000) != 0o200000 or
            armed_sched & 0o60000):
        raise ValueError('faulted owner not RUN/no-WAIT')
    if (d['v1504_armed_pc'] >> 18) & 0o10000:
        raise ValueError('faulted owner unexpectedly in user return')

    prior = d['v1504_owner_fdctl_before']
    after = d['v1504_owner_fdctl_after']
    exact = {
        'v1504_owner_term_count': 1,
        'v1504_owner_commit_count': 1,
        'v1504_owner_slot': slot,
        'v1504_private_fatal_count': 1,
        'v1504_private_status': 0o400001,
        'v1504_finish_count': 1,
        'v1504_finish_status': 0o400001,
        'v1504_zombie_count': 1,
        'v1504_owner_backing_before': 0o37,
        'v1504_def_count_%02o' % slot: 3,
        'v1504_def_kind_%02o' % slot: 1,
    }
    for key, value in exact.items():
        if d[key] != value:
            raise ValueError('%s=%o expected=%o' % (key, d[key], value))
    if prior != d['v1504_armed_fdctl']:
        raise ValueError('pending TERM changed before owner delivery')
    if not (prior >> 18) & 0o4:
        raise ValueError('private owner did not see pending TERM')
    if after != ((prior & ~(0o16 << 18)) | 0o4):
        raise ValueError('owning return failed to atomically consume TERM')
    if not ((d['v1504_def_prior_%02o' % slot] >> 18) & 0o4):
        raise ValueError('last repeated TERM did not find prior TERM')


def mutations(d):
    slot = d['v1494_slot']
    changes = (
        ('v1504_owner_term_count', 0),
        ('v1504_owner_term_count', 2),
        ('v1504_owner_commit_count', 0),
        ('v1504_owner_slot', slot + 1),
        ('v1504_owner_fdctl_before',
         d['v1504_owner_fdctl_before'] & ~(0o4 << 18)),
        ('v1504_owner_fdctl_after',
         d['v1504_owner_fdctl_after'] | (0o4 << 18)),
        ('v1504_owner_fdctl_after',
         d['v1504_owner_fdctl_after'] & ~0o4),
        ('v1504_private_fatal_count', 0),
        ('v1504_private_status', 0o400002),
        ('v1504_finish_count', 0),
        ('v1504_finish_status', 0o400002),
        ('v1504_zombie_count', 0),
        ('v1504_armed_fdctl', d['v1504_armed_fdctl'] & ~(0o4 << 18)),
        ('v1504_armed_pc', d['v1504_armed_pc'] | (0o10000 << 18)),
        ('v1504_armed_sched', d['v1504_armed_sched'] | (0o40000 << 18)),
        ('v1504_owner_backing_before',
         (d['v1494_first'] << 18) | d['v1494_blocks']),
        ('v1504_def_count_%02o' % slot, 0),
        ('v1504_def_count_%02o' % slot, 4),
        ('v1504_def_kind_%02o' % slot, 2),
        ('v1504_def_prior_%02o' % slot,
         d['v1504_def_prior_%02o' % slot] & ~(0o4 << 18)),
    )
    rejected = 0
    for field, changed in changes:
        trial = dict(d)
        trial[field] = changed
        try:
            check_owner(trial)
        except ValueError:
            rejected += 1
        else:
            raise AssertionError('unsafe owner-state mutation passed: '
                                 + field)
    return rejected


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1504.py ADDRESSES COMPLETED-SIMH.OUT')
    addresses, simh = sys.argv[1:]
    owner = V1504['read'](addresses, simh)
    base = V1503['READ'](addresses, simh)
    base.update(V1503['get_extras'](addresses, simh))
    V1503['verify'](base, Path(simh).read_text(errors='replace'))
    data = dict(base)
    data.update(owner)
    check_owner(data)
    rejected = mutations(data)
    if rejected != 20:
        raise ValueError('incomplete owner negative test matrix')
    print('PASS v1504: real 256K PDP-6 selected slot %03o' %
          data['v1494_slot'])
    print('PASS v1504: one owner-side TERM consumption, pending bit cleared '
          'and fatal-close latch set')
    print('PASS v1504: exactly one fatal status 0400001, one finish '
          'and one zombie publication')
    print('PASS v1504: preceding v1503 physical bitmap/owner/F07 scope '
          'also PASS; %d owner negative mutations rejected' % rejected)
    print('v1504: permanently irreparable backing and full policy remain OPEN')


if __name__ == '__main__':
    main()
