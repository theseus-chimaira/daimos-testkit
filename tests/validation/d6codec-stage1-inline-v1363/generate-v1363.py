#!/usr/bin/env python3
"""Build test-only complete-buffer D6CODEC Stage-1 source variants.

No production Stage-1 file or build recipe is modified by this tool.
The current five Stage-1 loaders already stage the *entire* compressed
payload before invoking the D6LZ36 decoder. Therefore an installed
resumable decoder is unnecessary for the Stage-1 format conversion.
"""
import pathlib
import re
import sys


HANDOFF = {
    "dsk": """stage1_handoff:
        move    01,kinit_stack_base     ; input begins after decoded KINIT
        move    02,compressed_words
        movei   03,030000
        move    04,01
        subi    04,030000             ; exact output length
        pushj   017,d6codec_v053_decode
        jumpn   01,fail_decompress

""",
    "drm": """stage1_handoff:
        move    01,kinit_stack_base
        move    02,compressed_words
        movei   03,030000
        move    04,01
        subi    04,030000
        pushj   017,d6codec_v053_decode
        jumpn   01,fail_decompress

""",
    "dtc": """stage1_handoff:
        ; Preserve the direct-entry address and KINIT length across decode.
        move    02,04                ; compressed length survived tape read
        move    04,013
        movei   03,030000
        move    01,03
        add     01,04
        push    017,05
        push    017,013
        pushj   017,d6codec_v053_decode
        pop     017,013
        pop     017,05
        jumpn   01,bad_tape
        movei   017,030000
        add     017,013
        setz    01,
        setz    02,
        jrst    0(05)

""",
    "mtc": """stage1_handoff:
        move    02,04                ; compressed length survived tape read
        move    04,013
        movei   03,030000
        move    01,03
        add     01,04
        push    017,05
        push    017,013
        pushj   017,d6codec_v053_decode
        pop     017,013
        pop     017,05
        jumpn   01,bad_tape
        movei   017,030000
        add     017,013
        jrst    0(05)

""",
    "ptr": """stage1_handoff:
        movei   03,030000
        move    04,image_words
        move    01,03
        add     01,04
        move    02,compressed_words
        push    017,016              ; the entry address uses AC16
        pushj   017,d6codec_v053_decode
        pop     017,016
        jumpn   01,bad_tape
        movei   017,030000
        add     017,image_words
        jrst    0(016)

""",
}


def replace_range(data, begin, end, replacement):
    left = data.find(begin)
    assert left >= 0 and data.find(begin, left + len(begin)) < 0, begin
    right = data.find(end, left + len(begin))
    assert right > left, (begin, end)
    return data[:left] + replacement + data[right:]


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate-v1363.py DAIMOS_REPO OUTPUT_DIRECTORY")
    repo = pathlib.Path(sys.argv[1]).resolve()
    dest = pathlib.Path(sys.argv[2]).resolve()
    dest.mkdir(parents=True, exist_ok=True)
    decoder = repo / "system/kernel/core/d6codec_decode_v053.s"
    assert decoder.is_file()
    for kind, handoff in HANDOFF.items():
        source = repo / "system/stand/pdp6" / kind / "stage1.s"
        data = source.read_text()
        assert data.count('.include "../common/decompressor.inc"') == 1
        data = data.replace('.include "../common/decompressor.inc"',
                            '.include "%s"' % decoder)
        if kind in ("dsk", "drm"):
            data = replace_range(data, "stage1_handoff:\n",
                                 "stage1_enter_kinit:", handoff)
        elif kind == "dtc":
            data = replace_range(data, "stage1_handoff:\n",
                                 "stage1_raw_handoff:", handoff)
        else:
            data = replace_range(data, "stage1_handoff:\n",
                                 "bad_tape:", handoff)
        # DTC/MTC read_word clobbers AC3 only; AC4 retains the compressed
        # count through loading. Pass it in AC2 before reusing AC4 for the
        # output size. No persistent scratch word is necessary.
        # These include paths are relative to their original sources.
        # Generated artifacts are outside the production directory.
        base = source.parent
        data = re.sub(r'\.include\s+"(\.\./common/[^\"]+)"',
                      lambda m: '.include "%s"' % (base / m.group(1)).resolve(),
                      data)
        # The executable path must use only the complete-buffer decoder.
        assert not re.search(r'^\s*(?:blt|pushj)\s+.*d6lz_fixed_base',
                             data, re.MULTILINE)
        output = dest / ("stage1-%s-v1363.s" % kind)
        output.write_text(data)
        print("GENERATED", kind, output)


if __name__ == "__main__":
    main()
