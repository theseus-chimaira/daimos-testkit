#!/usr/bin/env python3
"""Verify post-DMA checked-release refusal and original PDP-6 MM rollback.

Read both actual 128K physical guest HALTs, linked process/BCACHE/MM and
full backing-bitmap boundary witnesses, real PI6 and DRM PI2 counts,
and the same four original D6FSR2 physical members across cold boots.
"""

from pathlib import Path
import importlib.util
import re
import sys

MASK36 = (1 << 36) - 1
TRANSITION = 0o200000
KEYS = (
    'fault_armed', 'release_refusals', 'rollback_count', 'term_events',
    'slot', 'allocated_base', 'mm_before', 'mm_after',
    'owner_before', 'owner_after', 'backing_before', 'backing_after',
    'bitmap_words', 'bitmap_differences', 'record_before', 'record_after',
    'process_before', 'process_after', 'process_word1_before',
    'process_word1_after', 'process_word2_before', 'process_word2_after',
    'bcache_state_before', 'bcache_state_after',
    'bcache_tag_before', 'bcache_tag_after',
    'bcache_private_before', 'bcache_private_after',
    'storage_expect_after', 'extent_still_present', 'in_request',
)


def imported(name, key):
    path = Path(__file__).with_name(name)
    spec = importlib.util.spec_from_file_location(key, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def extract(mapping, addresses, transcript):
    known = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                     'v1584_base').get_symbols(mapping)
    linked = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                      'v1584_linked').get_symbols(addresses)
    assert transcript.count('HALT instruction, PC:') == 1
    tail = transcript.split('HALT instruction, PC:', 1)[1]
    values = {}
    for key in KEYS:
        name = 'daimos_v1588_' + key
        assert name in linked and name in known
        assert known[name] == linked[name], 'stale linked witness ' + name
        pattern = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % linked[name]
        found = re.findall(pattern, tail)
        assert len(found) == 1, 'missing genuine post-HALT ' + name
        values[key] = int(found[0], 8)
    return values


def check(mapping, addr4, addr5, addr8, logs, media):
    physical = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                        'v1584_physical')
    timed = imported('daimos-p1c-snapshot-timer-verify-v1585.py',
                     'v1585_timed')
    first, second, unit, block, pool, occupied = physical.check(
        mapping, addr4, logs, media, True)
    observed = []
    for boot, (log, earlier) in enumerate(zip(logs, (first, second)), start=1):
        values = extract(mapping, addr8, log)
        timer = timed.extract(mapping, addr5, log)
        assert timer['daimos_v1585_armed'] == 1
        assert timer['daimos_v1585_woke'] == 1
        assert timer['daimos_v1585_slot'] == values['slot']
        assert ((timer['daimos_v1585_end_tick'] -
                 timer['daimos_v1585_start_tick']) & 0o377777) > 0
        assert values['release_refusals'] == 1, \
            'no selected real post-read BACKSTORE release refusal'
        assert values['fault_armed'] == 0
        assert values['in_request'] == 0
        assert values['rollback_count'] == 1, \
            'original MM post-unpin rollback not completed exactly once'
        assert values['term_events'] == 1, 'failed owner TERM not sent'
        assert 0 < values['slot'] < 24
        assert values['allocated_base'] > 0
        assert values['allocated_base'] % 0o2000 == 0
        assert values['mm_before'] > 0
        assert values['mm_before'] == values['mm_after'] + 1
        assert values['extent_still_present'] == 0
        assert values['owner_before'] == values['owner_after'] > 0, \
            'original DISK owner lost in post-I/O rollback'
        assert values['backing_before'] == values['backing_after'] > 0
        assert values['bitmap_words'] == \
            (earlier['backing_region_count'] + 35) // 36
        assert 0 < values['bitmap_words'] <= 0o100
        assert values['bitmap_differences'] == 0, \
            'complete process-owned BACKSTORE bitmap changed on refusal'
        assert values['record_before'] == values['record_after'] != 0
        assert values['process_before'] & TRANSITION
        assert values['process_after'] == \
            (values['process_before'] & (MASK36 ^ TRANSITION))
        for word in ('process_word1', 'process_word2'):
            assert values[word + '_before'] == values[word + '_after']
        for word in ('bcache_state', 'bcache_tag', 'bcache_private'):
            assert values[word + '_before'] == values[word + '_after'], \
                'BCACHE ' + word + ' modified by post-DMA rollback'
        assert values['storage_expect_after'] == 0, \
            'original packed DISK mode was incorrectly published RESIDENT'
        assert earlier['daimos_v1584_swap_started'] >= 2
        assert earlier['daimos_v1584_swap_started'] == \
            earlier['daimos_v1584_swap_completed'] + 1, \
            'exactly one refused post-DMA swap-in expected'
        assert earlier['daimos_v1584_swap_reads'] == \
            earlier['daimos_v1584_swap_started'], \
            'refused release must follow completed physical BACKSTORE READ'
        assert earlier['daimos_v1584_swap_pi2'] >= \
            earlier['daimos_v1584_swap_reads'], \
            'no real physical Type-236 PI2 for selected swap READ'
        assert earlier['mfsdev_storage_errors'] == 0
        observed.append((values, earlier))
    return observed, (unit, block, pool, occupied)


def selftest(mapping, addr4, addr5, addr8, logs, media):
    physical = imported('daimos-p1c-snapshot-swap-verify-v1584.py',
                        'v1584_negatives')
    physical.selftest(mapping, addr4, logs, media)
    linked = physical.get_symbols(addr8)
    source = extract(mapping, addr8, logs[0])
    front, tail = logs[0].split('HALT instruction, PC:', 1)
    mutants = (
        ('no post-DMA release refusal', 'release_refusals', 0),
        ('no actual MM rollback', 'rollback_count', 0),
        ('no failed owner TERM', 'term_events', 0),
        ('fault still armed', 'fault_armed', 1),
        ('orphaned release-call marker', 'in_request', 1),
        ('wrong owner slot', 'slot', 0),
        ('unallocated physical VM', 'allocated_base', 0),
        ('leaked physical MM extent', 'mm_after', source['mm_before']),
        ('MM table still contains new extent', 'extent_still_present', 1),
        ('unexamined bitmap span', 'bitmap_words', 1),
        ('modified exact bitmap', 'bitmap_differences', 1),
        ('changed process backing ownership', 'owner_after', 0),
        ('changed used BACKSTORE blocks', 'backing_after', 0),
        ('lost existing DISK record', 'record_after', 0),
        ('orphaned transition', 'process_after', source['process_before']),
        ('changed original process words', 'process_word1_after', 0),
        ('changed physical process pointer', 'process_word2_after', 0),
        ('BCACHE slab corrupted', 'bcache_state_after', MASK36),
        ('BCACHE workspace tag corrupted', 'bcache_tag_after', 0),
        ('BCACHE private tag corrupted', 'bcache_private_after', 1),
        ('published RESIDENT after error', 'storage_expect_after', MASK36),
    )
    for label, key, value in mutants:
        symbol = 'daimos_v1588_' + key
        pat = (r'(?m)^((?:sim>\s*)?0*%o:\s*)'
               r'([0-7]{1,12})(\s*)$') % linked[symbol]
        assert len(re.findall(pat, tail)) == 1
        changed = re.sub(pat,
                         lambda m: m.group(1) + '%012o' % value + m.group(3),
                         tail, count=1)
        try:
            check(mapping, addr4, addr5, addr8,
                  [front + 'HALT instruction, PC:' + changed, logs[1]],
                  media)
        except (AssertionError, KeyError):
            print('PASS v1588: rejected ' + label)
        else:
            raise AssertionError('accepted false postread rollback: ' + label)


def main():
    args = sys.argv[1:]
    negatives = '--self-test' in args
    if negatives:
        args.remove('--self-test')
    if len(args) != 8:
        raise SystemExit('usage: v1588 [--self-test] MAP ADDR4 ADDR5 '
                         'ADDR8 BOOT1 BOOT2 DRUM_DIR REPORT')
    mapping, addr4, addr5, addr8, boot1, boot2 = [
        Path(arg).read_text(errors='replace') for arg in args[:6]]
    drum = Path(args[6])
    media = [(drum / ('dsk%d.dsk' % unit)).read_bytes()
             for unit in range(4)]
    logs = [boot1, boot2]
    observed, physical = check(mapping, addr4, addr5, addr8, logs, media)
    unit, block, pool, occupied = physical
    result = ('PASS v1588: real two-boot 128K PDP-6 physical snapshot '
              'DR%d:%06o pool=%d, %d nonzero other BACKSTORE sectors\n' %
              (unit, block, pool, occupied))
    for index, (values, original) in enumerate(observed, start=1):
        result += ('BOOT %d: selected release refusal=1, MM %d->%d, '
                   'exact bitmap %d words identical, owner %06o, '
                   'BCACHE metadata unchanged, real swap READs=%d, '
                   'resident publications=%d, matched DRM PI2=%d\n' %
                   (index, values['mm_before'], values['mm_after'],
                    values['bitmap_words'], values['owner_after'],
                    original['daimos_v1584_swap_reads'],
                    original['daimos_v1584_swap_completed'],
                    original['daimos_v1584_swap_pi2']))
    Path(args[7]).write_text(result)
    print(result, end='')
    if negatives:
        selftest(mapping, addr4, addr5, addr8, logs, media)


if __name__ == '__main__':
    main()
