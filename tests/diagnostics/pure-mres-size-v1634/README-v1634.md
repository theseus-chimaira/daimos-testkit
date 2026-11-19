# P1-E v1634: reproducible removable PURE MRES compiler-size experiment

The v1633 physically proven fixed-parent APR corridor requires
at least **000605 octal / 389 decimal words** less necessary low-
core occupancy before six full child APRs can fit in 48K. The
current separately installed PURE MRES image is **003336 octal /
1758 decimal words**, with a source-matched identical KCORE.

This testkit-only experiment rebuilds the seven constituent PURE
MRES objects using the original PDP-6 GCC 3.2 compiler and assembler
without altering any production sources, executable loader contract,
MM ownership, KCORE build or original Type-551 tapes. The unchanged
three assembler objects are copied verbatim. It generates an
independent `p10fold -m 20` plan, then links against the original
`kcore.map` and obtains the complete DXR image length from
`dxrcheck -d`. Each compiler variant uses a unique scratch path.

    DAIMOS_REPO=/path/to/DAIMOS \
    PURE_MRES_BUILD_V1634=/path/to/original/v1629/build \
        sh tests/diagnostics/pure-mres-size-v1634/compile-matrix-v1634.sh

The simulator build's required `das -F -C -O` flags are critical:
omitting `-F` (a diagnostic harness error, NOT a DAIMOS defect)
produced a spurious 1762-word baseline although compiler-generated
assembly text was identical. Corrected tool invocation produces
an original `-Os` DXR that is **byte-for-byte identical** to the
source-backed v1629 artifact, not merely the same image length.
This byte-equivalence is an explicit test gate.

| Compiler options | DXR words (decimal) | Difference vs original |
|---|---:|---:|
| `-Os` (original, byte-identical) | 1758 | 0 |
| `-O2` | 1806 | +48 |
| `-O1` | 1797 | +39 |
| `-Os -fno-inline` | 1758 | 0 |
| `-Os -fomit-frame-pointer` | 1758 | 0 |
| `-Os -fno-cse-follow-jumps` | 1771 | +13 |
| `-Os -fno-strength-reduce` | 1757 | -1 |
| `-Os -fno-builtin` | 1758 | 0 |

The only apparent size improvement is ONE decimal word, far less
than the required 389-word capacity shift. The alternative
flagged images were linked, NOT run through full guest execution;
their size alone is NOT permission to deploy them. There is no
validated compiler-option repair for the 48K process-admission
regression. Do not change the production compiler defaults.

Next investigate correctness-preserving source consolidation of
duplicated PURE MRES routines, then measure its full installed
size and all functional/rollback paths. A proposed shrink must
still survive a real 48K physical PDP-6 guest with source-matched
restoration, MM owners and six RUN admissions. PURE remains OFF
by default; strict 32K whole-KCORE optimization stays on HOLD.
