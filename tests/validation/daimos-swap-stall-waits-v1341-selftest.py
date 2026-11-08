#!/usr/bin/env python3
"""Synthetic source-linked wait decoder regression and negative cases."""

from pathlib import Path
import os
import runpy
import tempfile

ROOT = Path(__file__).resolve().parent
MODULE = runpy.run_path(str(ROOT / 'daimos-swap-stall-waits-v1341.py'))


def sample(clock):
    base = 0o17000
    values = {0o25353: base, 0o25357: 7, 0o23741: clock}
    states = {
        1: 0o340024000000,          # CHILD wait
        2: 0o360024051435,          # interruptible event
        3: 0o320024400334,          # timed wait
        4: 0o320024023433,          # FS provider event
        5: 0o320024400002,          # timed wait
        6: 0o320024023731,          # disposable holder event
    }
    for slot in range(7):
        values[base + slot * 3] = 0o200001
        values[base + slot * 3 + 1] = 0o64000000000
        values[base + slot * 3 + 2] = states.get(slot, 0)
    return ('Simulation stopped, PC: 001234\n' +
            ''.join('sim> %o: %012o\n' % (addr, value)
                    for addr, value in sorted(values.items())))


def main():
    tmp = os.environ.get('TMPDIR') or str(Path.home() / 'tmp')
    with tempfile.TemporaryDirectory(prefix='daimos-v1341-', dir=tmp) as root:
        path = Path(root)
        linked = path / 'linked.map'
        raw = path / 'simh.raw'
        linked.write_text('proc_table 025353\nproc_high_slot 025357\n'
                          'proc_timer_clock 023741\n'
                          'fs_provider_wait_event_v917 023433\n'
                          'daimos_test_hold_event_v1150 023731\n')
        raw.write_text(sample(0) + sample(1))
        snapshots = MODULE['decode'](MODULE['symbols'](linked), raw)
        assert len(snapshots) == 2
        states = {entry['slot']: entry for entry in snapshots[-1][1]}
        assert states[1]['kind'] == 'CHILD'
        assert states[2]['kind'] == 'INTR'
        assert states[3]['kind'] == 'TIMER'
        assert states[4]['symbol'] == ['fs_provider_wait_event_v917']
        assert states[5]['kind'] == 'TIMER'
        assert states[6]['symbol'] == ['daimos_test_hold_event_v1150']
        for name, broken in (
                ('missing-clock', raw.read_text().replace('sim> 23741:',
                                                          'sim> 23742:')),
                ('missing-table', raw.read_text().replace('sim> 25353:',
                                                          'sim> 25354:')),
                ('missing-descriptor', raw.read_text().replace(
                    'sim> 17022:', 'sim> 17023:'))):
            raw.write_text(broken)
            try:
                MODULE['decode'](MODULE['symbols'](linked), raw)
            except ValueError:
                continue
            raise AssertionError('accepted unsafe raw trace: ' + name)
    print('v1341: linked wait decoding and three missing-evidence '
          'negative controls PASS')


if __name__ == '__main__':
    main()
