# v1677 read-only DAIMOS local/remote branch ancestry inventory

Run `python3 audit-branches-v1677.py "$HOME/git/DAIMOS" output.json`
after a fresh `git fetch --prune` of the intended remote. The script
reads ALL local refs and ALL `origin` refs, excludes symbolic remote
HEAD, classifies each by commit ancestry of main and the unmerged PURE
branch, and records every attached worktree and its dirty path count.
It fails if any unique tip would be silently discarded. It has no
merge, fetch, force checkout, deletion or push side effects.

2026-11-19 source audit PASS: 91 local, 89 remote, no unique tip,
four dirty of fifteen attached worktrees. The matching signed-off
snapshot is in DAIMOS `design/daimos-branch-consolidation-v1677.md`
and exact refs in `design/daimos-branch-ref-inventory-v1677.tsv`.
This is an inventory gate only; local and remote branch cleanup must
wait until the actual PURE mainline merge and all fault/boot tests pass.
