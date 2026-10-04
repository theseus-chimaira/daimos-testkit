#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"

tag=daimos-dpy-interrupt-policy-v1
dpy_h="$DAIMOS_REPO/system/kernel/drivers/dpy.h"
clk_h="$DAIMOS_REPO/system/kernel/drivers/clk.h"
dpy_s="$DAIMOS_REPO/system/kernel/drivers/dpy_io.s"
minit_c="$DAIMOS_REPO/system/kernel/modules/module_minit.c"

fail()
{
        echo "$tag: $1" >&2
        exit 1
}

grep -Eq '^#define[[:space:]]+DPY_NATIVE_PI_LEVEL[[:space:]]+7U$' "$dpy_h" ||
        fail 'DPY DATA/DONE is not assigned to lowest-priority PI7'
grep -Eq '^#define[[:space:]]+CLK_NATIVE_PI_LEVEL[[:space:]]+6U$' "$clk_h" ||
        fail 'APR line clock is not assigned to PI6'

# The Type 344 has no autonomous display-list timer.  Keep DONE on PI7, but
# retain the optional PI6 wrapper solely as the frame-start timebase.  It must
# live in the DPY MRES, never in unconditional CLK/KCORE code.
grep -q '^dpy_pi_handler:$' "$dpy_s" ||
        fail 'dedicated PI7 DPY DONE handler missing'
grep -q '^dpy_clock_handler:$' "$dpy_s" ||
        fail 'optional DPY clock wrapper missing'
grep -q '^dpy_clk_pi_service_call:$' "$dpy_s" ||
        fail 'DPY clock wrapper no longer delegates to normal CLK service'

# The Type-344 interface accepts display words through DATAO.  Do not feed
# device 0130 with BLKO: the simulator (and documented interface behaviour)
# does not support that transport for the Type-340 display path.
if grep -Eq '^[[:space:]]*blko[[:space:]]+0130,' "$dpy_s"; then
        fail 'DPY incorrectly uses BLKO instead of interrupt-driven DATAO'
fi
grep -Eq '^[[:space:]]*datao[[:space:]]+0130,' "$dpy_s" ||
        fail 'DPY DATAO refresh feeder missing'

dpy_minit=`awk '
        /^dpy_minit\(void\)/ { in_fn=1 }
        in_fn { print }
        in_fn && /^}$/ { exit }
' "$minit_c"`

printf '%s\n' "$dpy_minit" | grep -q 'minit_diag_nodev(name);' ||
        fail 'DPY no-device probe path missing'
printf '%s\n' "$dpy_minit" | grep -q 'base = minit_install(name);' ||
        fail 'DPY MRES install missing'

nodev_line=`printf '%s\n' "$dpy_minit" | grep -n 'minit_diag_nodev(name);' | head -1 | cut -d: -f1`
install_line=`printf '%s\n' "$dpy_minit" | grep -n 'base = minit_install(name);' | head -1 | cut -d: -f1`
pi7_line=`printf '%s\n' "$dpy_minit" | grep -n 'pdp10_pi_level7_span_load =' | head -1 | cut -d: -f1`
clock_line=`printf '%s\n' "$dpy_minit" | grep -n 'module_pi_unregister(CLK_NATIVE_PI_LEVEL' | head -1 | cut -d: -f1`

test -n "$nodev_line" && test -n "$install_line" && test -n "$pi7_line" && test -n "$clock_line" ||
        fail 'cannot locate DPY interrupt-install sequence'
test "$nodev_line" -lt "$install_line" ||
        fail 'DPY MRES can be installed before the no-device return'
test "$install_line" -lt "$pi7_line" ||
        fail 'PI7 path can be patched before DPY MRES installation'
test "$install_line" -lt "$clock_line" ||
        fail 'CLK handler can be replaced before DPY MRES installation'

# DPY deliberately bypasses the generic eight-word handler table at PI7.  This
# avoids adding resident KCORE space merely to support an optional display.
if printf '%s\n' "$dpy_minit" | grep -Eq 'module_pi_register\([^,]*DPY_NATIVE_PI_LEVEL'; then
        fail 'DPY unexpectedly consumes a generic resident PI-handler slot'
fi
printf '%s\n' "$dpy_minit" | grep -q 'minit_pi_enable(DPY_NATIVE_PI_LEVEL);' ||
        fail 'DPY PI7 is not enabled after installing the pre-handler'

printf '%s\n' "$tag: PASS (CLK PI6, DPY DONE PI7, DATAO refresh, zero no-DPY interrupt-path changes)"
