#!/usr/bin/env python3
"""Independent PDP-6 DSK270 four-member D6FSR2/FSINFO physical oracle.

Read actual raw member-sector bytes; do not trust only CTY stage markers.
"""

from pathlib import Path
import struct
import sys

D6FSR2 = 0o442654636222
DRIVE_HEADER = 0o444243000000
MASK36 = (1 << 36) - 1


def check(log, headers, sizes):
    assert 'MACH                                PDP6' in log
    assert 'MEM                                 128 K' in log
    assert 'DSK270                                OK' in log
    assert 'DRM236                                OK' in log
    assert 'D6FS                              LOADED' in log
    assert 'MEMFS                             LOADED' in log
    assert 'P1D-D6FS-DSK-CAPACITY6-V1594' in log
    assert 'XIP-RUN-PASS' in log and 'STATUS:0' in log
    assert log.count('HALT instruction, PC:') == 1
    assert not any(marker in log for marker in
                   ('XIP-FAIL-', 'SIM-ERROR', 'Sockets: bind error'))
    assert len(headers) == len(sizes) == 4
    assert min(sizes) > 8192 * 1024 and len(set(sizes)) == 1
    units = set()
    common = []
    for i, (header, size) in enumerate(zip(headers, sizes)):
        assert size % 1024 == 0
        assert len(header) == 128
        assert all(0 <= word <= MASK36 for word in header)
        assert header[0] == DRIVE_HEADER, 'bad physical drive marker'
        assert header[6] == D6FSR2, 'bad D6FSR2 member %d' % i
        assert header[5] not in units, 'reused physical member identity'
        units.add(header[5])
        base = (header[7] >> 18) & 0o777777
        span = header[7] & 0o777777
        tail = header[10]
        assert base > 0 and span > 0 and tail > 0
        assert base + span + tail <= size // 1024
        common.append((base, span, tail))
    assert len(set(common)) == 1, 'physically inconsistent D6FSR2 layout'
    return common[0]


def negatives(log, headers, sizes):
    for label, variant in (
        ('invalid real D6FSR2 marker', 0),
        ('duplicate physical root member', 1),
        ('no real logged FSINFO', 2),
    ):
        changed = [list(item) for item in headers]
        witness = log
        if variant == 0:
            changed[2][6] = 0
        elif variant == 1:
            changed[3][5] = changed[0][5]
        else:
            witness = log.replace('P1D-D6FS-DSK-CAPACITY6-V1594',
                                  'P1D-D6FS-DSK-ABSENT', 1)
        try:
            check(witness, changed, sizes)
        except AssertionError:
            print('PASS v1594: rejected ' + label)
        else:
            raise AssertionError('accepted false physical DSK: ' + label)


def main():
    args = sys.argv[1:]
    selftest = '--self-test' in args
    if selftest:
        args.remove('--self-test')
    if len(args) != 3:
        raise SystemExit('usage: v1594 [--self-test] SIMH_LOG DISK_DIR REPORT')
    log = Path(args[0]).read_text(errors='replace')
    images = [Path(args[1]) / ('dsk%d.dsk' % i) for i in range(4)]
    headers = []
    for image in images:
        with image.open('rb') as f:
            headers.append(list(struct.unpack('<128Q', f.read(1024))))
    sizes = [image.stat().st_size for image in images]
    base, span, tail = check(log, headers, sizes)
    result = ('PASS v1594: four real DSK270 D6FSR2 root members, '
              'per-member sectors=%d base=%06o data=%06o tail=%06o; '
              'original KINIT FSINFO capacity=6 and XIP lifecycle\n' %
              (sizes[0] // 1024, base, span, tail))
    Path(args[2]).write_text(result)
    print(result, end='')
    if selftest:
        negatives(log, headers, sizes)


if __name__ == '__main__':
    main()
