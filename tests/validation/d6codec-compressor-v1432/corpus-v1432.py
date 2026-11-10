#!/usr/bin/env python3
"""Compare bitmap against real DXR binary/TSFS-like restart data.

The comparison uses the actual built 36-bit initialized DXR image
payloads. This is a codec payload comparison, not a mounted TSFS
read simulation and not an assertion about media-format headers.
"""
import argparse
import csv
import ctypes
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def import_script(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ORIGINAL = import_script(
    ROOT / "tests/validation/d6codec-compare-v1422/"
    "run-full-dxr-v1422.py", "full_dxr_v1422")
BITMAP = import_script(
    ROOT / "tests/validation/d6codec-compressor-v1432/"
    "measure-v1432.py", "bitmap_v1432")


class ProductionCodec:
    """Call the actual unmodified DAIMOS D6LZ36 host implementation."""

    def __init__(self, path):
        library = ctypes.CDLL(str(path.resolve()))
        pointer = ctypes.POINTER(ctypes.c_uint64)
        self.compress = library.d6lz_codec_compress
        self.compress.argtypes = [
            pointer, ctypes.c_size_t,
            ctypes.POINTER(pointer), ctypes.POINTER(ctypes.c_size_t)]
        self.compress.restype = ctypes.c_int
        self.decode = library.d6lz_codec_decompress
        self.decode.argtypes = [
            pointer, ctypes.c_size_t, pointer, ctypes.c_size_t]
        self.decode.restype = ctypes.c_int
        self.free = ctypes.CDLL(None).free
        self.free.argtypes = [ctypes.c_void_p]

    def encode(self, words):
        source = (ctypes.c_uint64 * len(words))(*words)
        encoded = ctypes.POINTER(ctypes.c_uint64)()
        length = ctypes.c_size_t()
        if self.compress(source, len(words), ctypes.byref(encoded),
                         ctypes.byref(length)) != 0:
            raise RuntimeError("D6LZ36 host compression failed")
        try:
            data = list(encoded[:length.value])
            restored = (ctypes.c_uint64 * len(words))()
            if self.decode(encoded, length.value, restored,
                           len(words)) != 0 or list(restored) != words:
                raise RuntimeError("D6LZ36 host roundtrip failed")
            return data
        finally:
            self.free(encoded)


def encode_sizes(words, d6lz):
    return (
        len(BITMAP.bitmap_encode(words)),
        len(d6lz.encode(words)),
        len(ORIGINAL.grouped.encode(words)),
        len(ORIGINAL.block.encode(words)),
    )


def add_rows(target, path, words, d6lz, mode, chunk):
    totals = [0, 0, 0, 0]
    chunks = 0
    if mode == "whole":
        segments = [words]
    else:
        segments = (
            words[i:i + chunk] for i in range(0, len(words), chunk))
    for segment in segments:
        sizes = encode_sizes(segment, d6lz)
        totals = [a + b for a, b in zip(totals, sizes)]
        chunks += 1
    target.append({
        "file": path.name, "mode": mode,
        "raw_words": len(words),
        "nonzero_words": sum(x != 0 for x in words),
        "chunks": chunks,
        "bitmap_words": totals[0],
        "d6lz36_words": totals[1],
        "grouped_words": totals[2],
        "block_words": totals[3],
    })


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dxr-dir", required=True, type=Path)
    parser.add_argument("--dsh", required=True, type=Path)
    parser.add_argument("--d6lz-library", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--restart-words", type=int, default=256)
    args = parser.parse_args()
    codec = ProductionCodec(args.d6lz_library)
    corpus = sorted(args.dxr_dir.glob("*.dxr"))
    if len(corpus) < 25 or not args.dsh.exists():
        raise ValueError("expected a real DAIMOS DXR corpus and DSH")
    corpus.append(args.dsh)
    results = []
    for path in corpus:
        source = list(ORIGINAL.grouped.dxr.load(path))
        if not source:
            raise ValueError("empty DXR image " + str(path))
        for mode in ("whole", "restart256"):
            add_rows(results, path, source, codec, mode, args.restart_words)
        print("FILE", path.name, "raw", len(source),
              "zero", sum(x == 0 for x in source),
              "bitmap", results[-2]["bitmap_words"],
              "d6lz", results[-2]["d6lz36_words"], flush=True)
    with args.output.open("w") as file:
        writer = csv.DictWriter(
            file, fieldnames=list(results[0]), delimiter="\t",
            lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)
    for mode in ("whole", "restart256"):
        subset = [x for x in results
                  if x["mode"] == mode and x["file"] != args.dsh.name]
        totals = {
            col: sum(row[col] for row in subset)
            for col in ("raw_words", "nonzero_words", "bitmap_words",
                        "d6lz36_words", "grouped_words", "block_words")}
        print("AGGREGATE_29", mode, totals, flush=True)
    print("PASS real DAIMOS initialized DXR bitmap/file codec comparison")


if __name__ == "__main__":
    main()
