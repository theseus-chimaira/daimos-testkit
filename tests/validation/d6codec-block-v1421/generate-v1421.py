#!/usr/bin/env python3
"""Experimental PDP-6 36-bit block LZ/RLE v1421 host encoder and fixtures.

This is a separate experimental stream. It is not valid grouped D6CODEC.
All output and independent roundtrip checks remain in daimos-testkit.
"""
import argparse
import importlib.util
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location(
    "grouped_v1420",
    ROOT / "tests/validation/d6codec-fastpath-v1420/generate-v1420.py")
grouped = importlib.util.module_from_spec(spec)
spec.loader.exec_module(grouped)


def command(kind, n, distance=0):
    if not 1 <= n <= 128:
        raise ValueError("invalid block length")
    if kind == 2:
        if not 1 <= distance <= 512:
            raise ValueError("invalid distance")
        dist = distance - 1
    else:
        if distance:
            raise ValueError("unexpected distance")
        dist = 0
    return (kind << 34) | ((n - 1) << 27) | (dist << 18)


def encode(src):
    output, literal = [], []
    p = 0

    def flush():
        if literal:
            output.append(command(0, len(literal)))
            output.extend(literal)
            literal.clear()

    while p < len(src):
        maximum = min(128, len(src) - p)
        zero = 0
        if src[p] == 0:
            while zero < maximum and src[p + zero] == 0:
                zero += 1
        best, best_dist = 0, 0
        if zero < 2:
            for d in range(min(128, p), 0, -1):
                k = 0
                while k < maximum and src[p + k] == src[p + k - d]:
                    k += 1
                if k > best:
                    best, best_dist = k, d
                if k == 128:
                    break
        if zero >= 2:
            flush()
            output.append(command(1, zero))
            p += zero
        elif best >= 3:
            flush()
            output.append(command(2, best, best_dist))
            p += best
        else:
            literal.append(src[p])
            p += 1
            if len(literal) == 128:
                flush()
    flush()
    return output


def decode(encoded, decoded_words):
    output, i = [], 0
    while len(output) < decoded_words:
        if i == len(encoded):
            raise ValueError("truncated commands")
        cmd = encoded[i]
        i += 1
        if cmd & ((1 << 18) - 1):
            raise ValueError("reserved bits")
        kind = cmd >> 34
        n = ((cmd >> 27) & 127) + 1
        d = ((cmd >> 18) & 511)
        if n + len(output) > decoded_words:
            raise ValueError("output overflow")
        if kind == 0:
            if d or i + n > len(encoded):
                raise ValueError("invalid literal")
            output.extend(encoded[i:i + n])
            i += n
        elif kind == 1:
            if d:
                raise ValueError("invalid zero run")
            output.extend([0] * n)
        elif kind == 2:
            d += 1
            if d > len(output):
                raise ValueError("invalid reference")
            for _ in range(n):
                output.append(output[-d])
        else:
            raise ValueError("reserved opcode")
    if len(output) != decoded_words or i != len(encoded):
        raise ValueError("nonexact stream")
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dxr_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    dxrs = sorted(args.dxr_dir.glob("*.dxr"))
    if not dxrs:
        raise ValueError("missing actual DXR files")
    rows, sample = [], []
    for path in dxrs:
        words = list(grouped.dxr.load(path))
        packed = encode(words)
        if decode(packed, len(words)) != words:
            raise ValueError("host roundtrip: " + path.name)
        rows.append((path.name, len(words), len(packed)))
        sample.extend(words[:128])
    sample = sample[:2560]
    assert 2000 <= len(sample) <= 2560
    (args.output_dir / "corpus-v1421.tsv").write_text(
        "file\twords\tblock_words\n" +
        "".join("%s\t%d\t%d\n" % r for r in rows))
    rng = random.Random(1420)
    cases = {
        "normal": sample,
        "zeros": [0] * 3810,
        "literal": [rng.getrandbits(36) or 1 for _ in range(1920)],
        "overlap": [0o123456701234] * 2033,
        "worst": [0o12345] * 1500
    }
    for name, raw in cases.items():
        if name == "worst":
            # Deliberately inefficient legal one-word match stream.
            # The production-intended encoder would combine these runs.
            packed = [command(0, 1), raw[0]] + [
                command(2, 1, 1)] * (len(raw) - 1)
        else:
            packed = encode(raw)
        assert decode(packed, len(raw)) == raw
        for mode, verify, refills in [
            ("bench", False, ()),
            ("verify", True, ()),
            ("refill", True, (1, 7, 32)) if name == "overlap"
            else ("refill", True, (7,))
        ]:
            if mode == "refill" and name in ("zeros", "worst"):
                continue
            grouped.emit(args.output_dir / ("%s_%s_v1421.s" % (name, mode)),
                         raw, packed, verify, refills, version="v1421")
        print("%s: output=%d compressed=%d" %
              (name, len(raw), len(packed)))
    print("corpus: files=%d input=%d block=%d" % (
        len(rows), sum(r[1] for r in rows), sum(r[2] for r in rows)))


if __name__ == "__main__":
    main()
