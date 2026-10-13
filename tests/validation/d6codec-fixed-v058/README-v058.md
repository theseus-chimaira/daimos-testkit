# D6 codec v058 fixed-address native regression

This directory validates the candidate new-format resumable decoder with
exactly the previous 000060 register ABI, without activating production.

- `run-v058.sh`: copies the actual decoder into 000060 on native PDP-6,
  tests incomplete prefixes of length 1..30 for a maximum 31-word group,
  then completes decoding and verifies all literal words, as well as odd
  halfword distances 1 and 3 and preserved AC15/AC16.
- `run-invalid-v058.sh`: checks malformed group counts, reserved control
  bits, unused flags, descriptor padding, match length and invalid kind.
- `vfs/run-vfs-v058.sh`: installs the decoder at 000060 and exercises the
  redesigned VFS adapter with a mock provider delivering only two words
  per read, including the maximum 31-word group and repeated compaction.

Each runner assembles the fixed decoder in the same translation unit as its
low-core BLT installation test, so the assembler can resolve the copied image
span without relying on cross-object symbol subtraction. This also avoids
hard-coding the decoder size in the test.

All tests require `DAIMOS_REPO`, `TESTKIT_REPO` and `PDP10_PREFIX`. They use
versioned temporary run directories under `$TMPDIR`, default `$HOME/tmp`.

These tests do not establish all end-to-end codec acceptance: address-wrap,
input/output aliasing, 64-word edge geometry, production boot, DXR, TSFS,
PURE and KPACK ownership have not yet been covered by this version.
