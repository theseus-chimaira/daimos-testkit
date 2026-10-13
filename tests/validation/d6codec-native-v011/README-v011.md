# v011 native codec fault isolation (not passing)

Isolated reproduction using p10run --machine pdp6 --mode deposit.
No DAIMOS, KCORE, or common testkit build files are changed.

The original v010 reproduction returns __test_exit=1 (native encoder error)
for an 8-zero-word prefix and three following nonzero words.

Separate diagnostic builds distinguished the two error exits in the
v009 encoder. The observed result was code 2 for the zero-run output-capacity
error branch, not code 3 for literal-group capacity. An experiment that
removed this branch did not validate the encoder. The zero-run loop and
register/counter update must be examined in a debugger with a step limit.
Do not disable capacity checks as a workaround. Do not integrate the codec.

The original encoder is deliberately included unmodified for a reproducible
reference; the fault remains OPEN. The run-v010.sh script has a separate v011
workdir and no KCORE rebuild dependency.
