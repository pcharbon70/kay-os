#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
evidence_dir=${1:-}
zig_executable=${ZIG:-$(command -v zig || true)}
qemu_executable=${QEMU:-$(command -v qemu-system-x86_64 || true)}
readonly bios_path="/usr/share/seabios/bios.bin"
readonly case_manifest="$repo_root/config/m0/phase-01-cases.json"
readonly baseline_seconds=30
readonly build_closure_seconds=180
readonly qemu_rejection_seconds=10
readonly watchdog_probe_seconds=1

fail() {
    printf 'phase 1 verification failed: %s\n' "$*" >&2
    exit 1
}

if [[ -z "$evidence_dir" || "$evidence_dir" != /* ]]; then
    fail "usage: $0 ABSOLUTE_EMPTY_EVIDENCE_DIRECTORY"
fi
if [[ -e "$evidence_dir" ]] && [[ -n "$(find "$evidence_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    fail "evidence directory must be absent or empty: $evidence_dir"
fi
[[ -n "$zig_executable" ]] || fail "zig is required"
[[ -n "$qemu_executable" ]] || fail "qemu-system-x86_64 is required"

for command_name in timeout sha256sum grep git date; do
    command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done

mkdir -p "$evidence_dir/build-closure"
cp -- "$case_manifest" "$evidence_dir/phase-01-cases.json"

for limit in \
    "baseline_seconds $baseline_seconds" \
    "build_closure_seconds $build_closure_seconds" \
    "qemu_rejection_seconds $qemu_rejection_seconds" \
    "watchdog_probe_seconds $watchdog_probe_seconds"; do
    read -r limit_name limit_value <<<"$limit"
    grep -Fq "\"$limit_name\": $limit_value" "$case_manifest" ||
        fail "case manifest does not bind $limit_name=$limit_value"
done

manifest_sha256=$(sha256sum "$case_manifest" | awk '{print $1}')
tested_revision=$(git -C "$repo_root" rev-parse HEAD)
git -C "$repo_root" status --porcelain=v1 > "$evidence_dir/git-status.txt"

printf 'case_id\tresult\tobservation\n' > "$evidence_dir/case-results.tsv"
record_pass() {
    grep -Fq "\"id\": \"$1\"" "$case_manifest" ||
        fail "unregistered case result: $1"
    printf '%s\tpass\t%s\n' "$1" "$2" >> "$evidence_dir/case-results.tsv"
}

if ! timeout "$baseline_seconds" env KAY_ZIG="$zig_executable" KAY_QEMU="$qemu_executable" \
    "$repo_root/scripts/m0/verify-development-baseline.sh" \
    > "$evidence_dir/baseline.log" 2>&1; then
    fail "m0-p01-t01-baseline did not pass"
fi
record_pass m0-p01-t01-baseline "pinned development inputs resolved"

if ! timeout "$build_closure_seconds" env ZIG="$zig_executable" \
    "$repo_root/scripts/m0/verify-build-closure.sh" "$evidence_dir/build-closure" \
    > "$evidence_dir/build-closure.log" 2>&1; then
    fail "m0-p01-t02-clean-builds did not pass"
fi
record_pass m0-p01-t02-clean-builds "clean builds, maps and build negative cases passed"
record_pass m0-p01-n05-build-closure "helper, host import and CPU option drift were rejected"

if timeout "$baseline_seconds" env KAY_ZIG="$zig_executable" KAY_QEMU=/kay-os/missing/qemu \
    "$repo_root/scripts/m0/verify-development-baseline.sh" \
    > "$evidence_dir/negative-missing-qemu.log" 2>&1; then
    fail "m0-p01-n01-missing-qemu unexpectedly passed"
fi
grep -Fq 'missing command: /kay-os/missing/qemu' "$evidence_dir/negative-missing-qemu.log" ||
    fail "m0-p01-n01-missing-qemu returned the wrong diagnostic"
record_pass m0-p01-n01-missing-qemu "missing pinned QEMU was rejected"

if timeout "$baseline_seconds" env KAY_ZIG="$zig_executable" KAY_QEMU="$qemu_executable" \
    KAY_BIOS=/kay-os/missing/bios.bin \
    "$repo_root/scripts/m0/verify-development-baseline.sh" \
    > "$evidence_dir/negative-missing-firmware.log" 2>&1; then
    fail "m0-p01-n02-missing-firmware unexpectedly passed"
fi
grep -Fq 'SeaBIOS path /kay-os/missing/bios.bin does not match' \
    "$evidence_dir/negative-missing-firmware.log" ||
    fail "m0-p01-n02-missing-firmware returned the wrong diagnostic"
record_pass m0-p01-n02-missing-firmware "changed firmware path was rejected"

if timeout "$qemu_rejection_seconds" "$qemu_executable" \
    -machine kay-os-missing-machine,accel=tcg -cpu Nehalem-v1 -m 64M \
    -nodefaults -display none -S -bios "$bios_path" \
    > "$evidence_dir/negative-unavailable-machine.log" 2>&1; then
    fail "m0-p01-n03-unavailable-machine unexpectedly passed"
fi
grep -Eqi 'unsupported machine type|unknown.*machine|invalid.*machine' \
    "$evidence_dir/negative-unavailable-machine.log" ||
    fail "m0-p01-n03-unavailable-machine returned the wrong diagnostic"
record_pass m0-p01-n03-unavailable-machine "unavailable machine was rejected"

if timeout "$qemu_rejection_seconds" "$qemu_executable" \
    -machine pc-q35-8.2,accel=tcg -cpu kay-os-missing-cpu -m 64M \
    -nodefaults -display none -S -bios "$bios_path" \
    > "$evidence_dir/negative-unavailable-cpu.log" 2>&1; then
    fail "m0-p01-n04-unavailable-cpu unexpectedly passed"
fi
grep -Eqi 'unable to find CPU model|unknown.*cpu|invalid.*cpu' \
    "$evidence_dir/negative-unavailable-cpu.log" ||
    fail "m0-p01-n04-unavailable-cpu returned the wrong diagnostic"
record_pass m0-p01-n04-unavailable-cpu "unavailable CPU was rejected"

set +e
timeout "$watchdog_probe_seconds" bash -c 'sleep 5' > "$evidence_dir/negative-watchdog.log" 2>&1
watchdog_status=$?
set -e
[[ "$watchdog_status" -eq 124 ]] || fail "m0-p01-n06-watchdog returned $watchdog_status, expected 124"
printf 'timeout_status=%s\n' "$watchdog_status" > "$evidence_dir/negative-watchdog.log"
record_pass m0-p01-n06-watchdog "deadline returned status 124"

grep -Fq '"inventory_status": "deferred-by-user"' \
    "$repo_root/config/m0/development-baseline.json" ||
    fail "physical inventory status is not explicitly deferred"
grep -Fq '"inventory_evidence": null' \
    "$repo_root/config/m0/development-baseline.json" ||
    fail "physical inventory evidence must remain absent"
grep -Fq '"required": false' "$case_manifest" ||
    fail "case manifest unexpectedly requires physical inventory"
record_pass m0-p01-b01-physical-boundary "physical inventory deferred to m0-p03-inventory and not consumed"

find "$evidence_dir" -type f ! -name evidence.sha256 -print0 \
    | sort -z \
    | xargs -0 sha256sum > "$evidence_dir/evidence.sha256"

{
    printf 'task_id=m0-p01-integration\n'
    printf 'result=pass\n'
    printf 'scope=virtual-input-and-build-integration\n'
    printf 'tested_revision=%s\n' "$tested_revision"
    printf 'dirty_file_count=%s\n' "$(wc -l < "$evidence_dir/git-status.txt")"
    printf 'case_manifest_sha256=%s\n' "$manifest_sha256"
    printf 'artifact_sha256='
    sha256sum "$evidence_dir/build-closure/kay-m0-fixture.elf" | awk '{print $1}'
    printf 'physical_inventory=deferred-to-m0-p03-inventory-not-consumed\n'
    printf 'completed_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$evidence_dir/result.txt"

echo "m0-p01-integration verification passed; evidence: $evidence_dir"
