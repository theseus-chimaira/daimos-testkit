# Filesystem MRES second-level vector accounting v683

An isolated assembly/link experiment measured 38 text words for the
`fs_mres_vector_target`, `fs_mres_vector_dispatch`, and
`fs_mres_context_vector_dispatch` machinery plus identical external helpers.
The minimal two-entry replacement and the same helpers linked to 5 words.
Thus 33 words is a **gross** code upper bound for this artificial comparison,
not a net KCORE saving. Real direct entry points require patched targets,
operation validation, context calling conventions, and preserved serialization.

Each of D6FS, MEMFS, DTFS, TSFS currently retains eight two-target packed
vector words, 32 words across these four modules. These are MRES storage,
not KCORE storage. Removing packed vectors might recover some MRES data,
but one target per operation can easily be larger unless operations are
specialized or binding addresses are embedded in existing instructions.

The script counts populated operation entries from the live sources.
No production source, linker, or MINIT behavior was changed.
