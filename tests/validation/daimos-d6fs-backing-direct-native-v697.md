# v697 — linked and PDP-6 tested D6FS direct-binding experiment

The experiment from v696 is linked both ways with `dlink -b 0 -A` using
the v694 KCORE map. The resulting baseline `.dxr` is 800 bytes and the
direct-call candidate is 784 bytes, a **16-byte reduction representing two
36-bit instructions** in this image encoding. This is an isolated linked
`fs_backing` comparison, *not* a full-MRES integrated build.

The native PDP-6 test runs each variant's extracted physical-backend
dispatcher and root-accounting paths. It checks missing-backend failure,
then patches the four backend slots and, for the candidate, the four root
`PUSHJ` instructions. Read and write root-accounting increments and
successful provider returns PASS for both variants. The baseline test
explicitly patches the DSK default-zero entries to `kret_neg1` before
calling an absent backend; default-zero is not itself a safe absence state.

The candidate is viable at the isolated branch/call level, but production
integration still requires updating four MRES export indices, their KINIT
patch writes, the D6FS package `-X` list, and verifying both singleton and
multi-member roots plus secondary mount I/O. There is no production change
in v697.
