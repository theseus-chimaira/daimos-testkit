#!/usr/bin/env python3
"""Count BLT operations/words on generated, exact decoded test streams.

The SIMH instruction step count treats BLT as one instruction, but the
PDP-6 performs a number of memory transfers proportional to its length.
BLT count/word totals are used only for illustrative timing estimates.
"""
from pathlib import Path
import sys


def read_fixture(path):
    text = path.read_text().split("compressed:\n", 1)[1]
    text = text.split(".bss", 1)[0]
    return [int(line.strip().split()[-1], 8) for line in text.splitlines()
            if line.strip().startswith(".word")]


def grouped_blt(data):
    i, count, copies, decoded = 0, 0, 0, 0
    while i < len(data):
        control = data[i]
        i += 1
        tokens = control >> 30
        assert 1 <= tokens <= 30
        flags = control & ((1 << 30) - 1)
        matches = sum((flags >> (29 - t)) & 1 for t in range(tokens))
        descriptors = data[i:i + (matches + 1) // 2]
        i += len(descriptors)
        if matches == 0:
            count += 1
            copies += tokens
            decoded += tokens
            i += tokens
            continue
        idx = 0
        for t in range(tokens):
            if not ((flags >> (29 - t)) & 1):
                decoded += 1
                i += 1
                continue
            desc = ((descriptors[idx // 2] >> (
                18 if idx % 2 == 0 else 0)) & ((1 << 18) - 1))
            idx += 1
            kind, length = desc >> 16, (desc >> 9) & 127
            assert length
            if kind == 1:
                if length > 1:
                    count += 1
                    copies += length - 1
            else:
                assert kind in (0, 2)
                count += 1
                copies += length
            decoded += length
    assert i == len(data)
    return count, copies, decoded


def block_blt(data):
    i, count, copies, decoded = 0, 0, 0, 0
    while i < len(data):
        word = data[i]
        i += 1
        assert not (word & ((1 << 18) - 1))
        kind, length = word >> 34, ((word >> 27) & 127) + 1
        if kind == 0:
            count += 1
            copies += length
            i += length
        elif kind == 1:
            if length > 1:
                count += 1
                copies += length - 1
        elif kind == 2:
            count += 1
            copies += length
        else:
            raise ValueError("reserved command")
        decoded += length
    assert i == len(data)
    return count, copies, decoded


def main():
    work = Path(sys.argv[1])
    lines = ["codec\tworkload\tdecoded\tblt_calls\tblt_words"]
    for task in ("zeros", "normal", "literal", "overlap", "worst"):
        for codec, vers, reader in (
            ("baseline", "v1420", lambda src: (
                0, 0, grouped_blt(src)[2])),
            ("grouped", "v1420", grouped_blt),
            ("block", "v1421", block_blt)
        ):
            path = work / ("block" if codec == "block" else "grouped")
            filename = path / ("%s_bench_%s.s" % (task, vers))
            calls, words, decoded = reader(read_fixture(filename))
            # The normal C ABI adapter saves and restores seven ACs
            # via two BLTs, one per entrance and exit.
            calls += 2
            words += 14
            lines.append("%s\t%s\t%d\t%d\t%d" % (
                codec, task, decoded, calls, words))
    (work / "blt-stats-v1422.tsv").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
