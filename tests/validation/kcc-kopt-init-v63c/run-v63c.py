#!/usr/bin/env python3
"""Compare v63b and v63c initializer emission and wire footprints."""
import concurrent.futures
import importlib.util
from pathlib import Path
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "phase_harness", HERE.parent / "kcc-kopt-wide-v63a/run-v63a.py")
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
h.WORK = Path(tempfile.mkdtemp(prefix="kcc-kopt-init-v63c.", dir=h.TMP))
W = h.WORK


def records(data):
    assert data[:7] == b"KPCODE6" and int.from_bytes(data[7:12], "big") == 6
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


def main():
    print("evidence:", W, flush=True)
    jobs = [("cpp", h.BASE, "cpp"), ("parse", h.BASE, "parse"),
            ("base-gen", h.BASE, "gen"), ("base-opt", h.BASE, "opt"),
            ("cand-gen", h.CAND, "gen"), ("cand-opt", h.CAND, "opt")]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(h.build, jobs))
    regression = h.STUB.parent.parent.parent / "tests/semantic/regression"
    patterns = ("kcc-static-*.c", "*initializer*.c",
                "kcc-packed-tag-layout*.c", "kcc-wide-field-boundaries*.c",
                "global_packed_init*.c", "kcc-wide-literal*.c")
    fixtures = [HERE / "fixture-v63c.c"] + sorted(set(
        p for pattern in patterns for p in regression.glob(pattern)))
    count = 0
    rejected = 0
    coverage = set()
    sizes = [0, 0]
    examples = {}
    for target in ("pdp6", "ki10"):
        sources = fixtures + sorted(h.BASE.glob("*.c")) if target == "pdp6" else fixtures
        for src in sources:
            for mode in ("-O", "-n"):
                p = W / ("case-%03d" % (count + rejected + 1))
                p.mkdir()
                kpt, kir = p / "x.kpt", p / "x.kir"
                common = ["-Pgnu99", mode, "-x=" + target, "-m=gas",
                          "-DHOST_DAIMOS=1", "-DHOST_UNIX=0",
                          "-Iself/include/", "-Hself/include/",
                          "-I" + str(regression.parent.parent.parent / "support/common"),
                          "-I" + str(regression.parent.parent.parent / "support/include")]
                # The native compiler has a 102-character path contract.
                # Preserve the source directory for quoted includes.
                input_path = src
                if len(str(src)) > 102:
                    input_path = p / "source.c"
                    input_path.write_bytes(src.read_bytes())
                    common.append("-I" + str(src.parent))
                with kpt.open("wb") as stream:
                    h.run([W / "cpp", *common, input_path], h.BASE, p / "cpp.log", stdout=stream)
                parse_args = [W / "parse", "-Pgnu99", mode, "-x=" + target,
                              "-m=gas", "-S", kpt, "-o", kir]
                if src.name == "pdp10-flexible-string-initializers-v1.c":
                    # Existing unsupported GNU flexible-array initialization
                    # is rejected in KPARSE before any backend record exists.
                    h.run(parse_args, h.BASE, p / "parse.log", fail=True)
                    assert "Flexible or incomplete array member cannot be initialized" in (p / "parse.log").read_text()
                    rejected += 1
                    print("existing parser rejection", src.name, target, mode, flush=True)
                    continue
                h.run(parse_args, h.BASE, p / "parse.log")
                for idx, version in enumerate(("base", "cand")):
                    kp = p / (version + ".kp")
                    gen = [W / (version + "-gen")]
                    if mode == "-n":
                        gen.append("-n")
                    h.run(gen + [kir, "-R=" + str(kp)], h.BASE, p / (version + "-gen.log"))
                    h.run([W / (version + "-opt"), kp, "-R=" + str(p / (version + ".s"))],
                          h.BASE, p / (version + "-opt.log"))
                    sizes[idx] += kp.stat().st_size
                assert (p / "base.s").read_bytes() == (p / "cand.s").read_bytes(), p
                data = (p / "cand.kp").read_bytes()
                for off, kind, words in records(data):
                    if kind == 23:
                        coverage.add((words[0], words[1]))
                        examples[words[0]] = (p, off, data)
                    if kind == 24:
                        coverage.add((24, 0))
                        examples[24] = (p, off, data)
                count += 1
                print("identity", count, src.name, target, mode, flush=True)
    required = {(1, 0), (2, 1), (2, 2), (2, 3), (3, 1),
                (4, 0), (24, 0)}
    assert required <= coverage, (coverage, required - coverage)
    bad = W / "bad.kp"
    # Bad kind, invalid byte mode/width, and bad label symbol reference.
    for key, index, value in [(1, 0, 99), (2, 1, 99), (2, 2, 37),
                              (3, 3, 1), (24, 0, 0), (24, 2, 72)]:
        p, off, data = examples[key]
        corrupt = bytearray(data)
        corrupt[off+10+5*index:off+15+5*index] = value.to_bytes(5, "big")
        bad.write_bytes(corrupt)
        h.run([W / "cand-opt", bad, "-R=" + str(W / "bad.s")],
              h.BASE, W / ("bad-%d-%d.log" % (key, index)), fail=True)
    p, off, data = examples[2]
    bad.write_bytes(data[:off+12])
    h.run([W / "cand-opt", bad, "-R=" + str(W / "bad.s")],
          h.BASE, W / "truncated.log", fail=True)
    for exe, kp in [("base-opt", p / "cand.kp"), ("cand-opt", p / "base.kp")]:
        h.run([W / exe, kp, "-R=" + str(W / "bad.s")],
              h.BASE, W / (exe + "-version.log"), fail=True)
    print("PASS", count, "identity pairs; initializer coverage", sorted(coverage),
          "KPCODE bytes", sizes, "existing parser rejections", rejected, flush=True)


if __name__ == "__main__":
    main()
