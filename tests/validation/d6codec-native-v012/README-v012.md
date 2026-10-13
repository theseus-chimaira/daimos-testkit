# Native PDP-6 codec fault isolation v012

Tests remain isolated; no DAIMOS/KCORE or shared testkit configuration changed.

An isolated three-nonzero-word input also returns encoder error from the
v009 assembler encoder when run with `p10run --machine pdp6`. This means the
v010 failure is not exclusively caused by zero-run search. A prior attempt
to change zero-run branch direction and change its group control constant
also failed. The experiment should not proceed to paired descriptors before
correcting the encoder's common entry/exit and copy path.

The original zero-run failure remains in v010/v011. This v012 fixture
contains just three nonzero input words selected from the same source
array; source and output counts are three. The native assembler encoder and
fixed decoder are unmodified copies from v011. The v012 fixture is not
part of automated passing tests.

This checkpoint is KNOWN FAILING and does not establish compression
correctness or a working native encoder.
