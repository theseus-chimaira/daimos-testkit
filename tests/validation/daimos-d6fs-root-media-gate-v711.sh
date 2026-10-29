#!/bin/sh
# Refuse reused/dirty D6FS media before interpreting a startup ?RT as a kernel regression.
set -eu
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
if [ "$#" -ne 2 ]; then
  echo "usage: $0 boot-directory clean|dirty" >&2
  exit 2
fi
boot=$1
expected=$2
case $expected in clean|dirty) ;; *) exit 2 ;; esac
test -d "$boot/disk"
work=$(mktemp "$TMPDIR/daimos-d6fs-media-v711.XXXXXX")
trap 'rm -f "$work"' EXIT HUP INT TERM
if "$PDP10_PREFIX/bin/d6fsck" -n 4 -d "$boot/disk" >"$work" 2>&1; then
  if grep -q 'state=CLEAN' "$work"; then actual=clean; else actual=invalid; fi
else
  if grep -q 'DIRTY' "$work"; then actual=dirty; else actual=invalid; fi
fi
if [ "$actual" != "$expected" ]; then
  cat "$work" >&2
  echo "v711: expected $expected, got $actual" >&2
  exit 1
fi
echo "v711: D6FS preflight correctly classified $actual media PASS"
