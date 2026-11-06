#!/usr/bin/env python3
"""Verify slot-6 ownership ordering in the real disposable v1150 fixture."""

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def load_injector(path):
    spec = importlib.util.spec_from_file_location('f07_order_v1259', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    repo = Path(os.environ['DAIMOS_REPO'])
    selfdir = Path(__file__).resolve().parent
    injector = selfdir / 'daimos-f07-provider-order-v1259.py'
    v1150 = selfdir / 'daimos-oom-provider-held-v1150.py'
    root_source = repo / 'system/kernel'
    paths = ('fs/fs_mres.s', 'proc/proc_pdp6.s',
             'proc/syscall_dispatch_pdp6.s')

    with tempfile.TemporaryDirectory(prefix='daimos-f07-provider-v1259-',
                                     dir=os.environ['TMPDIR']) as temp:
        copies = []
        for mode in (0, 1):
            target = Path(temp) / ('guest%d' % mode)
            for rel in paths:
                destination = target / rel
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(root_source / rel, destination)
            env = os.environ.copy()
            env['V1207_TEST_SWAPSLOTS'] = str(mode)
            subprocess.run(['python3', str(v1150), str(target), '0'],
                           env=env, check=True)
            copies.append(target)

        base = (copies[0] / paths[0]).read_text()
        gated = (copies[1] / paths[0]).read_text()
        assert 'daimos_f07_gate_wait_v1259:' not in base
        assert gated.count('daimos_f07_gate_wait_v1259:') == 1
        assert gated.count('daimos_f07_gate_event_v1259: .block 1') == 1
        assert gated.count('daimos_f07_gateway_started_v1259: .block 1') == 1
        gate_path = gated.split('daimos_f07_gate_wait_v1259:\n', 1)[1]
        gate_path = gate_path.split('daimos_f07_gate_pass_v1259:', 1)[0]
        assert gate_path.count('pushj   17,proc_wait_event\n'
                               '        jrst    fs_provider_lock_retry') == 1
        assert gated.count('aos     daimos_test_holder_enter_v1150') == 1
        publish = gated.index('aos     daimos_test_holder_enter_v1150')
        wake = gated.index('pushj   17,proc_wakeup_event', publish)
        copy_lease = gated.index('move    0,fs_provider_ready', publish)
        assert publish < wake < copy_lease
        assert 'skipn   daimos_f07_gateway_started_v1259' in gated
        base_proc = (copies[0] / paths[1]).read_text()
        ordered_proc = (copies[1] / paths[1]).read_text()
        assert 'setom   daimos_f07_gateway_started_v1259' in ordered_proc
        assert ordered_proc != base_proc
        assert ordered_proc.replace('''        ; PID 4's first timed sleep follows its provider-start PIPE read.
        ; This explicit phase marker, not INIT's timer, gates only its
        ; subsequent provider request. No marker is needed for PID 6.
        caie    0,4
        jrst    daimos_f07_not_gateway_v1259
        setom   daimos_f07_gateway_started_v1259
daimos_f07_not_gateway_v1259:
''', '') == base_proc
        assert (copies[0] / paths[2]).read_bytes() == \
               (copies[1] / paths[2]).read_bytes()

        inject = load_injector(injector).inject
        try:
            inject(copies[1])
        except ValueError:
            pass
        else:
            raise AssertionError('v1259: duplicate injection was accepted')
        # The malformed anchor must fail closed before editing any source.
        broken = Path(temp) / 'broken' / paths[0]
        broken.parent.mkdir(parents=True, exist_ok=True)
        broken.write_text(base.replace('fs_provider_lock_retry:',
                                       'fs_provider_lock_moved:', 1))
        broken_proc = Path(temp) / 'broken' / paths[1]
        broken_proc.parent.mkdir(parents=True, exist_ok=True)
        broken_proc.write_text(base_proc)
        previous = broken.read_bytes()
        try:
            inject(broken.parent.parent)
        except ValueError:
            pass
        else:
            raise AssertionError('v1259: missing hook was accepted')
        assert broken.read_bytes() == previous
        assert (copies[1] / paths[1]).is_file()
        for rel in paths:
            assert (root_source / rel).is_file()

    print('v1259: genuine v1150 source unchanged outside swap stress; '
          'test-only gateway/holder ordering and negative hooks PASS')


if __name__ == '__main__':
    main()
