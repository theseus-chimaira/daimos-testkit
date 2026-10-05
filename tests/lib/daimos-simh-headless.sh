#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
        echo "usage: $0 INPUT.ini OUTPUT.ini DCS_PORT GE_PORT" >&2
        exit 2
fi

in=$1
out=$2
dcs_port=$3
ge_port=$4

# Ordinary kernel/userland regressions must not initialize SIMH's host-video
# backends.  In particular WCNSLS CSCOPE starts vid-thread, which can block in
# the host DRM driver during teardown.  DPY windowing is also unnecessary here.
# Dedicated DPY/WCNSLS tests use the unmodified graphical configuration.
awk -v dcs="$dcs_port" -v ge="$ge_port" '
/^set dpy / {
        if (!dpy_done) {
                print "set dpy disable"
                dpy_done = 1
        }
        next
}
/^set wcnsls / {
        if (!wc_done) {
                print "set wcnsls disable"
                wc_done = 1
        }
        next
}
/^set ocnsls / {
        if (!oc_done) {
                print "set ocnsls disable"
                oc_done = 1
        }
        next
}
/^attach -q dcs0 / {
        print "attach -q dcs0 " dcs
        next
}
/^attach -q ge0 / {
        print "attach -q ge0 " ge
        next
}
{ print }
' "$in" > "$out"
