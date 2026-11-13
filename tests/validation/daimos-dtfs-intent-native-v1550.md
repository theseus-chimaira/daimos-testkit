# v1550: native PDP-6 DTVOL2 record and explicit host format

Date: 2026-11-13. KCORE P0-B staged implementation, not mounted
media durability acceptance.

Production `tools/host/mkdtfs.c` now supports an **explicit**
`mkdtfs --durable-v1550 -o NEW.tap` argument. The existing
`mkdtfs -o NEW.tap` output is **unchanged DTVOL1**. The new option
emits six checked words in the already reserved native physical
RBN0 and 122 zeros, with an independently randomized nonzero
72-bit identity. DTVOL2/CLEAN is the only initial formatter state.
The rest of the native directory/owner map layout remains unchanged.

The new standalone source module
`system/kernel/fs/dtfs_intent_validate_v1550.s` is genuine PDP-6
assembly with ABI `AC1=RBN0[128]`, returning `AC1=0` for CLEAN,
`1` for WRITE_INTENT, and `-1` for all unsupported or malformed
records. It requires exact DTVOL2 magic, both nonzero ID halves,
correct 36-bit identity complement, one of the two *exact* state
values, correct state+salt complement, and 122 zero padding words.
No global buffers, extra RAM table, stack usage or device writes.

`daimos-dtfs-intent-native-v1550.sh` builds host `mkdtfs` from
the current checkout, generates genuine new DTVOL1 and DTVOL2
physical DECtape images, extracts their 36-bit words from both
18-bit lanes, and executes the genuine validator on a PDP-6
through `p10run` for 13 actual-image and intentionally damaged
record cases. Clean, dirty, independent clean identity, legacy
DTVOL1, all-zero legacy, unknown state with valid recalculated
seal, padding, checksum, zero ID halves, torn state and other
corruptions are exercised. **13 native cases PASS.**

Seven actual-source mutations are rejected: bypass magic,
identity checksum, state, seal, padding, or high/low nonzero-ID
checks. A test-fixture error was detected and fixed: a generated
PDP-10 `.word` without a leading zero assembled large 36-bit
octal media words as *decimal*. All media word constants are now
emitted with an explicit leading `0`. The baseline and all seven
mutations subsequently PASS. This was not a production parser bug.

Legacy v1520 `daimos-dtfs-volume-id-v1520.sh` regression **PASS**
after the changes: host default DTVOL1 format, target MKFS identity
clear, native mount admission and all five native mutations.

Reproduce:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-intent-native-v1550.sh
sh tests/validation/daimos-dtfs-volume-id-v1520.sh
```

**Important deployment restriction:** the native validator is
currently **not linked into the production DTFS provider or
its mount-control path**. An experimental DTVOL2 tape is not
currently mountable by DAIMOS. In particular, there is no dirty
write-ahead arm, owner-safe CLEAN unmount or cold-reboot
acceptance in v1550. The optional host formatter output must not
be represented as a supported writable production filesystem.
This is a source and format parsing milestone only; P0-B OPEN.

Next v1551: integrate the parser alongside raw read/write and
identity checks under the serialized DTFS provider; ensure that
write buffer and live directory contents are not clobbered;
fail closed before any data mutation; prove actual native Type-551
partial I/O and cold boot. Keep P0-A and P1-C separate.
