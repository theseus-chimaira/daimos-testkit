#!/usr/bin/env python3
"""Check that the disposable provider barrier cannot alter ordinary BRK."""

import os
from pathlib import Path
import runpy
import tempfile


def main():
    path = Path(__file__).parent / 'daimos-f07-provider-barrier-v1279.py'
    inject = runpy.run_path(str(path))['inject']
    source = ('        .text\n'
              'native_sys_brk:\n'
              '        move    1,2\n'
              '        pushj   17,vm_space_brk_current\n'
              '        popj    17,\n')
    with tempfile.TemporaryDirectory(
            prefix='daimos-f07-provider-barrier-v1279-',
            dir=os.environ.get('TMPDIR', str(Path.home() / 'tmp'))) as tmp:
        root = Path(tmp)
        proc = root / 'proc'
        proc.mkdir()
        target = proc / 'syscall_dispatch_pdp6.s'
        target.write_text(source)
        inject(root)
        result = target.read_text()
        for probe, counter in (
                ('0777764', 'predispatch'),
                ('0777765', 'spinner'),
                ('0777766', 'holder_enter')):
            if result.count('caie    2,' + probe) != 1 or \
                    result.count('move    1,daimos_test_%s_v1150' %
                                 counter) != 1:
                raise AssertionError('v1279 probe mismatch: ' + probe)
        if result.count('pushj   17,vm_space_brk_current') != 1 or \
                result.count('daimos_f07_barrier_regular_v1279:') != 1:
            raise AssertionError('v1279 ordinary BRK path was removed')
        for mutant in (source.replace('native_sys_brk:', 'old_sys_brk:'),
                       source + source):
            target.write_text(mutant)
            try:
                inject(root)
            except ValueError:
                pass
            else:
                raise AssertionError('v1279 unsafe source accepted')
    print('v1279: three read-only counters, ordinary BRK and two '
          'negative source mutations PASS')


if __name__ == '__main__':
    main()
