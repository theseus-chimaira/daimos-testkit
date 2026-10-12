# D6FS intent transition selector — 2026-10-12 v1

This C99 host-only state model advances two fixed 128-word slots through
PREPARE, COMMIT, EMPTY, PREPARE, COMMIT, EMPTY, alternating writes to the
older slot. For each step, it enumerates all 129 word-prefix interrupted
writes, insisting at least one valid record survives. It also rejects any
mixed prefix that passes integrity but matches neither full old nor full
new record. Total: **774 cuts**, PASS with `-Wall -Wextra -Werror`.

The first implementation accidentally overwrote the sole valid slot and
failed at step 0, cut 3. Correct alternation starts with the *other* slot;
this is a protocol invariant, not a test workaround. A new deployment must
initialize at least one fully durable record before allowing transactions.

This remains an abstract selector experiment, NOT filesystem recovery:
checksum is provisional and weak, no disk barriers, device reorder, partial
word tearing, wraparound, replay, metadata integrity or power cut is modeled.
It cannot establish whether COMMIT or EMPTY is permissible without linking
these states to idempotent FCB/dirent and allocation recovery.
