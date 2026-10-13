#!/usr/bin/env python3
"""Create 256-word real-DXR native parity and decode test."""
import pathlib,sys
from importlib.machinery import SourceFileLoader
m=SourceFileLoader('m','tests/host/d6codec-v039/compare-v039.py').load_module()
v=SourceFileLoader('v','tests/host/d6codec-v046/compare-v046.py').load_module()
r=pathlib.Path(__file__).resolve().parent
path=pathlib.Path('/home/theseus/git/DAIMOS/build/system/boot/pdp6/userland-build/userland/darc.dxr')
source=list(m.load(path)[:256]);enc=v.native_policy(source)
assert m.decode(enc,len(source))==source
s='''/* Self-contained 256-word darc DXR compressed stream parity and decoder test. */
.text
.globl main
.globl d6v046_encode_literals
.globl d6v046_decode
main:
 movei 1,source
 movei 2,0400
 movei 3,encoded
 movei 4,0500
 pushj 17,d6v046_encode_literals
 jumpl 1,fail
 caie 1,0%o
 jrst fail
 movei 5,0
check_enc:
 move 6,encoded(5)
 came 6,expected(5)
 jrst fail
 aoj 5,
 caige 5,0%o
 jrst check_enc
 movei 1,encoded
 movei 2,0%o
 movei 3,decoded
 movei 4,0400
 pushj 17,d6v046_decode
 jumpn 1,fail
 movei 5,0
check_dec:
 move 6,decoded(5)
 came 6,source(5)
 jrst fail
 aoj 5,
 caige 5,0400
 jrst check_dec
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
source:
'''%(len(enc),len(enc),len(enc))
s+=''.join(' .word 0%o\n'%word for word in source)
s+='expected:\n'+''.join(' .word 0%o\n'%word for word in enc)
s+='''.bss
encoded: .block 0500
decoded: .block 0400
.globl __test_exit
__test_exit: .block 1
'''
(r/'test_darc_256_v046.s').write_text(s)
print('sample=256 encoded=',len(enc))
