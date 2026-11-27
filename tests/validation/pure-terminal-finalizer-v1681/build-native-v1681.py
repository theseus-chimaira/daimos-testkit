#!/usr/bin/env python3
"""Source-extract original finalizer/VM/MM/RAW terminal into PDP6 test."""
from pathlib import Path
import sys


def once(source, old, new):
    if source.count(old) != 1:
        raise ValueError("original production/fixture source anchor moved: " +
                         old[:65])
    return source.replace(old, new, 1)


def between(source, before, after):
    if source.count(before) != 1 or after not in source.split(before, 1)[1]:
        raise ValueError("original MM/FINALIZE source boundary changed: " +
                         before[:65])
    return before + source.split(before, 1)[1].split(after, 1)[0]


def main():
    if len(sys.argv) != 4:
        raise ValueError("usage: build-native-v1681.py DAIMOS testkit workdir")
    kernel = Path(sys.argv[1]) / "system/kernel"
    tests = Path(sys.argv[2]) / "tests/validation"
    work = Path(sys.argv[3]);work.mkdir(parents=True, exist_ok=True)
    source = (kernel / "proc/proc_pdp6.s").read_text(encoding="ascii")
    head = ".text\n.globl proc_finish_slot\n.globl proc_finish_service_v881\n.globl proc_finish_backoff_advance_v885\n"
    head += ".equ PROC_WORDS,3\n.equ PROC_TRANSITION_RH,0200000\n"
    head += ".equ PROC_STATE_LH_MASK,0700000\n"
    head += ".equ PROC_FILE_TABLE_OFFSET,026\n.equ PROC_FDCTL_OFFSET,024\n"
    head += ".equ PROC_FINALIZE_OFFSET,067\n"
    head += ".equ PROC_FINALIZE_MARK_LH,0400000\n"
    head += ".equ PROC_FINALIZE_PREVM_LH,0100000\n"
    head += ".equ PROC_FINISH_ARMED_LH_V1763,040000\n"
    # K05 v1902 also scans one mutually exclusive PURE rollback tag.
    # This historical v1681 guest exercises ORIGINAL FINALIZE owners,
    # never a PURE recovery. Extract the original new tag constant;
    # fail the guest if an incorrect FINALIZE/PURE dispatch crosses it.
    head += ".equ PROC_SWAP_RETRY_LH,040000\n"
    head += ".equ PROC_FATAL_CLOSE_BIT,4\n.equ CTX_PC,020\n"
    head += ".equ PROC_WAIT_LH_MASK,060000\n"
    body = between(source, "proc_finish_slot:\n", "\nproc_slot_discard:\n")
    backoff = between(source, "proc_finish_backoff_advance_v885:\n",
                      "\n        .bss\n")
    # v1937 added a real stack-owned EXEC reservation check before
    # foreign teardown. Link the original guard, not a permissive stub.
    backing_source = (kernel / "proc/proc_pure_backing_pdp6.s").read_text(
        encoding="ascii")
    stack_guard = between(backing_source, "proc_exec_stack_busy_v1937:\n",
                          "\n; Release exactly this stack record")
    (work / "original-finalizer.s").write_text(
        head + body + "\n" + backoff +
        "\n.globl proc_exec_stack_busy_v1937\n" + stack_guard +
        "\n.bss\n.globl proc_exec_resv_head_v1933\n"
        "proc_exec_resv_head_v1933: .block 1\n", encoding="ascii")

    vm = (kernel / "proc/vm_pdp6.s").read_text(encoding="ascii")
    part = between(vm,"vm_space_destroy:\n", "\n/**\n")
    (work / "original-vm-destroy.s").write_text(
        ".text\n.globl vm_space_destroy\n" + part, encoding="ascii")

    mm = (kernel / "mm/mm_pdp6.s").read_text(encoding="ascii")
    bits = (between(mm, "mm_delete:\n", "\n; int mm_extent_insert(") +
            between(mm,"mm_find_base:\n", "\n; int mm_is_pinned(") +
            between(mm,"mm_free:\n", "\n; int mm_process_transfer_pinned(") +
            between(mm,"mm_pin_adjust:\n", "\n        .bss\n"))
    head = (".text\n.globl mm_pin\n.globl mm_unpin\n.globl mm_free\n"
            ".equ MM_PIN_ONE,010000000\n"
            ".equ MM_PIN_FIELD,03770000000\n")
    (work / "original-mm.s").write_text(head + bits, encoding="ascii")

    fixture = (tests / "daimos-deferred-uarea-v881.s").read_text(
        encoding="ascii")
    fixture = ".text\n.globl proc_session_teardown\n" + fixture.split(
        ".globl proc_session_teardown\n", 1)[1]
    fixture = once(fixture,
        "vm_space_destroy:\n aos __vm_calls\n setom 1(1)\n setz 1,\n popj 17,\n", "")
    # Link the original v1768 parent eligibility leaf: a real RUN INIT
    # is necessary for ZOMB publication. The old v881 fixture left slot
    # 1 empty and incorrectly assumed any parent number was waitable.
    fixture = once(fixture,
        "__ptable: .block 6\n .word __uarea,,0400407\n .word 04000,,020000\n",
        "__ptable: .block 3\n"
        " .word __init_uarea_v1807,,0400000\n"
        " .word 04000,,020000\n"
        " .word 0200000,,0\n"
        " .word __uarea,,0400407\n .word 02000,,0\n")
    fixture += "\n.data\n__init_uarea_v1807: .block 0407\n"
    # Original v881 fixture owns C-coded proc_table symbol and stable
    # u-area. It has no RAW backing. Install one at the exact v1609
    # u-area offset, leaving the rest of the fixture unchanged.
    old = " .block 0407-070\n .word 0\n"
    if fixture.count(old) != 2:
        raise ValueError("v1681 exactly two fixture u-area blocks required")
    fixture = fixture.replace(old,
        " .block 0406-070\n .word 0\n .word 0\n", 1)
    fixture += """
.data
.globl mm_extents
mm_extents: .block 020
.globl mm_extent_count
mm_extent_count: .word 0
.globl mm_extent_capacity
mm_extent_capacity: .word 010
.globl mm_core_words
mm_core_words: .word 0100000
.globl mm_arenas
mm_arenas: .word 040000,,040000
 .block 2
.globl mm_arena_count
mm_arena_count: .word 1
__records_v1681: .block 4
__modes_v1681: .word 0
.globl vfs_mount_limit
vfs_mount_limit: .word 0
.globl vfs_mount_root_base
vfs_mount_root_base: .word 0
.globl vfs_namespace_root
vfs_namespace_root: .word 0
.globl kconst_2_2
kconst_2_2: .word 2,,2
.globl proc_swap_storage_invariant_v30
.text
proc_swap_storage_invariant_v30:
 movei 1,0777
 movem 1,__test_exit
 halt .
.globl proc_swap_service_one
proc_swap_service_one:
 movei 1,0701
 movem 1,__test_exit
 halt .
.globl fs_provider_reg_call
fs_provider_reg_call:
 seto 1,
 popj 17,
.globl vfs_dtfs_owner_admit_v1562
vfs_dtfs_owner_admit_v1562:
 seto 1,
 popj 17,
"""
    (work / "driver-v1681.s").write_text(fixture, encoding="ascii")

    term = (kernel / "proc/proc_pure_packed_detach_v1609.s").read_text(
        encoding="ascii")
    pre = (".equ PROC_SWAP_TEXT_SHIFT,026\n"
           ".equ PROC_SWAP_TEXT_MASK,037777\n"
           ".equ PROC_SWAP_BACKING_OFFSET,0406\n"
           ".equ EXEC_USER_ORIGIN,020\n")
    (work / "original-pure-term.s").write_text(pre + term,
                                                encoding="ascii")
    (work / "term-entry.s").write_text(
        ".text\n.globl proc_swap_term_v1666\n"
        "proc_swap_term_v1666:\n jrst pdp6_pure_detach_v1609\n",
        encoding="ascii")
    backing = (0o500 << 0o26) | 0o12345
    test = (tests / "pure-terminal-finalizer-v1681/test-native-v1681.s").read_text(
        encoding="ascii")
    if test.count("V1681_BACKING_WORD") != 2:
        raise ValueError("v1681 test must use exact backing twice")
    test = test.replace("V1681_BACKING_WORD", "%o" % backing)
    # The existing v881 fixture deliberately uses local symbols for
    # its mm/process backing. Emit test and fixture in one source unit.
    # Original production functions remain separately linked and unchanged.
    (work / "test-fixture.s").write_text(
        test + "\n" + fixture, encoding="ascii")
    print("v1681: production FINALIZER/VM/MM/PURE source boundaries PASS;")
    print("v1681: test backing octal", oct(backing))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit("FAIL v1681 source: " + str(exc))
