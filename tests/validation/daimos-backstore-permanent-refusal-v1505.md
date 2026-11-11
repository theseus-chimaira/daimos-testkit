# v1505: source-authentic repeated corrupt-BACKSTORE rollback

The native PDP-6 fixture joins **production** `proc_swap_in`,
`proc_swap_mres_service_v481`, `backstore_verify_allocated_v795`
and `backstore_free`. Backend MM allocation/unpin/free and device
reads are controlled by the existing accepted v1405 fixture.
`proc_event_apply` is an event-observer stub; v1498/v1501 cover the
real event policy separately. The v1493 production extraction and
its two executable unsafe-state mutations run before this fixture.

The driver deliberately supplies **six consecutive slot-0 swap
requests** for the same nonresident DISK owner with one allocation
bitmap bit missing. On every failed checked free it observes:

- failure returned without READY_ONCE or a RESIDENT VM;
- the same DISK record, backing first/count and bitmap unchanged;
- the stable process descriptor no longer TRANSITION-locked;
- no retained MM pin, false backing decrement or premature publish.

After six requests the fixture checks exactly six real payload reads,
six MM rollback frees, six TERM service calls, zero successful
publishes and zero unexpected invariant/exchange calls. Only then
the fixture restores the original bitmap bit and makes a seventh
request. This succeeds, returns the actual `slot|READY_ONCE` code,
publishes once and releases the original backing with exact zero
final accounting. Both the existing v1493 unsafe skip-release and
false-ready mutations continue to be rejected.

Command:

```
DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross \
    sh tests/validation/daimos-backstore-permanent-refusal-v1505.sh
```

**Limits:** These six retries were explicitly forced by the test
driver; they are not evidence of any real clock cadence or infinite
loop in production. The result proves fail-closed ownership across
an arbitrary sequence, but does not prove terminal progress if the
bitmap can never be repaired. That failure-recovery feature remains
OPEN and needs an explicit quarantine/notification design without
discarding the private executive continuation. This fixture adds
no production KCORE code, resident RAM or storage-format changes.
