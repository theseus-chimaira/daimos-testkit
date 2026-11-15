#!/usr/bin/env python3
"""Independent v1585 PI6 timer to slot-0 swap restore physical oracle.

Read actual linked PDP-6 values, two HALT transcripts and all four raw
Type-236 members. Healthy snapshot success alone does not pass the
strict overlap gate. Require the original v1584 independent PI2 and
DISK->RESIDENT publication criteria in *both* cold boots as well as
the one-tick timer arm and real PI6 timer service wakeup.
"""

from pathlib import Path
import importlib.util
import re
import sys

NAMES = ('daimos_v1585_slot', 'daimos_v1585_armed',
         'daimos_v1585_woke', 'daimos_v1585_start_tick',
         'daimos_v1585_end_tick')


def base_verifier():
    path = Path(__file__).with_name('daimos-p1c-snapshot-swap-verify-v1584.py')
    spec = importlib.util.spec_from_file_location('v1584_physical', path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def extract(mapping, addresses, transcript):
    known = base_verifier().get_symbols(mapping)
    linked = base_verifier().get_symbols(addresses)
    marker = 'HALT instruction, PC:'
    assert transcript.count(marker) == 1
    after = transcript.split(marker, 1)[1]
    values = {}
    for name in NAMES:
        assert name in known and name in linked
        assert known[name] == linked[name], 'linked counter drift: ' + name
        pat = r'(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$' % linked[name]
        matches = re.findall(pat, after)
        assert len(matches) == 1, 'not an original post-HALT word ' + name
        values[name] = int(matches[0], 8)
    return values


def verify(mapping, addr4, addr5, logs, media, strict):
    base = base_verifier()
    results = base.check(mapping, addr4, logs, media, False)
    measured = [extract(mapping, addr5, log) for log in logs]
    report = []
    for i, (values, original) in enumerate(zip(measured, results[:2])):
        elapsed = ((values['daimos_v1585_end_tick'] -
                    values['daimos_v1585_start_tick']) & 0o377777)
        report.append('BOOT %d timer armed=%d woke=%d slot=%d ticks=%d '
                      'independent started=%d committed=%d matched_PI2=%d' %
                      (i + 1, values['daimos_v1585_armed'],
                       values['daimos_v1585_woke'],
                       values['daimos_v1585_slot'], elapsed,
                       original['daimos_v1584_swap_started'],
                       original['daimos_v1584_swap_completed'],
                       original['daimos_v1584_swap_pi2']))
        if strict:
            assert values['daimos_v1585_armed'] == 1, \
                'no genuine timed sleeping DISK candidate at shutdown'
            assert values['daimos_v1585_woke'] >= 1, \
                'original PI6 timer service failed to wake candidate'
            assert 0 < values['daimos_v1585_slot'] < 24
            assert elapsed > 0, 'real clock never passed snapshot boundary'
            assert original['daimos_v1584_swap_started'] > 0, \
                'original slot-0 scheduler did not restore awakened slot'
            assert original['daimos_v1584_swap_reads'] > 0, \
                'no genuine mapped BACKSTORE swap READ'
            assert original['daimos_v1584_swap_pi2'] > 0, \
                'no matched original Type-236 DR_DONE'
            assert original['daimos_v1584_swap_completed'] > 0, \
                'original DISK-to-RESIDENT publication did not complete'
    if strict:
        base.check(mapping, addr4, logs, media, True)
    return results, measured, report


def selftest(mapping, addr4, addr5, logs, media):
    # First rerun the inherited full physical v1584 negative matrix,
    # including the extra real swap/PI2 witnesses now nonzero.
    base_verifier().selftest(mapping, addr4, logs, media)
    linked = base_verifier().get_symbols(addr5)
    original = extract(mapping, addr5, logs[0])
    head, tail = logs[0].split('HALT instruction, PC:', 1)
    mutations = [('missing arm', 'daimos_v1585_armed', 0),
                 ('missing PI6 wakeup', 'daimos_v1585_woke', 0),
                 ('missing child slot', 'daimos_v1585_slot', 0),
                 ('no snapshot clock span', 'daimos_v1585_end_tick',
                  original['daimos_v1585_start_tick'])]
    for label, name, value in mutations:
        pat = r'(?m)^((?:sim>\s*)?0*%o:\s*)([0-7]{1,12})(\s*)$' % linked[name]
        assert len(re.findall(pat, tail)) == 1
        changed = re.sub(pat, lambda m: m.group(1) + '%012o' % value +
                         m.group(3), tail, count=1)
        try:
            verify(mapping, addr4, addr5,
                   [head + 'HALT instruction, PC:' + changed, logs[1]],
                   media, True)
        except (AssertionError, KeyError):
            print('PASS v1585: rejected ' + label)
        else:
            raise AssertionError('accepted invalid physical PI6 evidence ' + label)


def main():
    args = sys.argv[1:]
    negative = '--self-test' in args
    if negative:
        args.remove('--self-test')
    if len(args) != 7:
        raise SystemExit('usage: verifier [--self-test] MAP ADDR4 ADDR5 '
                         'BOOT1 BOOT2 DRUM_DIR REPORT')
    mapping, addr4, addr5, boot1, boot2 = [
        Path(path).read_text(errors='replace') for path in args[:5]]
    drum = Path(args[5])
    media = [(drum / ('dsk%d.dsk' % unit)).read_bytes()
             for unit in range(4)]
    logs = [boot1, boot2]
    # Always publish the observed counters, even if strict acceptance fails.
    _, measured, report = verify(mapping, addr4, addr5, logs, media, False)
    Path(args[6]).write_text('\n'.join(report) + '\n')
    print('\n'.join(report))
    verify(mapping, addr4, addr5, logs, media, True)
    if negative:
        selftest(mapping, addr4, addr5, logs, media)
    print('PASS v1585: true timer-driven independent swap-in across physical PI2')


if __name__ == '__main__':
    main()
