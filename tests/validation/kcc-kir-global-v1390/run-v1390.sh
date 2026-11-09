#!/bin/sh
# Strict KIR1/KGEN compiler gate. Retain evidence on every failure.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS tree}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
here="$testkit/tests/validation/kcc-kir-global-v1390"
base="$TMPDIR/kcc-native-refresh-v1373"
work=${V1390_WORK:-$TMPDIR/kcc-kir-global-v1390}

test -s "$base/boot-v1373.simh"
test -x "$TMPDIR/d6codec-fullboot-v1370/pty-run-v1370"
if [ -e "$work" ]; then
    echo "v1390: refusing to overwrite $work" >&2
    exit 2
fi
mkdir -p "$work"

set +e
PDP10_PREFIX="$PDP10_PREFIX" \
  sh "$testkit/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" \
    --dofile "$base/boot-v1373.simh" \
    --pty-run "$TMPDIR/d6codec-fullboot-v1370/pty-run-v1370" \
    --login ROOT --probes "$here/probes-v1390.txt" --isolate-media \
    --work-dir "$work/run" --markdown-report "$work/report-v1390.md" \
    --boot-timeout 115 --timeout 240 > "$work/guest-v1390.log" 2>&1
rc=$?
set -e
printf '%s\n' "v1390: harness exit $rc, evidence $work"
if [ -f "$work/run/results.tsv" ]; then
    cat "$work/run/results.tsv"
fi
exit "$rc"
