#!/usr/bin/env python3
"""Write deterministic native KCC/DOBJ1/DLINK relocation acceptance probes."""

from pathlib import Path
import sys


MODULES = (
    ("call-main", "CM"),
    ("call-provider", "CP"),
    ("data-main", "DM"),
    ("data-provider", "DP"),
    ("local-main", "LM"),
)


def probe(lines, name, command, status, timeout=175):
    lines.extend(("probe " + name,
                  "command " + command + "; ECHO " + status + ":$?",
                  "contains " + status + ":0",
                  "not_contains UUO",
                  "timeout " + str(timeout),
                  "end"))


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: make_probes_v1405.py OUTPUT")
    lines = ["# Native DOBJ1 external/local relocations: status and bytes."]
    for stem, abbrev in MODULES:
        label = stem.replace("-", "").upper()
        obj = "/SCRATCH/V5" + abbrev
        fixture = "/CONFIG/V1405-" + label
        probe(lines, "v1405-" + stem + "-compile",
              "/OPTION/BASE/EXEC/KCC -Pgnu99 -O -x=pdp6 -m=gas -S "
              "-O " + obj + ".A7 " + fixture + ".C",
              abbrev + "KCC", 230)
        probe(lines, "v1405-" + stem + "-asm-equality",
              "CMP " + obj + ".A7 " + fixture + ".A7",
              abbrev + "ASM", 70)
        probe(lines, "v1405-" + stem + "-native-dobj",
              "/OPTION/BASE/EXEC/DAS -A -C -O " + obj + ".DOBJ " +
              obj + ".A7", abbrev + "DAS", 205)
        probe(lines, "v1405-" + stem + "-dobj-equality",
              "CMP " + obj + ".DOBJ " + fixture + ".DOBJ",
              abbrev + "OBJ", 70)

    for kind, abbrevs in (("CALL", ("CM", "CP")),
                          ("DATA", ("DM", "DP")),
                          ("LOCAL", ("LM",))):
        objects = " ".join("/SCRATCH/V5" + ab + ".DOBJ" for ab in abbrevs)
        dxr = "/SCRATCH/V5" + kind + ".DXR"
        probe(lines, "v1405-" + kind.lower() + "-native-link",
              "/OPTION/BASE/EXEC/DLINK -O " + dxr + " -B 020 "
              "/CONFIG/V1403-CRT0.DOBJ " + objects +
              " /CONFIG/V1403-SYSCALL.DOBJ", kind + "LINK", 220)
        probe(lines, "v1405-" + kind.lower() + "-image-equality",
              "CMP " + dxr + " /CONFIG/V1405-" + kind + "-GOLD.DXR",
              kind + "CMP", 75)
        lines.extend(("probe v1405-" + kind.lower() + "-c89-run",
                      "command " + dxr + "; ECHO " + kind + "RUN:$?",
                      "contains " + kind + "RUN:7",
                      "not_contains UUO",
                      "timeout 90",
                      "end"))
    Path(sys.argv[1]).write_text("\n".join(lines) + "\n",
                                 encoding="ascii")
    print("V1405_PROBES_PASS count=%d" % sum(
        text.startswith("probe ") for text in lines))


if __name__ == "__main__":
    main()
