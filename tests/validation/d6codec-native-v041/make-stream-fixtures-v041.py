#!/usr/bin/env python3
"""Generate native parity tests from real v038 DXR payload fixtures."""
import pathlib,sys
r=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,'tests/host/d6codec-v040')
from importlib.machinery import SourceFileLoader
m=SourceFileLoader('v040', 'tests/host/d6codec-v040/compare-v040.py').load_module()
for kind in ('configctl','darc','d6lz'):
 f=pathlib.Path(f'tests/validation/d6codec-native-v038/test_{kind}_v038.s')
 t=f.read_text();source=t.split('source:\n',1)[1].split('        .bss',1)[0]
 words=[int(line.strip().split()[-1],8) for line in source.splitlines() if '.word' in line]
 assert len(words)==128
 encoded=m.pack(m.tokenize(words))
 assert m.m.decode(encoded,len(words))==words
 data=''.join(f'        .word 0{v:o}\n' for v in words)
 expected=''.join(f'        .word 0{v:o}\n' for v in encoded)
 assembly=f'''/* Real-DXR payload byte-exact encoded stream test: {kind}. */
.text
.globl main
.globl d6v041_encode_literals
.globl d6v041_decode
main:
        movei   1,source
        movei   2,0200
        movei   3,encoded
        movei   4,0300
        pushj   17,d6v041_encode_literals
        jumpl   1,fail
        caie    1,0{len(encoded):o}
        jrst    fail
        movei   5,0
verify_stream:
        move    6,encoded(5)
        came    6,expected(5)
        jrst    fail
        aoj     5,
        caige   5,0{len(encoded):o}
        jrst    verify_stream
        movei   1,encoded
        movei   2,0{len(encoded):o}
        movei   3,decoded
        movei   4,0200
        pushj   17,d6v041_decode
        jumpn   1,fail
        movei   5,0
verify_decoded:
        move    6,source(5)
        came    6,decoded(5)
        jrst    fail
        aoj     5,
        caige   5,0200
        jrst    verify_decoded
        setz    1,
        popj    17,
fail:
        movei   1,1
        popj    17,
.data
source:
{data}expected:
{expected}.bss
encoded: .block 0300
decoded: .block 0200
.globl __test_exit
__test_exit: .block 1
'''
 (r/f'test_dxr_{kind}_v041.s').write_text(assembly)
 print(kind,len(words),len(encoded))
