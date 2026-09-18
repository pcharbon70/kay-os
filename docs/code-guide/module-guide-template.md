---
title: Module guide template
description: Required structure for a Kay OS Code Companion module guide
---

# {Module name}

{Give a one-paragraph, non-specialist summary of the module and its current
implementation state.}

## Problem

{Explain what problem this module solves, why Kay OS needs it now, and the
observable outcome. Separate current implementation from future intent.}

## Mental model

{Give the smallest useful conceptual model. Add a Mermaid flow, sequence,
state, or ownership diagram when relationships are easier to understand
visually. Explain every node and boundary in prose.}

## Important files

{List the files in recommended reading order. State the responsibility and
language of each one. Use repository-relative paths in backticks so the
coverage verifier can check them.}

## Execution flow

{Trace control and data from entry to completion. Distinguish build time,
boot time, normal execution, failure handling, and tests when applicable.
Use titled, language-tagged fenced code blocks or checked snippets.}

## Data structures

{Explain layouts, fields, units, alignment, encodings, valid states, and
cross-language or cross-privilege representations. Include a compact table
when it materially improves understanding.}

## Ownership and lifetime

{State who creates, may mutate, lends, transfers, validates, and destroys each
important resource. Explain pointer and buffer lifetime rules.}

## Privilege and trust boundaries

{Identify privilege levels and trusted, validated, untrusted, host-provided,
firmware-provided, and test-only behavior.}

## Failure behavior

{Explain validation failures, diagnostics, cleanup, rollback, halt/reset,
timeouts, and deliberately impossible states.}

## Tests and evidence

{Name exact commands, cases, fixtures, limits, revisions, and retained
evidence. Explain what each test demonstrates rather than listing names only.}

## What this does not demonstrate

{List important claims that are still unsupported: boot, hardware,
concurrency, security, portability, compatibility, performance, or other
future behavior.}

## Language and OS concepts

{Define the C, Zig, assembly, ABI, linker, CPU, and operating-system concepts
introduced here. Link stable project terms to the glossary.}

## Revision and maintenance

{Name the implementation revision reviewed by this guide, its reopening
conditions, and which source/config/test changes require this guide to change.}
