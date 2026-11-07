#!/usr/bin/env python3
"""Verify PDP-6 *live* no-partner pressure, never guest completion.

Decode the source-linked SIMH read-only samples directly. A passing
sample demonstrates genuine allocator pressure and a real cooldown,
not eventual process restore, HALT or leak-free cleanup. The latter
require separate postflight acceptance against the completed guest.
"""

from pathlib import Path
import argparse
import re

FIELDS = ('pressure', 'fallback', 'victim_search', 'reclaim_ok',
          'reclaim_fail', 'swapout_ok', 'swapout_fail', 'swapin_ok',
          'swapin_pressure', 'swapin_fail', 'cooldown', 'exchanged',
          'restored')
ALLOC = ('calls', 'error', 'owner', 'requested', 'extents', 'low_fit',
         'low_base_or_free', 'high_fit', 'high_base_or_free', 'meta')
PAIR = re.compile(r'(?m)^sim>\s*([0-7]+):\s*([0-7]{1,12})\s*$')
SAMPLE = re.compile(r'\[v1306\]\s+sample=(\d+).*?\bpressure=(\d+)'
                    r'.*?\bcooldown=(\d+).*?\balloc_failures=(\d+)')


def verify(swap, alloc, sample):
    """Return useful pressure evidence; reject false or mixed samples."""
    count = swap['pressure']
    if count <= 0 or alloc['calls'] != count:
        raise ValueError('missing or mismatched real MM pressure')
    if alloc['error'] != (1 << 36) - 1:
        raise ValueError('wrong typed MM_ERR_NOMEM result')
    if alloc['requested'] == 0 or alloc['owner'] == 0:
        raise ValueError('invalid physical allocator request')
    if alloc['low_fit'] != 0 or alloc['high_fit'] != 0:
        raise ValueError('pressure sample has a free matching extent')
    if swap['fallback'] != 0 or swap['exchanged'] != 0:
        raise ValueError('fallback or exchange was used')
    if swap['swapin_pressure'] != count or swap['cooldown'] != count:
        raise ValueError('physical pressure not fully converted to cooldown')
    if swap['swapin_fail'] != 0 or swap['restored'] != swap['swapin_ok']:
        raise ValueError('unexpected fatal swap-in or missing restore')
    if swap['reclaim_fail'] < count:
        raise ValueError('reclaim shortfall is not accounted for')
    # proc_swap_out_fail is reached by *refused reclaim attempts* too.
    # It does not establish a fatal process swap-out transaction error.
    # Do not apply the final guest's stricter cleanup classifier here.
    if swap['swapout_fail'] < count:
        raise ValueError('pressure path reclaim refusals not observed')
    if sample is not None:
        if (sample['pressure'] != count or sample['cooldown'] != count or
                sample['alloc_failures'] != count):
            raise ValueError('SIMH sampler/count snapshot mismatch')
    return count


def read_samples(address_path, transcript_path):
    addresses = {}
    for line in Path(address_path).read_text().splitlines():
        parts = line.split()
        if len(parts) != 2:
            raise ValueError('invalid source-linked address entry')
        if parts[0] in addresses:
            raise ValueError('duplicate source-linked address')
        addresses[parts[0]] = int(parts[1], 8)
    text = Path(transcript_path).read_text(errors='replace')
    all_names = {'f07s_diag_' + name for name in FIELDS}
    all_names.update('f07a_' + name for name in ALLOC)
    missing = all_names - addresses.keys()
    if missing:
        raise ValueError('missing source-linked addresses: %r' % missing)
    blocks = []
    for section in re.split(r'(?m)^Simulation stopped, PC:', text)[1:]:
        values = {int(addr, 8): int(value, 8)
                  for addr, value in PAIR.findall(section)}
        if not all(addresses[name] in values for name in all_names):
            continue
        swap = {name: values[addresses['f07s_diag_' + name]]
                for name in FIELDS}
        alloc = {name: values[addresses['f07a_' + name]]
                 for name in ALLOC}
        match = SAMPLE.search(section)
        sample = ({key: int(val) for key, val in
                   zip(('number', 'pressure', 'cooldown', 'alloc_failures'),
                       match.groups())} if match else None)
        blocks.append((swap, alloc, sample))
    if not blocks:
        raise ValueError('no complete physical source-linked SIMH samples')
    return blocks


def self_test():
    swap = dict.fromkeys(FIELDS, 0)
    swap.update(pressure=93, victim_search=147, reclaim_ok=54,
                reclaim_fail=93, swapout_ok=54, swapout_fail=93,
                swapin_ok=37, swapin_pressure=93, cooldown=93,
                restored=37)
    alloc = dict.fromkeys(ALLOC, 0)
    alloc.update(calls=93, error=(1 << 36)-1, owner=5, requested=26624)
    sample = dict(number=12, pressure=93, cooldown=93, alloc_failures=93)
    assert verify(swap, alloc, sample) == 93
    mutations = (
        ('fake-no-mm-pressure', 'swap', 'pressure', 0),
        ('not-no-partner', 'swap', 'exchanged', 1),
        ('missing-cooldown', 'swap', 'cooldown', 0),
        ('wrong-typed-error', 'alloc', 'error', 0),
        ('wrong-mm-count', 'alloc', 'calls', 92),
        ('fatal-swapin', 'swap', 'swapin_fail', 1),
        ('fake-sampler', 'sample', 'pressure', 92),
        ('wrong-restore', 'swap', 'restored', 36),
    )
    for name, obj, key, val in mutations:
        altered = dict({'swap': swap, 'alloc': alloc, 'sample': sample}[obj])
        altered[key] = val
        args = {'swap': swap, 'alloc': alloc, 'sample': sample}
        args[obj] = altered
        try:
            verify(**args)
        except ValueError:
            continue
        raise AssertionError('unsafe mutation accepted: ' + name)
    print('v1336: eight live pressure evidence mutations rejected PASS')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('addresses', nargs='?')
    parser.add_argument('raw', nargs='?')
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.addresses or not args.raw:
        parser.error('require linked ADDRESSES and SIMH RAW trace')
    blocks = read_samples(args.addresses, args.raw)
    latest = blocks[-1]
    count = verify(*latest)
    print('v1336: live physical PDP-6 pressure=%d cooldown=%d '
          'swapout=%d swapin=%d no_partner=YES' %
          (count, latest[0]['cooldown'], latest[0]['swapout_ok'],
           latest[0]['swapin_ok']))
    print('v1336: NOT full-guest liveness or cleanup acceptance')


if __name__ == '__main__':
    main()
