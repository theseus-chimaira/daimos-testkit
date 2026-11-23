#!/usr/bin/env python3
"""Compare production D6 block host codec with independent v1421 reference.

Adapted from the detached v1452 host test without its obsolete fixed
29-file DXR corpus gate. The actual production C encoder/decoder is
compiled as a temporary shared library by run-v1824.sh.
"""

import argparse
import ctypes
import importlib.util
from pathlib import Path
import random
import sys


ROOT = Path(__file__).resolve().parents[3]


def import_script(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


REFERENCE = import_script(
    ROOT / "tests/validation/d6codec-block-v1421/generate-v1421.py",
    "block_v1421_reference_v1824")
DXR = REFERENCE.grouped.dxr


class Host:
    def __init__(self, path):
        library = ctypes.CDLL(str(path.resolve()))
        pointer = ctypes.POINTER(ctypes.c_uint64)
        self.compress = library.d6block_compress_v1452
        self.compress.argtypes = [
            pointer, ctypes.c_size_t,
            ctypes.POINTER(pointer), ctypes.POINTER(ctypes.c_size_t)]
        self.compress.restype = ctypes.c_int
        self.decode = library.d6block_decompress_v1452
        self.decode.argtypes = [
            pointer, ctypes.c_size_t, pointer, ctypes.c_size_t]
        self.decode.restype = ctypes.c_int
        self.free = ctypes.CDLL(None).free
        self.free.argtypes = [ctypes.c_void_p]

    def encode(self, words):
        raw = (ctypes.c_uint64 * len(words))(*words)
        pointer = ctypes.POINTER(ctypes.c_uint64)()
        length = ctypes.c_size_t()
        assert self.compress(raw, len(words),
                             ctypes.byref(pointer),
                             ctypes.byref(length)) == 0, \
            "production host encoder refused valid input"
        try:
            packed = list(pointer[:length.value])
            restored = (ctypes.c_uint64 * len(words))()
            assert self.decode(pointer, length.value, restored,
                               len(words)) == 0, \
                "production host decoder refused encoded stream"
            assert list(restored) == words, \
                "production host decoder changed a decoded word"
            return packed
        finally:
            self.free(pointer)


def cases_from_build(boot):
    dxrs = sorted(boot.glob("*.dxr"))
    names = {item.name for item in dxrs}
    assert len(dxrs) >= 20, "incomplete current boot DXR corpus"
    assert {"kcore.dxr", "kinit.dxr", "stage1-dsk.dxr"} <= names
    samples = {"boot-" + path.name: list(DXR.load(path))
               for path in dxrs}
    dsh = boot / "userland-build/userland/dsh.dxr"
    assert dsh.is_file(), "missing native shell DXR"
    samples["userland-dsh"] = list(DXR.load(dsh))
    rng = random.Random(1452)
    samples.update({
        "one": [1],
        "two": [3, 5],
        "zero_runs": [0] * 8192,
        "overlap_one": [0o123456123456] * 4100,
        "distance_128": list(range(1, 129)) * 16,
        "alternating": [0o12345, 0o43210] * 2048,
        "random": [rng.getrandbits(36) for _ in range(2144)],
        "mixed": ([0] * 219 + list(range(37)) * 12 +
                  [0o7654321] * 799),
    })
    return samples, len(dxrs)


def bad_streams(host):
    # This checks strict rejection, including exact source consumption.
    fixtures = [
        ([1 << 34], 128),
        ([3 << 34], 1),
        ([0], 1),
        ([1 << 18], 1),
        ([(2 << 34)], 1),
        ([(1 << 34) | 1], 1),
        ([(1 << 34), 0], 1),
    ]
    for index, (words, target) in enumerate(fixtures):
        packed = (ctypes.c_uint64 * len(words))(*words)
        restored = (ctypes.c_uint64 * target)()
        assert host.decode(packed, len(words), restored, target) == -1, \
            "strict decoder accepted bad case " + str(index)
    print("PASS v1824: seven malformed/trailing stream rejections")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--boot", required=True, type=Path)
    parser.add_argument("--library", required=True, type=Path)
    args = parser.parse_args()
    host = Host(args.library)
    samples, dxr_count = cases_from_build(args.boot)
    total = 0
    for name, source in samples.items():
        expected = REFERENCE.encode(source)
        actual = host.encode(source)
        assert actual == expected, (
            name + ": C/Python encoded word mismatch (" +
            str(len(actual)) + " vs " + str(len(expected)) + ")")
        total += len(source)
        print("HOST_CODEC_PASS", name, len(source), len(actual), flush=True)
    bad_streams(host)
    print("PASS v1824: %d real boot DXRs, DSH and 8 stress streams, "
          "%d source words, byte-identical host compressor" %
          (dxr_count, total))


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, OSError, ValueError) as error:
        sys.exit("FAIL v1824 host block reference: " + str(error))
