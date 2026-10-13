#!/usr/bin/env python3
"""Verify concrete v068 CLI stream against independent v065 token repacker."""
import importlib.machinery
import pathlib
import subprocess
import sys
root, writer, work = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
work.mkdir(parents=True, exist_ok=True)
model = importlib.machinery.SourceFileLoader('v065', str(root / 'tests/host/d6codec-layout-v065/compare-v065.py')).load_module()
loader = importlib.machinery.SourceFileLoader('v039', str(root / 'tests/host/d6codec-v039/compare-v039.py')).load_module()
policy = importlib.machinery.SourceFileLoader('v046', str(root / 'tests/host/d6codec-v046/compare-v046.py')).load_module()
entries = (root / 'tests/host/d6codec-v006/results-v006.tsv').read_text().splitlines()[1:]
assert len(entries) == 81
raw = compressed = 0
for i, entry in enumerate(entries):
    path = pathlib.Path(entry.split('\t')[0])
    src = loader.load(path)
    expected = model.inline_pack(model.unpack_groups(policy.native_policy(src)))
    sourcefile, encodedfile = work / ('source-%03d-v068.txt' % i), work / ('encoded-%03d-v068.txt' % i)
    sourcefile.write_text(''.join('%012o\n' % x for x in src))
    subprocess.run([str(writer), '-t', str(sourcefile), str(encodedfile)], check=True)
    got = [int(line, 8) for line in encodedfile.read_text().splitlines()]
    assert got == expected, (path, len(got), len(expected))
    assert model.inline_decode(got, len(src)) == list(src), path
    raw += len(src)
    compressed += len(got)
assert (raw, compressed) == (159973, 135534), (raw, compressed)
print('PASS v068 81 DXR parity: %d raw / %d inline words' % (raw, compressed))
