#!/usr/bin/env python3
"""Source-linked negative controls for real STOP/PACKED foreign TERM.

Mutate only copied original SIMH physical checkpoint B evidence. Never
change the accepted source recording or relax the original MM oracle.
"""
import importlib.util
import re
import subprocess
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 6:
        raise ValueError("usage: test-negative-v1682.py fixture.map "
                         "kcore.map original-console.clean variant workdir")
    fixture, coremap, console, variant, workdir = sys.argv[1:]
    out = Path(workdir)
    out.mkdir(parents=True, exist_ok=True)
    src = Path(console).read_text(encoding="ascii")
    oldfile = Path(__file__).parent.parent / "pure-runtime-reclaim-v1673" / \
              "measure-v1673.py"
    spec = importlib.util.spec_from_file_location("original_mm_v1673", oldfile)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    views = old.observations(src, fixture)
    word_map = views[1]["words"]
    table = word_map[old.lookup(coremap, "proc_table")]
    meta = word_map[table + 6]
    uarea = (meta >> 18) & ((1 << 18) - 1)
    pc = uarea + 0o20
    sched = table + 8
    physical = {"bad-user-pc": (pc, word_map[pc] & ~(0o10000 << 18)),
                "forged-exec-wait": (sched, word_map[sched] |
                                     (0o20000 << 18)),
                "wrong-stop-state": (sched, word_map[sched] &
                                     ~(7 << 33) | (3 << 33))}
    a = src.index("V1673 HOLD B")
    b = src.index("V1673 RELEASE B", a)

    def swap_word(addr, value):
        section = src[a:b]
        pat = r"(?m)^((?:sim> )?%o:\s+)([0-7]{12})(\s*)$" % addr
        matches = list(re.finditer(pat, section))
        if len(matches) != 1:
            raise ValueError("missing or duplicate true physical word %o" % addr)
        match = matches[0]
        mutated = (section[:match.start()] + match.group(1) +
                   "%012o" % value + match.group(3) +
                   section[match.end():])
        return src[:a] + mutated + src[b:]

    cases = {name: swap_word(addr, value)
             for name, (addr, value) in physical.items()}
    marker = "V1682 FOREIGN TERM ACCEPTED"
    if src.count(marker) != 1:
        raise ValueError("missing original accepted foreign TERM")
    cases["missing-foreign-term"] = src.replace(
        marker, "V1682 NOT ACCEPTED", 1)
    marker = "V1682 APR WORDS 3072"
    if src.count(marker) != 1:
        raise ValueError("missing real native APR growth observation")
    cases["missing-apr-growth"] = src.replace(
        marker, "V1682 APR WORDS 1024", 1)
    for name, altered in cases.items():
        evidence = out / (variant + "-" + name + ".clean")
        report = out / (variant + "-" + name + ".json")
        evidence.write_text(altered, encoding="ascii")
        proc = subprocess.run([
            sys.executable, str(Path(__file__).with_name("measure-v1682.py")),
            fixture, coremap, str(evidence), "48", str(report)],
            capture_output=True, text=True)
        if proc.returncode == 0 or "FAIL v1682 original STOP/TERM context" \
                not in proc.stderr:
            raise ValueError("invalid original physical witness accepted: " +
                             name + " (" + proc.stderr[:150] + ")")
        print("PASS v1682: original source witness mutant rejected: " + name)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, UnicodeError) as exc:
        raise SystemExit("FAIL v1682 physical negative controls: " + str(exc))
