#!/usr/bin/env python3
"""Fail-closed v1510 test-only C and PDP-6 assembly injection checks."""

from pathlib import Path
import os
import runpy
import tempfile


HERE = Path(__file__).resolve().parent
USER = runpy.run_path(str(HERE / "daimos-backstore-swapped-user-v1510.py"))
OBSERVER = runpy.run_path(str(HERE / "daimos-backstore-swapped-observer-v1510.py"))
PREV = runpy.run_path(str(HERE / "daimos-backstore-bystander-user-v1509.py"))


def expect_reject(callback, label):
    try:
        callback()
    except ValueError:
        return
    raise AssertionError("v1510 accepted malformed source: " + label)


def make_kernel(path):
    (path / "proc").mkdir(parents=True, exist_ok=True)
    (path / "storage").mkdir(exist_ok=True)
    (path / "proc/proc_pdp6.s").write_text(
        "daimos_test_sleep_normal_v1150:\n        hrrz    1,1\n")
    (path / "proc/proc_swap_pdp6.s").write_text(
        "proc_swap_service_restore_done_v842:\n"
        "        aos     daimos_f07s_restored_v1209\n"
        "        pop     17,1\n"
        "        iori    1,PROC_SCHED_READY_ONCE\n"
        "proc_swap_service_pressure:\n"
        "proc_swap_service_exchanged_v834:\n"
        "        aos     daimos_f07s_exchanged_v1209\n"
        "        pop     17,2                   ; discard candidate\n"
        "        ; original checked exchange\n"
        "        pop     17,1\n"
        "        iori    1,PROC_SCHED_READY_ONCE\n"
        "proc_swap_service_no_pair_v834:\n")
    (path / "storage/backstore_entry_v484.s").write_text(
        "; v1508 exact owner witnesses\n        .bss\n")


def self_test():
    original = (HERE / "daimos-oom-requester-live-v1075.c").read_text()
    # Supply only the existing v1348 fixture marker expected by v1509.
    original = original.replace(
        "        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,\n"
        "                SYS_EVENT_ARG((unsigned int)spinner, SYS_EVENT_TERM)) != 0)\n",
        "        /* v1348 disposable guest only: normal spinner countdown. */\n"
        "        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,\n"
        "                SYS_EVENT_ARG((unsigned int)spinner, SYS_EVENT_TERM)) != 0)\n",
        1)
    original = PREV["inject"](original)
    generated = USER["inject"](original)
    assert generated.count("dsys_sleep(0120000U)") == 1
    assert generated.count("if (dsys_getpid() == 011U)") == 1
    assert generated.count("if (dsys_read_words(0, &word, 1U) != 0)") >= 1
    assert generated.index("v1510 disposable child") > generated.index(
        "if (dsys_write_words(3, &word, 1U) != 1")
    for label, changed in (
        ("missing-C-branch", original.replace(USER["ANCHOR"], "", 1)),
        ("double-C-branch", original + USER["ANCHOR"]),
        ("missing-v1509", original.replace(
            "v1509: retain the REAL spinner during extra-child TERM/WAIT",
            "absent", 1)),
        ("duplicate-contender", generated),
    ):
        expect_reject(lambda c=changed: USER["inject"](c), label)

    root_tmp = os.environ.get("TMPDIR", os.path.expanduser("~/tmp"))
    with tempfile.TemporaryDirectory(prefix="daimos-v1510-src-",
                                     dir=root_tmp) as dirname:
        root = Path(dirname)
        make_kernel(root)
        observer = OBSERVER["inject"]
        observer(root)
        changed = (root / "proc/proc_swap_pdp6.s").read_text()
        assert changed.count("aos     daimos_v1510_restore_count") == 1
        assert changed.count("aos     daimos_v1510_exchange_count") == 1
        assert (root / "proc/proc_pdp6.s").read_text().count(
            "aos     daimos_v1510_sleep_count") == 1
        assert (root / "storage/backstore_entry_v484.s").read_text().count(
            "daimos_v1510_sleep_count: .block 1") == 1
        expect_reject(lambda: observer(root), "double-observer")

        make_kernel(root)
        path = root / "proc/proc_swap_pdp6.s"
        original = path.read_text()
        path.write_text(original.replace(
            "proc_swap_service_exchanged_v834:", "changed_exchange:"))
        expect_reject(lambda: observer(root), "missing-exchange")

        make_kernel(root)
        path = root / "proc/proc_pdp6.s"
        path.write_text("proc_sleep_ticks:\n        hrrz    1,1\n")
        expect_reject(lambda: observer(root), "missing-real-sleep")

        make_kernel(root)
        path = root / "proc/proc_swap_pdp6.s"
        path.write_text(path.read_text().replace(
            "        iori    1,PROC_SCHED_READY_ONCE\n", "", 1))
        expect_reject(lambda: observer(root), "missing-checked-publish")

    print("PASS v1510: delayed user child preserves original PIPE wait")
    print("PASS v1510: real checked restore/exchange and SLEEP source anchors")
    print("PASS v1510: eight malformed source mutations rejected")


if __name__ == "__main__":
    self_test()
