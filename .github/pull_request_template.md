## Summary

<!-- What changed and what user-visible or architectural outcome does it produce? -->

## Reader's guide

### Why this change exists

<!-- Explain the problem in plain language. -->

### Execution flow

<!-- Trace the relevant path through files/components. Use Mermaid when useful. -->

### Files to read, in order

<!-- Give a short ordered reading path and the purpose of each file. -->

### Important data structures

<!-- Explain new or changed layouts, fields, encodings, and invariants. -->

### New C/Zig/assembly concepts

<!-- Define language or machine concepts for a non-specialist reader. -->

### Invariants and safety assumptions

<!-- State what must remain true, including ownership and lifetime rules. -->

### Failure paths

<!-- Explain rejection, halt, rollback, timeout, and diagnostic behavior. -->

### Tests and what they prove

<!-- List exact commands/cases and their evidence boundary. -->

### What this change does not prove

<!-- Prevent broader boot, hardware, security, or compatibility claims. -->

## Code Companion checklist

- [ ] The code map and affected module guides are updated.
- [ ] New `src/` files appear in `docs/code-guide/coverage.tsv`.
- [ ] New terminology is defined in `docs/code-guide/glossary.md`.
- [ ] Source comments explain why and invariants rather than teaching syntax.
- [ ] `scripts/docs/verify-code-guide.sh` passes.

## Verification

<!-- Include exact commands, revisions, dirty state, results, and artifacts. -->

## Boundaries and follow-ups

<!-- Record deferred work, unchanged exclusions, and gate-reopening conditions. -->
