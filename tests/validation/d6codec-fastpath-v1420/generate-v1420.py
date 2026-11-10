#!/usr/bin/env python3
"""Independent grouped D6CODEC v1420 native fixtures and corpus sizes.

Tests belong in daimos-testkit, not the production kernel tree.
Do not infer PDP-6 microseconds from simulator instruction limits.
"""
import argparse
import importlib.util
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[3]

spec = importlib.util.spec_from_file_location(
    "dxr_v039", ROOT / "tests/host/d6codec-v039/compare-v039.py")
dxr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dxr)


def encode(words):
    tokens = []
    p = 0
    while p < len(words):
        maximum = min(127, len(words) - p)
        if words[p] == 0:
            k = 1
            while k < maximum and words[p + k] == 0:
                k += 1
            tokens.append((1, 1, k, 0))
            p += k
            continue
        best, distance = 0, 0
        for d in range(min(128, p), 0, -1):
            k = 0
            while k < maximum and words[p + k] == words[p + k - d]:
                k += 1
            if k > best:
                best, distance = k, d
            if k == 127:
                break
        if best >= 2:
            tokens.append((1, 0, best, distance))
            p += best
        else:
            tokens.append((0, words[p]))
            p += 1
    return group_tokens(tokens)


def group_tokens(tokens):
    packed = []
    for start in range(0, len(tokens), 30):
        group = tokens[start:start + 30]
        flags, descriptors, literals = 0, [], []
        for i, token in enumerate(group):
            if token[0]:
                flags |= 1 << (29 - i)
                descriptors.append(
                    (token[1] << 16) | (token[2] << 9) | token[3])
            else:
                literals.append(token[1])
        packed.append((len(group) << 30) | flags)
        for i in range(0, len(descriptors), 2):
            right = descriptors[i + 1] if i + 1 < len(descriptors) else 0
            packed.append((descriptors[i] << 18) | right)
        packed.extend(literals)
    return packed


def emit(path, raw, packed, verify, refills, version="v1420"):
    assert 0 < len(raw) < (1 << 18)
    assert all(0 <= w < (1 << 36) for w in raw + packed)
    code = [
        "/* Generated grouped D6CODEC fixture v1420. */",
        ".text",
        ".globl main",
        ".globl d6codec_decode_buffer_v1420",
        ".globl d6codec_decode_vfs_v1420",
        ".globl vfs_read_words",
        "main:"
    ]
    def call(vnode):
        if vnode == 0:
            code.extend([
                " movei 2,compressed",
                " movei 3,0%o" % len(packed),
                " movei 4,decoded",
                " hrli 4,0%o" % len(raw),
                " pushj 17,d6codec_decode_buffer_v1420"
            ])
        else:
            code.extend([
                " movei 1,0%o" % vnode,
                " setz 2,",
                " movei 3,0%o" % len(packed),
                " movei 4,decoded",
                " hrli 4,0%o" % len(raw),
                " pushj 17,d6codec_decode_vfs_v1420"
            ])
        code.append(" jumpn 1,fail")
        if verify:
            code.extend([" pushj 17,verify", " jumpn 1,fail"])
    call(0)
    for n in refills:
        call(n)
    code.extend([
        " setz 1,",
        " popj 17,",
        "verify:",
        " movei 5,0",
        "verify_loop:",
        " move 6,source(5)",
        " came 6,decoded(5)",
        " jrst fail",
        " aoj 5,",
        " caige 5,0%o" % len(raw),
        " jrst verify_loop",
        " setz 1,",
        " popj 17,",
        "fail:",
        " movei 1,1",
        " popj 17,",
        "vfs_read_words:",
        " move 5,4",                      # requested words
        " camle 5,1",                    # vnode is maximum short read
        " move 5,1",
        " move 6,[0%o]" % len(packed),
        " sub 6,2",
        " jumple 6,vfs_fail",
        " camle 5,6",
        " move 5,6",
        " move 1,5",                      # actual words returned
        " movei 6,compressed",
        " add 6,2",
        " move 7,3",
        "vfs_copy:",
        " move 0,0(6)",
        " movem 0,0(7)",
        " aoj 6,",
        " aoj 7,",
        " sojg 5,vfs_copy",
        " popj 17,",
        "vfs_fail:",
        " seto 1,",
        " popj 17,",
        ".data",
        "source:"
    ])
    code.extend(" .word 0%o" % w for w in raw)
    code.append("compressed:")
    code.extend(" .word 0%o" % w for w in packed)
    code.extend([
        ".bss",
        "decoded: .block 0%o" % len(raw),
        ".globl __test_exit",
        "__test_exit: .block 1"
    ])
    if version != "v1420":
        code = [line.replace("v1420", version) for line in code]
    path.write_text("\n".join(code) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dxr_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    dxrs = sorted(args.dxr_dir.glob("*.dxr"))
    if not dxrs:
        raise ValueError("missing real DXR files")
    lengths = []
    sample = []
    for file in dxrs:
        raw = list(dxr.load(file))
        packed = encode(raw)
        lengths.append((file.name, len(raw), len(packed)))
        # Use distinct DXR prefixes; repeating five prefixes four
        # times would artificially create excellent cross-file matches.
        sample.extend(raw[:128])
    sample = sample[:2560]
    assert 2000 <= len(sample) <= 2560
    (args.output_dir / "corpus-v1420.tsv").write_text(
        "file\twords\tgrouped_words\n" +
        "".join("%s\t%d\t%d\n" % v for v in lengths))
    rng = random.Random(1420)
    cases = {
        "normal": (sample, encode(sample)),
        "zeros": ([0] * 3810, group_tokens([(1, 1, 127, 0)] * 30)),
        "literal": ([rng.getrandbits(36) or 1 for _ in range(1920)], None),
        "overlap": ([0o123456701234] * 2033, None),
        "worst": ([0o12345] * 1500, group_tokens(
            [(0, 0o12345)] + [(1, 0, 1, 1)] * 1499))
    }
    # The pathological one-word match stream is valid but never
    # produced by the reference encoder (its threshold is >=2).
    for name, (raw, packed) in cases.items():
        if packed is None:
            packed = encode(raw)
        for suffix, verify, refills in [
            ("bench", False, ()),
            ("verify", True, ()),
            ("refill", True, (1, 7, 32)) if name == "overlap"
            else ("refill", True, (7,))
        ]:
            if suffix == "refill" and name in ("zeros", "worst"):
                continue
            emit(args.output_dir / ("%s_%s_v1420.s" % (name, suffix)),
                 raw, packed, verify, refills)
        print("%s: output=%d compressed=%d" % (name, len(raw), len(packed)))
    print("corpus: files=%d input=%d grouped=%d" % (
        len(lengths), sum(row[1] for row in lengths),
        sum(row[2] for row in lengths)))


if __name__ == "__main__":
    main()
