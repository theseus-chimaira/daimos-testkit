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
        '.text', '.globl main', '.globl d6codec_v061_decode',
        'main:', ' movei 1,v077_compressed',
        f' movei 2,0{len(packed):o}',
        ' movei 3,v077_output',
        f' movei 4,v077_output+0{len(original):o}',
        ' movei 5,v077_output',
        ' pushj 17,d6codec_v061_decode',
        ' jumpn 1,v077_fail',
        ' movei 6,0', 'v077_check:',
        ' move 7,v077_output(6)',
        ' came 7,v077_original(6)',
        ' jrst v077_fail', ' aoj 6,',
        f' caige 6,0{len(original):o}',
        ' jrst v077_check', ' setz 1,', ' popj 17,',
        'v077_fail:', ' movei 1,1', ' popj 17,',
        '.data', 'v077_compressed:',
    ]
    lines += [f' .word 0{w:012o}' for w in packed]
    lines += ['v077_original:']
    lines += [f' .word 0{w:012o}' for w in original]
    lines += ['.bss',f'v077_output: .block 0{len(original):o}',
              '.globl __test_exit','__test_exit: .block 1']
    output.write_text('\n'.join(lines)+'\n')

if __name__=='__main__':
    if len(sys.argv)!=4:
        raise SystemExit('usage: make-native-v077.py SOURCE COMPRESSED OUTPUT')
    main()
