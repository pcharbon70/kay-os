# Kay OS

Kay OS is an experimental Intel x86-64 operating system informed by the fault
containment, supervision, isolation, and message-oriented principles of
Erlang/OTP and the BEAM virtual machine.

The first proof-of-concept delivery is a minimal kernel that boots a native
user-mode serial CLI. Later milestones add protected services, an unprivileged
project-owned BEAM runtime with process-local tracing garbage collection, and
integrated recovery tests. AtomVM is not an implementation dependency.

## Current state

M0 Phase 1 is establishing the target, toolchain, virtual fixture, physical
inventory procedure, and reproducible freestanding build baseline. No bootable
Kay OS image exists yet.

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

The physical T7500 inventory is currently deferred by explicit user decision.
It is a Phase 3/final-M0 physical-qualification input, not a prerequisite for
the independently pinned QEMU fixture. M0 Phase 1 virtual integration and
Phase 2 contract work may proceed without it; no such work qualifies the
physical motherboard.

Kay OS source is licensed under the Apache License, Version 2.0.
