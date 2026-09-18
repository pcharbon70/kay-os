# M0 Phase 1 decisions

This record binds the implementation inputs selected before Kay OS begins its
freestanding build qualification. It implements the decision portion of
`m0-p01-decisions`; it is not boot or milestone-acceptance evidence.

## Accepted decisions

| Decision | Selection | Status |
| --- | --- | --- |
| Operating-system name | Kay OS, in honor of Alan Kay | Accepted by user on 2026-09-17 |
| Implementation repository | Public `pcharbon70/kay-os` repository | Accepted by user on 2026-09-17 |
| Kernel language | Zig | Accepted by user on 2026-09-08 |
| Toolchain | Zig 0.16.0, LLVM backend and LLD path | Accepted by user on 2026-09-17; executable qualification pending |
| Initial guest memory | 64 MiB | Accepted by user on 2026-09-17 |
| Emulator acquisition | Linux Mint/Ubuntu distribution QEMU and SeaBIOS packages | Accepted by user on 2026-09-17; QEMU `1:8.2.2+ds-0ubuntu1.18` and SeaBIOS `1.16.3-2` installed |
| Physical inventory | Defer collection while virtual work proceeds | Accepted by user on 2026-09-17; moved to `m0-p03-inventory`, where it blocks final M0 and physical claims rather than Phase 1 virtual integration |
| Section 1.2 fixture | Non-bootable fixed-address ELF at a synthetic 2 MiB base | Accepted by user on 2026-09-17 |
| Build driver | `build.zig` plus validation scripts | Accepted by user on 2026-09-17 |
| Native boundary | Bidirectional Zig/C ABI plus assembly entry; C compiled by `zig cc`; no libc | Accepted by user on 2026-09-17 |
| Repository license | Apache License 2.0 | Accepted by user on 2026-09-17 |

## Selected virtual profile

The selected profile is QEMU `qemu-system-x86_64`, TCG, `pc-q35-8.2`,
`Nehalem-v1`, one virtual socket/core/thread, 64 MiB, explicit SeaBIOS,
headless serial I/O, no network device, and no writable guest storage. The
machine version, CPU model, package versions, firmware path, and binary hashes
must be checked by the executable baseline verifier before use.

This fixture is not a Dell Precision T7500 motherboard model. It provides an
older Intel x86-64 instruction baseline for reproducible virtual bring-up.

## Qualification boundary

The build must use a freestanding x86-64 target, disable the red zone, avoid
implicit libc and host syscalls, keep FP/SIMD outside the initial execution
contract, enumerate undefined helpers, and retain ABI/disassembly evidence.
Experimental incremental compilation and the experimental self-hosted ELF
linker are excluded from the acceptance profile.

The Section 1.2 fixture is a static `ET_EXEC` image linked at `0x200000`. Its
assembly entry supplies a private stack, calls Zig, Zig calls C, and C calls a
fixed-signature Zig callback. C and Zig both assert the shared record layout.
The fixture is deliberately not bootable and does not settle the Phase 2
loader, image, or firmware handoff.

## Open inputs

- The physical T7500 CPU, topology, RAM, firmware, board, device, ACPI, and
  serial/debug inventory has not been collected. Phase 3 owns that independent
  qualification input; virtual work must not infer it from q35 or product
  literature.
- The acceptance reviewer is unassigned.
- The accepted compiler, linker, QEMU executable, and SeaBIOS image identities
  are pinned in the machine-readable baseline. Each execution record must
  capture its resolved paths and recheck those identities.
- Bootloader, boot handoff, image format, console/time ABI, and fault policy
  belong to M0 Phase 2 and remain open.

## Physical qualification boundary

The eventual physical check must use explicitly approved removable or
read-only boot media and a separately identified serial/debug path. It must not
write disks, change persistent firmware settings, or update firmware without a
new authorization. Until the installed topology is observed, the bootloader
and kernel must leave every additional processor unstarted or place it in a
documented safe parked state. The one-vCPU QEMU profile neither reproduces the
T7500 motherboard nor qualifies physical timing, interrupts, devices, or NUMA.
