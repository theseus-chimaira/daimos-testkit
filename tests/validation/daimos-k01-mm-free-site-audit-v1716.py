#!/usr/bin/env python3
"""K01 MM-free ownership/refusal source audit for real production PDP-6.

This is a structural canary, not a proof of all runtime interleavings.
Every production mm_free caller must have a reviewed failure edge.
"""

from pathlib import Path
import re
import sys


# Each guard is the first executable branch after mm_free, except for
# MEMFS's saved-AC4 POP. An unchanged site count prevents a new release
# caller from silently escaping the K01 owner-refusal audit.
SITES = {
    "drivers/dpy_io.s": (
        "jumpn 1,dpy_list_done",
        "jumpn 1,dpy_list_rollback_v874",
        "jumpn 1,dpy_list_rollback_bad_v874",
        "jumpe 1,dpy_list_stopped",
    ),
    "fs/d6fs_runtime.s": (
        "jumpn 1,proc_swap_storage_invariant_v30",
        "jumpn 1,d6fs_provider_unmount_free_fail",
    ),
    "fs/dtfs_intent_owned_arm_v1552.s": (
        "jumpn 1,dtfs_owned_arm_release_fail_v1552",
        "jumpn 1,dtfs_owned_arm_fail_v1552",
    ),
    "fs/memfs_data_pdp6.s": (
        "jumpn 1,memfs_data_free_fail_v1401",
        "jumpn 1,memfs_evict_zero",
        "jumpn 1,memfs_data_destroy_invariant_v1400",
    ),
    "fs/memfs_runtime.s": (
        "jumpn 1,memfs_mres_mount_bad",
        "jumpn 1,memfs_mres_unmount_bad",
    ),
    "fs/tsfs_runtime.s": (
        "jumpn 1,proc_swap_storage_invariant_v30",
        "jumpn 1,proc_swap_storage_invariant_v30",
    ),
    "ipc/pipe.s": (
        "jumpn 1,proc_swap_storage_invariant_v30",
        "jumpe 1,pipe_close_ok",
    ),
    "proc/exec_lowmem_pdp6.s": (
        "jumpn 1,proc_swap_storage_invariant_v30",
    ),
    "proc/proc_pdp6.s": (
        "jumpn 1,proc_uarea_release_fail",
    ),
    "proc/proc_swap_pdp6.s": (
        "jumpn 1,proc_swap_storage_invariant_v30",
        "jumpn 1,proc_swap_storage_invariant_v30",
        "jumpn 1,proc_swap_storage_invariant_v30",
    ),
    "proc/vm_pdp6.s": (
        "jumpe 1,vm_brk_commit",
        "jumpn 1,proc_swap_storage_invariant_v30",
        "jumpn 1,vm_space_destroy_fail",
    ),
    "storage/bcache_pdp6.s": (
        "jumpn 1,bcache_reclaim_none",
    ),
}

CALL = re.compile(r"^\s*pushj\s+17,mm_free\s*(?:;.*)?$")
BRANCH = re.compile(r"\s+")


def normalized(text):
    return BRANCH.sub(" ", text.strip().split(";", 1)[0]).strip()


def check_source(root):
    found = {}
    for path in sorted(root.rglob("*.s")):
        lines = path.read_text(errors="replace").splitlines()
        sites = []
        for i, line in enumerate(lines):
            if not CALL.fullmatch(line):
                continue
            # Keep only instructions, not source comments, from the
            # next few lines. The first executable action after a free
            # must branch on its typed result or preserve a saved AC.
            after = []
            for text in lines[i + 1:i + 12]:
                norm = normalized(text)
                if not norm or norm.startswith(";"):
                    continue
                after.append(norm)
                if len(after) >= 4:
                    break
            sites.append((i + 1, after))
        if sites:
            found[str(path.relative_to(root))] = sites

    if set(found) != set(SITES):
        raise ValueError("MM-free source files changed: unexpected=%s missing=%s" %
                         (sorted(set(found) - set(SITES)),
                          sorted(set(SITES) - set(found))))

    count = 0
    for filename, expected in SITES.items():
        actual = found[filename]
        if len(actual) != len(expected):
            raise ValueError("%s has %d MM free sites, expected %d" %
                             (filename, len(actual), len(expected)))
        for (line, after), guard in zip(actual, expected):
            count += 1
            first = after[0] if after else ""
            if filename == "fs/memfs_data_pdp6.s" and "memfs_data_free_fail_v1401" in guard:
                if first != "pop 17,4" or len(after) < 2:
                    raise ValueError("%s:%d lost saved-AC4 return" % (filename, line))
                first = after[1]
            if first != guard:
                raise ValueError("%s:%d lacks reviewed MM refusal edge %r (got %r)" %
                                 (filename, line, guard, first))
    assert count == 26
    return count


def self_test(root):
    check_source(root)
    rejected = 0
    # Check the audit's failure modes without editing the actual tree.
    import tempfile
    from shutil import copytree
    with tempfile.TemporaryDirectory(prefix="daimos-k01-mm-free-audit-v1716-") as td:
        dst = Path(td) / "kernel"
        copytree(root, dst)
        targets = (
            ("ipc/pipe.s", 0),
            ("proc/exec_lowmem_pdp6.s", 0),
            ("fs/memfs_runtime.s", 0),
            ("fs/d6fs_runtime.s", 1),
        )
        for name, ordinal in targets:
            file = dst / name
            s = file.read_text()
            lines = s.splitlines(keepends=True)
            sites = [i for i, text in enumerate(lines) if CALL.fullmatch(text.rstrip("\n"))]
            assert len(sites) == len(SITES[name]), name
            needle = SITES[name][ordinal]
            matches = [i for i in range(sites[ordinal] + 1,
                                        min(sites[ordinal] + 12, len(lines)))
                       if normalized(lines[i]) == needle]
            assert len(matches) == 1, (name, needle)
            lines[matches[0]] = "        move    0,0    ; unsafe no refusal\n"
            file.write_text("".join(lines))
            try:
                check_source(dst)
            except ValueError:
                rejected += 1
            else:
                raise AssertionError("unsafe source mutation was accepted: " + name)
            file.write_text(s)
        # An entirely new caller requires explicit owner/refusal review.
        file = dst / "proc/proc_pdp6.s"
        original = file.read_text()
        file.write_text(original + "\nnew_mm_free_unreviewed_v1716:\n"
                        "        pushj   17,mm_free\n"
                        "        popj    17,\n")
        try:
            check_source(dst)
        except ValueError:
            rejected += 1
        else:
            raise AssertionError("unreviewed new MM-free caller was accepted")
        file.write_text(original)
    assert rejected == len(targets) + 1
    return rejected


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: daimos-k01-mm-free-site-audit-v1716.py DAIMOS_REPO")
    root = Path(sys.argv[1]) / "system/kernel"
    count = check_source(root)
    mutations = self_test(root)
    print("K01 v1716: %d production MM-free callers audited in %d files PASS" %
          (count, len(SITES)))
    print("K01 v1716: %d unsafe refusal-edge mutations rejected PASS" % mutations)
    print("K01 v1716: structural check only; runtime/physical gates remain independent")


if __name__ == "__main__":
    main()
