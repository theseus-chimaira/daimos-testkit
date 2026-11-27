#!/usr/bin/env python3
"""Unsafe production-source controls; all must execute native assertions."""
from pathlib import Path
import sys

source=Path(sys.argv[1]).read_text()
work=Path(sys.argv[2])
start=source.index('static void\npbr_save_v1989(')
end=source.index('/* PI excluded. Discover only an inactive',start)
stage=source[start:end]
before,after=source[:start],source[end:]
variants=[
    ('lose-length',
     'id->escrow = PBR_TAG_V1989(source, encoded, phase);',
     'id->escrow = PBR_TAG_V1989(source, encoded - 1UL, phase);'),
    ('lose-current-brk',
     'u[PROC_BRK_OFFSET] = PBR_HEAP_V1989(id->brk);',
     'u[PROC_BRK_OFFSET] = PBR_HEAP_V1989(id->brk) & ~MM_HALF_MASK;'),
    ('retain-authority',
     'pbr_phase_v1989(id, PBR_HOLD_V1989);\n        if (phase == PBR_PAIR_V1989)',
     'if (phase == PBR_PAIR_V1989)'),
    ('no-pair-proof',
     'if (proc_pure_full_owners_v1917(slot, source, encoded,\n                    target, id->words, 1U, 1U) != 3)\n                        return MM_ERR_BUSY;\n                (void)mm_unpin(target);',
     '(void)mm_unpin(target);'),
    ('no-free-proof',
     'if (proc_pure_full_owners_v1917(slot, source, encoded,\n                    target, id->words, 1U, 0U) != 3)\n                        return MM_ERR_BUSY;\n                (void)mm_free(target, MM_TYPE_PROCESS, slot);',
     '(void)mm_free(target, MM_TYPE_PROCESS, slot);'),
    ('no-source-proof',
     'if (phase != PBR_SOURCE_V1989 || target ||\n            proc_pure_full_owners_v1917(slot, source, encoded,\n                0UL, id->words, 1U, 0U) != 1)',
     'if (phase != PBR_SOURCE_V1989 || target)'),
    ('no-version-tag',
     '(PBR_HEAP_FIELD_V1989(id.brk) & (PBR_BRK_TAG_V1989 | PBR_BRK_BAD_V1989))\n                != PBR_BRK_TAG_V1989 ||',
     '0 ||'),
    ('no-post-identity',
     '(void)mm_unpin(target);\n                if (!pbr_identity_ok_v1980(slot, id))\n                        return MM_ERR_BUSY;',
     '(void)mm_unpin(target);'),
]
for name,old,new in variants:
    assert stage.count(old)==1,name
    (work/(name+'.c')).write_text(before+stage.replace(old,new,1)+after)
a='        if (!pbr_heap_ok_v1989(id.brk, id.words))\n                goto out;'
assert source.count(a)==1
(work/'no-heap-proof.c').write_text(source.replace(a,'',1))
