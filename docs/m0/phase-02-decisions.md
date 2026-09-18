---
title: M0 Phase 2 decisions
description: Accepted boot, image, ABI, interface, and fault-policy choices
---

# M0 Phase 2 decisions

This record freezes the inputs needed to implement and test the M0 boot, image,
and initial-interface contracts. The machine-readable counterpart is
`config/m0/phase-02-contracts.json`.

## Accepted decisions

| Area | Selection | Reason and boundary |
| --- | --- | --- |
| Loader | Limine v12.9.0, protocol base revision 6, protocol header revision `da65184e` | Limine owns BIOS-to-long-mode transition. Kay embeds the exact discovery tags, validates and copies the bounded handoff, and does not retain unvalidated borrowed pointers. |
| Supply chain | Exact signed binary archive, SHA-256 hashes, pinned signing-key fingerprint | A changed archive, signature, or key is a hard failure. |
| Native image | Fixed higher-half static ELF64 `ET_EXEC` | Only aligned `PT_LOAD`-style segments are admitted; no relocations, interpreter, dynamic linking, or write-execute segment. |
| Native calls | Restricted System V AMD64 integer ABI | The red zone and FP/SIMD are disabled. Kay owns a 16-byte-aligned stack. |
| User entry | Dedicated DPL3 interrupt gate, TSS kernel stack, `iretq` | This is the selected M1 mechanism; M0 records but does not implement or prove it. |
| Console | Copy-based byte stream, maximum 256 bytes | Read/write grants are separate. The CLI owns line editing; the kernel does not parse commands. |
| Time | Unsigned 64-bit monotonic nanoseconds, checked conversion, absolute waits | Read and wait grants are separate. Overflow and past deadlines are errors. |
| Fatal fault | Bounded emergency serial record followed by stable halt | Diagnostics must be finite and cannot depend on the ordinary console path remaining healthy. |
| Boot media | Deterministic read-only BIOS ISO | It matches the SeaBIOS QEMU baseline and introduces no writable guest storage. |

## Authority boundary

The trusted development path contains the build host, pinned firmware, verified
Limine release, and Kay kernel. Loader input, image descriptions, and later
user-domain requests are validated at their boundary. The CLI receives only
console-read, console-write, clock-read, and clock-wait grants. No grant implies
arbitrary physical memory, firmware mutation, authentication, or root authority.

## Evidence boundary

The Phase 2 host tests validate bounded formats and build a structurally audited
higher-half image. They do not prove that the image boots, that Limine's handoff
has been normalized inside the guest, that a DPL3 transition works, or that the
Dell Precision T7500 behaves like QEMU. Those claims remain assigned to later
guest integration and physical qualification.
