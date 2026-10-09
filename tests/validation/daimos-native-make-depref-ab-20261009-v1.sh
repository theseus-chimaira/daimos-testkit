#!/bin/sh
# Compare a baseline MAKE with the packed dependency rule-ref experiment.
# Both are tested under the same native SIMH probe set, timed at DSH boundary.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
b="$TMPDIR/daimos-make-depref-ab-20261009-v1"
mkdir -p "$b"
kit="$HOME/git/daimos-testkit"
python3 - "$kit/tools/daimos-simh-harness-v4.sh" "$b/harness.sh" <<'PY'
import sys
s=open(sys.argv[1]).read()
needle='''                send_dsh "$probe_command" "$probe_timeout" "$probe_terminal" "$output" || rc=$?'''
assert needle in s
s=s.replace(needle,'''                mark_start=$(date +%s%N)
                send_dsh "$probe_command" "$probe_timeout" "$probe_terminal" "$output" || rc=$?
                mark_end=$(date +%s%N)
                printf '%s\\t%s\\t%s\\t%s\\n' "$probe_name" "$mark_start" "$mark_end" "$rc" >> "$work/timing-ns.tsv"''',1)
open(sys.argv[2],'w').write(s)
PY
chmod 755 "$b/harness.sh"
for variant in before after; do
 case "$variant" in before) commit=93fd5eb;; after) commit=c720f2d;; esac
 tree="$b/$variant/tree"
 mkdir -p "$b/$variant"
 git -C "$HOME/git/DAIMOS" worktree add --detach "$tree" "$commit"
 script="$b/$variant/runner.sh"
 cp "$kit/tests/validation/daimos-native-make-include-20261009-v1.sh" "$script"
 sed -i "s/tag=daimos-native-make-include-20261009-v1/tag=daimos-make-depref-$variant-20261009-v1/" "$script"
 sed -i "s|\"\$(dirname \"\$0\")/../../tools/pty-run-v1.c\"|\"$kit/tools/pty-run-v1.c\"|g" "$script"
 sed -i "s|\"\$(dirname \"\$0\")/../../tools/daimos-simh-harness-v4.sh\"|\"$b/harness.sh\"|g" "$script"
 DAIMOS_REPO="$tree" PDP10_PREFIX=/usr/local PDP10_KCC=/usr/local/bin/kcc KCC_BOOT_BUILD=/usr/local/lib/kcc/bootstrap DAS_REPO="$HOME/git/das" KCC_REPO="$HOME/git/kcc" KEEP_WORK=1 sh "$script" > "$b/$variant/output.log" 2>&1
 work=$(sed -n 's/^retained: //p' "$b/$variant/output.log" | tail -1)
 cp "$work/run/timing-ns.tsv" "$b/$variant/timing-ns.tsv"
done
python3 - "$b" <<'PY'
import pathlib,sys
b=pathlib.Path(sys.argv[1]); a={}
for variant in ('before','after'):
 for line in (b/variant/'timing-ns.tsv').read_text().splitlines():
  name,x,y,rc=line.split('\t')
  assert rc=='0', (name,variant,rc)
  a.setdefault(name,{})[variant]=(int(y)-int(x))/1e9
print('PROBE,BEFORE_SECONDS,AFTER_SECONDS')
for name,pair in a.items():
 if len(pair)==2: print(f'{name},{pair["before"]:.3f},{pair["after"]:.3f}')
PY
