#!/usr/bin/env python3
"""Read real DXR payload into self-contained, versioned PDP-6 fixtures."""
import pathlib, struct
ROOT=pathlib.Path(__file__).resolve().parent
CORPUS=pathlib.Path('tests/host/d6codec-v006/results-v006.tsv')
TEMPLATE=pathlib.Path('tests/validation/d6codec-native-v037/test_mixed_v037.s').read_text()
paths=[pathlib.Path(x.split('\t')[0]) for x in CORPUS.read_text().splitlines()[1:] if x.strip()]
for name, needle, offset in [('configctl','configctl.dxr',0),('darc','darc.dxr',64),('d6lz','d6lz.dxr',128)]:
    path=next(p for p in paths if p.name==needle)
    contents=path.read_bytes()
    assert len(contents)%8==0
    words=struct.unpack('<'+'Q'*(len(contents)//8),contents)
    assert all(w<1<<36 for w in words)
    rel=(words[1]>>18)
    relocation=(rel+35)//36
    header=3 if len(words)==3+rel+relocation else 2
    assert len(words)==header+rel+relocation
    assert rel>=offset+128
    sample=words[header+offset:header+offset+128]
    s=TEMPLATE.replace('d6v037_','d6v038_')
    a=s.index('source:\n');b=s.index('        .bss',a)
    s=s[:a]+'source:\n'+''.join(f'        .word 0{w:o}\n' for w in sample)+s[b:]
    (ROOT/f'test_{name}_v038.s').write_text(s)
    print(name,path.name,'offset',offset,'sample_words',len(sample))
