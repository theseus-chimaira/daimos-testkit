#!/usr/bin/env python3
"""Validate host v059 against the independent native-policy 81-DXR model."""
import importlib.machinery
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
writer = pathlib.Path(sys.argv[2])
work = pathlib.Path(sys.argv[3])
work.mkdir(parents=True, exist_ok=True)
model = importlib.machinery.SourceFileLoader(
    'd6codec_v046_model',
    str(root / 'tests/host/d6codec-v046/compare-v046.py')).load_module()
loader = importlib.machinery.SourceFileLoader(
    'd6codec_v039_loader',
    str(root / 'tests/host/d6codec-v039/compare-v039.py')).load_module()
manifest = root / 'tests/host/d6codec-v006/results-v006.tsv'
entries = manifest.read_text().splitlines()[1:]
assert len(entries) == 81, len(entries)
raw_total = 0
encoded_total = 0
for index, entry in enumerate(entries):
    path = pathlib.Path(entry.split('\t')[0])
    source = loader.load(path)
    expected = model.native_policy(source)
    raw_total += len(source)
    sourcefile = work / ('source-%03d-v059.words' % index)
    encodedfile = work / ('encoded-%03d-v059.words' % index)
    sourcefile.write_text(''.join('%012o\n' % w for w in source))
    subprocess.run([str(writer), '-t', str(sourcefile), str(encodedfile)],
                   check=True)
    got = [int(line, 8) for line in encodedfile.read_text().splitlines()]
    if got != expected:
        for word, (a, b) in enumerate(zip(got, expected)):
            if a != b:
                raise AssertionError('%s word %d: %012o != %012o' %
                                     (path.name, word, a, b))
        raise AssertionError('%s lengths %d != %d' %
                             (path.name, len(got), len(expected)))
    decoded = loader.decode(got, len(source))
    if decoded != list(source):
        raise AssertionError('decode mismatch: ' + str(path))
    encoded_total += len(got)
assert raw_total == 159973, raw_total
assert encoded_total == 131463, encoded_total
print('PASS 81 DXR host/native-policy parity: %d raw / %d compressed words' %
      (raw_total, encoded_total))
