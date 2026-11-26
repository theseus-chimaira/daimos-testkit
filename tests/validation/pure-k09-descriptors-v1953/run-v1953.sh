#!/bin/sh
# Organic MM descriptor exhaustion through native PIPE and RUN syscalls.
set -eu
test "$#" = 1 || { echo "usage: $0 WORK" >&2; exit 2; }
mkdir "$1"
work=$(CDPATH= cd -- "$1" && pwd)
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
V1673_ONLY_VARIANT=general V1673_KERNEL_COMPILER=kcc \
V1673_CTY_TOKENS=ABCD V1673_WORK_DIR="$work" KEEP_TEST=1 \
V1673_TIMEOUT="${V1673_TIMEOUT:-1800}" \
V1673_GUEST_C="$here/init-v1953.c" \
V1673_CHILD_ASM="$here/child-v1953.s" \
V1673_MEASURE="$here/verify-v1953.py" \
sh "$here/../pure-runtime-reclaim-v1673/run-physical-v1673.sh"
