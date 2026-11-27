"""Produce test-only unsafe variants of the staged DROP implementation."""
from pathlib import Path
import sys

src, work = map(Path, sys.argv[1:])
drop = (src / 'proc/proc_pure_ram_v1381.c').read_text()
service = (work / 'service-v1990.c').read_text()

variants = [
    ('dirty-unlock', service,
     '''        if ((u[PROC_FINALIZE_OFFSET] & PROC_PURE_KIND_MASK_V1919) ==
            PROC_PURE_KIND_MASK_V1919)
                return 0;''', '        /* unsafe: HOLD may unlock */'),
    ('no-retry-route', service,
     '''                rc = proc_pure_dirty_recover_v1993(
                    (unsigned int)(command_v1902 & 0377UL));
                if (rc != PBD_NOT_MINE_V1993)
                        return rc;''', '                /* unsafe: skip directory rollback */'),
    ('no-rebase-proof', drop,
     '''                    !proc_pure_owner_v1918(slot, MM_TYPE_PROCESS, base, words, 1U))
                        return MM_ERR_BUSY;
                (void)mm_pure_rebase_pinned_v1381''',
     '''                    0)
                        return MM_ERR_BUSY;
                (void)mm_pure_rebase_pinned_v1381'''),
    ('no-unpin-proof', drop,
     '''            !proc_pure_owner_v1918(slot, MM_TYPE_PACKED_PROCESS,
                suffix, words - skip, 1U))
                return MM_ERR_BUSY;
        (void)mm_unpin(suffix);''',
     '''            0)
                return MM_ERR_BUSY;
        (void)mm_unpin(suffix);'''),
    ('forget-saved-identity', drop,
     """        if (tag != PBD_TAG_V1993(suffix, phase, VM_SPACE_WORDS(p), id.identity) ||
            !id.backing""",
     """        u[PROC_FINALIZE_OFFSET] = PBD_TAG_V1993(suffix, 0U, VM_SPACE_WORDS(p), id.identity);
        if (!id.backing"""),
    ('no-post-proof', drop,
     '''                (void)mm_pure_rebase_pinned_v1381(base, slot, skip, words);
                if (!pbd_same_v1993(slot, id, hold, mode))
                        return MM_ERR_BUSY;''',
     '''                (void)mm_pure_rebase_pinned_v1381(base, slot, skip, words);'''),
]
for name, source, old, new in variants:
    assert source.count(old) == 1, name
    (work / (name + '.c')).write_text(source.replace(old, new, 1),
                                     encoding='ascii')
