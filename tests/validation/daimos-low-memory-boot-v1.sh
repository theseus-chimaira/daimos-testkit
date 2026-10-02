#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-low-memory-boot-v1
work="$TMPDIR/$tag-$$"

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$work"

run_one()
{
        mem=$1
        run="$work/$mem"
        build="$run/build"
        out="$run/simh.out"
        clean="$run/simh.clean"
        ini="$run/boot.ini"
        boot="$build/system/boot/pdp6"

        mkdir -p "$run"
        PATH="$PDP10_PREFIX/bin:$PATH" \
            "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
            BUILD_ROOT="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null

        # The final INIT transition must not consume permanent KCORE.  KINIT
        # keeps only a small protected text hole while loading INIT, then
        # publishes that hole itself immediately before entering user mode.
        if grep -Eq '^(kcore_boot_start|kcore_boot_handoff)[[:space:]]' \
            "$boot/kcore.map"; then
                echo "low-memory-boot: permanent boot-transition code returned to KCORE" >&2
                exit 1
        fi
        # Disk boot mounts D6FS directly as the namespace root.  The obsolete
        # empty initfs/bootstrap-MEMFS image and root-rebind path must not
        # return, because they consumed scarce 32K bootstrap memory.
        if grep -Eq '^(__initfs_begin|kfs_boot_rebind_root)[[:space:]]' \
            "$boot/kinit.map"; then
                echo "low-memory-boot: bootstrap initfs/MEMFS root returned" >&2
                exit 1
        fi
        late_begin=$(awk '$1 == "__kinit_late_begin" { print $2; exit }' \
            "$boot/kinit.map")
        late_end=$(awk '$1 == "__kinit_late_end" { print $2; exit }' \
            "$boot/kinit.map")
        image_end=$(awk '$1 == "__kinit_image_end" { print $2; exit }' \
            "$boot/kinit.map")
        case "$late_begin:$late_end:$image_end" in
        *[!0-7:]*|'')
                echo "low-memory-boot: KINIT self-reclaim markers missing" >&2
                exit 1
                ;;
        esac
        if [ "$((0$late_begin))" -ge "$((0$late_end))" ] || \
            [ "$((0$late_end))" -ge "$((0$image_end))" ]; then
                echo "low-memory-boot: invalid KINIT self-reclaim marker order" >&2
                exit 1
        fi
        for sym in mm_boot_init mm_add_free mm_largest_free mm_alloc; do
                addr=$(awk -v sym="$sym" '$1 == sym { print $2; exit }' \
                    "$boot/kinit.map")
                case "$addr" in
                ''|*[!0-7]*)
                        echo "low-memory-boot: $sym missing from late KINIT" >&2
                        exit 1
                        ;;
                esac
                if [ "$((0$addr))" -lt "$((0$late_begin))" ] || \
                    [ "$((0$addr))" -ge "$((0$late_end))" ]; then
                        echo "low-memory-boot: $sym escaped late KINIT" >&2
                        exit 1
                fi
                if grep -Eq "^${sym}[[:space:]]" "$boot/kcore.map"; then
                        echo "low-memory-boot: $sym returned to permanent KCORE" >&2
                        exit 1
                fi
        done

        # Runtime RUN loads a new executable and records its swap backing after
        # late KINIT has been reclaimed.  Those helpers must therefore remain
        # in KCORE rather than being classified as boot-only construction.
        for sym in exec_load_process proc_swap_attach; do
                if ! grep -Eq "^${sym}[[:space:]]" "$boot/kcore.map"; then
                        echo "low-memory-boot: $sym missing from permanent KCORE" >&2
                        exit 1
                fi
        done

        # Each run needs a freshly built filesystem: normal boot marks D6FS
        # active/dirty, so sharing one disk would turn this into a recovery test.
        sed -e "s/^set cpu [0-9][0-9]*k$/set cpu ${mem}k/" \
            -e '/^go 020$/,$d' "$boot/boot.ini" >"$ini"
        grep -Eq '^_start[[:space:]]+000020$' \
            "$boot/userland-build/userland/dsh.map" || {
                echo "low-memory-boot: user image is not linked at logical 020" >&2
                exit 1
        }

        cat >>"$ini" <<'SIMH_EOF'
expect "# "
go 020
examine RL
examine PL
send "MEMSTAT\r"
expect "# "
go
send "EXIT\r"
go
exit
SIMH_EOF

        set +e
        (
                cd "$boot"
                TERM=dumb timeout -k 2s 20s stdbuf -o0 -e0 \
                    "$PDP10_PREFIX/bin/pdp6" "$ini"
        ) >"$out" 2>&1
        rc=$?
        set -e
        if [ "$rc" -ne 0 ]; then
                cat "$out" >&2
                echo "low-memory-boot: ${mem}K simulator failed: $rc" >&2
                exit 1
        fi

        tr -d '\r' <"$out" >"$clean"

        grep -Eq "^MEM[[:space:]]+${mem} K" "$clean" || {
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K probe result missing" >&2
                exit 1
        }
        grep -q '^DSH V1' "$clean" || {
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K boot did not reach DSH" >&2
                exit 1
        }
        grep -q '^MEMSTAT$' "$clean" || {
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K MEMSTAT command missing" >&2
                exit 1
        }
        grep -q '^RESIDENT [0-9][0-9]*$' "$clean" || {
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K MEMSTAT did not return" >&2
                exit 1
        }
        grep -Eq '^PROCESS-WORDS [1-9][0-9]*$' "$clean" || {
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K MEMSTAT lost resident process accounting" >&2
                exit 1
        }
        grep -Eq '^PROC-SLOTS [1-9][0-9]*$' "$clean" || {
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K MEMSTAT lost process-slot accounting" >&2
                exit 1
        }
        grep -q '^PROC-SLOTS-MAX [0-9][0-9]*$' "$clean" || {
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K MEMSTAT process-slot result missing" >&2
                exit 1
        }
        memfs_capacity=$(awk '/^MEMFS-CAPACITY / { print $2; exit }' "$clean")
        case "$memfs_capacity" in
        ''|*[!0-9]*)
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K MEMFS capacity result missing" >&2
                exit 1
                ;;
        esac
        rl=$(awk '{ for (i = 1; i <= NF; ++i) if ($i == "RL:") { print $(i + 1); exit } }' "$clean")
        pl=$(awk '{ for (i = 1; i <= NF; ++i) if ($i == "PL:") { print $(i + 1); exit } }' "$clean")
        case "$rl" in
        *000) ;;
        *)
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K relocation register is not aligned" >&2
                exit 1
                ;;
        esac
        case "$pl" in
        *1777) ;;
        *)
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K protection limit is invalid" >&2
                exit 1
                ;;
        esac
        if grep -q 'MNTERR' "$clean"; then
                cat "$clean" >&2
                echo "low-memory-boot: ${mem}K boot reported MNTERR" >&2
                exit 1
        fi
}

run_one 32
run_one 64
run_one 96
run_one 256

printf '%s\n' 'low-memory-boot: PASS (MEMFS accounting, protected user entry, syscalls, and exit)'
