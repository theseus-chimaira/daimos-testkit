#!/usr/bin/env python3
"""Reject the old packed-string bug and execute the repaired assembly."""
import concurrent.futures
import importlib.util
import os
from pathlib import Path
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "phase_harness", HERE.parent / "kcc-kopt-wide-v63a/run-v63a.py")
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
h.WORK = Path(tempfile.mkdtemp(prefix="kcc-packed-string-v63b1.", dir=h.TMP))
W = h.WORK
print("evidence:", W, flush=True)
jobs = [("cpp", h.BASE, "cpp"), ("parse", h.BASE, "parse"),
        ("base-gen", h.BASE, "gen"), ("cand-gen", h.CAND, "gen"),
        ("cand-opt", h.CAND, "opt")]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    list(pool.map(h.build, jobs))
support = h.STUB.parent.parent.parent / "support"
p10run = Path(os.environ["PDP10_PREFIX"]) / "bin/p10run"
for mode in ("-O", "-n"):
    d = W / mode[1:]
    d.mkdir()
    kpt, kir, kp, asm = [d / name for name in ("x.kpt", "x.kir", "x.kp", "x.s")]
    with kpt.open("wb") as stream:
        h.run([W / "cpp", "-Pgnu99", mode, "-x=pdp6", "-m=gas",
               HERE / "fixture-v63b1.c"], h.BASE, d / "cpp.log", stdout=stream)
    h.run([W / "parse", "-Pgnu99", mode, "-x=pdp6", "-m=gas",
           "-S", kpt, "-o", kir], h.BASE, d / "parse.log")
    flag = ["-n"] if mode == "-n" else []
    h.run([W / "base-gen", *flag, kir, "-R=" + str(kp)],
          h.BASE, d / "old.log", fail=True)
    assert "GNU packed static scalar initializer must be an integer constant" in (d / "old.log").read_text()
    h.run([W / "cand-gen", *flag, kir, "-R=" + str(kp)],
          h.BASE, d / "fixed.log")
    h.run([W / "cand-opt", kp, "-R=" + str(asm)], h.BASE, d / "opt.log")
    h.run([p10run, "--machine", "pdp6", "--mode", "deposit",
           "--exec-mode", "step", "--step-limit", "900000", "--timeout", "35",
           "--workdir", d / "guest", "--name", "kcc-packed-string-v63b1-" + mode[1:],
           "--expect", "__test_exit=0", support / "crt0-upstream-v1.s",
           asm, support / "exit-v1.s", support / "abort-v1.s"],
          h.BASE, d / "guest.log")
    print("PASS packed string", mode, flush=True)
