#!/usr/bin/env python3
"""Verify native DF10 DMA modifies only its allocated KCORE control words."""
import argparse
from pathlib import Path
import re
import struct
import subprocess

MASK = (1 << 36) - 1
BASE = 0o62
CIA = 0o150
COMPLETION = CIA + 1
APR = 0o147
BUFFER = 0o102000
START = 0o100000


def symbols(path):
    return {f[0]: int(f[1], 8) for l in path.read_text().splitlines()
            if len(f := l.split()) == 2 and re.fullmatch('[0-7]+', f[1])}


def main():
    parser = argparse.ArgumentParser()
    for name in ('build', 'prefix', 'work'):
        parser.add_argument(name, type=Path)
    a = parser.parse_args()
    a.work.mkdir(parents=True)
    sym = symbols(a.build / 'kcore.map')
    assert sym['d6b_image_start_v1458'] == BASE
    assert sym['d6b_image_end_v1458'] == sym['vm_pdp6_apr'] == APR
    assert sym['ka10_df10_cia'] == CIA
    assert sym['ka10_df10_completion'] == COMPLETION
    image = [int(w, 8) for w in (a.build / 'kcore.stream').read_text().splitlines()[2:]]
    assert len(image) == sym['__kcore_low_init_end'] - BASE
    assert image[APR-BASE:COMPLETION-BASE+1] == [0, 0, 0]
    # Use the actual linked image, not a synthetic empty low core. Supply
    # a nonzero APR shadow and a sentinel in every resident BSS word.
    image[APR-BASE] = 0o006000170000
    image += [0o525252525252] * (sym['__kcore_low_end'] - sym['__kcore_low_init_end'])
    assert BASE + len(image) < START
    expected = [(0o123456701234 + n * 0o1030405) & MASK for n in range(128)]
    for mode in ('read', 'write'):
        media = a.work / (mode + '.drm')
        with media.open('wb') as f:
            f.truncate(345600 * 8)
            if mode == 'read':
                f.seek(128 * 8)
                f.write(struct.pack('<128Q', *expected))
        lines = ['set cpu 64k', 'set cpu oneseg', 'set cpu nomaoff',
                 'set fha enabled', 'set fha0 rm10', 'attach -q fha0 ' + str(media)]
        lines.extend('deposit %o %012o' % (BASE + i, w) for i, w in enumerate(image))
        iowd = ((-128 & 0o777777) << 18) | (BUFFER - 1)
        # Logical block 1 is track 0, segment 2. DATAO encodes the
        # channel address and transfer direction in the low half.
        command = (2 << 18) | CIA | (0o1000 if mode == 'write' else 0)
        lines.extend(('deposit %o %012o' % (CIA, iowd),
                      'deposit %o 0' % COMPLETION,
                      'deposit 100010 %012o' % command,
                      'deposit 100000 717140100010',
                      'deposit 100001 717340000010',
                      'deposit 100002 254000100001',
                      'deposit 100003 717240100011',
                      'deposit 100004 254200100004'))
        if mode == 'write':
            lines.extend('deposit %o %012o' % (BUFFER+i,w) for i,w in enumerate(expected))
        lines.extend(('go 100000', 'examine 100011',
                      'examine %o-%o' % (BASE, BASE+len(image)-1),
                      'examine %o-%o' % (BUFFER-1, BUFFER+128),
                      'detach fha0', 'exit'))
        ini = a.work / (mode + '.ini')
        ini.write_text('\n'.join(lines) + '\n')
        result = subprocess.run([str(a.prefix / 'bin/pdp10-ka'), str(ini)],
                                capture_output=True, text=True, timeout=30, check=True)
        log = result.stdout + result.stderr
        (a.work / (mode + '.log')).write_text(log)
        assert 'HALT instruction, PC: 100004' in log, log[-2000:]
        vals = {int(n, 8): int(v, 8) for n,v in re.findall(r'^([0-7]+):\s+([0-7]+)', log, re.M)}
        assert vals[0o100011] & 0o10 and not vals[0o100011] & 0o377760
        assert vals[CIA] == iowd
        assert vals[COMPLETION] == (COMPLETION << 18) | (BUFFER + 127)
        for i,w in enumerate(image):
            addr = BASE + i
            if addr not in (CIA, COMPLETION):
                assert vals[addr] == w, (mode, oct(addr), oct(w), oct(vals[addr]))
        if mode == 'read':
            actual = [vals[BUFFER+i] for i in range(128)]
            assert vals[BUFFER-1] == vals[BUFFER+128] == 0
        else:
            with media.open('rb') as f:
                f.seek(128 * 8)
                actual = list(struct.unpack('<128Q', f.read(128 * 8)))
        assert actual == expected, mode
        print('PASS %s: %d protected KCORE words unchanged, DF10 completion %012o' %
              (mode, len(image)-2, vals[COMPLETION]), flush=True)


if __name__ == '__main__':
    main()
