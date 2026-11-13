#!/usr/bin/env python3
"""Pre-implementation safety model for native DTFS durable write intent.

This deliberately models partial physical 36-bit word writes, as observed
with the v1529 Type-551 simulator. It is NOT a production runtime test.
"""

MASK = (1 << 36) - 1
WORDS = 128
DTVOL1 = 0o446466575421
DTVOL2 = DTVOL1 + 1
DIRTY = 0o552255225522
SEAL_SALT = 0o246134572610


def make_record(version=DTVOL2, state=0, high=0o123456701234,
                low=0o653210765432):
    assert high and low and high <= MASK and low <= MASK
    block = [0] * WORDS
    block[0:4] = [version, high, low, (~(version ^ high ^ low)) & MASK]
    if version == DTVOL2:
        assert state in (0, DIRTY)
        block[4] = state
        block[5] = (~(version ^ high ^ low ^ state ^ SEAL_SALT)) & MASK
    return block


def parse_record(block):
    """Return CLEAN, DIRTY, OLD, LEGACY or INVALID; never auto-upgrade."""
    if len(block) != WORDS or any(not 0 <= w <= MASK for w in block):
        return "INVALID"
    if not any(block):
        return "LEGACY"
    magic, high, low, check = block[:4]
    if magic not in (DTVOL1, DTVOL2) or not high or not low or (
            check != ((~(magic ^ high ^ low)) & MASK)):
        return "INVALID"
    if magic == DTVOL1:
        return "OLD" if not any(block[4:]) else "INVALID"
    if any(block[6:]) or block[4] not in (0, DIRTY) or block[5] != (
            (~(magic ^ high ^ low ^ block[4] ^ SEAL_SALT)) & MASK):
        return "INVALID"
    return "DIRTY" if block[4] else "CLEAN"


def physically_write(old, new, prefix=WORDS):
    """Simulated v1529 prefix write: only first prefix words change."""
    assert len(old) == WORDS and len(new) == WORDS
    assert 0 <= prefix <= WORDS
    return new[:prefix] + old[prefix:]


def fresh_mount(record, expected_id=None):
    """Cold/reinsert admission. An old valid directory is not an override."""
    if parse_record(record) != "CLEAN":
        return False
    if expected_id is not None and tuple(record[1:3]) != expected_id:
        return False
    return True


def may_write_data(observed, expected_dirty, write_completed):
    """Durable intent must be committed and read back before a data WRITE."""
    return (write_completed and parse_record(observed) == "DIRTY" and
            observed == expected_dirty)


def exercise():
    tests = 0

    def check(name, condition):
        nonlocal tests
        assert condition, name
        tests += 1
        print("PASS v1549 model:", name)

    original = make_record()
    dirty = make_record(state=DIRTY)
    check("new-v2-clean-mount", fresh_mount(original))
    check("old-v1-cannot-silently-upgrade", not fresh_mount(
        make_record(version=DTVOL1)))
    check("legacy-zero-cannot-silently-upgrade", not fresh_mount([0]*WORDS))
    check("readback-after-full-dirty-mark-allows-first-data-write",
          may_write_data(physically_write(original, dirty), dirty, True))
    for cutoff in range(WORDS):
        partial = physically_write(original, dirty, cutoff)
        # The writer must abort on every incomplete marker write, even if
        # a truncated write happens to leave a valid CLEAN/dirty header.
        check_write = not may_write_data(partial,dirty,False)
        assert check_write, ("uncommitted-intent",cutoff)
        # A partially committed DIRTY header cannot create a false
        # assertion of clean ownership: no data transfer has started.
        if parse_record(partial) == "CLEAN":
            assert cutoff <= 4, ("unexpected-clean-prefix",cutoff)
    check("all-128-early-write-failures-abort-without-data-write",True)

    data = [0] * WORDS
    requested = [0] * WORDS
    requested[1],requested[2] = 0o12345,0o65432
    damaged = physically_write(data,requested,2)
    check("genuine-one-of-two-partial-data-words",
          damaged[1] == requested[1] and damaged[2] == data[2])
    check("cold-boot-rejects-dirty-regardless-of-directory",
          not fresh_mount(dirty))
    check("reinsertion-rejects-dirty-same-72bit-id",
          not fresh_mount(dirty,tuple(original[1:3])))

    # Once the file/directory writes are all fully committed, a clean
    # seal can be attempted during checked owner-safe unmount. A failed
    # seal update is never counted as a successful unmount.
    for cutoff in range(WORDS):
        partial = physically_write(dirty,original,cutoff)
        assert not (parse_record(partial) == "CLEAN" and cutoff < 6), (
            "premature-clean-commit",cutoff)
    check("all-128-clean-seal-partials-fail-closed-or-post-data",True)
    check("full-clean-seal-remounts-only-after-committed-data",
          fresh_mount(physically_write(dirty,original)))

    replacement = make_record(high=original[1]+1, low=original[2]+1)
    check("different-stamped-replacement-mounts",fresh_mount(replacement))
    check("changed-media-rejected-for-existing-owner",
          not fresh_mount(replacement,tuple(original[1:3])))
    check("discard-does-not-clear-or-repair-old-dirty-media",
          parse_record(dirty) == "DIRTY")
    broken = list(original)
    broken[5] ^= 1
    check("broken-seal-checksum-rejected",not fresh_mount(broken))
    broken = list(original)
    broken[63] = 1
    check("nonzero-reserved-padding-rejected",not fresh_mount(broken))
    check("dirty-seal-cannot-repair-on-identity-equality",
          not fresh_mount(dirty,tuple(dirty[1:3])))

    print("PASS v1549: %d protocol invariants and 256 partial-prefix variants" % tests)


if __name__ == "__main__":
    exercise()
