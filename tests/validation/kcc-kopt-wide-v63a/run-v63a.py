#!/usr/bin/env python3
"""Compare the actual native-phase host builds before/after KPCODE4.

The two KGENs consume identical KIR2 files; their matching KOPTs must
emit identical assembly, including optimized split output. Retain the
streams and logs, and reject incompatible and malformed wide records.
"""
import concurrent.futures
import os
from pathlib import Path
import subprocess
import tempfile

HOME = Path.home()
BASE = Path(os.environ["KCC_BASE_SOURCE"]).resolve()
CAND = Path(os.environ.get("KCC_SOURCE", HOME / "git/kcc")).resolve()
TMP = Path(os.environ.get("TMPDIR") or HOME / "tmp")
TMP.mkdir(parents=True, exist_ok=True)
WORK = Path(tempfile.mkdtemp(prefix="kcc-kopt-wide-v63a.", dir=TMP))
STUB = Path(os.environ.get("PDP10_TESTKIT_REPO", HOME / "git/pdp10-testkit")) / "misc/kcc-regression/host-daimos-path-v1.c"
HERE = Path(__file__).resolve().parent
SOURCES = {
    "cpp": "cc ccasmb ccdata ccerr ccout ccpp ccppout ccsym ccsrc",
    "parse": "cc ccasmb ccdata ccbind ccdbug ccdecl ccerr cceval cclex ccnode ccppin ccstmt ccsym cctype ccoututil cckirwrite ccvla",
    "gen": "cckgen cccreg cccse cccode ccdata ccdbug ccerr ccevalgen ccgen ccgen1 ccgen2 ccgswi ccjskp ccnode ccreg ccsym cctype ccopt ccoututil cckpout cckpwrite cckirread ccvla",
    "opt": "cckopt cckpread ccout ccoututil ccdata ccerr ccasmb",
}


def run(args, cwd, log, *, stdout=None, fail=False):
    with open(log, "wb") as err:
        proc = subprocess.run([str(x) for x in args], cwd=cwd,
                              stdout=stdout or err, stderr=err)
    if (proc.returncode == 0) == fail:
        raise RuntimeError(f"unexpected exit {proc.returncode}: {args}; {log}")


def build(task):
    name, root, phase = task
    out = WORK / name
    args = [os.environ.get("HOSTCC", "cc"), "-std=c99", "-O0",
            "-funsigned-char", "-DHOST_DAIMOS=1", "-DHOST_UNIX=0",
            f"-DKCC_PHASE_{phase.upper()}=1"]
    args += [s + ".c" for s in SOURCES[phase].split()]
    run(args + [STUB, "-o", out], root, WORK / (name + ".log"))
    print("built", name, flush=True)


def records(data):
    assert data[:7] == b"KPCODE4" and int.from_bytes(data[7:12], "big") == 4
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


def wire_record(kind, words):
    return b"".join(v.to_bytes(5, "big") for v in [kind, len(words), *words])


def text_record(s):
    data = s.encode("ascii")
    packed = [int.from_bytes(data[i:i+4].ljust(4, b"\0"), "big")
              for i in range(0, len(data), 4)]
    return wire_record(19, [len(data), *packed])


def compare_text(flags, hrel, lrel, lab):
    # The original v62j templates, including stack and unsigned
    # ordering, independently reconstructed for fixed AC assignments.
    h1, l1, h2, l2, flag = 1, 2, 3, 4, 5
    label = ("%DIUCMP" if flags & 1 else "%DICMP") + str(lab)
    out = ""
    if (flags & 3) == 1:
        out += "\tTLC\t1,0400000\n\tTLC\t3,0400000\n"
    out += "\tSETZ\t5,\n"
    if flags & 2:
        out += "\tMOVE\t1,-1(17)\n"
        if flags & 1:
            out += "\tTLC\t1,0400000\n"
        out += "\tMOVE\t2,0(17)\n"
        if flags & 1:
            out += "\tTLC\t2,0400000\n\tTLC\t3,0400000\n"
    out += (f"\t{hrel}\t{h1:o},{h2:o}\n"
            f"\tJRST\t{label}H\n"
            f"\tJRST\t{label}T\n"
            f"{label}H:\n"
            f"\tCAME\t{h1:o},{h2:o}\n"
            f"\tJRST\t{label}D\n"
            f"\tJRST\t{label}E\n"
            f"{label}E:\n"
            f"\t{lrel}\t{l1:o},{l2:o}\n"
            f"\tJRST\t{label}D\n"
            f"{label}T:\n"
            f"\tMOVEI\t{flag:o},1\n"
            f"{label}D:\n")
    if flags & 2:
        out += "\tSUB\t17,[2,,2]\n"
    return out + "\tJUMPN\t5,.+2\n"


def direct_expansion(p, data):
    # Use the same module header and flags as a real compiler stream.
    # Construct one v3 raw text and one v4 typed stream for each case.
    # Derive the relation opcodes from the compiler headers.
    opfile = WORK / "relation-opcodes.c"
    opfile.write_text(
        '#include "cc.h"\n#include "ccgen.h"\n'
        'int main(void) { printf("%d %d %d %d\\n", '
        'P_CAM+POF_ISSKIP+POS_SKPL, P_CAM+POF_ISSKIP+POS_SKPLE, '
        'P_CAM+POF_ISSKIP+POS_SKPG, P_CAM+POF_ISSKIP+POS_SKPGE); return 0; }\n')
    exe = WORK / "relation-opcodes"
    run([os.environ.get("HOSTCC", "cc"), "-std=c99", "-I", CAND,
         opfile, "-o", exe], CAND, WORK / "relation-opcodes.log")
    ops = [int(x) for x in subprocess.check_output([exe], text=True).split()]
    relations = [(ops[0], "CAML", "CAML"), (ops[1], "CAML", "CAMLE"),
                 (ops[2], "CAMG", "CAMG"), (ops[3], "CAMG", "CAMGE")]
    begin = next(wire_record(kind, words) for _, kind, words in records(data)
                 if kind == 1)
    end = wire_record(20, [0])
    old_header = (p / "base.kp").read_bytes()[:37]
    cases = 0
    for flags in range(4):
        for op, hrel, lrel in relations:
            stem = WORK / ("direct-%d-%d" % (flags, op))
            old = stem.with_suffix(".v3")
            new = stem.with_suffix(".v4")
            old.write_bytes(old_header + begin +
                            text_record(compare_text(flags, hrel, lrel, 7)) + end)
            new.write_bytes(data[:37] + begin +
                            wire_record(21, [2, flags, op, 7, 1, 2, 3, 4, 5]) + end)
            for name, stream in [("base", old), ("cand", new)]:
                run([WORK / (name + "-opt"), stream,
                     "-R=" + str(stem) + "." + name + ".s"],
                    BASE, str(stem) + "." + name + ".log")
            assert Path(str(stem) + ".base.s").read_bytes() == Path(str(stem) + ".cand.s").read_bytes(), stem
            cases += 1
    print("PASS", cases, "direct comparison expansion cases", flush=True)


def main():
    print("evidence:", WORK, flush=True)
    jobs = [("cpp", BASE, "cpp"), ("parse", BASE, "parse"),
            ("base-gen", BASE, "gen"), ("base-opt", BASE, "opt"),
            ("cand-gen", CAND, "gen"), ("cand-opt", CAND, "opt")]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(build, jobs))
    count = 0
    kinds = set()
    compare_ops = set()
    example = None
    for src in [HERE / "fixture-v63a.c"] + sorted(BASE.glob("*.c")):
        for mode in ("-O", "-n"):
            p = WORK / (src.stem + ("-o" if mode == "-O" else "-n"))
            p.mkdir()
            kpt, kir = p / "x.kpt", p / "x.kir"
            common = ["-Pgnu99", mode, "-x=pdp6", "-m=gas",
                      "-DHOST_DAIMOS=1", "-DHOST_UNIX=0",
                      "-Iself/include/", "-Hself/include/"]
            with kpt.open("wb") as stream:
                run([WORK / "cpp", *common, src], BASE, p / "cpp.log", stdout=stream)
            run([WORK / "parse", "-Pgnu99", mode, "-x=pdp6", "-m=gas",
                 "-S", kpt, "-o", kir], BASE, p / "parse.log")
            for version in ("base", "cand"):
                kp = p / (version + ".kp")
                gen = [WORK / (version + "-gen")]
                if mode == "-n":
                    gen.append("-n")
                run(gen + [kir, "-R=" + str(kp)], BASE, p / (version + "-gen.log"))
                run([WORK / (version + "-opt"), kp, "-R=" + str(p / (version + ".s"))],
                    BASE, p / (version + "-opt.log"))
            assert (p / "base.s").read_bytes() == (p / "cand.s").read_bytes(), p
            data = (p / "cand.kp").read_bytes()
            for off, kind, words in records(data):
                if kind == 21:
                    assert len(words) == 9
                    kinds.add((words[0], words[1]))
                    if words[0] == 2:
                        compare_ops.add(words[2])
                    if example is None:
                        example = (p, off, data)
            count += 1
            print("identity", count, src.name, mode, flush=True)
    assert (1, 0) in kinds and (1, 1) in kinds
    assert (2, 0) in kinds and (2, 1) in kinds
    assert len(compare_ops) == 4
    assert example is not None
    p, off, data = example
    direct_expansion(p, data)
    bad = WORK / "bad.kp"
    # Invalid record kind, flags, register, and truncated payload.
    for index, value in [(0, 99), (1, 8), (4, 0), (8, 99)]:
        # flag is zero for add/sub, 1..17 for compares.
        corrupt = bytearray(data)
        corrupt[off+10+5*index:off+15+5*index] = value.to_bytes(5, "big")
        bad.write_bytes(corrupt)
        run([WORK / "cand-opt", bad, "-R=" + str(WORK / "bad.s")],
            BASE, WORK / ("bad-%d.log" % index), fail=True)
    bad.write_bytes(data[:off+12])
    run([WORK / "cand-opt", bad, "-R=" + str(WORK / "bad.s")],
        BASE, WORK / "truncated.log", fail=True)
    for exe, kp in [("base-opt", p / "cand.kp"), ("cand-opt", p / "base.kp")]:
        run([WORK / exe, kp, "-R=" + str(WORK / "bad.s")],
            BASE, WORK / (exe + "-version.log"), fail=True)
    print("PASS", count, "identity pairs; wide kinds/flags", sorted(kinds),
          "relations", sorted(compare_ops), flush=True)


if __name__ == "__main__":
    main()
