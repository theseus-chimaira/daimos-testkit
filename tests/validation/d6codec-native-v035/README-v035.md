# v035 — candidate third-word rejection experiment

This native PDP-6 testkit experiment adds an early comparison of the third
word of each candidate match (provided >=3 words remain) before entering
the exhaustive candidate-extension loop. The comparison is semantics-safe:
a useful word match must span at least three words. There is no index or
additional persistent RAM.

Tested in the PDP-6 simulator. Both 128-word encoder-only fixtures and all
five existing encoder/decoder regression tests PASS. Encoder size grows
from 126 to 134 words (+8); decoder remains 99 words. Combined becomes
233 words, with zero codec static data/BSS.

| Input | v031 126-word encoder | v035 134-word candidate |
|---|---|---|
| 128 pseudo-random words | fails by 50000, passes by 55000 | same |
| 128 identical words | fails by 2000, passes by 2500 | same |

The measured step bounds do not establish any performance improvement,
and the extra 8 resident instructions impose a definite RAM cost. The
candidate is rejected as a production recommendation and retained only
as a testkit experiment. Do not mistake step-limit bounds for PDP-6 CPU
cycles or exact encoder-only retired instruction counts. Further work
should seek a genuinely lower-complexity match search or collect exact
instruction measurements for representative DAIMOS workloads.

DAIMOS, KCORE, shared testkit configuration and concurrent work untouched.
