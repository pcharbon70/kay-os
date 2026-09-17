#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
output_dir=${1:-}

if [[ -z "$output_dir" ]]; then
    echo "usage: $0 ABSOLUTE_OUTPUT_DIRECTORY" >&2
    exit 2
fi
if [[ "$output_dir" != /* ]]; then
    echo "output directory must be absolute: $output_dir" >&2
    exit 2
fi
if [[ -e "$output_dir" ]] && [[ -n "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "output directory must be absent or empty: $output_dir" >&2
    exit 2
fi

zig_executable=${ZIG:-$(command -v zig || true)}
if [[ -z "$zig_executable" ]]; then
    echo "zig is required" >&2
    exit 2
fi

mkdir -p "$output_dir/prefix" "$output_dir/cache/local" "$output_dir/cache/global"
(
    cd "$repo_root"
    ZIG_LOCAL_CACHE_DIR="$output_dir/cache/local" \
    ZIG_GLOBAL_CACHE_DIR="$output_dir/cache/global" \
        "$zig_executable" build --prefix "$output_dir/prefix" --summary all
)

canonical_elf="$output_dir/prefix/bin/kay-m0-fixture"
audit_elf="$output_dir/prefix/bin/kay-m0-fixture-audit"
cp -- "$canonical_elf" "$output_dir/kay-m0-fixture.elf"
cp -- "$audit_elf" "$output_dir/kay-m0-fixture-audit.elf"

sha256sum "$output_dir/kay-m0-fixture-audit.elf" > "$output_dir/audit.sha256"
sha256sum "$output_dir/kay-m0-fixture.elf" > "$output_dir/canonical.sha256"
nm -n "$output_dir/kay-m0-fixture-audit.elf" > "$output_dir/symbols.map"
readelf -hW -SW -lW -sW "$output_dir/kay-m0-fixture-audit.elf" > "$output_dir/elf.map"
objdump -drwC -Mintel "$output_dir/kay-m0-fixture-audit.elf" > "$output_dir/disassembly.txt"

printf '%s\n' "$zig_executable build --prefix <absolute-output>/prefix --summary all" \
    > "$output_dir/build-command.txt"
