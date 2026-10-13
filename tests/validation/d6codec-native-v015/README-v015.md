# Native PDP-6 v015 paired-descriptor decoder experiment

An experimental 99-word assembler decoder of v006-format counted groups,
with two 18-bit match descriptors packed into one 36-bit descriptor word.
It implements literal, word-copy and zero-run tokens. It does NOT yet
implement halfword-reference tokens or resumable input refills; it clobbers
AC10..AC16 and is NOT kernel-ABI compatible. It MUST NOT be integrated.

Verified on PDP-6 with `p10run` standalone deposit execution: three tokens
(literal, 3-word distance-1 overlapping backreference, 3-word zero run)
reproduce 7 exact output words. Tested encoded payload comprises 3 words.
The test is deterministic and isolated from DAIMOS and KCORE.

The test source specifies descriptor words 03001,,0203000 and the control
033000000000 (octal). First fixture drafts had an incorrect control word
and extra input word; corrected before the passing test.

Not yet verified: nontrivial multi-group state, multiple literal positions,
reserved/malformed descriptors, odd halfword backreferences, C ABI, bounded
source refill, or equivalence across all v006 DXR streams. Size is 99 native
36-bit instructions with zero BSS/data (DAS -F -C, pdp10-objdump).

`encoder_v014.s` is copied from v014 for reference but not exercised here:
its zero-run emission uses an incompatible older descriptor encoding and
must be redesigned before being called a matching compressor.
