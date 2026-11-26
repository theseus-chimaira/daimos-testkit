#!/usr/bin/env python3
"""Force one real ADT/DFR race in a disposable linked driver copy."""
from pathlib import Path
import sys

assert len(sys.argv)==4
source, target=map(Path,sys.argv[1:3])
mode=sys.argv[3]
assert mode in ('confirm','unsafe')
s=source.read_text()
key='dsk_address_adt_datao_v1959:\n        datao 0270,1'
assert s.count(key)==1
s=s.replace(key,'''dsk_address_adt_datao_v1959:
        skipe forced_once_v1959
        jrst forced_issue_v1959
forced_wait_v1959:
        coni 0270,5
        trnn 5,DSK_DFR
        jrst forced_wait_v1959
        aos forced_once_v1959
forced_issue_v1959:
        datao 0270,1''')
if mode=='unsafe':
    key='dsk_address_confirm_v1959:\n        coni 0270,5'
    assert s.count(key)==1
    s=s.replace(key,'dsk_address_confirm_v1959:\n        jrst dsk_address_ready_v1959\n        coni 0270,5')
s+='\n        .bss\n        .globl forced_once_v1959\nforced_once_v1959: .block 1\n'
target.write_text(s)
