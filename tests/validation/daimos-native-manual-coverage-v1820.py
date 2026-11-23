#!/usr/bin/env python3
"""Check native DAIMOS SIXMD coverage against current build manifests.

This is the current-source successor to the archived v1073 inventory:
MKSWAP remains a planned guest command and the old host formatter
has been replaced. Do not invent host utility manual inventory.
"""

import os
from pathlib import Path
import re
import subprocess
import sys


REFERENCE = re.compile(r"\$\(([A-Z][A-Z0-9_]*)\)")
ASSIGN = re.compile(r"^([A-Z][A-Z0-9_]*)\s*(?:[:+?])?=\s*(.*)$")


def variables(source):
    values = {}
    pending = ""
    for raw in source.splitlines():
        line = pending + raw
        if line.rstrip().endswith("\\"):
            pending = line.rstrip()[:-1] + " "
            continue
        pending = ""
        match = ASSIGN.match(line)
        if match:
            values[match.group(1)] = match.group(2)
    assert not pending, "unterminated make continuation"
    return values


def names(variable, values):
    def resolve(value, stack):
        def replace(match):
            name = match.group(1)
            assert name in values, "unknown manifest variable " + name
            assert name not in stack, "recursive make variable " + name
            return resolve(values[name], stack + (name,))

        return REFERENCE.sub(replace, value)

    assert variable in values, "missing make variable " + variable
    words = resolve(values[variable], (variable,)).split()
    assert len(words) == len(set(words)), "duplicate " + variable
    return set(words)


def validate(checker, path, name):
    assert path.is_file(), "missing SIXMD " + str(path)
    result = subprocess.run([str(checker), str(path), name],
                            capture_output=True, text=True, check=False)
    assert result.returncode == 0, str(path) + ": " + result.stderr


def main():
    repo = Path(os.environ["DAIMOS_REPO"])
    prefix = Path(os.environ["PDP10_PREFIX"])
    checker = prefix / "bin/sixmd-check"
    user = repo / "userland"
    text = (user / "Makefile").read_text(encoding="ascii")
    values = variables(text)
    public = set()
    for name in ("COMMAND_PROGRAMS", "UTILITY_MISC_PROGRAMS",
                 "UTILITY_TEXT_PROGRAMS", "UTILITY_DOC_PROGRAMS"):
        public |= names(name, values)

    build = re.search(r"(?m)^build:\s*(.*)$", text)
    assert build, "missing native build target"
    assert "$(PUBLIC_PROGRAM_DXRS)" in build.group(1), \
        "public programs absent from build target"
    private = {"MOUNTALL", "DSHCOMP"}
    standalone = set(re.findall(r"\$\(([A-Z][A-Z0-9_]*)_DXR\)",
                                build.group(1)))
    assert private <= standalone, "private native helpers not built"
    executable = public | standalone
    required = executable - private
    documented = names("PUBLIC_MANUAL_NAMES", values)
    assert documented == required, (
        "native manifest/documentation mismatch; missing " +
        repr(sorted(required - documented)) + ", extra " +
        repr(sorted(documented - required)))

    pages = user / "manual"
    extras = {path.stem for path in pages.glob("*.SIXMD")} - documented
    assert extras == private | {"MKSWAP"}, \
        "unaccounted private/planned manual pages: " + repr(extras)
    for name in sorted(documented | extras):
        validate(checker, pages / (name + ".SIXMD"), name)

    planned = (pages / "MKSWAP.SIXMD").read_text(encoding="ascii")
    assert "PLANNED NATIVE" in planned and "NOT YET INSTALLED" in planned
    boot = (repo / "system/boot/pdp6/Makefile").read_text(encoding="ascii")
    assert '-e MKSWAP' in boot and '-e DSHCOMP' in boot
    assert '-f "/SYSTEM/EXEC/MKSWAP:' not in boot, \
        "unimplemented native MKSWAP advertised as installed"

    optional = user / "optional/asmutils"
    install = (optional / "Makefile").read_text(encoding="ascii")
    installed = set(re.findall(
        r"\$\(CP\)\s+([A-Z0-9.]+)\s+\$\(EXEC\)/[A-Z0-9.]+", install))
    assert installed, "no optional native assembler programs found"
    for name in sorted(installed):
        validate(checker, optional / "manual" / (name + ".SIXMD"), name)

    print("daimos-native-manual-coverage-v1820: PASS "
          "(%d public manuals, %d private native helpers, "
          "%d optional native manuals; MKSWAP planned)" %
          (len(documented), len(private), len(installed)))


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, KeyError, OSError) as error:
        sys.exit("daimos-native-manual-coverage-v1820: FAIL: " + str(error))
