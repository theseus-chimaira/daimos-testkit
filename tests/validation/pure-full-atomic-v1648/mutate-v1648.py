#!/usr/bin/env python3
"""Generate two invalid, disposable v1391 FULL transactions.

No production source is modified.  The native source-linked v1648
regression must reject BOTH a missing RAW overlay and a leaked target
after a refused authoritative PACKED source release.
"""

from pathlib import Path
import sys


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: mutate-v1648.py production.c kind output.c")
    source = Path(sys.argv[1]).read_text(encoding="ascii")
    kind = sys.argv[2]
    if kind == "overlay":
        before = ("        fs_copy_words(PRAM_PTR(source), PRAM_PTR(target + skip),\n"
                  "            (unsigned int)raw);")
        after = "        /* TEST MUTANT: omit authoritative writable suffix. */"
    elif kind == "target-free":
        before = ("        if (mm_free(target, MM_TYPE_PROCESS, slot) != MM_OK)\n"
                  "                return MM_ERR_BUSY;")
        # Leave the original v1395 fault cases intact.  Only after a
        # successful source unpin and a later invalid source-free
        # refusal is the provisional target incorrectly leaked.
        # This must fail in the NEW v1648 source-free test, not in the
        # already accepted baseline fixture.
        after = (
            "        /* TEST MUTANT: leak target after source free error. */\n"
            "        if (source_pinned || rc != MM_ERR_INVAL) {\n"
            "                if (mm_free(target, MM_TYPE_PROCESS, slot) != MM_OK)\n"
            "                        return MM_ERR_BUSY;\n"
            "        }")
    else:
        raise SystemExit("unknown v1648 mutant: " + kind)
    assert source.count(before) == 1, "production transaction changed"
    result = source.replace(before, after, 1)
    assert result != source
    Path(sys.argv[3]).write_text(result, encoding="ascii")


if __name__ == "__main__":
    main()
