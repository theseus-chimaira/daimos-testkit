# Staged PDP-6 D6CODEC failure-path stack regression v1357

The native test executes multiple failing calls through the staged
v055 register-preserving decoder and encoder wrappers using the
512-word canary CRT from the older v051 complete-DXR test.

Cases cover malformed or truncated decoder control data; address-wrap
rejection before input access; encoder literal-capacity failure after
a group header; zero-run capacity failure; and insufficient capacity
after the encoder enters its repeated-word match-search path.

The test checks that each call returns the full-word -1 failure
result. The final CRT canary assertion is 016 octal (14 decimal)
stack words, including the CRT main call, v055 register saves and
the codec call chain. This matches the full-DXR v1356 stack observation
but is **not** a proof for every malformed input, maximal call depth,
or a nested VFS/EXEC/TSFS production stack.

Run:

```
DAIMOS_REPO=/path/to/DAIMOS sh tests/validation/d6codec-stack-fail-v1357/run-v1357.sh
```

The production system still uses D6LZ36; this test changes no
production code or stored media format.
