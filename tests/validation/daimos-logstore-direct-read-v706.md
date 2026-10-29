# v706 — LOGSTORE direct read binding

The LOGSTORE MRES previously had two callers branching to a common
`logstore_backend_read_jump` intermediary. One belongs to a multi-member
BLOCKSET backend and the other to a singleton direct device. KINIT already
chooses exactly one backend at installation and uses the same service
address for both branches. It now patches the RH of both `JUMPE` instructions
individually, with exports 2 (`logstore_backend_read_call`) and 4
(`logstore_direct_read_call`). Existing write export index 3 is unchanged.

The write `JRST` is deliberately retained: it is the fall-through from
the multi-member read conditional and a target for the direct write path.
The read intermediary is removed. Both read sites default to `kret_neg1`
until patched. No permanent binding table is needed.

Comparing two separately linked images against the same KCORE map yields
800 bytes before and 792 bytes after, or one 36-bit instruction word saved.
The native PDP-6 regression exercises read and write in both multi-member
and direct-device branches. Boot-level LOGSTORE coverage remains separate.
