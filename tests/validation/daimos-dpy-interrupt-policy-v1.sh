#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"

tag=daimos-dpy-interrupt-policy-v1
dpy_h="$DAIMOS_REPO/system/kernel/drivers/dpy.h"
clk_h="$DAIMOS_REPO/system/kernel/drivers/clk.h"
dpy_s="$DAIMOS_REPO/system/kernel/drivers/dpy_io.s"
clk_s="$DAIMOS_REPO/system/kernel/drivers/clk_io.s"
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

grep -q '^dpy_pi_handler:$' "$dpy_s" ||
        fail 'dedicated PI7 DPY DONE pre-handler missing'
grep -q '^dpy_clock_handler:$' "$dpy_s" ||
        fail 'stackless DPY post-clock hook missing'
grep -q '^clk_pi_post_handler:$' "$clk_s" ||
        fail 'CLK post-service patch point missing'
grep -q '^ dpy_clk_tick_load:$' "$dpy_s" ||
        fail 'DPY resident clock-tick load patch point missing'

# Type 344 accepts display words through DATAO.  BLKO on device 0130 is not
# the supported display transport and previously blacked the retained screen.
if grep -Eq '^[[:space:]]*blko[[:space:]]+0130,' "$dpy_s"; then
        fail 'DPY incorrectly uses BLKO instead of interrupt-driven DATAO'
fi
grep -Eq '^[[:space:]]*datao[[:space:]]+0130,' "$dpy_s" ||
        fail 'DPY DATAO refresh feeder missing'

# The post-clock hook must remain stackless: it can run while KINIT owns an
# executive stack which is not safe for an extra PUSHJ frame.
clock_body=`sed -n '/^dpy_clock_handler:/,/^\/\*\* Start one asynchronous replay/p' "$dpy_s"`
printf '%s\n' "$clock_body" | grep -Eq '^[[:space:]]*pushj[[:space:]]' &&
        fail 'DPY post-clock hook unexpectedly uses PUSHJ'

dpy_minit=`awk '
        /^dpy_minit\(void\)/ { in_fn=1 }
        in_fn { print }
        in_fn && /^}$/ { exit }
' "$minit_c"`

printf '%s\n' "$dpy_minit" | grep -q 'minit_diag_nodev(name);' ||
        fail 'DPY no-device probe path missing'
printf '%s\n' "$dpy_minit" | grep -q 'base = minit_install(name);' ||
        fail 'DPY MRES install missing'
printf '%s\n' "$dpy_minit" | grep -q 'pdp10_pi_level7_span_load =' ||
        fail 'DPY PI7 pre-handler patch missing'
printf '%s\n' "$dpy_minit" | grep -q 'clk_pi_post_handler_addr' ||
        fail 'DPY does not patch the CLK post-service hook'
printf '%s\n' "$dpy_minit" | grep -q 'DPY_X_CLK_TICK_LOAD' ||
        fail 'DPY clock-tick source patch missing'

nodev_line=`printf '%s\n' "$dpy_minit" | grep -n 'minit_diag_nodev(name);' | head -1 | cut -d: -f1`
install_line=`printf '%s\n' "$dpy_minit" | grep -n 'base = minit_install(name);' | head -1 | cut -d: -f1`
pi7_line=`printf '%s\n' "$dpy_minit" | grep -n 'pdp10_pi_level7_span_load =' | head -1 | cut -d: -f1`
clock_line=`printf '%s\n' "$dpy_minit" | grep -n 'clk_pi_post_handler_addr' | tail -1 | cut -d: -f1`

test -n "$nodev_line" && test -n "$install_line" && test -n "$pi7_line" && test -n "$clock_line" ||
        fail 'cannot locate DPY interrupt-install sequence'
test "$nodev_line" -lt "$install_line" ||
        fail 'DPY MRES can be installed before the no-device return'
test "$install_line" -lt "$pi7_line" ||
        fail 'PI7 path can be patched before DPY MRES installation'
test "$install_line" -lt "$clock_line" ||
        fail 'clock hook can be patched before DPY MRES installation'

# DPY deliberately bypasses the generic finite handler table at PI7.  No-DPY
# systems retain the original span-load instruction and CLK post-service JRST.
if printf '%s\n' "$dpy_minit" | grep -Eq 'module_pi_register\([^,]*DPY_NATIVE_PI_LEVEL'; then
        fail 'DPY unexpectedly consumes a generic resident PI-handler slot'
fi
printf '%s\n' "$dpy_minit" | grep -q 'minit_pi_enable(DPY_NATIVE_PI_LEVEL);' ||
        fail 'DPY PI7 is not enabled after installing the pre-handler'

printf '%s\n' \
    "$tag: PASS (CLK PI6 post-hook, DPY DONE PI7, DATAO refresh, stackless clock path)"
