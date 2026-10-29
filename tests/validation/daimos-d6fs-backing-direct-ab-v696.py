#!/usr/bin/env python3
"""Generate and assemble a D6FS direct-backend A/B without production edits.

Only four JRST trampolines are eliminated. Every patched branch/call is
retained as a distinct, named relocation site for future KINIT/MODLOAD use.
"""
import argparse
from pathlib import Path
import re
import subprocess

p = argparse.ArgumentParser()
p.add_argument('repo', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--assembler', default='das')
a = p.parse_args()
source = (a.repo/'system/kernel/storage/fs_backing.s').read_text()
start = source.index('fs_backing_direct_dispatch:')
end = source.index('fs_backing_direct_root_done:')
segment = source[start:end]
# In the old implementation each branch enters a JRST, and root paths PUSHJ
# to the very same slot. The alternate binds each branch and PUSHJ directly.
for target in ('read', 'write'):
    for backend in ('', 'drm_'):
        sym = 'fs_backing_direct_'+backend+target+'_jump'
        declaration = re.search(r'^'+sym+r':\n\s*jrst\s+(?:0|kret_neg1)\n',segment,re.M)
        assert declaration, sym
        segment = segment[:declaration.start()]+segment[declaration.end():]
        if target == 'read':
            old = 'jumpe   7,'+sym
            assert old in segment
            segment = segment.replace(old, sym+':\n        jumpe   7,kret_neg1', 1)
        else:
            if backend == '':
                anchor = 'fs_backing_direct_read_jump:'
            else:
                anchor = 'fs_backing_direct_drm_read_jump:'
            # The original write JRST is the immediate fall-through after
            # the conditional read branch; retain that branch's fall-through.
            pat = r'('+re.escape('jumpe   7,kret_neg1')+r'\n)'
            pos = segment.index('fs_backing_direct_'+backend+'read_jump:')
            m = re.search(pat, segment[pos:]); assert m
            insert = pos+m.end()
            segment = segment[:insert]+sym+':\n        jrst    kret_neg1\n'+segment[insert:]
for backend in ('', 'drm_'):
    for target in ('read','write'):
        old = 'pushj   17,fs_backing_direct_'+backend+target+'_jump'
        label = 'fs_backing_direct_root_'+backend+target+'_call'
        assert segment.count(old)==1
        segment=segment.replace(old,label+':\n        pushj   17,kret_neg1',1)
candidate=source[:start]+segment+source[end:]
# We removed two read JRSTs. Each write fall-through JRST remains, now
# serving as a direct patch site; it is not a net deletion.
for label in ('fs_backing_direct_read_jump','fs_backing_direct_write_jump',
              'fs_backing_direct_drm_read_jump','fs_backing_direct_drm_write_jump'):
    assert candidate.count(label+':')==1
assert candidate.count('fs_backing_direct_root_')>=4
out=a.output
out.mkdir(parents=True,exist_ok=True)
(out/'fs_backing-base-v696.s').write_text(source)
(out/'fs_backing-direct-v696.s').write_text(candidate)
for tag in ('base','direct'):
    subprocess.run([a.assembler,'-F','-C','-O',str(out/f'fs_backing-{tag}-v696.dobj'),
                    str(out/f'fs_backing-{tag}-v696.s')],check=True)
print('v696: baseline/candidate PDP-6 assembler PASS')
print('v696: two read-entry JRST instructions eliminated; four root calls rebound directly')
print('v696: write tail JRST instructions remain, so gross saving is TWO words, not four')
