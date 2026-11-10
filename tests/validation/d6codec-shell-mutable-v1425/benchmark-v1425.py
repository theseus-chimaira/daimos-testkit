#!/usr/bin/env python3
"""Model mutable DAIMOS DSH memory and compare two native word codecs.

This is a reproducible SYNTHETIC process state, not a SIMH memory dump.
The executable text tail and initialized DATA come from the actual
built DSH DXR; BSS shapes and heap conventions follow DSH sources.
All counts refer to physical 36-bit words, never eight-byte host slots.
"""
import argparse
import csv
import importlib.util
import json
from pathlib import Path
import random
import re
import struct

ROOT = Path(__file__).resolve().parents[3]
MASK18 = (1 << 18) - 1
MASK36 = (1 << 36) - 1
ORIGIN = 0o20
SECTOR = 0o200
APR_BLOCK = 0o2000
STACK_RESERVE = 0o2000
DSH_S6_WORDS = 6


def import_from(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


GROUPED = import_from(
    ROOT / "tests/validation/d6codec-fastpath-v1420/generate-v1420.py",
    "d6codec_grouped_v1420")
BLOCK = import_from(
    ROOT / "tests/validation/d6codec-block-v1421/generate-v1421.py",
    "d6codec_block_v1421")


def roundup(n, quantum):
    return (n + quantum - 1) // quantum * quantum


def dxr_image(path):
    contents = path.read_bytes()
    if len(contents) % 8:
        raise ValueError("DXR is not 64-bit host-word packed")
    words = list(struct.unpack("<%dQ" % (len(contents) // 8), contents))
    if any(w > MASK36 for w in words):
        raise ValueError("non-36-bit data in DXR")
    image_words, flags = words[1] >> 18, words[1] & MASK18
    bss_words = flags & 0o77777
    if (words[0] >> 18) != 0o447062 or (words[2] & MASK18) != 0o647022:
        raise ValueError("expected genuine DSH DXR2/TX2 header")
    text_words = words[2] >> 18
    reloc_words = roundup(image_words, 36) // 36
    if len(words) != 3 + image_words + reloc_words:
        raise ValueError("DXR word count contradicts header")
    if not (0 < text_words <= image_words):
        raise ValueError("invalid text/data geometry")
    return {
        "payload": words[3:3 + image_words],
        "image_words": image_words,
        "bss_words": bss_words,
        "text_words": text_words,
        "pure": bool(flags & 0o200000),
        "compressed": bool(flags & 0o100000),
    }


def bss_declarations(build_dir):
    """Read sizes of actual compiler-generated DSH .bss objects.

    We arrange individual static objects in a convenient model order.
    Linker placement beyond individual source object declarations is
    deliberately NOT asserted to equal the live guest memory layout.
    """
    files = (
        "dsh.s", "dsh_exec.s", "dsh_env.s", "dsh_heap.s")
    result = {}
    cursor = 0
    for file in files:
        path = build_dir / file
        source = path.read_text()
        section = source.split("\n\t.bss\n", 1)[1].split(
            "\n\t.text", 1)[0]
        lines = section.splitlines()
        for index, line in enumerate(lines):
            match = re.fullmatch(r"([a-z][a-z0-9_]*):", line.strip())
            if not match:
                continue
            nxt = lines[index + 1].strip() if index + 1 < len(lines) else ""
            size = re.fullmatch(r"\.space ([0-9]+)", nxt)
            if size is None:
                continue
            count = int(size.group(1))
            # KCC produces .space in 9-bit byte positions, four per
            # 36-bit machine word.
            if count % 4:
                raise ValueError("unaligned BSS symbol " + match.group(1))
            result[match.group(1)] = (cursor, count // 4)
            cursor += count // 4
    return result, cursor


def sixbit_words(s):
    if not all(32 <= ord(ch) <= 95 for ch in s):
        raise ValueError("unsupported SIXBIT shell string: " + s)
    result = []
    for start in range(0, len(s), 6):
        word = 0
        for ch in s[start:start + 6]:
            word = (word << 6) | (ord(ch) - 32)
        word <<= 6 * (6 - len(s[start:start + 6]))
        result.append(word)
    return result


def s6_struct(s):
    if len(s) > 36:
        raise ValueError("dsh_s6 maximum is 36 characters")
    words = sixbit_words(s)
    return [len(s)] + words + [0] * (DSH_S6_WORDS - len(words))


ENV = [
    ("HOME", "/ROOT"), ("USER", "ROOT"),
    ("PATH", "/SYSTEM/EXEC:/OPTION/BASE/EXEC"),
    ("PWD", "/"), ("PS1", "DSH> "),
    ("TERM", "VT100"), ("SHELL", "/SYSTEM/EXEC/DSH"),
    ("LANG", "C"), ("TMP", "/TEMP"), ("EDITOR", "EDIT"),
    ("HOST", "DAIMOS"), ("PS2", "> "), ("CONFIG", "/CONFIG"),
    ("LOGNAME", "ROOT"), ("OLDPWD", "/SYSTEM"),
    ("HISTFILE", "/ROOT/.DSH_HISTORY"), ("X", "1234"),
    ("Y", "TEST"), ("MODE", "INTERACTIVE"),
    ("COLOR", "GREEN")
]


PROFILES = {
    "after_exec": dict(vars=0, aliases=0, jobs=0,
                       stack_used=0, active=False, function=False),
    "idle_prompt": dict(vars=6, aliases=0, jobs=0,
                        stack_used=350, active=False, function=False),
    "running_command": dict(vars=12, aliases=2, jobs=1,
                            stack_used=545, active=True, function=False),
    "function_heavy": dict(vars=20, aliases=4, jobs=2,
                           stack_used=690, active=True, function=True),
    "incompressible_control": dict(vars=0, aliases=0, jobs=0,
                                   stack_used=0, active=False,
                                   function=False, randomize=True)
}


def make_snapshot(dxr, layout, bss_declared, profile_name):
    model = PROFILES[profile_name]
    n = dxr["image_words"]
    bss = dxr["bss_words"]
    text = dxr["text_words"]
    initial_vm = roundup(ORIGIN + n + bss + STACK_RESERVE, APR_BLOCK)
    text_skip = (ORIGIN + text) // SECTOR * SECTOR
    output = [0] * initial_vm
    output[ORIGIN:ORIGIN + n] = dxr["payload"]
    bss_base = ORIGIN + n
    stack_base = initial_vm - STACK_RESERVE

    def put(address, words):
        if address < 0 or address + len(words) > len(output):
            raise ValueError("out-of-bounds model write")
        output[address:address + len(words)] = [
            x & MASK36 for x in words]

    def sym(name):
        if name not in layout:
            raise ValueError("missing source-derived DSH symbol " + name)
        base, size = layout[name]
        return bss_base + base, size

    main, main_words = sym("dsh_main_state")
    assert main_words == 454
    # DSH structs: 64 variable descriptors * 2, 8 aliases * 15,
    # 4 jobs * 12, arg0 * 7, 20 args * 7, and 11 scalar fields.
    assert 64 * 2 + 8 * 15 + 4 * 12 + 7 + 20 * 7 + 11 == main_words

    # The real loader zeroes the complete rounded physical VM.
    # A modeled command startup area holds counted SIXBIT argv/envp.
    launch = ["DSH"] + [
        "%s=%s" % (key, value) for key, value in ENV[:model["vars"]]
        if len("%s=%s" % (key, value)) <= 102]
    cursor = stack_base + 1 + len(launch) + 1
    put(stack_base, [((1 << 18) | (len(launch) - 1))])
    for index, item in enumerate(launch):
        packed = sixbit_words(item)
        put(stack_base + 1 + index, [cursor])
        put(cursor, [len(item)] + packed)
        cursor += 1 + len(packed)

    # A 337-word main() stack frame is visible in compiled dsh.s
    # (octal 0521). Most of its script-token workspace is zero
    # outside commands, unlike random-noise synthetic benchmarks.
    rng = random.Random(0xD510 + len(profile_name))
    for i in range(model["stack_used"]):
        at = cursor + i
        if at >= initial_vm:
            raise ValueError("sample exceeds the 1024-word startup stack")
        if i % 19 == 0:
            output[at] = (0o400000 << 18) | rng.randrange(0o10000, 0o40000)
        elif i % 11 == 0:
            output[at] = rng.randrange(1, 0o77777)
        elif model["active"] and i % 17 == 0:
            output[at] = rng.getrandbits(36)

    # The heap begins at the end of the initial allocated VM, per
    # PROC_BRK_OFFSET and dsh_heap_alloc(). It grows the physical VM
    # in 1024-word units even for much smaller logical allocations.
    heap_base = initial_vm
    heap_cursor = heap_base

    def alloc(payload):
        nonlocal heap_cursor
        size = len(payload) + 2
        where = heap_cursor
        heap_cursor += size
        required = roundup(heap_cursor, APR_BLOCK)
        if len(output) < required:
            output.extend([0] * (required - len(output)))
        put(where, [size, 0] + payload)
        return where + 2

    for i, (name, value) in enumerate(ENV[:model["vars"]]):
        nwords = sixbit_words(name)
        vwords = sixbit_words(value)
        payload = nwords + vwords
        ptr = alloc(payload)
        meta = (0o600000 << 18) | (len(vwords) * 6 << 6) | len(name)
        put(main + 2 * i, [meta, ptr])

    # Sparse aliases and inactive jobs have the exact widths of their
    # C structs. The model intentionally does not pretend that an
    # unknown user session has these particular values.
    for i in range(model["aliases"]):
        pos = main + 128 + i * 15
        put(pos, [1] + s6_struct("L" + str(i)) +
            s6_struct("LS /SYSTEM"))
    for i in range(model["jobs"]):
        pos = main + 128 + 120 + i * 12
        put(pos, [1, 100 + i, 100 + i, 1, 0] +
            s6_struct("SLEEP 1"))
    put(main + 128 + 120 + 48, s6_struct("DSH"))
    # Scalar field positions follow dsh.h; these are modeled values.
    put(main + 443, [0, 0, 1, int(model["active"]), 0, 0, 0, 0, 0, 0, 3])

    if model["active"]:
        cmd = "LS /SYSTEM/EXEC"
        loc, _ = sym("dsh_input_line")
        put(loc, [len(cmd)] + sixbit_words(cmd))
        run, _ = sym("dsh_run_block")
        run_words = [3, 1, 0o200000, len(cmd)] + sixbit_words(cmd)
        put(run, run_words)
        inline, _ = sym("dsh_inline_node")
        put(inline, [1, MASK18, MASK18, MASK18, 2, 0] +
            s6_struct("LS") + s6_struct("WC"))
        busy, _ = sym("dsh_inline_busy")
        put(busy, [1])
        active, _ = sym("dsh_nodes_active")
        put(active, [1])
        # A wide 20-argument expansion uses 20 * 7 = 140 words
        # plus the DSH two-word heap allocation header.
        if model["vars"] > 0:
            args = [0] * 140
            args[0:7] = s6_struct("LS")
            args[7:14] = s6_struct("/SYSTEM/EXEC")
            alloc(args)

    if model["function"]:
        # DSH_FUNC_MAX_NODES=8, and each dsh_node is 200 words.
        # Defining a function acquires 1600 heap words, even when
        # most of its node records are unused/zero.
        function_words = [0] * 1600
        for i in range(6):
            function_words[200 * i:200 * i + 6] = [
                1, MASK18, MASK18, MASK18, 1, 0]
            function_words[200 * i + 6:200 * i + 13] = s6_struct("ECHO")
        fn_ptr = alloc(function_words)
        fn, _ = sym("dsh_function_nodes")
        put(fn, [fn_ptr])
        used, _ = sym("dsh_function_nodes_used")
        put(used, [6])
        funcs, _ = sym("dsh_functions")
        put(funcs, [1] + s6_struct("FN") + [0, 0, 6])

    if model.get("randomize"):
        # Deliberate incompressible bound, NOT a plausible idle shell.
        for p in range(text_skip, len(output)):
            output[p] = rng.getrandbits(36)

    if bss_declared > bss:
        raise ValueError("modeled BSS exceeds actual linked DXR BSS")
    if not (initial_vm <= len(output) <= initial_vm + 2 * APR_BLOCK):
        raise ValueError("unexpected heap growth")
    return {
        "words": output,
        "physical_prefix": text_skip,
        "writable_start": ORIGIN + text,
        "initial_vm": initial_vm,
        "logical_heap_words": heap_cursor - heap_base,
        "modeled_bss_words": bss_declared,
        "actual_bss_words": bss,
        "stack_base": stack_base,
    }


def compress_words(words):
    grouped_stream = GROUPED.encode(words)
    block_stream = BLOCK.encode(words)
    if GROUPED.dxr.decode(grouped_stream, len(words)) != words:
        raise ValueError("grouped compressed roundtrip failure")
    if BLOCK.decode(block_stream, len(words)) != words:
        raise ValueError("block compressed roundtrip failure")
    return grouped_stream, block_stream


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dxr", required=True, type=Path)
    parser.add_argument("--dsh-asm", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--native-fixtures", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    dxr = dxr_image(args.dxr)
    layout, declared = bss_declarations(args.dsh_asm)
    observations = []
    metadata = {k: v for k, v in dxr.items() if k != "payload"}
    metadata["bss_declared_source_words"] = declared
    metadata["profiles"] = {}
    for name in PROFILES:
        snapshot = make_snapshot(dxr, layout, declared, name)
        metadata["profiles"][name] = {
            k: v for k, v in snapshot.items() if k != "words"}
        full = snapshot["words"]
        for region, source in (
            ("physical_sector_suffix", full[snapshot["physical_prefix"]:]),
            ("writable_only", full[snapshot["writable_start"]:])):
            grouped_stream, block_stream = compress_words(source)
            row = {
                "scenario": name, "region": region,
                "raw_words": len(source),
                "nonzero_words": sum(w != 0 for w in source),
                "grouped_words": len(grouped_stream),
                "block_words": len(block_stream),
                "grouped_pct": round(100 * len(grouped_stream) / len(source), 2),
                "block_pct": round(100 * len(block_stream) / len(source), 2),
            }
            observations.append(row)
            if args.native_fixtures and region == "physical_sector_suffix":
                for fmt, packed, version in (
                    ("grouped", grouped_stream, "v1420"),
                    ("block", block_stream, "v1424")):
                    path = args.output / (
                        "%s_%s_v1425.s" % (name, fmt))
                    GROUPED.emit(path, source, packed, True, (), version=version)
            print("%s %-23s raw=%4d nonzero=%4d group=%4d block=%4d" % (
                name, region, len(source), row["nonzero_words"],
                len(grouped_stream), len(block_stream)), flush=True)
    columns = list(observations[0])
    with (args.output / "results-v1425.tsv").open("w") as f:
        writer = csv.DictWriter(f, fieldnames=columns, delimiter="\t")
        writer.writeheader()
        writer.writerows(observations)
    (args.output / "model-v1425.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n")
    print("PASS v1425 host roundtrips and deterministic DSH memory model")


if __name__ == "__main__":
    main()
