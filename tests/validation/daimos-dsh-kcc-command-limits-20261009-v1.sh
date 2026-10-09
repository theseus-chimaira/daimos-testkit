#!/bin/sh
# DSH must accommodate the full native KCC single-command invocation.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
python3 - "$DAIMOS_REPO" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1]) / 'userland/dsh'
def limit(file, name):
    source = (root / file).read_text()
    match = re.search(r'^#define\s+' + name + r'\s+(\d+)U\s*$', source, re.M)
    assert match, f'missing limit {name}'
    return int(match.group(1))
command = ('KCC -S -O B/TEST.S -PGNU99 -X=PDP6 -M=GAS '
           '-DHOST_DAIMOS=1 -DHOST_UNIX=0 '
           '-I/OPTION/SOURCE/KCC/SELF/INCLUDE '
           '-I/OPTION/SOURCE/KCC/ABI -DKCC_PHASE_CPP=1 CC.C')
args = command.split()
assert len(command) <= limit('dsh.h', 'DSH_LINE_MAX_CHARS')
assert len(args) <= limit('dsh.h', 'DSH_MAX_ARGS')
assert len(args) <= limit('dsh_parse.h', 'DSH_PARSE_MAX_WORDS')
assert len(args) <= limit('dsh_lex.h', 'DSH_LEX_MAX_TOKENS')
assert len(args) <= limit('dsh.h', 'DSH_SCRIPT_MAX_TOKENS')
assert limit('dsh.h', 'DSH_LINE_MAX_WORDS') * 6 >= limit('dsh.h', 'DSH_LINE_MAX_CHARS')
assert max(map(len, args)) <= limit('dsh.h', 'DSH_S6_MAX_CHARS')
print(f'PASS: native KCC command: {len(command)} characters, {len(args)} arguments')
PY
