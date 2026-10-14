#!/bin/sh
# Require a complete interactive disk-root boot after MM/MRES placement.
# The INIT banner alone is not acceptance: reject simulator HALT explicitly.
set -eu
log=${1:?usage: check-mm-boot-v135.sh simulator.log}
clean=${TMPDIR:-$HOME/tmp}/mm-v135-boot-check-$$.txt
trap 'rm -f "$clean"' EXIT HUP INT TERM
tr -d '\r' < "$log" > "$clean"
for milestone in 'DAIMON' 'D6FS' 'INIT V1' 'LOGIN: '; do
    if ! grep -F "$milestone" "$clean" >/dev/null; then
        printf 'FAIL: boot did not reach %s\n' "$milestone" >&2
        exit 1
    fi
done
if grep -E 'HALT instruction|\?RT|INIT: NO INITTAB' "$clean" >/dev/null; then
    printf 'FAIL: boot transcript contains a halt or INIT failure\n' >&2
    exit 1
fi
echo 'PASS: PDP-6 MM/MRES boot reached LOGIN without a halt'
