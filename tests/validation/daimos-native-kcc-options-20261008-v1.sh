#!/bin/sh
# Check that the native KCC driver forwards profile flags to KCPP.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"

tag=daimos-native-kcc-options-20261008-v1
work=$(mktemp -d "$TMPDIR/$tag.XXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "retained: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM

cat > "$work/probe.c" <<'EOF_C'
int main(void) { return 0; }
EOF_C
"$PDP10_PREFIX/bin/csix" -e "$work/probe.c" "$work/probe.s6"
cat > "$work/optmake.txt" <<'EOF_MAKE'
.PHONY: ALL
ALL:
> !/OPTION/BASE/EXEC/KCC -S -O /TEMP/KCCOPT.S /CONFIG/KCCOPT.C
EOF_MAKE
tr '[:lower:]' '[:upper:]' < "$work/optmake.txt" > "$work/optmake.upper"
"$PDP10_PREFIX/bin/s6text" --encode "$work/optmake.upper" "$work/optmake.s6"
cat > "$work/shellmake.txt" <<'EOF_MAKE_SHELL'
.PHONY: ALL
ALL:
> /OPTION/BASE/EXEC/KCC -S -O /TEMP/KCCSHELL.S /CONFIG/KCCOPT.C
EOF_MAKE_SHELL
"$PDP10_PREFIX/bin/s6text" --encode "$work/shellmake.txt" "$work/shellmake.s6"
cat > "$work/cppmake.txt" <<'EOF_MAKE_CPP'
.PHONY: ALL
ALL:
> !/OPTION/BASE/LIBEXEC/KCC/KCPP -R=/SCRATCH/KCCMAKE.KPT /CONFIG/KCCOPT.C
EOF_MAKE_CPP
"$PDP10_PREFIX/bin/s6text" --encode "$work/cppmake.txt" "$work/cppmake.s6"
cat > "$work/parsemake.txt" <<'EOF_MAKE_PARSE'
.PHONY: ALL
ALL:
> !/OPTION/BASE/LIBEXEC/KCC/KPARSE -R=/SCRATCH/KCCMAKE.KIR -X=/SCRATCH/KCCMAKE.KP1 -Y=/SCRATCH/KCCMAKE.S /SCRATCH/KCCMAKE.KPT
EOF_MAKE_PARSE
"$PDP10_PREFIX/bin/s6text" --encode "$work/parsemake.txt" "$work/parsemake.s6"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$work/pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"

cat > "$work/probes" <<'EOF_PROBES'
probe native-kcc-direct
command /OPTION/BASE/EXEC/KCC -S -O /TEMP/KCCDIRECT.S /CONFIG/KCCOPT.C; ECHO STATUS:$?
contains STATUS:0
timeout 240
end
probe native-kcpp-direct
command /OPTION/BASE/LIBEXEC/KCC/KCPP -R=/TEMP/KCCTEST.KPT /CONFIG/KCCOPT.C; ECHO STATUS:$?
contains STATUS:0
timeout 240
end
probe native-kcc-profile-options
command MAKE -F /CONFIG/OPTSMAKE ALL; ECHO STATUS:$?
contains STATUS:0
timeout 240
end
probe native-kcc-shell-recipe
command MAKE -F /CONFIG/SHELLMAKE ALL; ECHO STATUS:$?
contains STATUS:0
timeout 240
end
probe native-kcpp-make-recipe
command MAKE -F /CONFIG/CPPMAKE ALL; ECHO STATUS:$?
contains STATUS:0
timeout 240
end
probe native-kparse-make-recipe
command MAKE -F /CONFIG/PARMAKE ALL; ECHO STATUS:$?
contains STATUS:0
timeout 240
end
probe native-compiled-source
command LS /SCRATCH/KCCMAKE.S
contains KCCMAKE.S
end
probe native-kcc-profile-output
command LS /TEMP/KCCOPT.S
contains KCCOPT.S
end
EOF_PROBES

make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        PDP10_PREFIX="$PDP10_PREFIX" BUILD="$work/boot" \
        KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
        DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
        DAIMOS_TOOLS_REPO="${DAIMOS_TOOLS_REPO:-$HOME/git/daimos-tools}" \
        SIMH_CPU_KWORDS="${SIMH_CPU_KWORDS:-96}" \
        D6FS_EXTRA_ARGS="-f /CONFIG/KCCOPT.C:$work/probe.s6:644:binwords -f /CONFIG/OPTSMAKE:$work/optmake.s6:644:binwords -f /CONFIG/SHELLMAKE:$work/shellmake.s6:644:binwords -f /CONFIG/CPPMAKE:$work/cppmake.s6:644:binwords -f /CONFIG/PARMAKE:$work/parsemake.s6:644:binwords" \
        > "$work/build.log" 2>&1 || {
        tail -50 "$work/build.log" >&2
        exit 1
}

"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
        --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md"
echo "$tag: PASS"
