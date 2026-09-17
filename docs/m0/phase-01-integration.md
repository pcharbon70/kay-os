# M0 Phase 1 virtual integration

The Phase 1 integration driver assembles the selected development baseline and
freestanding build closure into one finite, versioned virtual-input gate. It
implements `m0-p01-integration` and only the preliminary virtual portions of
M0-T01 and M0-T02. It does not boot the ELF or qualify the Dell Precision
T7500.

## Case envelope

`config/m0/phase-01-cases.json` binds every case, deadline and scope boundary.
The driver refuses to report an unregistered case, verifies that its four
deadlines equal the manifest, and records the manifest hash in every result.
There is no random workload, so the manifest records a null seed.

The positive path:

- resolves the exact Zig, LLD, QEMU, Q35, Nehalem-v1 and SeaBIOS identities;
- reruns the two clean absolute-path builds with independent caches;
- compares the stripped ELF, symbol map and ELF map; and
- repeats the ABI, dependency and FP/SIMD disassembly census.

The negative path requires explicit failure for:

- a missing pinned QEMU executable;
- a changed or missing SeaBIOS path;
- unavailable QEMU machine and CPU requests;
- the undefined compiler helper, host import and CPU-option drift cases from
  the build-closure driver; and
- a controlled command that exceeds the one-second watchdog deadline.

Unexpected success, an unmatched diagnostic, a deadline violation, a missing
case registration or a changed manifest limit makes the driver return nonzero.

## Physical boundary

The case manifest records that physical inventory is not required by this
virtual gate. The driver confirms the inventory is explicitly deferred and
has no evidence value, then records `deferred-to-m0-p03-inventory-not-consumed`.
It never invokes the inventory collector. Q35, Nehalem-v1 and SeaBIOS results
therefore remain virtual evidence and make no statement about T7500 wiring,
firmware behavior, timing, devices or topology.

## Running the gate

Use an absent or empty absolute evidence directory:

```sh
ZIG=/absolute/path/to/zig \
QEMU=/absolute/path/to/qemu-system-x86_64 \
  scripts/m0/verify-phase-01.sh /absolute/evidence/directory
```

The directory receives the manifest, Git revision and dirty state, per-case
TSV, positive and negative logs, nested build-closure evidence, a final result
record and hashes for every retained evidence file. Generated artifacts and
logs remain outside version control; the research execution journal records
the accepted run, exact revision, observations, hashes and limitations.

Passing this driver permits the Phase 1 virtual handoff for acceptance review.
It does not close final M0, whose Phase 2 contracts, Phase 3 harness and
`m0-p03-inventory` obligations remain outstanding.
