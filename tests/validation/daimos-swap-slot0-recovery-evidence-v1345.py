#!/usr/bin/env python3
"""Classify booted v1344 *partial* physical swap/provider recovery.

This checks linked read-only SIMH sampler fields, never a completed
guest. It is not an alternative to the strict F07 HALT, TERM/WAIT,
MM or backing postflight checks.
"""

from pathlib import Path
import argparse
import re

PREFIX = re.compile(r'^\[v(1306|1342|1344)\] sample=(\d+)\s+(.*)$')
FIELD = re.compile(r'([A-Za-z][A-Za-z0-9_]*)=([0-9]+)')
ALL_ONES = (1 << 36) - 1
HALF = (1 << 18) - 1


def samples(path):
    found = {}
    for line in Path(path).read_text(errors='replace').splitlines():
        match = PREFIX.match(line)
        if match is None:
            continue
        version, sample, rest = match.groups()
        key = int(sample)
        values = dict(FIELD.findall(rest))
        entry = found.setdefault((key, version), {})
        if any(name in entry for name in values):
            raise ValueError('duplicate read-only sample field')
        entry.update(values)
    return found


def numeric(entry, key, octal=False):
    if key not in entry:
        raise ValueError('missing sampler field ' + key)
    return int(entry[key], 8 if octal else 10)


def verify(found):
    rows = sorted({n for n, version in found if version == '1306'})
    if len(rows) < 4:
        raise ValueError('too few physical guest samples')
    before = None
    after = None
    provider = None
    device = 0
    for n in rows:
        try:
            mm = found[n, '1306']
            lease = found[n, '1342']
            io = found[n, '1344']
        except KeyError as exc:
            raise ValueError('missing linked sample ' + str(exc))
        pc = numeric(mm, 'PC', True)
        ac1 = numeric(io, 'ac1', True)
        active = numeric(io, 'drm_active', True)
        if pc in (0o15624, 0o15625) and active & HALF:
            if ac1 != (active & HALF) + 2:
                raise ValueError('slot-0 wait is not active DRM event')
            device += 1
        if (numeric(mm, 'pressure') == 1 and
                numeric(mm, 'cooldown') == 1 and
                numeric(mm, 'alloc_failures') == 1 and
                numeric(mm, 'exchanges') == 0):
            if numeric(lease, 'released') == 0:
                before = before or (n, numeric(mm, 'swapin'))
            if (numeric(lease, 'released') == 1 and
                    numeric(lease, 'owner_count') == 0 and
                    numeric(lease, 'prepared') == 4 and
                    numeric(lease, 'freed') == 4 and
                    numeric(lease, 'error') == 0 and
                    numeric(lease, 'pinned_base', True) == 0 and
                    numeric(lease, 'release_pressure') == 1):
                after = (n, numeric(mm, 'swapin'))
        if (numeric(lease, 'real_oom') == 1 and
                numeric(lease, 'fatal_busy') >= 2 and
                numeric(lease, 'holder_enter') == 1 and
                numeric(lease, 'release', True) == ALL_ONES and
                numeric(lease, 'holder_return') == 1):
            provider = n
    if before is None or after is None or after[0] <= before[0]:
        raise ValueError('no observed genuine pressure-then-owner-release')
    if after[1] <= before[1]:
        raise ValueError('no successful swap-in after release')
    if provider is None or provider < after[0]:
        raise ValueError('guarded independent provider return not observed')
    if not device:
        raise ValueError('no confirmed DRM active-completion wait')
    return before, after, provider, device


def negative_controls(found):
    """Mutation controls use a copy of the actual, source-linked trace."""
    cases = (
        ('no-physical-pressure', lambda bad:
         bad[15, '1306'].__setitem__('pressure', '0')),
        ('fatal-swap-in', lambda bad:
         bad[15, '1306'].__setitem__('exchanges', '1')),
        ('wrong-drum-event', lambda bad:
         bad[4, '1344'].__setitem__('ac1', '000000000000')),
        ('no-owner-cleanup', lambda bad:
         [v.__setitem__('owner_count', '1') for (n, kind), v in
          bad.items() if kind == '1342' and n >= 16]),
        ('no-holder-return', lambda bad:
         bad[18, '1342'].__setitem__('holder_return', '0')),
        ('missing-release-witness', lambda bad:
         [v.__setitem__('release_pressure', '0') for (n, kind), v in
          bad.items() if kind == '1342' and n >= 16]),
    )
    for label, mutate in cases:
        altered = {key: dict(value) for key, value in found.items()}
        mutate(altered)
        try:
            verify(altered)
        except ValueError:
            continue
        raise AssertionError('unsafe evidence mutation accepted: ' + label)
    return len(cases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sampler_log')
    args = parser.parse_args()
    found = samples(args.sampler_log)
    before, after, provider, device = verify(found)
    rejected = negative_controls(found)
    print('v1345: source-linked booted pressure before sample=%d '
          'swapin=%d' % before)
    print('v1345: full MM owner release sample=%d swapin=%d; '
          'guarded provider return sample=%d; active DRM waits=%d' %
          (after[0], after[1], provider, device))
    print('v1345: diagnostic subcase PASS; NO full guest HALT or '
          'zero-leak postflight acceptance')
    print('v1345: unsafe evidence mutations rejected=%d' % rejected)


if __name__ == '__main__':
    main()
