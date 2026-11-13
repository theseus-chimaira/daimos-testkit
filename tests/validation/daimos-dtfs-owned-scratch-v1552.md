# v1552: physically pinned MM scratch lifetime for DTFS DTVOL2

Date: 2026-11-13. Standalone source-linked PDP-6 feature acceptance.
The complete live KCORE P0-B transaction is **NOT** enabled.

## Source under test

The new production source module
`system/kernel/fs/dtfs_intent_owned_arm_v1552.s` accepts AC1=Type-551
unit, AC2/3=the admitted 72-bit identity, and AC4=the pointer to
a **caller-retained scratch base word initialized to zero**.
It allocates 128 contiguous MM_TYPE_KERNEL_DYNAMIC words with
owner **015 octal**, using `mm_alloc_aligned_noreclaim` and
`MM_ALLOC_HIGH`. It then calls the real `mm_pin` before starting
the v1551 physical Type-551 RBN0 write/readback service. Once
the entire I/O operation returns, it calls `mm_unpin`, then
`mm_free` with the exact owner/type. A verified successful free
zeros the caller's scratch base word, and only then does the
wrapper return the actual v1551 arm outcome.

MM owner 015 is distinct from the currently used low-core
KCORE owners (including BCACHE 6, BADMAP 7, D6FS 010, MEMFS
011, DTFS directory 012, exec launch 013, display text 014).
There are **no new permanent data/BSS words**. The 0200-word
temporary extent exists only during this particular transaction.

If `mm_unpin` or `mm_free` reports refusal, the wrapper returns
failure **and retains the exact physical scratch base** in the
caller-supplied pointer so owner-aware recovery can retry safely.
It never overwrites a pre-existing nonzero pointer, even if
the caller tries to start another transaction. Pin refusal
attempts `mm_free` only on the unpinned buffer, and retains the
base on that free's refusal. MM allocation failures never
start the Type-551 arm. A complete physical arm that succeeds
but whose MM release fails is not reported to callers as an
ordinary successful transaction.

## Executed tests

`daimos-dtfs-owned-scratch-v1552.sh` runs the actual wrapper
instructions on the PDP-6 with strictly checked mock MM API
outcomes, including the complete six-argument no-reclaim ABI,
expected owner 015, exact 0200-word allocation, pin holding
during v1551, and free-after-unpin. **11 scenarios PASS**:
successful/repeated lease, failed underlying intent with proper
cleanup, MM shortage, pin refusal, pin refusal with failed free,
unpin refusal, free refusal, nonzero pre-existing owner,
missing basep, and additional accepted request lifecycle.

The same test rejects **10 actual-source unsafe mutations**:
missing physical pin, unpin or free; wrong owner or buffer length;
skipping the durable intent call; hiding an arm failure; losing
the retained allocation on failed release; replacing an existing
pointer; and freeing without checking unpin success.

`daimos-dtfs-owned-scratch-real-mm-v1552.sh` separately links
unchanged production `mm_pdp6.s` allocator, extent metadata,
`mm_pin`, `mm_unpin` and `mm_free` instructions against the real
v1552 wrapper. The MM arena contains 02000 octal words, and
the test allocates, pins, observes the exact extent owner/type,
unpins and frees the 0200-word extent **twice**, leaving
`mm_extent_count=0`, and finally removes the arena and confirms
a real MM shortage prevents physical arming. **PASS**. Only the
underlying v1551 Type-551 service is simulated in this real-MM
test; that physical service has its own source-linked native
v1551 acceptance. These two suites do not substitute for one
complete booted guest exercising real Type-551 interrupt/DMA.

Reproduce:

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-owned-scratch-v1552.sh
sh tests/validation/daimos-dtfs-owned-scratch-real-mm-v1552.sh
```

## Remaining KCORE P0-B work

The wrapper is deliberately **not linked into live DTFS MRES**.
There is no automatic DTVOL2 mount admission, on-mount armed state,
mandatory first-data-write gate, or exclusive owner-safe CLEAN
unmount. The caller must serialize the provider and retain its
basep across any cleanup refusal. Native negative tests guard
against dropping that pointer; the real provider must have an
owner-safe way to retain it until the owning transaction ends.

Next, integrate the verified scratch lease/dirty barrier into the
provider's first-write transaction without bypasses, and then
implement its final CLEAN unmount. Run actual Type-551 partial
media/reinsertion/cold-boot tests before closing P0-B.
P0-A complete; P1-C open. No optimization undertaken.
