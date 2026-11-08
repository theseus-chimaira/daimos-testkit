#!/usr/bin/env python3
"""Check v1207 mandatory swap fields versus optional live diagnostics."""

from pathlib import Path
import runpy
import tempfile


def main():
    mod = runpy.run_path(str(Path(__file__).with_name(
        'daimos-f07-swapstack-verify-v1207.py')))
    expected = mod['SWAP_FIELDS']
    with tempfile.TemporaryDirectory(prefix='daimos-v1349-swap-fields-') as temp:
        root = Path(temp)
        mapping = root / 'addresses'
        simh = root / 'simh.out'
        addresses = []
        records = []
        for index, key in enumerate(sorted(expected)):
            address = 0o30000 + index
            addresses.append('f07s_%s %06o' % (key, address))
            records.append('%06o:\t%012o' % (address, index))
        addresses.append('f07s_diag_timer_next 037700')
        mapping.write_text('\n'.join(addresses) + '\n')
        source = '\n'.join(records) + '\n'
        simh.write_text(source)
        found = mod['read_values'](mapping, simh, 'f07s_')
        if set(found) != expected or 'diag_timer_next' in found:
            raise AssertionError('unexpected optional live diagnostic')
        for name, bad in (
                ('missing', source.replace(records[0] + '\n', '', 1)),
                ('duplicate', source + records[0] + '\n')):
            simh.write_text(bad)
            try:
                mod['read_values'](mapping, simh, 'f07s_')
            except ValueError:
                continue
            raise AssertionError('mandatory v1207 field ' + name + ' escaped')
    print('v1349: original v1207 mandatory swap fields remain strict; '
          'optional live diagnostics ignored, two negatives PASS')


if __name__ == '__main__':
    main()
