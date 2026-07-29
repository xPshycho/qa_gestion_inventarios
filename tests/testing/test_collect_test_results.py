from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest


SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "scripts"
    / "testing"
    / "collect_test_results.py"
)
SPEC = importlib.util.spec_from_file_location("collect_test_results", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class CollectTestResultsTest(unittest.TestCase):
    def test_collects_evidence_and_summarizes_junit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            junit = root / "native" / "TEST-example.xml"
            junit.parent.mkdir()
            junit.write_text(
                '<testsuite tests="3" failures="1" errors="0" '
                'skipped="1" time="1.25"></testsuite>',
                encoding="utf-8",
            )
            report = root / "native" / "report.txt"
            report.write_text("safe report", encoding="utf-8")
            coverage = root / "native" / "coverage-summary.json"
            coverage.write_text(
                json.dumps(
                    {
                        "total": {
                            "lines": {
                                "total": 10,
                                "covered": 8,
                                "pct": 80,
                            },
                            "branches": {
                                "total": 4,
                                "covered": 3,
                                "pct": 75,
                            },
                        }
                    }
                ),
                encoding="utf-8",
            )
            output = root / "test-results"

            exit_code = MODULE.main(
                [
                    "--suite",
                    "backend/unit",
                    "--status",
                    "passed",
                    "--output-root",
                    str(output),
                    "--junit",
                    str(junit.parent),
                    "--copy",
                    f"reports={report}",
                    "--coverage",
                    str(coverage),
                    "--metadata",
                    "workflow=local",
                ]
            )

            self.assertEqual(0, exit_code)
            summary = json.loads(
                (output / "backend/unit/summary.json").read_text(encoding="utf-8")
            )
            self.assertEqual("failed", summary["status"])
            self.assertEqual(3, summary["junit"]["tests"])
            self.assertEqual(1, summary["junit"]["failures"])
            self.assertEqual("local", summary["metadata"]["workflow"])
            self.assertEqual(80, summary["coverage"]["lines"]["percentage"])
            self.assertEqual(3, summary["coverage"]["branches"]["covered"])
            self.assertTrue(
                (output / "backend/unit/evidence/reports").is_file()
            )
            metrics = (output / "backend/unit/metrics.prom").read_text(
                encoding="utf-8"
            )
            self.assertIn(
                'inventory_test_suite_passed{suite="backend/unit"} 0', metrics
            )
            self.assertIn(
                'inventory_test_coverage_percentage'
                '{suite="backend/unit",metric="lines"} 80.0',
                metrics,
            )

    def test_reads_jacoco_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            coverage = root / "jacoco.xml"
            coverage.write_text(
                """<report name="inventory">
                <counter type="LINE" missed="10" covered="90"/>
                <counter type="BRANCH" missed="3" covered="7"/>
                </report>""",
                encoding="utf-8",
            )

            parsed = MODULE.parse_coverage([coverage])

            self.assertEqual(90.0, parsed["lines"]["percentage"])
            self.assertEqual(70.0, parsed["branches"]["percentage"])

    def test_missing_optional_evidence_is_recorded(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            output = root / "test-results"

            exit_code = MODULE.main(
                [
                    "--suite",
                    "security/zap",
                    "--output-root",
                    str(output),
                    "--copy",
                    f"reports={root / 'missing'}",
                ]
            )

            self.assertEqual(0, exit_code)
            summary = json.loads(
                (output / "security/zap/summary.json").read_text(encoding="utf-8")
            )
            self.assertFalse(summary["evidence"][0]["available"])
            self.assertEqual(0, summary["evidence"][0]["filesCopied"])

    def test_rejects_unsafe_suite_path(self) -> None:
        with self.assertRaises(SystemExit):
            MODULE.build_parser().parse_args(
                ["--suite", "../outside/unit"]
            )


if __name__ == "__main__":
    unittest.main()
