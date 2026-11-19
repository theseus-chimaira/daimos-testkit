# v1668: dedicated swapless TSFS KINIT with no DISK SWAP candidate

Parent DAIMOS commit v1667:
`9d9d310526a363caf43430e18a84b5720cc08872`.

Only `ROOT=tape DAIMOS_PURE_MRES_ENABLED=1
DAIMOS_SWAPLESS_ONLY_V1668=1` enables the dedicated image.
`DAIMOS_PBM_V1667=1` is an independently gated test-only bitmap
PURE MRES; it is not required for v1668 and remains OFF by default.

General `ROOT=auto` and all other boot profiles continue to link
the original disk-swap MRES candidate and preserve the unchanged
root-aware selection. Dedicated ROOT=disk/drum, or a missing PURE
option, must fail Make configuration with a diagnostic. The
strict KINIT module table records zero for its SWAP MINIT package;
the original `proc_swap_mres_package_v481` symbol MUST NOT be
present in the linked KINIT image. The original PURE MRES remains
the only installed process-backing service in this configuration.

The actual ROOT-before-SWAP MINIT selects PURE only for DTC/TSFS
with no positively validated BACKSTORE. A positive BACKSTORE
halts as SWAP FAIL, before any MRES install or block publication,
because the DISK MRES has been physically excluded. Unexpected
root class or unresolved selector likewise fails closed. An
additional full-profile AUXSTORE MINIT check detects a later
positive BACKSTORE rediscovery and halts before LOGSTORE setup.
A logstore-only AUXSTORE descriptor with zero BACKSTORE remains
admissible. DSK/DRM device drivers are retained for independent
non-swap auxiliary services: they are NOT the disk-swap MRES.

## Strict C89 original-source selection and build policy

    DAIMOS_REPO=/path/to/DAIMOS \
      sh tests/validation/pure-swapless-kinit-v1668/run-v1668.sh

This extracts the unmodified `proc_swap_minit_v481()` and
`auxstore_minit()` from production `module_minit.c`. It compiles
them in strict host C89 with only hardware discovery, installer
and diagnostics provided by the historical v1613 fixtures.
It checks absent/zero/positive validated BACKSTORE, failure with
stale counters, different root classes, exact three PURE export
patches, zero installed DISK MRES and the later AUXSTORE probe.
Two independently compiled unsafe mutants are executed and
rejected: skipping the first positive-BACKSTORE fatal, and
skipping the second positive-BACKSTORE redetection fatal.

The runner evaluates the real top-level Makefile MRES candidate
list, covering strict tape, normal tape, normal auto/disk/drum,
strict tape with test-only bitmap PURE and invalid combinations.
It reruns the historical v1665/v1613 root-aware source tests.

## Actual 64K PDP-6 physical positive and negative tests

    DAIMOS_REPO=/path/to/DAIMOS \
      sh tests/validation/pure-swapless-kinit-v1668/run-physical-v1668.sh

Builds GCC lowmem `ROOT=tape BOOT=dtc` with a three-member TSFS
root. The no-AUXSTORE run detaches all disk and drum images:
`MEM 64 K`, `DTC OK`, `PURE LOADED`, `INIT V1`, alive until a
controlled simulator timeout. The positive-AUXSTORE run uses the
SAME source-built KINIT/TSFS root image, but attaches DRM0 from
the Makefile-produced valid AUXST1 BACKSTORE image (all DSK and
other DRM media detached). It MUST print `SWAP FAIL` then `HALT`
without `PURE LOADED` or `INIT V1`. The earlier direct positive
physical run HALTed at PC 065774 octal. The actual versioned
test verifies the hardware error behavior, not just compilation.

`V1668_BOOT_BUILD` may name a source-built strict 64K image
directory for testing without rebuilding; `KEEP_TEST=1` retains
the exact two SIMH transcripts and input configs under `$TMPDIR`.

## Matched source-built image size test

    V1668_GENERAL_BUILD=/path/to/general-gcc-lowmem \
      V1668_STRICT_BUILD=/path/to/strict-gcc-lowmem \
      sh tests/validation/pure-swapless-kinit-v1668/run-size-v1668.sh

The original v1667-base GCC lowmem `ROOT=tape` source compiled
with strict flag 0 has fixed KCORE octal 024076, PURE MRES 1863
resident words and KINIT end octal 113732. The v1668 strict image
has the SAME fixed KCORE end and installed PURE size, and KINIT
end octal 110205: **1877 transient words saved**. The excluded
DISK SWAP candidate itself is 1837 installed words; the extra
40 remaining saved image words are net KINIT selector, table and
packaging changes; they have not been attributed individually.
The test proves the disk package is missing from the actual
linker map and the module table specifies a zero SWAP candidate.

These are temporary image-address/word changes, not a claim of
1877 more free runtime words or a physical measured high-water.
An independently linked source-matched **KCC FULL** ROOT=tape
general/strict pair passes the same size/ownership script:
fixed KCORE `024353` octal, installed PURE 2307 words unchanged,
general KINIT end `131475` -> strict `125775` octal, **1856
transient words saved**, and no disk-swap MRES symbol in the
strict map. Both GCC lowmem and KCC FULL link/profile tests PASS.
No change to the normal default PURE=OFF, bitmap stage=OFF.
Mode3 production admission remains disabled; physical 48K and
strict 32K acceptance and full-mode KCC physical RAM profiling
remain separate future gates.
