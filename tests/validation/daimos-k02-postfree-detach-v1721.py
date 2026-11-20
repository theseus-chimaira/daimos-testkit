#!/usr/bin/env python3
"""Generate a v890 physical guest with K02 post-MM-free detach refusals.

The original v890 script and all production sources remain unchanged. This
generator requires unique anchors: source or test drift must fail, not run an
unverified guest. Everything added to the guest is test-only instrumentation.
"""

from pathlib import Path
import sys


def replace_once(source, old, new):
    count = source.count(old)
    if count != 1:
        raise SystemExit("v1721: expected one hook (%d): %r" % (count, old[:90]))
    return source.replace(old, new, 1)


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: v1721.py SOURCE_V890 GENERATED_SCRIPT TEST_DIR")
    original = Path(sys.argv[1]).read_text()
    script = replace_once(original,
        'self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)\n',
        "self='%s'\n" % sys.argv[3])

    # Called only after the v890 copied-kernel preparation. The actual
    # vm_space_destroy and MM allocator remain unmodified and linked.
    hook = r"""python3 - "$work/source/system/kernel" <<'PYK02V1721'
from pathlib import Path
import sys

root = Path(sys.argv[1])
path = root / 'proc/vm_pdp6_swap.c'
source = path.read_text()
old_include = '#include "proc_storage_map_v28.h"\n'
globals_ = '''
/* Test-only refusal of executable backing detach AFTER real MM release. */
extern kword_t daimos_test_owner_v890;
extern kword_t daimos_test_staged_v890;
extern kword_t proc_current_slot;
kword_t daimos_test_k02_attempts_v1721;
kword_t daimos_test_k02_refusals_v1721;
kword_t daimos_k02_owner_v1721;
kword_t daimos_k02_idle_v1721;
kword_t daimos_test_k02_record_v1721;
kword_t daimos_test_k02_errors_v1721;
'''
assert source.count(old_include) == 1
source = source.replace(old_include, old_include + globals_, 1)
old = '        p = &proc_table[slot];\n        state = proc_swap_records[slot].state;\n'
new = '''        p = &proc_table[slot];
        /* The selected low-memory EXEC has already crossed the actual
         * MM free. The original VM is VM_NONE; no MM PROCESS extent may
         * still belong to this process. Refuse the first two attempts,
         * leaving the complete executable-backing record untouched.
         * The third call runs the production detach unmodified. */
        if ((kword_t)slot == daimos_test_owner_v890 &&
            daimos_test_staged_v890 == 1UL &&
            p->vm_state == ~(kword_t)0) {
                int k02_i;
                kword_t k02_backing = proc_swap_records[slot].state;
                ++daimos_test_k02_attempts_v1721;
                if (daimos_test_k02_attempts_v1721 == 1UL) {
                        daimos_test_k02_record_v1721 = k02_backing;
                        if (k02_backing == 0UL)
                                ++daimos_test_k02_errors_v1721;
                } else if (k02_backing != daimos_test_k02_record_v1721) {
                        ++daimos_test_k02_errors_v1721;
                }
                for (k02_i = 0; k02_i < mm_extent_count; ++k02_i) {
                        struct mm_extent *e = &mm_extents[k02_i];
                        if (MM_EXTENT_TYPE(e) == MM_TYPE_PROCESS &&
                            MM_EXTENT_OWNER(e) == (unsigned int)slot)
                                ++daimos_test_k02_errors_v1721;
                }
                if (proc_current_slot == (kword_t)slot)
                        ++daimos_k02_owner_v1721;
                else if (proc_current_slot == 0UL)
                        ++daimos_k02_idle_v1721;
                else
                        ++daimos_test_k02_errors_v1721;
                if (daimos_test_k02_attempts_v1721 <= 2UL) {
                        ++daimos_test_k02_refusals_v1721;
                        return -1;
                }
        }
        state = proc_swap_records[slot].state;
'''
assert source.count(old) == 1
path.write_text(source.replace(old, new, 1))
PYK02V1721
"""
    anchor = '''if [ "$e10_provider" = 1 ]; then
    python3 "$self/daimos-fatal-exec-provider-v1157.py"'''
    script = replace_once(script, anchor, hook + anchor)

    sample = r'''for name in attempts refusals owner_calls idle_calls record errors; do
    case "$name" in
    owner_calls) sym="daimos_k02_owner_v1721" ;;
    idle_calls) sym="daimos_k02_idle_v1721" ;;
    *) sym="daimos_test_k02_${name}_v1721" ;;
    esac
    addr=$(awk -v s="$sym" '$1 == s {print $2; exit}' "$map")
    test -n "$addr" || { echo "v1721: missing $sym" >&2; exit 1; }
    printf 'k02_%s %s\n' "$name" "$addr" >> "$work/addresses"
done
'''
    anchor = '''if [ "$nested" = 1 ]; then
    for name in late_run run_error finish_owner finish_fail \\
'''
    script = replace_once(script, anchor, sample + anchor)

    # v890's ordinary path successfully finishes old-VM destruction,
    # enters lowmem_old_gone, and then injects a replacement loader error.
    # Here the destructor fails AFTER mm_free and BEFORE that success edge:
    # these three success-only counters must stay zero, not one.
    script = replace_once(script,
        'expected = dict(staged=1, commits=1, vm_destroy=1, load_fail=1,\n',
        'expected = dict(staged=1, commits=0, vm_destroy=0, load_fail=0,\n')
    script = replace_once(script,
        "print('v890: real EXEC destroys VM, replacement loader fails, '\n"
        "      'VFS refusal twice, retry, FILE ownership, WAIT PASS')",
        "print('v1721: post-MM-free backing refusal prevents replacement '\n"
        "      'loader entry; fatal FILE retry and WAIT PASS')")

    # The original v890 post-VM fatal-EXEC, VFS retry and WAIT verifier
    # must pass first. These additional witnesses then prove our precise
    # three-attempt identity and successful final retirement.
    script += r'''
python3 - "$work/addresses" "$work/simh.out" <<'PYK02VERIFY'
from pathlib import Path
import re
import sys

output = Path(sys.argv[2]).read_text(errors='replace')
counts = {}
for row in Path(sys.argv[1]).read_text().splitlines():
    name, address = row.split()
    if not name.startswith('k02_'):
        continue
    hits = re.findall(r'(?im)^\s*0*' + re.escape(address.lstrip('0')) +
                      r'\s*:\s*([0-7]+)\b', output)
    if not hits:
        raise SystemExit('v1721: absent physical sample ' + name)
    counts[name] = int(hits[-1], 8)
print('v1721 real MM free / injected backing detach refusal:', counts)
expected = dict(k02_attempts=3, k02_refusals=2, k02_owner_calls=1,
                k02_idle_calls=2, k02_errors=0)
for name, value in expected.items():
    if counts.get(name) != value:
        raise SystemExit('v1721: incorrect %s: %s != %d' %
                         (name, counts.get(name), value))
if counts['k02_record'] == 0:
    raise SystemExit('v1721: no backing record remained during refusal')
print('v1721: actual MM owner freed, backing retained twice, slot-0 '
      'PREVM retry, final WAIT and independent v890 FILE retry PASS')
PYK02VERIFY
'''
    Path(sys.argv[2]).write_text(script)


if __name__ == '__main__':
    main()
