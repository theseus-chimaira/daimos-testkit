#!/usr/bin/env python3
"""Add pre-write geometry validation to test-only v1363 Stage-1 variants."""
import pathlib
import subprocess
import sys

if len(sys.argv) != 6:
    raise SystemExit(
        "usage: generate-v1364.py DAIMOS_REPO TESTKIT OUT CORE_WORDS_OCTAL STACK_WORDS_OCTAL")
repo = pathlib.Path(sys.argv[1]).resolve()
testkit = pathlib.Path(sys.argv[2]).resolve()
out = pathlib.Path(sys.argv[3]).resolve()
core_text = sys.argv[4]
core = int(core_text, 8)
reserve_text = sys.argv[5]
reserve = int(reserve_text, 8)
if not 0o30000 + reserve + 1 <= core <= 0o1000000:
    raise ValueError("unsupported core/stack physical address geometry")
geometry = repo / "system/stand/pdp6/common/stage1-geometry-v1364.inc"
assert geometry.is_file()
out.mkdir(parents=True, exist_ok=True)
subprocess.run([sys.executable,
                str(testkit / "tests/validation/d6codec-stage1-inline-v1363/generate-v1363.py"),
                str(repo), str(out)], check=True)


def validator(out_size, compressed, save=None):
    result = ""
    if save:
        result += "        move 010,%s\n" % save
    result += ("        move 01,%s\n"
               "        move 02,%s\n"
               "        move 03,[0%s]\n"
               "        move 04,[0%s]\n"
               "        pushj 017,d6stage_geometry_v1364\n") % (
                   out_size, compressed, core_text, reserve_text)
    if save:
        result += "        move 04,010\n"
    return result


for kind in ("dsk", "drm", "dtc", "mtc", "ptr"):
    path = out / ("stage1-%s-v1363.s" % kind)
    data = path.read_text()
    assert data.count("stage1_handoff:\n") == 1
    # The geometry entry belongs to Stage-1 normal text; no fixed BLT copy.
    data = data.replace("stage1_handoff:\n",
                        '.include "%s"\nstage1_handoff:\n' % geometry, 1)
    if kind in ("dsk", "drm"):
        marker = "        movem 011,compressed_words\n"
        insert = validator("03", "011") + "        jumpn 00,fail_khead\n"
        assert data.count(marker) == 1
        data = data.replace(marker, marker + insert, 1)
        first_write = "        jrst stage1_stream_begin\n"
    elif kind == "dtc":
        marker = "        hrrz 06,03\n"
        insert = validator("013", "04", "04") + "        jumpn 00,bad_tape\n"
        assert data.count(marker) == 1
        data = data.replace(marker, marker + insert, 1)
        first_write = "compressed_stream:\n"
    elif kind == "mtc":
        marker = "        jumpe 04,bad_tape\n"
        insert = validator("013", "04", "04") + "        jumpn 00,bad_tape\n"
        assert data.count(marker) == 1
        data = data.replace(marker, marker + insert, 1)
        first_write = "load_loop:\n"
    else:
        marker = "        movem 07,compressed_words\n"
        # AC2 owns the first-tape total. Keep it in AC10 across the
        # validation call; verify segment length BEFORE first media write.
        insert = ("        move 010,02\n" +
                  validator("image_words", "compressed_words") +
                  "        jumpn 00,bad_tape\n"
                  "        move 02,010\n")
        assert data.count(marker) == 1
        data = data.replace(marker, marker + insert, 1)
        mark2 = "        subi 02,03\n"
        assert data.count(mark2) == 1
        data = data.replace(mark2, mark2 +
                            "        camle 02,compressed_words\n"
                            "        jrst bad_tape\n", 1)
        first_write = "        pushj 017,read_words\n"
    assert data.index("pushj 017,d6stage_geometry_v1364") < data.index(first_write)
    name = out / ("stage1-%s-v1364.s" % kind)
    name.write_text(data)
    print("GENERATED",kind,name)
