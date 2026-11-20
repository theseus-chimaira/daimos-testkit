#!/bin/sh
# K02 final ownership/cleanup acceptance against the live DAIMOS checkout.
# No production source is patched by this driver. Physical gates build
# disposable 256K PDP-6 kernels with test-only faults.
#
# Usage: sh daimos-k02-final-accept-v1730.sh [native|physical|all]
set -eu
: "$DAIMOS_REPO" "$PDP10_PREFIX"
TMPDIR=$(printenv TMPDIR || printf '%s' "$HOME/tmp")
export TMPDIR
mkdir -p "$TMPDIR"
group=all
if [ $# -gt 0 ]; then group=$1; fi
case "$group" in
native|physical|all) ;;
*) echo "usage: $0 [native|physical|all]" >&2; exit 2 ;;
esac

self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-k02-final-accept-v1730.XXXXXX")
result="$work/results"
: > "$result"
printf 'DAIMOS_HEAD %s\n' \
    "$(git -C "$DAIMOS_REPO" rev-parse HEAD)" >> "$result"
printf 'TESTKIT_HEAD %s\n' \
    "$(git -C "$self/../.." rev-parse HEAD)" >> "$result"
printf 'GROUP %s\n' "$group" >> "$result"
printf 'v1730: result directory %s\n' "$work"

# Fail closed: do not infer success from a simulator HALT or a grep.
# Each versioned guest is responsible for its full strict verifier.
run_gate()
{
    mode=$1
    name=$2
    file="$self/$name.sh"
    if [ ! -f "$file" ]; then
        printf 'MISSING %s %s\n' "$mode" "$name" >> "$result"
        echo "v1730: missing test: $file" >&2
        exit 1
    fi
    printf 'v1730: %s %s\n' "$mode" "$name"
    if sh "$file" > "$work/$name.log" 2>&1; then
        printf 'PASS %s %s\n' "$mode" "$name" >> "$result"
        tail -3 "$work/$name.log"
    else
        code=$?
        printf 'FAIL %s %s %s\n' "$mode" "$name" "$code" >> "$result"
        tail -70 "$work/$name.log" >&2
        echo "v1730: failed: $name (exit $code)" >&2
        echo "v1730: retained logs: $work" >&2
        exit "$code"
    fi
}

if [ "$group" = native ] || [ "$group" = all ]; then
    for name in \
        daimos-k02-exec-stage-owner-v1719 \
        daimos-k02-exec-lowmem-owner-v1720 \
        daimos-k02-run-pipe-lifetime-v1722 \
        daimos-run-discard-reaper-v892 \
        daimos-k02-permanent-session-v1728 \
        daimos-fatal-owner-hup-v970 \
        daimos-pipe-typed-close-v1099 \
        daimos-reaper-backoff-v1102 \
        daimos-session-hup-repeated-failure-v922
    do
        run_gate NATIVE "$name"
    done
fi

if [ "$group" = physical ] || [ "$group" = all ]; then
    # Four distinct physical owner-boundary gates:
    # 1721: PROCESS MM freed before backing-detach refusal.
    # 1726: concurrent RUN children own PIPE and D6FS.
    # 1729: permanent D6FS, session HUP and fatal EXEC.
    # 900: named FIFO MM_BUSY and retry/reopen.
    for name in \
        daimos-k02-postfree-detach-v1721 \
        daimos-k02-concurrent-owners-v1726 \
        daimos-k02-session-exec-v1729 \
        daimos-fifo-pinned-final-v900
    do
        run_gate PHYSICAL "$name"
    done
fi

printf 'PASS v1730 %s\n' "$group" >> "$result"
echo "v1730: ALL $group gates PASS"
echo "v1730: preserved result manifest and individual logs: $work"
