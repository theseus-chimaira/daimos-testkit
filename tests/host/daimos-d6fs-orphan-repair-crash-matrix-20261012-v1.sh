#!/bin/sh
# C99 d6fsck real-media recovery: abort after each fsync'd repair block.
# Always uses disposable copies; NEVER invoke repair on input disk images.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO required}"
: "${D6FS_DISK:?D6FS_DISK must point to the pre-existing faulted disk directory}"
: "${TMPDIR:=$HOME/tmp}"
: "${D6FS_MEMBERS:=4}"
: "${D6FS_CUT_MAX:=256}"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-d6fs-orphan-repair-crash-20261012-v1.XXXXXXXX")
cc=${HOST_CC:-cc}
"$cc" -std=c99 -O2 -Wall -Wextra -Werror -DD6FSCK_TEST_FAULTS \
    "$DAIMOS_REPO/tools/host/d6fsck.c" -o "$work/d6fsck-fault"
"$cc" -std=c99 -O2 -Wall -Wextra -Werror \
    "$DAIMOS_REPO/tools/host/d6fsck.c" -o "$work/d6fsck-clean"
# This specific regression starts with two unreachable regular FCBs, 0451/0452.
if "$work/d6fsck-clean" -n "$D6FS_MEMBERS" -d "$D6FS_DISK" > "$work/source-check.log" 2>&1; then
    echo 'ERROR: expected faulted/orphaned source image' >&2; exit 1
fi
grep -F 'unreachable FCB: 451' "$work/source-check.log" >/dev/null
grep -F 'unreachable FCB: 452' "$work/source-check.log" >/dev/null
find "$D6FS_DISK" -maxdepth 1 -type f -name 'dsk*.dsk' -exec cksum '{}' ';' > "$work/source-before.cksum"
i=1
cut_count=0
finished=0
while test "$i" -le "$D6FS_CUT_MAX"; do
    clone="$work/cut-$i"
    mkdir -p "$clone"
    for f in "$D6FS_DISK"/dsk*.dsk; do
        test -f "$f"
        cp --reflink=auto "$f" "$clone/"
    done
    status=0
    D6FSCK_TEST_ABORT_WRITE="$i" "$work/d6fsck-fault" -r -n "$D6FS_MEMBERS" -d "$clone" > "$clone/interrupted.log" 2>&1 || status=$?
    case "$status" in
        99) cut_count=$((cut_count + 1)) ;;
        0) finished=1 ;;
        *) echo "FAIL cut $i: unexpected exit $status" >&2; exit 1 ;;
    esac
    "$work/d6fsck-clean" -r -n "$D6FS_MEMBERS" -d "$clone" > "$clone/resume.log" 2>&1 || {
        echo "FAIL cut $i: recovery did not complete" >&2; tail -20 "$clone/resume.log" >&2; exit 1;
    }
    "$work/d6fsck-clean" -n "$D6FS_MEMBERS" -d "$clone" > "$clone/verify.log" 2>&1 || {
        echo "FAIL cut $i: recovered volume is not clean" >&2; tail -20 "$clone/verify.log" >&2; exit 1;
    }
    grep -F 'FCBs: clean' "$clone/verify.log" >/dev/null
    "$work/d6fsck-clean" -r -n "$D6FS_MEMBERS" -d "$clone" > "$clone/idempotent.log" 2>&1
    if grep -E 'reclaimed orphan|deterministic repairs written|repaired superblock' "$clone/idempotent.log" >/dev/null; then
        echo "FAIL cut $i: repeated repair modified volume" >&2; exit 1
    fi
    if test $((i % 8)) -eq 0; then
        printf 'PASS: %s durable-write interruption cuts recovered\n' "$cut_count"
    fi
    if test "$finished" -eq 1; then
        break
    fi
    i=$((i + 1))
done
if test "$finished" -ne 1 || test "$cut_count" -lt 1; then
    echo 'FAIL: repair write count exceeded bound or none were exercised' >&2
    exit 1
fi
find "$D6FS_DISK" -maxdepth 1 -type f -name 'dsk*.dsk' -exec cksum '{}' ';' > "$work/source-after.cksum"
cmp "$work/source-before.cksum" "$work/source-after.cksum"
printf 'PASS: %s durable-write cuts; repair restart clean and idempotent; source unchanged\n' "$cut_count"
printf 'ARTIFACTS=%s\n' "$work"
