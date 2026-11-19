#!/usr/bin/env python3
"""Read-only, fail-closed inventory of all DAIMOS local and remote refs.

No delete, merge, push, fetch or worktree modification is performed.
Classification is by Git ancestry, not by similar branch names.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path


def git(root, *args):
    return subprocess.check_output(
        ["git", "-C", str(root)] + list(args),
        text=True, stderr=subprocess.PIPE).strip()


def ancestor(root, a, b):
    return subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", a, b],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def audit(root, main, feature):
    main_id = git(root, "rev-parse", "--verify", main + "^{commit}")
    feature_id = git(root, "rev-parse", "--verify", feature + "^{commit}")
    lines = git(root, "for-each-ref", "--format=%(refname) %(objectname)",
                "refs/heads", "refs/remotes").splitlines()
    items = []
    local = set()
    remote = set()
    for line in lines:
        path, oid = line.split()
        if path.startswith("refs/heads/"):
            name = path[len("refs/heads/"):]
            scope = "local"
            local.add(name)
        elif path.startswith("refs/remotes/origin/"):
            name = path[len("refs/remotes/origin/"):]
            if name == "HEAD":
                continue
            scope = "origin"
            remote.add(name)
        else:
            continue
        m = ancestor(root, oid, main_id)
        f = ancestor(root, oid, feature_id)
        classification = ("both" if m and f else "main-only" if m
                          else "feature-only" if f else "unique")
        items.append({"name": name, "scope": scope,
                      "commit": oid, "classification": classification})
    worktrees = []
    parts = git(root, "worktree", "list", "--porcelain").split("\n\n")
    for part in parts:
        fields = {}
        for line in part.splitlines():
            if " " in line:
                k, v = line.split(" ", 1)
                fields[k] = v
            elif line:
                fields[line] = True
        if "worktree" not in fields:
            continue
        wpath = Path(fields["worktree"])
        dirty = git(wpath, "status", "--porcelain", "--untracked-files=normal")
        worktrees.append({"path": str(wpath), "head": fields.get("HEAD", ""),
                          "branch": fields.get("branch", "DETACHED"),
                          "dirty_count": len(dirty.splitlines()) if dirty else 0})
    totals = {name: sum(x["classification"] == name for x in items)
              for name in ("both", "main-only", "feature-only", "unique")}
    result = {"main": main_id, "feature": feature_id,
              "refs": sorted(items, key=lambda x: (x["scope"], x["name"])),
              "counts": totals, "local_count": len(local),
              "remote_count": len(remote),
              "local_only": sorted(local - remote),
              "remote_only": sorted(remote - local),
              "worktrees": worktrees}
    if totals["unique"]:
        raise ValueError("unmerged unique branch tips: " + ", ".join(
            x["scope"] + "/" + x["name"] for x in items
            if x["classification"] == "unique"))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repo")
    parser.add_argument("out")
    parser.add_argument("--main", default="main")
    parser.add_argument("--feature", default=
                        "kcore-pure-reclaim-pressure-v1673-20261118")
    args = parser.parse_args()
    try:
        output = audit(Path(args.repo), args.main, args.feature)
    except (subprocess.CalledProcessError, ValueError) as exc:
        raise SystemExit("FAIL v1677 branch inventory: " + str(exc))
    Path(args.out).write_text(json.dumps(output, sort_keys=True,
                                         indent=2) + "\n", encoding="ascii")
    print("PASS v1677 branch inventory: %d local, %d origin, %d unique" %
          (output["local_count"], output["remote_count"],
           output["counts"]["unique"]))
    print("worktrees: %d, dirty: %d" %
          (len(output["worktrees"]), sum(bool(x["dirty_count"])
           for x in output["worktrees"])))


if __name__ == "__main__":
    main()
