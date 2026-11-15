#!/usr/bin/env python3
"""Audit original MM/owner/backing/BCACHE rollback during physical snapshot.

Both cold boots must recover the actual MEMFS XIP and LOGSTORE. An
independent full guest's real slot-0 MM allocation is followed by one
test-induced pin refusal; original mm_free and DISK-mode rollback must
preserve every bitmap word and BCACHE metadata at the transaction
boundary, before the scheduler's ordinary TERM event can discard owner.
"""

from pathlib import Path
import importlib.util
import re
import sys

MASK36 = (1 << 36) - 1
TRANSITION = 0o200000
KEYS = (
    'fault_armed', 'pin_refusals', 'rollback_count', 'term_events',
    'slot', 'allocated_base', 'mm_before', 'mm_after',
    'owner_before', 'owner_after', 'backing_before', 'backing_after',
    'bitmap_words', 'bitmap_differences', 'record_before', 'record_after',
    'process_before', 'process_after', 'process_word1_before',
    'process_word1_after', 'process_word2_before', 'process_word2_after',
    'bcache_state_before', 'bcache_state_after',
    'bcache_tag_before', 'bcache_tag_after',
    'bcache_private_before', 'bcache_private_after',
    'storage_expect_after', 'extent_still_present',
)


def baseline():
    path = Path(__file__).with_name('daimos-p1c-snapshot-swap-verify-v1584.py')
    spec = importlib.util.spec_from_file_location('v1584_rollback_base', path)
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def timer():
    path = Path(__file__).with_name('daimos-p1c-snapshot-timer-verify-v1585.py')
    spec = importlib.util.spec_from_file_location('v1585_rollback_timer', path)
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def captures(mapping, addresses, transcript):
    symbols = baseline().get_symbols(mapping)
    linked = baseline().get_symbols(addresses)
    marker = 'HALT instruction, PC:'
    assert transcript.count(marker) == 1, 'not one normal full guest HALT'
    after = transcript.split(marker, 1)[1]
    witness = {}
    for suffix in KEYS:
        name = 'daimos_v1587_' + suffix
        assert name in symbols and name in linked
        assert symbols[name] == linked[name], 'stale KCORE map: ' + name
        pattern = (r'(?m)^(?:sim>\s*)?0*%o:\s*'
                   r'([0-7]{1,12})\s*$') % linked[name]
        hits = re.findall(pattern, after)
        assert len(hits) == 1, 'missing exact original witness: ' + name
        witness[suffix] = int(hits[0], 8)
    return witness


def check(mapping, addr4, addr5, addr7, logs, media):
    base = baseline()
    checked = base.check(mapping, addr4, logs, media)
    # Base checks two original physical PDP-6 cold boots, actual PI2,
    # restored MEMFS/XIP/LOGSTORE, physical v2 header and root VOLUME.
    timer_check = timer()
    witnesses = []
    for index, transcript in enumerate(logs):
        original = checked[index]
        timed = timer_check.extract(mapping, addr5, transcript)
        witness = captures(mapping, addr7, transcript)
        assert timed['daimos_v1585_armed'] == 1
        assert timed['daimos_v1585_woke'] == 1
        assert timed['daimos_v1585_slot'] == witness['slot']
        assert ((timed['daimos_v1585_end_tick'] -
                 timed['daimos_v1585_start_tick']) & 0o377777) > 0
        assert original['daimos_v1584_swap_started'] >= 1, \
            'no independent scheduler transaction'
        assert original['daimos_v1584_snapshot_pi2'] > 0
        assert original['mfsdev_storage_errors'] == 0

        assert witness['fault_armed'] == 0
        assert witness['pin_refusals'] == 1, 'no single selected pin refusal'
        assert witness['rollback_count'] == 1, 'not one original MM rollback'
        assert witness['term_events'] == 1, 'original owner failure event missing'
        assert 0 < witness['slot'] < 24
        assert witness['allocated_base'] > 0
        assert witness['allocated_base'] % 0o2000 == 0
        assert witness['mm_before'] > 0
        assert witness['mm_after'] + 1 == witness['mm_before'], \
            'original MM extent was not removed by mm_free'
        assert witness['extent_still_present'] == 0, \
            'newly allocated physical VM base still appears in MM table'
        assert witness['bitmap_words'] == \
            (original['backing_region_count'] + 35) // 36
        assert 0 < witness['bitmap_words'] <= 0o100
        assert witness['bitmap_differences'] == 0, \
            'a real BACKSTORE bitmap word changed during failed pin rollback'
        assert witness['owner_before'] == witness['owner_after'] > 0, \
            'original process swap ownership mutated during rollback'
        assert witness['backing_before'] == witness['backing_after'] > 0, \
            'original BACKSTORE used-block count mutated during rollback'
        assert witness['record_before'] == witness['record_after'] != 0, \
            'original disk backing record was lost or replaced'
        assert witness['process_before'] & TRANSITION, \
            'real independent swap-in did not hold transition'
        assert witness['process_after'] == \
            (witness['process_before'] & (MASK36 ^ TRANSITION)), \
            'transition lock not cleared precisely'
        for word in ('process_word1', 'process_word2'):
            assert witness[word + '_before'] == witness[word + '_after'], \
                'original process descriptor other word changed: ' + word
        for word in ('bcache_state', 'bcache_tag', 'bcache_private'):
            assert witness[word + '_before'] == witness[word + '_after'], \
                'BCACHE metadata changed during pre-I/O MM failure: ' + word
        assert witness['storage_expect_after'] == 0, \
            'original process storage mode lost authoritative DISK state'
        witnesses.append(witness)
    return checked, witnesses


def negative(mapping, addr4, addr5, addr7, logs, media):
    # Retain the inherited fully independent raw-physical metadata tests.
    baseline().selftest(mapping, addr4, logs, media)
    keys = baseline().get_symbols(addr7)
    before, after = logs[0].split('HALT instruction, PC:', 1)
    data = captures(mapping, addr7, logs[0])
    mutant = (
        ('unconsumed pin fault arm', 'fault_armed', 1),
        ('missing MM refusal', 'pin_refusals', 0),
        ('missing MM rollback', 'rollback_count', 0),
        ('missing TERM event', 'term_events', 0),
        ('wrong selected slot', 'slot', 0),
        ('missing allocated base', 'allocated_base', 0),
        ('leaked MM extent', 'mm_after', data['mm_before']),
        ('lost MM process extent', 'extent_still_present', 1),
        ('changed backing bitmap', 'bitmap_differences', 1),
        ('wrong full bitmap span', 'bitmap_words', 1),
        ('lost owner count', 'owner_after', 0),
        ('wrong backing count', 'backing_after', 0),
        ('lost disk record', 'record_after', 0),
        ('orphaned transition', 'process_after', data['process_before']),
        ('altered process image', 'process_word1_after', 0),
        ('modified process scheduler', 'process_word2_after', 0),
        ('BCACHE slab changed', 'bcache_state_after', MASK36),
        ('BCACHE workspace tag changed', 'bcache_tag_after', MASK36 ^
         data['bcache_tag_before']),
        ('BCACHE private tag changed', 'bcache_private_after', MASK36 ^
         data['bcache_private_before']),
        ('DISK mode changed', 'storage_expect_after', MASK36),
    )
    for label, suffix, corrupted in mutant:
        address = keys['daimos_v1587_' + suffix]
        pattern = (r'(?m)^((?:sim>\s*)?0*%o:\s*)'
                   r'([0-7]{1,12})(\s*)$') % address
        assert len(re.findall(pattern, after)) == 1
        changed = re.sub(pattern, lambda m: m.group(1) +
                         '%012o' % corrupted + m.group(3), after, count=1)
        try:
            check(mapping, addr4, addr5, addr7,
                  [before + 'HALT instruction, PC:' + changed, logs[1]],
                  media)
        except (AssertionError, KeyError):
            print('PASS v1587: rejected ' + label)
        else:
            raise AssertionError('accepted invalid recoverable MM witness: '
                                 + label)


def main():
    args = sys.argv[1:]
    mutants = '--self-test' in args
    if mutants:
        args.remove('--self-test')
    if len(args) != 8:
        raise SystemExit('usage: verifier [--self-test] MAP ADDR4 ADDR5 '
                         'ADDR7 BOOT1 BOOT2 DRUM_DIR REPORT')
    mapping, addr4, addr5, addr7, boot1, boot2 = [
        Path(name).read_text(errors='replace') for name in args[:6]]
    drum = Path(args[6])
    media = [(drum / ('dsk%d.dsk' % unit)).read_bytes()
             for unit in range(4)]
    logs = [boot1, boot2]
    physical, values = check(mapping, addr4, addr5, addr7, logs, media)
    message = '\n'.join(
        ('BOOT %d: original pin refusal=%d MM rollback=%d TERM=%d '
         'slot=%d allocated=%06o MM=%d->%d exact bitmap=%d words '
         'mismatches=%d backing=%o mode=DISK cache=unchanged' %
         (i + 1, item['pin_refusals'], item['rollback_count'],
          item['term_events'], item['slot'], item['allocated_base'],
          item['mm_before'], item['mm_after'], item['bitmap_words'],
          item['bitmap_differences'], item['backing_after']))
        for i, item in enumerate(values))
    message += ('\nPASS v1587: both real cold boots restored committed '
                'mapped MEMFS/LOGSTORE after exact original pre-I/O MM '
                'rollback; physical DR%d header block %06o\n' %
                (physical[2], physical[3]))
    # The caller prints this only after an already-validated physical pass.
    Path(args[7]).write_text(message)
    print(message, end='')
    if mutants:
        negative(mapping, addr4, addr5, addr7, logs, media)


if __name__ == '__main__':
    main()
