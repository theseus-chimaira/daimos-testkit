#!/usr/bin/env python3
"""Audit physical 36-bit RAW suffix and exact v1451 bitmap word cost."""

from pathlib import Path
import hashlib
import re
import sys


# Source-sensitive baseline from the independent completed original
# 48K v1654 PDP-6 physical run. The parent-side child2 has three words
# of private control state unlike slots3..7; equal encoded lengths do
# NOT mean equal private RAW data. Keep both distinct contents exact.
EXPECTED_SHA256_V1657 = {
    2: "9f31bf1a3e3afe77268d81e6b35ae8459a88723fbba839c2688a2d27f020ed0c",
    3: "f4f75cb10db5d9e254e33e9dc732f6b47eb2680d98dbe6600ae07fb1113184c4",
    4: "f4f75cb10db5d9e254e33e9dc732f6b47eb2680d98dbe6600ae07fb1113184c4",
    5: "f4f75cb10db5d9e254e33e9dc732f6b47eb2680d98dbe6600ae07fb1113184c4",
    6: "f4f75cb10db5d9e254e33e9dc732f6b47eb2680d98dbe6600ae07fb1113184c4",
    7: "f4f75cb10db5d9e254e33e9dc732f6b47eb2680d98dbe6600ae07fb1113184c4",
}


def audit(trace_path, ranges_path):
    trace = Path(trace_path).read_text(encoding="ascii")
    intervals = [(int(s), int(a, 8), int(b, 8))
                 for s, a, b in (line.split() for line in
                 Path(ranges_path).read_text(encoding="ascii").splitlines())]
    assert {s for s, _, _ in intervals} == set(range(2, 8))
    assert "V1657_FINISHED_Z" in trace
    assert "HALT instruction, PC: 000000" in trace
    assert "aaaaaax[B" in trace
    assert "wwwwwwZ" in trace
    total_raw = 0
    total_packed = 0
    total_nonzero = 0
    digests = {}
    for slot, lo, hi in intervals:
        assert hi - lo == 0o6600
        begin = "V1657_BEGIN_SLOT_%d\n" % slot
        end = "V1657_END_SLOT_%d\n" % slot
        assert trace.count(begin) == 1 and trace.count(end) == 1
        region = trace.split(begin, 1)[1].split(end, 1)[0]
        words = {}
        for addr, word in re.findall(
                r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", region):
            address = int(addr, 8)
            assert lo <= address < hi and address not in words
            words[address] = int(word, 8)
        assert len(words) == hi - lo, (slot, len(words), hi - lo)
        raw = [words[address] for address in range(lo, hi)]
        assert all(0 <= word < (1 << 36) for word in raw)
        digest = hashlib.sha256(b"".join(
            word.to_bytes(8, "little") for word in raw)).hexdigest()
        digests[slot] = digest
        assert EXPECTED_SHA256_V1657[slot] == digest, (
            slot, "original private 36-bit RAW changed")
        nonzero = sum(bool(word) for word in raw)
        # Actual v1451 representation: one literal per nonzero word
        # and exactly ONE 36-bit bitmap per group of 36 decoded words.
        # Construct both its encoded mask and literal sequence here,
        # then independently reconstruct every 36-bit RAW word.
        encoded = []
        for start in range(0, len(raw), 36):
            chunk = raw[start:start + 36]
            mask = sum(1 << (35 - idx) for idx, word
                       in enumerate(chunk) if word)
            encoded.append(mask)
            encoded.extend(word for word in chunk if word)
        restored = []
        offset = 0
        while len(restored) < len(raw):
            mask = encoded[offset]
            offset += 1
            for idx in range(min(36, len(raw) - len(restored))):
                if mask & (1 << (35 - idx)):
                    restored.append(encoded[offset])
                    offset += 1
                else:
                    restored.append(0)
        assert restored == raw and offset == len(encoded)
        assert len(encoded) == (len(raw) + 35) // 36 + nonzero
        total_raw += len(raw)
        total_packed += len(encoded)
        total_nonzero += nonzero
        print("v1657 slot%d: raw=%d nonzero=%d bitmap=%d net=%d" %
              (slot, len(raw), nonzero, len(encoded), len(raw)-len(encoded)))
    assert set(digests) == set(EXPECTED_SHA256_V1657)
    assert len(set(digests.values())) == 2
    print("v1657: two distinct original private RAW suffix hashes verified")
    print("v1657 six-source total: raw=%d nonzero=%d bitmap=%d "
          "gross_saved=%d" % (total_raw, total_nonzero, total_packed,
                                total_raw - total_packed))
    assert total_raw == 6 * 3456
    assert 0 < total_packed <= total_raw + 6 * 96
    print("PASS v1657: original six physical 36-bit RAW suffixes captured")
    print("v1657: this is candidate codeword density, NOT an MM transaction "
          "or net physical peak RAM claim")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: audit-v1657.py trace.clean intervals.txt")
    try:
        audit(*sys.argv[1:])
    except (AssertionError, ValueError, KeyError, OSError) as exc:
        print("FAIL v1657 original source density: %s" % exc,
              file=sys.stderr)
        sys.exit(1)
