---
title: Glossary
description: C, Zig, assembly, build, and operating-system terms used by Kay OS
---

# Glossary

This glossary defines terms in the way Kay OS uses them. It favors a useful
first explanation over a complete language or processor reference.

## How to use this glossary

Follow terms from a module guide when needed. Definitions distinguish a general
concept from the narrower profile currently accepted by Kay OS.

## Language and ABI terms

**ABI (Application Binary Interface)**
: The binary-level agreement that independently compiled code follows: data
  layout, alignment, symbol names, argument and result placement, register use,
  stack rules, and calling convention. An ABI is lower-level than a source API.

**Alignment**
: A requirement that an object begin at an address divisible by a particular
  power of two. The current `kay_packet` requires eight-byte alignment.

**Calling convention**
: Rules for how a function call crosses compiled code: where arguments and
  results go, which registers a callee must preserve, and how the stack is
  maintained. Kay OS's initial Zig/C probe uses the x86-64 C convention.

**C pointer**
: A machine address interpreted as referring to an object of a declared type.
  A pointer does not itself prove that the address is non-null, correctly
  aligned, alive, large enough, or authorized.

**`const` pointer target**
: A declaration that code will not mutate an object through that pointer. It
  is not a lifetime, ownership, or concurrency guarantee.

**Fixed-width integer**
: An integer type with an exact bit count, such as C's `uint64_t` or Zig's
  `u64`. It controls field width but does not by itself define serialization
  byte order.

**`comptime`**
: Zig evaluation performed by the compiler. Kay OS uses it to reject ABI
  layout drift before producing a binary.

**Freestanding**
: A compilation environment that does not assume a normal host operating
  system or full standard library. Kay OS must supply or deliberately reject
  every runtime facility its generated code requires.

**Undefined behavior**
: A C program operation for which the language imposes no requirements, such
  as reading beyond the end of an array. Kernel interfaces must validate
  untrusted inputs before C code can make assumptions that would otherwise
  permit undefined behavior.

## Binary and linker terms

**ELF (Executable and Linkable Format)**
: The binary container used by the current x86-64 fixture. ELF describes an
  entry address, sections, loadable segments, symbols, and other metadata.

**Entry point**
: The address where control begins when an image is started. The qualification
  fixture declares `_start` at virtual address `0x200000`, but M0 Phase 1 does
  not provide a loader that actually transfers control there.

**Linker**
: The tool that combines compiled objects, resolves symbol references, applies
  layout rules, and emits the final binary. Kay OS uses LLD for the accepted
  M0 profile.

**Linker script**
: A file directing the linker's memory layout. The M0 script places code,
  read-only data, writable data, zero-filled storage, and the qualification
  stack at explicit boundaries.

**Section**
: A named grouping of code or data in an object or executable, such as
  `.text`, `.rodata`, `.data`, or `.bss`.

**Symbol**
: A linker-visible name associated with code or data, such as `_start` or
  `kay_c_accumulate`. A declaration may reference a symbol implemented in a
  different language.

**BSS**
: Storage that must contain zeros when execution begins but does not need its
  zero bytes stored in the executable. A future loader must establish this
  condition; the Phase 1 fixture only describes it.

## Processor and kernel terms

**Red zone**
: In the conventional x86-64 user-space ABI, a small area below the stack
  pointer that leaf functions may use without moving the pointer. Interrupts
  can make that unsafe for kernel code, so the accepted fixture disables it.

**FP/SIMD state**
: Floating-point and vector register state, including x87, MMX, XMM, YMM, and
  ZMM facilities. Early Kay OS code forbids their use until the kernel owns
  their enablement, saving, restoration, and fault behavior.

**Privilege level**
: A processor-enforced authority level. Kernel code normally runs with more
  authority than user code. The M0 fixture has no demonstrated privilege
  transition and must not be mistaken for one.

**TCG**
: QEMU's software CPU translator. The initial virtual profile uses TCG rather
  than depending on host hardware virtualization.

## Evidence terms

**Fixture**
: A deliberately bounded artifact used to test a particular contract. The M0
  ELF is a compiler/linker/ABI fixture, not yet a bootable Kay OS kernel.

**Negative test**
: A test that passes only when an invalid or forbidden input is rejected. M0
  negative cases require unresolved compiler helpers, host syscalls, and CPU
  option drift to fail.

**Reproducible build**
: A build whose declared outputs can be reproduced from pinned inputs under
  stated conditions. The M0 acceptance ELF is stripped so absolute debug paths
  do not change its bytes.

**Evidence boundary**
: The limit of what an observation supports. Successful compilation does not
  prove execution; QEMU behavior does not prove physical motherboard behavior.
