#!/usr/bin/env python3
"""P0-B v1092: fail-closed provider lifetime contract and unsafe mutants.

This is a structural safety guard, not a simulator proof. The booted
nonreturning-owner, permanent-refusal, and revival tests are separate.
"""

import os
from pathlib import Path


ROOT = Path(os.environ["DAIMOS_REPO"]) / "system/kernel"
FILES = {
    "gateway": (ROOT / "fs/fs_mres.s").read_text(),
    "process": (ROOT / "proc/proc_pdp6.s").read_text(),
    "file": (ROOT / "fs/file_runtime.s").read_text(),
    "syscall": (ROOT / "proc/syscall_dispatch_pdp6.s").read_text(),
}


def section(source, begin, end):
    assert source.count(begin) == 1, ("missing or ambiguous", begin)
    tail = source.split(begin, 1)[1]
    assert end in tail, ("missing end", end)
    return tail.split(end, 1)[0]


def ordered(source, *tokens):
    at = -1
    for token in tokens:
        at2 = source.find(token, at + 1)
        assert at2 > at, ("missing or out of order", token)
        at = at2


def verify(src):
    fs = src["gateway"]
    proc = src["process"]
    f = src["file"]
    disp = src["syscall"]

    serial = section(fs, "fs_provider_serialized:",
                     "; KCORE memory-pressure bridge")
    acquire = section(serial, "fs_provider_lock_retry:",
                      "fs_provider_lock_wait:")
    contention = section(serial, "fs_provider_lock_wait:",
                         "fs_provider_unlock:")
    unlock = section(serial, "fs_provider_unlock:",
                     "fs_memfs_service_jump:")
    ordered(acquire,
            "hrlzm   0,fs_provider_ready",
            "setzm   fs_provider_wait_event_v917",
            "pushj   17,@fs_memfs_service_jump(7)",
            "jrst    fs_provider_unlock")
    assert serial.count("setom   fs_provider_ready") == 1
    assert "setom   fs_provider_ready" in unlock
    assert "setom   fs_provider_wait_event_v917" in unlock
    assert "pushj   17,proc_wakeup_event" in unlock
    assert "setom   fs_provider_ready" not in contention
    assert "setom   fs_provider_ready" not in acquire

    # No lock theft when another process owns an uncompleted provider.
    ordered(contention,
            "skipn   proc_current_slot",
            "jrst    fs_provider_lock_refuse_v917",
            "hlrz    0,fs_provider_ready",
            "came    0,proc_current_slot",
            "jrst    fs_provider_lock_foreign_v1078",
            "jrst    fs_provider_lock_refuse_v917")
    assert ("came    0,proc_current_slot\n"
            "        jrst    fs_provider_lock_foreign_v1078\n"
            "        jrst    fs_provider_lock_refuse_v917") in contention
    ordered(contention,
            "fs_provider_lock_foreign_v1078:",
            "trnn    1,04",
            "jrst    fs_provider_lock_sleep_v915",
            "jrst    fs_provider_lock_refuse_v917")
    ordered(contention,
            "fs_provider_lock_refuse_v917:",
            "blt     0,7",
            "sub     17,kconst_7_7",
            "jrst    kret_neg5")
    ordered(contention,
            "fs_provider_lock_sleep_v915:",
            "pushj   17,proc_wait_event",
            "jrst    fs_provider_lock_retry")

    # Fatal cancellation is permitted only before the new provider call.
    ordered(acquire,
            "trne    1,04",
            "jrst    fs_provider_lock_probe_v1090",
            "tlne    1,016",
            "jrst    fs_provider_lock_refuse_v917",
            "trne    1,01",
            "jrst    fs_provider_lock_refuse_v917",
            "fs_provider_lock_probe_v1090:",
            "hrlzm   0,fs_provider_ready")

    event = section(proc, "proc_event_apply:",
                    "proc_event_nonfatal:")
    ordered(event,
            "move    1,PROC_FDCTL_OFFSET(1)",
            "trne    1,PROC_FATAL_CLOSE_BIT",
            "jrst    proc_event_fatal_close_busy_v879")
    ordered(event,
            "proc_event_fatal_other:",
            "trne    2,1",
            "tlne    1,PROC_WAIT_LH_MASK",
            "jrst    proc_event_fatal_other_defer_term_v926",
            "pushj   17,file_close_all_at_v865",
            "jumpn   1,proc_event_fatal_other_close_fail_v867",
            "pushj   17,proc_finish_slot")
    assert ("tlne    1,PROC_WAIT_LH_MASK\n"
            "        jrst    proc_event_fatal_other_defer_term_v926") in event
    ordered(event,
            "evt_def_record_v970:",
            "iorm    2,PROC_FDCTL_OFFSET(1)",
            "tlne    5,PROC_WAIT_CHILD_LH",
            "jrst    evt_def_done_v1090",
            "tlne    5,PROC_WAIT_EVENT_LH",
            "hrrz    6,5",
            "caie    6,fs_provider_wait_event_v917",
            "caie    6,PROC_STATE_SLEEP",
            "pushj   17,proc_runq_add")
    wake = section(event, "evt_def_record_v970:",
                   "proc_event_fatal_close_busy_v879:")
    for forbidden in ("mm_free", "fs_provider_unlock",
                      "proc_finish_slot", "file_close_all"):
        assert forbidden not in wake, ("unsafe fatal wake", forbidden)

    finalizer = section(proc, "proc_finish_new_v881:",
                        "proc_finish_new_self_v920:")
    ordered(finalizer,
            "tlne    1,PROC_WAIT_LH_MASK",
            "jrst    proc_finish_fail",
            "tlnn    1,010000",
            "jrst    proc_finish_fail")

    # Rejected provider CLOSE is an occupied process-private owner, not a
    # committed exit. Retry delay is capped; total completion is not.
    fatal = section(proc, "proc_fatal_close_current_v879:",
                    "/**\n * @brief Publish the current process-private kernel stack")
    ordered(fatal,
            "iorm    3,-2(2)",
            "proc_fatal_close_retry_v879:",
            "pushj   17,file_close_all",
            "jumpn   1,proc_fatal_close_wait_v995",
            "pushj   17,proc_session_teardown",
            "jumpe   1,proc_fatal_close_done_v879",
            "proc_fatal_close_wait_v995:",
            "pushj   17,proc_sleep_ticks",
            "caige   1,01000",
            "jrst    proc_fatal_close_retry_v879",
            "proc_fatal_close_done_v879:",
            "jrst    proc_exit_current")
    for forbidden in ("mm_free", "proc_finish_slot",
                      "setom   fs_provider_ready"):
        assert forbidden not in fatal, ("unsafe owner release", forbidden)

    close = section(f, "file_close_entry_v865:",
                    "; int file_dup(int fd)")
    ordered(close,
            "file_close_vfs:", "pushj   17,vfs_sync",
            "file_close_finish:", "jumpn   1,file_close_done",
            "setzm   (010)")
    allclose = section(f, "file_close_all_at_v865:",
                       "; Shared bulk-word I/O validation")
    ordered(allclose, "pushj   17,file_close_entry_v865",
            "jumpe   1,file_close_all_next",
            "file_close_all_failed_v888:", "seto    012",
            "movem   4,1(011)", "move    1,012")
    assert "proc_control_getteardown_v886:" in proc
    assert "trne    6,PROC_FATAL_CLOSE_BIT" in proc
    assert ".equ    PROC_OOM_BRK_ENABLED_V1000,0" in disp


verify(FILES)

# Negative controls change real source code in memory, not runtime fixtures.
# Each must break one independent ownership or containment invariant.
MUTATIONS = (
    ("foreign unlock", "gateway", "fs_provider_lock_foreign_v1078:\n",
     "fs_provider_lock_foreign_v1078:\n"
     "        setom   fs_provider_ready\n"),
    ("recursive wait", "gateway",
     "        jrst    fs_provider_lock_refuse_v917\n"
     "fs_provider_lock_foreign_v1078:",
     "        jrst    fs_provider_lock_sleep_v915\n"
     "fs_provider_lock_foreign_v1078:"),
    ("fatal owner sleep", "gateway",
     "        trnn    1,04                  ; skip wait when fatal-close is set",
     "        trnn    1,00                  ; skip wait when fatal-close is set"),
    ("early unlock", "gateway",
     "        pushj   17,@fs_memfs_service_jump(7)\n"
     "        jrst    fs_provider_unlock",
     "        setom   fs_provider_ready\n"
     "        pushj   17,@fs_memfs_service_jump(7)\n"
     "        jrst    fs_provider_unlock"),
    ("fatal close stuck", "gateway",
     "        trne    1,04                  ; already in owner-side FILE teardown",
     "        trnn    1,04                  ; already in owner-side FILE teardown"),
    ("no pending abort", "gateway",
     "        tlne    1,016                 ; pending INT/TERM/HUP",
     "        tlnn    1,016                 ; pending INT/TERM/HUP"),
    ("remote stack free", "process",
     "        tlne    1,PROC_WAIT_LH_MASK\n"
     "        jrst    proc_event_fatal_other_defer_term_v926",
     "        tlne    1,PROC_WAIT_LH_MASK\n"
     "        jrst    proc_event_fatal_other_close_fail_v867"),
    ("remote fatal owner free", "process",
     "        trne    1,PROC_FATAL_CLOSE_BIT\n"
     "        jrst    proc_event_fatal_close_busy_v879",
     "        trne    1,PROC_FATAL_CLOSE_BIT\n"
     "        jrst    proc_event_fatal_other"),
    ("remote finalizer ignores wait", "process",
     "        tlne    1,PROC_WAIT_LH_MASK\n"
     "        jrst    proc_finish_fail",
     "        tlnn    1,PROC_WAIT_LH_MASK\n"
     "        jrst    proc_finish_fail"),
    ("child wake", "process", "        tlne    5,PROC_WAIT_CHILD_LH",
     "        tlnn    5,PROC_WAIT_CHILD_LH"),
    ("wrong event wake", "process",
     "        caie    6,fs_provider_wait_event_v917",
     "        caie    6,0"),
    ("unbounded cpu retry", "process", "        caige   1,01000",
     "        caige   1,0777777"),
    ("failed close commits", "file",
     "file_close_finish:\n        jumpn   1,file_close_done",
     "file_close_finish:\n        jumpe   1,file_close_done"),
    ("OOM early activation", "syscall",
     ".equ    PROC_OOM_BRK_ENABLED_V1000,0",
     ".equ    PROC_OOM_BRK_ENABLED_V1000,1"),
)

for label, file_key, before, after in MUTATIONS:
    original = FILES[file_key]
    assert original.count(before) == 1, ("ambiguous mutation", label)
    candidate = dict(FILES)
    candidate[file_key] = original.replace(before, after, 1)
    try:
        verify(candidate)
    except AssertionError:
        continue
    raise AssertionError(("unsafe mutation unexpectedly accepted", label))

print("v1092: P0-B provider lifetime/quarantine source contract PASS")
print("v1092: 14 unsafe ownership, wake, retry, and OOM mutants rejected PASS")
