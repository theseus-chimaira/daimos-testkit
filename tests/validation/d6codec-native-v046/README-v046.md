# v046 — 256-word native DXR parity checkpoint

Self-contained PDP-6 test fixture generated from the first 256 36-bit DXR
payload words of `darc.dxr`. It verifies the encoder produces exactly 192
compressed words matching an independently generated grouped two-word policy
stream, then validates native decoding of all 256 words. PASS on PDP-6.

This extends v045's three independent 128-word fixtures across additional
30-token group boundaries without increasing encoder or decoder footprint.
No claim of full-native compression of all 81 DXRs is made.

Run `run-v046.sh`; regenerate the pinned fixture with `make-long-v046.py`
if the original DAIMOS DXR build is available. No production files changed.
