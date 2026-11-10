#!/usr/bin/env python3
"""Measure source-identical native C89 grouped/block encoders on real DSH.

Actual DSH RAM comes from the v1426 physical simulator captures. The
host C output must match each pre-existing Python encoder word for
word. Native PDP-6 fixtures test those same exact outputs.
"""
import argparse
import csv
import ctypes
import importlib.util
import json
from pathlib import Path
import statistics
import time

ROOT = Path(__file__).resolve().parents[3]
STATES = ("idle_initial", "after_commands", "after_function")


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


PRIOR = imported(
    ROOT / "tests/validation/d6codec-shell-live-v1426/measure-v1426.py",
    "measure_v1426")


class Encoder:
    def __init__(self, lib):
        library = ctypes.CDLL(str(lib.resolve()))
        ptr = ctypes.POINTER(ctypes.c_ulong)
        self.methods = {}
        for fmt, func in (
                ("grouped", "grouped_encode_v1429"),
                ("block", "block_encode_v1429"),
                ("d6lz", "d6lz_encode_v1430"),
                ("d6lz_fast", "d6lz_fast_encode_v1431")):
            fn = getattr(library, func)
            fn.argtypes = [ptr, ctypes.c_uint, ptr, ctypes.c_uint]
            fn.restype = ctypes.c_int
            self.methods[fmt] = fn

    def encode(self, fmt, words):
        source = (ctypes.c_ulong * len(words))(*words)
        capacity = len(words) * 2 + 128
        target = (ctypes.c_ulong * capacity)()
        n = self.methods[fmt](source, len(words), target, capacity)
        if n <= 0 or n > capacity:
            raise ValueError("native C encoder failed: " + fmt)
        return list(target[:n])

    def time_ns(self, fmt, words, repeat):
        source = (ctypes.c_ulong * len(words))(*words)
        capacity = len(words) * 2 + 128
        target = (ctypes.c_ulong * capacity)()
        run = self.methods[fmt]
        timing = []
        for _ in range(repeat):
            t0 = time.perf_counter_ns()
            size = run(source, len(words), target, capacity)
            timing.append(time.perf_counter_ns() - t0)
            if size <= 0:
                raise ValueError("native C timing failed")
        return int(statistics.median(timing))


class ProductionD6Lz:
    """Direct reference against unmodified DAIMOS host compressor."""

    def __init__(self, path):
        lib = ctypes.CDLL(str(path.resolve()))
        ptr = ctypes.POINTER(ctypes.c_uint64)
        count = ctypes.c_size_t
        self.compress = lib.d6lz_codec_compress
        self.compress.argtypes = [
            ptr, count, ctypes.POINTER(ptr), ctypes.POINTER(count)]
        self.compress.restype = ctypes.c_int
        self.decode = lib.d6lz_codec_decompress
        self.decode.argtypes = [ptr, count, ptr, count]
        self.decode.restype = ctypes.c_int
        self.free = ctypes.CDLL(None).free
        self.free.argtypes = [ctypes.c_void_p]

    def encode(self, words):
        source = (ctypes.c_uint64 * len(words))(*words)
        pointer = ctypes.POINTER(ctypes.c_uint64)()
        count = ctypes.c_size_t()
        if self.compress(source, len(words), ctypes.byref(pointer),
                         ctypes.byref(count)) != 0:
            raise ValueError("production D6LZ36 host encoding failed")
        try:
            stream = list(pointer[:count.value])
            decoded = (ctypes.c_uint64 * len(words))()
            if self.decode(pointer, count.value, decoded,
                           len(words)) != 0 or list(decoded) != words:
                raise ValueError("production D6LZ36 host decoding failed")
            return stream
        finally:
            self.free(pointer)

    def validate(self, encoded, words):
        raw = (ctypes.c_uint64 * len(encoded))(*encoded)
        decoded = (ctypes.c_uint64 * len(words))()
        if self.decode(raw, len(encoded), decoded, len(words)) != 0:
            raise ValueError("fast D6LZ36 failed production decompression")
        if list(decoded) != words:
            raise ValueError("fast D6LZ36 restored data mismatch")


def reference_fast_d6lz(words):
    """Independent host implementation of 16 selected D6LZ distances."""
    result = []
    position = 0
    distances = (1, 2, 3, 4, 5, 6, 7, 8,
                 12, 16, 24, 32, 48, 64, 96, 128)
    while position < len(words):
        control_slot = len(result)
        result.append(0)
        flags = 0
        for token in range(36):
            if position == len(words):
                break
            maximum = min(130, len(words) - position)
            best = 0
            chosen = 0
            for distance in distances:
                if distance > position:
                    continue
                length = 0
                while (length < maximum and
                       words[position + length] ==
                       words[position + length - distance]):
                    length += 1
                if length >= 3 and length > best:
                    best = length
                    chosen = distance
                    if best == 130:
                        break
            if best >= 3:
                flags |= 1 << (35 - token)
                result.append(((best - 3) << 7) | (chosen - 1))
                position += best
            else:
                result.append(words[position])
                position += 1
        result[control_slot] = flags
    return result


ENCODER_NAMES = {
    "grouped": "grouped_encode_v1429",
    "block": "block_encode_v1429",
    "d6lz": "d6lz_encode_v1430",
    "d6lz_fast": "d6lz_fast_encode_v1431",
}


def create_native_fixture(path, source, expected, fmt):
    # The C89 code uses the PDP-6 kword ABI: unsigned long is 36 bits.
    # Only the encoder is measured; output comparison is omitted from
    # optional raw instruction-step benchmarks.
    lines = [
        "/* Native PDP-6 DSH encoder C89 exact output v1429. */",
        ".text", ".globl main",
        ".globl " + ENCODER_NAMES[fmt],
        "main:",
        " movei 1,source",
        " movei 2,0%o" % len(source),
        " movei 3,encoded",
        " movei 4,0%o" % (2 * len(source) + 128),
        " pushj 17," + ENCODER_NAMES[fmt],
        " caie 1,0%o" % len(expected),
        " jrst fail",
        " setz 5,",
        "compare:",
        " move 6,reference(5)",
        " came 6,encoded(5)",
        " jrst fail",
        " aoj 5,",
        " caige 5,0%o" % len(expected),
        " jrst compare",
        " setz 1,",
        " popj 17,",
        "fail:",
        " movei 1,1",
        " popj 17,",
        ".data", "source:",
    ]
    lines.extend(" .word 0%o" % x for x in source)
    lines.append("reference:")
    lines.extend(" .word 0%o" % x for x in expected)
    lines.extend([
        ".bss",
        "encoded: .block 0%o" % (2 * len(source) + 128),
        ".globl __test_exit",
        "__test_exit: .block 1",
    ])
    path.write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--library", type=Path, required=True)
    parser.add_argument("--repeat", type=int, default=19)
    parser.add_argument("--d6lz-library", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    code = Encoder(args.library)
    prod_d6lz = (ProductionD6Lz(args.d6lz_library)
                 if args.d6lz_library is not None else None)
    rows = []
    samples = {}
    with (ROOT / "tests/validation/d6codec-shell-live-v1426/"
          "results-live-v1426.tsv").open() as f:
        old = {(x["state"], x["region"]): x for x in
               csv.DictReader(f, delimiter="\t")}
    for state in STATES:
        info, snapshot, digest = PRIOR.read_live(args.input, state)
        samples[state] = snapshot
        match = old[(state, "physical_sector_suffix")]
        if (match["sha256_source"] != digest or
                int(match["raw_words"]) != len(snapshot)):
            raise ValueError("real DSH memory changed since v1426")
        references = [
            ("grouped", PRIOR.GROUP.encode(snapshot)),
            ("block", PRIOR.BLOCK.encode(snapshot))]
        if prod_d6lz is not None:
            references.append(("d6lz", prod_d6lz.encode(snapshot)))
            references.append(("d6lz_fast",
                               reference_fast_d6lz(snapshot)))
        for fmt, reference in references:
            actual = code.encode(fmt, snapshot)
            if fmt == "d6lz_fast":
                prod_d6lz.validate(actual, snapshot)
            if reference != actual:
                for i, (a, b) in enumerate(zip(reference, actual)):
                    if a != b:
                        raise ValueError(
                            "%s differs at encoded word %d: %012o %012o" %
                            (fmt, i, a, b))
                raise ValueError("%s compressed word count differs" % fmt)
            time_ns = code.time_ns(fmt, snapshot, args.repeat)
            row = dict(
                state=state, codec=fmt,
                raw_words=len(snapshot), encoded_words=len(actual),
                host_c_median_us=round(time_ns / 1000.0, 3),
                source_sha256=digest)
            rows.append(row)
            create_native_fixture(
                args.output / ("%s_%s_encode_v1429.s" % (state, fmt)),
                snapshot, actual, fmt)
            print("EXACT %-17s %-8s raw=%5d packed=%4d host_C_us=%.1f" %
                  (state, fmt, len(snapshot), len(actual),
                   time_ns / 1000.0), flush=True)
    cases = {
        "all_zeros": [0] * 400,
        "same_word": [0o123456701234] * 400,
        "alternating": [0o34567, 0o76543] * 200,
        "tiny": [0o1234567],
        "two": [0o11111, 0o22222],
    }
    for name, data in cases.items():
        references = [
            ("grouped", PRIOR.GROUP.encode(data)),
            ("block", PRIOR.BLOCK.encode(data))]
        if prod_d6lz is not None:
            references.append(("d6lz", prod_d6lz.encode(data)))
            references.append(("d6lz_fast", reference_fast_d6lz(data)))
        for fmt, reference in references:
            actual = code.encode(fmt, data)
            if fmt == "d6lz_fast":
                prod_d6lz.validate(actual, data)
            if actual != reference:
                raise ValueError(
                    "reference stream mismatch for " + name + "/" + fmt)
            create_native_fixture(
                args.output / ("%s_%s_encode_v1429.s" % (name, fmt)),
                data, actual, fmt)
    with (args.output / "results-v1429.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(rows[0]),
            delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print("PASS C89/Python bit-identical output for 3 real DSH + 5 cases")


if __name__ == "__main__":
    main()
