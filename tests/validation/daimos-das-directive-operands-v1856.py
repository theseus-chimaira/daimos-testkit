#!/usr/bin/env python3
"""Check parsed DAS text/BYTE/LONG operands against a word-level oracle.

The assembler must consume each directive mnemonic exactly once.  Both
file-backed and pipe-backed phase transports must emit identical DXRs.
"""

import argparse
import os
import pathlib
import subprocess
import tempfile

MASK36 = 0o777777777777
MAGIC = 0o447062


def text_words(text, width, zero_term=False):
    size = 6 if width == 6 else 5
    codes = []
    for c in text:
        if width == 6:
            c = c.upper()
            codes.append(ord(c) - ord(' ') if ' ' <= c <= '_' else 0)
        else:
            codes.append(ord(c) & 0o177)
    if zero_term:
        codes.append(0)
    count = max(1, (len(codes) + size - 1) // size)
    codes.extend([0] * (count * size - len(codes)))
    result = []
    for offset in range(0, len(codes), size):
        word = 0
        for value in codes[offset:offset + size]:
            word = (word << width) | value
        if width == 7:
            word <<= 1
        result.append(word)
    return result


def expected_words():
    words = []
    words += text_words('', 7)
    words += text_words('ABCDE', 7)
    words += text_words('ABCDEF', 7)
    words += text_words('ABCD', 7, True)
    words += text_words('ABCDE', 7, True)
    words += text_words('', 6)
    words += text_words('abcdef', 6)
    words += text_words('ABCDEFG', 6)
    words += [(1 << 27) | (2 << 18) | (3 << 9) | 4]
    words += [1, 2, 3]
    return words


SOURCE = """.text
.entry start
start:
    .ASCII //
    .ASCII /ABCDE/
    .ASCII /ABCDEF/
    .ASCIZ /ABCD/
    .ASCIZ /ABCDE/
    .SIXBIT //
    .SIXBIT /abcdef/
    .SIXBIT /ABCDEFG/
    BYTE (9)1,(9)2,(9)3,(9)4
    LONG 1,2,3
"""


def check(path):
    data = path.read_bytes()
    if len(data) < 16 or len(data) % 8:
        raise AssertionError('incomplete DXR')
    words = [int.from_bytes(data[i:i + 8], 'little') & MASK36
             for i in range(0, len(data), 8)]
    if (words[0] >> 18) != MAGIC:
        raise AssertionError('bad DXR magic')
    actual_length = (words[1] >> 18) & 0o777777
    expected = expected_words()
    if actual_length != len(expected):
        raise AssertionError('image words=%d expected=%d' %
                             (actual_length, len(expected)))
    for index, value in enumerate(expected):
        if words[2 + index] != value:
            raise AssertionError('word %d: %012o != %012o' %
                                 (index, words[2 + index], value))
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--das', required=True, type=pathlib.Path)
    args = parser.parse_args()
    das = args.das.resolve()
    base = pathlib.Path(os.environ.get('TMPDIR') or
                        str(pathlib.Path.home() / 'tmp'))
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='das-directives-v1856-',
                                     dir=str(base)) as directory:
        work = pathlib.Path(directory)
        source = work / 'source-v1856.s'
        source.write_text(SOURCE, encoding='ascii')
        image1 = work / 'file-v1856.dxr'
        image2 = work / 'pipe-v1856.dxr'
        subprocess.run([str(das), '-A', '-O', str(image1), str(source)],
                       check=True)
        subprocess.run([str(das), '-A', '-P', '-O', str(image2), str(source)],
                       check=True)
        data = check(image1)
        if check(image2) != data:
            raise AssertionError('file and pipe transports differ')
    print('PASS: directive operands and both phase transports')


if __name__ == '__main__':
    main()
