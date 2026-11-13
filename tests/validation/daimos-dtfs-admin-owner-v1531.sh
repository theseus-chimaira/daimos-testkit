#!/bin/sh
# Source-linked real KCORE/VFS/FILE administration with swapped-uarea
# remote owners and an injected interprocess-open race during provider I/O.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dtfs-admin-owner-v1531.XXXXXX")
if [ "${DTFS_ADMIN_OWNER_KEEP_V1531:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
fi

python3 - "$DAIMOS_REPO" "$work" <<'PY'
from pathlib import Path
import sys

repo, out = (Path(x) for x in sys.argv[1:])
vfs = (repo / "system/kernel/fs/vfs.s").read_text()
file = (repo / "system/kernel/fs/file_runtime.s").read_text()

def section(text, start, end):
    assert text.count(start) == 1, (start, text.count(start))
    a = text.index(start)
    assert end in text[a:], end
    return text[a:text.index(end, a)]

vfs_src = section(
    vfs, "vfs_unmount:\n",
    "        .data\n; KINIT publishes both bases"
)
assert "vfs_dtfs_discard_slot_v1531:\n" in vfs_src
assert "vfs_dtfs_poisoned_slot_v1531:\n" in vfs_src
assert "vfs_unmount_owner_check_v1523:\n" in vfs_src
fd_src = section(
    file, "file_node_from_fd:\n", "file_check_access:\n"
)
drop_src = section(
    file, "file_dtfs_abandon_fd_v1531:\n",
    "; int file_dup(int fd)"
)
find_src = section(
    file, "file_find:\n", "; int file_new_fd"
)
busy_src = section(
    file, "file_mount_busy_v1523:\n",
    "; int file_close_all(void)"
)
source = (".text\n.globl vfs_dtfs_discard_slot_v1531\n"
          ".globl vfs_dtfs_poisoned_slot_v1531\n"
          ".globl file_dtfs_abandon_fd_v1531\n"
          ".globl file_mount_busy_v1523\n"
          ".globl file_find\n.globl file_node_from_fd\n"
          + vfs_src + "\n" + fd_src + "\n"
          + drop_src + "\n" + find_src + "\n" + busy_src)
(out / "production-v1531.s").write_text(source)
mutants = (
    ("skip-initial-owner",
     "pushj   17,vfs_unmount_owner_check_v1523",
     "pushj   17,kret_zero"),
    ("skip-final-owner",
     "pushj   17,vfs_unmount_owner_check_v1523",
     "pushj   17,kret_zero", -1),
    ("skip-provider-verify",
     "pushj   17,fs_provider_reg_call",
     "pushj   17,kret_zero"),
    ("skip-write-marker",
     "trnn    3,0400000",
     "trnn    3,0"),
)
for item in mutants:
    name, old, new = item[:3]
    if name == "skip-write-marker":
        anchor, region = "", source
    else:
        start = "vfs_dtfs_discard_slot_v1531:\n"
        assert source.count(start) == 1
        prefix, region = source.split(start, 1)
        anchor = prefix + start
    count = region.count(old)
    expected = 2 if "owner" in name else 1
    assert count == expected, (name, count, expected)
    if len(item) == 4:
        prefix, suffix = region.rsplit(old, 1)
        altered = anchor + prefix + new + suffix
    else:
        altered = anchor + region.replace(old, new, 1)
    (out / ("mutant-" + name + "-v1531.s")).write_text(altered)
print("PASS v1531: extracted live VFS/FILE source with four mutations")
PY

run_case()
{
    name=$1
    source=$2
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 650000 \
        --timeout 30 --workdir "$work/run-$name" \
        --name "dtfs-admin-$name-v1531" --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" \
        "$self/daimos-dtfs-admin-owner-v1531.s" \
        "$source" > "$work/$name.log" 2>&1
}

if ! run_case baseline "$work/production-v1531.s"; then
    tail -65 "$work/baseline.log" >&2
    echo 'FAIL v1531: real VFS/FILE admin-owner baseline' >&2
    exit 1
fi
echo 'PASS v1531: all-process owner fencing, poison-only FD drop and replacement'
for name in skip-initial-owner skip-final-owner skip-provider-verify \
    skip-write-marker; do
    if run_case "$name" "$work/mutant-$name-v1531.s"; then
        echo "FAIL v1531: accepted unsafe $name source mutation" >&2
        exit 1
    fi
    grep -q '^FAIL: __test_exit:' "$work/$name.log" || {
        tail -65 "$work/$name.log" >&2
        echo "FAIL v1531: mutant $name did not reach oracle" >&2
        exit 1
    }
    echo "PASS v1531: rejected native $name mutation"
done
