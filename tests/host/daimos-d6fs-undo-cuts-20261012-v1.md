# D6FS bounded undo-journal interruption experiment (2026-10-12)

Run: `make test-daimos-d6fs-undo-cuts`.

The strict C99 host model passes 5,805 write/replay interruption cuts
across three cases: append requiring allocation, append within existing
capacity, and append at a block-aligned EOF. It also rejects corrupted
undo payloads, missing headers and conflicting same-generation headers.

Each simulated backing write can persist any prefix of its 128 words.
The model saves full prior images of the old tail data block, freemap block,
summary block and FCB block, including adjacent unrelated FCB records.
It then writes a PREPARE header, applies in-place writes, and writes COMMIT
to the alternate header. Recovery after PREPARE restores verified undo
images and marks EMPTY; recovery after COMMIT retains the new image.
Recovery can itself be interrupted and restarted.
An explicit negative test lets COMMIT overtake the final FCB write and
demonstrates an unsafe state despite valid journal headers. Real integration
must define an enforceable durability barrier before COMMIT.

## Important limitations

- **No physical write barrier was tested.** The model assumes that a
  successfully returned block write is durable before the next write.
- The negative reordering test is a counterexample under weaker ordering,
  not a recoverable case in the proposed two-state model.
- The toy rotating XOR checksum is not suitable for a persistent format.
- The test is not attached to real D6FS allocation, directory entries,
  block ownership, FCB formats, or actual runtime metadata offsets.
- It does not test duplicate appends, multiple live writers, metadata
  generations across many transactions, or a simultaneous loss of both
  intent headers. Those require additional separate tests.
- The existing D6FS V2 and current PDP-6 kernel are **unchanged**.
  In particular, the LOGSTORE reservation is already assigned and must
  not be silently treated as filesystem transaction space.

This is evidence about the candidate sequence **under the stated model
assumptions**, not a crash-safety proof. Before implementing a V3 transaction,
define a separate reserved journal area, a strong 36-bit integrity mechanism,
write-order/durability barriers, boot replay, allocation reconciliation,
unknown-outcome reporting and measured kernel/RAM cost.
