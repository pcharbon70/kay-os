#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
evidence_dir=${1:-"$repo_root/evidence/local/m0-p01-build"}
zig_executable=${ZIG:-$(command -v zig || true)}

if [[ -z "$zig_executable" ]]; then
    echo "zig is required" >&2
    exit 2
fi
if [[ "$evidence_dir" != /* ]]; then
    echo "evidence directory must be absolute: $evidence_dir" >&2
    exit 2
fi
if [[ -e "$evidence_dir" ]] && [[ -n "$(find "$evidence_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "evidence directory must be absent or empty: $evidence_dir" >&2
    exit 2
fi

work_root=$(mktemp -d /tmp/kay-m0-build-closure.XXXXXX)
trap 'rm -rf -- "$work_root"' EXIT
mkdir -p "$evidence_dir" "$work_root/a/source" "$work_root/b/source"

copy_source() {
    local destination=$1
    (
        cd "$repo_root"
        tar \
            --exclude=.git \
            --exclude=.zig-cache \
            --exclude=zig-out \
            --exclude=evidence/local \
            -cf - .
    ) | tar -xf - -C "$destination"
}

copy_source "$work_root/a/source"
copy_source "$work_root/b/source"

ZIG="$zig_executable" "$work_root/a/source/scripts/m0/build-fixture.sh" "$work_root/a/output" \
    > "$evidence_dir/build-a.log" 2>&1
ZIG="$zig_executable" "$work_root/b/source/scripts/m0/build-fixture.sh" "$work_root/b/output" \
    > "$evidence_dir/build-b.log" 2>&1

artifact_a="$work_root/a/output/kay-m0-fixture.elf"
artifact_b="$work_root/b/output/kay-m0-fixture.elf"
audit_a="$work_root/a/output/kay-m0-fixture-audit.elf"

cmp --silent "$artifact_a" "$artifact_b"
cmp --silent "$work_root/a/output/symbols.map" "$work_root/b/output/symbols.map"
cmp --silent "$work_root/a/output/elf.map" "$work_root/b/output/elf.map"

cp -- "$artifact_a" "$evidence_dir/kay-m0-fixture.elf"
cp -- "$work_root/a/output/symbols.map" "$evidence_dir/symbols.map"
cp -- "$work_root/a/output/elf.map" "$evidence_dir/elf.map"
cp -- "$work_root/a/output/disassembly.txt" "$evidence_dir/disassembly.txt"

sha256sum "$artifact_a" "$artifact_b" > "$evidence_dir/canonical-builds.sha256"
sha256sum \
    "$work_root/a/output/kay-m0-fixture-audit.elf" \
    "$work_root/b/output/kay-m0-fixture-audit.elf" \
    > "$evidence_dir/audit-builds.sha256"

cat > "$evidence_dir/reproducibility.txt" <<'EOF'
Two clean source copies were built from distinct absolute directories with
independent local and global Zig caches. The unstripped audit ELFs may differ
only because DWARF records each absolute source directory. The acceptance ELF is
produced directly by Zig's `-fstrip` target; its bytes and the audit targets'
symbol and ELF maps must compare equal. No other nondeterminism is permitted.
EOF

readelf -hW "$artifact_a" | grep -Eq 'Class:[[:space:]]+ELF64'
readelf -hW "$artifact_a" | grep -Eq 'Type:[[:space:]]+EXEC'
readelf -hW "$artifact_a" | grep -Eq 'Machine:[[:space:]]+Advanced Micro Devices X86-64'
readelf -hW "$artifact_a" | grep -Eq 'Entry point address:[[:space:]]+0x200000'
if readelf -lW "$artifact_a" | grep -Eq 'INTERP|DYNAMIC'; then
    echo "dynamic loader dependency found" >&2
    exit 1
fi
if [[ -n "$(nm -u "$audit_a")" ]]; then
    echo "undefined symbols found" >&2
    nm -u "$audit_a" >&2
    exit 1
fi

for symbol in _start kay_fixture_main kay_c_accumulate kay_zig_callback kay_panic __stack_bottom __stack_top; do
    grep -Eq "[[:space:]]${symbol}$" "$evidence_dir/symbols.map"
done

if grep -Eqi '(^|[^[:alnum:]_])(xmm[0-9]+|ymm[0-9]+|zmm[0-9]+|mm[0-7])([^[:alnum:]_]|$)' \
    "$evidence_dir/disassembly.txt"; then
    echo "FP/SIMD register use found" >&2
    exit 1
fi
if grep -Eqi '[[:space:]](fld|fst|fadd|fsub|fmul|fdiv|fcom|fucom|fxch|fwait)([[:space:][:alpha:].]|$)' \
    "$evidence_dir/disassembly.txt"; then
    echo "x87 instruction use found" >&2
    exit 1
fi

run_expected_link_failure() {
    local case_name=$1
    local source_file=$2
    local expected_symbol=$3
    local case_root="$work_root/negative-$case_name"
    mkdir -p "$case_root/local" "$case_root/global"
    if ZIG_LOCAL_CACHE_DIR="$case_root/local" ZIG_GLOBAL_CACHE_DIR="$case_root/global" \
        "$zig_executable" build-exe "$source_file" \
            -target x86_64-freestanding-none -mcpu nehalem -O ReleaseSmall \
            -fllvm -flld -fno-compiler-rt -fno-ubsan-rt \
            -fno-PIC -fno-PIE -mno-red-zone -fentry=_start \
            -femit-bin="$case_root/output.elf" \
            > "$evidence_dir/negative-$case_name.log" 2>&1; then
        echo "negative case unexpectedly linked: $case_name" >&2
        exit 1
    fi
    grep -Fq "undefined symbol: $expected_symbol" "$evidence_dir/negative-$case_name.log"
}

run_expected_link_failure \
    undefined-helper "$repo_root/tests/m0/negative/undefined-helper.c" __udivti3
run_expected_link_failure \
    host-syscall "$repo_root/tests/m0/negative/host-syscall.c" write

cpu_case_root="$work_root/negative-cpu-option"
mkdir -p "$cpu_case_root/local" "$cpu_case_root/global" "$cpu_case_root/prefix"
if (
    cd "$repo_root"
    ZIG_LOCAL_CACHE_DIR="$cpu_case_root/local" ZIG_GLOBAL_CACHE_DIR="$cpu_case_root/global" \
        "$zig_executable" build -Dcpu=haswell --prefix "$cpu_case_root/prefix"
) > "$evidence_dir/negative-cpu-option.log" 2>&1; then
    echo "CPU override unexpectedly accepted" >&2
    exit 1
fi
grep -Fq 'invalid option: -Dcpu' "$evidence_dir/negative-cpu-option.log"

{
    printf 'task_id=m0-p01-build\n'
    printf 'result=pass\n'
    printf 'zig_version='
    "$zig_executable" version
    printf 'zig_sha256='
    sha256sum "$zig_executable" | awk '{print $1}'
    printf 'artifact_sha256='
    sha256sum "$artifact_a" | awk '{print $1}'
    printf 'absolute_build_a=%s\n' "$work_root/a/source"
    printf 'absolute_build_b=%s\n' "$work_root/b/source"
    printf 'negative_cases=undefined-helper,host-syscall,cpu-option-drift\n'
} > "$evidence_dir/result.txt"

echo "m0-p01-build verification passed; evidence: $evidence_dir"
