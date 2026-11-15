#!/usr/bin/env python3
"""Check genuine two-owner PI6 wake plus isolated post-DMA rollback.

Use the exact v1584 physical-media/swap PI2 oracle, v1585 timer record
and v1588 post-release MM/bitmap witnesses from two distinct boots.
"""

import importlib.util
from pathlib import Path
import re
import sys

MASK36 = (1 << 36) - 1


def imported(filename, label):
    path = Path(__file__).with_name(filename)
    spec = importlib.util.spec_from_file_location(label, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def owner_extract(mapping, addresses, transcript):
    old = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                   'original_symbols_v1592')
    original = old.get_symbols(mapping)
    linked = old.get_symbols(addresses)
    assert transcript.count('HALT instruction, PC:') == 1
    after = transcript.split('HALT instruction, PC:', 1)[1]
    out = {}
    for suffix in ('first_slot', 'second_slot', 'first_woke', 'second_woke'):
        name = 'daimos_v1592_' + suffix
        assert name in original and name in linked
        assert original[name] == linked[name]
        pat = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % linked[name]
        matches = re.findall(pat, after)
        assert len(matches) == 1, 'missing linked owner witness ' + name
        out[suffix] = int(matches[0], 8)
    return out


def check(mapping, addresses4, addresses5, addresses8, addresses2,
          logs, media):
    physical = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                        'original_media_v1592')
    timer = imported('daimos-p1c-snapshot-timer-verify-v1585.py',
                     'original_timer_v1592')
    rollback = imported('daimos-p1c-postread-release-verify-v1588.py',
                        'original_rollback_v1592')
    first, second, unit, block, pool, occupied = physical.check(
        mapping, addresses4, logs, media, True)
    observed = []
    for transcript, base in zip(logs, (first, second)):
        two = owner_extract(mapping, addresses2, transcript)
        clock = timer.extract(mapping, addresses5, transcript)
        failed = rollback.extract(mapping, addresses8, transcript)
        assert 0 < two['first_slot'] < 24
        assert 0 < two['second_slot'] < 24
        assert two['first_slot'] != two['second_slot'], 'same slot twice'
        assert clock['daimos_v1585_armed'] == 2, 'did not arm both'
        assert clock['daimos_v1585_slot'] == two['second_slot']
        assert two['first_woke'] == 1 and two['second_woke'] == 1, \
            'two independent original PI6 wakeups not both observed'
        assert clock['daimos_v1585_woke'] == 1
        assert ((clock['daimos_v1585_end_tick'] -
                 clock['daimos_v1585_start_tick']) & 0o377777) > 0
        assert failed['slot'] in (two['first_slot'], two['second_slot']), \
            'refused owner was not independently timer-woken'
        assert failed['release_refusals'] == 1
        assert failed['rollback_count'] == 1
        assert failed['term_events'] == 1
        assert failed['fault_armed'] == failed['in_request'] == 0
        assert failed['mm_before'] == failed['mm_after'] + 1
        assert failed['allocated_base'] != 0
        assert failed['allocated_base'] % 0o2000 == 0
        assert failed['extent_still_present'] == 0
        assert failed['owner_before'] == failed['owner_after'] > 0
        assert failed['backing_before'] == failed['backing_after'] > 0
        assert failed['bitmap_words'] == \
            (base['backing_region_count'] + 35) // 36
        assert failed['bitmap_differences'] == 0
        assert failed['record_before'] == failed['record_after'] != 0
        assert failed['process_before'] & 0o200000
        assert failed['process_after'] == \
            (failed['process_before'] & (MASK36 ^ 0o200000))
        for name in ('process_word1', 'process_word2', 'bcache_state',
                     'bcache_tag', 'bcache_private'):
            assert failed[name + '_before'] == failed[name + '_after']
        assert failed['storage_expect_after'] == 0
        assert base['daimos_v1584_swap_started'] >= 2
        assert base['daimos_v1584_swap_completed'] >= 1
        assert base['daimos_v1584_swap_started'] == \
            base['daimos_v1584_swap_completed'] + 1
        assert base['daimos_v1584_swap_reads'] == \
            base['daimos_v1584_swap_started']
        assert base['daimos_v1584_swap_pi2'] >= \
            base['daimos_v1584_swap_reads']
        assert base['mfsdev_storage_errors'] == 0
        observed.append((two, failed, base))
    return observed, (unit, block, pool, occupied)


def negative_tests(mapping, a4, a5, a8, a2, logs, media):
    base = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                    'physical_mutants_v1592')
    original = owner_extract(mapping, a2, logs[0])
    rollback = imported('daimos-p1c-postread-release-verify-v1588.py',
                        'rollback_mutants_v1592')
    failed = rollback.extract(mapping, a8, logs[0])
    timer = imported('daimos-p1c-snapshot-timer-verify-v1585.py',
                     'timer_mutants_v1592')
    clock = timer.extract(mapping, a5, logs[0])
    linked = {}
    for addresses in (a2, a5, a8):
        linked.update(base.get_symbols(addresses))
    oldhead, oldtail = logs[0].split('HALT instruction, PC:', 1)
    for label, symbol, corrupted in (
        ('first owner missing', 'daimos_v1592_first_slot', 0),
        ('second owner missing', 'daimos_v1592_second_slot', 0),
        ('same selected process twice', 'daimos_v1592_second_slot',
         original['first_slot']),
        ('first PI6 wake lost', 'daimos_v1592_first_woke', 0),
        ('second PI6 wake lost', 'daimos_v1592_second_woke', 0),
        ('false duplicate PI6 wake', 'daimos_v1592_second_woke', 2),
        ('only one timer armed', 'daimos_v1585_armed', 1),
        ('timer did not wake second', 'daimos_v1585_woke', 0),
        ('second slot mismatch', 'daimos_v1585_slot',
         original['first_slot']),
        ('rollback not completed', 'daimos_v1588_rollback_count', 0),
        ('failed owner lost', 'daimos_v1588_owner_after', 0),
        ('BACKSTORE bitmap corrupted', 'daimos_v1588_bitmap_differences', 1),
        ('MM rollback extent leaked', 'daimos_v1588_mm_after',
         failed['mm_before']),
        ('TERM not sent', 'daimos_v1588_term_events', 0),
        ('transition not removed', 'daimos_v1588_process_after',
         failed['process_before']),
        ('neither timer armed', 'daimos_v1585_armed', 0),
    ):
        assert symbol in linked
        if symbol == 'daimos_v1585_woke':
            assert clock['daimos_v1585_woke'] == 1
        pat = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % \
            linked[symbol]
        assert len(re.findall(pat, oldtail)) == 1
        changed = re.sub(pat, lambda m: m.group(1) +
                         '%012o' % corrupted + m.group(3), oldtail, count=1)
        try:
            check(mapping, a4, a5, a8, a2,
                  [oldhead + 'HALT instruction, PC:' + changed, logs[1]],
                  media)
        except (AssertionError, KeyError):
            print('PASS v1592: rejected ' + label)
        else:
            raise AssertionError('accepted false two-owner: ' + label)
    base.selftest(mapping, a4, logs, media)


def main():
    args = sys.argv[1:]
    negatives = '--self-test' in args
    if negatives:
        args.remove('--self-test')
    if len(args) != 9:
        raise SystemExit('usage: v1592 [--self-test] MAP ADDR4 ADDR5 ADDR8 '
                         'ADDR1592 BOOT1 BOOT2 DRUM_DIR REPORT')
    mapping, a4, a5, a8, a2, log1, log2 = [
        Path(path).read_text(errors='replace') for path in args[:7]]
    directory = Path(args[7])
    media = [(directory / ('dsk%d.dsk' % i)).read_bytes()
             for i in range(4)]
    owners, physical = check(mapping, a4, a5, a8, a2,
                             [log1, log2], media)
    unit, block, pool, occupied = physical
    report = ['PASS v1592: two original PI6 DISK owners per boot, '
              'mapped physical MEMFS snapshot DR%d:%06o pool=%d, '
              '%d nonzero backing sectors' %
              (unit, block, pool, occupied)]
    for index, (two, failed, base) in enumerate(owners, 1):
        report.append('BOOT %d: original timer slots=%d/%d, PI6=1/1, '
                      'selected failed owner=%d, rollback=1, '
                      'original swap started=%d completed=%d PI2=%d' %
                      (index, two['first_slot'], two['second_slot'],
                       failed['slot'], base['daimos_v1584_swap_started'],
                       base['daimos_v1584_swap_completed'],
                       base['daimos_v1584_swap_pi2']))
    result = '\n'.join(report) + '\n'
    Path(args[8]).write_text(result)
    print(result, end='')
    if negatives:
        negative_tests(mapping, a4, a5, a8, a2, [log1, log2], media)


if __name__ == '__main__':
    main()
