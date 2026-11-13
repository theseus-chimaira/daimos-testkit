#!/usr/bin/env python3
"""Exercise the v1549 candidate seal on actual host mkdtfs DECtape images.

This is an OFFLINE format experiment, not a guest mount or kernel patch.
Native Type-551 images use two little-endian 18-bit halves per word.
"""

import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location(
    "daimos_dtfs_durable_model_v1549",
    HERE / "daimos-dtfs-durable-intent-v1549.py")
assert SPEC is not None and SPEC.loader is not None
PROTOCOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROTOCOL)

BLOCK_WORDS = 128
WORD_BYTES = 8
DATA_BLOCK = 0o145


def decode_word(data):
    assert len(data) == WORD_BYTES
    high = int.from_bytes(data[:4], "little")
    low = int.from_bytes(data[4:], "little")
    if high > 0o777777 or low > 0o777777:
        raise AssertionError("corrupt physical 18-bit half")
    return (high << 18) | low


def encode_word(word):
    if not 0 <= word <= PROTOCOL.MASK:
        raise AssertionError("invalid 36-bit word")
    return ((word >> 18).to_bytes(4, "little") +
            (word & 0o777777).to_bytes(4, "little"))


def read_block(path, block):
    with path.open("rb") as stream:
        stream.seek(block * BLOCK_WORDS * WORD_BYTES)
        data = stream.read(BLOCK_WORDS * WORD_BYTES)
    if len(data) != BLOCK_WORDS * WORD_BYTES:
        raise AssertionError("truncated actual DECtape image")
    return [decode_word(data[p:p + WORD_BYTES])
            for p in range(0, len(data), WORD_BYTES)]


def write_block(path, block, values):
    assert len(values) == BLOCK_WORDS
    with path.open("r+b") as stream:
        stream.seek(block * BLOCK_WORDS * WORD_BYTES)
        for word in values:
            stream.write(encode_word(word))


def format_v2_copy(image):
    old = read_block(image, 0)
    assert PROTOCOL.parse_record(old) == "OLD"
    cleaned = PROTOCOL.make_record(
        high=old[1], low=old[2], version=PROTOCOL.DTVOL2)
    # This only modifies an isolated, never-mounted formatter test output.
    # It MUST NOT be used to silently promote a real old DTVOL1 medium.
    write_block(image, 0, cleaned)
    assert PROTOCOL.parse_record(read_block(image, 0)) == "CLEAN"
    return cleaned


def run(mkdtfs):
    with tempfile.TemporaryDirectory(prefix="daimos-dtfs-v1549-") as tmp:
        source = Path(tmp) / "unmodified-v1.tap"
        replacement = Path(tmp) / "new-v2.tap"
        subprocess.run([mkdtfs, "-o", str(source)], check=True)
        subprocess.run([mkdtfs, "-o", str(replacement)], check=True)
        original = read_block(source, 0)
        assert PROTOCOL.parse_record(original) == "OLD"
        assert not PROTOCOL.fresh_mount(original)
        assert read_block(source, 0o144)[0] != 0
        print("PASS v1549 model: actual mkdtfs DTVOL1 refused by candidate parser")

        clean = format_v2_copy(source)
        other = format_v2_copy(replacement)
        assert clean[1:3] != other[1:3]
        assert PROTOCOL.fresh_mount(read_block(source, 0))
        print("PASS v1549: actual 18-bit-lane DTVOL2 record round-trip")

        dirty = PROTOCOL.make_record(
            state=PROTOCOL.DIRTY, high=clean[1], low=clean[2])
        write_block(source, 0, dirty)
        assert read_block(source, 0) == dirty
        assert not PROTOCOL.fresh_mount(read_block(source, 0))

        # v1529 observed one requested new word and one untouched old
        # word after a partial Type-551 physical block write. Exercise
        # that exact in-image state while the write-ahead seal persists.
        old_data = read_block(source, DATA_BLOCK)
        requested = list(old_data)
        requested[1] = 0o145123456701
        requested[2] = 0o145765432107
        write_block(source, DATA_BLOCK,
                    PROTOCOL.physically_write(old_data, requested, 2))
        observed_data = read_block(source, DATA_BLOCK)
        assert (observed_data[1] == requested[1] and
                observed_data[2] == old_data[2])
        assert read_block(source, 0) == dirty
        assert not PROTOCOL.fresh_mount(read_block(source, 0))
        print("PASS v1549: actual image retains dirty seal after partial data")

        # A replacement with a fresh ID must not inherit old ownership.
        assert PROTOCOL.fresh_mount(read_block(replacement, 0))
        assert not PROTOCOL.fresh_mount(read_block(replacement, 0),
                                        tuple(clean[1:3]))
        print("PASS v1549: independent clean replacement accepted, old ID refused")

        # Reopening the original file as if on a new boot cannot erase
        # its seal or the physical partly updated data block.
        reopened = Path(str(source))
        assert PROTOCOL.parse_record(read_block(reopened, 0)) == "DIRTY"
        assert read_block(reopened, DATA_BLOCK) == observed_data
        print("PASS v1549: offline cold-open retains original dirty state")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: durable-media-v1549.py /path/to/mkdtfs")
    run(sys.argv[1])
