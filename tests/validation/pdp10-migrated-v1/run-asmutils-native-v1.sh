#!/bin/sh
set -eu

fail()
{
    echo "run-asmutils-native-v1: $*" >&2
    exit 1
}

TEST_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PDP10_PREFIX=${PDP10_PREFIX:?set PDP10_PREFIX}
DAIMOS_REPO=${DAIMOS_REPO:?set DAIMOS_REPO}
DAS_ROOT=${DAS_ROOT:?set DAS_ROOT}
TMPDIR=${TMPDIR:?set TMPDIR}

tag=asmutils-native-v1
work=$TMPDIR/$tag-$$
build=$work/build
user=$work/user
src=$DAIMOS_REPO/userland/optional/asmutils
enc=$work/s6
script=$work/TEST.DSH
script_s6=$work/TEST.DSH.s6rec
text=$work/TEXT.S6
text_s6=$work/TEXT.S6.s6rec
extra=$work/extra.args
out=$work/simh.out
mkdir -p "$user" "$enc"
trap 'rm -rf "$work"' 0 1 2 3 15

kcc=$PDP10_PREFIX/bin/kcc
das=$DAS_ROOT/das
dlink=$PDP10_PREFIX/bin/dlink
simh=$PDP10_PREFIX/bin/pdp6
s6text=$DAS_ROOT/s6text

for tool in "$kcc" "$das" "$dlink" "$simh" "$s6text"; do
    [ -x "$tool" ] || fail "missing tool: $tool"
done

incs="-I$DAIMOS_REPO/system/kernel/boot -I$DAIMOS_REPO/system/kernel/core -I$DAIMOS_REPO/system/kernel/drivers -I$DAIMOS_REPO/system/kernel/fs -I$DAIMOS_REPO/system/kernel/mm -I$DAIMOS_REPO/system/kernel/modules -I$DAIMOS_REPO/system/kernel/proc -I$DAIMOS_REPO/system/kernel/storage -I$DAIMOS_REPO/userland/libc -I$PDP10_PREFIX/include"
"$kcc" -Pgnu99 -O -x=pdp6 -m=gas ${ASMUTILS_CPPFLAGS:-} $incs -S \
    "$TEST_ROOT/asmutils-native-run-v1.c" -o "$user/init.s"
"$das" -F -C -O "$user/init.dobj" "$user/init.s"
"$das" -F -C -O "$user/crt0.dobj" "$DAIMOS_REPO/userland/libc/crt0.s"
"$das" -F -C -O "$user/syscall.dobj" "$DAIMOS_REPO/userland/libc/syscall.s"
"$das" -F -C -O "$user/syscall_helpers.dobj" \
    "$DAIMOS_REPO/userland/libc/syscall_helpers.s"
"$dlink" --daimos-uuo-relax -b 020 -o "$user/init.dxr" -M "$user/init.map" \
    "$user/crt0.dobj" "$user/syscall.dobj" "$user/syscall_helpers.dobj" \
    "$user/init.dobj"

programs=${ASMUTILS_PROGRAMS:-'ARGS ASCII2SIX BENCH CPUSPEED CRC DIS DXRINFO ECHO FACTOR FALSE MKDIR MV OD PRIME RAND REV RM RMDIR SIX2ASCII SLEEP SORT SUM TOUCH TR TRUE UNIQ YES'}
target_dir=${ASMUTILS_WORKDIR:-/TEMP/ASMUTILS}

printf 'CD %s OR EXIT 2\n' "$target_dir" > "$script"
code=10
native_dasflags=${ASMUTILS_DASFLAGS:--B -S}
for p in $programs; do
    echo "/SYSTEM/EXEC/ECHO ASM $p" >> "$script"
    out_name=${ASMUTILS_OUTPUT_NAME:-$p.DXR}
    if [ "${ASMUTILS_ABSOLUTE_PATHS:-0}" = 1 ]; then
        echo "/OPTION/BASE/EXEC/DAS $native_dasflags -O $target_dir/$out_name $target_dir/$p.S OR EXIT $code" >> "$script"
    else
        echo "/OPTION/BASE/EXEC/DAS $native_dasflags -O $out_name $p.S OR EXIT $code" >> "$script"
    fi
    code=$((code + 1))
done
if [ "${ASMUTILS_ASSEMBLE_ONLY:-0}" = 1 ]; then
    echo 'EXIT 0' >> "$script"
else
cat >> "$script" <<'EOF'
/SYSTEM/EXEC/ECHO TEST 1
/TEMP/ASMUTILS/TRUE.DXR OR EXIT 40
/SYSTEM/EXEC/ECHO TEST 2
/TEMP/ASMUTILS/FALSE.DXR AND EXIT 41
/SYSTEM/EXEC/ECHO TEST 3
/TEMP/ASMUTILS/PRIME.DXR 7 OR EXIT 42
/SYSTEM/EXEC/ECHO TEST 4
/TEMP/ASMUTILS/PRIME.DXR 8 AND EXIT 43
/SYSTEM/EXEC/ECHO TEST 5
/TEMP/ASMUTILS/SLEEP.DXR 0 OR EXIT 44
/SYSTEM/EXEC/ECHO TEST 6
/TEMP/ASMUTILS/TOUCH.DXR T OR EXIT 45
/SYSTEM/EXEC/ECHO TEST 7
/TEMP/ASMUTILS/MV.DXR T T2 OR EXIT 46
/SYSTEM/EXEC/ECHO TEST 8
/TEMP/ASMUTILS/RM.DXR T2 OR EXIT 47
/SYSTEM/EXEC/ECHO TEST 9
/TEMP/ASMUTILS/MKDIR.DXR D OR EXIT 48
/SYSTEM/EXEC/ECHO TEST 10
/TEMP/ASMUTILS/RMDIR.DXR D OR EXIT 49
/SYSTEM/EXEC/ECHO TEST 11
/TEMP/ASMUTILS/DXRINFO.DXR TRUE.DXR OR EXIT 50
/SYSTEM/EXEC/ECHO TEST 12
/TEMP/ASMUTILS/DIS.DXR TRUE.DXR > DIS.OUT OR EXIT 51
/SYSTEM/EXEC/ECHO TEST 13
/TEMP/ASMUTILS/OD.DXR TRUE.DXR > OD.OUT OR EXIT 52
/SYSTEM/EXEC/ECHO TEST 14
/TEMP/ASMUTILS/SUM.DXR TRUE.DXR > SUM.OUT OR EXIT 53
/SYSTEM/EXEC/ECHO TEST 15
/TEMP/ASMUTILS/RAND.DXR 1 1 > RAND.OUT OR EXIT 54
/SYSTEM/EXEC/ECHO TEST 16
/TEMP/ASMUTILS/FACTOR.DXR 12 > FACTOR.OUT OR EXIT 55
/SYSTEM/EXEC/ECHO TEST 17
/TEMP/ASMUTILS/ARGS.DXR A B > ARGS.OUT OR EXIT 56
/SYSTEM/EXEC/ECHO TEST 18
/TEMP/ASMUTILS/ECHO.DXR A B > ECHO.OUT OR EXIT 57
/SYSTEM/EXEC/ECHO TEST 19
/TEMP/ASMUTILS/BENCH.DXR 10 > BENCH.OUT OR EXIT 58
/SYSTEM/EXEC/ECHO TEST 20
/TEMP/ASMUTILS/REV.DXR < TEXT.S6 > REV.OUT OR EXIT 60
/SYSTEM/EXEC/ECHO TEST 21
/TEMP/ASMUTILS/UNIQ.DXR < TEXT.S6 > UNIQ.OUT OR EXIT 61
/SYSTEM/EXEC/ECHO TEST 22
/TEMP/ASMUTILS/SORT.DXR < TEXT.S6 > SORT.OUT OR EXIT 62
/SYSTEM/EXEC/ECHO TEST 23
/TEMP/ASMUTILS/TR.DXR A B < TEXT.S6 > TR.OUT OR EXIT 63
/SYSTEM/EXEC/ECHO TEST 24
/SYSTEM/EXEC/ECHO ABC ! /TEMP/ASMUTILS/ASCII2SIX.DXR ! /TEMP/ASMUTILS/SIX2ASCII.DXR > CONV.OUT OR EXIT 64
/SYSTEM/EXEC/ECHO TEST 25
/SYSTEM/EXEC/ECHO ABC ! /TEMP/ASMUTILS/CRC.DXR > CRC.OUT OR EXIT 65
EXIT 0
EOF
fi

cat > "$text" <<'EOF'
BETA
ALPHA
ALPHA
EOF
"$s6text" --encode "$script" "$script_s6"
"$s6text" --encode "$text" "$text_s6"

: > "$extra"
printf '%s\n' '-D /TEMP/ASMUTILS:755' >> "$extra"
if [ -n "${ASMUTILS_SOURCE_FILES:-}" ]; then
    for b in $ASMUTILS_SOURCE_FILES; do
        f=$src/$b
        e=$enc/$b.s6rec
        "$s6text" --encode "$f" "$e"
        printf '%s\n' "-f $target_dir/$b:$e:644:binwords" >> "$extra"
    done
else
    for f in "$src"/*.S; do
        b=$(basename "$f")
        e=$enc/$b.s6rec
        "$s6text" --encode "$f" "$e"
        printf '%s\n' "-f $target_dir/$b:$e:644:binwords" >> "$extra"
    done
fi
printf '%s\n' "-f /TEMP/ASMUTILS/TEST.DSH:$script_s6:644:binwords" >> "$extra"
printf '%s\n' "-f /TEMP/ASMUTILS/TEXT.S6:$text_s6:644:binwords" >> "$extra"

extra_args=$(tr '\n' ' ' < "$extra")
PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
    DAS="$DAS_ROOT/das" DASFLAGS=-F DAS_REPO="$DAS_ROOT" \
    PROC_BOOT_USERS=1 D6FS_LOGSTORE_BLOCKS=010 D6FS_SWAP_TAIL_BLOCKS=010 \
    SYSTEM_INIT_DXR="$user/init.dxr" D6FS_EXTRA_ARGS="$extra_args" >/dev/null

boot=$build/system/boot/pdp6
set +e
(
    cd "$boot"
    TERM=dumb timeout -k 2s "${ASMUTILS_TIMEOUT:-600}s" stdbuf -o0 -e0 "$simh" boot.ini
) >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    cat "$out" >&2
    fail "simulator failed: $rc"
fi
if ! tr -d '\r' < "$out" | grep -F 'ASMUTILS NATIVE PASS' >/dev/null; then
    cat "$out" >&2
    fail "native assembler utility contract failed"
fi
if tr -d '\r' < "$out" | grep -F 'ASMUTILS NATIVE FAIL' >/dev/null; then
    cat "$out" >&2
    fail "native assembler utility target reported failure"
fi

echo "native ASMUTILS assembly/runtime contract passed"
