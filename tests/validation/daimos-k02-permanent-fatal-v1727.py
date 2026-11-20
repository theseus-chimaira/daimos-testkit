#!/usr/bin/env python3
"""Physical K02 permanent provider refusal and independent fatal HUP."""

from pathlib import Path
import subprocess
import sys


def one(source, old, new):
    if source.count(old) != 1:
        raise SystemExit("v1727: unique source anchor mismatch: " + repr(old[:90]))
    return source.replace(old, new, 1)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: v1727.py VERSIONED_WORKDIR TEST_DIR")
    work = Path(sys.argv[1]).resolve()
    root = Path(sys.argv[2]).resolve()
    subprocess.run([sys.executable,
                    str(root / "daimos-k02-concurrent-owners-v1726.py"),
                    str(work), str(root)], check=True)

    script = (work / "daimos-k02-concurrent-owners-v1726.generated.sh"
              ).read_text().replace("v1726", "v1727").replace(
                  "PYV1726", "PYV1727")
    source = (root / "daimos-k02-concurrent-owners-v1726.c").read_text()
    start = source.index("        if (mode == 'B') {\n"
                         "                /* The first provider refusal")
    stop = source.index("        if (mode == 'A') {\n"
                        "                if (dsys_getpid()", start)
    source = source[:start] + """        if (mode == 'B') {
                volatile kword_t *bad;
                if (dsys_getpid() != 2 || dsys_readchar(5) != 'G')
                        fail('b');
                /* First EXIT will close stdout; emit the B witness now.
                 * The native fatal-sleep counter proves later APR entry.
                 */
                (void)dsys_writechar(1, 'B');
                if (dsys_exit(FILE_STATUS) != -1 ||
                    dsys_meminfo(&live) != 0 ||
                    live.file_slots_used != 1UL)
                        fail('d');
                /* Actual APR fault: the provider will permanently refuse
                 * FILE closure on the owner's private kernel stack.
                 */
                bad = (volatile kword_t *)0777777UL;
                (void)*bad;
                fail('x');
                return 1;
        }
""" + source[stop:]
    source = one(source,
        """                (void)dsys_exit(PIPE_STATUS);
                (void)dsys_halt();""",
        """                /* Self-HUP completes the second PIPE close via
                 * fatal EXIT, independent of the blocked D6FS child.
                 */
                (void)dsys_procctl(SYS_PROCCTL_EVENT_PID,
                    SYS_EVENT_ARG(3U, SYS_EVENT_HUP));
                (void)dsys_halt();""")
    source = one(source,
        "SYS_WAIT_STATUS_VALUE(status) != PIPE_STATUS)",
        "SYS_WAIT_STATUS_VALUE(status) != "
        "(SYS_WAIT_EVENT_FLAG | SYS_EVENT_HUP))")

    start = source.index("        status = 0UL;\n"
                         "        if (dsys_wait((unsigned int)bpid,")
    stop = source.index("        (void)dsys_writechar(1, 'P');", start)
    source = source[:start] + """        /* Permanent refusal must leave B non-waitable and FD6 owned.
         * Foreign HUP cannot free B's sleeping fatal APR continuation.
         */
        status = 0UL;
        if (dsys_wait((unsigned int)bpid, &status,
            SYS_WAIT_NOHANG) != 0)
                fail('B');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)bpid, SYS_EVENT_HUP)) != -1)
                fail('H');
        if (dsys_sleep(0200U) != 0)
                fail('T');
        status = 0UL;
        if (dsys_wait((unsigned int)bpid, &status,
            SYS_WAIT_NOHANG) != 0)
                fail('N');
        /* process_slots_used is global, but file_slots_used scans only
         * the caller's FD table. B's FD6 is checked physically by the
         * PIPE hook and remains owned outside INIT's table.
         */
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used + 1UL ||
            after.file_slots_used != before.file_slots_used)
                fail('C');
""" + source[stop:]
    source = one(source, '#include "../test_sixbit.h"',
                 '#include "%s"' % (root.parent / "test_sixbit.h"))
    generated_c = work / "daimos-k02-permanent-fatal-v1727.generated.c"
    generated_c.write_text(source)
    script = one(script,
        str(root / "daimos-k02-concurrent-owners-v1727.c"),
        str(generated_c))

    # Only the copied D6FS provider is modified: slot2 FD6 never closes.
    script = one(script,
        """        caile   2,2
        jrst    kret_zero               ; production success, third try
        aos     daimos_provrefuse_v1727""",
        """        ; Test-only permanent D6FS refusal: retain FD6 forever.
        aos     daimos_provrefuse_v1727""")
    script = one(script,
        """        move    5,daimos_provcalls_v1727
        caie    5,1
        aos     daimos_test_errors_v1727
        move    5,daimos_provrefuse_v1727
        caie    5,1
        aos     daimos_test_errors_v1727""",
        """        move    5,daimos_provcalls_v1727
        caige   5,2
        aos     daimos_test_errors_v1727
        move    5,daimos_provrefuse_v1727
        camn    5,daimos_provcalls_v1727
        jrst    daimos_test_provider_ok_v1727
        aos     daimos_test_errors_v1727
daimos_test_provider_ok_v1727:""")
    script = one(script,
        """        skipn   042(5)                 ; uarea FILE base 026 + 2*FD6
        jrst    daimos_test_overlap_bad_v1727
        aos     daimos_test_overlap_v1727""",
        """        skipn   042(5)                 ; B owns its real FD6
        jrst    daimos_test_overlap_bad_v1727
        move    6,024(5)               ; B original u-area control
        trnn    6,04                   ; PROC_FATAL_CLOSE_BIT
        jrst    daimos_test_overlap_bad_v1727
        aos     daimos_test_overlap_v1727""")

    # Observe exponential fatal-owner sleep on its actual private stack.
    # Neither proc_sleep_ticks nor the scheduler is changed.
    hook = r"""python3 - "$work/source/system/kernel/proc/proc_pdp6.s" <<'PYV1727'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '''proc_fatal_close_wait_v995:
        move    1,(17)                ; owner-stack retry interval'''
new = '''proc_fatal_close_wait_v995:
        move    4,proc_current_slot
        caie    4,2
        jrst    daimos_fatal_probe_done_v1727
        move    4,daimos_fatal_delay_v1727
        jumpe   4,daimos_fatal_first_v1727
        caige   4,01000
        lsh     4,1
        jrst    daimos_fatal_compare_v1727
daimos_fatal_first_v1727:
        movei   4,1
daimos_fatal_compare_v1727:
        move    5,(17)
        camn    4,5
        jrst    daimos_fatal_valid_v1727
        aos     daimos_fatal_wrong_v1727
daimos_fatal_valid_v1727:
        movem   5,daimos_fatal_delay_v1727
        aos     daimos_fatal_sleep_v1727
daimos_fatal_probe_done_v1727:
        move    1,(17)                ; owner-stack retry interval'''
assert s.count(old) == 1, 'v1727: fatal retry anchor drift'
s = s.replace(old, new, 1)
for name in ('sleep', 'wrong', 'delay'):
    sym = 'daimos_fatal_' + name + '_v1727'
    assert sym + ':' not in s
    s += '\n        .bss\n        .globl ' + sym + '\n' + sym + ': .block 1\n'
p.write_text(s)
PYV1727
"""
    script = one(script,
        'cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"\n',
        'cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"\n' + hook)

    # Examine the new resident KCORE diagnostics in the physical guest.
    # Versioned names remain below the linker's symbol length limit.
    script = one(script,
        "for pair in provcalls:daimos_provcalls_v1727",
        """for name in sleep wrong delay; do
    sym="daimos_fatal_"$name"_v1727"
    addr=$(awk -v s="$sym" '$1 == s {print $2; exit}' "$build/kcore.map")
    test -n "$addr" || { echo "v1727: missing $sym" >&2; exit 1; }
    printf 'fatal_%s %s\\n' "$name" "$addr" >> "$work/addresses"
done
for pair in provcalls:daimos_provcalls_v1727""")
    script = one(script,
        """expected = dict(calls=2, pins=1, unpins=1, busy=1, freed=1, errors=0, overlap=2, provcalls=3, provrefuse=2, leaseok=3, leasebad=0)""",
        """expected = dict(calls=2, pins=1, unpins=1, busy=1,
                freed=1, errors=0, overlap=2, leasebad=0,
                fatal_wrong=0)""")
    script = one(script,
        "if seen['owner'] != 3 or seen['target'] == 0:",
        """if not (3 <= seen['fatal_sleep'] <= 12 and
        2 <= seen['fatal_delay'] <= 0o1000):
    raise SystemExit('v1727: no bounded exponential private-stack '
                     'sleep: ' + str(seen))
if not (seen['provcalls'] == seen['provrefuse'] ==
        seen['leaseok'] and
        seen['provcalls'] >= seen['fatal_sleep'] + 1 and
        seen['provcalls'] <= 24):
    raise SystemExit('v1727: provider not permanently refusing or '
                     'retry is unbounded: ' + str(seen))
if re.search(r'(?m)^B\\r?$', out) is None:
    raise SystemExit('v1727: APR-fault witness from B missing')
if seen['owner'] != 3 or seen['target'] == 0:""")
    script = one(script,
        "v1727: overlapping RUN child PIPE and D6FS owner failures, ",
        "v1727: permanent fatal D6FS owner while PIPE self-HUP exits, ")
    script = one(script,
        "two live owners and independent WAIT completion PASS:",
        "bounded private-stack sleep and independent progress PASS:")
    # Console writes are unbuffered characters, not line-oriented. B is
    # emitted before first EXIT closes its stdout; INIT writes P at the
    # end. No newline is emitted between them: require one exact BP line.
    script = one(script, "r'(?m)^B\\r?$'", "r'(?m)^BP\\r?$'")
    script = one(script, "r'(?m)^P\\r?$'", "r'(?m)^BP\\r?$'")
    (work / "daimos-k02-permanent-fatal-v1727.generated.sh").write_text(
        script)


if __name__ == "__main__":
    main()
