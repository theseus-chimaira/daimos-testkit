#!/usr/bin/env python3
"""Check exact v1253 source hooks and reject two missing-hook mutants."""

from pathlib import Path
import os
import sys
import tempfile
import runpy
import subprocess


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1253 DAIMOS_REPO')
    root = Path(sys.argv[1])
    original = (root / 'system/kernel/proc/proc_pdp6.s').read_text()
    injector = runpy.run_path(str(Path(__file__).with_name(
        'daimos-f07-dispatch-tally-v1253.py')))['inject']
    report = runpy.run_path(str(Path(__file__).with_name(
        'daimos-f07-dispatch-report-v1253.py')))
    tmpdir = Path(os.environ.get('TMPDIR') or (Path.home() / 'tmp'))
    tmpdir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='daimos-f07-v1253-',
                                     dir=tmpdir) as tmp:
        kernel = Path(tmp)
        (kernel / 'proc').mkdir()
        path = kernel / 'proc/proc_pdp6.s'
        path.write_text(original)
        injector(kernel)
        instrumented = path.read_text()
        if instrumented.count('daimos_f07u_dispatch_v1253(6)') != 1:
            raise ValueError('dispatch tally missing')
        if instrumented.count('daimos_f07u_swapreq_v1253(6)') != 1:
            raise ValueError('swap request tally missing')
        if instrumented.count('.block 0100') != 2:
            raise ValueError('wrong bounded per-slot counter sizes')
        if instrumented.count('        movem   1,proc_current_slot') != \
                original.count('        movem   1,proc_current_slot'):
            raise ValueError('original dispatch publication changed')
        source = kernel / 'proc_pdp6_v1253.s'
        source.write_text('        .set PROC_STACK_WATERMARK,1\n'
                          '        .set KINIT_STACK_WATERMARK,0\n' +
                          instrumented)
        tool = (Path(os.environ['PDP10_PREFIX']) / 'bin/das')
        subprocess.run([str(tool), '-F', '-C', '-O',
                        str(kernel / 'proc_pdp6_v1253.dobj'), str(source)],
                       check=True, capture_output=True)
        for anchor in ('proc_sched_restore_selected:\n',
                       'proc_select_done_swap_v879:\n'):
            path.write_text(original.replace(anchor, '', 1))
            try:
                injector(kernel)
            except ValueError:
                pass
            else:
                raise ValueError('missing hook mutant accepted: ' + anchor)
    names = ['f07u_idle']
    names += ['f07u_%s%02o' % (kind, slot)
              for kind in ('dispatch', 'swapreq')
              for slot in range(64)]
    addresses = ''.join('%s %06o\n' % (name, 0o20000 + i)
                        for i, name in enumerate(names))
    simulator = ''.join('%o: %012o\n' % (0o20000 + i,
                         17 if name == 'f07u_dispatch03' else 0)
                        for i, name in enumerate(names))
    values = report['load'](addresses, simulator)
    rows = report['summary'](values)
    if rows != [(3, 17, 0)]:
        raise ValueError('incorrect per-slot dispatch decode')
    for bad in (simulator.splitlines(True)[1:],
                simulator.splitlines(True) + simulator.splitlines(True)[0:1]):
        try:
            report['load'](addresses, ''.join(bad))
        except ValueError:
            pass
        else:
            raise ValueError('malformed SIMH sample accepted')
    print('v1253: per-slot dispatch/swap tallies and two mutants PASS')


if __name__ == '__main__':
    main()
