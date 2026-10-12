#!/usr/bin/env python3
"""Generate an isolated test-only backing-write failure variant.

This intentionally never edits DAIMOS source. Build systems can substitute
its output for fs_backing.s in a test image. No production BSS is added.
The caller specifies a logical backing block for error injection. C99 is
not applicable here: this is a host-side fixture generator.
"""
import argparse
from pathlib import Path


def inject(source: str, logical: int | None, first_word: int | None = None,
           logical_range: tuple[int, int] | None = None,
           after_write_range: tuple[int, int] | None = None) -> str:
    if logical is not None and not 0 <= logical < 1 << 24:
        raise ValueError('logical block outside supported range')
    if sum(x is not None for x in (logical, first_word, logical_range, after_write_range)) != 1:
        raise ValueError('specify exactly one selector')
    if logical_range is not None and not (0 <= logical_range[0] <= logical_range[1] < 1 << 24):
        raise ValueError('invalid logical block range')
    if after_write_range is not None and not (0 <= after_write_range[0] <= after_write_range[1] < 1 << 24):
        raise ValueError("invalid after-write range")
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
    if after_write_range is not None:
        low, high = after_write_range
        ending = '        move    1,1(1)\n        jrst    (4)\n'
        if after.count(ending) != 1:
            raise ValueError('unexpected callback dispatch')
        replacement = (f'        ; TEST ONLY: post-I/O status for {low:o}..{high:o}.\n'
                       '        push    17,2\n'
                       '        move    1,1(1)\n'
                       '        pushj   17,(4)\n'
                       '        pop     17,2\n'
                       '        jumpn   1,fs_backing_after_done\n'
                       f'        caige   2,{low:o}\n'
                       '        jrst    fs_backing_after_done\n'
                       f'        caig    2,{high:o}\n'
                       '        seto    1,\n'
                       'fs_backing_after_done:\n'
                       '        popj    17,\n')
        return before + anchor + after.replace(ending, replacement, 1)
    if logical is not None:
        fault = (f'        ; TEST ONLY: reject logical block {logical:o}.\n'
                 f'        caie    2,{logical:o}\n'
                 '        jrst    fs_backing_write_fault_pass\n'
                 '        jrst    kret_neg1\n'
                 'fs_backing_write_fault_pass:\n')
    elif logical_range is not None:
        low, high = logical_range
        fault = (f'        ; TEST ONLY: reject logical range {low:o}..{high:o}.\n'
                 f'        caige   2,{low:o}\n'
                 '        jrst    fs_backing_write_fault_pass\n'
                 f'        caig    2,{high:o}\n'
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
    selector.add_argument('--logical-range', nargs=2, type=lambda x: int(x, 0), metavar=('START','END'))
    selector.add_argument('--after-write-range', nargs=2, type=lambda x: int(x, 0))
    args = parser.parse_args()
    data = inject(args.source.read_text(), args.logical, args.first_word,
                  tuple(args.logical_range) if args.logical_range else None,
                  tuple(args.after_write_range) if args.after_write_range else None)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(data)


if __name__ == '__main__':
    main()
