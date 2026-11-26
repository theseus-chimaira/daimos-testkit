#!/usr/bin/env python3
"""Exercise the existing native RC10/DF10 controller with RM10 media."""
import argparse
from pathlib import Path
import re
import struct
import subprocess

MASK = (1 << 36) - 1


def bcd(n):
    return (n // 10 << 4) | n % 10


def pattern(n):
    return (0o123456701234 + n * 0o1030405) & MASK


def main():
    p = argparse.ArgumentParser()
    p.add_argument('prefix', type=Path)
    p.add_argument('work', type=Path)
    a = p.parse_args()
    a.work.mkdir(parents=True)
    for block in (0, 29, 30, 2699):
        for mode in ('read', 'write'):
            stem = '%s-%d' % (mode, block)
            media = a.work / (stem + '.drm')
            # Keep neighboring logical blocks distinct, to detect spillover.
            start = block * 128
            expected = [pattern(start + i) for i in range(128)]
            with media.open('wb') as f:
                f.truncate(345600 * 8)
                if mode == 'read':
                    f.seek(start * 8)
                    f.write(struct.pack('<128Q', *expected))
            command = (bcd(block // 30) << 25) | (bcd((block % 30) * 2) << 18) | 0o100
            if mode == 'write':
                command |= 0o1000
            # DF10 CIA is an even address in the first 512 words. The
            # completion word occupies CIA+1, initially a zero terminator.
            # The IOWD uses a negative count and the preceding address.
            lines = ['set cpu 64k', 'set cpu oneseg', 'set cpu nomaoff',
                     'set fha enabled', 'set fha0 rm10', 'attach -q fha0 ' + str(media),
                     'deposit 100 %012o' % (((-128 & 0o777777) << 18) | 0o1777),
                     'deposit 101 0', 'deposit 102 %012o' % command,
                     # DATAO 170,102; CONSO 170,10; JRST 1001; CONI 170,103; HALT 1004.
                     'deposit 1000 717140000102', 'deposit 1001 717340000010',
                     'deposit 1002 254000001001', 'deposit 1003 717240000103',
                     'deposit 1004 254200001004']
            if mode == 'write':
                lines += ['deposit %o %012o' % (0o2000+i, word) for i, word in enumerate(expected)]
            lines += ['go 1000', 'examine 100-103', 'examine 1777-2200', 'detach fha0', 'exit']
            ini = a.work / (stem + '.ini')
            ini.write_text('\n'.join(lines) + '\n')
            r = subprocess.run([str(a.prefix / 'bin/pdp10-ka'), str(ini)], capture_output=True,
                               text=True, timeout=15, check=True)
            log = r.stdout + r.stderr
            (a.work / (stem + '.log')).write_text(log)
            assert 'HALT instruction, PC: 001004' in log, log
            vals = {int(n, 8): int(v, 8) for n, v in re.findall(r'^([0-7]+):\s+([0-7]+)', log, re.M)}
            assert vals[0o103] & 0o10 and not vals[0o103] & 0o377760, log
            if mode == 'read':
                actual = [vals[0o2000+i] for i in range(128)]
                assert vals[0o1777] == vals[0o2200] == 0
            else:
                with media.open('rb') as f:
                    f.seek(start * 8)
                    actual = list(struct.unpack('<128Q', f.read(128 * 8)))
            diffs = [(i, oct(x), oct(y)) for i, (x, y) in enumerate(zip(expected, actual)) if x != y]
            assert not diffs, (mode, block, diffs[:10])
            print('PASS', mode, block, flush=True)


if __name__ == '__main__':
    main()
