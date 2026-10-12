#!/bin/sh
# Host-only 32K EXEC occupancy calculation. No target code is modified.
set -eu
data=${1:-tests/host/daimos-dsh-32k-occupancy-20261012-v14.txt}
test -r "$data"
set -- $(sed -n '/^LOMEM TOTAL /p' "$data")
test "$1" = LOMEM && test "$2" = TOTAL
total=$((0$3))
resident=$((0$5))
process=$((0$7))
memfs=$((0$9))
set -- $(sed -n '/^LOMEM PROC 01 /p' "$data")
test "$1" = LOMEM && test "$3" = 01
init=$((0$5))
set -- $(sed -n '/^LOMEM PROC 02 /p' "$data")
test "$1" = LOMEM && test "$3" = 02
login=$((0$5))
test "$total" -eq $((0100000))
test "$resident" -eq $((031152))
test "$process" -eq $((025020))
test "$init" -eq $((012000))
test "$login" -eq $((012000))
test "$memfs" -eq 0
available=$((total - resident - process + login - memfs))
max_aligned=$(( (available / 02000) * 02000 ))
printf 'After LOGIN extent release, INIT resident: %o free words; max initial 02000-aligned DSH extent %o\n' "$available" "$max_aligned"
test "$available" -eq $((033606))
test "$max_aligned" -eq $((032000))
test "$max_aligned" -lt $((044000))
printf '%s\n' 'PASS: 32K DSH 044000 cannot fit with INIT resident, even disregarding fragmentation'
