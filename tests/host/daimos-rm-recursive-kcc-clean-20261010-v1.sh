#!/bin/sh
# Structural regression checks for native recursive RM and KCC BUILD cleanup.
set -eu
: "${DAIMOS_REPO:?}"
kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$DAIMOS_REPO" "$kcc" <<'PY'
from pathlib import Path
import re,sys
root=Path(sys.argv[1]); kcc=Path(sys.argv[2]); make=(kcc/'daimos.mk').read_text(); c=(root/'userland/exec/commands.c').read_text(); docs=(root/'userland/manual/RM.SIXMD').read_text(); asm=(root/'userland/optional/asmutils/Makefile').read_text()
assert not (root/'userland/optional/asmutils/RM.S').exists()
assert not re.search(r'^RM: RM\.S|\$\(CP\) RM(?:\.S)? ',asm,re.M)
assert re.search(r'(?m)^\.S\.DOBJ:\n\t@/OPTION/BASE/EXEC/DAS -F -C -O \$@ \$<',make)
assert not re.search(r'(?m)^BUILD/[^\n]+\.DOBJ:',make)
assert re.search(r'(?m)^CLEAN:\n\t@\$\(NATIVE_RM\) -R -F BUILD$',make)
assert 'rm_tree(child, depth + 1U)' in c and 'dsys_rmdir(path)' in c
assert 'VFS_TYPE_MOUNTSRC' in c and 'RM_MAX_DEPTH' in c
assert 'RM [-R] [-F]' in docs
print('PASS: native RM -R implementation, assembler RM removal, suffix and CLEAN graph')
PY

# Verify GNU Make's directory-qualified inference agrees with the staged rule.
work=$(mktemp -d "${TMPDIR:-$HOME/tmp}/kcc-suffix-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/BUILD"
cp "$kcc/daimos.mk" "$work/daimos.mk"
printf '; test only\n' > "$work/BUILD/PROBE.S"
(cd "$work" && make -r -f daimos.mk -n BUILD/PROBE.DOBJ) > "$work/output"
grep -Fq '/OPTION/BASE/EXEC/DAS -F -C -O BUILD/PROBE.DOBJ BUILD/PROBE.S' "$work/output"
echo 'PASS: directory-qualified .S.DOBJ suffix inference'
