#!/usr/bin/env python3
"""Reject divergent, absent and incomplete root media sets."""
import importlib.util
from pathlib import Path
import tempfile

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('media', root/'tools/check-pdp6-root-media-v1.py')
media = importlib.util.module_from_spec(spec)
spec.loader.exec_module(media)
with tempfile.TemporaryDirectory() as temp:
    base = Path(temp)
    original, copied = base/'original', base/'copied'
    original.mkdir()
    copied.mkdir()
    for i in range(4):
        data = bytes([i])*4096
        (original/f'dsk{i}.dsk').write_bytes(data)
        (copied/f'dsk{i}.dsk').write_bytes(data)
    assert len(media.compare(original,copied,4)) == 4
    (copied/'dsk2.dsk').write_bytes(b'corrupt')
    try:
        media.compare(original,copied,4)
    except ValueError:
        pass
    else:
        raise AssertionError('corrupted member accepted')
    (copied/'dsk2.dsk').unlink()
    try:
        media.compare(original,copied,4)
    except ValueError:
        pass
    else:
        raise AssertionError('missing member accepted')
    try:
        media.compare(original,copied,5)
    except ValueError:
        pass
    else:
        raise AssertionError('invalid member count accepted')
print('PDP-6 root media integrity v1: PASS')
