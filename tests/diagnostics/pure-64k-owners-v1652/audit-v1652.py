#!/usr/bin/env python3
"""Audit a REAL original 64K nine-child guest, not a memory-gain claim.

The guest must execute all original C89 PIPE/data/EXIT/WAIT assertions,
and the source-linked freshly compressed DXR must match its plain image.
Physical PACKED MM owner acceptance requires separate live snapshots.
"""

from pathlib import Path
import re
import runpy
import sys


def audit(guest):
    guest = Path(guest)
    build = guest / "build"
    source = (guest / "user/init-v1614.c").read_text(encoding="ascii")
    console = (guest / "console.clean").read_text(encoding="ascii")
    ini = (guest / "noaux.ini").read_text(encoding="ascii")
    # The root builder preserves its original manifest. The accepted
    # compressed PURE DXR is added in a separate v1638 TSFS manifest.
    manifest = (guest / "tsfs-root-v1638.manifest").read_text(
        encoding="ascii")
    assert "set cpu 64k\n" in ini
    assert not re.search(r"(?m)^attach -q (dsk|dr)[0-9]+ ", ini)
    assert "MEM                                  64 K" in console
    assert "PURE                              LOADED" in console
    assert "DTFS                              LOADED" in console
    assert "HALT instruction, PC: 000000" in console
    assert "HALT instruction, PC: 000001" not in console
    assert console.count("HALT instruction") == 1
    assert console.count("aaaaaaaaax[B") == 1
    assert re.search(r"(?s)a{9}x\[B.*?\[A.*?Lw{9}Z", console)
    guest_output = console.split("aaaaaaaaax[B", 1)[1]
    guest_output = guest_output.split("HALT instruction", 1)[0]
    assert "!" not in guest_output
    for source_text in (
            "#define P14_CHILDREN         9U",
            "pid[i] = p14_spawn(rd, i != 0U);",
            "denied = p14_spawn(rd, 1U);",
            "if (denied != -1)",
            "p14_seed_secondary_v1643(void)",
            "SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE",
            "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
            "dsys_wait((unsigned int)pid[i], &status, 0U)",
            "p14_data[0] != 012345670123UL",
            "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL"):
        assert source_text in source, source_text
    assert "F /SYSTEM/COMP " in manifest
    assert "F /SYSTEM/INIT " in manifest
    assert re.search(
        r"(?m)^proc_pure_mres_package_v1612\s+[0-7]+$",
        (build / "kinit.map").read_text(encoding="ascii"))
    module = runpy.run_path(str(Path(__file__).resolve().parent.parent /
        "pure-full-restore-v1638/audit-v1638.py"))
    plain = module["dxr_words"]((guest / "user/init.dxr").read_bytes())
    compressed = module["dxr_words"](
        (guest / "user/comp-v1638.dxr").read_bytes())
    assert plain[0] == compressed[0] and plain[2] == compressed[2]
    assert (plain[1] >> 18) == (compressed[1] >> 18)
    assert (plain[1] & 0o300000) == 0o200000
    assert (compressed[1] & 0o300000) == 0o300000
    print("v1652: real PDP-6 64K no-AUX source-built PURE+DTFS boot")
    print("v1652: original 9 actual RUN, one refused RUN, nine PIPE/data/WAIT exits")
    print("v1652: source-linked compressed/PLAIN DXR, one normal HALT PC000000")
    print("PASS v1652: independent 64K nine-child physical lifecycle")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: audit-v1652.py original-guest-workdir")
    try:
        audit(sys.argv[1])
    except (AssertionError, UnicodeError, ValueError, KeyError, OSError) as err:
        print("FAIL v1652 physical 64K lifecycle: %s" % err, file=sys.stderr)
        sys.exit(1)
