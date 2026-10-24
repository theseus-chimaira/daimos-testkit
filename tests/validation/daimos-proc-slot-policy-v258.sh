#!/bin/sh
# Check the production C policy at every supported 8K boundary.
set -eu
: "${DAIMOS_REPO:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-proc-slots-v258.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/policy.c" <<'C'
#include <assert.h>
#include <stdio.h>
#define PROC_MIN_SLOTS 8U
#define kword_t unsigned long
C
sed -n '/^unsigned int$/,/^}/p' "$DAIMOS_REPO/system/kernel/proc/proc_boot.c" | head -n 10 >> "$work/policy.c"
cat >> "$work/policy.c" <<'C'
int main(void)
{
    unsigned int k;
    assert(proc_slots_for_core(0UL) == 8U);
    for (k = 32U; k <= 256U; k += 8U) {
        assert(proc_slots_for_core((unsigned long)k * 1024UL) == k / 4U);
        if (k < 256U)
            assert(proc_slots_for_core(((unsigned long)k + 7UL) * 1024UL)
                == k / 4U);
    }
    assert(proc_slots_for_core(512UL * 1024UL) == 64U);
    puts("daimos-proc-slot-policy-v258: PASS (8K steps, bounds, cap)");
    return 0;
}
C
${CC:-cc} -std=c99 -Wall -Wextra -Werror "$work/policy.c" -o "$work/policy"
"$work/policy"
