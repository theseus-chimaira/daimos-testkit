#!/usr/bin/env python3
"""Link isolated PDP-6 grouped-codec KCORE variants, never production.

The normal build's full object order and p10fold input scope are read
directly from its Makefile.  All output is written below TMPDIR.
"""
import hashlib
import os
from pathlib import Path
import re
import shlex
import struct
import subprocess
import sys


def run(argv, cwd=None, log=None):
    # Avoid printing dozens of absolute object paths for each dlink run.
    visible = [str(x) for x in argv[:6]]
    if len(argv) > len(visible):
        visible.append("... %d more arguments" % (len(argv) - len(visible)))
    print("RUN", " ".join(shlex.quote(x) for x in visible), flush=True)
    if log is None:
        subprocess.run([str(x) for x in argv], cwd=cwd, check=True)
    else:
        with Path(log).open("w") as output:
            subprocess.run([str(x) for x in argv], cwd=cwd, check=True,
                           stdout=output)


def make_objects(repo, variable):
    rule = "print-v1368:; @printf '%s\\n' '$({})'".format(variable)
    result = subprocess.check_output(
        ["make", "-s", "-C", str(repo / "system/boot/pdp6"),
         "--eval=" + rule, "print-v1368"], text=True)
    items = shlex.split(result)
    if not items or any(not Path(item).is_file() for item in items):
        raise RuntimeError("missing built objects for " + variable)
    return items


def dxr_info(path):
    data = Path(path).read_bytes()
    if len(data) < 16 or len(data) % 8:
        raise ValueError("bad DXR " + str(path))
    header = struct.unpack_from("<QQ", data)
    return header[1] >> 18, header[1] & 0o777777, hashlib.sha256(data).hexdigest()


def symbols(path):
    out = {}
    for line in path.read_text().splitlines():
        parts = line.split()
        if len(parts) >= 2 and re.fullmatch(r"[0-7]+", parts[1]):
            out[parts[0]] = int(parts[1], 8)
    return out


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: link-v1368.py DAIMOS_REPO WORKDIR")
    repo = Path(sys.argv[1]).resolve()
    work = Path(sys.argv[2]).resolve()
    work.mkdir(parents=True, exist_ok=True)
    tool_prefix = Path(os.environ.get("PDP10_PREFIX", str(Path.home() / "cross")))
    bin_dir = tool_prefix / "bin"
    das, dlink, p10fold = (bin_dir / x for x in ("das", "dlink", "p10fold"))
    gcc = bin_dir / "pdp10-dec-none-gcc"
    libgcc = subprocess.check_output(
        [str(gcc), "-print-libgcc-file-name"], text=True).strip()
    build = repo / "build/system/boot/pdp6"
    production = build / "kcore.dxr"
    production_map = build / "kcore.map"
    production_fold = build / "kcore.fold"
    all_objs = make_objects(repo, "KCORE_FIXED_OBJS")
    fold_objs = make_objects(repo, "KCORE_FOLD_OBJS")
    fixed = str(build / "d6lz_fixed.dobj")
    old_adapter = str(build / "d6lz.dobj")
    assert all_objs[0] == fixed and all_objs[2] == old_adapter
    assert all_objs[-1].endswith("/kcore_end.dobj")

    # ABI label substitution in test-owned assembly only. No old C or
    # assembler caller is edited, and the on-disk format is unchanged.
    adapter_src = repo / "system/kernel/core/d6codec_vfs_v1367.s"
    engine_src = repo / "system/kernel/core/d6codec_stream_v1367.s"
    adapter_text = adapter_src.read_text()
    adapter_text = adapter_text.replace(
        "d6codec_decode_vfs_v1367", "d6lz36_decode_vfs")
    adapter_text = adapter_text.replace(
        "d6codec_decode_buffer_v1367", "d6lz36_decode_buffer")
    alias_src = work / "d6codec-vfs-alias-v1368.s"
    alias_src.write_text(adapter_text)
    alias_obj = work / "d6codec-vfs-alias-v1368.dobj"
    engine_obj = work / "d6codec-stream-v1368.dobj"
    run([das, "-F", "-C", "-O", alias_obj, alias_src])
    run([das, "-F", "-C", "-O", engine_obj, engine_src])

    # A non-executable 40-word reservation preserves the previous
    # fixed decoder's physical slot and all subsequent linked offsets.
    # The reservation is deliberately NOT a second installed decoder.
    lowcore_src = work / "lowcore-reserved-v1368.s"
    lowcore_src.write_text(
        ".text\n.globl d6codec_lowcore_reserved_v1368\n"
        "d6codec_lowcore_reserved_v1368:\n .block 050\n")
    lowcore_obj = work / "lowcore-reserved-v1368.dobj"
    run([das, "-F", "-C", "-O", lowcore_obj, lowcore_src])

    def link(name, objlist, plan):
        dxr = work / (name + ".dxr")
        mapfile = work / (name + ".map")
        run([dlink, "-b", "060", "--fold-plan", plan, "-o", dxr,
             "-M", mapfile, *objlist, libgcc])
        return dxr_info(dxr), symbols(mapfile)

    # Verify there is no hidden mismatch between the current Makefile
    # and the archived production linked object/fold plan.
    baseline, base_symbols = link("baseline-v1368", all_objs, production_fold)
    expected = dxr_info(production)
    if baseline != expected or (work / "baseline-v1368.dxr").read_bytes() != production.read_bytes():
        raise RuntimeError("baseline KCORE is not byte-identical to production")
    print("BASELINE_EXACT_PASS text=%d bss=%d end=0%o" % (
        baseline[0], baseline[1], base_symbols["__kcore_low_end"]), flush=True)

    def grouped_list(lowcore):
        assembled = []
        for obj in all_objs:
            if obj == fixed:
                if lowcore == "legacy":
                    assembled.append(obj)
                elif lowcore == "reserved":
                    assembled.append(str(lowcore_obj))
                elif lowcore != "none":
                    raise AssertionError(lowcore)
            elif obj == old_adapter:
                assembled.extend((str(alias_obj), str(engine_obj)))
            else:
                assembled.append(obj)
        assert assembled[-1].endswith("/kcore_end.dobj")
        return assembled

    plans = {"production": production_fold}
    regenerated = work / "grouped-v1368.fold"
    run([p10fold, "-m", "2", "-P", regenerated,
         *fold_objs, alias_obj, engine_obj],
        log=work / "grouped-v1368.fold-analysis.txt")
    plans["regenerated"] = regenerated
    results = {}
    for mode in ("legacy", "reserved", "none"):
        for scope in ("production", "regenerated"):
            name = "grouped-%s-%s-v1368" % (mode, scope)
            info, syms = link(name, grouped_list(mode), plans[scope])
            for key in ("d6lz36_decode_vfs", "d6lz36_decode_buffer",
                        "d6codec_stream_v1367", "__kcore_low_end",
                        "__kcore_low_init_end"):
                if key not in syms:
                    raise RuntimeError("missing " + key + " in " + name)
            if mode != "legacy" and "d6lz36_decode_core" in syms:
                raise RuntimeError("legacy core present in grouped-only link")
            if mode == "reserved" and syms.get("exec_replace_current_lowmem") != base_symbols.get("exec_replace_current_lowmem"):
                raise RuntimeError("reserved lowcore moved early EXEC instructions")
            results[(mode, scope)] = (info, syms)
            print("LINK_PASS mode=%s fold=%s text=%d bss=%d delta_text=%+d delta_end=%+d end=0%o" %
                  (mode, scope, info[0], info[1], info[0] - baseline[0],
                   syms["__kcore_low_end"] - base_symbols["__kcore_low_end"],
                   syms["__kcore_low_end"]), flush=True)

    # Relink real MRES packages against the *new* KCORE symbols.  This
    # proves their references (including EXEC/PURE and TSFS decode
    # entries) resolve against the candidate relocation map, without
    # installing a MRES or modifying an existing image.
    packages = {
        "swap": {
            "objects": ["proc_swap_mres_v481", "backstore_mres_v484"],
            "name": "proc_swap_mres_package_v481",
            "exports": ["proc_swap_mres_reclaim_v481", "proc_swap_mres_service_v481",
                        "backstore_mres_bitmap_words_v484", "backstore_mres_init_v484",
                        "backstore_mres_alloc_v484", "backstore_mres_free_v484",
                        "backstore_mres_verify_allocated_v880"],
            "existing": "swapv481-mres.dobj",
        },
        "dtfs": {
            "objects": ["dtfs", "dtfs_runtime", "tsfs", "tsfs_runtime"],
            "name": "dtfs_mres_package",
            "exports": ["dtfs_mres_dispatch", "dtfs_dtc_read_jump",
                        "dtfs_dtc_write_jump", "dtfs_mount_unit", "tsfs_mres_dispatch",
                        "dtfs_dir"],
            "fold": "dtfs-mres.fold", "existing": "dtfs-mres.dobj",
        },
        "d6fs": {
            "objects": ["fs_backing", "d6fs_provider", "d6fs_validate", "d6fs_runtime"],
            "name": "d6fs_mres_package",
            "exports": ["d6fs_mres_dispatch", "fs_backing_root_read",
                        "fs_backing_root_write", "fs_backing_root_read_jump",
                        "fs_backing_root_write_jump", "fs_backing_direct_read",
                        "fs_backing_direct_write", "fs_backing_direct_read_jump",
                        "fs_backing_direct_write_jump", "fs_backing_direct_drm_read_jump",
                        "fs_backing_direct_drm_write_jump",
                        "fs_backing_direct_root_read_call",
                        "fs_backing_direct_root_write_call",
                        "fs_backing_direct_root_drm_read_call",
                        "fs_backing_direct_root_drm_write_call",
                        "clkbind_dfr0", "clkbind_dfr1", "clkbind_dfm0",
                        "clkbind_dfn0"],
            "fold": "d6fs-mres.fold", "existing": "d6fs-mres.dobj",
        },
        "monitorfs": {
            "objects": ["monitorfs_mres_v16", "monitorfs_swap_v63_mres"],
            "name": "monitorfs_mres_package",
            "exports": ["mfsdev_lookup_mres_v15", "mfsdev_readdir_mres_v15",
                        "mfsdev_stat_mres_v15", "mfsdev_readchar_mres_v15",
                        "mfsproc_lookup_mres_v15", "mfsproc_readdir_mres_v15",
                        "mfsproc_stat_mres_v15", "mfsproc_read_words_mres_v15",
                        "mfsproc_format_slot_mres_v15"],
            "existing": "monitorfs-mres.dobj",
        },
        "tape": {
            "objects": ["tape_io"], "name": "tape_mres_package",
            "exports": ["tape_pi_handler", "dtc_read_block", "mtc_service",
                        "dtc_write_block", "tape_dct_handler",
                        "tape_watchdog_tick_v1089"],
            "existing": "tape-mres.dobj",
        },
    }
    def mres_link(package, map_path, prefix):
        spec = packages[package]
        output = work / (prefix + "-" + package + "-v1368.dobj")
        dxr = work / (prefix + "-" + package + "-v1368.dxr")
        mapfile = work / (prefix + "-" + package + "-v1368.map")
        argv = [dlink, "-b", "0", "-A", map_path, "-o", dxr,
                "-M", mapfile]
        if "fold" in spec:
            argv.extend(("--fold-plan", build / spec["fold"]))
        argv.extend(("-R", output, "-N", spec["name"]))
        for symbol in spec["exports"]:
            argv.extend(("-X", symbol))
        argv.extend(build / (x + ".dobj") for x in spec["objects"])
        run(argv)
        if not output.is_file():
            raise RuntimeError("missing MRES output " + str(output))
        return output

    # First prove the normal MRES recipe reproduces archived outputs.
    for package, spec in packages.items():
        produced = mres_link(package, production_map, "original")
        expected_mres = build / spec["existing"]
        if produced.read_bytes() != expected_mres.read_bytes():
            raise RuntimeError("baseline MRES differs for " + package)
        print("MRES_BASELINE_EXACT_PASS package=" + package, flush=True)
        original_mres_header = subprocess.check_output(
            [str(bin_dir / "pdp10-dec-none-objdump"), "-h", str(produced)],
            text=True)
        original_size = re.search(
            r"mres: initialized=(\d+) bss=(\d+) resident=(\d+)",
            original_mres_header)
        if original_size is None:
            raise RuntimeError("unrecognized MRES header for " + package)
        for mode in ("reserved", "none"):
            modified = mres_link(
                package, work / ("grouped-%s-regenerated-v1368.map" % mode),
                mode)
            mres_header = subprocess.check_output(
                [str(bin_dir / "pdp10-dec-none-objdump"), "-h", str(modified)],
                text=True)
            size = re.search(
                r"mres: initialized=(\d+) bss=(\d+) resident=(\d+)",
                mres_header)
            if size is None or size.groups() != original_size.groups():
                raise RuntimeError("MRES residency changed for %s %s" %
                                   (package, mode))
            print("MRES_LINK_PASS package=%s grouped=%s resident=%s" %
                  (package, mode, size.group(3)), flush=True)

    # Check the actual KINIT install artifacts, not only DXR linking.
    # A KCORE with a new low-core geometry must generate its own image
    # boundary; reusing the old stream would truncate newly linked code.
    for name in ("baseline-v1368", "grouped-reserved-regenerated-v1368",
                 "grouped-none-regenerated-v1368"):
        mapfile = work / (name + ".map")
        lowend = symbols(mapfile)["__kcore_low_init_end"]
        if lowend <= 0o60:
            raise RuntimeError("invalid KCORE initialized end")
        rim = work / (name + ".rim")
        stream = work / (name + ".stream")
        run([bin_dir / "dxrconvert", "--simh", "-b", "060",
             work / (name + ".dxr"), rim])
        run([bin_dir / "mkstream", "-i", rim, "-o", stream,
             "-b", "060", "-w", format(lowend - 0o60, "o")])
        if not rim.is_file() or not stream.is_file() or stream.stat().st_size == 0:
            raise RuntimeError("no KCORE initialization stream for " + name)
        if name == "baseline-v1368":
            for extension in ("rim", "stream"):
                if (work / (name + "." + extension)).read_bytes() != (build / ("kcore." + extension)).read_bytes():
                    raise RuntimeError("baseline KCORE %s differs" % extension)
        print("KCORE_IMAGE_PASS name=%s init_end=0%o" %
              (name, lowend), flush=True)

    # Record only test-local results, so the normal build remains intact.
    report = work / "report-v1368.txt"
    with report.open("w") as out:
        out.write("baseline_text=%d baseline_bss=%d baseline_end=0%o\n" %
                  (baseline[0], baseline[1], base_symbols["__kcore_low_end"]))
        for (mode, scope), (info, syms) in sorted(results.items()):
            out.write("%s %s text=%d bss=%d delta=%+d end=0%o\n" %
                      (mode, scope, info[0], info[1], info[0] - baseline[0],
                       syms["__kcore_low_end"]))
    print("PASS v1368 KCORE and five MRES package relocation tests: " + str(report), flush=True)


if __name__ == "__main__":
    main()
