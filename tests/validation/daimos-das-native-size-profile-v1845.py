#!/usr/bin/env python3
"""Profile native DAS phase image budgets and assembler symbol regions.

This is a diagnostic, not an acceptance test: oversize images are
reported without relaxing the authoritative phase-size checker.
"""
import argparse
import pathlib
import re

LIMITS = {"das1": 0o34000, "das2": 0o31000}
WORD_MASK = 0o777777777777
MAGIC = 0o447062
LABEL = re.compile(r"^([A-Za-z_][A-Za-z_0-9$]*):$")


def image_size(path):
    data = path.read_bytes()
    if len(data) < 16 or len(data) % 8:
        raise ValueError("invalid DXR length: " + str(path))
    words = [int.from_bytes(data[i:i + 8], "little") & WORD_MASK
             for i in range(0, len(data), 8)]
    if ((words[0] >> 18) & 0o777777) != MAGIC:
        raise ValueError("invalid DXR magic: " + str(path))
    image = (words[1] >> 18) & 0o777777
    bss = words[1] & 0o777777
    reloc = (image + 35) // 36
    if len(words) not in (2 + image + reloc, 3 + image + reloc):
        raise ValueError("invalid DXR payload length: " + str(path))
    return image, bss


def profile(phase, directory, top):
    image, bss = image_size(directory / (phase + ".dxr"))
    asm = (directory / (phase + "-v1.s")).read_text(encoding="ascii")
    labels = []
    for line_no, line in enumerate(asm.splitlines(), 1):
        match = LABEL.match(line)
        if match and not match.group(1).startswith("L"):
            labels.append((line_no, match.group(1)))
    # Assembly line spans identify candidates, not exact word counts.
    # Linker layout and embedded data can change the real word sizes.
    spans = sorted(((end - start, name)
                    for (start, name), (end, _) in zip(labels, labels[1:])),
                   reverse=True)
    limit = LIMITS[phase]
    print("%s image=%06o bss=%06o ceiling=%06o excess=%06o" %
          (phase, image, bss, limit, max(0, image - limit)))
    print("%s largest assembly regions (source lines; not image words):" % phase)
    for lines, name in spans[:top]:
        print("  %-38s %5d lines" % (name, lines))
    return image > limit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=pathlib.Path, required=True)
    parser.add_argument("--top", type=int, default=12)
    args = parser.parse_args()
    if args.top < 1:
        parser.error("--top must be positive")
    oversized = False
    for phase in ("das1", "das2"):
        oversized |= profile(phase, args.build_dir, args.top)
    if oversized:
        print("DIAGNOSTIC: native phase image ceilings exceeded; not accepted")
    else:
        print("DIAGNOSTIC: native phase image sizes within ceilings")


if __name__ == "__main__":
    main()
