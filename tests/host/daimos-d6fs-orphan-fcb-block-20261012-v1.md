# D6FS ambiguous-completion FCB identity audit — 2026-10-12

`d6fsck` prints FCB indices using `%o` (octal), not decimal. The failure
reported `unreachable FCB: 451` and `452`. With the checked filesystem's
FCB table starting at logical block 442, the FCB layout uses eight 16-word
FCBs per 128-word physical block. Hence:

* octal FCB 451 = decimal 297: FCB-table logical block 479, slot 1
* octal FCB 452 = decimal 298: FCB-table logical block 479, slot 2

Both orphaned FCBs belong to the *same* logical FCB table block 479 that
was targeted by the narrowed post-write error injector. This materially
strengthens the association between the injected block and the orphaned
metadata, but it does **not** prove that the target file's own FCB was the
one faulted, or establish the number of injected failures. The injector
applies to every successful write to this block, including any runtime
creation or directory metadata operations affecting these FCB slots.

The missing next experiment is an individually identified FCB-slot
transition with one-shot hit accounting, plus filesystem checks before and
after that transition. Keep the previously observed regression open.
