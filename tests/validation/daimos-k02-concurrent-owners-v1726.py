#!/usr/bin/env python3
"""Build a real two-child K02 owner-overlap guest from v1725 machinery."""

from pathlib import Path
import subprocess
import sys


def one(source, old, new):
    count = source.count(old)
    if count != 1:
        raise SystemExit("v1726: changed source anchor %d: %r" %
                         (count, old[:90]))
    return source.replace(old, new, 1)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: v1726.py VERSIONED_WORKDIR TEST_DIR")
    work = Path(sys.argv[1]).resolve()
    root = Path(sys.argv[2]).resolve()
    subprocess.run([
        sys.executable,
        str(root / "daimos-k02-run-provider-lease-v1725.py"),
        str(work), str(root)], check=True)

    src = work / "daimos-k02-run-provider-lease-v1725.generated.sh"
    script = src.read_text().replace("v1725", "v1726").replace(
        "PYV1725", "PYV1726")
    script = one(script,
        str(work / "daimos-k02-run-provider-lease-v1726.generated.c"),
        str(root / "daimos-k02-concurrent-owners-v1726.c"))

    # B=slot2 owns a refused D6FS FILE while A=slot3 owns the PIPE.
    # The physical PIPE hook verifies B's live FD6 during *both* final
    # MM release attempts. No production scheduler or cleanup is patched.
    injection = r"""
old = '''        caile   4,1
        jrst    daimos_test_child_v1726'''
new = '''        caie    4,3                    ; must be RUN child A
        jrst    daimos_test_wrong_child_v1726
        jrst    daimos_test_child_v1726
daimos_test_wrong_child_v1726:
        aos     daimos_test_errors_v1726'''
assert source.count(old) == 1, 'v1726: PIPE child anchor drift'
source = source.replace(old, new, 1)

old = '''daimos_test_pin_stage_v1726:
        move    4,daimos_test_calls_v1726'''
new = '''daimos_test_pin_stage_v1726:
        ; Child B must have already refused provider SYNC exactly once.
        ; Its original FILE FD6 must still be owned in its stable u-area.
        move    5,daimos_provcalls_v1726
        caie    5,1
        aos     daimos_test_errors_v1726
        move    5,daimos_provrefuse_v1726
        caie    5,1
        aos     daimos_test_errors_v1726
        move    5,proc_table
        move    5,6(5)                 ; slot2 meta, 3 words per proc
        hlrz    5,5                    ; stable u-area physical address
        jumpe   5,daimos_test_overlap_bad_v1726
        skipn   042(5)                 ; uarea FILE base 026 + 2*FD6
        jrst    daimos_test_overlap_bad_v1726
        aos     daimos_test_overlap_v1726
        jrst    daimos_test_overlap_done_v1726
daimos_test_overlap_bad_v1726:
        aos     daimos_test_errors_v1726
daimos_test_overlap_done_v1726:
        move    4,daimos_test_calls_v1726'''
assert source.count(old) == 1, 'v1726: overlap anchor drift'
source = source.replace(old, new, 1)

source += '''
        .bss
        .globl daimos_test_overlap_v1726
daimos_test_overlap_v1726: .block 1
'''
"""
    script = one(script, "path.write_text(source)\nPY\n",
                 injection + "\npath.write_text(source)\nPY\n")
    script = one(script,
        "for name in target owner calls pins unpins busy freed errors; do",
        "for name in target owner calls pins unpins busy freed errors overlap; do")
    script = one(script,
        "expected = dict(calls=2, pins=1, unpins=1, busy=1, freed=1, "
        "errors=0, provcalls=3, provrefuse=2, leaseok=3, leasebad=0)",
        "expected = dict(calls=2, pins=1, unpins=1, busy=1, freed=1, "
        "errors=0, overlap=2, provcalls=3, provrefuse=2, "
        "leaseok=3, leasebad=0)")
    script = one(script,
        "if seen['owner'] <= 1 or seen['target'] == 0:",
        "if seen['owner'] != 3 or seen['target'] == 0:")
    script = one(script,
        "v1726: RUN child PIPE MM_BUSY and two D6FS provider refusals, ",
        "v1726: overlapping RUN child PIPE and D6FS owner failures, ")
    script = one(script,
        "provider lease identity, 3 EXIT passes, parent WAIT PASS:",
        "two live owners and independent WAIT completion PASS:")

    (work / "daimos-k02-concurrent-owners-v1726.generated.sh").write_text(
        script)


if __name__ == "__main__":
    main()
