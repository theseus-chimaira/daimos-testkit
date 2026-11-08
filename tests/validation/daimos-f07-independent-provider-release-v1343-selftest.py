#!/usr/bin/env python3
"""Fail-closed static regression for disposable provider-release hook."""

from pathlib import Path
import os
import runpy
import tempfile

HERE = Path(__file__).resolve().parent
inject = runpy.run_path(str(HERE /
    'daimos-f07-independent-provider-release-v1343.py'))['inject']

SOURCE = '''daimos_test_maybe_release_v1150:
        move    0,daimos_test_fatal_busy_v1150
        caige   0,2
        jrst    daimos_test_sleep_normal_v1150
        setom   daimos_test_release_v1150
        setom   daimos_test_hold_event_v1150
        pushj   17,proc_wakeup_event
daimos_test_not_init_v1150:
        skipn   daimos_test_predispatch_v1150
        jrst    daimos_test_sleep_normal_v1150
        aos     daimos_test_spinner_v1150
daimos_test_sleep_normal_v1150:
        hrrz    1,1
'''


def main():
    tmp = os.environ.get('TMPDIR') or str(Path.home() / 'tmp')
    with tempfile.TemporaryDirectory(prefix='daimos-v1343-', dir=tmp) as d:
        root = Path(d)
        (root / 'proc').mkdir()
        path = root / 'proc/proc_pdp6.s'
        path.write_text(SOURCE)
        inject(root)
        changed = path.read_text()
        assert changed.count('jrst    daimos_test_maybe_release_v1150') == 1
        assert changed.count('caige   0,2') == 1
        assert changed.count('setom   daimos_test_release_v1150') == 1
        assert changed.count('pushj   17,proc_wakeup_event') == 1
        assert changed.index('skipn   daimos_test_real_oom_v1150') < \
               changed.index('jrst    daimos_test_maybe_release_v1150')
        for name, bad in (
                ('missing-spinner', SOURCE.replace(
                    'aos     daimos_test_spinner_v1150',
                    'setzm   daimos_test_spinner_v1150')),
                ('missing-busy-gate', SOURCE.replace(
                    'caige   0,2', 'caige   0,1')),
                ('missing-original-release', SOURCE.replace(
                    'daimos_test_maybe_release_v1150:',
                    'daimos_test_maybe_release_other:'))):
            path.write_text(bad)
            try:
                inject(root)
            except ValueError:
                continue
            raise AssertionError('unsafe v1343 injection accepted: ' + name)
    print('v1343: original guarded provider release preserved; '
          'three unsafe fixture mutations rejected PASS')


if __name__ == '__main__':
    main()
