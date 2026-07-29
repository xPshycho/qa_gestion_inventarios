#!/usr/bin/env python3
"""Copy test evidence into one tree and publish machine-readable summaries."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import sys
import xml.etree.ElementTree as ET


SUITE_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*(/[a-z0-9][a-z0-9-]*)+$")
NAME_PATTERN = re.compile(r"^[a-zA-Z0-9_.-]+$")
VALID_STATUSES = ("passed", "failed", "cancelled", "unknown")


@dataclass
class JUnitTotals:
    files: int = 0
    tests: int = 0
    failures: int = 0
    errors: int = 0
    skipped: int = 0
    duration_seconds: float = 0.0

    def add(self, root: ET.Element) -> None:
        suites = [root] if root.tag == "testsuite" else list(root.findall("./testsuite"))
        for suite in suites:
            self.tests += int(suite.attrib.get("tests", 0))
            self.failures += int(suite.attrib.get("failures", 0))
            self.errors += int(suite.attrib.get("errors", 0))
            self.skipped += int(
                suite.attrib.get("skipped", suite.attrib.get("disabled", 0))
            )
            self.duration_seconds += float(suite.attrib.get("time", 0.0))


def parse_assignment(value: str) -> tuple[str, str]:
    name, separator, assigned_value = value.partition("=")
    if not separator or not NAME_PATTERN.fullmatch(name) or not assigned_value:
        raise argparse.ArgumentTypeError("expected NAME=VALUE")
    return name, assigned_value


def validate_suite(value: str) -> str:
    if not SUITE_PATTERN.fullmatch(value):
        raise argparse.ArgumentTypeError(
            "suite must contain at least service/type using lowercase path segments"
        )
    return value


def ensure_safe_relative_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or path == Path("."):
        raise ValueError(f"unsafe destination path: {value}")
    return path


def copy_evidence(source: Path, destination: Path) -> int:
    if source.is_symlink():
        raise ValueError(f"symbolic links are not accepted: {source}")
    if not source.exists():
        return 0

    copied = 0
    if source.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        return 1

    for candidate in sorted(source.rglob("*")):
        if candidate.is_symlink():
            raise ValueError(f"symbolic links are not accepted: {candidate}")
        if not candidate.is_file():
            continue
        relative = candidate.relative_to(source)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(candidate, target)
        copied += 1
    return copied


def junit_files(paths: list[Path]) -> list[Path]:
    files: set[Path] = set()
    for path in paths:
        if path.is_symlink():
            raise ValueError(f"symbolic links are not accepted: {path}")
        if path.is_file() and path.suffix == ".xml":
            files.add(path)
        elif path.is_dir():
            files.update(candidate for candidate in path.rglob("*.xml"))
    return sorted(files)


def parse_junit(paths: list[Path]) -> JUnitTotals:
    totals = JUnitTotals()
    for report in junit_files(paths):
        if report.is_symlink():
            raise ValueError(f"symbolic links are not accepted: {report}")
        try:
            root = ET.parse(report).getroot()
        except ET.ParseError as error:
            raise ValueError(f"invalid JUnit XML {report}: {error}") from error
        if root.tag not in {"testsuite", "testsuites"}:
            continue
        totals.files += 1
        totals.add(root)
    return totals


def prometheus_summary(suite: str, status: str, totals: JUnitTotals) -> str:
    escaped_suite = suite.replace("\\", "\\\\").replace('"', '\\"')
    status_value = 1 if status == "passed" else 0
    labels = f'suite="{escaped_suite}"'
    metrics = (
        ("inventory_test_suite_passed", status_value),
        ("inventory_test_junit_files", totals.files),
        ("inventory_test_cases", totals.tests),
        ("inventory_test_failures", totals.failures),
        ("inventory_test_errors", totals.errors),
        ("inventory_test_skipped", totals.skipped),
        ("inventory_test_duration_seconds", round(totals.duration_seconds, 6)),
    )
    return "".join(f"{name}{{{labels}}} {value}\n" for name, value in metrics)


def markdown_summary(summary: dict[str, object]) -> str:
    junit = summary["junit"]
    assert isinstance(junit, dict)
    evidence = summary["evidence"]
    assert isinstance(evidence, list)
    evidence_rows = "\n".join(
        f"| `{item['name']}` | `{item['source']}` | {item['filesCopied']} |"
        for item in evidence
    )
    return f"""# Test result: {summary['suite']}

- Status: **{summary['status']}**
- Generated: `{summary['generatedAt']}`
- JUnit files: {junit['files']}
- Tests: {junit['tests']}
- Failures: {junit['failures']}
- Errors: {junit['errors']}
- Skipped: {junit['skipped']}
- Duration: {junit['durationSeconds']} seconds

## Evidence

| Name | Source | Files copied |
|---|---|---:|
{evidence_rows or '| n/a | n/a | 0 |'}
"""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", required=True, type=validate_suite)
    parser.add_argument("--status", choices=VALID_STATUSES, default="unknown")
    parser.add_argument("--output-root", default="test-results")
    parser.add_argument(
        "--copy",
        action="append",
        default=[],
        type=parse_assignment,
        metavar="NAME=PATH",
        help="copy PATH into the suite evidence/NAME directory",
    )
    parser.add_argument(
        "--junit",
        action="append",
        default=[],
        type=Path,
        metavar="PATH",
        help="read a JUnit XML file or directory (repeatable)",
    )
    parser.add_argument(
        "--metadata",
        action="append",
        default=[],
        type=parse_assignment,
        metavar="NAME=VALUE",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = build_parser().parse_args(argv)
    output_root = Path(arguments.output_root).resolve()
    suite_path = ensure_safe_relative_path(arguments.suite)
    suite_directory = output_root / suite_path
    suite_directory.mkdir(parents=True, exist_ok=True)

    evidence: list[dict[str, object]] = []
    for name, source_value in arguments.copy:
        source = Path(source_value)
        destination = suite_directory / "evidence" / ensure_safe_relative_path(name)
        copied = copy_evidence(source, destination)
        evidence.append(
            {
                "name": name,
                "source": source.as_posix(),
                "filesCopied": copied,
                "available": copied > 0,
            }
        )

    totals = parse_junit(arguments.junit)
    status = arguments.status
    if totals.failures or totals.errors:
        status = "failed"

    summary = {
        "schemaVersion": 1,
        "suite": arguments.suite,
        "status": status,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "junit": {
            "files": totals.files,
            "tests": totals.tests,
            "failures": totals.failures,
            "errors": totals.errors,
            "skipped": totals.skipped,
            "durationSeconds": round(totals.duration_seconds, 6),
        },
        "evidence": evidence,
        "metadata": dict(arguments.metadata),
    }

    (suite_directory / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (suite_directory / "summary.md").write_text(
        markdown_summary(summary), encoding="utf-8"
    )
    (suite_directory / "metrics.prom").write_text(
        prometheus_summary(arguments.suite, status, totals), encoding="utf-8"
    )
    print(suite_directory)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"collect-test-results: {error}", file=sys.stderr)
        raise SystemExit(1) from error
