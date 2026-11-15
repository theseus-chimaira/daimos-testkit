#!/usr/bin/env python3
"""Prove exact successful slot-7 publication and physical DRM FSINFO.

Retain original v1592 independent two-owner, MM, physical PI2/media
checks; append only post-commit owner/VM and actual FSINFO witnesses.
"""

from pathlib import Path
import importlib.util
import re
import sys

FIELDS = ('first_published', 'second_published', 'second_slot',
          'second_procword', 'second_vm', 'second_record',
          'second_uarea_backing')


def load(name, label):
    spec = importlib.util.spec_from_file_location(label,
        Path(__file__).with_name(name))
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def extract(mapping, addresses, transcript):
    base = load('daimos-p1c-snapshot-swap-verify-v1584.py', 'map_v1593')
    original = base.get_symbols(mapping)
    linked = base.get_symbols(addresses)
    assert transcript.count('HALT instruction, PC:') == 1
    after = transcript.split('HALT instruction, PC:', 1)[1]
    result = {}
    for key in FIELDS:
        name = 'daimos_v1593_' + key
        assert name in linked and name in original
        assert linked[name] == original[name], 'stale v1593 link ' + key
        pattern = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % linked[name]
        found = re.findall(pattern, after)
        assert len(found) == 1, 'no genuine v1593 memory word ' + key
        result[key] = int(found[0], 8)
    return result


def check(mapping, a4, a5, a8, a2, a3, logs, media):
    previous = load('daimos-p1c-two-owner-verify-v1592.py',
                    'original_two_owners_v1593')
    existing, physical = previous.check(mapping, a4, a5, a8, a2,
                                        logs, media)
    results = []
    for transcript, (two, failed, base) in zip(logs, existing):
        assert 'P1D-D6FS-DRM-CAPACITY6-V1593' in transcript, \
            'no original D6FS DRM-root FSINFO guest check'
        published = extract(mapping, a3, transcript)
        # A slot may have succeeded at an earlier transaction before
        # later being swapped again and selected for a refused release.
        # A successful publication is not a permanent per-slot status.
        assert published['first_published'] <= \
            base['daimos_v1584_swap_completed'], \
            'failed slot publication count exceeds all successful swaps'
        assert published['second_published'] == 1, \
            'specific second real owner never published'
        assert published['second_slot'] == two['second_slot'], \
            'different slot was published instead of timer-woken owner'
        assert published['second_slot'] != failed['slot'], \
            'different selected release-refusal transaction owner'
        assert published['second_vm'] > 0 and \
            published['second_vm'] % 0o2000 == 0, \
            'published owner has no aligned resident VM'
        assert published['second_record'] != 0, \
            'successful owner did not retain its original stable image key'
        assert published['second_uarea_backing'] == 0, \
            'successful owner retains the old disk BACKSTORE record'
        assert published['second_procword'] & 0o400000, \
            'published owner has no stable u-area'
        assert not published['second_procword'] & 0o200000, \
            'success left process in TRANSITION'
        assert base['daimos_v1584_swap_completed'] == 4
        results.append(published)
    return results, existing, physical


def negatives(mapping, a4, a5, a8, a2, a3, logs, media):
    old = load('daimos-p1c-snapshot-swap-verify-v1584.py',
               'symbols_negative_v1593')
    linked = old.get_symbols(a3)
    previous = load('daimos-p1c-two-owner-verify-v1592.py',
                    'two_owners_negative_v1593')
    own = previous.owner_extract(mapping, a2, logs[0])
    actual = extract(mapping, a3, logs[0])
    before, after = logs[0].split('HALT instruction, PC:', 1)
    for label, field, value in (
        ('impossible first owner publication count', 'first_published', 5),
        ('successful slot absent', 'second_published', 0),
        ('double publication', 'second_published', 2),
        ('wrong published slot', 'second_slot', own['first_slot']),
        ('unaligned resident VM', 'second_vm', 1),
        ('missing committed swap record', 'second_record', 0),
        ('stale disk owner after success', 'second_uarea_backing', 1),
        ('orphaned process transition', 'second_procword',
         actual['second_procword'] | 0o200000),
        ('no stable process u-area', 'second_procword',
         actual['second_procword'] & ~0o400000),
    ):
        symbol = 'daimos_v1593_' + field
        pat = (r'(?m)^((?:sim>\s*)?0*%o:\s*)'
               r'([0-7]{1,12})(\s*)$') % linked[symbol]
        assert len(re.findall(pat, after)) == 1
        changed = re.sub(pat, lambda m: m.group(1) +
                         '%012o' % value + m.group(3), after, count=1)
        try:
            check(mapping, a4, a5, a8, a2, a3,
                  [before + 'HALT instruction, PC:' + changed, logs[1]],
                  media)
        except (AssertionError, KeyError):
            print('PASS v1593: rejected ' + label)
        else:
            raise AssertionError('accepted false publication: ' + label)
    # Also require actual guest FSINFO execution, not just KINIT symbols.
    broken = logs[0].replace('P1D-D6FS-DRM-CAPACITY6-V1593',
                             'P1D-D6FS-DRM-CAPACITY-INVALID', 1)
    try:
        check(mapping, a4, a5, a8, a2, a3, [broken, logs[1]], media)
    except AssertionError:
        print('PASS v1593: rejected absent physical D6FS-root FSINFO')
    else:
        raise AssertionError('accepted absent physical D6FS inventory')
    previous.negative_tests(mapping, a4, a5, a8, a2, logs, media)


def main():
    args = sys.argv[1:]
    selftest = '--self-test' in args
    if selftest:
        args.remove('--self-test')
    if len(args) != 10:
        raise SystemExit('usage: v1593 [--self-test] MAP ADDR4 ADDR5 ADDR8 '
                         'ADDR1592 ADDR1593 BOOT1 BOOT2 DRUMDIR REPORT')
    mapping, a4, a5, a8, a2, a3, l1, l2 = [
        Path(arg).read_text(errors='replace') for arg in args[:8]]
    media = [(Path(args[8]) / ('dsk%d.dsk' % i)).read_bytes()
             for i in range(4)]
    results, original, physical = check(mapping, a4, a5, a8, a2, a3,
                                         [l1, l2], media)
    unit, block, pool, occupied = physical
    lines = ['PASS v1593: real two-owner physical snapshot DR%d:%06o '
             'pool=%d nonzero=%d; D6FS-root FSINFO capacity=6' %
             (unit, block, pool, occupied)]
    for index, (published, (_, _, base)) in enumerate(
            zip(results, original), 1):
        lines.append('BOOT %d: first-slot earlier/other successful commits=%d; '
                     'successful independent second slot=%d, VM=%06o, '
                     'uarea backing=0, four total publications, '
                     'original physical PI2=%d' %
                     (index, published['first_published'],
                      published['second_slot'],
                      published['second_vm'],
                      base['daimos_v1584_swap_pi2']))
    report = '\n'.join(lines) + '\n'
    Path(args[9]).write_text(report)
    print(report, end='')
    if selftest:
        negatives(mapping, a4, a5, a8, a2, a3, [l1, l2], media)


if __name__ == '__main__':
    main()
