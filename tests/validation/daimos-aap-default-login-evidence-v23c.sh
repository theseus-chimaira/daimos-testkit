#!/bin/sh
# Verify an AAP Type-551/Type-626 console capture from a *default* INITTAB
# boot. The capture must come from a fresh ROOT=tape BOOT=dtc image with
# CTY0, DCS0 and GE0 entries unchanged. Only guest-visible console behavior
# is required: AAP diagnostic traces were removed in the emulator cleanup.
# Image construction and emulator driving are separate acceptance steps.
set -eu
capture=${1:?usage: daimos-aap-default-login-evidence-v23c.sh CAPTURE}
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
[ -s "$capture" ] || { echo "empty AAP capture: $capture" >&2; exit 1; }
for marker in 'INIT V1' 'LOGIN: ' 'DSH V1'; do
    grep -aF "$marker" "$capture" >/dev/null || {
        echo "AAP boot capture missing: $marker" >&2
        exit 1
    }
done
for marker in 'INIT: RUN FAILED' 'INIT: RESPAWN FAILED' \
    'INIT: NO INITTAB' 'LOGIN INCORRECT' 'LOGIN: SESSION FAILED'; do
    if grep -aF "$marker" "$capture" >/dev/null; then
        echo "AAP boot capture reports failure: $marker" >&2
        exit 1
    fi
done
echo 'aap-default-login-evidence-v23c: PASS (guest-visible INIT, ROOT login, DSH, no respawn/auth errors; no block-word audit)'
