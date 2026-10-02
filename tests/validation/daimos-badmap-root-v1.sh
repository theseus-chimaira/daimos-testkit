#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-badmap-root-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
build_out="$work/build.out"
simh_out="$work/simh.out"
fsck_out="$work/d6fsck.out"
runtime_ini="$work/runtime.ini"
zero="$work/zero-sector"

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work"

PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" BUILD_ROOT="$build/daimos-build" \
    PDP10_PREFIX="$PDP10_PREFIX" D6FS_SPARE_BLOCKS=16 \
    >"$build_out" 2>&1 || {
        cat "$build_out" >&2
        echo "$tag: image build failed" >&2
        exit 1
    }

layout=`grep 'mkd6fs:' "$build_out" | tail -1`
set -- `printf '%s\n' "$layout" | \
    sed -n 's/.* super=\([0-7][0-7]*\)\/\([0-7][0-7]*\).*/\1 \2/p'`
if [ "$#" -ne 2 ]; then
        cat "$build_out" >&2
        echo "$tag: cannot derive D6FS superblock locations" >&2
        exit 1
fi
super_a=$1
super_b=$2
base=`"$PDP10_PREFIX/bin/d6swap" -n 1 -d "$build/disk" --show | \
    sed -n 's/.*d6fs-base=\([0-7][0-7]*\).*/\1/p' | head -1`
if [ -z "$base" ]; then
        echo "$tag: cannot derive physical D6FS base" >&2
        exit 1
fi
phys_a=$((0$base + 0$super_a))
phys_b=$((0$base + 0$super_b))
phys_a_o=`printf '%o' "$phys_a"`
phys_b_o=`printf '%o' "$phys_b"`

# d6bad accepts physical member sectors.  Copy both current superblock copies
# to spare sectors and publish the exception map before damaging originals.
"$PDP10_PREFIX/bin/d6bad" -n 1 -d "$build/disk" \
    --add "0:0$phys_a_o:2" >/dev/null
map_out=`"$PDP10_PREFIX/bin/d6bad" -n 1 -d "$build/disk" --list`
printf '%s\n' "$map_out" | grep -q "source=0:$phys_a_o spare=" || {
        printf '%s\n' "$map_out" >&2
        echo "$tag: first superblock remap missing" >&2
        exit 1
}
printf '%s\n' "$map_out" | grep -q "source=0:$phys_b_o spare=" || {
        printf '%s\n' "$map_out" >&2
        echo "$tag: second superblock remap missing" >&2
        exit 1
}

# The simulator DSK image stores one 128-word PDP-10 sector in 1024 bytes.
dd if=/dev/zero of="$zero" bs=1024 count=1 2>/dev/null
for sec in "$phys_a" "$phys_b"; do
        dd if=/dev/zero of="$build/disk/dsk0.dsk" bs=1024 seek="$sec" \
            count=1 conv=notrunc 2>/dev/null
        dd if="$build/disk/dsk0.dsk" bs=1024 skip="$sec" count=1 \
            2>/dev/null | cmp - "$zero" >/dev/null || {
                echo "$tag: failed to destroy original physical sector $sec" >&2
                exit 1
            }
done

"$PDP10_PREFIX/bin/d6fsck" -n 1 -d "$build/disk" >"$fsck_out" 2>&1 || {
        cat "$fsck_out" >&2
        echo "$tag: host D6FS read did not survive remapped superblocks" >&2
        exit 1
}
grep -q ': clean$' "$fsck_out" || {
        cat "$fsck_out" >&2
        echo "$tag: host D6FS is not clean through BADMAP" >&2
        exit 1
}

# Stop as soon as LOGIN proves the target loaded D6FS from the replacement
# sectors.  Neither destroyed source superblock contains a usable filesystem.
sed '/^go 020$/,$d' "$build/boot.ini" >"$runtime_ini"
cat >>"$runtime_ini" <<'EOF_SIMH'
expect "LOGIN:"
go 020
exit
EOF_SIMH

set +e
(
        cd "$build"
        TERM=dumb timeout -k 2s 20s stdbuf -o0 -e0 \
            "$PDP10_PREFIX/bin/pdp6" "$runtime_ini"
) >"$simh_out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$simh_out" >&2
        echo "$tag: simulator failed: $rc" >&2
        exit 1
fi
grep -Eq '^BADMAP[[:space:]]+LOADED' "$simh_out" || {
        cat "$simh_out" >&2
        echo "$tag: BADMAP package did not load" >&2
        exit 1
}
grep -Eq '^D6FS[[:space:]]+LOADED' "$simh_out" || {
        cat "$simh_out" >&2
        echo "$tag: D6FS did not load through BADMAP" >&2
        exit 1
}
grep -q '^LOGIN:' "$simh_out" || {
        cat "$simh_out" >&2
        echo "$tag: boot did not reach LOGIN through remapped superblocks" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (destroyed D6FS superblocks recovered through BADMAP)"
