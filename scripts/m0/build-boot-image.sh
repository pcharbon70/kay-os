#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
output_dir=${1:-}
limine_dir=${2:-}
zig_executable=${ZIG:-$(command -v zig || true)}
xorriso_executable=${XORRISO:-$(command -v xorriso || true)}
readonly source_date_epoch=1789704000

fail() {
    printf 'boot image build failed: %s\n' "$*" >&2
    exit 1
}

[[ -n "$output_dir" && "$output_dir" == /* ]] || fail "usage: $0 ABSOLUTE_EMPTY_OUTPUT_DIR ABSOLUTE_LIMINE_RELEASE_DIR"
[[ -d "$limine_dir" && "$limine_dir" == /* ]] || fail "Limine release directory is required"
if [[ -e "$output_dir" ]] && [[ -n "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    fail "output directory must be absent or empty"
fi
[[ -n "$zig_executable" && -x "$zig_executable" ]] || fail "zig is required"
[[ -n "$xorriso_executable" && -x "$xorriso_executable" ]] || fail "xorriso is required"
for command_name in make cc readelf sha256sum touch; do
    command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done
for required_file in limine-bios-cd.bin limine-bios.sys limine.c Makefile; do
    [[ -f "$limine_dir/$required_file" ]] || fail "Limine release lacks $required_file"
done

mkdir -p "$output_dir/build/local" "$output_dir/build/global" "$output_dir/prefix" \
    "$output_dir/iso-root/boot"
(
    cd "$repo_root"
    ZIG_LOCAL_CACHE_DIR="$output_dir/build/local" \
    ZIG_GLOBAL_CACHE_DIR="$output_dir/build/global" \
        "$zig_executable" build boot-kernel --prefix "$output_dir/prefix" --summary all
)
cp -- "$output_dir/prefix/bin/kay-m0-kernel" "$output_dir/iso-root/boot/kay-m0-kernel.elf"
cp -- "$limine_dir/limine-bios-cd.bin" "$output_dir/iso-root/boot/limine-bios-cd.bin"
cp -- "$limine_dir/limine-bios.sys" "$output_dir/iso-root/boot/limine-bios.sys"
cp -- "$repo_root/config/m0/limine.conf" "$output_dir/iso-root/limine.conf"

find "$output_dir/iso-root" -exec touch -h -d "@$source_date_epoch" {} +
make -C "$limine_dir" limine >/dev/null

SOURCE_DATE_EPOCH=$source_date_epoch "$xorriso_executable" -as mkisofs \
    -quiet -R -r -J -V KAY_M0 \
    -b boot/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
    -o "$output_dir/kay-m0.iso" "$output_dir/iso-root"
iso_path="$output_dir/kay-m0.iso"
[[ -f "$iso_path" && ! -L "$iso_path" ]] || fail "generated ISO is not a regular file"
"$limine_dir/limine" bios-install "$iso_path" --force >/dev/null

readelf -hW -lW "$output_dir/iso-root/boot/kay-m0-kernel.elf" > "$output_dir/kernel-elf.txt"
sha256sum "$output_dir/iso-root/boot/kay-m0-kernel.elf" "$output_dir/kay-m0.iso" > "$output_dir/artifacts.sha256"
printf 'source_date_epoch=%s\nfirmware=SeaBIOS\nmedia=read-only-ISO\n' "$source_date_epoch" > "$output_dir/build-profile.txt"
printf 'M0 boot contract image built at %s\n' "$output_dir/kay-m0.iso"
