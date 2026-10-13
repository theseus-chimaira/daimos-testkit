# DAIMOS native codec production ABI: v050 testkit design proposal

**Status: design only. NOT yet an implemented ABI.** This document is kept
in the versioned testkit experiment, not production `pdp10-doc`, until
implementation, stack measurement, and integration tests finish.

## Existing experimental entry points

- Encoder input AC1 (input pointer), AC2 (input 36-bit word count),
  AC3 (output pointer), AC4 (available output words), AC17 PDP-6 pushdown
  stack pointer. Returns AC1 = encoded word count, or full-word -1 for
  insufficient output. AC0..AC16 are treated as volatile in the existing
  assembler tests. Its error path can leave the output partly modified.
- Decoder input AC1 (compressed pointer), AC2 (compressed word count),
  AC3 (destination pointer), AC4 (exact expected decoded word count),
  AC17 stack pointer. Returns AC1 = 0 success, -1 failure. It also can
  leave the destination partially modified on failure. Decoder accepts
  kind-0 word, kind-1 zero-run and kind-2 *even-halfword* references; it
  rejects kind-2 odd-halfword offsets and kind-3.
- Both assume valid caller memory mappings. Neither validates arbitrary
  pointer provenance, overlapping buffers or 18-bit address wraparound.
- Current native static code sizes are 129 encoder + 99 decoder = 228
  36-bit words, codec .data/.bss = 0. These measurements do *not* include
  caller buffers, stack high-water, interfaces, wrappers or pending
  production safety checks.

## Proposed smallest production interface

1. Keep two **bounded one-shot** primitives first, matching the already
   tested calling convention. Enforce non-overlapping input and output
   ranges and verify address arithmetic cannot wrap in the caller or
   validated entry shim. Caller supplies a trusted exact decoded size.
2. Document registers precisely: either AC0..AC16 caller-clobbered for
   assembly-only kernel use, or provide a separate versioned C-callable
   wrapper saving the kernel's actual ABI callee-saved set. Do not assume
   a C ABI until disassembly and calling conventions are checked.
3. Errors should distinguish invalid compressed stream, short input,
   insufficient output and impossible buffer bounds only after measuring
   code growth. Full-word -1 remains the interim shared failure code.
4. Decoder output is untrusted until entire decode returns success.
   Boot and executable consumers must not execute a partially decoded
   buffer. Prefer validate-then-publish semantics at the caller, rather
   than duplicating a full output buffer inside a RAM-constrained kernel.
5. If the caller can guarantee a complete contiguous stream, avoid
   streaming state entirely: it costs RAM and complicates control-group
   rollback. Streaming is optional until a concrete boot/TSFS/swap
   consumer demonstrates the need.

## Resumable streaming design (deferred pending consumers)

If genuinely required, process a **complete control group** as the unit of
atomic progress. Group header contains 1..30 tokens; following it are
ceil(number of matches/2) descriptor words and then literals. A streaming
boundary must not split these pieces without retaining cursor/flags,
descriptor-half toggle, group counters, and output history for backrefs.
A single bounded group may produce as many as 30*127 = 3810 decoded
words; callers may instead stream inside a group with explicit state and
additional RAM. The most memory-efficient alternative is to require
caller-supplied complete group and output space and return NEED_SPACE
without consuming the group. Exact state footprint and minimum useful
chunk size must be established on actual consumers; do not invent a
constant size. The 128-word backreference history must survive splits.

## Release gates / tests still open

- Prove input/output pointer range validation and no 18-bit wrap.
- Fill stack with a canary and measure encoder and decoder high-water
  independently for normal, match-heavy and malformed streams. Current
  test CRT reserves 512 words but **does not measure usage**.
- Probe encoder insufficient-capacity behavior across control-group
  insertion and verify no writes past the advertised boundary.
- Fuzz descriptor fields including nonzero unused control bits, incomplete
  groups and trailing input. Verify strict rejection as required by spec;
  v048 currently has only 22 targeted cases, not exhaustive fuzzing.
- Determine whether production requires canonical stream validation
  (zero unused flag/descriptor bits). Native decoder's existing acceptance
  of noncanonical unused bits should be reviewed deliberately.
- Compare CPU cost and net resident code+stack+workspace footprint in
  actual boot, DXR, TSFS and swap environments before replacing D6LZ36.
- Keep all implementation experiments in versioned testkit directories
  until concurrent KCORE work is complete and production edits authorized.

## Evidence through v049

- Host policy model: 81 DXR images, 159973 raw / 131463 compressed words.
- PDP-6 exact-stream and native decode: three complete mid-sized DXRs,
  plus the largest `dsh.dxr` (15870 raw / 12723 compressed words).
- v048 targeted corruption and output guard tests: 22 PASS.
- Native grouped two-word encoder 129 code words; decoder 99 words.

No production files were touched in developing this design.
