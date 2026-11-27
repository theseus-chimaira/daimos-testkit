# v1992 physical directory FULL FREE/SOURCE rollback

    make test-pure-directory-full-build-v1992 DAIMOS_REPO=/path/to/DAIMOS
    make test-pure-directory-full-physical-v1992 V1992_BUILD=/path/to/new/build V1992_WORK=/path/to/new/work
    make test-pure-directory-full-audit-v1992 V1992_BUILD=/path/to/new/build V1992_WORK=/path/to/work

Rebuild the original v1987 INIT/marked COMP/POST fixture from the
committed source, then build the strict swapless 64K PDP6 GCC directory
profile with DAIMOS_PBM_DIRECTORY_V1983=1 and
DAIMOS_PBM_IDLE_RECOVER_V1990=1. No previous temporary build is required.
The DAIMOS-specific mkauxstore and mkdtfs media producers are built from
the same checkout under the unique work directory. Their CLI/format
contracts differ from (or are absent in) the installed standalone tools.
Other utilities use PDP10_PREFIX; no shared tool is replaced. Root
media is structurally checked with the source-linked TSFS validator.

The runner extends the v1991 scoped leaf-refusal protocol and retains
its V1991 monitor examine markers. Refuse actual FULL finish once,
then refuse target FREE after the actual target unpin succeeds. Refuse
FREE again at the first idle retry. On the second idle retry, let
target FREE succeed but refuse source unpin; repeat the unpin refusal
at the third idle retry. Allow the fourth idle retry to retire only the
original source pin. No artificial MM owner, pin, process, clock,
scheduler or payload state is deposited. Every injected entry
instruction is restored at the live stack return PC.

The independent verifier requires the entire MM table to differ from
the original only by the expected target pin retirement, target
deletion and original source pin retirement. It checks exact source
geometry, backing and credential, BRK escrow (including absent target
in SOURCE), the original encoded payload, original retry clock/backoff,
no READY while held, and the normal FULL retry and restored EXEC.
The healthy v1987 lifecycle oracle checks all admitted children, exact
TERM/WAIT/EXIT, final MM/HALT and unchanged root tapes. Fifteen negative
trace controls are included, including wrong phase, stale target,
target pin change and wrong source unpin argument.

This tests known-pin FREE/SOURCE rollback only, not hardware failure,
ambiguous ownership, dirty DROP, source loss or general mode3 acceptance.
A fresh image is compared with its actual captured hashes, not presumed
byte-identical to unavailable historical v1987/v1991 artifacts.

## Accepted physical result

DAIMOS source 18a44866, installed SIMH cf52e6c6. Fresh source-built
GCC MRES 5917 words, zero BSS. TSFS3 members,55 files,316 extents.
12 admitted children (fixture ceiling), four251-word bitmap owners,
one3584-word RAW and seven4096-word resident children at pressure;
33 descriptors, free1334, largest APR-aligned gap512. Original slot3
bitmap062400/251, provisional target160000/4096. Five scoped refusals:
finish, target FREE twice, source UNPIN twice. Actual idle ticks
6362/6394/6458/6586 and delays16->32->64->128->256. Exact owners and
payload, original heap, no READY, retry pending retired before normal
FULL, marked-to-unmarked EXEC4096->2048, all12 exact waits, final
MM/HALT and unchanged tapes. All15 independent corrupted traces reject.
No production change or new compiler/assembler defect demonstrated.

The first media build failed because installed mkauxstore lacks the
DAIMOS confirmation/conversion options; the next lacked mkdtfs.
Built those two tools from DAIMOS source and regenerated failed drum
media, then completed the same fresh build. Existing compiler include
order and libc built-in declaration warnings observed. No shared tool
installation changed. Historical byte identity not claimed; current
GCC MRES size agrees with v1991. Current pressure free differs by two
words from historical1332, not a measured source-change saving.

Evidence relative TMPDIR:
pure-directory-physical-build-v1992.1zNwBW/build,
pure-directory-physical-replay-v1992.8OKkKf/physical.clean.
