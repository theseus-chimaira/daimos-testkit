#!/usr/bin/env python3
"""Read-only reel verifier unit test with synthetic native COMP blocks."""
import argparse
from pathlib import Path
import runpy
import struct
import tempfile

v = runpy.run_path(str(Path(__file__).with_name("check-reel-v1944.py")))
p = argparse.ArgumentParser()
p.add_argument("original", type=Path)
p.add_argument("expected", type=Path)
p.add_argument("work", type=Path)
a = p.parse_args()
r = v["read_reel"](a.original)
expected = [x[0] for x in struct.iter_unpack("<Q", a.expected.read_bytes())]
n = (len(expected)+126)//127
blocks = list(range(101, 101+n))
d = r[100*128:101*128]
d[0o123] = v["sixbit"]("COMP")
tail = len(expected)-127*(n-1)
d[0o124] = tail & 63
d[0o26] |= tail >> 6
d[0] |= 1
for i, b in enumerate(blocks):
    w, sh = divmod(b, 7)
    sh = 31-5*sh
    assert not (d[w] >> sh) & 31
    d[w] |= 1 << sh
    nxt = blocks[i+1] if i+1<n else 0
    part = expected[127*i:127*(i+1)]
    r[b*128] = (nxt<<18) | (blocks[0]<<8) | len(part)
    r[b*128+1:b*128+1+len(part)] = part
r[100*128:101*128] = d

def write(path, words):
    path.write_bytes(b"".join(struct.pack("<II", w>>18, w&0o777777)
                             for w in words))

with tempfile.TemporaryDirectory(prefix="reel-oracle-v1944-", dir=a.work) as tmp:
    f = Path(tmp)/"synthetic.tap"
    write(f, r)
    assert v["verify"](a.original, f, a.expected) == (blocks[0], n)
    for name, pos, xor in (
        ("payload", blocks[0]*128+1, 1),
        ("header", blocks[0]*128, 1),
        ("cycle", blocks[-1]*128, blocks[0]<<18),
        ("name", 100*128+0o123, 1),
        ("exec", 100*128, 1),
        ("seal", 4, 1),
    ):
        mutated = r.copy()
        mutated[pos] ^= xor
        write(f, mutated)
        try:
            v["verify"](a.original, f, a.expected)
        except AssertionError:
            print("PASS verifier negative " + name)
        else:
            raise SystemExit("FAIL accepted " + name)
print("PASS v1944 synthetic reel verifier positive and six negatives")
