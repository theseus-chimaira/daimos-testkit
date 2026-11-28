#!/usr/bin/env python3
"""Compare v63a and v63b split assembly using identical KIR2 inputs."""
import concurrent.futures
import importlib.util
from pathlib import Path
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "phase_harness", HERE.parent / "kcc-kopt-wide-v63a/run-v63a.py")
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
h.WORK = Path(tempfile.mkdtemp(prefix="kcc-kopt-expand-v63b.", dir=h.TMP))
W = h.WORK


def records(data):
    assert data[:7] == b"KPCODE5" and int.from_bytes(data[7:12], "big") == 5
    i = 37
    while i < len(data):
        kind = int.from_bytes(data[i:i+5], "big")
        n = int.from_bytes(data[i+5:i+10], "big")
        end = i + 10 + 5*n
        assert end <= len(data)
        yield i, kind, [int.from_bytes(data[j:j+5], "big")
                        for j in range(i+10, end, 5)]
        i = end
    assert i == len(data)


def direct_cases(p, data):
    # These forms are hard to force through the allocator. Compare their
    # actual typed replay against the old raw-text replay, independently.
    cases = [
        ([10, 1, 2], "\tPUSH\t17,1\n\tPUSH\t17,2\n"),
        ([17, 1, 2], "\tMOVE\t1,2\n\tTLC\t1,0400000\n"),
        ([18, 1, 2], "\tMOVE\t1,37777777777(17)\n\tMOVE\t2,0(17)\n"),
        ([19, 1, 2, 3], "\tDMOVE\t1,-1(17)\n\tSUB\t17,[2,,2]\n"
         "\tTLNE\t1,0400000\n\t TLO\t2,0400000\n"
         "\tDMOVEM\t1,0(3)\n\tTLZ\t2,0400000\n"),
        ([23, 1], "\tSETZ\t1,\n"),
    ]
    begin = next(h.wire_record(kind, words) for _, kind, words in records(data)
                 if kind == 1)
    end = h.wire_record(20, [0])
    old_header = (p / "base.kp").read_bytes()[:37]
    for words, asm in cases:
        stem = W / ("direct-%d" % words[0])
        old = stem.with_suffix(".v4")
        new = stem.with_suffix(".v5")
        old.write_bytes(old_header + begin + h.text_record(asm) + end)
        new.write_bytes(data[:37] + begin + h.wire_record(22, words) + end)
        for name, stream in [("base", old), ("cand", new)]:
            h.run([W / (name + "-opt"), stream,
                   "-R=" + str(stem) + "." + name + ".s"],
                  h.BASE, str(stem) + "." + name + ".log")
        assert Path(str(stem) + ".base.s").read_bytes() == Path(str(stem) + ".cand.s").read_bytes(), stem
    print("PASS", len(cases), "direct fixed expansion cases", flush=True)
    return {words[0] for words, _ in cases}


def main():
    print("evidence:", W, flush=True)
    jobs = [("cpp", h.BASE, "cpp"), ("parse", h.BASE, "parse"),
            ("base-gen", h.BASE, "gen"), ("base-opt", h.BASE, "opt"),
            ("cand-gen", h.CAND, "gen"), ("cand-opt", h.CAND, "opt")]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(h.build, jobs))
    regression = h.STUB.parent.parent.parent / "tests/semantic/regression"
    fixtures = [HERE / "fixture-v63b.c",
                *sorted(regression.glob("kcc-wide-*.c"))]
    sources = fixtures + sorted(h.BASE.glob("*.c"))
    count = 0
    ops = set()
    div_modes = set()
    example = None
    for target in ("pdp6", "ki10"):
        for src in sources if target == "pdp6" else fixtures:
            for mode in ("-O", "-n"):
                p = W / (src.stem + "-" + target + ("-o" if mode == "-O" else "-n"))
                p.mkdir()
                kpt, kir = p / "x.kpt", p / "x.kir"
                common = ["-Pgnu99", mode, "-x=" + target, "-m=gas",
                          "-DHOST_DAIMOS=1", "-DHOST_UNIX=0",
                          "-Iself/include/", "-Hself/include/"]
                with kpt.open("wb") as stream:
                    h.run([W / "cpp", *common, src], h.BASE, p / "cpp.log", stdout=stream)
                h.run([W / "parse", "-Pgnu99", mode, "-x=" + target,
                       "-m=gas", "-S", kpt, "-o", kir], h.BASE, p / "parse.log")
                for version in ("base", "cand"):
                    kp = p / (version + ".kp")
                    gen = [W / (version + "-gen")]
                    if mode == "-n":
                        gen.append("-n")
                    h.run(gen + [kir, "-R=" + str(kp)], h.BASE, p / (version + "-gen.log"))
                    h.run([W / (version + "-opt"), kp, "-R=" + str(p / (version + ".s"))],
                          h.BASE, p / (version + "-opt.log"))
                assert (p / "base.s").read_bytes() == (p / "cand.s").read_bytes(), p
                data = (p / "cand.kp").read_bytes()
                for off, kind, words in records(data):
                    if kind == 22:
                        ops.add(words[0])
                        if words[0] == 2:
                            div_modes.add(tuple(words[1:3]))
                            example = (p, off, data)
                count += 1
                print("identity", count, src.name, target, mode, flush=True)
    assert 1 in ops and 2 in ops and len(div_modes) == 4, (ops, div_modes)
    p, off, data = example
    direct = direct_cases(p, data)
    assert ops | direct == set(range(1, 31)), (ops, direct)
    bad = W / "bad.kp"
    # Unknown operation, invalid signedness, invalid physical register.
    for index, value in [(0, 999), (1, 2), (4, 99)]:
        corrupt = bytearray(data)
        corrupt[off+10+5*index:off+15+5*index] = value.to_bytes(5, "big")
        bad.write_bytes(corrupt)
        h.run([W / "cand-opt", bad, "-R=" + str(W / "bad.s")],
              h.BASE, W / ("bad-%d.log" % index), fail=True)
    bad.write_bytes(data[:off+12])
    h.run([W / "cand-opt", bad, "-R=" + str(W / "bad.s")],
          h.BASE, W / "truncated.log", fail=True)
    for exe, kp in [("base-opt", p / "cand.kp"), ("cand-opt", p / "base.kp")]:
        h.run([W / exe, kp, "-R=" + str(W / "bad.s")],
              h.BASE, W / (exe + "-version.log"), fail=True)
    print("PASS", count, "identity pairs; operations", sorted(ops),
          "divider variants", sorted(div_modes), flush=True)


if __name__ == "__main__":
    main()
