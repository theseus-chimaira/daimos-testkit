#!/usr/bin/env python3
"""v1645 C89 guest: stage one real PIPE wake before releasing all six.

Build directly from the accepted v1644 source-derived RW DTFS guest.
All original child DATA/PIPE/exit status and parent exact WAITs remain.
The first genuine read may consume one identified wake word; all five
remaining children continue to sleep on the still-open pipe writer.
"""

from pathlib import Path
import runpy
import sys


def generate(original):
    here = Path(__file__).resolve().parent
    prior = runpy.run_path(str(here.parent /
                                "pure-backing-guards-v1644/prepare-v1644.py"))
    src = prior["generate"](original)
    marker = "#define P14_STATUS           057U"
    assert src.count(marker) == 1
    src = src.replace(marker, marker + "\n#define P14_WAKE_V1645      052345670123UL", 1)

    # The same child still checks its private writable sentinel and exits
    # exactly 057; its single PIPE word may be the explicitly written
    # first-wakeup token rather than the writer's final EOF.
    original_read = """        if (dsys_read_words(0, &word, 1U) != 0)
            (void)dsys_exit(071);"""
    new_read = """        {
            int nread = dsys_read_words(0, &word, 1U);
            if (nread != 0 &&
                (nread != 1 || word != P14_WAKE_V1645))
                (void)dsys_exit(071);
        }"""
    assert src.count(original_read) == 1
    src = src.replace(original_read, new_read, 1)

    # The prior v1644 checks run first, proving all six PACKED RAW sources.
    # Then send precisely ONE word to the shared pipe. While the writer
    # remains open, no other child can read EOF. An explicit real sleep
    # yields PI6 CPU time to the one awakened child; we then retest the
    # executable guard on the still-live remaining owners. Unlike a
    # tight loop this is an actual scheduler interleaving, not a stub.
    original_close = """    if (dsys_close(wr) != 0)
        p14_fail('e');"""
    new_close = """    {
        kword_t wake = P14_WAKE_V1645;
        if (dsys_write_words(wr, &wake, 1U) != 1)
            p14_fail('h');
        (void)p14_char('H');
    }
    /* Allow a genuine PI6 scheduling window for one restoring child.
     * The other five still block on the same open PIPE writer.
     * Repeated backing denial MUST survive a concurrent restore.
     */
    p14_check_busy_v1644();
    if (dsys_sleep(0200U) != 0)
        p14_fail('i');
    (void)p14_char('T');
    p14_check_busy_v1644();
    if (dsys_close(wr) != 0)
        p14_fail('e');"""
    assert src.count(original_close) == 1
    src = src.replace(original_close, new_close, 1)
    for fragment in ("#define P14_CHILDREN         6U",
                     "denied = p14_spawn(rd, 1U);",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "p14_check_busy_v1644();",
                     "(void)p14_char('H');", "(void)p14_char('T');",
                     "(void)p14_char('U');", "(void)p14_char('Z');"):
        assert fragment in src
    return src


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1645.py original.c output.c")
    result = generate(Path(sys.argv[1]).read_text(encoding="ascii"))
    Path(sys.argv[2]).write_text(result, encoding="ascii")
    print("v1645: one real PIPE wake + PI6 window + five PACKED guardians")


if __name__ == "__main__":
    main()
