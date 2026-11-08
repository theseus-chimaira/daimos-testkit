#!/usr/bin/env python3
"""Verify the strict v1303 postflight ignores non-schema live probes.

Future samplers may append optional read-only addresses. They are not
part of the original after-HALT resource counter schema and must not
become mandatory simply because their names share a prefix.
"""

from pathlib import Path
import runpy
import tempfile


def main():
    module = runpy.run_path(str(Path(__file__).with_name(
        'daimos-swap-no-partner-physical-v1303.py')))
    fields = [('f07s_diag_' + key, 0) for key in module['FIELDS']]
    fields += [('f07a_' + key, 0) for key in module['ALLOC']]
    fields += [('f07s_final_swap_blocks', 0),
               ('f07s_final_backstore_used', 0)]
    with tempfile.TemporaryDirectory(prefix='daimos-v1347-schema-') as temp:
        root = Path(temp)
        addresses = root / 'addresses'
        transcript = root / 'simh.out'
        source = ['HALT instruction, PC: 021430']
        rows = []
        for index, (name, value) in enumerate(fields):
            addr = 0o30000 + index
            rows.append('%s %06o' % (name, addr))
            source.append('%06o:\t%012o' % (addr, value))
        rows.extend(('f07s_diag_timer_next 037700',
                     'f07s_final_optional_debug 037701'))
        addresses.write_text('\n'.join(rows) + '\n')
        transcript.write_text('\n'.join(source) + '\nGoodbye\n')
        counts, alloc, final = module['decode'](addresses, transcript)
        if (set(counts) != set(module['FIELDS']) or
                set(alloc) != set(module['ALLOC']) or
                'f07s_diag_timer_next' in final or
                'f07s_final_optional_debug' in final):
            raise AssertionError('optional source-linked diagnostic is mandatory')
        original = transcript.read_text()
        for mode in ('missing-required', 'duplicate-required'):
            if mode == 'missing-required':
                transcript.write_text(original.replace(source[1] + '\n', '', 1))
            else:
                transcript.write_text(original + source[1] + '\n')
            try:
                module['decode'](addresses, transcript)
            except ValueError:
                pass
            else:
                raise AssertionError('unsafe schema mutation: ' + mode)
        print('v1347: optional live address excluded, missing/duplicate '
              'mandatory postflight counter rejected PASS')


if __name__ == '__main__':
    main()
