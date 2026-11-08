#!/usr/bin/env python3
"""Create a test-only grouped DXR2 executable from a real linked DXR.

The format is still the documented compressed DXR2 file layout:
  DXR magic+entry, image_words+flags+BSS, TX2+text_words,
  compressed payload, relocation bitmap.

Only the payload codec changes. The compressed flag is the *existing*
DXR flag; it does not distinguish grouped and legacy streams. This
tool MUST NOT be used for normal production media until the system's
atomic format cutover. It publishes only a newly named test artifact.
"""
import importlib.util
import os
import pathlib
import struct
import sys

MASK36 = (1 << 36) - 1
HALF = (1 << 18) - 1
COMPRESSED = 0o100000
MAGIC = 0o447062
TEXT_TAG = 0o647022


def reference():
    testkit = pathlib.Path(__file__).resolve().parents[3]
    path = testkit / "tests/validation/d6codec-current-corpus-v1359/generate-v1359.py"
    spec = importlib.util.spec_from_file_location("grouped_v1359", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load(path):
    data = pathlib.Path(path).read_bytes()
    if not data or len(data) % 8:
        raise ValueError("bad DXR word container length")
    words = struct.unpack("<" + "Q" * (len(data) // 8), data)
    if any(x > MASK36 for x in words):
        raise ValueError("DXR word exceeds 36 bits")
    return list(words)


def unpack_original(words):
    if len(words) < 3 or words[0] >> 18 != MAGIC:
        raise ValueError("not a linked DXR")
    image = words[1] >> 18
    flags = words[1] & HALF
    if not 0 < image <= HALF or flags & COMPRESSED:
        raise ValueError("empty or already compressed DXR")
    if words[0] & HALF >= image:
        raise ValueError("entry beyond DXR image")
    reloc = (image + 35) // 36
    if len(words) == image + reloc + 2:
        header = 2
        text = 0
    elif len(words) == image + reloc + 3:
        header = 3
        if words[2] & HALF != TEXT_TAG or words[2] >> 18 > image:
            raise ValueError("malformed DXR2 text header")
        text = words[2] >> 18
    else:
        raise ValueError("DXR image size/relocation bitmap mismatch")
    return header, image, reloc, text


def validate_grouped(words):
    if len(words) < 4 or words[0] >> 18 != MAGIC:
        raise ValueError("not grouped DXR2")
    if not words[1] & COMPRESSED:
        raise ValueError("DXR not marked compressed")
    image = words[1] >> 18
    reloc = (image + 35) // 36
    if not 0 < image <= HALF or len(words) <= 3 + reloc:
        raise ValueError("bad grouped DXR shape")
    if words[2] & HALF != TEXT_TAG or words[2] >> 18 > image:
        raise ValueError("bad grouped DXR2 text metadata")
    payload = words[3:len(words) - reloc]
    decoded = reference().reference.decode(payload, image)
    if len(decoded) != image:
        raise ValueError("grouped DXR decode length mismatch")
    return decoded


def convert(source, destination):
    source = pathlib.Path(source).resolve()
    destination = pathlib.Path(destination).resolve()
    if source == destination or destination.is_file():
        raise ValueError("refusing to replace a source or existing DXR")
    if destination.name.endswith(".d6lz.dxr") or destination.name == source.name:
        raise ValueError("refusing to publish under a legacy filename")
    words = load(source)
    header, image, reloc, text = unpack_original(words)
    codec = reference()
    compressed = codec.encode(words[header:header + image])
    if codec.reference.decode(compressed, image) != words[header:header + image]:
        raise ValueError("independent grouped reference roundtrip failed")
    out = ([words[0], words[1] | COMPRESSED,
            words[2] if header == 3 else TEXT_TAG] + compressed +
           words[-reloc:])
    if validate_grouped(out) != words[header:header + image]:
        raise ValueError("independent re-read of grouped DXR failed")
    if out[-reloc:] != words[-reloc:]:
        raise ValueError("relocation metadata not preserved")
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = destination.with_name(destination.name + ".tmp." + str(os.getpid()))
    try:
        with staging.open("xb") as output:
            output.write(struct.pack("<" + "Q" * len(out), *out))
        staging.replace(destination)
    finally:
        if staging.exists():
            staging.unlink()
    print("GROUPED_EXEC_V1369_PASS input=%s output=%s image=%d compressed=%d reloc=%d text=%d" %
          (source.name, destination.name, image, len(compressed), reloc, text))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: grouped_dxr_v1369.py INPUT.dxr NEW.grouped-v1369.dxr")
    convert(sys.argv[1], sys.argv[2])
