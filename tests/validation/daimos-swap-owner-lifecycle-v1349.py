#!/usr/bin/env python3
"""Verify real MM owner lifetime across *two* source-linked guest phases.

The earlier v1327 verifier expects all four 8K words-owning extents
to exist in the late BRK OOM MM snapshot. That is not the lifetime
of the independent-release guest: it must free its test-owned MM
before INIT can reach requester OOM. Check actual booted live samples
on both sides of release plus the original final HALT counters.
"""

from pathlib import Path
import re
import runpy
import sys


def verify(live, final):
    pre = None
    released = None
    rows = sorted(set(n for n, kind in live if kind == '1306'))
    for n in rows:
        mm = live.get((n, '1306'))
        own = live.get((n, '1342'))
        if mm is None or own is None:
            raise ValueError('missing paired source-linked owner sample')
        def value(name):
            if name not in own:
                raise ValueError('missing owner field ' + name)
            return int(own[name], 8 if name == 'pinned_base' else 10)
        if (value('prepared') == 4 and value('owner_count') == 4 and
                value('freed') == 0 and value('error') == 0 and
                value('pinned_base') != 0 and value('released') == 0):
            pre = pre or n
        if (value('prepared') == 4 and value('owner_count') == 0 and
                value('freed') == 4 and value('error') == 0 and
                value('pinned_base') == 0 and value('released') == 1 and
                value('release_pressure') == 1 and
                value('release_calls') == 1 and
                int(mm['pressure']) >= 1 and
                int(mm['cooldown']) >= 1 and
                int(mm['exchanges']) == 0):
            released = released or n
    if pre is None or released is None or pre >= released:
        raise ValueError('no ordered real MM occupancy and independent release')
    if final != {'prepared': 4, 'freed': 4, 'count': 0, 'error': 0}:
        raise ValueError('real owner MM final cleanup not exact')
    return pre, released


def read_final(address_file, transcript):
    address = dict(line.split() for line in Path(address_file).read_text().splitlines())
    text = Path(transcript).read_text(errors='replace')
    if 'HALT instruction, PC:' not in text or 'Goodbye' not in text:
        raise ValueError('no completed PDP-6 guest HALT/EXIT')
    final = {}
    for key in ('prepared', 'freed', 'count', 'error'):
        label = 'f07h_' + key
        if label not in address:
            raise ValueError('missing source-linked final owner ' + label)
        addr = int(address[label], 8)
        hits = re.findall(r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' % addr,
                          text)
        if len(hits) != 1:
            raise ValueError('absent or duplicated final owner ' + label)
        final[key] = int(hits[0], 8)
    return final


def negatives(live, final):
    cases = (
        ('lost-original-pin', lambda bad, done:
         [v.__setitem__('pinned_base', '000000') for (n, kind), v in
          bad.items() if kind == '1342']),
        ('missing-owner-before', lambda bad, done:
         [v.__setitem__('owner_count', '0') for (n, kind), v in
          bad.items() if kind == '1342']),
        ('no-independent-release', lambda bad, done:
         [v.__setitem__('released', '0') for (n, kind), v in
          bad.items() if kind == '1342']),
        ('fabricated-cooldown', lambda bad, done:
         [v.__setitem__('cooldown', '0') for (n, kind), v in
          bad.items() if kind == '1306']),
        ('extra-owner-remains', lambda bad, done:
         done.__setitem__('count', 1)),
        ('unbalanced-owner-free', lambda bad, done:
         done.__setitem__('freed', 3)),
    )
    for title, mutate in cases:
        altered = {k: dict(v) for k, v in live.items()}
        ending = dict(final)
        mutate(altered, ending)
        try:
            verify(altered, ending)
        except ValueError:
            continue
        raise AssertionError('unsafe owner lifecycle mutation accepted: ' + title)
    return len(cases)


def main():
    if len(sys.argv) != 4:
        raise SystemExit('usage: v1349.py ADDRESSES SIMH.OUT SAMPLER.LOG')
    here = Path(__file__).resolve().parent
    sampler = runpy.run_path(str(here / 'daimos-swap-slot0-recovery-evidence-v1345.py'))
    live = sampler['samples'](sys.argv[3])
    final = read_final(sys.argv[1], sys.argv[2])
    pre, release = verify(live, final)
    count = negatives(live, final)
    print('v1349: four real owner extents with process pin at sample=%d; '
          'post-cooldown independent release at sample=%d' % (pre, release))
    print('v1349: HALT owner prepared=4 freed=4 remaining=0 error=0; '
          '%d negative controls PASS' % count)


if __name__ == '__main__':
    main()
