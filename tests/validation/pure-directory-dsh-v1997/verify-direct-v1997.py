#!/usr/bin/env python3
"""Replay the accepted direct DSH checkpoint evidence without SIMH."""
import hashlib
import json
from pathlib import Path
import sys

MASK = (1 << 18) - 1
CORE = 48 * 1024


def verify(snapshots, bitmap, transcript):
    stages = []
    for label, snap in zip(('initial', 'held', 'restored'), snapshots):
        assert snap['label'] == label
        meta = snap['meta']
        assert meta['proc_current_slot'] == 0
        extents = snap['extents']
        assert len(extents) == 2 * meta['mm_extent_count']
        assert meta['mm_extent_count'] <= meta['mm_extent_capacity']
        rows = {r['slot']: r for r in snap['processes']}
        assert len(rows) == len(snap['processes'])
        owners = {}
        end = 0
        for span, flags in zip(extents[::2], extents[1::2]):
            base, words = span & MASK, span >> 18
            owner, kind, pins = flags & MASK, (flags >> 18) & 7, (flags >> 21) & 255
            assert words > 0 and end <= base and base + words <= CORE
            end = base + words
            if kind in (1, 4):
                assert owner in rows
                owners.setdefault(owner, []).append([base, words, kind, pins])
        for slot, r in rows.items():
            assert r['owners'] == owners[slot] and len(owners[slot]) == 1
            assert r['state'] == 3 and not r['escrow'] and not r['meta'] & (1 << 16)
            assert r['uarea'] and r['backing']
            if r['mode'] == 0:
                assert r['owners'] == [[r['base'], r['words'], 1, 0]]
                assert not r['saved_backing']
            else:
                assert r['mode'] == 3 and not r['base']
                assert r['saved_backing'] == r['backing']
                assert owners[slot][0][2:] == [4, 0]
        stages.append(rows)
    before, held, after = stages
    assert set(before) == set(after) == {1, 2}
    assert set(held) == {1, 2, 3}
    assert before[1] == held[1] == after[1]
    a, b, c = before[2], held[2], after[2]
    assert [r['mode'] for r in (a, b, c)] == [0, 3, 0]
    for key in ('slot', 'uarea', 'backing', 'credential'):
        assert a[key] == b[key] == c[key]
    assert b['credential'] & (1 << 31)
    assert a['words'] == 15360 and b['words'] == c['words'] == 16384
    assert held[3]['mode'] == 0 and held[3]['words'] == 10240
    base, count, kind, pins = b['owners'][0]
    raw = b['words'] - (((b['backing'] >> 22 & 0o37777) + 0o20) & ~0o177)
    assert base % 128 == 0 and bitmap['base'] == base
    assert bitmap['raw'] == raw == 3200 and bitmap['encoded'] == count == 242
    packed = bitmap['packed']
    assert len(packed) == count and all(0 <= w < 1 << 36 for w in packed)
    groups = (raw + 35) // 36
    pos = groups
    decoded = []
    for i in range(groups * 36):
        bit = packed[i // 36] & (1 << (35 - i % 36))
        if i >= raw:
            assert not bit
        elif bit:
            assert pos < count and packed[pos]
            decoded.append(packed[pos])
            pos += 1
        else:
            decoded.append(0)
    assert pos == count
    value = 'DAIMOS-K15-STATE'
    words = [sum((ord(ch) - 32) << (30 - 6*j) for j,ch in enumerate(value[i:i+6]))
             for i in range(0,len(value),6)]
    assert any(decoded[i:i+len(words)] == words for i in range(raw-len(words)+1))
    markers = ('K15BOOT', 'DSH V1', 'KEEP=DAIMOS-K15-STATE', 'K15HELD',
               'K15REAPED', 'KEEP=DAIMOS-K15-STATE', 'K15DONE', 'HALT instruction')
    start = 0
    for marker in markers:
        start = transcript.index(marker, start) + len(marker)
    return raw, count


def main():
    w = Path(sys.argv[1])
    snapshots = [json.loads((w/(label+'.json')).read_text())
                 for label in ('initial', 'held', 'restored')]
    bitmap = json.loads((w/'held-bitmap.json').read_text())
    transcript = (w/'console-v1426.log').read_text()
    raw, count = verify(snapshots, bitmap, transcript)
    for name in ('image-sha256', 'tapes-before.sha256'):
        for line in (w/name).read_text().splitlines():
            digest, path = line.split('  ', 1)
            assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest
    print('PASS replay: real DSH identity, MM, bitmap %d->%d, typed waits/HALT and hashes' % (raw,count))


if __name__ == '__main__':
    main()
