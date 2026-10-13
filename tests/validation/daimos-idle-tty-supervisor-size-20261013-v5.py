#!/usr/bin/env python3
"""DXR2 size guard for the opt-in on-demand LOGIN SUPERVISOR image."""
import re
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: guard.py SUPERVISOR.dxr 'dxrcheck result'")
    result = sys.argv[2]
    match = re.search(r"DXR image=([0-7]+) bss=([0-7]+)", result)
    if not match:
        raise SystemExit("FAIL: no DXR image/BSS")
    image, bss = (int(w, 8) for w in match.groups())
    data = Path(sys.argv[1]).read_bytes()
    if len(data) < 24:
        raise SystemExit("FAIL: truncated DXR2")
    st2 = int.from_bytes(data[16:24], "little")
    if (st2 & 0o777777) != 0o636422 or st2 >> 18 != 0o400:
        raise SystemExit("FAIL: incorrect ST2 stack metadata")
    total = image + bss + 0o20 + 0o400
    extent = (total + 0o1777) & ~0o1777
    if extent > 0o4000:
        raise SystemExit("FAIL: opt-in supervisor grew past two APR blocks")
    print("PASS idle supervisor image=%o BSS=%o required=%o extent=%o" %
          (image, bss, total, extent))


if __name__ == "__main__":
    main()
