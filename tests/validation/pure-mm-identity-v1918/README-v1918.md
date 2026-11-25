# Native DROP/PREFIX owner identity gate, v1918

Run on the PDP-6 simulator using the installed KCC, DAS and p10run:

    DAIMOS_REPO=$HOME/git/DAIMOS sh run-v1918.sh

Set KEEP_TEST=1 to retain generated source, assemblies and mutation logs
under TMPDIR. Production DROP/PREFIX and the real MM rebase, claim,
release and commit assembly are linked into the native guest. The
allocator, pin/unpin, immutable loader and PI operations are controlled
fixtures inherited from v1384; this is not a physical PI6 test.

Six cases check a lost successful DROP rebase reply, lost successful
PREFIX claim/commit/release replies, foreign retag after release and an
extra pin during prefix I/O. Checks cover exact physical identity,
owner/type/size, pin count, original suffix data, backing, storage mode,
TRANSITION, escrow, PI balance and allocation/free/unpin counts.
Seven scanner cases cover adjacent independent MODULE/KERNEL_DYNAMIC
namespaces, a preceding overlap, an additional same-slot user owner,
capacity overflow, zero span and physical-address overflow. Both
exact-base lookup and initial discovery are checked.

Two private source mutations must fail native assertions (not compilation,
linking or timeout): a DROP that trusts the rebase return rather than
the committed descriptor (0101), and a PREFIX release that bypasses the
original suffix owner/pin proof (0403). The baseline passes all 13 cases.

The gate validates synchronous DROP/PREFIX decisions only. Deferred
reconciliation of held DROP/PREFIX owners and terminal cleanup remain
K06 work. No physical or production acceptance is claimed.
