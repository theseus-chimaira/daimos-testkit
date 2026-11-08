#!/usr/bin/env python3
"""Isolated, full-set MRES relink and KINIT packaging for D6CODEC.

Replays the actual dlink MRES recipes from DAIMOS's current Makefile,
with *only* output paths and the selected KCORE map replaced. No
production object, boot image, make target or media is overwritten.
"""
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


def run(args):
    print("RUN", Path(str(args[0])).name, "args", len(args), flush=True)
    subprocess.run([str(x) for x in args], check=True)


def build_variables(repo, names):
    # Query the actual Makefile configuration, not duplicated lists.
    show = "print-v1370:; @printf '%s\\n' " + " ".join(
        '"%s=%s"' % (n, "$(%s)" % n) for n in names)
    out = subprocess.check_output(
        ["make", "-s", "-C", str(repo / "system/boot/pdp6"),
         "--eval=" + show, "print-v1370"], text=True)
    return {a: b for a, b in (line.split("=", 1) for line in out.splitlines())}


def export_recipes(repo, pkg_names, production, grouped, outputs):
    """Return an argv pair for every active MRES package in the build."""
    text = (repo / "system/boot/pdp6/Makefile").read_text()
    var_paths = {}
    for name, path in re.findall(
            r"(?m)^([A-Z0-9_]+_MRES_OBJ(?:_V[0-9]+)?)\s*=\s*\$\(BUILD\)/([^\s]+\.dobj)", text):
        var_paths[production / path] = name

    recipes = {}
    active = None
    lines = text.splitlines()
    for i, line in enumerate(lines):
        heading = re.match(r"^\$\(([A-Z0-9_]+_MRES_OBJ(?:_V[0-9]+)?)\):", line)
        if heading:
            active = heading.group(1)
        if not line.lstrip().startswith("$(DLINK) -b 0 -A $(KCORE_MAP)"):
            continue
        if active is None:
            raise ValueError("MRES dlink has no matching target")
        command = line.strip()
        following = i
        while command.endswith("\\"):
            following += 1
            command = command[:-1] + " " + lines[following].strip()
        if "-R $@" not in command:
            raise ValueError("MRES recipe lacks output -R: " + active)
        if active in recipes:
            raise ValueError("duplicate MRES recipe: " + active)
        recipes[active] = command

    selected = {}
    for original in pkg_names:
        var = var_paths.get(original)
        if var is None or var not in recipes:
            raise ValueError("missing MRES recipe for " + str(original))
        command = recipes[var]
        for key, value in {
            "DLINK": str(Path(os.environ.get("PDP10_PREFIX", str(Path.home() / "cross"))) / "bin/dlink"),
            "BUILD": str(production),
            "GE_MRES_FOLD_PLAN": str(production / "ge-mres.fold"),
            "TTY_MRES_FOLD_PLAN": str(production / "tty-mres.fold"),
            "DTFS_MRES_FOLD_PLAN": str(production / "dtfs-mres.fold"),
            "D6FS_MRES_FOLD_PLAN": str(production / "d6fs-mres.fold"),
            "KCORE_MAP": str(production / "kcore.map"),
        }.items():
            command = command.replace("$(" + key + ")", value)
        if re.search(r"\$\(|\$@", command.replace("$@", "")):
            raise ValueError("unsupported MRES Makefile expansion: " + var)
        args = shlex.split(command)
        if args.count("-R") != 1 or args.count("-M") != 1 or args.count("-o") != 1:
            raise ValueError("unsupported MRES link recipe: " + var)
        def new_args(base, mapfile):
            updated = args[:]
            updated[updated.index("-A") + 1] = str(mapfile)
            for opt, suffix in (("-R", ".dobj"), ("-M", ".map"), ("-o", ".dxr")):
                old = Path(updated[updated.index(opt) + 1])
                if old.parent != production and opt != "-R":
                    raise ValueError("MRES link would publish outside build")
                if opt == "-R":
                    if old != Path("$@"):
                        raise ValueError("unexpected -R target")
                    file = original.name
                else:
                    file = old.name
                updated[updated.index(opt) + 1] = str(base / file)
            return updated
        selected[original] = (
            new_args(outputs / "original", production / "kcore.map"),
            new_args(outputs / "grouped", grouped))
    return selected


def read_map(path):
    found = {}
    for row in Path(path).read_text().splitlines():
        fields = row.split()
        if len(fields) >= 2 and re.fullmatch("[0-7]+", fields[1]):
            found[fields[0]] = int(fields[1], 8)
    return found


def obj_header(prefix, path):
    return subprocess.check_output(
        [str(prefix / "bin/pdp10-dec-none-objdump"), "-h", str(path)],
        text=True)


def main(repo, grouped_dir, work):
    repo, grouped_dir, work = map(lambda x: Path(x).resolve(), (repo, grouped_dir, work))
    production = repo / "build/system/boot/pdp6"
    work.mkdir(parents=True, exist_ok=True)
    for folder in ("original", "grouped"):
        (work / folder).mkdir(exist_ok=True)
    prefix = Path(os.environ.get("PDP10_PREFIX", str(Path.home() / "cross")))
    dlink, das, dxrconvert, mkstream = (
        prefix / "bin" / x for x in ("dlink", "das", "dxrconvert", "mkstream"))
    vars = build_variables(repo, ["MINIT_TABLE_OBJ", "KCORE_EMBED_OBJ", "KINIT_OBJS",
                                  "MRES_PACKAGE_OBJS", "KINIT_LATE_OBJS", "END_OBJ"])
    packages = [Path(x) for x in shlex.split(vars["MRES_PACKAGE_OBJS"])]
    if len(packages) < 20 or len(set(packages)) != len(packages):
        raise ValueError("unexpected active MRES package inventory")
    grouped_map = grouped_dir / "grouped-reserved-regenerated-v1368.map"
    grouped_stream = grouped_dir / "grouped-reserved-regenerated-v1368.stream"
    for source in (grouped_map, grouped_stream, production / "kinit.dxr"):
        if not source.is_file():
            raise ValueError("missing KCORE/KINIT artifact " + str(source))
    recipes = export_recipes(repo, packages, production, grouped_map, work)

    # Verify every build recipe against the unmodified normal output.
    # This detects semantic changes in the Makefile before use.
    for idx, original in enumerate(packages, 1):
        control, grouped = recipes[original]
        run(control)
        linked = work / "original" / original.name
        if linked.read_bytes() != original.read_bytes():
            raise RuntimeError("baseline MRES differs: " + original.name)
        run(grouped)
        grouped_obj = work / "grouped" / original.name
        original_size = re.search(r"mres: initialized=(\d+) bss=(\d+) resident=(\d+)",
                                  obj_header(prefix, linked))
        grouped_size = re.search(r"mres: initialized=(\d+) bss=(\d+) resident=(\d+)",
                                 obj_header(prefix, grouped_obj))
        if original_size is None or grouped_size is None:
            raise RuntimeError("unreadable MRES object " + original.name)
        if original_size.groups() != grouped_size.groups():
            raise RuntimeError("MRES residency changed " + original.name)
        print("MRES_V1370_PASS %d/%d %s resident=%s" %
              (idx, len(packages), original.name, grouped_size.group(3)), flush=True)

    def link_kinit(name, kernel_map, embed, grouped_mres):
        items = []
        for key in ("MINIT_TABLE_OBJ", "KCORE_EMBED_OBJ", "KINIT_OBJS",
                    "MRES_PACKAGE_OBJS", "KINIT_LATE_OBJS", "END_OBJ"):
            for word in shlex.split(vars[key]):
                path = Path(word)
                if key == "KCORE_EMBED_OBJ":
                    path = embed
                elif key == "MRES_PACKAGE_OBJS" and grouped_mres:
                    path = work / "grouped" / path.name
                if not path.is_file():
                    raise ValueError("missing KINIT input " + str(path))
                items.append(path)
        out = work / (name + ".dxr")
        mapfile = work / (name + ".map")
        run([dlink, "-b", "030000", "-A", kernel_map, "-o", out,
             "-M", mapfile, *items])
        return out, mapfile

    baseline, baseline_map = link_kinit("control-kinit-v1370",
                                       production / "kcore.map",
                                       Path(vars["KCORE_EMBED_OBJ"]), False)
    if baseline.read_bytes() != (production / "kinit.dxr").read_bytes():
        raise RuntimeError("KINIT control not identical to production")
    print("KINIT_BASELINE_EXACT_V1370", flush=True)

    lowcore = read_map(grouped_map)
    end = lowcore["__kcore_low_init_end"]
    if not 0o60 < end < 0o1000000:
        raise ValueError("grouped KCORE invalid initialized range")
    embed_src = work / "kcore-embed-v1370.s"
    embed_src.write_text(
        ".text\n.globl __kcore_load_begin\n.globl __kcore_load_end\n"
        "__kcore_load_begin:\n .block %o\n__kcore_load_end:\n" % (end - 0o60))
    embed_obj = work / "kcore-embed-v1370.dobj"
    run([das, "-F", "-C", "-O", embed_obj, embed_src])
    result, result_map = link_kinit("grouped-kinit-v1370", grouped_map,
                                   embed_obj, True)
    image_syms = read_map(result_map)
    if image_syms["__kcore_load_end"] - image_syms["__kcore_load_begin"] != end - 0o60:
        raise RuntimeError("KINIT grouped KCORE load slot is inconsistent")
    if image_syms["__kinit_image_end"] >= 0o1000000 - 0o400:
        raise RuntimeError("KINIT exceeds configured 256K physical geometry")
    print("KINIT_GROUPED_V1370_PASS entry=0%o load=[0%o,0%o)" %
          (image_syms["kinit_enter"], image_syms["__kcore_load_begin"],
           image_syms["__kcore_load_end"]), flush=True)

    image_rim = work / "grouped-kinit-v1370.rim"
    image_raw = work / "grouped-kinit-v1370.raw.words"
    image_words = work / "grouped-kinit-v1370.words"
    run([dxrconvert, "--simh", "-b", "030000", result, image_rim])
    run([mkstream, "-i", image_rim, "-o", image_raw, "-b", "030000",
         "-w", format(image_syms["__kinit_image_end"] - 0o30000, "o")])
    run(["sh", repo / "system/boot/pdp6/image/mkimage.sh", "--map", result_map,
         "--input", image_raw, "--kcore", grouped_stream, "--kcore-map", grouped_map,
         "--core-words", "01000000", "--stack-words", "0400", "--output", image_words])
    # Verify actual low-core decoder bytes were inserted, not an old slot.
    stream = [int(x, 8) for x in grouped_stream.read_text().splitlines()]
    installed = [int(x, 8) for x in image_words.read_text().splitlines()]
    at = image_syms["__kcore_load_begin"] - 0o30000 + 2
    if installed[at:at + len(stream) - 2] != stream[2:]:
        raise RuntimeError("grouped KCORE byte content not installed in KINIT")
    print("KINIT_GROUPED_INSTALL_V1370_PASS words=%d mres=%d" %
          (len(installed) - 2, len(packages)), flush=True)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: build_grouped_image_v1370.py DAIMOS_REPO V1368_KCORE_DIR WORKDIR")
    main(sys.argv[1], sys.argv[2], sys.argv[3])
