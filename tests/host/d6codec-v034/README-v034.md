# v034 — small direct-mapped candidate-index feasibility study

C99 host-only study in daimos-testkit. Two stand-alone tools test a hash
of 36-bit words with 8, 16, 32, or 64 one-entry buckets. Each bucket holds
one source position; each candidate must still pass full-word comparison.
The proposed index needs at least one 36-bit PDP-6 word per bucket and
additional instructions for initialization, rolling updates and hashing.
There is no native implementation, no DXR compressed-size measurement, and
no PDP-6 cycle-count measurement here. All arrays in the host tools are
static or local, without dynamic allocation.

`index-profile-v034.c` uses 100 independently seeded 128-word pseudo-random
sequences. The candidate hash suffers many collisions for every index size;
collisions represent wasted candidate checks or replacement of candidates,
not accepted false matches.

`pattern-profile-v034.c` tests deterministic 512-word input patterns. A
reference exists when a previous identical word occurs within 128 words.
This is intentionally a **necessary, not sufficient** condition for a
length-3 match: the experiment does not model real codec savings.

Selected findings from `pattern-results-v034.txt`:

* 8 slots lose all 495 period-17 reference positions; 32 slots lose none.
* 64 slots still lose 103 of 224 mixed-pattern reference positions.
* Uniform repetition is found with every slot count.
* Random data contains no repeated 36-bit words in the constructed case,
  yet many occupied buckets still lead to candidate collisions.

Decision: do NOT replace the exhaustive native matcher with this naive
single-entry index. It can lose useful matches and costs 8..64 permanent or
scratch words plus encoder instructions. Future investigations should use
a measured DXR corpus trace and include hash initialization cost, output
size, complete match-length verification and RAM. A **rolling two-word
fingerprint filter without an index** may be a better low-RAM hypothesis,
but its instruction and CPU costs are not yet established.

Production DAIMOS/KCORE and concurrently edited testkit files untouched.
