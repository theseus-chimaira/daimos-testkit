#!/usr/bin/env python3
"""Generate complete, independently verified DXR PDP-6 encoder fixtures."""
import pathlib,sys
from importlib.machinery import SourceFileLoader
m=SourceFileLoader('v039','tests/host/d6codec-v039/compare-v039.py').load_module()
v=SourceFileLoader('v046','tests/host/d6codec-v046/compare-v046.py').load_module()
root=pathlib.Path(__file__).resolve().parent
manifest=[pathlib.Path(x.split('\t')[0]) for x in m.MANIFEST.read_text().splitlines()[1:]]
for filename in ('configctl.dxr','darc.dxr','d6lz.dxr'):
 path=next(p for p in manifest if p.name==filename)
 source=list(m.load(path));encoded=v.native_policy(source)
 assert m.decode(encoded,len(source))==source
 stem=path.stem
 # PDP-6 simulator memory must hold both full source, reference stream,
 # output and decoded buffer; fixtures are versioned and self-contained.
 s=f'''/* Full native {filename}: compressed stream parity and decode. */
.text
.globl main
.globl d6v047_encode_literals
.globl d6v047_decode
main:
 movei 1,source
 movei 2,0{len(source):o}
 movei 3,encoded
 movei 4,0{len(encoded):o}
 pushj 17,d6v047_encode_literals
 jumpl 1,fail
 caie 1,0{len(encoded):o}
 jrst fail
 movei 5,0
check_enc:
 move 6,encoded(5)
 came 6,expected(5)
 jrst fail
 aoj 5,
 caige 5,0{len(encoded):o}
 jrst check_enc
 movei 1,encoded
 movei 2,0{len(encoded):o}
 movei 3,decoded
 movei 4,0{len(source):o}
 pushj 17,d6v047_decode
 jumpn 1,fail
 movei 5,0
check_dec:
 move 6,decoded(5)
 came 6,source(5)
 jrst fail
 aoj 5,
 caige 5,0{len(source):o}
 jrst check_dec
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
source:
'''
 s+=''.join(f' .word 0{w:o}\n' for w in source)
 s+='expected:\n'+''.join(f' .word 0{w:o}\n' for w in encoded)
 s+=f'''.bss
encoded: .block 0{len(encoded):o}
decoded: .block 0{len(source):o}
.globl __test_exit
__test_exit: .block 1
'''
 (root/f'test_full_{stem}_v047.s').write_text(s)
 print(f'{stem}\traw={len(source)}\tcompressed={len(encoded)}')
