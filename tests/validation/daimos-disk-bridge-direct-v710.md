# v710 — DSK270 / DRM236 bridge direct read bindings

The KCORE bridges for DSK270 and DRM236 each contained a read-side
`JUMPE`, a patched write `JRST` and a patched read `JRST`. The read-side
JUMPE now has its own exported patch-site label and KINIT rewrites its
right half to the installed read service. The write JRST remains.

The absent read branch defaults to `kret_neg1`; the write-side behavior
is unchanged. The deferred module-mover fixed-binding list tracks the
new labels. Two KCORE instruction words are expected to be removed.

Validate assembly, the native read/write path, and linked KCORE maps
before reporting final savings. Full boot with hardware remains separate.
