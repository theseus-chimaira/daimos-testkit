#!/usr/bin/env python3
"""Read-only physical K04 dying-parent / pinned-PREVM-child verifier.

Usage: verify-v1797.py --self-test | MAP CTY DCS SIMH DISK
"""
from pathlib import Path
import re
import subprocess
import sys


HEADER = 'PID PPID S WORDS TD RETRY PVM DETAIL ERR COMM'
NAMES = tuple('k04_prevm_' + field + '_v1797'
              for field in ('base', 'calls', 'done'))


def ps_entry(scan, pid, parent, stage, pvm, command):
    pattern = ((r'(?m)^%d\s+%d\s+\d+\s+\d+\s+%d\s+\d+'
                r'\s+%d\s+\d+\s+\d+\s+%s\s*$') %
               (pid, parent, stage, pvm, command))
    return bool(re.search(pattern, scan))


def ps_scans(dcs_text):
    return [part.split('# ', 1)[0] for part in
            dcs_text.replace('\r', '').split(HEADER)[1:]]


def verify_evidence_v1797(map_text, cty_text, dcs_text, simh_text):
    sym = {}
    for name, value in re.findall(
            r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', map_text):
        if name in NAMES:
            if name in sym:
                raise ValueError('duplicate physical witness label')
            sym[name] = int(value, 8)
    if set(sym) != set(NAMES) or len(set(sym.values())) != 3:
        raise ValueError('missing or ambiguous scratch physical symbols')

    cty_text = cty_text.replace('\r', '')
    dcs_text = dcs_text.replace('\r', '')
    if '# TRUE' not in cty_text or 'TRUE\n' not in cty_text:
        raise ValueError('CTY parent did not wait on TRUE child')
    if 'KILL 2' not in dcs_text or 'HALT' not in dcs_text:
        raise ValueError('no foreign parent TERM and operator HALT')
    if 'UUO 000000000006' in cty_text + dcs_text:
        raise ValueError('guest UUO during orphan recovery')
    scans = ps_scans(dcs_text)
    before = -1
    adopted = -1
    released = -1
    for i, scan in enumerate(scans):
        if before < 0 and ps_entry(scan, 5, 2, 3, 1, 'TRUE'):
            before = i
            continue
        if (before >= 0 and adopted < 0 and
                ps_entry(scan, 5, 1, 3, 1, 'TRUE')):
            adopted = i
            continue
        if adopted >= 0 and (not re.search(r'(?m)^5\s+', scan) or
                ps_entry(scan, 5, 3, 0, 0, 'PS')):
            released = i
            break
    if not (0 <= before < adopted < released):
        raise ValueError('no ordered physical parent->INIT->FREE evidence')

    halt = simh_text.rfind('HALT instruction, PC:')
    if halt < 0 or 'Goodbye' not in simh_text[halt:]:
        raise ValueError('no normal guest HALT / SIMH exit')
    words = {}
    for address, word in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$',
            simh_text[halt:]):
        addr = int(address, 8)
        if addr in words:
            raise ValueError('duplicate post-HALT witness')
        words[addr] = int(word, 8)
    try:
        values = tuple(words[sym[name]] for name in NAMES)
    except KeyError:
        raise ValueError('missing physical VM witness')
    if values != (0, 0o14, 0o777777777777):
        raise ValueError('PREVM pin/unpin/attempts mismatch: %r' %
                         (values,))
    return before, adopted, released, values


def self_test():
    syms = {name: 0o25037 + i for i, name in enumerate(NAMES)}
    mp = ''.join('%s %06o\n' % (name, syms[name]) for name in NAMES)
    cty = 'LOGIN: ROOT\n# TRUE\nTRUE\n'
    base = (HEADER + '\n0 0 2 0 0 0 0 0 0 SWAPPE\n'
            '1 0 3 5120 0 0 0 0 0 INIT\n')
    before = base + '5 2 2 2048 3 16 1 0 0 TRUE\n# '
    adopted = base + '5 1 2 2048 3 256 1 0 0 TRUE\n# '
    cleared = base + '7 3 2 3072 0 0 0 0 0 PS\n# '
    dcs = ('# PS\n' + before + '# KILL 2\nKILL 2\n# PS\n' +
           adopted + '# PS\n' + cleared + 'HALT\n')
    simh = ('HALT instruction, PC: 022650\n' +
            ''.join('%06o:\t%012o\n' % (syms[name], word)
                    for name, word in zip(
                        NAMES, (0, 0o14, 0o777777777777))) +
            'Goodbye\n')
    verify_evidence_v1797(mp, cty, dcs, simh)
    bad = (
        (mp, cty, dcs.replace('KILL 2', 'NOOP'), simh),
        (mp, cty, dcs.replace('5 1 2', '5 2 2'), simh),
        (mp, cty, dcs.replace('5 2 2', '5 1 2'), simh),
        (mp, cty, dcs.replace('7 3 2', '5 1 2'), simh),
        (mp, cty, dcs, simh.replace('HALT instruction', 'Stop')),
        (mp, cty, dcs, simh.replace('%012o' % 0o14,
                                    '%012o' % 0o13)),
        (mp, cty, dcs, simh.replace('%012o' % 0o777777777777,
                                    '%012o' % 0)),
        (mp.replace(NAMES[2], 'other_symbol'), cty, dcs, simh),
    )
    for i, args in enumerate(bad):
        try:
            verify_evidence_v1797(*args)
        except ValueError:
            continue
        raise AssertionError('v1797 negative control %d passed' % i)
    print('v1797 positive + %d negative controls PASS' % len(bad))


def main(argv):
    if argv == ['--self-test']:
        self_test()
        return 0
    if len(argv) != 5:
        print('usage: verify-v1797.py --self-test | MAP CTY DCS SIMH DISK',
              file=sys.stderr)
        return 2
    result = verify_evidence_v1797(*(Path(p).read_text(errors='replace')
                                      for p in argv[:4]))
    print('v1797 ordered parent/adopted/release scans:', result[:3])
    print('v1797 physical VM witnesses:', result[3])
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', argv[4]],
                          capture_output=True, text=True)
    out = fsck.stdout + fsck.stderr
    print(out.strip())
    if fsck.returncode or 'state=CLEAN' not in out:
        raise ValueError('D6FS not CLEAN after guest HALT')
    print('K04 v1797 dying-parent/PREVM adoption verified PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError) as exc:
        print('K04 v1797 NOT ACCEPTED:', exc, file=sys.stderr)
        sys.exit(1)
