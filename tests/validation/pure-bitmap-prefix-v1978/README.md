# K12 v1978: original PURE prefix lease

    DAIMOS_REPO=$HOME/git/DAIMOS sh tests/validation/pure-bitmap-prefix-v1978/run-v1978.sh

Native PDP6 and KA10 execute the actual staged preparation/cancel code,
v1977 directory codec, full mm_pdp6.s allocator including pin/unpin,
mm_pure_rebase_v1381.s, permanent storage map, and real machine PI gate.
The fixture supplies synthetic mount identity and backing availability;
no provider I/O or live scheduler is needed. Actual private old RAW
unlock/recovery predicates are extracted unchanged for negative checks.
Unrelated VM move/reclaim callbacks must not run. Fault wrappers either
refuse an operation before mutation or lose the reply after real MM
mutation. The write-pass fault is injected after real encoded writes.

Each CPU runs 72 prepare/cancel calls, plus real RAW-drop fallback,
pinned free refusal, exact released-prefix allocator reuse, PI-state
checks and whole u-area/RAW/adjacent-owner checks. Healthy SLEEP/STOP,
176-word canonical candidate in a 256-word prefix of a 1024-word image,
dense/no-fit clean refusal, 27 admission/owner failures, pin and unpin
loss/refusal, old RAW gate rejection of dirty escrow even without pin,
invalid lease identity, dirty write failure, rebase refusal/lost reply,
and final pin-retirement failure/lost reply are covered. Real allocator
is forced to reuse exactly the released prefix; overwrite it and prove
RAW intact. No mode3 publication.

Six source mutations must execute and fail: missing opt-in, wrong
u-area owner, missing pin witness, wrong dirty tag, unsafe full-owner
unpin on cancel refusal, stale backing token. Existing v1926 provider
availability and v1919 deferred RAW/PREFIX recovery regressions remain
separate and must continue to pass with the staged flag absent.

The synchronous lease requires caller-held TRANSITION and global PI
exclusion until commit/cancel; this test does not establish physical
interrupt latency, persistent recovery of a torn candidate, or safe
live mode3 scheduler integration.
