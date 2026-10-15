#!/usr/bin/env python3
"""Build a native PDP-6 decoder fixture from real extracted 36-bit words."""
import pathlib
import sys

def words(path):
    raw = pathlib.Path(path).read_bytes()
    if len(raw) % 8:
        raise ValueError('not a whole number of 36-bit container words')
    data = [int.from_bytes(raw[i:i+8], 'little') for i in range(0,len(raw),8)]
    if any(n >= (1 << 36) for n in data):
        raise ValueError('input exceeds 36 bits')
    return data

def main():
    source, compressed, output = map(pathlib.Path,sys.argv[1:])
    original = words(source)
    packed = words(compressed)
    if not original or not packed:
        raise ValueError('empty native fixture')
    lines = [
        '.text', '.globl main', '.globl d6lz_image_start',
        '.globl d6lz_image_end',
        'main:', ' movei 1,d6lz_image_start', ' hrl 1,1',
        ' hrri 1,000060',
        ' blt 1,000060+(d6lz_image_end-d6lz_image_start)-1',
        ' movei 1,v085_compressed',
        f' movei 2,0{len(packed):o}',
        ' movei 3,v085_output',
        f' movei 4,v085_output+0{len(original):o}',
        ' movei 5,v085_output',
        ' pushj 17,000060',
        ' jumpn 1,v085_fail',
        ' movei 6,0', 'v085_check:',
        ' move 7,v085_output(6)',
        ' came 7,v085_original(6)',
        ' jrst v085_fail', ' aoj 6,',
        f' caige 6,0{len(original):o}',
        ' jrst v085_check', ' setz 1,', ' popj 17,',
        'v085_fail:', ' movei 1,1', ' popj 17,',
        '.data', 'v085_compressed:',
    ]
    lines += [f' .word 0{w:012o}' for w in packed]
    lines += ['v085_original:']
    lines += [f' .word 0{w:012o}' for w in original]
    lines += ['.bss',f'v085_output: .block 0{len(original):o}',
              '.globl __test_exit','__test_exit: .block 1']
    output.write_text('\n'.join(lines)+'\n')

if __name__=='__main__':
    if len(sys.argv)!=4:
        raise SystemExit('usage: make-native-v085.py SOURCE COMPRESSED OUTPUT')
    main()
