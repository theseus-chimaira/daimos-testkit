#!/usr/bin/env python3
"""Compare D6 v060 grouped paired descriptors to streaming inline tokens.

The inline candidate writes 1 control word per 36 tokens, one full word per
match descriptor, and one word per literal.  Its objective is decoder text/RAM,
not better compression. This is a host model, not an activated format.
"""
import importlib.machinery
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
v040 = importlib.machinery.SourceFileLoader('v040', str(root / 'tests/host/d6codec-v040/compare-v040.py')).load_module()
v046 = importlib.machinery.SourceFileLoader('v046', str(root / 'tests/host/d6codec-v046/compare-v046.py')).load_module()
v039 = importlib.machinery.SourceFileLoader('v039', str(root / 'tests/host/d6codec-v039/compare-v039.py')).load_module()


def unpack_groups(encoded):
    """Preserve native-policy tokens; only rearrange their wire layout."""
    pos = 0
    tokens = []
    while pos < len(encoded):
        control = encoded[pos]
        pos += 1
        count = control >> 30
        assert 1 <= count <= 30
        flags = control & ((1 << 30) - 1)
        assert flags & ((1 << (30 - count)) - 1) == 0
        matches = sum((flags >> (29 - k)) & 1 for k in range(count))
        words = encoded[pos:pos + (matches + 1) // 2]
        assert len(words) == (matches + 1) // 2
        pos += len(words)
        literals = encoded[pos:pos + count - matches]
        assert len(literals) == count - matches
        pos += len(literals)
        desc_index = lit_index = 0
        for k in range(count):
            if flags & (1 << (29 - k)):
                desc = (words[desc_index // 2] >> (18 if desc_index % 2 == 0 else 0)) & 0o777777
                tokens.append((1, desc))
                desc_index += 1
            else:
                tokens.append((0, literals[lit_index]))
                lit_index += 1
        assert desc_index == matches
    return tokens


def inline_pack(tokens):
    out = []
    for base in range(0, len(tokens), 36):
        group = tokens[base:base + 36]
        flags = 0
        for i, (match, _) in enumerate(group):
            if match:
                flags |= 1 << (35 - i)
        out.append(flags)
        out.extend(word for _, word in group)
    return out


def inline_decode(encoded, output_words):
    pos = 0
    out = []
    while len(out) < output_words:
        assert pos < len(encoded)
        flags = encoded[pos]
        pos += 1
        for i in range(36):
            if len(out) == output_words:
                # The last group may contain fewer than 36 tokens.
                assert flags & ((1 << (36 - i)) - 1) == 0
                break
            assert pos < len(encoded)
            token = encoded[pos]
            pos += 1
            if not flags & (1 << (35 - i)):
                out.append(token)
                continue
            assert token <= 0o777777
            kind = token >> 16
            length = (token >> 9) & 127
            distance = token & 511
            assert 1 <= length <= output_words - len(out)
            if kind == 1:
                assert distance == 0
                out.extend([0] * length)
            elif kind == 0:
                assert 1 <= distance <= len(out)
                for _ in range(length):
                    out.append(out[-distance])
            elif kind == 2:
                assert 1 <= distance <= len(out) * 2
                for j in range(length * 2):
                    half = 2 * len(out) - (1 if j % 2 else 0)
                    source_half = half - distance
                    val = (out[source_half // 2] >> (0 if source_half & 1 else 18)) & 0o777777
                    if j % 2 == 0:
                        out.append(val << 18)
                    else:
                        out[-1] |= val
            else:
                raise ValueError('invalid kind')
    assert pos == len(encoded)
    return out


def main():
    total = [0, 0, 0]
    for line in v039.MANIFEST.read_text().splitlines()[1:]:
        source = v039.load(pathlib.Path(line.split('\t')[0]))
        paired = v046.native_policy(source)
        tokens = unpack_groups(paired)
        inline = inline_pack(tokens)
        assert v039.decode(paired, len(source)) == list(source)
        assert inline_decode(inline, len(source)) == list(source)
        total = [a + b for a, b in zip(total, (len(source), len(paired), len(inline)))]
    print('81 DXR: raw=%d paired=%d inline=%d inline_delta=%+d' %
          (*total, total[2] - total[1]))
    print('inline relative growth over paired: %.2f%%' %
          ((total[2] / total[1] - 1.0) * 100.0))


if __name__ == '__main__':
    main()
