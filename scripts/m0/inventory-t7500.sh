#!/usr/bin/env bash
set -euo pipefail

section() {
  printf '\n## %s\n' "$1"
}

run_if_available() {
  local command_name="$1"
  shift
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" "$@" 2>&1 || printf 'command failed: %s\n' "$command_name"
  else
    printf 'command unavailable: %s\n' "$command_name"
  fi
}

safe_dmi_field() {
  local label="$1"
  local path="$2"
  if [[ -r "$path" ]]; then
    printf '%s: ' "$label"
    tr -d '\000' <"$path"
    printf '\n'
  else
    printf '%s: unavailable\n' "$label"
  fi
}

cat <<'HEADER'
# Kay OS Dell Precision T7500 read-only inventory

This report intentionally excludes system serial numbers, board serial numbers,
asset tags, chassis serial numbers, MAC addresses, storage identifiers, and raw
firmware table contents. Review it before publishing.
HEADER

section "Collection environment"
printf 'collected_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'hostname: redacted\n'
run_if_available uname -srvm

section "CPU identity, features, and topology"
run_if_available lscpu
run_if_available lscpu -e=CPU,SOCKET,CORE,NODE,ONLINE,MAXMHZ,MINMHZ

section "Memory"
run_if_available free -b
if [[ -r /proc/meminfo ]]; then
  grep -E '^(MemTotal|HugePages_Total|Hugepagesize):' /proc/meminfo || true
fi

section "Safe DMI fields"
safe_dmi_field system_vendor /sys/class/dmi/id/sys_vendor
safe_dmi_field product_name /sys/class/dmi/id/product_name
safe_dmi_field product_version /sys/class/dmi/id/product_version
safe_dmi_field board_vendor /sys/class/dmi/id/board_vendor
safe_dmi_field board_name /sys/class/dmi/id/board_name
safe_dmi_field board_version /sys/class/dmi/id/board_version
safe_dmi_field chassis_vendor /sys/class/dmi/id/chassis_vendor
safe_dmi_field chassis_type /sys/class/dmi/id/chassis_type
safe_dmi_field bios_vendor /sys/class/dmi/id/bios_vendor
safe_dmi_field bios_version /sys/class/dmi/id/bios_version
safe_dmi_field bios_date /sys/class/dmi/id/bios_date

section "PCI devices"
run_if_available lspci -nn

section "Serial facilities"
for device in /dev/ttyS*; do
  [[ -e "$device" ]] || continue
  ls -l "$device"
done

section "ACPI table identities"
if [[ -d /sys/firmware/acpi/tables ]]; then
  while IFS= read -r -d '' table; do
    if digest="$(sha256sum "$table" 2>/dev/null)"; then
      printf '%s %s\n' "$(basename "$table")" "${digest%% *}"
    else
      printf '%s unreadable\n' "$(basename "$table")"
    fi
  done < <(find /sys/firmware/acpi/tables -maxdepth 1 -type f -print0 | sort -z)
else
  printf 'ACPI table directory unavailable\n'
fi

section "Excluded identifiers"
printf '%s\n' \
  'system/product/board/chassis serial numbers: deliberately not collected' \
  'asset and service tags: deliberately not collected' \
  'MAC addresses: deliberately not collected' \
  'storage serial numbers and UUIDs: deliberately not collected'
