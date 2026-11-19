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




def source_fixture_contract():
    pid1 = (HERE / "proc-pressure-v1674.c").read_text(encoding="ascii")
    child = (HERE / "pipe-child-v1674.s").read_text(encoding="ascii")
    # RUN_FD_MAP(child_fd, parent_fd): reversed arguments silently
    # map the parent's CTY instead of the PIPE reader into child fd0.
    assert "SYS_RUN_FD_MAP(0U, (unsigned int)readfd)" in pid1
    assert "SYS_RUN_FD_MAP((unsigned int)readfd, 0U)" not in pid1
    assert "dsys_pipe()" in pid1
    assert "dsys_write_words(pipe_write_fd, &release_token, 1U)" in pid1
    assert "V1674 PIPE RELEASED" in pid1
    assert "uuo 055,0(1)" in child
    assert "uuo 061,0(1)" not in child
    assert "movei 01,052" in child  # actual BRK extension selector
    assert "uuo 077,0(1)" in child
    assert "came 04,[01234567]" in child
    # The original v1673 CTY oracle rejects repeated physical words.
    # Reading mm_extent_capacity a second time during A setup broke the
    # original full physical run despite an otherwise valid guest.
    monitor_source = (HERE / "host-cty-v1674.py").read_text(
        encoding="ascii")
    assert "capacity = read_word(snapshot_text, source_symbol(" in monitor_source
    assert "capacity = examine_word(" not in monitor_source

def run():
    source_fixture_contract()
    addresses = dict(mm_extents=0o24102, mm_extent_count=0o23471,
                     mm_process_shrink_pinned=0o2277,
                     mm_process_grow_pinned=0o2341,
                     mm_pin=0o2473, mm_extent_insert=0o1222,
                     mm_is_pinned=0o1267,
                     vm_space_brk_current=0o21732,
                     vm_space_create=0o22320,
                     __kcore_low_end=0o24102)
    watched = set(range(0o24102, 0o24102 + 64)) | {0o23471}
    shadow = {0o23471: 10, 0o24102: 5, 0o24104: 6,
              0o24106: (2048 << 18) | 0o10000,
              0o24110: (3072 << 18) | 0o12000}
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
                  event(0o22163, 0o24106, (3072 << 18) | 0o10000) +
                  event(0o34435, 0o24110, (2944 << 18) | 0o12200))
        report, length = trace.replay(window, watched, shadow, addresses, 0)
        assert length == 6
        assert report["commits"] == 1
        assert report["resizes"] == 3
        assert report["pure_span_events"] == 1
        assert report["brk_span_events"] == 1
        assert report["staging_writes"] == 2
        assert [x["free"] for x in report["stable"]] == [100] * 4
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
