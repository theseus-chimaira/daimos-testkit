#!/bin/sh
# An excluded long directive must not terminate KCC with an internal error.
set -eu
: "${KCC_CC:?Set KCC_CC to the compiled host KCC executable}"
: "${TMPDIR:=$HOME/tmp}"
work="$TMPDIR/kcc-excluded-long-directive-v1070-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/probe-v1070.c" <<'EOF'
#if 0
#nonexistent_very_long_directive_that_should_be_ignored_by_the_parser xyz
#endif
int retained_value(void)
{
    return 42;
}
EOF
if ! "$KCC_CC" -S -v=nostats -x=pdp6 \
    -o "$work/probe-v1070.s" "$work/probe-v1070.c" \
    > "$work/compiler-v1070.log" 2>&1; then
    cat "$work/compiler-v1070.log" >&2
    exit 1
fi
test -s "$work/probe-v1070.s"
grep -Fq 'retained_value:' "$work/probe-v1070.s"
if grep -i -q 'internal error' "$work/compiler-v1070.log"; then
    cat "$work/compiler-v1070.log" >&2
    exit 1
fi
echo 'PASS: KCC continues after excluded long directive'
