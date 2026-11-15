#!/usr/bin/env python3
"""Verify original D6FS cached-data reclamation during physical rollback.

Normal D6FS VFS reads populate an original MM-owned private cache slab.
At snapshot entry the test copies 128 36-bit words, and observes their
exact identity at the original BCACHE reclaim boundary. A successful
reclaim must invalidate the cache, make fetch MISS, and preserve the
separate process DISK/backing rollback and both real physical cold boots.
"""

import importlib.util
from pathlib import Path
import re
import sys

FIELDS = ('primed', 'nonzero', 'slab', 'key', 'before_differences',
          'after_differences', 'fetch_after', 'fetch_differences',
          'reclaim_matched', 'reclaim_inflight', 'reclaim_swaps',
          'reclaim_differences', 'reclaim_succeeded', 'reclaim_refused')
MASK36 = (1 << 36) - 1


def module(name, label):
    file = Path(__file__).with_name(name)
    spec = importlib.util.spec_from_file_location(label, file)
    assert spec is not None and spec.loader is not None
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def extract(mapping, addresses, transcript):
    v1584 = module('daimos-p1c-snapshot-swap-verify-v1584.py',
                   'base_link_v1589')
    known = v1584.get_symbols(mapping)
    linked = v1584.get_symbols(addresses)
    assert transcript.count('HALT instruction, PC:') == 1
    after = transcript.split('HALT instruction, PC:', 1)[1]
    values = {}
    for name in FIELDS:
        key = 'daimos_v1589_' + name
        assert key in linked and key in known
        assert linked[key] == known[key], 'stale v1589 cache symbol ' + name
        pattern = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % linked[key]
        matches = re.findall(pattern, after)
        assert len(matches) == 1, 'missing real post-HALT ' + name
        values[name] = int(matches[0], 8)
    return values


def check(mapping, addr4, addr5, addr8, addr9, logs, media):
    earlier = module('daimos-p1c-postread-release-verify-v1588.py',
                     'postread_v1589')
    baseline, physical = earlier.check(mapping, addr4, addr5, addr8,
                                       logs, media)
    values = []
    for i, log in enumerate(logs):
        assert 'P1C-BCACHE-D6FS-WARM-V1589' in log, \
            'no actual userland D6FS filesystem read'
        item = extract(mapping, addr9, log)
        assert item['primed'] == 1, 'no valid original private D6FS cache'
        assert 0 < item['nonzero'] <= 128, 'cached data absent or zero'
        assert 0 < item['slab'] < 0o400000, 'no real MM-managed cache slab'
        source = (item['key'] >> 24) & 0o7777
        assert (source & 0o7700) == 0o1000, \
            'private cache source not genuine D6FS mount identity'
        assert 0 <= (item['key'] & 0o77777777) < 0o100000000
        assert item['reclaim_matched'] == 1, \
            'original BCACHE reclaim never saw the D6FS private owner'
        assert 0 < item['reclaim_swaps'] <= \
            baseline[i][1]['daimos_v1584_swap_started'], \
            'reclaim did not occur during an independently scheduled swap'
        assert item['reclaim_inflight'] == 0, \
            'incomplete original matched MM reclaim'
        assert item['reclaim_differences'] == 0, \
            'full 128-word D6FS payload changed BEFORE original reclaim'
        assert item['reclaim_succeeded'] == 1, \
            'real MM did not free the independently cached D6FS slab'
        assert item['reclaim_refused'] == 0
        assert item['before_differences'] == 1, \
            'private D6FS owner unexpectedly survived original reclaim'
        assert item['after_differences'] == 1, \
            'private cache owner was resurrected after MM rollback'
        assert item['fetch_after'] == 0, \
            'stale D6FS cached identity still returned HIT after reclaim'
        assert item['fetch_differences'] == item['nonzero'], \
            'miss must not copy any of the old private 128-word payload'
        assert baseline[i][0]['bcache_state_before'] == 0, \
            'cache slab still claimed after original MM reclaim'
        assert baseline[i][0]['bcache_state_after'] == 0
        assert baseline[i][0]['bcache_tag_before'] == MASK36
        assert baseline[i][0]['bcache_tag_after'] == MASK36
        values.append(item)
    return baseline, physical, values


def negatives(mapping, addr4, addr5, addr8, addr9, logs, media):
    linked = module('daimos-p1c-snapshot-swap-verify-v1584.py',
                    'neg_symbols_v1589').get_symbols(addr9)
    before, after = logs[0].split('HALT instruction, PC:', 1)
    mutants = (
        ('no populated private cache', 'primed', 0),
        ('all-zero cached physical block', 'nonzero', 0),
        ('no MM-owned cache slab', 'slab', 0),
        ('wrong D6FS provider/source identity', 'key', 1),
        ('missing matched real BCACHE reclaim', 'reclaim_matched', 0),
        ('cache reclaimed outside independent swap', 'reclaim_swaps', 0),
        ('incomplete BCACHE reclaim', 'reclaim_inflight', 1),
        ('corrupted cached data before reclaim', 'reclaim_differences', 1),
        ('missing original cache MM free', 'reclaim_succeeded', 0),
        ('unexpected refused cache MM free', 'reclaim_refused', 1),
        ('stale private slab before release', 'before_differences', 0),
        ('stale private slab after MM rollback', 'after_differences', 0),
        ('false cache hit after reclaim', 'fetch_after', 1),
        ('invalid readback after miss', 'fetch_differences', 0),
    )
    for label, suffix, replacement in mutants:
        address = linked['daimos_v1589_' + suffix]
        pat = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % address
        assert len(re.findall(pat, after)) == 1
        changed = re.sub(pat,
                         lambda m: m.group(1) + '%012o' % replacement +
                         m.group(3), after, count=1)
        try:
            check(mapping, addr4, addr5, addr8, addr9,
                  [before + 'HALT instruction, PC:' + changed, logs[1]],
                  media)
        except (AssertionError, KeyError):
            print('PASS v1589: rejected ' + label)
        else:
            raise AssertionError('accepted unsafe populated cache ' + label)


def main():
    args = sys.argv[1:]
    self_test = '--self-test' in args
    if self_test:
        args.remove('--self-test')
    if len(args) != 9:
        raise SystemExit('usage: verifier [--self-test] MAP ADDR4 ADDR5 '
                         'ADDR8 ADDR9 BOOT1 BOOT2 DRUM_DIR REPORT')
    mapping, addr4, addr5, addr8, addr9, log1, log2 = [
        Path(path).read_text(errors='replace') for path in args[:7]]
    drum = Path(args[7])
    media = [(drum / ('dsk%d.dsk' % unit)).read_bytes()
             for unit in range(4)]
    logs = [log1, log2]
    baseline, physical, cached = check(mapping, addr4, addr5, addr8,
                                       addr9, logs, media)
    lines = ['PASS v1589: exact original D6FS BCACHE data at real MM reclaim, '
             'no stale identity during physical post-DMA rollback; DR%d:%06o' %
             physical[:2]]
    for index, item in enumerate(cached):
        lines.append('BOOT %d: D6FS slab=%06o source/block=%012o '
                     'nonzero=%d, full 128-word reclaim differences=0, '
                     'original MM freed slab, stale fetch MISS, swap PI2=%d' %
                     (index + 1, item['slab'], item['key'], item['nonzero'],
                      baseline[index][1]['daimos_v1584_swap_pi2']))
    report = '\n'.join(lines) + '\n'
    Path(args[8]).write_text(report)
    print(report, end='')
    if self_test:
        module('daimos-p1c-postread-release-verify-v1588.py',
               'inherited_postread_v1589').selftest(
                   mapping, addr4, addr5, addr8, logs, media)
        negatives(mapping, addr4, addr5, addr8, addr9, logs, media)


if __name__ == '__main__':
    main()
