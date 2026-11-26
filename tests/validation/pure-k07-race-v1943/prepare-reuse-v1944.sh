#!/bin/sh
# Reuse an actual guest-seeded and CLEAN-retired reel. No fabricated
# native filesystem and no modification of kernel/MM/provider code.
set -eu
: "${DAIMOS_REPO:?}" "${V1944_SEED_BUILD:?}" "${V1944_SEED_TRACE:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
export PATH="$PDP10_PREFIX/bin:$PATH"
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
old=$(CDPATH= cd -- "$V1944_SEED_BUILD" && pwd)
seed=$(CDPATH= cd -- "$V1944_SEED_TRACE" && pwd)
work=$(mktemp -d "$TMPDIR/pure-k07-race-reuse-v1944.XXXXXX")
trap 'echo "v1944 reuse fixture: $work"' EXIT
b="$work/build"
mkdir -p "$b" "$work/user"
python3 "$here/check-reel-v1944.py" "$old/media/dtc3-home-v22.tap" \
    "$seed/media/dtc3.tap" "$old/../user/comp-v1638.dxr"
python3 - "$seed/physical.clean" "$old/../user/init-v1943.c" "$work/user/init-v1944.c" <<'PY'
from pathlib import Path
import sys
trace, old, new = map(Path, sys.argv[1:])
assert "ijkccccccccdsuIE" in trace.read_text(), "actual guest seed not complete"
s = old.read_text()
a = s.index("static int\np14_seed_secondary_v1643(void)")
z = s.index("\n}\n",a)+3
s = s[:a] + """static int
p14_seed_secondary_v1643(void)
{
    struct sys_fsinfo info;
    struct vfs_stat st;
    if (dsys_dtfs_mount(p14_device_v1643, p14_mount_v1643,
            SYS_DTFS_TYPE_NATIVE) != 0)
        return -1;
    if (dsys_fsinfo(1U, &info) != 1 ||
        info.provider != 5UL || info.mount_id != 2UL)
        return -2;
    if (dsys_stat(p14_compressed_path, &st) != 0 ||
        st.type != VFS_TYPE_REG || st.size_words != 999UL ||
        (st.mode & 0111U) == 0)
        return -3;
    return 0;
}
""" + s[z:]
new.write_text(s, encoding="ascii")
PY
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
incs=
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc"
"$cc" -std=c99 -Os $incs -S "$work/user/init-v1944.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
cp "$old/../user/crt0.dobj" "$old/../user/syscall.dobj" "$work/user/"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$work/dlink-v1944" \
    "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
"$work/dlink-v1944" --pure -b 020 -o "$work/user/init.dxr" \
    -M "$work/user/init.map" "$work/user/crt0.dobj" \
    "$work/user/syscall.dobj" "$work/user/init.dobj" "$("$cc" -print-libgcc-file-name)"
"$PDP10_PREFIX/bin/dxrcheck" "$work/user/init.dxr"
cp "$old/../user/comp-v1638.dxr" "$work/user/comp-v1638.dxr"
cp -a "$old/." "$b/"
cp "$seed/media/dtc3.tap" "$b/media/dtc3-home-v22.tap"
python3 - "$old" "$work" "$b" <<'PY'
from pathlib import Path
import sys
old,w,b=map(Path,sys.argv[1:])
s=(old/"tsfs-root.manifest").read_text()
a="F /SYSTEM/INIT "+str(old.parent/"user/init.dxr")
assert s.count(a)==1 and "F /SYSTEM/COMP " not in s
s=s.replace(a,"F /SYSTEM/INIT "+str(w/"user/init.dxr"),1)
(b/"tsfs-root.manifest").write_text(s)
s+="F /SYSTEM/COMP "+str(w/"user/comp-v1638.dxr")+" 0555 0 0\n"
(w/"tsfs-root-v1944.manifest").write_text(s)
(b/"boot.ini").write_text((old/"boot.ini").read_text().replace(str(old)+"/",str(b)+"/"))
PY
"$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$work/tsfs-root-v1944.manifest" \
    -b "$b/kinit.lowmem.words" -o "$work/tsfs-v1944"
"$b/tsfscheck-v1461" "$work/tsfs-v1944"0.dta "$work/tsfs-v1944"1.dta "$work/tsfs-v1944"2.dta
for unit in 0 1 2; do cp "$work/tsfs-v1944$unit.dta" "$b/media/dtc$unit.tap"; done
for n in kcore.dxr kinit.lowmem.words pure-mres-v1612.dxr; do cmp "$old/$n" "$b/$n"; done
cmp "$old/../user/comp-v1638.dxr" "$work/user/comp-v1638.dxr"
python3 "$here/check-reel-v1944.py" "$old/media/dtc3-home-v22.tap" \
    "$b/media/dtc3-home-v22.tap" "$work/user/comp-v1638.dxr"
echo "PASS v1944: actual guest-seeded reel reused, same kernel and compressed child"
echo "V1943_BUILD=$b"
