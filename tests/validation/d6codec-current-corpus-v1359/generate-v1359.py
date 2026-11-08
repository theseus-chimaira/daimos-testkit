#!/usr/bin/env python3
"""Host grouped reference: full current DXR inventory, native golden samples."""
import pathlib
import sys

testkit = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(testkit / "tests/host/d6codec-v039"))
import importlib.util

spec = importlib.util.spec_from_file_location(
    "reference_v039", testkit / "tests/host/d6codec-v039/compare-v039.py")
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


def encode(words):
    """Independently form grouped tokens with the native >=2 match policy."""
    tokens = []
    p = 0
    while p < len(words):
        limit = min(127, len(words) - p)
        if words[p] == 0:
            run = 1
            while run < limit and words[p + run] == 0:
                run += 1
            tokens.append((1, 1, run, 0))
            p += run
            continue
        best = 0
        distance = 0
        for d in range(min(128, p), 0, -1):
            count = 0
            while count < limit and words[p + count] == words[p + count - d]:
                count += 1
            if count > best:
                best, distance = count, d
            if count == 127:
                break
        if best >= 2:
            tokens.append((1, 0, best, distance))
            p += best
        else:
            tokens.append((0, words[p]))
            p += 1
    output = []
    for start in range(0, len(tokens), 30):
        group = tokens[start:start + 30]
        flags, descriptors, literals = 0, [], []
        for i, token in enumerate(group):
            if token[0]:
                flags |= 1 << (29 - i)
                descriptors.append((token[1] << 16) | (token[2] << 9) | token[3])
            else:
                literals.append(token[1])
        output.append((len(group) << 30) | flags)
        for index in range(0, len(descriptors), 2):
            right = descriptors[index + 1] if index + 1 < len(descriptors) else 0
            output.append((descriptors[index] << 18) | right)
        output.extend(literals)
    return output


def write_fixture(path, words, golden):
    def declarations(values):
        return "".join("        .word 0%o\n" % value for value in values)
    n, size = len(words), len(golden)
    src = """/* v1359: host golden full native prefix parity. */
.text
.globl main
.globl d6codec_kcore_encode_v055
.globl d6codec_kcore_decode_v055
main:
 movei 1,source
 movei 2,0%o
 movei 3,encoded
 movei 4,0%o
 pushj 17,d6codec_kcore_encode_v055
 caie 1,0%o
 jrst fail
 movei 5,0
check_encoded:
 move 6,encoded(5)
 came 6,golden(5)
 jrst fail
 aoj 5,
 caige 5,0%o
 jrst check_encoded
 movei 1,encoded
 movei 2,0%o
 movei 3,decoded
 movei 4,0%o
 pushj 17,d6codec_kcore_decode_v055
 jumpn 1,fail
 movei 5,0
check_decoded:
 move 6,source(5)
 came 6,decoded(5)
 jrst fail
 aoj 5,
 caige 5,0%o
 jrst check_decoded
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
.data
source:
""" % (n, size, size, size, size, n, n)
    src += declarations(words) + "golden:\n" + declarations(golden)
    src += ".bss\nencoded: .block 0%o\ndecoded: .block 0%o\n" % (size + 1, n)
    src += ".globl __test_exit\n__test_exit: .block 1\n"
    path.write_text(src)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate-v1359.py BUILD_DXR_DIR OUTPUT_DIR")
    base = pathlib.Path(sys.argv[1])
    outdir = pathlib.Path(sys.argv[2])
    outdir.mkdir(parents=True, exist_ok=True)
    files = sorted(base.glob("*.dxr"))
    if not files:
        raise RuntimeError("no current DXR artifacts")
    required = ("kcore", "d6fs-mres", "monitorfs-mres", "swap-mres-v481", "tape-mres")
    names = {path.stem for path in files}
    if not set(required) <= names:
        raise RuntimeError("required current DXR categories absent")
    rows = []
    for path in files:
        words = list(reference.load(path))
        encoded = encode(words)
        if reference.decode(encoded, len(words)) != words:
            raise RuntimeError("host roundtrip failure: " + path.name)
        rows.append((path.name, len(words), len(encoded)))
        if path.stem in required:
            # Exactly the same host token policy is applied to the first
            # 128 source words; the PDP-6 fixture validates each prefix.
            prefix = words[:128]
            if len(prefix) < 2:
                raise RuntimeError("short required native prefix")
            write_fixture(outdir / ("native_%s_v1359.s" % path.stem),
                          prefix, encode(prefix))
    (outdir / "host-results-v1359.tsv").write_text(
        "artifact\tinput_words\tencoded_words\n" +
        "".join("%s\t%d\t%d\n" % row for row in rows))
    print("HOST_CURRENT_DXR_PASS files=%d input_words=%d encoded_words=%d" %
          (len(rows), sum(row[1] for row in rows), sum(row[2] for row in rows)))


if __name__ == "__main__":
    main()
