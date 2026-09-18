#!/usr/bin/env python3
"""Fail-closed reconciliation for the M0 Phase 2 policy and case manifest."""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import re
import sys


def fail(message: str) -> None:
    raise SystemExit(f"phase 2 policy check failed: {message}")


def require_text(path: pathlib.Path, fragments: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for fragment in fragments:
        if fragment not in text:
            fail(f"{path} does not bind {fragment!r}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=pathlib.Path, required=True)
    parser.add_argument("--results", type=pathlib.Path)
    parser.add_argument("--list-runner")
    parser.add_argument("--zig-policy", type=pathlib.Path)
    args = parser.parse_args()

    repo = args.repo.resolve()
    manifest = json.loads((repo / "config/m0/phase-02-cases.json").read_text())
    contract = json.loads((repo / "config/m0/phase-02-contracts.json").read_text())
    if manifest.get("format_version") != 2 or manifest.get("task_id") != "m0-p02-fixtures":
        fail("unsupported case-manifest identity")
    cases = manifest.get("cases")
    if not isinstance(cases, list) or not cases:
        fail("case manifest is empty")

    ids: list[str] = []
    allowed_runners = {"zig", "contract-driver", "integration"}
    for case in cases:
        if set(case) != {"id", "kind", "runner"}:
            fail(f"malformed case record: {case!r}")
        case_id = case["id"]
        if not re.fullmatch(r"m0-p02-[tn][0-9]{2}-[a-z0-9-]+", case_id):
            fail(f"invalid case id: {case_id!r}")
        if case["kind"] not in {"positive", "negative"} or case["runner"] not in allowed_runners:
            fail(f"invalid case classification: {case_id}")
        ids.append(case_id)
    if len(ids) != len(set(ids)):
        fail("case IDs are not unique")

    limits = manifest["limits"]
    expected_limits = {
        "maximum_boot_snapshot_bytes": contract["snapshot"]["maximum_bytes"],
        "maximum_memory_records": contract["snapshot"]["maximum_memory_records"],
        "maximum_image_segments": contract["image"]["maximum_load_segments"],
        "maximum_console_transfer_bytes": contract["console"]["maximum_transfer_bytes"],
    }
    for key, expected in expected_limits.items():
        if limits.get(key) != expected:
            fail(f"manifest {key} does not match contract value {expected}")
    for key in ("contract_test_seconds", "kernel_build_seconds", "boot_image_seconds", "phase_01_regression_seconds"):
        if not isinstance(limits.get(key), int) or limits[key] <= 0:
            fail(f"deadline {key} is not a positive integer")

    require_text(
        repo / "src/m0/contracts.zig",
        [
            f"pub const max_boot_snapshot_bytes: usize = {contract['snapshot']['maximum_bytes']};",
            f"pub const max_memory_records: usize = {contract['snapshot']['maximum_memory_records']};",
            f"pub const max_image_segments: usize = {contract['image']['maximum_load_segments']};",
            f"pub const max_console_transfer: usize = {contract['console']['maximum_transfer_bytes']};",
            f"pub const console_endpoint: u16 = {contract['console']['endpoint']};",
            f"pub const clock_endpoint: u16 = {contract['clock']['endpoint']};",
            f"pub const kernel_physical_base: u64 = 0x{int(contract['image']['physical_base'], 16):x};",
            f"pub const physical_limit: u64 = {contract['image']['physical_limit_mib']} * 1024 * 1024;",
        ],
    )
    require_text(
        repo / "src/m0/limine.zig",
        [
            f"pub const protocol_base_revision: u64 = {contract['boot']['protocol_base_revision']};",
            "0xf6b8f4b39de7d1ae",
            "0xfab91a6940fcb9cf",
            "0x785c6ed015d3e316",
            "0x181e920a7852b9d9",
            "0xf9562b2d5c95a6c8",
            "0x6a7b384944536bdc",
            "0xadc0e0531bb10d03",
            "0x9572709f31764c62",
        ],
    )
    require_text(
        repo / "linker/x86_64-m0-higher-half.ld",
        [
            f"KERNEL_VIRTUAL_BASE = {contract['image']['virtual_base']};",
            f"KERNEL_PHYSICAL_BASE = {contract['image']['physical_base']};",
            "KEEP(*(.limine_requests_start))",
            "KEEP(*(.limine_requests))",
            "KEEP(*(.limine_requests_end))",
            f"(__stack_top - __stack_bottom) == 0x{contract['image']['stack_bytes']:x}",
        ],
    )
    require_text(
        repo / "src/m0/image_audit.zig",
        [f"load_count != {contract['image']['expected_fixture_load_segments']}"],
    )
    require_text(
        repo / "scripts/m0/verify-phase-02-contracts.sh",
        [
            f"readonly contract_seconds={limits['contract_test_seconds']}",
            f"readonly build_seconds={limits['kernel_build_seconds']}",
        ],
    )
    require_text(
        repo / "scripts/m0/verify-phase-02.sh",
        [
            f"readonly boot_image_seconds={limits['boot_image_seconds']}",
            f"readonly phase_01_seconds={limits['phase_01_regression_seconds']}",
        ],
    )
    require_text(
        repo / "scripts/m0/build-boot-image.sh",
        [f"readonly source_date_epoch={contract['boot_media']['source_date_epoch']}"],
    )

    expected_authority = {
        ("console-read", 1, "console-read", "caller-budget", "kernel-console-service", "byte-count-and-bytes"),
        ("console-write", 1, "console-write", "caller-budget", "kernel-console-service", "byte-count"),
        ("clock-now", 2, "clock-read", "caller-budget", "kernel-clock-service", "monotonic-nanoseconds"),
        ("clock-wait-until", 2, "clock-wait", "caller-budget", "kernel-clock-service", "wait-completion"),
    }
    actual_authority = {
        (row["operation"], row["endpoint"], row["grant"], row["payer"], row["owner"], row["response"])
        for row in contract["authority_contracts"]
    }
    if actual_authority != expected_authority:
        fail("authority operation table is incomplete or drifted")
    if contract["result_codes"] != {
        "ok": 0,
        "denied": 1,
        "invalid_endpoint": 2,
        "invalid_length": 3,
        "deadline_in_past": 4,
    }:
        fail("stable result-code table drifted")

    if args.zig_policy:
        zig_operations: set[tuple[str, int, str, str, str, str]] = set()
        zig_results: dict[str, int] = {}
        for line in args.zig_policy.read_text(encoding="utf-8").splitlines():
            fields = line.split("\t")
            if fields[0] == "operation" and len(fields) == 8:
                operation, endpoint, grant, payer, owner, response, maximum = fields[1:]
                zig_operations.add(
                    (
                        operation.replace("_", "-"),
                        int(endpoint),
                        grant.replace("_", "-"),
                        payer.replace("_", "-"),
                        owner.replace("_", "-"),
                        response.replace("_", "-"),
                    )
                )
                expected_maximum = {
                    "console_read": contract["console"]["maximum_transfer_bytes"],
                    "console_write": contract["console"]["maximum_transfer_bytes"],
                    "clock_now": 8,
                    "clock_wait_until": 0,
                }[operation]
                if int(maximum) != expected_maximum:
                    fail(f"Zig maximum transfer drifted for {operation}")
            elif fields[0] == "result" and len(fields) == 3:
                zig_results[fields[1]] = int(fields[2])
            else:
                fail(f"malformed Zig policy line: {line!r}")
        if zig_operations != expected_authority:
            fail("Zig operation table does not match the JSON authority contract")
        if zig_results != contract["result_codes"]:
            fail("Zig result-code table does not match the JSON authority contract")

    if args.list_runner:
        if args.list_runner not in allowed_runners:
            fail(f"unknown runner: {args.list_runner}")
        for case in cases:
            if case["runner"] == args.list_runner:
                print(case["id"])

    if args.results:
        with args.results.open(newline="", encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream, delimiter="\t"))
        if not rows or set(rows[0]) != {"case_id", "result", "observation"}:
            fail("result table has the wrong columns")
        result_ids = [row["case_id"] for row in rows]
        if len(result_ids) != len(set(result_ids)):
            fail("result table contains duplicate case IDs")
        if set(result_ids) != set(ids):
            missing = sorted(set(ids) - set(result_ids))
            extra = sorted(set(result_ids) - set(ids))
            fail(f"result set mismatch; missing={missing}, extra={extra}")
        failed = [row["case_id"] for row in rows if row["result"] != "pass" or not row["observation"]]
        if failed:
            fail(f"non-passing or empty observations: {failed}")


if __name__ == "__main__":
    try:
        main()
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        fail(str(exc))
