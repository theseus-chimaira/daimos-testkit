# DSH SOURCE and function recursion investigation — 2026-10-10 v1

This report records **unresolved** failures. No shell production fix was
committed from these experiments.

## SOURCE

The existing conformance case `dsh-source-positional-restore` fails. A smaller
direct `SOURCE /CONFIG/S I; ECHO DIRECT:$?` reproduction also fails after
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

Next, trace the nested `dsh_exec_simple_node` and `dsh_expand_node_argv`
entry and check the saved user stack, particularly nested 20-argument local
arrays and function-call return addresses. Do not adopt a large static
argument arena merely to mask a stack or code-generation defect; RAM is the
primary optimization constraint. Preserve independent direct and nested
SOURCE tests so an early termination is not confused with positional restore.

## Function recursion

`DEF F DO F DONE; F; ECHO STATUS:$?` currently times out instead of
returning `STATUS:2` at `DSH_FUNC_MAX_CALLS`. Inspect call-depth propagation,
function body node preservation, and bounded argument frames with a separate
target test. A passing host probe-format check is not proof of target success.

All instrumentation and unsuccessful shell source experiments were restored
in the isolated DAIMOS worktree; neither failure has a verified correction.
