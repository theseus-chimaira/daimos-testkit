# v1619: physical Type-551 DTC0 block match and data completion

Status: source-linked PDP-6 diagnostic. This is NOT complete
PURE-prefix/slot-0/WAIT acceptance and does not patch the kernel.

The v1618 full 48K no-AUX TSFS/PURE guest showed an active
reverse DECtape search for physical RBN block 000004. Before
changing driver code, the testkit verifies whether the generated
root DTC0 media and original Type-551 driver can read that exact
block after a long reverse seek.

## Isolated physical controller regression

run-v1619.sh copies the real v1618 TSFS media/dtc0.tap
into a private test directory. It runs the production Type-551
and Type-136 sources under the real PDP-6 simulator using
the historical PI3/PI5 test interrupt vectors:

* Near: read physical block 4 twice.
* Long reverse: read block 0341, then reverse and read block 4.

The source-authentic dtc_read_block return must be zero and
the destination buffer must contain nonzero data. The test
checks that tape media remain byte-identical (read only).
There is no test-only bypass of RBN search or simulated data
completion; a controller failure causes a nonzero exit or
simulator timeout.

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_DTC_BUILD_V1618=/path/to/48k/build \
        sh tests/diagnostics/pure-dtc-rbn-v1619/run-v1619.sh

## Full 48K PURE guest, real source-linked breakpoints

run-physical-trap-v1619.sh copies the original tape driver
source to a temporary assembly unit, exporting only its
PI3 RBN-match and failure labels. It proves that the entire
linked IMAGE section is identical to the actual v1618
booted tape MRES before using test-only exported offsets:

* dtc_search_pi_found offset 000415, PC 031046.
* dtc_search_fail offset 000463, PC 031114.
* dtc_search_pi_read offset 000455, PC 031106.
* tape_dct_done_keep_dtc offset 000124, PC 030555.

The simulator waits for the final BRK request marker,
then arms breakpoints without changing the guest program or
installed MRES. At PI3 match, the original source reads
the current block number from DATAI and compares it to the
saved target. The capture must show unit 0, reverse motion,
target 000004 and last physical mark 000004.

run-transfer-v1619.sh continues from that RBN match to
the original PI3 read-arming branch and then to the
DCT read-completion branch. The source distinction
matters: Type-551 read completion is in
tape_dct_done_keep_dtc, NOT tape_pi_done,
which is not the normal DTC read-completion route.
No successful transfer should be reported from a
PI5-only breakpoint.

    PURE_BRK_BUILD_V1615=/path/to/48k/build \
    DAIMOS_REPO=/path/to/DAIMOS \
        sh tests/diagnostics/pure-dtc-rbn-v1619/run-transfer-v1619.sh

To run the read-only source-map audit on a preserved trace,
provide PURE_RBN_SYMBOL_MAP_V1619, PURE_RBN_TRACE_V1619,
PURE_DTC_BUILD_V1618, and DAIMOS_REPO to
run-audit-v1619.sh, optionally with
PURE_RBN_AUDIT_MODE_V1619=transfer. The audit checks
the matching block's actual PI3 state and rejects
a private mutation of the sampled block mark.

This does not establish successful VFS prefix reload,
release of the process MM pin, READY_ONCE, PIPE/WAIT/EXIT,
immutable executable-source lifetime, or positive net
physical RAM savings. P1-E remains disabled by default.
