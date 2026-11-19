#!/usr/bin/env python3
"""Prepare canonical native DAS ASCII7 and S6REC fixtures (test-only)."""

from pathlib import Path
import struct
import subprocess
import sys


SOURCE = (
    ".TEXT\n"
    ".GLOBL V1402_ENTRY\n"
    "V1402_ENTRY:\n"
    " MOVEI 1,012345\n"
    " POPJ 17,\n"
)

QUOTED_SOURCE = (
    '.TEXT\n.GLOBL V1402_QUOTED\nV1402_QUOTED:\n'
    '.ASCII "AbCdEf"\n'
)

RUN_SOURCE = (
    '.TEXT\n.GLOBL V1402_RUN\n.ENTRY V1402_RUN\nV1402_RUN:\n'
    ' MOVEI 1,07\n UUO 040,0(1)\n HALT .\n'
)


def ascii7_words(data):
    if any(ch == 0 or ch > 127 for ch in data):
        raise ValueError("input is not printable ASCII7")
    result = []
    for start in range(0, len(data), 5):
        word = 0
        for i, ch in enumerate(data[start:start + 5]):
            word |= ch << (29 - 7 * i)
        result.append(word)
    return result


def write_words(filename, words):
    Path(filename).write_bytes(struct.pack("<" + "Q" * len(words), *words))


def main():
    if len(sys.argv) != 6:
        raise SystemExit(
            "usage: make_fixtures_v1402.py DAS S6TEXT HOST_KCC_ASM "
            "OUTPUT_DIR HOST_KCC_A7")
    das, s6text, host_asm, output, host_a7 = sys.argv[1:]
    out = Path(output)
    out.mkdir(parents=True, exist_ok=True)
    source = out / "source-v1402.s"
    source.write_text(SOURCE, encoding="ascii")
    subprocess.run([s6text, "--encode", str(source),
                    str(out / "source-v1402.s6rec")], check=True)
    subprocess.run([das, "-O", str(out / "gold-v1402.dxr"),
                    str(source)], check=True)
    subprocess.run([das, "-O", str(out / "kcc-gold-v1402.dxr"),
                    host_asm], check=True)

    words = ascii7_words(SOURCE.encode("ascii"))
    write_words(out / "source-v1402.a7", words)
    # Reject invalid low spare bit, embedded NUL, and trailing words
    # after a partial final word rather than silently truncating input.
    bad_spare = words.copy()
    bad_spare[0] |= 1
    write_words(out / "bad-spare-v1402.a7", bad_spare)
    bad_nul = words.copy()
    bad_nul[0] &= ~(127 << 22)
    write_words(out / "bad-nul-v1402.a7", bad_nul)
    if len(SOURCE) % 5 == 0:
        raise ValueError("fixture must exercise short final word")
    write_words(out / "bad-trailing-v1402.a7", words + [0])

    # Case-sensitive quoted ASCII is not subject to assembler-keyword
    # folding.  The executable also proves native DAS output can RUN.
    for stem, value in (("quoted", QUOTED_SOURCE), ("run", RUN_SOURCE)):
        raw = value.encode("ascii")
        plain = out / (stem + "-v1402.s")
        plain.write_bytes(raw)
        write_words(out / (stem + "-v1402.a7"), ascii7_words(raw))
        subprocess.run([das, "-O", str(out / (stem + "-gold-v1402.dxr")),
                        str(plain)], check=True)

    # Recheck that host KCC's actual generated source has the expected
    # packed layout before passing it to native DAS in the guest.
    expected = ascii7_words(Path(host_asm).read_bytes())
    if Path(host_a7).read_bytes() != struct.pack(
            "<" + "Q" * len(expected), *expected):
        raise ValueError("host KCC ASCII7 fixture representation mismatch")
    print("V1402_FIXTURES_PASS ascii7_words=%d" % len(words))


if __name__ == "__main__":
    main()
