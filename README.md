# Kay OS

Kay OS is an experimental Intel x86-64 operating system informed by the fault
containment, supervision, isolation, and message-oriented principles of
Erlang/OTP and the BEAM virtual machine.

The first proof-of-concept delivery is a minimal kernel that boots a native
user-mode serial CLI. Later milestones add protected services, an unprivileged
project-owned BEAM runtime with process-local tracing garbage collection, and
integrated recovery tests. AtomVM is not an implementation dependency.

## Current state

M0 Phase 1 established the target, toolchain, virtual fixture, inventory
boundary, and reproducible freestanding build baseline. Phase 2 is defining
and exercising boot, image, console, time, and authority contracts. It now
produces a static higher-half ELF, but no guest boot has been accepted yet.

Section 1.2 now provides a non-bootable fixed-address ELF that qualifies the
selected Zig/C/assembly build boundary. It is a toolchain fixture, not a kernel
or firmware-loadable image.

The initial virtual fixture is deliberately small:

- Intel x86-64 with the QEMU `Nehalem-v1` CPU model;
- one virtual socket, core, and thread;
- 64 MiB of RAM;
- TCG acceleration and a versioned Q35 machine;
- SeaBIOS, headless serial I/O, no NIC, and no writable guest storage.

The governing research and plans remain in
[pcharbon70/atom-os-research](https://github.com/pcharbon70/atom-os-research),
whose historical repository name is not the operating-system name.

## Follow the code

The [Kay OS Code Companion](docs/code-guide/index.md) explains the code for
readers who are not already C, Zig, assembly, or kernel developers. Its
Markdown source builds into a searchable HTML/CSS site with highlighted code,
Mermaid diagrams, navigation, and a project glossary.

The first guided tour is [M0 build and ABI](docs/code-guide/m0-build-and-abi.md).
Continue with [M0 boot and interface contracts](docs/code-guide/m0-boot-and-interface-contracts.md).
To build and review the site locally:

```sh
python3 -m venv .venv-docs
.venv-docs/bin/pip install -r requirements-docs.txt
KAY_MKDOCS=.venv-docs/bin/mkdocs scripts/docs/verify-code-guide.sh
KAY_MKDOCS=.venv-docs/bin/mkdocs scripts/docs/preview.sh
```

`scripts/docs/serve.sh` provides MkDocs live reload when the local Python
installation supports its filesystem watcher. `preview.sh` performs a strict
build and serves the generated static site without that optional dependency.

## M0 development inputs

- `.tool-versions` pins Zig 0.16.0 for `asdf` users.
- `config/m0/development-baseline.json` is the machine-readable selected-input
  record.
- `scripts/m0/verify-development-baseline.sh` rejects missing or drifting host
  inputs.
- `scripts/m0/inventory-t7500.sh` captures a redacted, read-only physical-unit
  inventory when the lab machine becomes available.
- `config/m0/build-closure.json` fixes the freestanding ELF, ABI, instruction,
  failure, and reproducibility policy.
- `scripts/m0/verify-build-closure.sh ABSOLUTE_EVIDENCE_DIRECTORY` builds two
  clean absolute-path copies, audits both language directions and the assembly
  entry, and runs the negative dependency cases.
- `docs/m0/build-closure.md` explains the qualified boundary and its limits.
- `config/m0/phase-01-cases.json` binds the virtual integration cases and
  finite deadlines without treating physical inventory as a QEMU input.
- `scripts/m0/verify-phase-01.sh ABSOLUTE_EVIDENCE_DIRECTORY` runs the complete
  Phase 1 virtual gate and preserves its positive and negative observations.
- `docs/m0/phase-01-integration.md` explains the gate, evidence layout and
  physical-qualification boundary.
- `config/m0/phase-02-contracts.json` freezes the selected loader, image, ABI,
  console, clock, authority, and fatal-fault contracts.
- `scripts/m0/verify-phase-02-contracts.sh ABSOLUTE_EVIDENCE_DIRECTORY` runs
  bounded parser/authority cases and two clean higher-half image builds.
- `scripts/m0/verify-limine-release.sh` authenticates the pinned Limine input;
  `scripts/m0/build-boot-image.sh` creates the read-only BIOS ISO once
  `xorriso` is available.
- `scripts/m0/verify-phase-02.sh` is the complete signed-input integration
  gate, including deterministic ISO builds and the Phase 1 regression suite.

The physical T7500 inventory is currently deferred by explicit user decision.
It is a Phase 3/final-M0 physical-qualification input, not a prerequisite for
the independently pinned QEMU fixture. M0 Phase 1 virtual integration and
Phase 2 contract work may proceed without it; no such work qualifies the
physical motherboard.

Kay OS source is licensed under the Apache License, Version 2.0.
