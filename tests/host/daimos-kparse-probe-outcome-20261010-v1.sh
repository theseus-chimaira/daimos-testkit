#!/bin/sh
# Validate diagnostic rules against the retained native KCC failure transcript.
set -eu
: "${DAIMOS_REPO:?}"
probe="$(dirname "$0")/../validation/daimos-kparse-longrun-20261010-v3.sh"
log=${KPARSE_FAILURE_LOG:-$HOME/tmp/kparse-detached-20261010-v1/evidence/run/simh.log}
[ -f "$log" ] || { echo "missing original failure transcript: $log" >&2; exit 2; }
grep -F 'MAKE: RECIPE FAILED' "$log" >/dev/null
grep -E '^UUO[[:space:]]+[0-7]+' "$log" >/dev/null
for rule in 'not_contains MAKE: RECIPE FAILED' 'not_matches ^UUO[[:space:]]+[0-7]+'; do
    grep -F "$rule" "$probe" >/dev/null || exit 1
done
# An actual failure must match one of the assertions, independently of DSH returning.
if grep -F 'MAKE: RECIPE FAILED' "$log" >/dev/null || grep -E '^UUO[[:space:]]+[0-7]+' "$log" >/dev/null; then
    echo 'PASS: previously misclassified native KCC failure rejected by v3 rules'
else
    exit 1
fi
