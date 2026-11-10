#!/usr/bin/env python3
"""Illustrative PDP-6 execution estimates with BLT transfer costs.

DEC PDP-6 brochure F-61 (1964) gives BLT fast=1.5+0.8*n us and
slow=2.4+1.2*n us for n word transfers. The timings for all other
instructions vary by instruction, operand and memory; a fixed 2.5
fast / 4.0 slow us per non-BLT instruction is ONLY a comparison
model, not a hardware-time measurement or a cycle-accurate simulation.
"""
from pathlib import Path
import csv
import sys


def table(path, keys, value):
    with path.open() as f:
        return {tuple(row[k] for k in keys): int(row[value])
                for row in csv.DictReader(f, delimiter="\t")}


def main():
    work = Path(sys.argv[1])
    steps = table(work / "steps-v1422.tsv",
                  ("codec", "workload"), "steps")
    register = table(
        work.parent / "d6codec-register-v1424/steps-v1424.tsv",
        ("workload",), "steps")
    for (task,), value in register.items():
        steps[("register", task)] = value
    with (work / "blt-stats-v1422.tsv").open() as f:
        blt_rows = list(csv.DictReader(f, delimiter="\t"))
    blt = {}
    for row in blt_rows:
        codec, task = row["codec"], row["workload"]
        blt[(codec, task)] = (int(row["decoded"]),
                              int(row["blt_calls"]),
                              int(row["blt_words"]))
        if codec == "block":
            # Same block stream, but AC10..AC15 instead of AC10..AC16
            # are saved/restored in the compact adapter.
            blt[("register", task)] = (int(row["decoded"]),
                                       int(row["blt_calls"]),
                                       int(row["blt_words"]) - 2)
    output = ["codec\tworkload\tsteps\tdecoded\t"
              "slow_words_per_sec\tfast_words_per_sec"]
    for task in ("zeros", "normal", "literal", "overlap", "worst"):
        for codec in ("baseline", "grouped", "block", "register"):
            n, calls, words = blt[(codec, task)]
            instr = steps[(codec, task)]
            assert calls <= instr
            remaining = instr - calls
            slow_us = remaining * 4.0 + calls * 2.4 + words * 1.2
            fast_us = remaining * 2.5 + calls * 1.5 + words * 0.8
            line = "%s\t%s\t%d\t%d\t%d\t%d" % (
                codec, task, instr, n,
                round(n * 1000000.0 / slow_us),
                round(n * 1000000.0 / fast_us))
            print(line)
            output.append(line)
    (work / "hardware-model-v1424.tsv").write_text(
        "\n".join(output) + "\n")


if __name__ == "__main__":
    main()
