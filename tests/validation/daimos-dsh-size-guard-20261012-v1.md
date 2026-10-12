# DSH low-risk size regression — 2026-10-12 v1

Use `DSH_DXR=... DSH_MAP=... sh
tests/validation/daimos-dsh-size-guard-20261012-v1.sh` with the matching
newly built KCC/DAS DXR and linker map. Optional `DXRCHECK` defaults to
`dxrcheck`.

This stage's tested baseline is **036054 octal image words**, **015241
octal BSS words**, after splitting unused libc configuration/SIXBIT
helpers and eliminating duplicated quote-mask and lexer helper paths.
The test rejects a larger image/BSS and verifies that `u_text_fields`,
`u_text_key`, and `u_s6_eq` do not appear in the DSH link map.

It does **not** replace the final hard image limit of **036000 octal**
words. When the next shrinkage stage meets the production gate, tighten
this temporary size regression to 036000 and remove the exception.
