#!/usr/bin/env python3
"""Measure first-party campaign line coverage without third-party packages."""

from __future__ import annotations

import datetime as dt
import dis
import html
import json
import os
import sys
import trace
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TESTS_DIR = ROOT / "tests"
TARGET = (ROOT / "scripts" / "campaign.py").resolve()
DEFAULT_OUTPUT = ROOT / "coverage" / "python"
DEFAULT_BASELINE = ROOT / "python-coverage-baseline.txt"


def executable_lines(path: Path) -> set[int]:
    """Return line numbers with executable bytecode in a Python source file."""

    compiled = compile(path.read_text(encoding="utf-8"), str(path), "exec")
    lines: set[int] = set()

    def visit(code: object) -> None:
        if not isinstance(code, type(compiled)):
            return
        lines.update(
            line
            for _, line in dis.findlinestarts(code)
            if line is not None and line > 0
        )
        for constant in code.co_consts:
            if isinstance(constant, type(code)):
                visit(constant)

    visit(compiled)
    return lines


def run_campaign_tests() -> bool:
    suite = unittest.defaultTestLoader.discover(
        start_dir=str(TESTS_DIR),
        pattern="test_*.py",
    )
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    return result.wasSuccessful()


def trace_campaign_tests() -> tuple[bool, set[int]]:
    ignored_dirs = tuple(
        str(path.resolve())
        for path in {Path(sys.prefix), Path(sys.base_prefix), TESTS_DIR}
    )
    tracer = trace.Trace(
        count=True,
        trace=False,
        ignoremods=("trace", "unittest"),
        ignoredirs=ignored_dirs,
    )
    tests_passed = bool(tracer.runfunc(run_campaign_tests))
    covered = {
        line
        for (filename, line), count in tracer.results().counts.items()
        if count > 0
        and line > 0
        and Path(filename).resolve() == TARGET
    }
    return tests_passed, covered


def write_report(
    output_dir: Path,
    measured: set[int],
    covered: set[int],
    tests_passed: bool,
) -> float:
    covered_lines = measured & covered
    uncovered_lines = sorted(measured - covered_lines)
    percent = (len(covered_lines) / len(measured) * 100) if measured else 100.0
    rounded_percent = float(f"{percent:.2f}")
    relative_target = str(TARGET.relative_to(ROOT))
    summary = {
        "schema_version": "1",
        "tool": "python-trace-bytecode-lines",
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "target": relative_target,
        "tests_passed": tests_passed,
        "covered_lines": len(covered_lines),
        "total_lines": len(measured),
        "percent_covered": rounded_percent,
        "uncovered_lines": uncovered_lines,
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "coverage.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    (output_dir / "line-percent.txt").write_text(
        f"{rounded_percent:.2f}\n", encoding="utf-8"
    )
    uncovered = ", ".join(str(line) for line in uncovered_lines) or "none"
    (output_dir / "index.html").write_text(
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<title>hash-cracker Python campaign coverage</title>"
        "<style>body{font:14px sans-serif;margin:2rem}"
        "code,pre{background:#f4f4f4;padding:.25rem}</style></head><body>"
        f"<h1>Python campaign line coverage: {rounded_percent:.2f}%</h1>"
        f"<p>Target: <code>{html.escape(relative_target)}</code></p>"
        f"<p>Covered {len(covered_lines)} of {len(measured)} executable bytecode lines.</p>"
        f"<p>Tests passed: {html.escape(str(tests_passed))}</p>"
        f"<h2>Uncovered lines</h2><pre>{html.escape(uncovered)}</pre>"
        "</body></html>\n",
        encoding="utf-8",
    )
    return rounded_percent


def enforce_baseline(percent: float, baseline_path: Path, output_dir: Path) -> bool:
    if not baseline_path.is_file():
        (output_dir / "baseline-candidate.txt").write_text(
            f"{percent:.2f}\n", encoding="utf-8"
        )
        print(
            "No Python coverage baseline found; candidate written to "
            f"{output_dir / 'baseline-candidate.txt'}"
        )
        return True

    raw_baseline = baseline_path.read_text(encoding="utf-8").strip()
    try:
        baseline = float(raw_baseline)
    except ValueError:
        baseline = None
    if baseline is not None and baseline >= 0:
        if percent < baseline:
            print(
                f"Python coverage regressed: {percent:.2f}% < baseline {baseline:.2f}%",
                file=sys.stderr,
            )
            return False
        print(f"Python coverage baseline satisfied: {baseline:.2f}%")
        return True

    (output_dir / "baseline-candidate.txt").write_text(
        f"{percent:.2f}\n", encoding="utf-8"
    )
    print(
        "No valid Python coverage baseline found; candidate written to "
        f"{output_dir / 'baseline-candidate.txt'}"
    )
    return True


def main() -> int:
    output_dir = Path(os.environ.get("PYTHON_COVERAGE_DIR", DEFAULT_OUTPUT)).resolve()
    baseline_path = Path(
        os.environ.get("PYTHON_COVERAGE_BASELINE_FILE", DEFAULT_BASELINE)
    ).resolve()
    measured = executable_lines(TARGET)
    tests_passed, covered = trace_campaign_tests()
    percent = write_report(output_dir, measured, covered, tests_passed)
    print(f"Python campaign line coverage: {percent:.2f}%")
    print(f"Python coverage report: {output_dir}")
    baseline_ok = enforce_baseline(percent, baseline_path, output_dir)
    return 0 if tests_passed and baseline_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
