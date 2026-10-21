#!/bin/sh
# PDP-6 SIMH console PC preservation regression.
# Terminal editing libraries may export a writable termcap symbol named PC.
# Reading the next interactive command must not overwrite the CPU's PC.
set -eu

: "${TMPDIR:=$HOME/tmp}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
export TMPDIR

simh=${SIMH_PDP6:-"$PDP10_PREFIX/bin/pdp6"}
work="$TMPDIR/daimos-simh-console-pc-v115-$$"
mkdir -p "$work"

cleanup()
{
    if [ "${DAIMOS_SIMH_PC_KEEP_WORK:-0}" != 1 ]; then
        rm -rf "$work"
    fi
}
trap cleanup EXIT HUP INT TERM

if [ ! -x "$simh" ]; then
    echo "daimos-simh-console-pc-v115: simulator not executable: $simh" >&2
    exit 2
fi

# The first case tests the console without executing any instructions.
# An unexpected PC change cannot be attributed to CPU emulation.
cat > "$work/pc.ini" <<'EOF'
set cpu 256k
deposit PC 123
examine PC
EOF

printf 'examine PC\nexit\n' | "$simh" "$work/pc.ini" > "$work/pc.log" 2>&1 || {
    cat "$work/pc.log" >&2
    exit 1
}

if ! awk '
    /^PC:/ {
        value = $0
        sub(/^PC:[[:space:]]*/, "", value)
        if (value != "000123") bad = 1
        count++
    }
    END { if (count != 2 || bad) exit 1 }
' "$work/pc.log"; then
    echo 'daimos-simh-console-pc-v115: PC changed while reading interactive input' >&2
    cat "$work/pc.log" >&2
    exit 1
fi

# The second case executes a real PDP-6 guest, stops on a breakpoint,
# reads PC interactively, then steps. Each value has its own oracle.
cat > "$work/guest.ini" <<'EOF'
set cpu 256k
deposit -m 100 MOVEI 1,0
deposit -m 101 ADDI 1,1
deposit -m 102 JRST 101
break 102
go 100
examine PC
EOF

printf 'examine PC\nstep 1\nexamine PC\nexit\n' | \
    "$simh" "$work/guest.ini" > "$work/guest.log" 2>&1 || {
    cat "$work/guest.log" >&2
    exit 1
}

if ! awk '
    /^PC:/ {
        value = $0
        sub(/^PC:[[:space:]]*/, "", value)
        count++
        if ((count <= 2 && value != "000102") ||
            (count == 3 && value != "000101")) bad = 1
    }
    /Breakpoint, PC: 000102/ { breakpoint++ }
    /Step expired, PC: 000101/ { step++ }
    END { if (count != 3 || bad || breakpoint != 1 || step != 1) exit 1 }
' "$work/guest.log"; then
    echo 'daimos-simh-console-pc-v115: breakpoint/step PC state changed' >&2
    cat "$work/guest.log" >&2
    exit 1
fi

echo 'daimos-simh-console-pc-v115: PASS (startup, interactive, breakpoint, step)'
