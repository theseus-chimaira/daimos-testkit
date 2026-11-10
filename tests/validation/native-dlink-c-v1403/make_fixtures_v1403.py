#!/usr/bin/env python3
"""Build C89 host DOBJ and independent DXR reference for native DLINK."""

from pathlib import Path
import struct
import subprocess
import sys


def run(*args):
    subprocess.run([str(x) for x in args], check=True)


def ascii7(data):
    if any(ch == 0 or ch > 127 for ch in data):
        raise ValueError("host assembler output is not ASCII7")
    words = []
    for pos in range(0, len(data), 5):
        value = 0
        for i, ch in enumerate(data[pos:pos + 5]):
            value |= ch << (29 - i * 7)
        words.append(value)
    return struct.pack("<" + "Q" * len(words), *words)


def main():
    if len(sys.argv) != 8:
        raise SystemExit("usage: make_fixtures_v1403.py KCC DAS DLINK CSIX "
                         "SOURCE OUTPUT LIBC")
    kcc, das, dlink, csix, source, out, libc = sys.argv[1:]
    root = Path(out)
    root.mkdir(parents=True, exist_ok=False)
    src = root / "native-main-v1403.c"
    src.write_bytes(Path(source).read_bytes())
    asm = root / "native-main-v1403.s"
    run(kcc, "-Pgnu99", "-O", "-x=pdp6", "-m=gas", "-S", src,
        "-o", asm)
    (root / "native-main-v1403.a7").write_bytes(ascii7(asm.read_bytes()))
    run(csix, "-e", src, root / "native-main-v1403.s6rec")
    obj = root / "native-main-v1403.dobj"
    run(das, "-F", "-C", "-O", obj, asm)
    for stem in ("crt0", "syscall", "syscall_helpers"):
        (root / (stem + "-v1403.dobj")).write_bytes(
            (Path(libc) / (stem + ".dobj")).read_bytes())
    run(dlink, "-b", "020", "-o", root / "native-gold-v1403.dxr",
        root / "crt0-v1403.dobj", obj,
        root / "syscall-v1403.dobj", root / "syscall_helpers-v1403.dobj")
    print("V1403_HOST_OBJECTS_PASS")


if __name__ == "__main__":
    main()
