# Simulated DSH mutable process-memory compression (v1425)

Date: 2026-11-10. Reproducible experiment; no production DAIMOS
image, compressor, or shell has been changed.

## Reproduction

The inputs are the **actual built, uncompressed** DSH DXR and
its compiler-generated assembly files from the same build:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export DAIMOS_REPO=/path/to/DAIMOS-v1424-source-worktree
    export DSH_DXR=$HOME/git/DAIMOS/build/system/boot/pdp6/userland-build/userland/dsh.dxr
    export DSH_BUILD_DIR=$HOME/git/DAIMOS/build/system/boot/pdp6/userland-build/userland/dsh/dsh
    sh tests/validation/d6codec-shell-mutable-v1425/run-native-v1425.sh

The script writes a versioned TSV summary and JSON geometry report
to $TMPDIR/d6codec-shell-mutable-v1425, alongside native fixture
source and PDP-6 simulator reports. It does not edit DAIMOS.

## Real DSH image geometry

The DXR2 header reports 15,331 initialized image words, including
15,330 text and one initialized writable word, and 1,011 BSS words.
After 16 user-origin words and 1,024 startup/stack words, the
initial physical VM is 17,408 words (rounded to 1,024-word APR
allocation granularity). If immutable PURE text were dropped on
128-word sector boundaries, the omitted prefix would be 15,232
words and the retained sector-aligned suffix would be 2,176 words.
That suffix contains 114 trailing immutable text words copied
bit-for-bit from the real DXR in the four shell-shaped scenarios.
The deliberately incompressible control replaces the entire suffix,
including this TEXT tail, with seeded random 36-bit values.

**Important:** This DSH DXR is *not flagged PURE*. Therefore this
is a prospective compressed-suffix size experiment, not an existing
production DSH eviction/restore measurement.

The BSS object sizes come from the real generated DSH assembly:
31 words input line, 454 main state, 192 command block, 200 inline
AST node, and other source static objects, totaling 966 of the
actual 1,011 BSS words. The remaining 45 linked BSS words are
left zero. Their unknown live contents are NOT claimed to have
been captured. The model groups the source object sizes in a
convenient order rather than asserting exact linker placement.

The process startup records, variables, jobs, parser data, reserved
stack and heap are deterministic *simulations* informed by the
DSH source: 64 two-word variable descriptors, counted SIXBIT,
seven-word shell strings, two-word heap allocation headers, a
337-word main stack frame, and optional eight 200-word function
AST nodes. The initial heap break is at the end of the whole
rounded initial VM. Heap growth rounds the process to full
1,024-word allocations, leaving newly allocated words zero.
This produces 28 live heap words for idle, 196 for command,
and 1,837 for function-heavy. No actual running shell was
stopped or dumped.

## Physical sector-aligned suffix results (36-bit words)

| Model | Raw | Grouped D6CODEC | Block v1424 |
|---|---:|---:|---:|
| Just after EXEC | 2,176 | 138 | 148 |
| Idle prompt, six variables | 3,200 | 280 | 358 |
| Command, twelve variables | 3,200 | 463 | 618 |
| Functions, twenty variables | 4,224 | 646 | 868 |
| Incompressible/random control | 2,176 | 2,249 | 2,193 |

These figures count only the compressed payload; any container
header, allocator bookkeeping or staging buffers would be extra.
Even in the idle case, after a small dsh_heap_alloc() call, the
VM grows from 17,408 to 18,432 words and its potential retained
suffix grows from 2,176 to 3,200 words.

## Strict writable-only comparison (not sector aligned)

| Model | Raw | Grouped | Block |
|---|---:|---:|---:|
| Just after EXEC | 2,062 | 21 | 34 |
| Idle prompt | 3,086 | 162 | 244 |
| Running command | 3,086 | 347 | 504 |
| Functions/jobs | 4,110 | 530 | 754 |
| Random control | 2,062 | 2,131 | 2,079 |

The difference between tables is the 114-word real image TEXT tail.
Writable-only values deliberately omit that tail and therefore
do not describe the actual sector-granular suffix boundary.

## Acceptance

Both independent host implementations encode and decode all ten
modeled sequences exactly (five models times two regions). The
native PDP-6 emulator executes grouped v1420 and register-resident
block v1424 decoders on all five **complete physical suffixes**,
comparing every decoded word. All ten native tests PASS.
The deliberately random control proves that either codec can
increase storage requirements for poorly compressible data.

The experiment says nothing about full KCORE linking, suspension,
MM ownership, compressed-buffer allocation, in-place replacement,
real nested VFS stacks, compression CPU cost, or restart safety.
Any production swapless mutable-RAM policy needs a raw fallback
when compression is not beneficial, admission rules, exact
allocation accounting, and tested atomic restoration. This work
does **not** enable such a policy.
