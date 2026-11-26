#!/bin/sh
# Source-built disposable physical TSFS fixture; not a lifecycle oracle.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
export TMPDIR=${TMPDIR:-$HOME/tmp} PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export PATH="$PDP10_PREFIX/bin:$PATH"
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-directory-guest-v1983.XXXXXX")
trap 'echo "v1983 guest evidence: $work"' EXIT
mkdir -p "$work/user"
b="$work/build"
python3 "$kit/tests/diagnostics/pure-full-restore-v1638/prepare-v1638.py" \
    "$kit/tests/diagnostics/pure-brk-pressure-v1614/test-v1614.c" "$work/user/init-v1983.c"
python3 - "$work/user/init-v1983.c" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
# Capacity is a result, not a pre-assumed number of admitted children.
a='''        if (pid[i] <= 1)
            p14_fail('r');'''
b='''        if (pid[i] <= 1)
            break;'''
assert s.count(a)==1
s=s.replace(a,b).replace('#define P14_CHILDREN         6U','#define P14_CHILDREN         12U')
s=s.replace('unsigned int i;\n    kword_t old_brk','unsigned int i, children;\n    kword_t old_brk')
a=s.index('    /* Seventh RUN');b=s.index("    (void)p14_char('x');",a)
s=s[:a]+'''    children = i;
    if (children < 4U)
        p14_fail('r');
'''+s[b:]
s=s.replace('pid[P14_CHILDREN], got, denied;','pid[P14_CHILDREN], got;')
s=s.replace('target = P14_BRK_TARGET;', 'target = old_brk;')
a=s.index('    all_words = 0UL;');s=s[:a]+s[a:].replace('i < P14_CHILDREN','i < children')
# Check the complete sparse BSS tail, rather than only two sentinels.
a='''        if (p14_data[0] != 012345670123UL ||
            p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL)
            (void)dsys_exit(072);'''
b=a+'''
        for (i = 1U; i + 1U < P14_IMAGE_WORDS; ++i)
            if (p14_data[i] != (i % 0100U == 0U ? (kword_t)i : 0UL))
                (void)dsys_exit(073);'''
assert s.count(a)==1;s=s.replace(a,b)
s=s.replace('    if (argc > 1) {','    if (argc > 1) {\n        for (i = 0100U; i + 1U < P14_IMAGE_WORDS; i += 0100U)\n            p14_data[i] = (kword_t)i;')
p.write_text(s,encoding='ascii')
PY
cc="$PDP10_PREFIX/bin/pdp10-dec-none-gcc"
das="$PDP10_PREFIX/bin/das"
link="$work/dlink-v1983"
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$link" \
    "$DAIMOS_REPO/tools/host/dlink.c" "$DAIMOS_REPO/tools/host/dobj.c"
incs="-I$DAIMOS_REPO/userland/libc"
for dir in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
"$cc" -std=c99 -Os $incs -S "$work/user/init-v1983.c" -o "$work/user/init.s"
"$das" -C -F -O "$work/user/init.dobj" "$work/user/init.s"
for part in crt0 syscall; do
    "$das" -C -F -O "$work/user/$part.dobj" "$DAIMOS_REPO/userland/libc/$part.s"
done
libgcc=$("$cc" -print-libgcc-file-name)
for mode in init marked; do
    opt=; [ "$mode" = init ] || opt=--compressible-mutable
    "$link" --pure $opt -b 020 -o "$work/user/$mode.dxr" -M "$work/user/$mode.map" \
        "$work/user/crt0.dobj" "$work/user/syscall.dobj" "$work/user/init.dobj" "$libgcc"
done
make -s -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$b" PDP10_PREFIX="$PDP10_PREFIX" ROOT=tape BOOT=dtc \
    BOOT_PROFILE=lowmem COMPILER=gcc BOOT_CORE_WORDS=0200000 \
    SIMH_CPU_KWORDS=64 TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
    DAIMOS_PURE_MRES_ENABLED=1 DAIMOS_SWAPLESS_ONLY_V1668=1 DAIMOS_PBM_DIRECTORY_V1983=1 \
    SYSTEM_INIT_DXR="$work/user/init.dxr" >"$work/build.log" 2>&1 || { tail -60 "$work/build.log"; exit 1; }
"$b/d6block-v1464" -x "$work/user/marked.dxr" "$work/user/comp.dxr"
python3 - "$work/user" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);hdr=lambda n:[int.from_bytes((p/n).read_bytes()[i:i+8],'little') for i in (0,8,16)]
a,m,c=map(hdr,('init.dxr','marked.dxr','comp.dxr'))
assert m[:2]==a[:2] and m[2]==a[2]|(1<<35)
assert c[2]==m[2] and c[1]==m[1]|0o100000
print('Verified unmarked INIT and independently linked marked compressed DXR2 child')
PY
cp "$b/tsfs-root.manifest" "$work/tsfs.manifest"
printf 'F /SYSTEM/COMP %s 0555 0 0\n' "$work/user/comp.dxr" >>"$work/tsfs.manifest"
"$b/mktsfs-v1461" -n 3 -i 1:1 -g 1 -m "$work/tsfs.manifest" -b "$b/kinit.lowmem.words" -o "$work/root-v1983"
"$b/tsfscheck-v1461" "$work/root-v1983"0.dta "$work/root-v1983"1.dta "$work/root-v1983"2.dta
for unit in 0 1 2; do cp "$work/root-v1983$unit.dta" "$b/media/dtc$unit.tap"; done
printf 'V1983_BUILD=%s\n' "$b"
