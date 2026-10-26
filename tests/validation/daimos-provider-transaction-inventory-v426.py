#!/usr/bin/env python3
"""Audit native shared-workspace and potentially sleeping provider paths.

This is an inventory, not a proof that any particular path can release its
workspace. Run against the DAIMOS checkout before changing lock ownership.
"""
import argparse
import pathlib
import re


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", type=pathlib.Path)
    args = parser.parse_args()
    root = args.repo.resolve() / "system/kernel"
    checked = (
        "fs/d6fs_runtime.s", "fs/dtfs_runtime.s", "fs/dtfs_resize.s",
        "fs/tsfs_runtime.s", "fs/vfs.s", "storage/bcache_pdp6.s",
        "storage/auxstore_boot.c",
    )
    workspace_total = 0
    for rel in checked:
        path = root / rel
        lines = path.read_text().splitlines()
        workspace = [i for i, line in enumerate(lines, 1)
                     if re.search(r"\bfs_block_workspace\b", line)
                     and not line.lstrip().startswith((";", "//", "/*", "*"))]
        waits = [i for i, line in enumerate(lines, 1)
                 if re.search(r"\b(proc_wait_event|dsk270_(?:read|write)_sector|"
                              r"drm236_(?:read|write)_block)\b", line)
                 and not line.lstrip().startswith((";", "//", "/*", "*"))]
        workspace_total += len(workspace)
        print(f"{rel}: workspace_refs={len(workspace)} lines={workspace}; "
              f"direct_sleep_or_io_refs={len(waits)} lines={waits}")
    bridge = (root / "fs/fs_mres.s").read_text()
    for required in ("fs_provider_serialized:", "fs_provider_lock_wait:",
                     "fs_provider_unlock:", "fs_provider_ready:"):
        if required not in bridge:
            raise SystemExit(f"missing baseline lock anchor: {required}")
    if workspace_total < 20:
        raise SystemExit("unexpected shared-workspace inventory shrink")
    print(f"provider-transaction-inventory-v426: PASS "
          f"({workspace_total} workspace references; baseline lock intact)")


if __name__ == "__main__":
    main()
