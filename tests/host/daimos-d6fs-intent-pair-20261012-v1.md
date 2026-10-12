# D6FS two-copy intent selector prototype — 2026-10-12 v1

This C99 **host-only** experiment evaluates a 12-word record within a
128-word 36-bit block. Two record slots are selected by validated version,
sequence, state and a 36-bit rotation/XOR integrity digest. The fixed
record carries a prospective FCB index, parent, directory slot, entry size,
identity words, and reserved flags. No allocations or auxiliary resident
block buffers are required by the selector algorithm.

The test enumerates all 129 word-aligned prefixes of a simulated interrupted
overwrite of one copy, preserving an intact other copy. It also rejects
same-sequence disagreement even when both records have valid digests.
Host compile: `cc -std=c99 -O2 -Wall -Wextra -Werror`.
Result: **PASS**, 129 prefixes and equal-sequence conflict test.

This proves **only the prototype's deterministic selection conditions**.
It does not model arbitrary reordering, simultaneous destruction of both
copies, torn 36-bit words, adversarial checksum collisions, sector write
atomicity, persistence barriers, wraparound, or idempotent transaction
replay. The simple rotation/XOR digest is NOT an adequate final integrity
scheme or an on-disk format proposal. In particular, the recovery sequence
must not ever overwrite the only valid copy before its successor is known
durable, and it must reconcile all directory, FCB, bitmap and extent state.

The intent is to test the simplest selector independently before debating
persistent layout. **Do not integrate this prototype into DAIMOS** without
replacing the integrity scheme, defining storage ordering and implementing
boot-time recovery with power-cut tests. No production image was changed.
