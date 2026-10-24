#!/bin/sh
# Run the real PDP-6 insertion/deletion assembler at minimum and maximum
# KINIT-selected capacities; no stub allocator or host ABI substitutions.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-capacity-v261.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
for pair in '030:060' '0210:0420'; do
    cap=${pair%%:*}
    words=${pair#*:}
    previous=$(printf '%o' "$((0$cap - 1))")
    sed -e "s/caige 010,040/caige 010,$cap/" \
        -e "s/caie 3,040/caie 3,$cap/g" \
        -e "s/movei 1,040/movei 1,$cap/" \
        -e "s/caie 3,037/caie 3,$previous/" \
        -e "s/movei 1,037/movei 1,$previous/" \
        -e "s/\.block 0100/.block $words/" \
        "$self/daimos-mm-extents-v249.s" > "$work/capacity.s"
    printf '%s\n' '.text' '.globl mm_delete' '.globl mm_extent_insert' > "$work/mm-leaves.s"
    sed -n '/^mm_delete:/,/^; AC1=base\. Return/p' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" | sed '$d' >> "$work/mm-leaves.s"
    printf '%s\n' '.data' '.globl mm_extent_capacity' "mm_extent_capacity: .word $cap" >> "$work/mm-leaves.s"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode step \
        --start 1000 --step-limit 250000 --timeout 25 \
        --workdir "$work/run-$cap" --name "mm-capacity-v261-$cap" \
        --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
        "$work/capacity.s" "$work/mm-leaves.s" >/dev/null
    printf 'mm-capacity-v261: PASS cap=%s octal\n' "$cap"
done
