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

The physical T7500 inventory is currently deferred by explicit user decision.
Virtual experiments may proceed provisionally, but M0 Phase 1 cannot close
until that evidence is collected and reviewed.

