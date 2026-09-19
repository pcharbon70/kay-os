# M0 Phase 2 contract-integration execution record

## Scope

- Tasks: `m0-p02-fixtures`, `m0-p02-integration`, evidence portion of
  `m0-p02-handoff`
- Date: 2026-09-18
- Repository branch: `codex/m0-phase-02-contracts`
- Tested revision: `f85571e2f2bb036c258fd596552731422cb41b38`
- Tested state: clean worktree (`dirty_file_count=0`)
- Record revision: a later Section 2.2 documentation commit; it does not imply
  that the record commit or a future merge revision was the tested revision
- Environment: Linux x86-64 host; no QEMU guest and no physical T7500

## Inputs and invocation

- Driver: `scripts/m0/verify-phase-02.sh`
- Case manifest: 24 exact cases, SHA-256
  `4a373671781ae7297b511df7d82836f3b46000a542b6a8e3a882b85a26627194`
- Zig: 0.16.0; resolved binary SHA-256
  `2317bbb91798556d9d0f38aabdac23db83f0979b25f767259ae474546724087c`
- Limine: v12.9.0; archive SHA-256
  `9a738586bff5790bd8bfef4a4868a2939cba3f81f22f121306d668c97f1c85d8`;
  detached-signature SHA-256
  `c2ece24344e8b59350d8e7d9b70ce46b71f2c0cda3668096c14ff83f1f773e3d`;
  signing-key fingerprint `05D29860D0A0668AAEFB9D691F3C021BECA23821`
- `xorriso`: 1.5.6, resolved binary SHA-256
  `c66a5be11a674e97ed8983af520eae8fad900b47d104c92bc63e5cf254391922`;
  invoked from a temporary extraction of Ubuntu packages because this session
  could not provide the `sudo` password required for system installation
- Completed evidence directory: `/tmp/kay-p02-final-clean.iOr4jf`

```sh
LD_LIBRARY_PATH=/tmp/kay-xorriso-root/usr/lib/x86_64-linux-gnu \
XORRISO=/tmp/kay-xorriso-root/usr/bin/xorriso \
  bash scripts/m0/verify-phase-02.sh \
  /tmp/kay-p02-final-clean.iOr4jf \
  /tmp/limine-binary-12.9.0.tar.xz \
  /tmp/limine-binary-12.9.0.tar.xz.sig
```

## Actual results

The driver returned zero at `2026-09-18T18:28:44Z`. It reconciled an exact
24-row passing result set with the case manifest.

- Overall result: pass
- Higher-half kernel ELF SHA-256:
  `e3b317cabe4fd16e573fc86477ae06a96e1cec9ed33178b1519c71185f06244e`
- Deterministic BIOS ISO SHA-256:
  `3ffad1d85539911981121c65b8a4bdcfb7cd1d09fc14aa01fbb075debe74bc1f`
- ELF audit: two load segments, entry `0xffffffff80000000`, physical range
  `0x200000..0x206000`, Limine base revision 6
- Supply chain: exact Limine archive hashes and signing fingerprint matched;
  detached signature valid; deliberately truncated signature rejected
- Reproducibility: two independent absolute-directory kernel builds and two
  read-only ISO builds were byte-identical
- Policy consistency: compiled Zig operation and result-code tables matched
  the JSON contract; independently hard-coded Zig expectations passed
- Negative cases: truncation, overlap, arithmetic overflow, invalid entry,
  write-execute mapping, reservation conflict, oversized console transfer,
  absent grant, wrong endpoint/caller, past deadline, conversion overflow,
  invalid Limine signature and missing ISO tool were rejected
- Regression: the complete Phase 1 baseline and failure-detection suite passed
  on the same clean revision

## Independent review

The first independent review found seven implementation/evidence gaps:
boot-map reconciliation, physical-segment overlap, fail-closed manifest
reconciliation, authority-table completeness, emitted-ELF audit breadth, tool
identity capture and Code Companion accuracy. Those findings were corrected
before the clean run.

The follow-up review of exact commit
`f85571e2f2bb036c258fd596552731422cb41b38` found no remaining implementation
blocker. It specifically confirmed that:

- the compiled Zig operation/result table is exported and structurally
  compared with the JSON policy while tests independently assert every field;
- the Code Companion accurately describes the two emitted load segments; and
- the ELF parser rejects a segment whose file range exceeds the ELF bytes.

The guide's formerly stale “clean rerun pending” banner was corrected in this
later Section 2.2 documentation change.

## Boundaries and handoff

This result is hosted contract, supply-chain, build and image-construction
evidence. It did not boot the ISO in QEMU, execute ring 3, enforce the contracts
inside a running kernel, or test the physical Dell Precision T7500. The driver
records all three as `not-tested`.

Section 2.1 and `m0-p02-integration` are complete for their declared pre-boot
scope. On 2026-09-19, the user/project owner selected **proceed** and accepted
`m0-p02-handoff`. The research plan records the authoritative phase state.
Changes to pinned supply-chain inputs, the boot/image/interface contracts,
bounds, linker layout, operation table, case manifest or verification scripts
reopen the relevant result.
