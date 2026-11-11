#!/bin/sh
# Prove pending backing detach retains the owned MEMFS XIP MM reference.
# Extract actual production VM release and MEMFS release leaves, retaining
# v1094's independently exercised mock owner/error witnesses.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-xip-detach-v1471.XXXXXX")
trap 'if [ "${KEEP_TEST:-0}" != 1 ]; then rm -rf "$work"; else echo "v1471 work: $work"; fi' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO" "$here" "$work" <<'PY'
from pathlib import Path
import sys
root, here, out = [Path(s) for s in sys.argv[1:]]
vm = (root / 'system/kernel/proc/vm_pdp6.s').read_text()
mem = (root / 'system/kernel/fs/memfs_runtime.s').read_text()
old = (here / 'daimos-xip-release-stage-v1094.s').read_text()
assert vm.count('vm_space_destroy:') == 1
assert mem.count('memfs_mres_xip_release:') == 1
vm = vm.split('vm_space_destroy:', 1)[1].split(
    '/**\n * @brief Read executable words', 1)[0]
mem = mem.split('memfs_mres_xip_release:', 1)[1].split(
    '; SPACE returns total', 1)[0]
assert old.count('\nmain:\n') == 1
old = old.replace('\nmain:\n', '\nold_main_v1094:\n', 1)
assert 'fs_provider_reg_call:\n' in old
marker = 'fs_provider_reg_call:\n        aos     provider_calls_v1094\n'
assert old.count(marker) == 1
old = old.replace(marker, '''fs_provider_reg_call:
        caie    6,031                 ; v1469: read-only pinned-base query
        jrst    provider_release_v1471
        caie    7,4
        jrst    invariant_v1094
        pushj   17,memfs_xip_owns_base
        seto    3                      ; producer can clobber caller AC3
        jumpe   1,provider_query_done_v1471
        movei   1,1
provider_query_done_v1471:
        popj    17,
provider_release_v1471:
        movem   1,release_input_v1471 ; exact provider argument witness
        aos     provider_calls_v1094
''', 1)
header = '.text\n.globl vm_space_destroy\n.globl memfs_mres_xip_release\n'
test = (here / 'daimos-xip-detach-retry-v1471.s').read_text()
code = (header + test + '\nvm_space_destroy:' + vm + '\n'
        + 'memfs_mres_xip_release:' + mem + '\n' + old)
(out / 'production-and-mocks-v1471.s').write_text(code)
# Mutant: invert the pre-release detach refusal guard. A broken release
# may not silently pass the positive retry matrix.
anchor = '        jumpn   1,vm_space_destroy_xip_detach_fail_v1471'
assert code.count(anchor) == 1
(out / 'unsafe-detach-v1471.s').write_text(
    code.replace(anchor,
        '        jumpe   1,vm_space_destroy_xip_detach_fail_v1471', 1))
anchor = ('vm_space_destroy_release_normal_v1471:\n'
          '        move    1,(17)                 ; saved base, query clobbered AC3')
assert code.count(anchor) == 1
(out / 'unsafe-normal-base-v1471.s').write_text(
    code.replace(anchor,
        'vm_space_destroy_release_normal_v1471:\n'
        '        movei   1,017777              ; wrong physical base', 1))
PY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --start 1000 --step-limit 32000 --timeout 15 \
    --workdir "$work/run" --name daimos-xip-detach-retry-v1471 \
    --expect __test_exit=0 \
    "$here/daimos-test-crt0-v1.s" \
    "$work/production-and-mocks-v1471.s" > "$work/log" 2>&1 || {
        tail -75 "$work/log" >&2
        exit 1
    }
for mutant in unsafe-detach unsafe-normal-base; do
    if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 32000 --timeout 15 \
        --workdir "$work/$mutant" --name "daimos-xip-$mutant-v1471" \
        --expect __test_exit=0 \
        "$here/daimos-test-crt0-v1.s" \
        "$work/$mutant-v1471.s" > "$work/$mutant-log" 2>&1; then
        echo "FAIL: $mutant unexpectedly passed" >&2
        exit 1
    fi
    if ! grep -Fq 'FAIL: __test_exit:' "$work/$mutant-log"; then
        tail -40 "$work/$mutant-log" >&2
        echo "FAIL: $mutant must fail the native result assertion" >&2
        exit 1
    fi
done
echo 'PASS v1471: XIP detach/unpin refusal, private-VM base preservation, retries and 2 mutation controls'
