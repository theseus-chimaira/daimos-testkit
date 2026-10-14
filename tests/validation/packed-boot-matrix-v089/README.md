# DAIMOS packed-runtime PDP-6 hardware matrix v089

Run `DAIMOS_REPO=/path/to/DAIMOS tests/validation/packed-boot-matrix-v089/run-v089.sh`.
Each profile builds a separate fresh image tree under `${TMPDIR:-$HOME/tmp}`
with GCC, `PACKED_RUNTIME_V088=1`, and a simulator configuration matching
its hardware list. Select a subset with `PACKED_BOOT_PROFILES='d6fs tsfs'`.
The default runs all three. `PDP10_PREFIX`, `DAS_REPO`, `KCC_REPO`, and
`PDP6_SIMH` override installed tool locations as needed.

Validated 2026-10-14:

* **d6fs:** 32K, DSK0 and its DCT controller, CTY, PCLK, bootstrap PTR,
  one-member DBOOT/D6FS; reaches `INIT V1` (KINIT end `075162`).
* **tsfs:** 32K, DTC0 bootstrap and DTC1 root DECtape with DCT, CTY, PCLK,
  bootstrap PTR; reaches `INIT V1` (KINIT end `075535`).
* **full:** 256K, all supported controllers enabled with all available
  disk, drum, DECtape, magnetic-tape and serial/output media attached;
  reaches `INIT V1`.

The two minimal profiles explicitly disable optional controllers and omit
unused KINIT MINIT/MRES packages. `PCLK` is required to run the scheduler;
`PTR` is necessary only to load the initial boot block through the current
SIMH read-in loop. The bootstrap stack reserve stays at `02000` octal words.
The test rejects any fatal HALT and requires the `INIT V1` marker. An
expected simulator timeout after INIT is not a boot failure.

This tests the integrated packed-runtime kernel's startup and device
compatibility, **not yet** a live process compressed by the scheduler under
memory pressure and restored afterwards. That requires a separate test.
