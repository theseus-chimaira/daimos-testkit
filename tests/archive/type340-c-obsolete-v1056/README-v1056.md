# Archived Type 340 C-based regression (v1056)

The two files in this directory were the generic PDP-10 testkit's
original C-based Type 340 text test, migrated into daimos-testkit.
They are retained as historical source material, unchanged.

The C fixture includes `dpy_text.c`, a file deleted when DAIMOS
implemented retained display text in native Type-342 assembler blocks.
The historical test cannot build against current main, and should
not be used as a current test oracle. Its last failed invocation
stopped during C compilation because the included source was missing;
it did not execute a display test.

Current substitute: `test-daimos-dpy-native-blocks`, which verifies
fixed-pair edits, sparse fill, uppercase conversion, and ring wrap.
That test passes with the current DAIMOS source. A full live-display
guest test is a separate concern and is not claimed here.

Original file hashes are listed in `SHA256SUMS-v1056.txt`.
No 32K-specific tests or KCORE optimizations were run during cleanup.
