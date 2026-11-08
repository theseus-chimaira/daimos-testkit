#!/usr/bin/env python3
"""Test v1348's real-spinner witness is a guarded test-only observer."""

from pathlib import Path
import importlib.util
import tempfile


def main():
    here = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location(
        'daimos_v1348', here / 'daimos-f07-spinner-progress-gate-v1348.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    source = ('daimos_f07_normal_v1204:\n'
              '        move    1,2\n'
              '        pushj   17,vm_space_brk_current\n')
    original = ('''        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
                SYS_EVENT_ARG((unsigned int)spinner, SYS_EVENT_TERM)) != 0)
                fail('q');''')
    with tempfile.TemporaryDirectory(prefix='daimos-v1348-selftest-') as temp:
        root = Path(temp)
        (root / 'proc').mkdir()
        asm = root / 'proc/syscall_dispatch_pdp6.s'
        user = root / 'guest.c'
        asm.write_text(source)
        user.write_text(original)
        module.inject(root, user)
        compiled = asm.read_text()
        guest = user.read_text()
        for required in ('caie    2,0777755',
                         'caie    0,1',
                         'move    1,daimos_test_spinner_v1150',
                         'daimos_f07_original_brk_v1348:',
                         'pushj   17,vm_space_brk_current'):
            if required not in compiled:
                raise AssertionError('unguarded spinner progress selector')
        if ('word = dsys_brk(0777755UL)' not in guest or
                'word >= 5UL' not in guest or
                'if (probe == 01000U)' not in guest or
                original not in guest):
            raise AssertionError('witness gate does not require real sleeps')
        # Source drift and duplicate user TERM calls must fail closed.
        for title, bad_asm, bad_guest in (
                ('missing-BRK-anchor', source.replace('move    1,2',
                                                     'move    1,3'), original),
                ('double-TERM', source, original + '\n' + original),
                ('missing-TERM', source, 'no valid TERM event\n')):
            asm.write_text(bad_asm)
            user.write_text(bad_guest)
            try:
                module.inject(root, user)
            except ValueError:
                continue
            raise AssertionError('unsafe fixture mutation accepted: ' + title)
    print('v1348: read-only INIT progress selector, real five-sleep '
          'barrier and three fail-closed fixture mutations PASS')


if __name__ == '__main__':
    main()
