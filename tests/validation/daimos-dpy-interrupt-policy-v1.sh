#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"

tag=daimos-dpy-interrupt-policy-v1
dpy_h="$DAIMOS_REPO/system/kernel/drivers/dpy.h"
clk_h="$DAIMOS_REPO/system/kernel/drivers/clk.h"
dpy_s="$DAIMOS_REPO/system/kernel/drivers/dpy_io.s"
clk_s="$DAIMOS_REPO/system/kernel/drivers/clk_io.s"
minit_c="$DAIMOS_REPO/system/kernel/modules/module_minit.c"
minit_s="$DAIMOS_REPO/system/kernel/modules/module_io.s"

fail()
{
        echo "$tag: $1" >&2
        exit 1
}

grep -Eq '^#define[[:space:]]+DPY_NATIVE_PI_LEVEL[[:space:]]+7U$' "$dpy_h" ||
        fail 'DPY data channel is not assigned to lowest-priority PI7'
grep -Eq '^#define[[:space:]]+CLK_NATIVE_PI_LEVEL[[:space:]]+6U$' "$clk_h" ||
        fail 'APR line clock is not assigned to PI6'
grep -Eq '^#define[[:space:]]+SLV_DPY_ALT_PI_LEVEL[[:space:]]+6U$' "$minit_c" ||
        fail 'SLV is not moved from DPY-owned PI7 to ordinary PI6 dispatch'

grep -q '^dpy_pi_handler:$' "$dpy_s" ||
        fail 'private PI7 DPY BLKO completion entry missing'
grep -A4 '^dpy_pi_handler:$' "$dpy_s" | grep -Eq '^[[:space:]]*\.word[[:space:]]+0' ||
        fail 'DPY completion entry has no private JSR save word'
grep -q '^dpy_pi_return:$' "$dpy_s" ||
        fail 'private DPY PI7 restore path missing'
grep -q '^dpy_clock_handler:$' "$dpy_s" ||
        fail 'stackless DPY post-clock hook missing'
grep -q '^clk_pi_post_handler:$' "$clk_s" ||
        fail 'CLK post-service patch point missing'
grep -q '^ dpy_clk_tick_load:$' "$dpy_s" ||
        fail 'DPY resident clock-tick load patch point missing'

# PDP-6 Type-340 data delivery follows the ITS data-channel model: BLKO is the
# even PI7 vector instruction and count overflow selects an odd-vector JSR to
# the private DPY completion entry.  It must not be hidden inside a normal
# handler or fall through the generic PI7 dispatcher.
grep -q '^minit_dpy_blko_template:$' "$minit_s" ||
        fail 'MINIT DPY BLKO vector template missing'
grep -A1 '^minit_dpy_blko_template:$' "$minit_s" |
        grep -Eq '^[[:space:]]*blko[[:space:]]+0130,0$' ||
        fail 'MINIT DPY vector is not BLKO device 0130'
if grep -Eq '^[[:space:]]*datao[[:space:]]+0130,' "$dpy_s"; then
        fail 'resident DPY feeder still contains software DATAO transport'
fi

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
printf '%s\n' "$dpy_minit" | grep -q 'DPY_X_REFRESH_IOWD' ||
        fail 'DPY BLKO IOWD export missing'
printf '%s\n' "$dpy_minit" | grep -q '000056.*minit_dpy_blko_template' ||
        fail 'PI7 even vector is not patched to BLKO template'
printf '%s\n' "$dpy_minit" | grep -q '000057.*0264000000000UL' ||
        fail 'PI7 odd vector is not patched to direct JSR completion'
printf '%s\n' "$dpy_minit" | grep -q 'clk_pi_post_handler_addr' ||
        fail 'DPY does not patch the CLK post-service hook'
printf '%s\n' "$dpy_minit" | grep -q 'DPY_X_CLK_TICK_LOAD' ||
        fail 'DPY clock-tick source patch missing'
printf '%s\n' "$dpy_minit" | grep -q 'minit_pi_enable(DPY_NATIVE_PI_LEVEL);' ||
        fail 'DPY PI7 is not enabled after vector installation'

# DPY owns PI7 as a hardware channel, not as a generic handler-table member.
if printf '%s\n' "$dpy_minit" | grep -Eq 'module_pi_register\([^,]*DPY_NATIVE_PI_LEVEL'; then
        fail 'DPY unexpectedly consumes a generic resident PI-handler slot'
fi

printf '%s\n' \
    "$tag: PASS (CLK PI6, Type-340 BLKO PI7, direct overflow completion, stackless clock path)"
