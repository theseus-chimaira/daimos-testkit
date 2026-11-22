#!/usr/bin/env python3
"""Reject source-linked physical MRES fault witness tampering."""
import importlib.util
import re
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 5:
        raise ValueError("usage: test-fault-negative-v1679.py "
                         "console.clean kcore.map pure.map workdir")
    console, coremap, puremap, out = sys.argv[1:]
    work = Path(out)
    work.mkdir(parents=True, exist_ok=True)
    source = Path(console).read_text(encoding="ascii")
    modfile = Path(__file__).with_name("verify-fault-v1679.py")
    spec = importlib.util.spec_from_file_location("v1679_verifier", modfile)
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    physical = verifier.verify(console, coremap, puremap)
    service = verifier.symbol(coremap, "proc_swap_reclaim")

    def inject(address, mode):
        pat = r"(?m)^((?:sim> )?%o:\s+)([0-7]{12})(\s*)$" % address
        hits = list(re.finditer(pat, source))
        if len(hits) != 1:
            raise ValueError("physical witness mutation target ambiguous")
        hit = hits[0]
        if mode == "zero":
            new = hit.group(1) + "000000000000" + hit.group(3)
            return source[:hit.start()] + new + source[hit.end():]
        if mode == "wrong-opcode":
            word = int(hit.group(2), 8) ^ (1 << 27)
            new = hit.group(1) + "%012o" % word + hit.group(3)
            return source[:hit.start()] + new + source[hit.end():]
        if mode == "duplicate":
            return (source[:hit.end()] + "\n" + hit.group(1) +
                    hit.group(2) + source[hit.end():])
        raise ValueError("unsupported mutation")

    for name, target, mode in (("missing-rebase-count", physical, "zero"),
                                ("bad-jrst", service, "wrong-opcode"),
                                ("duplicate-count", physical, "duplicate")):
        candidate = work / ("v1679-unsafe-" + name + ".clean")
        candidate.write_text(inject(target, mode), encoding="ascii")
        try:
            verifier.verify(str(candidate), coremap, puremap)
        except ValueError as exc:
            print("PASS v1679: unsafe " + name + " rejected: " + str(exc))
        else:
            raise ValueError("unsafe source-linked fault witness accepted: " +
                             name)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1679 physical witness mutants: " + str(exc))
