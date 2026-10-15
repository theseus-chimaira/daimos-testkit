#!/usr/bin/env python3
"""Generate a native decoder test of the real linked PURE image payload."""
from pathlib import Path
import sys

def words(path):
    b=Path(path).read_bytes()
    if len(b)%8: raise ValueError('invalid container length')
    return [int.from_bytes(b[i:i+8],'little') for i in range(0,len(b),8)]
source=words(sys.argv[1]); packed=words(sys.argv[2]); image=source[1]>>18
reloc=(image+35)//36
original=source[3:3+image]; compressed=packed[3:len(packed)-reloc]
lines=['.text','.globl main','.globl d6codec_v061_decode','main:',
       ' movei 1,packed',f' movei 2,0{len(compressed):o}',
       ' movei 3,output',f' movei 4,output+0{image:o}',
       ' movei 5,output',' pushj 17,d6codec_v061_decode',
       ' jumpn 1,fail',' movei 6,0','check:',
       ' move 7,output(6)',' came 7,original(6)',' jrst fail',
       ' aoj 6,',f' caige 6,0{image:o}',' jrst check',
       ' setz 1,',' popj 17,','fail:',' movei 1,1',' popj 17,',
       '.data','packed:']
lines += [f' .word 0{w:012o}' for w in compressed]
lines += ['original:']+[f' .word 0{w:012o}' for w in original]
lines += ['.bss',f'output: .block 0{image:o}',
          '.globl __test_exit','__test_exit: .block 1']
Path(sys.argv[3]).write_text('\n'.join(lines)+'\n')
