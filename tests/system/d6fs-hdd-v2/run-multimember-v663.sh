#!/bin/sh
# Reproducible native-host launcher for the v582 PDP-6 multi-member suite.
# Relay binaries from an earlier host architecture must not be reused.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-multimember-v663.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -o "$work/pty-run-v663" \
    "$testkit_root/tools/pty-run-v1.c"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -o "$work/tcp-run-v663" \
    "$testkit_root/tools/tcp-run-v1.c"
export PTY_RUN="$work/pty-run-v663"
export TCP_RUN="$work/tcp-run-v663"

sh "$script_dir/run-multimember-v582.sh"
echo 'daimos-d6fs-hdd-multimember-v663: PASS'
