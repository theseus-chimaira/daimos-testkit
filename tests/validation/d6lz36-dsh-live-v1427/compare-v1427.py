#!/usr/bin/env python3
"""Measure production D6LZ36 on real stopped PDP-6 DSH memory."""
import argparse
import csv
import ctypes
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
STATES = ("idle_initial", "after_commands", "after_function")


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    item = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(item)
    return item


PRIOR = module(
    ROOT / "tests/validation/d6codec-shell-live-v1426/measure-v1426.py",
    "measure_v1426")


class ProductionCodec:
    """Use the exact tools/host/d6lz-codec.c implementations."""
    def __init__(self, library):
        lib = ctypes.CDLL(str(library.resolve()))
        word = ctypes.c_uint64
        ptr = ctypes.POINTER(word)
        count = ctypes.c_size_t
        self.compress = lib.d6lz_codec_compress
        self.compress.argtypes = [
            ptr, count, ctypes.POINTER(ptr), ctypes.POINTER(count)]
        self.compress.restype = ctypes.c_int
        self.decompress = lib.d6lz_codec_decompress
        self.decompress.argtypes = [ptr, count, ptr, count]
        self.decompress.restype = ctypes.c_int
        self.free = ctypes.CDLL(None).free
        self.free.argtypes = [ctypes.c_void_p]

    def encode(self, source):
        data = (ctypes.c_uint64 * len(source))(*source)
        ptr = ctypes.POINTER(ctypes.c_uint64)()
        size = ctypes.c_size_t()
        if self.compress(data, len(source), ctypes.byref(ptr),
                         ctypes.byref(size)) != 0:
            raise ValueError("D6LZ36 host compression failed")
        try:
            compressed = list(ptr[:size.value])
            result = (ctypes.c_uint64 * len(source))()
            if self.decompress(ptr, size.value, result,
                               len(source)) != 0:
                raise ValueError("D6LZ36 host decompression failed")
            if list(result) != source:
                raise ValueError("D6LZ36 host roundtrip differs")
            return compressed
        finally:
            self.free(ptr)


def fixture(path, raw, packed, verify=True):
    # The unchanged stage-1 core has absolute internal references to 060.
    # Recreate stage-1's 40-word installation into low core before calling
    # the unchanged production runtime direct-buffer adapter.
    code = [
        "/* Real DSH memory production D6LZ36 native test v1427. */",
        ".text",
        ".globl main",
        ".globl d6lz36_decode_core",
        ".globl d6lz36_decode_buffer",
        ".globl vfs_read_words",
        "main:",
        " move 0,[d6lz36_decode_core,,060]",
        " blt 0,0127",
        " movei 2,compressed",
        " movei 3,0%o" % len(packed),
        " movei 4,decoded",
        " hrli 4,0%o" % len(raw),
        " pushj 17,d6lz36_decode_buffer",
        " jumpn 1,fail",
    ]
    if verify:
        code.extend([
            " movei 5,0",
            "verify:",
            " move 6,source(5)",
            " came 6,decoded(5)",
            " jrst fail",
            " aoj 5,",
            " caige 5,0%o" % len(raw),
            " jrst verify",
        ])
    code.extend([
        " setz 1,", " popj 17,",
        "fail:", " movei 1,1", " popj 17,",
        "vfs_read_words:", " seto 1,", " popj 17,",
        ".data", "source:",
    ])
    code.extend(" .word 0%o" % w for w in raw)
    code.append("compressed:")
    code.extend(" .word 0%o" % w for w in packed)
    code.extend([
        ".bss", "decoded: .block 0%o" % len(raw),
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    path.write_text("\n".join(code) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--library", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--native-fixtures", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    codec = ProductionCodec(args.library)
    old = {}
    with (ROOT / "tests/validation/d6codec-shell-live-v1426/"
          "results-live-v1426.tsv").open() as f:
        for item in csv.DictReader(f, delimiter="\t"):
            old[(item["state"], item["region"])] = item
    rows = []
    for state in STATES:
        info, full, digest = PRIOR.read_live(args.input, state)
        text_tail = info["writable"] - info["prefix"]
        if text_tail != 114:
            raise ValueError("DSH text boundary has changed")
        for region, raw in (
                ("physical_sector_suffix", full),
                ("writable_only", full[text_tail:])):
            prior = old[(state, region)]
            if (digest != prior["sha256_source"] or
                    len(raw) != int(prior["raw_words"])):
                raise ValueError("input differs from v1426 real snapshot")
            packed = codec.encode(raw)
            row = {
                "state": state, "region": region,
                "raw_words": len(raw),
                "d6lz36_words": len(packed),
                "grouped_v1420_words": int(prior["grouped_words"]),
                "block_v1424_words": int(prior["block_words"]),
                "ram_rle_v1376_words": int(prior["kpack_rle_words"]),
                "source_sha256": digest,
            }
            rows.append(row)
            print("%-17s %-22s raw=%5d D6LZ=%4d grouped=%4d block=%4d RLE=%4d" %
                  (state, region, len(raw), len(packed),
                   row["grouped_v1420_words"], row["block_v1424_words"],
                   row["ram_rle_v1376_words"]), flush=True)
            if args.native_fixtures and region == "physical_sector_suffix":
                fixture(args.output / (state + "-d6lz36-verify-v1427.s"),
                        raw, packed)
                fixture(args.output / (state + "-d6lz36-bench-v1427.s"),
                        raw, packed, verify=False)
                for name, compressed, version in (
                        ("grouped", PRIOR.GROUP.encode(raw), "v1420"),
                        ("block", PRIOR.BLOCK.encode(raw), "v1424")):
                    PRIOR.GROUP.emit(
                        args.output /
                        ("%s-%s-bench-v1427.s" % (state, name)),
                        raw, compressed, False, (), version=version)
    fields = list(rows[0])
    with (args.output / "results-v1427.tsv").open("w") as f:
        writer = csv.DictWriter(f, fieldnames=fields,
                                delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print("PASS six D6LZ36 production host roundtrips")


if __name__ == "__main__":
    main()
