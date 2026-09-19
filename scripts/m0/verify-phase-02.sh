#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
evidence_dir=${1:-}
archive=${2:-}
signature=${3:-}
zig_executable=${ZIG:-$(command -v zig || true)}
xorriso_executable=${XORRISO:-$(command -v xorriso || true)}
qemu_executable=${QEMU:-$(command -v qemu-system-x86_64 || true)}
readonly manifest="$repo_root/config/m0/phase-02-cases.json"
readonly key="$repo_root/config/m0/limine-release-signing-key.asc"
readonly boot_image_seconds=240
readonly phase_01_seconds=300

fail() {
    printf 'phase 2 integration failed: %s\n' "$*" >&2
    exit 1
}

[[ -n "$evidence_dir" && "$evidence_dir" == /* ]] ||
    fail "usage: $0 ABSOLUTE_EMPTY_EVIDENCE_DIR LIMINE_ARCHIVE LIMINE_SIGNATURE"
[[ -f "$archive" ]] || fail "Limine archive is required"
[[ -f "$signature" ]] || fail "Limine signature is required"
[[ -n "$zig_executable" && -x "$zig_executable" ]] || fail "zig is required"
[[ -n "$xorriso_executable" && -x "$xorriso_executable" ]] || fail "xorriso is required"
[[ -n "$qemu_executable" && -x "$qemu_executable" ]] || fail "qemu-system-x86_64 is required"
if [[ -e "$evidence_dir" ]] && [[ -n "$(find "$evidence_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    fail "evidence directory must be absent or empty"
fi
for command_name in timeout sha256sum cmp grep git date head python3 gpg tar make cc readelf readlink; do
    command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done
python3 "$repo_root/scripts/m0/check-phase-02-policy.py" --repo "$repo_root"

mkdir -p "$evidence_dir"
cp -- "$manifest" "$evidence_dir/phase-02-cases.json"
cp -- "$repo_root/config/m0/phase-02-contracts.json" "$evidence_dir/phase-02-contracts.json"
git -C "$repo_root" status --porcelain=v1 > "$evidence_dir/git-status.txt"
printf 'case_id\tresult\tobservation\n' > "$evidence_dir/case-results.tsv"

record_pass() {
    printf '%s\tpass\t%s\n' "$1" "$2" >> "$evidence_dir/case-results.tsv"
}

if ! "$repo_root/scripts/m0/verify-limine-release.sh" \
    "$archive" "$signature" "$key" "$evidence_dir/limine" \
    > "$evidence_dir/limine.log" 2>&1; then
    fail "authenticated Limine release did not verify"
fi
record_pass m0-p02-t05-authenticated-limine-release "pinned hashes, fingerprint and detached signature passed"

head -c 32 "$signature" > "$evidence_dir/invalid-signature.bin"
if "$repo_root/scripts/m0/verify-limine-release.sh" \
    "$archive" "$evidence_dir/invalid-signature.bin" "$key" "$evidence_dir/invalid-limine" \
    > "$evidence_dir/invalid-signature.log" 2>&1; then
    fail "truncated Limine signature unexpectedly passed"
fi
record_pass m0-p02-n12-invalid-limine-signature "truncated detached signature was rejected"

if ! "$repo_root/scripts/m0/verify-phase-02-contracts.sh" "$evidence_dir/contracts" \
    > "$evidence_dir/contracts-driver.log" 2>&1; then
    fail "contract and higher-half image verification did not pass"
fi
while IFS= read -r case_id; do
    grep -Fq "contracts.test.$case_id...OK" "$evidence_dir/contracts/contracts.log" || fail "$case_id observation is missing"
    record_pass "$case_id" "Zig contract case passed"
done < <(python3 "$repo_root/scripts/m0/check-phase-02-policy.py" --repo "$repo_root" --list-runner zig)
record_pass m0-p02-t04-reproducible-higher-half-image "two absolute-directory ELF builds were byte-identical"
grep -Fq 'image-contract=pass' "$evidence_dir/contracts/image-contract.log" || fail "emitted ELF contract result is missing"
record_pass m0-p02-t08-emitted-elf-contract "emitted ELF passed the boot snapshot and image contract"

if timeout 10 env XORRISO=/kay-os/missing/xorriso \
    "$repo_root/scripts/m0/build-boot-image.sh" \
    "$evidence_dir/missing-tool-image" "$evidence_dir/limine/limine-binary" \
    > "$evidence_dir/missing-iso-tool.log" 2>&1; then
    fail "missing ISO tool unexpectedly passed"
fi
grep -Fq 'xorriso is required' "$evidence_dir/missing-iso-tool.log" || fail "missing ISO tool returned wrong diagnostic"
record_pass m0-p02-n13-missing-iso-tool "missing xorriso was rejected before image construction"

for image_name in image-a image-b; do
    if ! timeout "$boot_image_seconds" env ZIG="$zig_executable" XORRISO="$xorriso_executable" \
        "$repo_root/scripts/m0/build-boot-image.sh" \
        "$evidence_dir/$image_name" "$evidence_dir/limine/limine-binary" \
        > "$evidence_dir/$image_name.log" 2>&1; then
        fail "$image_name did not build"
    fi
done
cmp --silent "$evidence_dir/image-a/kay-m0.iso" "$evidence_dir/image-b/kay-m0.iso" ||
    fail "boot ISO is not reproducible"
cmp --silent "$evidence_dir/image-a/iso-root/boot/kay-m0-kernel.elf" \
    "$evidence_dir/image-b/iso-root/boot/kay-m0-kernel.elf" || fail "ISO kernels differ"
record_pass m0-p02-t06-deterministic-read-only-iso "two signed-input ISO builds were byte-identical"

if ! timeout "$phase_01_seconds" env ZIG="$zig_executable" QEMU="$qemu_executable" \
    "$repo_root/scripts/m0/verify-phase-01.sh" "$evidence_dir/phase-01-regression" \
    > "$evidence_dir/phase-01-regression.log" 2>&1; then
    fail "Phase 1 regression did not pass"
fi
record_pass m0-p02-t07-phase-01-regression "all Phase 1 baseline and failure-detection cases passed"

python3 "$repo_root/scripts/m0/check-phase-02-policy.py" \
    --repo "$repo_root" --results "$evidence_dir/case-results.tsv"

tool_file="$evidence_dir/tool-identities.tsv"
printf 'tool\tinvocation_path\tinvocation_sha256\tresolved_path\tresolved_sha256\tversion\n' > "$tool_file"
record_tool() {
    local label=$1
    local path=$2
    local version=$3
    local resolved
    resolved=$(readlink -f "$path")
    if [[ "$path" == */.asdf/shims/* ]] && command -v asdf >/dev/null 2>&1; then
        resolved=$(asdf which "$label" 2>/dev/null || printf '%s' "$resolved")
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$label" "$path" "$(sha256sum "$path" | awk '{print $1}')" \
        "$resolved" "$(sha256sum "$resolved" | awk '{print $1}')" "$version" >> "$tool_file"
}
record_tool zig "$zig_executable" "$($zig_executable version)"
record_tool qemu "$qemu_executable" "$($qemu_executable --version | head -1)"
record_tool xorriso "$xorriso_executable" "$($xorriso_executable -version 2>&1 | head -1)"
for tool_name in gpg tar make cc readelf python3; do
    tool_path=$(command -v "$tool_name")
    case "$tool_name" in
        gpg) tool_version=$($tool_path --version | head -1) ;;
        tar) tool_version=$($tool_path --version | head -1) ;;
        make) tool_version=$($tool_path --version | head -1) ;;
        cc) tool_version=$($tool_path --version | head -1) ;;
        readelf) tool_version=$($tool_path --version | head -1) ;;
        python3) tool_version=$($tool_path --version) ;;
    esac
    record_tool "$tool_name" "$tool_path" "$tool_version"
done
limine_tool="$evidence_dir/limine/limine-binary/limine"
record_tool limine "$limine_tool" "$($limine_tool --version | head -1)"

sha256sum \
    "$evidence_dir/image-a/kay-m0.iso" \
    "$evidence_dir/image-a/iso-root/boot/kay-m0-kernel.elf" \
    "$archive" "$signature" "$manifest" \
    > "$evidence_dir/artifacts.sha256"
find "$evidence_dir" -type f ! -name evidence.sha256 -print0 | sort -z | xargs -0 sha256sum > "$evidence_dir/evidence.sha256"
{
    printf 'task_id=m0-p02-integration\n'
    printf 'result=pass\n'
    printf 'tested_revision=%s\n' "$(git -C "$repo_root" rev-parse HEAD)"
    printf 'dirty_file_count=%s\n' "$(wc -l < "$evidence_dir/git-status.txt")"
    printf 'case_count=%s\n' "$(($(wc -l < "$evidence_dir/case-results.tsv") - 1))"
    printf 'iso_sha256=%s\n' "$(sha256sum "$evidence_dir/image-a/kay-m0.iso" | awk '{print $1}')"
    printf 'guest_boot=not-tested\n'
    printf 'ring3_enforcement=not-tested\n'
    printf 'physical_t7500=not-tested\n'
    printf 'completed_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$evidence_dir/result.txt"

printf 'M0 Phase 2 integration passed; evidence: %s\n' "$evidence_dir"
