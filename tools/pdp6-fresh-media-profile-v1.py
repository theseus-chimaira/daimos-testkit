#!/usr/bin/env python3
"""Prepare isolated, fresh PDP-6 SIMH DAIMOS boot profiling media.

Copies device media, preserving paths relative to the boot root so disk
and drum names cannot collide. Never run against production build media.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

ATTACH = re.compile(r'^(attach\s+[^\n]*?\s+)(/[^\s]+)(\s*)$', re.M)


def prepare(boot_ini, output, steps):
    boot_ini = Path(boot_ini).resolve()
    source_root = boot_ini.parent
    output = Path(output).resolve()
    if output == source_root or source_root in output.parents:
        raise ValueError('output must be outside production boot tree')
    if output.exists() and any(output.iterdir()):
        raise ValueError('refusing to reuse potentially modified media')
    if steps < 1:
        raise ValueError('positive step budget required')
    output.mkdir(parents=True, exist_ok=True)
    config = boot_ini.read_text()
    copied = {}
    def replace(match):
        prefix, old, suffix = match.groups()
        media = Path(old)
        if not media.is_file():
            raise FileNotFoundError(media)
        try:
            relative = media.relative_to(source_root)
        except ValueError:
            relative = Path('external') / hashlib.sha256(str(media).encode()).hexdigest()[:12] / media.name
        target = output / 'media' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if old not in copied:
            shutil.copyfile(media, target)
            copied[old] = {'relative': str(relative), 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
        return prefix + str(target) + suffix
    config = ATTACH.sub(replace, config)
    config = re.sub(r'^set -q -n log .+$', '; no production log', config, flags=re.M)
    config = re.sub(r'^set (dpy|wcnsls|ocnsls) .+$', '; no graphical device', config, flags=re.M)
    config = re.sub(r'^attach -q (dcs0|ge0) .+$', '; no network listener', config, flags=re.M)
    config = re.sub(r'^set (dcs|ge) enabled$', '; no network listener', config, flags=re.M)
    if config.count('go 020') != 1:
        raise ValueError('expected exactly one DAIMOS bootstrap entry')
    config = config.replace('go 020', f'deposit PC 020\nstep {steps}\nexamine PC\nexamine OPCOUNT[0-511]')
    script = output / 'bounded-boot-v1.ini'
    script.write_text(config)
    manifest = {'schema':'pdp6-fresh-media-profile-v1', 'steps':steps,
                'source_boot_ini_sha256':hashlib.sha256(boot_ini.read_bytes()).hexdigest(),
                'media':copied}
    (output/'media-manifest-v1.json').write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n')
    return script, manifest


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('boot_ini')
    p.add_argument('output')
    p.add_argument('--steps',type=int,default=12000000)
    a=p.parse_args()
    script,manifest=prepare(a.boot_ini,a.output,a.steps)
    print('Prepared fresh isolated media:',len(manifest['media']), 'image paths')
    print('SIMH bounded script:',script)


if __name__=='__main__':
    main()
