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
    daimos-reaper-sidl-runq-v1107 \
    daimos-tty-prevm-finalize-v1081 \
    daimos-discard-tty-prevm-v1085 \
    daimos-tty-mm-error-stage-v1093 \
    daimos-xip-release-stage-v1094 \
    daimos-xip-physical-retry-v1108 \
    daimos-xip-vm-retry-v1109; do
    echo "v1096: stage $name"
    sh "$self/$name.sh"
done

# The older direct-scope audit follows the checked TTY release now;
# transitive teardown must still allocate no new MM or backing blocks.
python3 "$self/daimos-fatal-release-scope-v1083.py"
python3 "$self/daimos-oom-transitive-release-v1087.py"

if [ "${P0D_FULL:-0}" = 1 ]; then
    echo 'v1125: physical MM wrong owner plus held foreign FS provider'
    sh "$self/daimos-fatal-mm-provider-v1125.sh"
    echo 'v1124: booted physical TTY/HUP, VM and post-VM u-area MM_BUSY'
    sh "$self/daimos-tty-vm-uarea-v1124.sh"
    echo 'v1096: booted pre-VM owner retry and committed finalization'
    sh "$self/daimos-oom-pre-vm-retry-v997.sh"
    echo 'v1103: booted combined PIPE/FILE/HUP/VM/u-area owner stages'
    sh "$self/daimos-oom-multistage-v1103.sh"
    echo 'v1117: mixed fatal stages plus stale WAIT/PID/event and bystander'
    sh "$self/daimos-oom-wait-churn-v1117.sh"
    echo 'v1118: real PIPE and VM MM_BUSY in one faulted process plus WAIT/PID'
    sh "$self/daimos-oom-physical-mixed-v1118.sh"
    echo 'v1104: booted physical member HUP and pinned PIPE final close'
    sh "$self/daimos-session-hup-pipe-mm-v1104.sh"
    echo 'v1105: booted physical member HUP and pinned DPY raw-list close'
    sh "$self/daimos-session-hup-dpy-mm-v1105.sh"
    echo 'v1119: booted physical PIPE plus Type-340 DPY final HUP close'
    sh "$self/daimos-session-hup-pipe-dpy-v1119.sh"
    echo 'v1121: booted Type-340 DPY MM_BUSY across DISK swap-out/restore'
    sh "$self/daimos-session-hup-dpy-swap-v1121.sh"
    echo 'v1122: first-member PIPE MM_BUSY then second-member DISK bitmap refusal'
    sh "$self/daimos-session-hup-pipe-swap-v1122.sh"
    echo 'v1120: booted actual numeric PID reuse after physical OOM, disabled'
    V1120_OOM_ENABLED=0 sh "$self/daimos-oom-pid-reuse-v1120.sh"
    echo 'v1120: booted actual numeric PID reuse after physical OOM, enabled'
    V1120_OOM_ENABLED=1 sh "$self/daimos-oom-pid-reuse-v1120.sh"
    echo 'v1106: booted real process-VM MM_BUSY plus FILE, uarea and FS lease'
    sh "$self/daimos-oom-physical-vm-v1106.sh"
    echo 'v1107: booted real DISK swap bitmap rejection and deferred release'
    sh "$self/daimos-session-hup-swap-v1107.sh"
    echo 'v1096: booted real OOM with D6FS SYNC and MM_BUSY refusals'
    sh "$self/daimos-oom-requester-provider-mm-v1077.sh"
    echo 'v1101: booted permanent MM wrong-owner quarantine and bystander'
    sh "$self/daimos-fatal-mm-wrong-owner-v1101.sh"
else
    echo 'v1096: disposable full guest matrix skipped (set P0D_FULL=1)'
fi

echo 'v1096: P0-D component release-stage matrix PASS'
