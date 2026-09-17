# M0 Phase 1 build closure

This document describes the executable qualification for task
`m0-p01-build`. The fixture proves that the selected Zig 0.16.0 LLVM/LLD path
can produce a controlled freestanding Intel x86-64 ELF with a narrow native
boundary. It does not boot, enter a processor mode, initialize hardware, or
provide kernel functionality.

## Selected artifact

`build.zig` emits two forms from the same sources and flags:

- `kay-m0-fixture` is the stripped acceptance ELF. It is a static ELF64
  `ET_EXEC`, has entry address `0x200000`, and has no dynamic loader, libc,
  compiler-runtime, unresolved-symbol, PIC, or PIE dependency.
- `kay-m0-fixture-audit` retains DWARF and symbols solely for the symbol,
  layout, dependency, and disassembly census. Absolute source paths in this
  audit-only DWARF are the sole permitted path-dependent bytes.

The accepted target is `x86_64-freestanding-none` with the explicit Nehalem
CPU model, LLVM code generation, LLD, `ReleaseSmall`, the red zone disabled,
frame pointers retained, stack checks and protectors disabled, compiler-rt and
UBSan runtimes disabled, and a 16 KiB fixture-owned stack. The linker script
fixes the synthetic image base at 2 MiB. This address is a qualification input,
not the future kernel's accepted load contract.

## Native ABI boundary

The fixture exercises all three initial directions:

1. `_start` is an assembly entry that installs the fixture stack and calls the
   fixed-signature Zig function `kay_fixture_main`.
2. Zig consumes `abi.h` through `@cImport`, verifies record size, alignment,
   and field offsets at compile time, then calls `kay_c_accumulate`.
3. C performs the same C11 static layout assertions and calls the exported
   Zig callback `kay_zig_callback`.

All cross-language arguments and results are pointers, `size_t`, or fixed-width
integers under the x86-64 System V C calling convention. Variadic functions,
unwinding, allocation, C library state, floating-point arguments, and SIMD
arguments are outside the contract. `kay_panic` is the current fixed-signature
terminal panic boundary; it disables interrupts and halts forever. It neither
formats output nor unwinds and will be replaced only through an explicit later
contract.

## Machine checks

Run:

```sh
ZIG=/absolute/path/to/zig \
  scripts/m0/verify-build-closure.sh /absolute/evidence/directory
```

The verifier copies the source twice into different clean absolute paths and
uses independent Zig caches. The stripped ELFs must be byte-identical, while
the audit ELFs must produce identical symbol and ELF maps. It rejects dynamic
loader state, undefined symbols, a wrong ELF class/type/machine/entry, missing
boundary symbols, and x87/MMX/SSE/AVX-family register use in the disassembly.

Three deliberate changes must fail:

- 128-bit division with compiler-rt disabled leaves `__udivti3` undefined;
- a host-style `write` import remains undefined because libc and host syscalls
  are unavailable; and
- a `-Dcpu=haswell` override is rejected because the build exposes no CPU
  override option.

The test result is meaningful only with the pinned Zig identity from
`config/m0/development-baseline.json`. QEMU is not involved in this fixture.

## Reproducibility result

The 2026-09-17 qualification produced identical stripped artifacts from two
clean absolute paths. The artifact SHA-256 was
`e94b127fcc4388e73b4620a8b0908dcdeed0c3a08fbf0052d92cce58a3baf31a`.
The separate audit ELF hashes differed, as expected, because their DWARF
contained the two source paths; their symbol and ELF maps compared equal.

The execution record is in `evidence/m0-p01-build-2026-09-17.md`. Physical
T7500 inventory, phase integration, boot-image construction, QEMU boot, and an
acceptance review remain open.
