#!/usr/bin/env python3
"""Generate a real validated D6FS secondary handoff from checked media.

Only testkit uses this transient producer. It does not invent geometry or
install a new resident scanner. All four on-media DBOOT descriptors and both
actual D6FS superblock copies must agree; the caller also runs d6fsck.
"""
from pathlib import Path
import sys

BLOCK_WORDS = 0o200
WORD_BYTES = 8
WORD_MASK = (1 << 36) - 1
HALF_MASK = (1 << 18) - 1
LAYOUT_MAGIC = 0o442654636222
D6FS_MAGIC = 0o44066263662
D6FS_VERSION = 2
HANDOFF_MAGIC = 0o44066263602


def physical_block(path, index):
    with path.open('rb') as f:
        f.seek(index * BLOCK_WORDS * WORD_BYTES)
        raw = f.read(BLOCK_WORDS * WORD_BYTES)
    if len(raw) != BLOCK_WORDS * WORD_BYTES:
        raise ValueError('short physical sector: %s %o' % (path, index))
    return [int.from_bytes(raw[i:i + 8], 'little') & WORD_MASK
            for i in range(0, len(raw), 8)]


def descriptors(directory):
    result = []
    for unit in range(4):
        path = directory / ('dsk%d.dsk' % unit)
        candidates = []
        for sec in range(0o200):
            block = physical_block(path, sec)
            if block[0o6] == LAYOUT_MAGIC:
                candidates.append((sec,block))
        if len(candidates) != 1:
            raise ValueError('unit %d: ambiguous physical layout: %d' %
                             (unit, len(candidates)))
        offset, block = candidates[0]
        base = (block[0o7] >> 18) & HALF_MASK
        count = block[0o7] & HALF_MASK
        super_a = block[0o10]
        super_b = block[0o11]
        if count == 0 or super_a == super_b or base <= offset:
            raise ValueError('invalid DBOOT physical geometry')
        result.append((path,base,count,super_a,super_b))
    bases = [r[1] for r in result]
    counts = [r[2] for r in result]
    pairs = [(r[3],r[4]) for r in result]
    if len(set(bases)) != 1 or len(set(counts)) != 1 or len(set(pairs)) != 1:
        raise ValueError('D6FS image members disagree on their layout')
    return result


def logical_block(members, logical):
    if logical >= sum(m[2] for m in members):
        raise ValueError('out-of-range logical block')
    # All four members have the same verified capacity, so this is the
    # actual mkd6fs zone-mapping rule for this particular diskset.
    member = members[logical % 4]
    return physical_block(member[0], member[1] + logical // 4)


def handoff(members, kind):
    super_a, super_b = members[0][3:5]
    a = logical_block(members,super_a)
    b = logical_block(members,super_b)
    if a != b:
        raise ValueError('unequal clean D6FS superblock generations')
    if (a[0] & ~0o77) != (D6FS_MAGIC & ~0o77) or \
       (a[0] & 0o77) != D6FS_VERSION or a[0o2] != 0:
        raise ValueError('secondary D6FS superblock is not clean v2')
    total = sum(m[2] for m in members)
    if a[0o7] != total or a[0o12] <= 0 or a[0o10] >= a[0o12]:
        raise ValueError('D6FS total blocks or root FCB invalid')
    if (a[0o11] >= total or a[0o13] >= total or
        a[0o15] >= total or a[0o16] <= 0 or
        a[0o15] + a[0o16] >= total):
        raise ValueError('invalid D6FS transient reader geometry')
    # Direct INTERLEAVE set with all four members, no boot-root flag.
    selector = 0o200017 if kind == 'dsk' else 0o600017
    opaque = (selector << 18) | members[0][1]
    summary = a[0o15]
    values = [
        summary + a[0o16],     # alloc cursor (read-only mount)
        summary << 12,         # prepacked summary with public mount ID=0
        a[0o1],                # CLEAN sequence
        total,
        a[0o10], a[0o11], a[0o12],
        a[0o13], a[0o14],
        super_a, super_b,
        HANDOFF_MAGIC, opaque, total,
    ]
    if len(values) != 0o16 or any(v < 0 or v > WORD_MASK for v in values):
        raise ValueError('bad D6FS transient handoff')
    return values


def main():
    if len(sys.argv) != 4 or sys.argv[2] not in ('dsk', 'drm'):
        raise SystemExit('usage: producer MEDIA_DIRECTORY dsk|drm HEADER_PATH')
    disk = Path(sys.argv[1])
    kind = sys.argv[2]
    members = descriptors(disk)
    data = handoff(members,kind)
    lines = [
        '/* Generated v1545 host-validated transient D6FS test handoff. */',
        'static kword_t secondary_handoff_v1545[016] = {',
    ]
    for i, word in enumerate(data):
        lines.append('    0%oUL%s /* word %02o */' %
                     (word, ',' if i < len(data) - 1 else '', i))
    lines.append('};')
    Path(sys.argv[3]).write_text('\n'.join(lines) + '\n')
    print('v1545: validated physical %s 4-member D6FS: '
          'super %o/%o total %o backing %012o' %
          (kind,members[0][3],members[0][4],data[3],data[12]))


if __name__ == '__main__':
    main()
