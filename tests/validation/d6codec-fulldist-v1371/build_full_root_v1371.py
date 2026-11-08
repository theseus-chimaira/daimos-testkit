#!/usr/bin/env python3
"""Construct a full grouped D6FS test root from DAIMOS's live Makefile.

Only versioned test outputs beneath WORK are written.  All 237 normal
files and all 29 normal directories come from D6FS_ROOT_ARGS, not from
a separately maintained distribution list.  Legacy D6LZ36 compressed
DXRs are rejected and replaced with verified grouped DXR2 payloads.
"""

import hashlib
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys


def load_codec(testkit):
    source = (testkit / "tests/validation/d6codec-runtime-exec-v1369" /
              "grouped_dxr_v1369.py")
    spec = importlib.util.spec_from_file_location("grouped_dxr_v1369", source)
    codec = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(codec)
    return codec


def run(argv, log=None):
    print("RUN", Path(str(argv[0])).name, "args", len(argv), flush=True)
    if log is None:
        subprocess.run([str(a) for a in argv], check=True)
    else:
        with Path(log).open("w") as out:
            subprocess.run([str(a) for a in argv], check=True,
                           stdout=out, stderr=subprocess.STDOUT)


def root_inventory(repo, work, userland):
    makefile = repo / "system/boot/pdp6"
    # Target is an in-memory make recipe used only to query the active
    # normal D6FS root list after Makefile expansion.  Quoted paths are
    # respected by the shell; printf prints one argument per output line.
    args = ["make", "-s", "-C", str(makefile),
            "BUILD=" + os.environ.get("V1372_NORMAL_BUILD", str(work / "normal-build")),
            "USERLAND_BUILD_ROOT=" + str(userland),
            "KCC_REPO=" + str(Path.home() / "git/kcc"),
            "DAS_REPO=" + str(Path.home() / "git/das"),
            "--eval=full-root-args-v1371:; @printf '%s\\n' $(D6FS_ROOT_ARGS)",
            "full-root-args-v1371"]
    lines = subprocess.check_output(args, text=True).splitlines()
    if len(lines) % 2:
        raise ValueError("invalid Makefile root argument count")
    pairs = [(lines[i], lines[i + 1]) for i in range(0, len(lines), 2)]
    if any(flag not in ("-D", "-f", "-l") for flag, _ in pairs):
        raise ValueError("unsupported D6FS root argument")
    files = [x for flag, x in pairs if flag == "-f"]
    directories = [x for flag, x in pairs if flag == "-D"]
    if len(files) < 200 or len(directories) < 20:
        raise ValueError("incomplete full distribution Makefile inventory")
    if len(files) != len(set(f.split(":", 1)[0] for f in files)):
        raise ValueError("duplicate root file paths")
    if len(directories) != len(set(d.split(":", 1)[0] for d in directories)):
        raise ValueError("duplicate root directory paths")
    (work / "root-args-expanded-v1371.txt").write_text("\n".join(lines) + "\n")
    return pairs


def stage_grouped(repo, testkit, work, userland, pairs):
    codec = load_codec(testkit)
    grouped = work / "grouped-dxr-v1371"
    grouped.mkdir(exist_ok=True)
    replaced = []
    inventory = []
    grouped_paths = set()
    old_count = 0
    exec_count = 0
    total_bytes = 0
    for option, value in pairs:
        if option != "-f":
            replaced.append((option, value))
            continue
        # File specs use PATH:HOST:MODE:format.  Never reinterpret a file
        # whose import format is not known to the Makefile root builder.
        target, host, mode, form = value.rsplit(":", 3)
        if form not in ("dxr", "binwords") or not re.fullmatch(r"[0-7]{3,4}", mode):
            raise ValueError("unsupported normal distribution format: " + value)
        if not target.startswith("/") or ".." in target.split("/"):
            raise ValueError("invalid filesystem path: " + target)
        if form == "binwords":
            source = Path(host)
            if not source.is_file():
                raise ValueError("missing normal distribution file: " + host)
            replaced.append((option, value))
            inventory.append((target, form, source, source))
            continue
        exec_count += 1
        legacy = host.endswith(".d6lz.dxr")
        source = Path(host[:-9] + ".dxr") if legacy else Path(host)
        if not source.is_file():
            raise ValueError("missing uncompressed DXR: " + str(source))
        source_words = codec.load(source)
        codec.unpack_original(source_words)
        if legacy:
            old_count += 1
            name = target.strip("/").replace("/", "_")
            output = grouped / (name + ".grouped-v1371.dxr")
            if output in grouped_paths:
                raise ValueError("grouped destination collision: " + target)
            grouped_paths.add(output)
            if output.is_file():
                output.unlink()
            codec.convert(source, output)
            image = codec.load(output)
            expected_header, decoded_words, _, _ = codec.unpack_original(source_words)
            if codec.validate_grouped(image) != source_words[
                    expected_header:expected_header + decoded_words]:
                raise ValueError("grouped roundtrip mismatch: " + target)
            if image[0] != source_words[0]:
                raise ValueError("changed executable entry: " + target)
            replaced.append((option, ":".join((target, str(output), mode, form))))
            inventory.append((target, "grouped", source, output))
            total_bytes += output.stat().st_size
        else:
            # Uncompressed INIT, MOUNTALL, native bootstraps and helper
            # DXRs remain unchanged.  Never admit a legacy compressed
            # executable here without a known, validated grouped source.
            replaced.append((option, value))
            inventory.append((target, "uncompressed", source, source))
    if not 50 <= old_count <= exec_count or exec_count < 80:
        raise ValueError("incomplete grouped DXR conversion inventory")
    if len(inventory) < 200:
        raise ValueError("incomplete file manifest")
    report = work / "root-inventory-v1371.txt"
    with report.open("w") as out:
        out.write("files=%d dxr=%d grouped=%d directories=%d\n" %
                  (len(inventory), exec_count, old_count,
                   sum(opt == "-D" for opt, _ in pairs)))
        for target, form, source, actual in inventory:
            digest = hashlib.sha256(actual.read_bytes()).hexdigest()
            out.write("%s %s %s %s\n" % (form, target,
                                            digest, actual.name))
    print("V1371_INVENTORY_PASS files=%d dxr=%d grouped=%d directories=%d grouped_bytes=%d" %
          (len(inventory), exec_count, old_count,
           sum(opt == "-D" for opt, _ in pairs), total_bytes), flush=True)
    return replaced


def make_root(testkit, repo, work, extras=()):
    v1370 = Path(os.environ.get("V1370_WORK", str(
        Path(os.environ.get("TMPDIR", str(Path.home() / "tmp"))) /
        "d6codec-fullboot-v1370"))).resolve()
    if not (v1370 / "grouped-kinit-v1370.compressed.words").is_file():
        raise ValueError("v1370 grouped boot artifacts missing; run v1370 first")
    userland = v1370 / "userland-build"
    if not (userland / "userland/init.dxr").is_file():
        raise ValueError("v1370 KCC userland build missing")
    pairs = root_inventory(repo, work, userland)
    args = stage_grouped(repo, testkit, work, userland, pairs)
    # Optional v1372 converter fixtures are appended only in the
    # isolated test image. Never replace a normal manifest file.
    existing = {value.split(":", 1)[0] for flag, value in args
                if flag == "-f"}
    for spec in extras:
        target, host, mode, kind = spec.rsplit(":", 3)
        allowed = ((target.startswith("/CONFIG/V1372") and
                    mode == "644" and kind == "binwords") or
                   (target == "/SYSTEM/EXEC/CSIX" and mode == "555" and
                    kind == "dxr"))
        if not allowed or target in existing or not Path(host).is_file():
            raise ValueError("invalid v1372 root extension: " + spec)
        existing.add(target)
        args.append(("-f", spec))
    if extras:
        print("V1372_EXTRA_FILES_PASS count=%d" % len(extras), flush=True)
    target = work / "disk-pristine-v1371"
    target.mkdir(exist_ok=True)
    prefix = Path(os.environ.get("PDP10_PREFIX", str(Path.home() / "cross")))
    bin_dir = prefix / "bin"
    run([bin_dir / "mkdsk", "-n", "4", "-m", "clean",
         "-p", v1370 / "grouped-kinit-v1370.compressed.words",
         "-o", target, "--d6fs-layout", "--logstore-blocks", "0400",
         "--swap-tail-blocks", "0400", "--spare-blocks", "0",
         "--member-sectors", "0130000,0130000,0130000,0130000"])
    flattened = [part for pair in args for part in pair]
    run([bin_dir / "mkd6fs", "-n", "4", "-d", target, *flattened],
        log=work / "mkd6fs-v1371.log")
    run([bin_dir / "logstore", "-n", "4", "-d", target, "--init"])
    run([bin_dir / "d6fsck", "-n", "4", "-d", target])
    print("V1371_ROOT_PASS full distribution D6FS built from normal Makefile", flush=True)


if __name__ == "__main__":
    if len(sys.argv) < 4 or (len(sys.argv) - 4) % 2:
        raise SystemExit("usage: build_full_root_v1371.py DAIMOS_REPO TESTKIT_REPO WORKDIR [--extra-file filesystem:host:mode:type]...")
    extras = []
    for i in range(4, len(sys.argv), 2):
        if sys.argv[i] != "--extra-file":
            raise SystemExit("unexpected option " + sys.argv[i])
        extras.append(sys.argv[i + 1])
    make_root(Path(sys.argv[2]).resolve(), Path(sys.argv[1]).resolve(),
              Path(sys.argv[3]).resolve(), extras)
