#!/bin/sh
# P0-D ownership stages: reuse executable source-linked PDP-6 test leaves.
# P0D_FULL=1 adds disposable 256K guest fault-injection regressions.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

for name in \
    daimos-pipe-close-v870 \
    daimos-pipe-typed-close-v1099 \
    daimos-dpy-replace-v874 \
    daimos-dpy-typed-replace-v1100 \
    daimos-swap-detach-v880 \
    daimos-swap-detach-state-v880 \
    daimos-session-hup-pending-v905 \
    daimos-uarea-typed-release-v1097 \
    daimos-prevm-retry-clock-v1098 \
    daimos-reaper-backoff-v1102 \
    daimos-tty-prevm-finalize-v1081 \
    daimos-discard-tty-prevm-v1085 \
    daimos-tty-mm-error-stage-v1093 \
    daimos-xip-release-stage-v1094; do
    echo "v1096: stage $name"
    sh "$self/$name.sh"
done

# The older direct-scope audit follows the checked TTY release now;
# transitive teardown must still allocate no new MM or backing blocks.
python3 "$self/daimos-fatal-release-scope-v1083.py"
python3 "$self/daimos-oom-transitive-release-v1087.py"

if [ "${P0D_FULL:-0}" = 1 ]; then
    echo 'v1096: booted pre-VM owner retry and committed finalization'
    sh "$self/daimos-oom-pre-vm-retry-v997.sh"
    echo 'v1103: booted combined PIPE/FILE/HUP/VM/u-area owner stages'
    sh "$self/daimos-oom-multistage-v1103.sh"
    echo 'v1096: booted real OOM with D6FS SYNC and MM_BUSY refusals'
    sh "$self/daimos-oom-requester-provider-mm-v1077.sh"
    echo 'v1101: booted permanent MM wrong-owner quarantine and bystander'
    sh "$self/daimos-fatal-mm-wrong-owner-v1101.sh"
else
    echo 'v1096: disposable full guest matrix skipped (set P0D_FULL=1)'
fi

echo 'v1096: P0-D component release-stage matrix PASS'
