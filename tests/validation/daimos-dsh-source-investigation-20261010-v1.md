# DSH SOURCE and function recursion investigation — 2026-10-10 v1

**Status: resolved and verified.** The observations below describe the
initial failing baseline. The later correction uses bounded argument frames
and restores both SOURCE and recursion without reducing DSH's argument limit.

## Verified resolution

The nested evaluator entered `dsh_exec_simple_node` but failed before
`dsh_expand_node_argv()` could execute. Temporarily changing the global
`DSH_MAX_ARGS` from 20 to 4 made all four SOURCE regressions pass, confirming
the excessive nested PDP-6 user-stack frame. That limit reduction was only
a diagnostic and was reverted.

The production design keeps the 20-word parser capacity. Simple commands
expand up to four arguments into a small stack frame. Wildcard, alias, and
larger argument expansions return to the caller before entering the rare
full-width path, which borrows a 20-record LIFO scratch extent through
`SYS_BRK` and releases it after execution. No permanent BSS allocation or
general libc allocator is linked. The `SYS_RUN` execution ABI independently
limits external calls to 16 arguments; excess arguments to an existing
executable produce status 126.

The SIMH harness also formerly recognized any literal `# ` in echoed input
as the next DSH prompt. Anchoring that marker to a terminal line start fixes
the nine trailing conformance false failures, including quoted and comment
commands. The final PDP-6 run passes **115/115 conformance probes** and the
real-DCS foreground/TTY acceptance. The same-source DXR image grew from
035071 to 035273 octal words (+0202), with BSS unchanged at 014445.

## SOURCE

The original conformance case `dsh-source-positional-restore` failed. A smaller
direct `SOURCE /CONFIG/S I; ECHO DIRECT:$?` reproduction also failed after
creating `/CONFIG/S` containing `ECHO SOURCE:$1`. In SIMH the shell returns
to `LOGIN:` rather than printing the expected output.

Temporary markers in `dsh_exec.c` confirmed that SOURCE enters, successfully
opens its input, reads one S6REC line, invokes `dsh_script_feed()`, and
successfully parses its tokens. Control then reaches the nested evaluator
but the process disappears before it returns. Markers before/after evaluation
give `EVAL START` with no corresponding `EVAL DONE` for the nested command.

Disabling the nested script-workspace reuse did not change this result.
Reading packed native SIXBIT directly with `u_text_gets6()` rather than
unpacking/repacking character data also did not solve the failure. Previous
simulator instrumentation reported no user-memory-protection fault.

The follow-up traced nested `dsh_exec_simple_node` entry and isolated the
twenty-record local array as the stack-pressure cause. The final design
avoids a large static argument arena and keeps independent direct/nested
SOURCE tests so early termination cannot masquerade as positional restore.

## Function recursion

`DEF F DO F DONE; F; ECHO STATUS:$?` originally timed out instead of
returning `STATUS:2` at `DSH_FUNC_MAX_CALLS`. The bounded-frame correction
now passes the target recursion-limit probe.

All diagnostic markers and unsuccessful workspace/packed-reader experiments
were discarded. Only the verified bounded-frame correction was retained.
