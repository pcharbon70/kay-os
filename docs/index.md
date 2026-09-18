---
title: Kay OS Code Companion
description: A guided path through the Kay OS implementation
---

# Kay OS Code Companion

Kay OS is an experimental Intel x86-64 operating system. This site explains
how its implementation grows for readers who do not begin as C, Zig, assembly,
or kernel specialists.

The guides are deliberately layered. Start with the outcome and mental model,
then follow the execution flow, data structures, ownership rules, failure
paths, tests, and language concepts. Each guide ends by stating what the code
does **not** yet demonstrate.

!!! warning "Evidence boundary"

    Compiling and linking a fixture is not the same as booting it. A QEMU test
    is not physical Dell Precision T7500 qualification. Every guide identifies
    its exact evidence boundary.

## Start here

1. Read the [Code Companion overview](code-guide/index.md).
2. Follow the [M0 build and ABI](code-guide/m0-build-and-abi.md) tour.
3. Continue with [M0 boot and interface contracts](code-guide/m0-boot-and-interface-contracts.md).
4. Use the [glossary](code-guide/glossary.md) whenever a term is unfamiliar.
5. Consult the M0 engineering records for exact decisions and test evidence.

## How the site is produced

The reviewed source remains Markdown in the repository. Material for MkDocs
turns it into this navigable HTML/CSS site and renders highlighted code and
Mermaid diagrams. The generated `site/` directory is disposable and is not
committed.
