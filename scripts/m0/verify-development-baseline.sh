#!/usr/bin/env bash
set -euo pipefail

readonly expected_zig="0.16.0"
readonly expected_zig_sha256="2317bbb91798556d9d0f38aabdac23db83f0979b25f767259ae474546724087c"
readonly expected_lld="LLD 21.1.0"
readonly expected_qemu_package="1:8.2.2+ds-0ubuntu1.18"
readonly expected_qemu_sha256="8a35ccba41582fc6c38b9df85fc9e35fa1d42f414d2d7d8090ee9b2f5e7c0854"
readonly expected_seabios_package="1.16.3-2"
readonly expected_seabios_sha256="4d597f68e06a0e28498e12e96e1f2ce64aee88a519685c61da92eb775c95a445"
readonly expected_machine="pc-q35-8.2"
readonly expected_cpu="Nehalem-v1"
readonly expected_bios="/usr/share/seabios/bios.bin"
readonly zig_command="${KAY_ZIG:-zig}"
readonly qemu_command="${KAY_QEMU:-qemu-system-x86_64}"
readonly bios_path="${KAY_BIOS:-$expected_bios}"

fail() {
  printf 'baseline verification failed: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

package_version() {
  dpkg-query -W -f='${Version}' "$1" 2>/dev/null || return 1
}

require_command "$zig_command"
require_command "$qemu_command"
require_command dpkg-query
require_command sha256sum
require_command awk
require_command grep

actual_zig="$("$zig_command" version)"
[[ "$actual_zig" == "$expected_zig" ]] ||
  fail "Zig $actual_zig is active; expected $expected_zig"
zig_executable="$("$zig_command" env | awk -F'"' '/[.]zig_exe =/{print $2; exit}')"
[[ -n "$zig_executable" && -x "$zig_executable" ]] ||
  fail "could not resolve the actual Zig executable"
actual_zig_sha256="$(sha256sum "$zig_executable" | awk '{print $1}')"
[[ "$actual_zig_sha256" == "$expected_zig_sha256" ]] ||
  fail "Zig hash $actual_zig_sha256 does not match $expected_zig_sha256"

actual_lld="$("$zig_command" ld.lld --version)"
[[ "$actual_lld" == "$expected_lld"* ]] ||
  fail "linker $actual_lld does not match $expected_lld"

actual_qemu_package="$(package_version qemu-system-x86)" ||
  fail "qemu-system-x86 package is not installed"
[[ "$actual_qemu_package" == "$expected_qemu_package" ]] ||
  fail "qemu-system-x86 package $actual_qemu_package does not match $expected_qemu_package"

actual_seabios_package="$(package_version seabios)" ||
  fail "seabios package is not installed"
[[ "$actual_seabios_package" == "$expected_seabios_package" ]] ||
  fail "seabios package $actual_seabios_package does not match $expected_seabios_package"
[[ "$bios_path" == "$expected_bios" ]] || fail "SeaBIOS path $bios_path does not match $expected_bios"
[[ -r "$bios_path" ]] || fail "SeaBIOS is not readable at $bios_path"

qemu_executable="$(command -v "$qemu_command")"
actual_qemu_sha256="$(sha256sum "$qemu_executable" | awk '{print $1}')"
[[ "$actual_qemu_sha256" == "$expected_qemu_sha256" ]] ||
  fail "QEMU hash $actual_qemu_sha256 does not match $expected_qemu_sha256"

actual_seabios_sha256="$(sha256sum "$bios_path" | awk '{print $1}')"
[[ "$actual_seabios_sha256" == "$expected_seabios_sha256" ]] ||
  fail "SeaBIOS hash $actual_seabios_sha256 does not match $expected_seabios_sha256"

machine_help="$("$qemu_command" -machine help)"
grep -Fq "$expected_machine" <<<"$machine_help" ||
  fail "QEMU does not expose machine $expected_machine"
cpu_help="$("$qemu_command" -cpu help)"
grep -Fq "$expected_cpu" <<<"$cpu_help" ||
  fail "QEMU does not expose CPU $expected_cpu"

printf 'profile=kay-os-m0-x86-64\n'
printf 'zig_version=%s\n' "$actual_zig"
printf 'zig_path=%s\n' "$zig_executable"
printf 'zig_sha256=%s\n' "$actual_zig_sha256"
printf 'lld_version=%s\n' "$actual_lld"
printf 'qemu_package_version=%s\n' "$actual_qemu_package"
qemu_version="$("$qemu_command" --version)"
printf 'qemu_version=%s\n' "${qemu_version%%$'\n'*}"
printf 'qemu_path=%s\n' "$qemu_executable"
printf 'qemu_sha256=%s\n' "$actual_qemu_sha256"
printf 'qemu_machine=%s\n' "$expected_machine"
printf 'qemu_cpu=%s\n' "$expected_cpu"
printf 'seabios_package_version=%s\n' "$actual_seabios_package"
printf 'seabios_path=%s\n' "$bios_path"
printf 'seabios_sha256=%s\n' "$actual_seabios_sha256"
