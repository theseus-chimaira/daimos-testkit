#!/usr/bin/env python3
"""Validate the real PDP-6 K04 v1787 SIDL clock-wrap transcript.

This tool is deliberately read-only.  It does not boot a guest, alter
MM ownership, patch a simulator image or modify a filesystem.  The
instrumented v1787 guest must HALT normally before the SIMH memory
examination; only then is D6FS checked with d6fsck -n.

Usage:
    python3 daimos-k04-clock-wrap-verify-v1787.py --self-test
    python3 daimos-k04-clock-wrap-verify-v1787.py MAP LOG DISK_DIRECTORY

The MAP is the instrumented image's kcore.map.  LOG is its complete
SIMH transcript, including the post-HALT examine command.
"""

import re
import subprocess
import sys
from pathlib import Path


MASK_V1787 = 0o377777
FULL_WORD_V1787 = 0o777777777777
REQUIRED_V1787 = (
    'k04_sidl_base_v1787',
    'k04_sidl_calls_v1787',
    'k04_sidl_done_v1787',
    'k04_post_base_v1787',
    'k04_post_calls_v1787',
    'k04_post_done_v1787',
    'k04_wrap_seed_v1787',
    'k04_wrap_first_pending_v1787',
    'k04_wrap_first_v1787',
    'k04_wrap_second_v1787',
    'k04_wrap_third_v1787',
)


def decode_v1787(map_text, transcript):
    """Reject ambiguous or incomplete physical post-HALT evidence."""
    symbols = {}
    for name, addr in re.findall(
            r'(?m)^([A-Za-z_][A-Za-z_0-9]*)\s+([0-7]+)\s*$', map_text):
        if name in REQUIRED_V1787:
            if name in symbols:
                raise ValueError('duplicate K04 map symbol: ' + name)
            symbols[name] = int(addr, 8)
    if set(symbols) != set(REQUIRED_V1787):
        raise ValueError('incomplete K04 v1787 symbol map')

    halted_at = transcript.rfind('HALT instruction, PC:')
    if halted_at < 0:
        raise ValueError('missing normal guest HALT')
    before_halt = transcript[:halted_at]
    if not re.search(
            r'(?m)^5[ \t]+2[ \t]+2[ \t]+[0-9]+[ \t]+0[ \t]+0'
            r'[ \t]+0[ \t]+0[ \t]+0[ \t]+PS[ \t]*\r?$', before_halt):
        raise ValueError('PID 5 was not observed reusable with zero teardown')
    after_halt = transcript[halted_at:]
    if 'Goodbye' not in after_halt:
        raise ValueError('SIMH did not exit after read-only examination')

    words = {}
    for addr, value in re.findall(
            r'(?m)^([0-7]+):[ \t]*([0-7]{12})\r?$', after_halt):
        address = int(addr, 8)
        if address in words:
            raise ValueError('duplicate post-HALT memory word')
        words[address] = int(value, 8)
    if not set(symbols.values()).issubset(words):
        raise ValueError('missing post-HALT K04 memory witnesses')

    def word(name):
        return words[symbols[name]]

    if (word('k04_sidl_base_v1787') != 0 or
            word('k04_sidl_calls_v1787') != 5 or
            word('k04_sidl_done_v1787') != FULL_WORD_V1787):
        raise ValueError('real SIDL MM owner was not released exactly once')
    if any(word(name) for name in (
            'k04_post_base_v1787', 'k04_post_calls_v1787',
            'k04_post_done_v1787')):
        raise ValueError('second-owner injection contaminates single-owner gate')
    if word('k04_wrap_seed_v1787') != 0o377770:
        raise ValueError('wrong injected qualified timer starting point')
    first = word('k04_wrap_first_v1787') & MASK_V1787
    second = word('k04_wrap_second_v1787') & MASK_V1787
    third = word('k04_wrap_third_v1787') & MASK_V1787
    pending = word('k04_wrap_first_pending_v1787')
    if not 0o377770 <= first <= 0o377777:
        raise ValueError('first MM failure was not before the wrap')
    if ((pending >> 18) & 0o777777) != 0o400020:
        raise ValueError('first refusal lacked pending/020 backoff')
    if (pending & MASK_V1787) != first:
        raise ValueError('first pending epoch differs from actual clock')
    if second >= first:
        raise ValueError('second VM attempt did not cross 17-bit wrap')
    delta1 = (second - first) & MASK_V1787
    delta2 = (third - second) & MASK_V1787
    if (delta1, delta2) != (0o20, 0o40):
        raise ValueError('wrong physical VM retry tick interval')
    return {'first': first, 'second': second, 'third': third,
            'delta1': delta1, 'delta2': delta2,
            'attempts': word('k04_sidl_calls_v1787')}


def self_test_v1787():
    mapping = {name: 0o25151 + i
               for i, name in enumerate(REQUIRED_V1787)}
    words = {address: 0 for address in mapping.values()}
    words[mapping['k04_sidl_calls_v1787']] = 5
    words[mapping['k04_sidl_done_v1787']] = FULL_WORD_V1787
    words[mapping['k04_wrap_seed_v1787']] = 0o377770
    words[mapping['k04_wrap_first_pending_v1787']] = ((0o400020 << 18)
                                                       | 0o377770)
    words[mapping['k04_wrap_first_v1787']] = 0o377770
    words[mapping['k04_wrap_second_v1787']] = 0o400010
    words[mapping['k04_wrap_third_v1787']] = 0o400050
    map_text = ''.join('%s %06o\n' % (name, addr)
                       for name, addr in mapping.items())
    header = ('INIT V1\nPS\nPID PPID S WORDS TD RETRY PVM DETAIL ERR COMM\n'
              '5 2 2 3072 0 0 0 0 0 PS    \n'
              '# HALT\nHALT instruction, PC: 022616\n')
    trailer = ''.join('%o:\t%012o\n' % (addr, word)
                      for addr, word in sorted(words.items()))
    transcript = header + trailer + 'Goodbye\n'
    decode_v1787(map_text, transcript)
    mutations = (
        transcript.replace('HALT instruction', 'Simulation interrupted'),
        transcript.replace('5 2 2 3072 0 0 0 0 0 PS',
                           '5 2 2 3072 2 16 0 0 0 PS'),
        transcript.replace('%012o' % words[mapping['k04_wrap_second_v1787']],
                           '%012o' % 0o400011),
        transcript.replace('%012o' % words[mapping['k04_wrap_first_pending_v1787']],
                           '%012o' % 0o400040377770),
        transcript.replace('%o:\t%012o\n' %
                           (mapping['k04_sidl_done_v1787'], FULL_WORD_V1787), ''),
    )
    for i, bad in enumerate(mutations):
        try:
            decode_v1787(map_text, bad)
        except ValueError:
            pass
        else:
            raise AssertionError('negative control %d accepted' % i)
    print('K04 v1787 decoder: positive and %d negatives PASS' %
          len(mutations))


def main_v1787(argv):
    if argv == ['--self-test']:
        self_test_v1787()
        return 0
    if len(argv) != 3:
        print('usage: %s --self-test | MAP LOG DISK_DIRECTORY' %
              Path(sys.argv[0]).name, file=sys.stderr)
        return 2
    result = decode_v1787(Path(argv[0]).read_text(),
                          Path(argv[1]).read_text(errors='replace'))
    print('K04 v1787: %d real MM attempts; clocks %06o -> %06o -> %06o; '
          'deltas %o, %o' %
          (result['attempts'], result['first'], result['second'],
           result['third'], result['delta1'], result['delta2']))
    fsck = subprocess.run(['d6fsck', '-n', '4', '-d', argv[2]],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True)
    print(fsck.stdout.strip())
    if fsck.returncode or not re.search(r'state=CLEAN', fsck.stdout):
        raise ValueError('read-only D6FS check did not report CLEAN')
    print('K04 v1787 SIDL physical clock-wrap acceptance PASS')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main_v1787(sys.argv[1:]))
    except (ValueError, OSError) as exc:
        print('K04 v1787 FAIL:', exc, file=sys.stderr)
        sys.exit(1)
