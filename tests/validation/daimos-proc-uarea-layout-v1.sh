#!/bin/sh
set -eu

tag=daimos-proc-uarea-layout-v1
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"

ph="$DAIMOS_REPO/system/kernel/proc/proc.h"
pa="$DAIMOS_REPO/system/kernel/proc/proc_pdp6.s"
fh="$DAIMOS_REPO/system/kernel/fs/file.h"

c_define()
{
        name=$1
        awk -v n="$name" '$1 == "#define" && $2 == n { v=$3; sub(/UL$/, "", v); sub(/U$/, "", v); print v; exit }' "$ph"
}

a_equ()
{
        name=$1
        awk -F, -v n="$name" '$1 ~ "^[[:space:]]*\\.equ[[:space:]]+" n "$" { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$pa"
}

file_nfile=`awk '$1 == "#define" && $2 == "FILE_NFILE" { v=$3; sub(/U$/, "", v); print v; exit }' "$fh"`
uarea=`c_define PROC_UAREA_WORDS`
fdctl=`c_define PROC_FDCTL_OFFSET`
cwd=`c_define PROC_FILE_CWD_OFFSET`
table=`c_define PROC_FILE_TABLE_OFFSET`
cred=`c_define PROC_CRED_OFFSET`
umask=`c_define PROC_UMASK_OFFSET`
stack=`c_define PROC_USTACK_BASE`
atable=`a_equ PROC_FILE_TABLE_OFFSET`
astack=`a_equ PROC_USTACK_BASE`
kstack=`a_equ PROC_KSTACK_WORDS`

[ "$uarea" = 0407 ] || { echo "$tag: unexpected PROC_UAREA_WORDS=$uarea" >&2; exit 1; }
[ "$fdctl" = 0024 ] || { echo "$tag: unexpected fdctl offset=$fdctl" >&2; exit 1; }
[ "$cwd" = 0025 ] || { echo "$tag: unexpected cwd offset=$cwd" >&2; exit 1; }
[ "$table" = 0026 ] || { echo "$tag: unexpected table offset=$table" >&2; exit 1; }
[ "$cred" = 0066 ] || { echo "$tag: unexpected credential offset=$cred" >&2; exit 1; }
[ "$umask" = 0067 ] || { echo "$tag: unexpected umask offset=$umask" >&2; exit 1; }
[ "$stack" = 0070 ] || { echo "$tag: unexpected stack offset=$stack" >&2; exit 1; }
[ "$atable" = 026 ] || { echo "$tag: assembly table offset=$atable" >&2; exit 1; }
[ "$astack" = 070 ] || { echo "$tag: assembly stack offset=$astack" >&2; exit 1; }
[ "$kstack" = 0316 ] || { echo "$tag: assembly stack words=$kstack" >&2; exit 1; }
[ "$file_nfile" = 16 ] || { echo "$tag: FILE_NFILE=$file_nfile" >&2; exit 1; }

# 0000-0023 is exactly 0024 words of overlaid scheduler/syscall context:
# AC0..AC17, one shared user/kernel PI return word, KSP, saved user SP, and
# the sleeping syscall's JSR word.  FDCTL occupies 0024, CWD 0025, sixteen
# two-word descriptors 0026-0065, credentials 0066, and umask 0067.  The
# stack begins at 0070.  The final u-area word (0406) retains executable
# backing metadata while swapped, so the private stack remains 0316 words.
[ $((0$cwd)) -eq $((0$fdctl + 1)) ] || exit 1
[ $((0$table)) -eq $((0$cwd + 1)) ] || exit 1
[ $((0$cred)) -eq $((0$table + file_nfile * 2)) ] || exit 1
[ $((0$umask)) -eq $((0$cred + 1)) ] || exit 1
[ $((0$stack)) -eq $((0$umask + 1)) ] || exit 1
[ $((0$uarea - 0$stack - 1)) -eq $((00316)) ] || exit 1
grep -A1 '^#define PROC_SWAP_BACKING_OFFSET' "$ph" | \
    grep -q 'PROC_UAREA_WORDS - 1UL' || {
        echo "$tag: swap backing is not the final u-area word" >&2
        exit 1
}
grep -A1 '^#define PROC_KSTACK_WORDS' "$ph" | \
    grep -q 'PROC_SWAP_BACKING_OFFSET - PROC_USTACK_BASE' || {
        echo "$tag: C stack bound does not exclude swap backing word" >&2
        exit 1
}

if grep -q 'PROC_KCTX_WORDS' "$ph" "$pa"; then
        echo "$tag: obsolete PROC_KCTX_WORDS returned" >&2
        exit 1
fi

if grep -q 'CTX_K_AC0\|CTX_K_PC\|CTX_U_PC' "$pa"; then
        echo "$tag: separate user/kernel saved context returned" >&2
        exit 1
fi
grep -q '^[[:space:]]*\.equ[[:space:]]*CTX_PC,020' "$pa" || {
        echo "$tag: shared PI return word is missing" >&2
        exit 1
}

if grep -q 'PROC_PID_MASK\|PROC_PID(' "$ph"; then
        echo "$tag: redundant descriptor PID storage returned" >&2
        exit 1
fi

pl="$DAIMOS_REPO/system/kernel/proc/proc_late.c"
ex="$DAIMOS_REPO/system/kernel/proc/exec.c"
si="$DAIMOS_REPO/system/kernel/proc/syscall_info.s"
if grep -q 'PROC_PID_MASK' "$pl" "$ex"; then
        echo "$tag: process creation stores redundant PID state" >&2
        exit 1
fi
grep -q 'pid is the process-table slot' "$si" || {
        echo "$tag: PROCINFO no longer documents slot-derived PID" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (context=0024 fdctl=1 cwd=1 file=0040 cred=1 umask=1 stack=0316 swap=1 total=0407 octal words)"
