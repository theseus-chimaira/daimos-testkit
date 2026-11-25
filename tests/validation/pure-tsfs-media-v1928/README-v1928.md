# TSFS mounted set identity, v1928

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-tsfs-media-v1928

The native guest executes the actual TSFS mount-publication leaf,
member proof and clean BCACHE invalidation. Physical DTC reads and
VFS publication are controlled boundaries. Forty descriptor/map cases
cover one, two and eight member layouts, nonsequential physical units,
unit zero, changed sealed descriptor fields, inconsistent redundant
copies, bad seals, raw-read refusals, false-success transfers, duplicate
or trailing selectors and missing membership. Original-source retries
must clear only the suspect flag; identity remains immutable. Mount
publication copies all five identity words; a second root publication
is refused. Seven independently executed unsafe variants fail guest
assertions (octal 010, 014, 026, 002, 002, 001, 033). The native fixture
varies member maps explicitly to exercise all sizes; the boot scanner
gate independently checks the actual one/two/eight-member handoff.

The extended shared reconstruction bridge covers eight cases for each
of DTFS, D6FS and TSFS and two MEMFS controls. The DROP gate adds TSFS
suspect-state refusal for both low and extended public mount IDs.
The v15 slab and multi-extent runners link the original invariant HALT
leaf and explicitly reject unexpected private-proof calls. The legacy
v1 compressed-extent runner still references the removed d6lz_pdp6.s;
it is not a passed regression and is not repaired by substituting an
unrelated codec. No whole-guest reel replacement or PI6 claim.
