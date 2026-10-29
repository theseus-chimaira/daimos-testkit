# v705 — Direct BADMAP base mapper

The BADMAP MRES originally entered its singleton/multi-member mapper through
`PUSHJ 17,badmap_base_map` and a separately patched `JRST`. KINIT needed
the intermediate slot only when selecting the BLOCKSET mapper for multiple
members. The new single call site `badmap_base_map_call` defaults to
`PUSHJ 17,badmap_direct_map`, and KINIT patches its right half to BLOCKSET
when the member count exceeds one.

The source-level export changes from `badmap_base_map_jump` to
`badmap_base_map_call` without changing its export index (6). Neither
singleton state geometry nor exception-map scanning is modified.

The isolated MRES link against the same KCORE map produced baseline 488
bytes and optimized 480 bytes, a net one-instruction-word reduction.
Native PDP-6 execution passed both the singleton default and a patched
alternate mapper, confirming the expected AC1/AC2 mapping results.
Full-system boot coverage is distinct from this isolated native test.
