#!/usr/bin/env python3
"""Disposable PDP-6 permanent checked BACKSTORE refusal for the F07 guest.

Reuse the established v1504 physical owner/TERM observers. Only a copied
kernel is modified. Unlike v1494's *repairable* bitmap failure, keep
the original bitmap intact and refuse every checked release of the
same selected physical DISK run. This cannot donate its missing bit
to an unrelated allocator while the source guest remains running.
"""

from pathlib import Path
import runpy
import sys


HERE = Path(__file__).resolve().parent


def once(text, old, new):
    if text.count(old) != 1:
        raise AssertionError("v1508 source anchor drift: " + repr(old))
    return text.replace(old, new, 1)


def inject(kernel):
    swap_path = kernel / "proc/proc_swap_pdp6.s"
    back_path = kernel / "storage/backstore.s"
    swap = swap_path.read_text()

    # v1494/v1495/v1499/v1504 older, accepted physical instruments
    # expected the pre-v1507 contiguous failure service. Adapt only
    # this disposable copy while leaving the real v1507 retry code in
    # place after instrumentation has been inserted.
    start = ("proc_swap_service_failed:\n"
             "        move    1,(17)\n"
             "        movem   1,proc_sched_cursor\n")
    event = "        movei   2,SYS_EVENT_TERM\n"
    assert swap.count(start) == 1
    suffix = swap.split(start, 1)[1]
    stamp = suffix.split(event, 1)[0]
    assert "proc_swap_service_failed_event_v1507:" in stamp
    swap = once(swap, start + stamp + event, start + event)
    swap_path.write_text(swap)

    runpy.run_path(
        str(HERE / "daimos-backstore-owner-return-v1504.py")
    )["instrument"](kernel)
    swap = swap_path.read_text()
    swap = once(swap, start.replace(
        "        move    1,(17)\n",
        "        aos     daimos_v1495_failed_entry\n"
        "        move    1,(17)\n"
        "        movem   1,daimos_v1495_service_slot\n") + event,
        start.replace(
        "        move    1,(17)\n",
        "        aos     daimos_v1495_failed_entry\n"
        "        move    1,(17)\n"
        "        movem   1,daimos_v1495_service_slot\n") + stamp + event)
    # Read-only exact last-failed-owner witness. This records real DISK
    # identity and the u-area retry word, not an inferred boolean.
    before = (
        "        aos     daimos_v1495_event_returned\n"
        "        pushj   17,daimos_v1494_term_witness\n")
    after = (
        "        aos     daimos_v1495_event_returned\n"
        "        move    4,(17)\n"
        "        came    4,daimos_v1494_slot\n"
        "        jrst    daimos_v1508_record_done\n"
        "        aos     daimos_v1508_record_count\n"
        "        move    5,proc_swap_records\n"
        "        add     5,4\n"
        "        move    6,(5)\n"
        "        movem   6,daimos_v1508_last_record\n"
        "        move    5,4\n"
        "        lsh     5,1\n"
        "        add     5,4\n"
        "        add     5,proc_table\n"
        "        move    6,(5)\n"
        "        movem   6,daimos_v1508_last_meta\n"
        "        move    6,1(5)\n"
        "        movem   6,daimos_v1508_last_vm\n"
        "        move    6,2(5)\n"
        "        movem   6,daimos_v1508_last_sched\n"
        "        hlrz    5,(5)\n"
        "        move    6,067(5)\n"
        "        movem   6,daimos_v1508_last_retry\n"
        "        move    6,024(5)\n"
        "        movem   6,daimos_v1508_last_fdctl\n"
        "daimos_v1508_record_done:\n"
        "        pushj   17,daimos_v1494_term_witness\n")
    swap = once(swap, before, after)
    swap_path.write_text(swap)

    entry = kernel / "storage/backstore_entry_v484.s"
    data = entry.read_text()
    data += "\n; v1508 DISPOSABLE LAST-FAILED-OWNER WITNESS.\n        .bss\n"
    for name in ("record_count", "last_record", "last_meta", "last_vm",
                 "last_sched", "last_retry", "last_fdctl"):
        label = "daimos_v1508_" + name
        data += "        .globl %s\n%s: .block 1\n" % (label, label)
    entry.write_text(data)

    back = back_path.read_text()
    # Only v1494's *fault injection* is changed. The allocation bitmap
    # remains correct. The selected existing DISK extent still receives
    # genuine physical reads; release is repeatedly refused at the
    # checked backstore_free boundary, without publishing any RAM owner.
    # The bitmap corruption is in the copied swap module, not the
    # backstore module.
    swap = swap_path.read_text()
    swap = once(swap,
        "        andcm   7,6\n"
        "        movem   7,(4)\n"
        "        movei   4,1\n",
        "        andcm   7,6\n"
        "        ; v1508: leave actual ownership bitmap untouched.\n"
        "        ; Refuse the selected run in backstore_free instead.\n"
        "        movei   4,1\n")
    swap_path.write_text(swap)

    old = (
        "        aos     daimos_v1494_free_calls\n"
        "        move    4,daimos_v1494_free_calls\n"
        "        caie    4,3\n"
        "        jrst    daimos_v1494_free_other\n")
    new = (
        "        aos     daimos_v1494_free_calls\n"
        "        ; v1508: permanent refusal, no bitmap repair or detach.\n"
        "        jrst    daimos_v1508_permanent_refusal\n")
    back = once(back, old, new)
    back = once(back,
        "daimos_v1494_free_other:\n",
        "daimos_v1508_permanent_refusal:\n"
        "        pop     17,5\n"
        "        pop     17,4\n"
        "        seto    1,\n"
        "        popj    17,\n"
        "daimos_v1494_free_other:\n")
    back_path.write_text(back)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1508.py DISPOSABLE_KERNEL")
    inject(Path(sys.argv[1]))
