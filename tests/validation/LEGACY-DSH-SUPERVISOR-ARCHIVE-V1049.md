# Historical DSH and INIT/SUPERVISOR test archive (v1049)

This branch preserves ancestry from the October 2026 testkit branches
`dsh-phase0-history-repair-tests-20261012-v7` and
`supervisor-idle-tty-activate-testkit-20261013-v5`.

The historical branches are intentionally merged with the `ours`
strategy. Their exact commits remain reachable but obsolete tests are
not introduced to present testkit main. In particular, current DAIMOS
PID 1 does not delegate to `/SYSTEM/EXEC/SUPERVISOR`, and current DSH
does not implement the earlier two-flock/truncate HISTFILE repair path.
Do not claim those historical feature acceptance runs apply to main.

The independent D6FS bounded-undo interruption-cut host experiment
was recompiled on 2026-11-03 with C99 warnings as errors. Its model
passed 5,805 append/replay interruption cases and demonstrated an
unsafe write reordering, but its assumptions about persistent writes
are not hardware-verified. It is neither an installed D6FS journal
format nor a production boot-replay implementation.

To recover an experimental source or test, use `git show` on either
preserved parent commit. Any future reintroduction must reconcile
current code interfaces and run its own acceptance tests. The archive
is retained only to avoid losing potentially useful historical work.

## v1053: nested-UUO stress history

The historical `testkit-dsh-nested-uuo-stress-20261022-v54` commits
are now ancestors of this archive. Their unreconciled nested-process,
angle-parameter lexer and EDCORE experiments remain historical only.
The branch's separate worktree held twelve untracked diagnostic probes
and one modified runtime report. Exact copies and their verified hashes
are now in testkit main under `tests/archive/dsh-nested-uuo-v1053/`.

The current media-isolation regression passed while reviewing the v54
branch. The old v54 test sources are not a basis for claiming those
nested-UUO bugs are fixed; they need independent guest reproduction.
The v1053 ancestry merge does not alter current active regression
targets or DAIMOS production sources.
