#!/usr/bin/env python3
"""Exercise descriptor/literal refill boundaries on current DXR corpus."""
import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


stream = load_module(HERE / "stream_model_v1360.py", "stream_v1360")
host = load_module(ROOT / "tests/validation/d6codec-current-corpus-v1359/generate-v1359.py", "host_v1359")
if len(sys.argv) != 2:
    raise SystemExit("usage: run-v1360.py DAIMOS_DXR_BUILD_DIR")
files = sorted(pathlib.Path(sys.argv[1]).glob("*.dxr"))
if len(files) < 20:
    raise RuntimeError("current linked DXR corpus unavailable")
windows = (1, 2, 3, 7, 16, 64)
count = 0
peak = 0
for filename in files:
    source = list(host.reference.load(filename))
    encoded = host.encode(source)
    for window in windows:
        result, scratch, refills = stream.decode(encoded, len(source), window)
        assert result == source, (filename, window)
        assert scratch <= 15
        assert refills >= 1 if encoded else refills == 0
        state = stream.Resumable(len(source), len(encoded))
        for offset in range(0, len(encoded), window):
            fragment = encoded[offset:offset + window]
            expected_status = (0 if offset + len(fragment) == len(encoded) else 1)
            assert state.feed(fragment) == expected_status
        assert state.output == source and state.peak <= 15
        peak = max(peak, scratch)
        count += 1


def rejects(words, output_size):
    for window in windows:
        try:
            stream.decode(words, output_size, window)
        except stream.InvalidStream:
            pass
        else:
            raise AssertionError(("unexpected success", words, output_size, window))
        state = stream.Resumable(output_size, len(words))
        try:
            if not words:
                state.feed([])
            else:
                for off in range(0, len(words), window):
                    state.feed(words[off:off + window])
        except stream.InvalidStream:
            continue
        raise AssertionError(("unexpected success", words, output_size, window))


rejects([1 << 30], 1)  # truncated literal
rejects([1 << 30, 42, 123], 1)  # trailing input
rejects([(1 << 30) | 1, 42], 1)  # noncanonical unused flags
rejects([(1 << 30) | (1 << 29), ((1 << 16) | (1 << 9)) << 18 | 1], 1)
rejects([(1 << 30) | (1 << 29), ((2 << 16) | (1 << 9) | 1) << 18], 1)
rejects([(1 << 30) | (1 << 29), ((0 << 16) | (1 << 9) | 1) << 18], 1)
rejects([(1 << 30) | (1 << 29), ((1 << 16) | (2 << 9)) << 18], 1)
rejects([0], 1)
rejects([(31 << 30), 42], 1)
rejects([1 << 30, 42], 2)

# Maximum descriptor scratch: 30 zero-runs use exactly 15 packed words.
control = (30 << 30) | ((1 << 30) - 1)
zero = ((1 << 16) | (1 << 9))
packed = (zero << 18) | zero
encoded = [control] + [packed] * 15
for window in windows:
    result, scratch, _ = stream.decode(encoded, 30, window)
    assert result == [0] * 30 and scratch == 15
    state = stream.Resumable(30, len(encoded))
    for offset in range(0, len(encoded), window):
        fragment = encoded[offset:offset + window]
        state.feed(fragment)
    assert state.output == [0] * 30 and state.peak == 15

# The empty stream succeeds only for an empty output.
assert stream.decode([], 0, 1)[0] == []
assert stream.Resumable(0, 0).feed([]) == 0
rejects([], 1)
print("PASS d6codec-stream-v1360: files=%d windows=%d successes=%d max_descriptor_scratch=%d rejection_cases=%d" %
      (len(files), len(windows), count, peak, 10))
