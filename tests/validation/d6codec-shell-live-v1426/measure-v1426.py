#!/usr/bin/env python3
"""Measure actual frozen PDP-6 DSH suffixes with two independent codecs.

Inputs are read-only physical memory captures from capture-v1426.py.
This script never substitutes synthetic data, even when a real
snapshot is missing; it fails closed instead.
"""
import argparse
import csv
import ctypes
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]
STATES = ("idle_initial", "after_commands", "after_function")
MASK36 = (1 << 36) - 1


class ActualRamCodec:
    """Call the unchanged DAIMOS v1376 C implementation on exact words."""

    def __init__(self, library):
        lib = ctypes.CDLL(str(library.resolve()))
        ptr = ctypes.POINTER(ctypes.c_ulong)
        self.measure = lib.kpack_ram_measure_v1376
        self.measure.argtypes = [ptr, ctypes.c_uint]
        self.measure.restype = ctypes.c_int
        self.encode = lib.kpack_ram_encode_v1376
        self.encode.argtypes = [ptr, ctypes.c_uint, ptr, ctypes.c_uint]
        self.encode.restype = ctypes.c_int
        self.decode = lib.kpack_ram_decode_v1376
        self.decode.argtypes = [ptr, ctypes.c_uint, ptr, ctypes.c_uint]
        self.decode.restype = ctypes.c_int

    def roundtrip(self, words):
        arr = (ctypes.c_ulong * len(words))(*words)
        count = self.measure(arr, len(words))
        if count < 1:
            raise ValueError("native C RAM codec measurement failed")
        target = (ctypes.c_ulong * count)()
        if self.encode(arr, len(words), target, count) != count:
            raise ValueError("native C RAM codec encode disagreement")
        restored = (ctypes.c_ulong * len(words))()
        if self.decode(target, count, restored, len(words)) != len(words):
            raise ValueError("native C RAM codec decode failure")
        if list(restored) != words:
            raise ValueError("native C RAM codec roundtrip mismatch")
        return list(target)


def emit_ram_native(path, words, encoded):
    """PDP-6 test executes actual v1376 C measure/encode/decode/compare."""
    code = [
        "/* Real DSH memory, exact RAM codec v1376 acceptance v1426. */",
        ".text", ".globl main",
        ".globl kpack_ram_measure_v1376",
        ".globl kpack_ram_encode_v1376",
        ".globl kpack_ram_decode_v1376",
        "main:",
        " movei 1,source", " movei 2,0%o" % len(words),
        " pushj 17,kpack_ram_measure_v1376",
        " caie 1,0%o" % len(encoded), " jrst fail",
        " movei 1,source", " movei 2,0%o" % len(words),
        " movei 3,compressed", " movei 4,0%o" % len(encoded),
        " pushj 17,kpack_ram_encode_v1376",
        " caie 1,0%o" % len(encoded), " jrst fail",
        " setz 5,",
        "cmp_encoded:", " move 6,reference(5)",
        " came 6,compressed(5)", " jrst fail",
        " aoj 5,", " caige 5,0%o" % len(encoded),
        " jrst cmp_encoded",
        " movei 1,compressed", " movei 2,0%o" % len(encoded),
        " movei 3,restored", " movei 4,0%o" % len(words),
        " pushj 17,kpack_ram_decode_v1376",
        " caie 1,0%o" % len(words), " jrst fail",
        " setz 5,", "cmp_raw:",
        " move 6,source(5)", " came 6,restored(5)", " jrst fail",
        " aoj 5,", " caige 5,0%o" % len(words),
        " jrst cmp_raw",
        " setz 1,", " popj 17,",
        "fail:", " movei 1,1", " popj 17,",
        ".data", "source:"
    ]
    code.extend(" .word 0%o" % v for v in words)
    code.append("reference:")
    code.extend(" .word 0%o" % v for v in encoded)
    code.extend([".bss", "compressed: .block 0%o" % len(encoded),
                 "restored: .block 0%o" % len(words),
                 ".globl __test_exit", "__test_exit: .block 1"])
    path.write_text("\n".join(code) + "\n")


def import_script(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


GROUP = import_script(
    ROOT / "tests/validation/d6codec-fastpath-v1420/generate-v1420.py",
    "d6codec_grouped_v1420")
BLOCK = import_script(
    ROOT / "tests/validation/d6codec-block-v1421/generate-v1421.py",
    "d6codec_block_v1421")


def read_live(root, state):
    meta = json.loads((root / (state + "-meta-v1426.json")).read_text())
    source = root / (state + "-physical-suffix-v1426.bin")
    if meta["label"] != state or not source.exists():
        raise ValueError("missing actual live DSH snapshot")
    binary = source.read_bytes()
    if len(binary) != meta["suffix_words"] * 8:
        raise ValueError("captured word count does not match guest VM")
    words = list(struct.unpack("<%dQ" % (len(binary) // 8), binary))
    if any(w > MASK36 for w in words):
        raise ValueError("captured physical word is not 36 bits")
    if sum(w != 0 for w in words) != meta["nonzero_words"]:
        raise ValueError("captured nonzero count mismatch")
    if not all(meta["signature"]):
        raise ValueError("DSH code signature was not accepted")
    if meta["extent"] - meta["prefix"] != len(words):
        raise ValueError("guest process geometry mismatch")
    return meta, words, hashlib.sha256(binary).hexdigest()


def main():
    arg = argparse.ArgumentParser()
    arg.add_argument("--input", required=True, type=Path)
    arg.add_argument("--output", required=True, type=Path)
    arg.add_argument("--native-fixtures", action="store_true")
    arg.add_argument("--kpack-library", type=Path, required=True)
    args = arg.parse_args()
    ram = ActualRamCodec(args.kpack_library)
    args.output.mkdir(parents=True, exist_ok=True)
    fields = (
        "state", "region", "raw_words", "nonzero_words",
        "grouped_words", "block_words", "kpack_rle_words",
        "grouped_pct", "block_pct", "kpack_rle_pct",
        "sha256_source")
    rows = []
    observed = {}
    for state in STATES:
        metadata, snapshot, checksum = read_live(args.input, state)
        observed[state] = (metadata, snapshot)
        tail = metadata["writable"] - metadata["prefix"]
        if tail != 114:
            raise ValueError("unexpected actual DSH text-tail geometry")
        for region, words in (("physical_sector_suffix", snapshot),
                              ("writable_only", snapshot[tail:])):
            grouped = GROUP.encode(words)
            block = BLOCK.encode(words)
            rle = ram.roundtrip(words)
            if GROUP.dxr.decode(grouped, len(words)) != words:
                raise ValueError("grouped live snapshot roundtrip failed")
            if BLOCK.decode(block, len(words)) != words:
                raise ValueError("block live snapshot roundtrip failed")
            row = {
                "state": state, "region": region,
                "raw_words": len(words),
                "nonzero_words": sum(x != 0 for x in words),
                "grouped_words": len(grouped),
                "block_words": len(block),
                "kpack_rle_words": len(rle),
                "grouped_pct": round(100 * len(grouped) / len(words), 2),
                "block_pct": round(100 * len(block) / len(words), 2),
                "kpack_rle_pct": round(100 * len(rle) / len(words), 2),
                "sha256_source": checksum,
            }
            rows.append(row)
            print("%-16s %-22s raw=%5d nonzero=%5d group=%4d block=%4d rle=%4d" %
                  (state, region, len(words), row["nonzero_words"],
                   len(grouped), len(block), len(rle)), flush=True)
            if args.native_fixtures and region == "physical_sector_suffix":
                for codec, compressed, version in (
                    ("grouped", grouped, "v1420"),
                    ("block", block, "v1424")):
                    target = args.output / (
                        "%s_%s_live_v1426.s" % (state, codec))
                    GROUP.emit(target, words, compressed, True, (),
                               version=version)
                emit_ram_native(
                    args.output / ("%s_ram_rle_live_v1426.s" % state),
                    words, rle)

    before = observed["idle_initial"][1]
    after = observed["after_commands"][1]
    if len(before) != len(after):
        raise ValueError("idle and command snapshots have different extents")
    diff = sum(a != b for a, b in zip(before, after))
    if diff == 0:
        raise ValueError("guest command did not change captured memory")
    print("LIVE_CHANGED_WORDS idle_vs_commands=%d" % diff)
    print("REAL_PROCESS_VM_GROWTH idle=%d after_functions=%d" %
          (observed["idle_initial"][0]["extent"],
           observed["after_function"][0]["extent"]))
    with (args.output / "results-live-v1426.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    (args.output / "capture-summary-v1426.json").write_text(json.dumps({
        "source": "real stopped SIMH PDP-6 DSH process physical memory",
        "states": {state: {**meta, "sha256_source": read_live(args.input, state)[2]}
                   for state, (meta, _) in observed.items()},
        "idle_command_changed_words": diff,
    }, indent=2, sort_keys=True) + "\n")
    print("PASS three actual DSH snapshots x three codecs x two regions",
          flush=True)


if __name__ == "__main__":
    main()
