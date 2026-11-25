# Native DTFS physical identity checks during PURE reconstruction (v1925)

Run against the current DAIMOS checkout using the installed tools:

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-dtfs-media-v1925

The first gate runs the actual DTFS private media-proof leaf, original
V1/V2 identity validator, raw-read recovery and both BCACHE invalidation
leaves. It uses independently formatted DTVOL1/DTVOL2 host images and the
existing v1556 controlled Type-551 completion fixture. Nineteen cases
cover clean and armed media, replacement volume IDs, inconsistent DIRTY
or read-only state, read errors, incomplete and false successful reads,
changed saved ID halves, poison/quiescence, unstamped legacy policy and
incomplete identity metadata. Both directory and clean cache tags must
be invalidated for a fresh physical proof. Two unsafe assembly variants
are executed and rejected at native assertion 023 octal.

The second gate links the real RAW DROP, PREFIX/FULL and shared image
bridge, with a controlled register-dispatch/VFS/MM boundary. Ten cases
exercise successful reconstruction, first/last proof refusal, root change
during the last proof, retry after restoration of the original source,
and non-DTFS behavior. The proof must run before header/payload reads
and again after payload, with PI enabled in the fixture. Failed checks
retain the original unpinned RAW suffix, backing and TRANSITION, without
publishing an APR. Both missing-proof variants fail at native assertion
0102 octal. The test checks the private register-dispatch operation but
does not simulate the complete provider lease or actual controller.

Existing isolated non-DTFS image-loader runners link a test-only refusing
provider stub; the stub never manufactures a physical-proof success.
No media replacement occurs in the full guest in these tests. The
physical proof is specific to stamped DTFS and does not detect a reel
exchange and reversal between the two checks, same-ID clones, or mount
metadata replaced before reconstruction. Legacy unstamped reels keep
the approved operator-trust policy, and other providers are unchanged.
