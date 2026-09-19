#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
evidence_dir=${1:-}
zig_executable=${ZIG:-$(command -v zig || true)}
readonly manifest="$repo_root/config/m0/phase-02-cases.json"
readonly contract_seconds=60
readonly build_seconds=180

fail() {
    printf 'phase 2 contract verification failed: %s\n' "$*" >&2
    exit 1
}

[[ -n "$evidence_dir" && "$evidence_dir" == /* ]] || fail "usage: $0 ABSOLUTE_EMPTY_EVIDENCE_DIRECTORY"
if [[ -e "$evidence_dir" ]] && [[ -n "$(find "$evidence_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    fail "evidence directory must be absent or empty"
fi
[[ -n "$zig_executable" ]] || fail "zig is required"
for command_name in timeout readelf sha256sum cmp grep awk git python3; do
    command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done
python3 "$repo_root/scripts/m0/check-phase-02-policy.py" --repo "$repo_root"

mkdir -p "$evidence_dir/test-cache/local" "$evidence_dir/test-cache/global"
cp -- "$manifest" "$evidence_dir/phase-02-cases.json"
git -C "$repo_root" status --porcelain=v1 > "$evidence_dir/git-status.txt"

if ! timeout "$contract_seconds" env \
    ZIG_LOCAL_CACHE_DIR="$evidence_dir/test-cache/local" \
    ZIG_GLOBAL_CACHE_DIR="$evidence_dir/test-cache/global" \
    "$zig_executable" test "$repo_root/src/m0/contracts.zig" \
    > "$evidence_dir/contracts.log" 2>&1; then
    fail "contract tests did not pass"
fi

if ! timeout "$contract_seconds" env \
    ZIG_LOCAL_CACHE_DIR="$evidence_dir/policy-cache/local" \
    ZIG_GLOBAL_CACHE_DIR="$evidence_dir/policy-cache/global" \
    "$zig_executable" run "$repo_root/src/m0/policy_dump.zig" \
    > "$evidence_dir/zig-policy.tsv" 2>&1; then
    fail "Zig authority policy export did not run"
fi
python3 "$repo_root/scripts/m0/check-phase-02-policy.py" \
    --repo "$repo_root" --zig-policy "$evidence_dir/zig-policy.tsv"

for build_name in build-a build-b; do
    mkdir -p "$evidence_dir/$build_name/local" "$evidence_dir/$build_name/global" "$evidence_dir/$build_name/prefix"
    if ! timeout "$build_seconds" env \
        ZIG_LOCAL_CACHE_DIR="$evidence_dir/$build_name/local" \
        ZIG_GLOBAL_CACHE_DIR="$evidence_dir/$build_name/global" \
        "$zig_executable" build --build-file "$repo_root/build.zig" \
        boot-kernel --prefix "$evidence_dir/$build_name/prefix" --summary all \
        > "$evidence_dir/$build_name.log" 2>&1; then
        fail "$build_name did not complete"
    fi
done

kernel_a="$evidence_dir/build-a/prefix/bin/kay-m0-kernel"
kernel_b="$evidence_dir/build-b/prefix/bin/kay-m0-kernel"
cmp --silent "$kernel_a" "$kernel_b" || fail "higher-half kernel is not reproducible"
readelf -hW -lW -dW -rW "$kernel_a" > "$evidence_dir/kernel-elf.txt"

mkdir -p "$evidence_dir/image-audit/local" "$evidence_dir/image-audit/global"
if ! timeout "$contract_seconds" env \
    ZIG_LOCAL_CACHE_DIR="$evidence_dir/image-audit/local" \
    ZIG_GLOBAL_CACHE_DIR="$evidence_dir/image-audit/global" \
    "$zig_executable" run "$repo_root/src/m0/image_audit.zig" -- "$kernel_a" \
    > "$evidence_dir/image-contract.log" 2>&1; then
    fail "emitted ELF did not pass the Zig image contract"
fi

grep -Fq 'Type:                              EXEC (Executable file)' "$evidence_dir/kernel-elf.txt" || fail "kernel is not ET_EXEC"
grep -Fq 'Entry point address:               0xffffffff80000000' "$evidence_dir/kernel-elf.txt" || fail "entry address drift"
grep -Fq '0xffffffff80000000 0x0000000000200000' "$evidence_dir/kernel-elf.txt" || fail "virtual/physical base drift"
grep -Fq 'Number of program headers:         2' "$evidence_dir/kernel-elf.txt" || fail "program-header count drift"
if grep -Eq 'LOAD.*W.*E|INTERP|DYNAMIC' "$evidence_dir/kernel-elf.txt"; then
    fail "kernel contains a write-execute or dynamic program header"
fi
grep -Fq 'There are no relocations in this file.' "$evidence_dir/kernel-elf.txt" || fail "kernel contains relocations"

sha256sum "$kernel_a" "$manifest" "$repo_root/config/m0/phase-02-contracts.json" > "$evidence_dir/artifacts.sha256"
{
    printf 'task_id=m0-p02-fixtures\n'
    printf 'result=pass\n'
    printf 'scope=hosted-contracts-and-static-image\n'
    printf 'tested_revision=%s\n' "$(git -C "$repo_root" rev-parse HEAD)"
    printf 'dirty_file_count=%s\n' "$(wc -l < "$evidence_dir/git-status.txt")"
    printf 'kernel_sha256=%s\n' "$(sha256sum "$kernel_a" | awk '{print $1}')"
    printf 'emitted_elf_contract=pass\n'
    printf 'guest_enforcement=not-tested\n'
    printf 'physical_hardware=not-tested\n'
} > "$evidence_dir/result.txt"

printf 'Phase 2 contract verification passed; evidence: %s\n' "$evidence_dir"
