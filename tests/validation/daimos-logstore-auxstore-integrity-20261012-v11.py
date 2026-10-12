#!/usr/bin/env python3
"""Check LOGSTORE records on a Type-236 AUXSTORE image after a cold boot.

The simulated drum stores 128 little-endian 64-bit host slots per block.
Only the low 36 bits of each host slot belong to the PDP-6.
"""

import argparse
from pathlib import Path
import struct

WORD_MASK = 0o777777777777
HALF_MASK = 0o777777
BLOCK_WORDS = 0o200
MAGIC_AUX = 0o416570636421
MAGIC_REC = 0o546362454321


def read_block(handle, block):
    handle.seek(block * BLOCK_WORDS * 8)
    data = handle.read(BLOCK_WORDS * 8)
    if len(data) != BLOCK_WORDS * 8:
        raise AssertionError("truncated AUXSTORE block")
    return struct.unpack("<128Q", data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--expect-max8", action="store_true")
    parser.add_argument("--expect-services", type=int)
    args = parser.parse_args()

    with args.image.open("rb") as handle:
        desc = read_block(handle, 0)
        assert desc[0] == MAGIC_AUX and desc[1] == 1, (
            "AUXSTORE descriptor corrupted (possibly raw-service ABI mismatch)"
        )
        start = (desc[3] >> 18) & HALF_MASK
        count = desc[3] & HALF_MASK
        assert start != 0 and count >= 3, "invalid LOGSTORE partition"
        records = []
        for slot in range(count - 2):
            record = read_block(handle, start + 2 + slot)
            if record[0] != MAGIC_REC or record[1] == 0:
                continue
            payload = record[3] & HALF_MASK
            assert payload <= 123, "LOGSTORE payload overflow"
            checksum = ((MAGIC_REC + record[1] +
                         (payload << 18)) & WORD_MASK)
            assert record[127] == ((checksum ^ WORD_MASK) | 1), (
                "invalid commit trailer"
            )
            records.append(record)

    assert records, "no valid LOGSTORE records persisted to AUXSTORE"
    records.sort(key=lambda rec: rec[1])
    assert len({rec[1] for rec in records}) == len(records), (
        "duplicate LOGSTORE sequence numbers"
    )
    events = [
        ((rec[3] >> 30) & 0o77, (rec[3] >> 18) & 0o7777,
         rec[4], rec[5])
        for rec in records if (rec[3] & HALF_MASK) == 2
    ]
    ready_counts = [event[3] for event in events
                    if event[0:3] == (1, 1, 1)]
    assert ready_counts, "missing persisted INIT_READY event"
    expected_count = 8 if args.expect_max8 else args.expect_services
    if expected_count is not None:
        assert expected_count in ready_counts, (
            "INIT_READY event has unexpected service count"
        )
    if args.expect_max8:
        failures = [event[3] for event in events
                    if event[0:3] == (4, 1, 2)]
        assert sorted(failures) == list(range(1, 8)), (
            "expected seven distinct RUN_FAILED entry indices"
        )
        assert any(event[1] == 2 for event in events), (
            "missing LOGIN event"
        )
    print("PASS AUXSTORE descriptor and %d persistent records" %
          len(records))
    print("PASS INIT_READY services=%s" %
          ",".join(str(count) for count in ready_counts))
    if args.expect_max8:
        print("PASS all seven RUN_FAILED records and LOGIN event")


if __name__ == "__main__":
    main()
