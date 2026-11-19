#!/usr/bin/env python3
"""Native v1674 oracle tests: staging writes never inflate committed peak."""

import importlib.util
from pathlib import Path


HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("v1674_trace", HERE / "trace-v1674.py")
trace = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trace)


def event(pc, addr, value):
    return "Breakpoint, PC: %06o (TEST)\n%o:\t%012o\n" % (
        pc, addr, value)


def run():
    addresses = dict(mm_extents=0o24102, mm_extent_count=0o23471,
                     mm_process_shrink_pinned=0o2277,
                     mm_process_grow_pinned=0o2341,
                     mm_pin=0o2473, mm_extent_insert=0o1222,
                     mm_is_pinned=0o1267)
    watched = set(range(0o24102, 0o24102 + 64)) | {0o23471}
    shadow = {0o23471: 10, 0o24102: 5, 0o24104: 6}
    original_decode = trace.P1670.decode

    def physical(state, addresses, core, index):
        # Deliberately make an intermediate descriptor shift look
        # geometrically valid and much larger than the true allocation.
        # The high-water oracle must not include this non-commit.
        v = state["words"][0o24102]
        free = 1 if v == 900 else 100
        return dict(free=free, largest_free=free,
                    allocated=200-free, extents=10,
                    by_type={"1": 200-free},
                    occupied_or_reserved=core * 1024 - free)

    trace.P1670.decode = physical
    try:
        window = (event(0o1251, 0o24102, 900) +
                  event(0o1252, 0o24102, 5) +
                  event(0o1253, 0o23471, 11) +
                  event(0o2317, 0o24104, 33) +
                  event(0o22163, 0o24106, 33))
        report, length = trace.replay(window, watched, shadow, addresses, 0)
        assert length == 5
        assert report["commits"] == 1
        assert report["resizes"] == 2
        assert report["pure_span_events"] == 1
        assert report["staging_writes"] == 2
        assert [x["free"] for x in report["stable"]] == [100, 100, 100]
        assert not any(x["free"] == 1 for x in report["stable"])
        try:
            trace.replay(event(0o1253, 0o23472, 11), watched,
                         shadow, addresses, 0)
        except ValueError as exc:
            assert "unwatched" in str(exc)
        else:
            raise AssertionError("unknown physical address accepted")
        try:
            trace.replay("Breakpoint, PC: 001253\n", watched,
                         shadow, addresses, 0)
        except ValueError as exc:
            assert "unpaired" in str(exc)
        else:
            raise AssertionError("unpaired breakpoint accepted")
    finally:
        trace.P1670.decode = original_decode
    print("PASS v1674 native: count/resize high-water excludes valid "
          "but uncommitted descriptor shifts and rejects bad watches")


if __name__ == "__main__":
    run()
