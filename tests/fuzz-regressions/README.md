# Sanitized regression inputs

`geometry-placement-leak.bin` is the preserved task-4 leak reproducer: 513 zero bytes, or 64 eight-byte legal-choice ranks plus one trailing byte. It drives actual actions and placement enumeration, rather than stopping at game construction. RLC 0.4.13 omitted owning-local cleanup on later return paths in the original staging helpers; the single-exit wrappers fix that leak without disabling sanitizers.

After building the current instrumented fuzzer as described in `tests/README.md`, replay it separately from the mutation campaign:

```bash
/workspace/4hammer-validation/task4-rules-fuzzer \
  tests/fuzz-regressions/geometry-placement-leak.bin -runs=1
```

Require a zero exit and no sanitizer errors. This input verifies native memory safety for the exercised sequence, not tabletop semantics. The deterministic suite separately checks rollback, invalid paths and cancellation of trapped movement. Legal-choice ranks depend on action enumeration; regenerate broader gameplay seeds when schemas or action legality change.
