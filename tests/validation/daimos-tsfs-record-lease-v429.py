#!/usr/bin/env python3
"""Guard TSFS table-record lease constraints for a future ABI rewrite.

Only asserts verified current source patterns. A PASS does not prove
safe concurrent I/O or justify removing global provider serialization.
"""
import pathlib
import re
import sys


def check(text, expression, explanation):
    if not re.search(expression, text, re.M | re.S):
        raise SystemExit("FAIL: " + explanation)


def main():
    path = pathlib.Path(sys.argv[1]) / "system/kernel/fs/tsfs_runtime.s"
    text = path.read_text()
    check(text, r"tsfs_file_record:\s*move\s+3,dtfs_media_base\s*"
                r"move\s+6,\[-4,,017\]", "file records must be 8 words")
    check(text, r"tsfs_extent_record:\s*move\s+3,tsfs_extent_media_base\s*"
                r"move\s+6,\[-5,,037\]", "extent records must be 4 words")
    check(text, r"tsfs_table_record:.*?pushj\s+17,dtfs_dtc_read.*?"
                r"addi\s+1,fs_block_workspace", "returned record aliases workspace")
    check(text, r"tsfs_parent_common:.*?pushj\s+17,tsfs_file_record.*?"
                r"move\s+2,5\s*; record pointer", "parent/name pointer escape")
    check(text, r"tsfs_readdir:.*?pushj\s+17,tsfs_node_record.*?"
                r"pushj\s+17,tsfs_file_record", "readdir has successive records")
    check(text, r"tsfs_read_d6lz:.*?movei\s+2,fs_block_workspace\+2.*?"
                r"pushj\s+17,d6lz36_decode_buffer", "decoder consumes workspace")
    print("tsfs-record-lease-v429: PASS (8/4-word records, pointer leases, decode buffer)")
    print("lower bound for private value copies: 8 stack words/file record, "
          "4 stack words/extent record, excluding linkage and saved ACs")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: daimos-tsfs-record-lease-v429.py DAIMOS_REPO")
    main()
