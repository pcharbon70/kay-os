#!/usr/bin/env bash
set -euo pipefail

archive=${1:-}
signature=${2:-}
signing_key=${3:-}
output_dir=${4:-}

readonly expected_archive_sha256=9a738586bff5790bd8bfef4a4868a2939cba3f81f22f121306d668c97f1c85d8
readonly expected_signature_sha256=c2ece24344e8b59350d8e7d9b70ce46b71f2c0cda3668096c14ff83f1f773e3d
readonly expected_fingerprint=05D29860D0A0668AAEFB9D691F3C021BECA23821

fail() {
    printf 'Limine release verification failed: %s\n' "$*" >&2
    exit 1
}

[[ -f "$archive" ]] || fail "archive is required"
[[ -f "$signature" ]] || fail "detached signature is required"
[[ -f "$signing_key" ]] || fail "pinned signing key is required"
[[ -n "$output_dir" && "$output_dir" == /* ]] || fail "absolute output directory is required"
if [[ -e "$output_dir" ]] && [[ -n "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    fail "output directory must be absent or empty"
fi

for command_name in sha256sum gpg tar awk grep; do
    command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done

[[ "$(sha256sum "$archive" | awk '{print $1}')" == "$expected_archive_sha256" ]] ||
    fail "archive hash does not match v12.9.0"
[[ "$(sha256sum "$signature" | awk '{print $1}')" == "$expected_signature_sha256" ]] ||
    fail "signature hash does not match v12.9.0"

keyring=$(mktemp -d /tmp/kay-limine-keyring.XXXXXX)
trap 'rm -rf -- "$keyring"' EXIT
chmod 700 "$keyring"
gpg --homedir "$keyring" --batch --no-autostart --import "$signing_key" >/dev/null 2>&1 ||
    fail "could not import pinned key"
actual_fingerprint=$(gpg --homedir "$keyring" --batch --no-autostart --with-colons --fingerprint |
    awk -F: '$1 == "fpr" { print $10; exit }')
[[ "$actual_fingerprint" == "$expected_fingerprint" ]] || fail "signing-key fingerprint mismatch"
gpg --homedir "$keyring" --batch --no-autostart --verify "$signature" "$archive" >/dev/null 2>&1 ||
    fail "detached signature is invalid"

mkdir -p "$output_dir"
tar -xJf "$archive" -C "$output_dir"
release_dir="$output_dir/limine-binary"
for required_file in limine-bios-cd.bin limine-bios.sys limine.c Makefile LICENSE; do
    [[ -f "$release_dir/$required_file" ]] || fail "release lacks $required_file"
done

{
    printf 'release=v12.9.0\n'
    printf 'archive_sha256=%s\n' "$expected_archive_sha256"
    printf 'signature_sha256=%s\n' "$expected_signature_sha256"
    printf 'signing_key_fingerprint=%s\n' "$expected_fingerprint"
    printf 'signature=valid\n'
} > "$output_dir/verification.txt"

printf 'Limine v12.9.0 archive and signature verified; extracted to %s\n' "$release_dir"
