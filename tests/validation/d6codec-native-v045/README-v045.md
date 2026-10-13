# v045: native two-word back-references

Research-only PDP-6 encoder based on v041 grouped writer. One changed
threshold, `CAIGE 6,2`, enables length-two word matches; no additional
instructions or static RAM. The existing kind-0 word-copy descriptor is
semantically equivalent to the even-halfword reference of twice the
halfword distance, so the 99-word native decoder already supports it.

Native encoder: 129 code words, zero .data/.bss. Decoder 99 code words;
combined 228, unchanged from v041.

PDP-6 tests PASS: five original v041 behavioral checks, native byte-exact
host-derived reference streams and round trips on three real 128-word DXR
samples. Configctl output decreases 99 -> 90 words; darc 79 -> 72; d6lz
117 -> 108. The old exact-capacity fixture necessarily changes with the
compressed length; revised tests prove a capacity of precisely 90 words
succeeds and capacity 89 fails. Encoder-only darc completes within 40,000
steps and is incomplete at 35,000, same bounds previously seen for v041.

The existing host v044 results suggest substantial benefits for two-word
matches across the complete DXR corpus. This native version has NOT yet
compressed all 81 complete DXRs: only three independently generated 128-word
reference fixtures have been validated. It is not a KCORE production ABI.
No DAIMOS/KCORE/shared files modified.
