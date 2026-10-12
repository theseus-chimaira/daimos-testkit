# D6FS recovery identity checks — 2026-10-12 v1

Host-only C99 prototype matching an intent's child FCB index, parent FCB,
directory slot, type, and four packed 36-bit name words. Parent and name
mismatch probes must fail even when the remaining fields match.

The 18 possible combinations of FCB identity state (absent/match/conflict),
dirent identity state (absent/match/conflict), and parent visibility give:
- both absent: safe empty result (regardless of parent visibility)
- both matching and parent visible: already published
- all other cases: investigation required, **15 unresolved cases**

This deliberately avoids deciding what to reclaim when metadata survives
without a matching directory entry, or when an entry refers to an FCB with
a conflicting identity. It does not read actual disk structures, prove a
persistent identity encoding, implement replay/undo, or simulate device
write barriers and crashes. The all-absent case is only safe relative to
the modeled object identities; allocation bitmap and extent state also
need validation before a real recovery can retire the intent.

Compile: `cc -std=c99 -O2 -Wall -Wextra -Werror`.
Result: PASS, 18 cases, 15 unresolved, name/parent mismatch probes.
