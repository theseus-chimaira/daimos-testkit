# PURE mutation admission at the serialized dispatch boundary, v1932

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-mutation-lease-v1932

The PDP-6 native gate links the actual provider gateway, read-only
policy, PURE backing scanner and D6FS unlink leaf. Controlled provider
wait publishes a matching or unrelated PURE owner, or changes mount
policy, before acquisition. Sixteen WRITE/TRUNCATE cases cover DTFS
and D6FS, exact owner refusal, RO refusal, unrelated owner and no owner.
Dispatch arguments, stack balance and lease release/wakeup are checked.
Two D6FS unlink cases verify that the newly resolved child, not the
parent or an earlier lookup, is checked before reading its FCB.
Four unsafe variants fail executed native assertions. The DTFS unlink
oracle also checks protected native/TENEX children before mutation.
Historical isolated lease and VFS fixtures link explicit nonphysical
state/stubs. Native provider destinations and wait completion are
controlled; this is not whole-guest PI6 acceptance.

This closes delayed mutation admission only. It does not establish
an executable reservation spanning the entire RUN/EXEC load, or prevent
owner publication during a mutation already in progress. Those lifetime
obligations remain open, as do direct MEMFS mutation admission audit
and integrated physical acceptance. Rename destination replacement is
not implemented by the inspected providers.
