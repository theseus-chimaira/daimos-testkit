#!/usr/bin/env python3
"""Generate an isolated test-only backing-write failure variant.

This intentionally never edits DAIMOS source. Build systems can substitute
its output for fs_backing.s in a test image. No production BSS is added.
The caller specifies a logical backing block for error injection. C99 is
not applicable here: this is a host-side fixture generator.
"""
import argparse
from pathlib import Path


def inject(source: str, logical: int | None, first_word: int | None = None) -> str:
    if logical is not None and not 0 <= logical < 1 << 24:
        raise ValueError('logical block outside supported range')
    if (logical is None) == (first_word is None):
        raise ValueError('specify exactly one of logical and first_word')
    if first_word is not None and not 0 <= first_word < 1 << 36:
        raise ValueError('first word outside 36-bit range')
    anchor = '; int fs_backing_write(backing, logical, block)\n'
    if source.count(anchor) != 1:
        raise ValueError('fs_backing_write entry not unique')
    before, after = source.split(anchor)
    if after.count('fs_backing_write:\n') != 1:
        raise ValueError('unexpected backing write entry')
    target = '        move    4,(1)\n        hrrz    4,4\n'
    if after.count(target) != 1:
        raise ValueError('unexpected backing dispatch layout')
    if logical is not None:
        fault = (f'        ; TEST ONLY: reject logical block {logical:o}.\n'
                 f'        caie    2,{logical:o}\n'
                 '        jrst    fs_backing_write_fault_pass\n'
                 '        jrst    kret_neg1\n'
                 'fs_backing_write_fault_pass:\n')
    else:
        fault = (f'        ; TEST ONLY: reject payload marker {first_word:o}.\n'
                 '        move    4,(3)\n'
                 f'        camn    4,[{first_word:o}]\n'
                 '        jrst    kret_neg1\n')
    return before + anchor + after.replace(target, fault + target, 1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    selector = parser.add_mutually_exclusive_group(required=True)
    selector.add_argument('--logical', type=lambda x: int(x, 0))
    selector.add_argument('--first-word', type=lambda x: int(x, 0))
    args = parser.parse_args()
    data = inject(args.source.read_text(), args.logical, args.first_word)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(data)


if __name__ == '__main__':
    main()
