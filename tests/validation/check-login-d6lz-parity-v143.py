#!/usr/bin/env python3
"""Check exact D6LZ36 LOGIN image and relocation-map compatibility.

Arguments are the uncompressed and compressed DXR paths from one build.
The legacy decoder uses MSB-first control words and overlapping backrefs.
This checks the host-generated stream, not PDP-6 runtime execution.
"""
import pathlib
import sys


def words(path):
    content = pathlib.Path(path).read_bytes()
    if len(content) % 8:
        raise ValueError("DXR is not a sequence of 64-bit containers")
    result = [int.from_bytes(content[i:i + 8], "little")
              for i in range(0, len(content), 8)]
    if any(w >= (1 << 36) for w in result):
        raise ValueError("DXR contains a non-36-bit word")
    return result


def check(original, compressed):
    mask = (1 << 18) - 1
    if len(compressed) < 4 or original[0] != compressed[0]:
        raise ValueError("DXR header mismatch")
    count = (compressed[1] >> 18) & mask
    reloc_count = (count + 35) // 36
    if count == 0 or len(compressed) < 3 + reloc_count:
        raise ValueError("invalid compressed DXR geometry")
    payload = compressed[3:len(compressed) - reloc_count]
    decoded = []
    source = 0
    while len(decoded) < count:
        if source >= len(payload):
            raise ValueError("missing D6LZ control")
        control = payload[source]
        source += 1
        for bit in range(35, -1, -1):
            if len(decoded) == count:
                break
            if source >= len(payload):
                raise ValueError("truncated D6LZ token")
            token = payload[source]
            source += 1
            if (control >> bit) & 1:
                distance = (token & 127) + 1
                length = (token >> 7) + 3
                if token >> 14 or distance > len(decoded) or len(decoded) + length > count:
                    raise ValueError("invalid D6LZ match")
                for _ in range(length):
                    decoded.append(decoded[-distance])
            else:
                decoded.append(token)
    if source != len(payload):
        raise ValueError("compressed payload has trailing words")
    if decoded != original[2:2 + count] and decoded != original[3:3 + count]:
        raise ValueError("D6LZ output differs from uncompressed DXR")
    if compressed[-reloc_count:] != original[-reloc_count:]:
        raise ValueError("DXR relocation-map mismatch")
    print("PASS: exact LOGIN D6LZ36 image and relocation-map parity; "
          f"image={count} compressed={len(payload)} reloc={reloc_count}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: check-login-d6lz-parity-v143.py RAW.dxr COMPRESSED.dxr")
    try:
        check(words(sys.argv[1]), words(sys.argv[2]))
    except ValueError as error:
        sys.exit(f"FAIL: {error}")
