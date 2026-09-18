# Repository instructions

These instructions apply to the entire Kay OS implementation repository.

## Project boundary

Kay OS is a new Intel x86-64 operating system informed by Erlang/OTP and BEAM
principles. The research and phased plans live in the separate
`atom-os-research` repository. This repository owns executable source, build
inputs, fixtures, tests, and implementation evidence.

The proof of concept is CLI-first. AtomVM, a graphical interface, writable
storage, networking, SMP, NUMA, and DMA devices are outside the initial boot
profile. The first virtual fixture uses one `Nehalem-v1` CPU, 64 MiB of RAM,
TCG, an explicitly versioned Q35 machine, SeaBIOS, serial I/O, and read-only
boot media.

## Language and toolchain

- Use Zig 0.16.0 as the pinned kernel toolchain.
- Use the LLVM code-generation backend and LLD path for the acceptance build.
- Treat the target as freestanding; do not introduce host syscalls or an
  implicit libc dependency.
- Keep C and assembly interfaces narrow, explicitly declared, and covered by
  size, alignment, calling-convention, symbol, and disassembly checks.
- Keep the x86-64 red zone disabled and do not assume FP/SIMD state is enabled.
- Experimental incremental compilation and the experimental self-hosted ELF
  linker are not part of the accepted M0 baseline.

## Change and evidence discipline

- Preserve task IDs from the research plan in commits, evidence, and tests.
- Pin external tools and record their versions and hashes.
- Make clean builds independent of the checkout's absolute path.
- Keep generated objects, caches, and test output outside version control.
- Do not mark a task or gate complete without retained command output.
- Keep virtual, hosted, and physical evidence distinct. QEMU does not qualify
  the Dell Precision T7500 motherboard.
- Do not write to physical firmware or storage without explicit authorization.

## Code Companion documentation

The `docs/code-guide/` tree is the Kay OS Code Companion. It is part of the
implementation contract, not optional after-the-fact prose. Author its source
in Markdown and generate the review site as HTML/CSS with Material for MkDocs;
do not hand-author generated HTML or commit the `site/` directory.

For every meaningful implementation change:

- update the code map and the affected module guide in the same change;
- map every new file under `src/` in `docs/code-guide/coverage.tsv`;
- map significant build, linker, test, configuration, or verification code
  when it defines behavior readers must understand;
- keep the guide's important-file list, execution flow, data structures,
  ownership, privilege boundary, failure behavior, tests, limitations,
  language concepts, and revision statement accurate;
- explain why and invariants in source comments; keep broad teaching and
  syntax explanations in the Code Companion;
- use Mermaid for flows with several components or state transitions, and use
  fenced, titled code blocks or checked snippets for source excerpts;
- state explicitly what evidence demonstrates and what it does not; and
- update `docs/code-guide/glossary.md` when a change introduces terminology a
  reader without C, Zig, assembly, or kernel experience may not know.

Start new module guides from `docs/code-guide/module-guide-template.md` and
retain every required second-level heading. Pull requests use
`.github/pull_request_template.md`, including its reader's guide and Code
Companion checklist. Run `scripts/docs/verify-code-guide.sh` before handoff;
the verifier checks required sections, source coverage, referenced paths,
navigation, and a strict MkDocs build.

## Verification

Run the narrowest relevant checks during development. Before handing off a
section, run its complete test driver plus `git diff --check`, and record the
tested revision, dirty state, tool versions, commands, results, and hashes.
Changes to source or Code Companion material must also pass
`scripts/docs/verify-code-guide.sh`.
