#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COVERAGE_DIR="${COVERAGE_DIR:-$REPO_ROOT/coverage}"
BASELINE_FILE="${COVERAGE_BASELINE_FILE:-$REPO_ROOT/coverage-baseline.txt}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required for Bash coverage reporting." >&2
    exit 1
fi

rm -rf -- "$COVERAGE_DIR"
mkdir -p -- "$COVERAGE_DIR"

TMP_DIR="$(mktemp -d /tmp/hash-cracker-coverage.XXXX)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

TRACE_FILE="$TMP_DIR/bash-trace.log"
TRACE_INIT="$TMP_DIR/bash-env"

cat >"$TRACE_INIT" <<'EOF'
exec 9>>"$HASH_CRACKER_TRACE_FILE"
PS4='+${BASH_SOURCE[0]}:${LINENO}: '
BASH_XTRACEFD=9
export BASH_XTRACEFD PS4
set -x
EOF

echo "Running smoke tests with nested Bash tracing..."
HASH_CRACKER_TRACE_FILE="$TRACE_FILE" \
    BASH_ENV="$TRACE_INIT" \
    bash "$REPO_ROOT/tests/smoke.sh"

python3 - "$REPO_ROOT" "$TRACE_FILE" "$COVERAGE_DIR" "$BASELINE_FILE" <<'PY'
import datetime as dt
import html
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
trace_path = Path(sys.argv[2])
output_dir = Path(sys.argv[3])
baseline_path = Path(sys.argv[4])

source_files = [root / "hash-cracker.sh"]
source_files.extend(sorted((root / "scripts").glob("*.sh")))
source_files.extend(sorted((root / "scripts" / "processors").glob("*.sh")))
source_files.extend(sorted((root / "scripts" / "selectors").glob("*.sh")))

source_files = [path.resolve() for path in source_files]
source_map = {str(path): path for path in source_files}
covered = {path: set() for path in source_files}
trace_pattern = re.compile(r"^\++([^:]+):(\d+): ")

for raw_line in trace_path.read_text(errors="replace").splitlines():
    match = trace_pattern.match(raw_line)
    if not match:
        continue

    traced_path = Path(match.group(1))
    if not traced_path.is_absolute():
        traced_path = (root / traced_path).resolve()
    traced_path = str(traced_path)
    if traced_path in source_map:
        covered[source_map[traced_path]].add(int(match.group(2)))


def measured_lines(path):
    lines = path.read_text(errors="replace").splitlines()
    measured = set()
    heredoc_marker = None
    multiline_awk = False
    continuation = False

    for number, line in enumerate(lines, 1):
        stripped = line.strip()

        if heredoc_marker:
            if stripped == heredoc_marker:
                heredoc_marker = None
            continue

        if multiline_awk:
            if re.match(r"^['\"]\s+", stripped):
                multiline_awk = False
                if any(operator in stripped for operator in ("|", "&&", ";", ">")):
                    measured.add(number)
            continue

        if continuation:
            continuation = line.rstrip().endswith("\\")
            continue

        if not stripped or stripped.startswith("#"):
            continue

        if stripped in {"{", "}", "(", ")", "fi", "done", "esac", ";;", "then", "do"}:
            continue
        if stripped == "else" or stripped.startswith("elif "):
            continue
        if re.match(r"^(function\s+)?[A-Za-z_][A-Za-z0-9_-]*\s*\(\)\s*\{$", stripped):
            continue
        if stripped.startswith(("for ", "while ", "until ", "case ")):
            continue
        if stripped.endswith(")") and not stripped.startswith(
            ("if ", "echo ", "printf ", "return ", "exit ", "source ")
        ):
            continue

        heredoc_match = re.search(
            r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", line
        )
        if heredoc_match:
            heredoc_marker = heredoc_match.group(2)
            measured.add(number)
            continue

        if re.search(r"\bawk\b.*\s['\"]\s*$", line):
            multiline_awk = True
            if not line.lstrip().startswith("awk ") or not number > 1 or not lines[number - 2].strip().endswith("$("):
                measured.add(number)
            continue

        measured.add(number)
        continuation = line.rstrip().endswith("\\")

    return measured


def function_ranges(path):
    lines = path.read_text(errors="replace").splitlines()
    functions = []
    function_pattern = re.compile(
        r"^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_-]*)\s*\(\)\s*\{"
    )

    for start, line in enumerate(lines):
        match = function_pattern.match(line)
        if not match:
            continue

        heredoc_marker = None
        end = len(lines)
        for candidate in range(start + 1, len(lines)):
            candidate_line = lines[candidate]
            stripped = candidate_line.strip()
            if heredoc_marker:
                if stripped == heredoc_marker:
                    heredoc_marker = None
                continue
            heredoc_match = re.search(
                r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", candidate_line
            )
            if heredoc_match:
                heredoc_marker = heredoc_match.group(2)
                continue
            if stripped == "}":
                end = candidate + 1
                break

        functions.append((match.group(1), start + 1, end))

    return functions


file_rows = []
total_lines = 0
total_covered = 0
total_functions = 0
total_functions_covered = 0
for path in source_files:
    measured = measured_lines(path)
    covered_line_numbers = covered[path] & measured
    covered_lines = len(covered_line_numbers)
    functions = []
    for name, start, end in function_ranges(path):
        function_covered = bool(covered_line_numbers & set(range(start + 1, end)))
        functions.append(
            {
                "name": name,
                "start_line": start,
                "end_line": end,
                "covered": function_covered,
            }
        )
    functions_covered = sum(1 for function in functions if function["covered"])
    total_lines += len(measured)
    total_covered += covered_lines
    total_functions += len(functions)
    total_functions_covered += functions_covered
    percent = (covered_lines / len(measured) * 100) if measured else 100.0
    function_percent = (
        functions_covered / len(functions) * 100 if functions else 100.0
    )
    file_rows.append(
        {
            "path": str(path.relative_to(root)),
            "covered_lines": covered_lines,
            "total_lines": len(measured),
            "percent_covered": round(percent, 2),
            "covered_functions": functions_covered,
            "total_functions": len(functions),
            "function_percent_covered": round(function_percent, 2),
            "uncovered_lines": sorted(measured - covered_line_numbers),
            "functions": functions,
        }
    )

percent = (total_covered / total_lines * 100) if total_lines else 100.0
function_percent = (
    total_functions_covered / total_functions * 100 if total_functions else 100.0
)
summary = {
    "schema_version": "2",
    "tool": "bash-xtrace-executable-lines",
    "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    "covered_lines": total_covered,
    "total_lines": total_lines,
    "percent_covered": round(percent, 2),
    "functions": {
        "covered": total_functions_covered,
        "total": total_functions,
        "percent_covered": round(function_percent, 2),
    },
    "files": file_rows,
}

(output_dir / "coverage.json").write_text(json.dumps(summary, indent=2) + "\n")
(output_dir / "line-percent.txt").write_text(f"{percent:.2f}\n")
(output_dir / "function-percent.txt").write_text(f"{function_percent:.2f}\n")

rows = "\n".join(
    "<tr><td>{}</td><td>{}</td><td>{}</td><td>{:.2f}%</td><td>{}</td><td>{}</td><td>{:.2f}%</td></tr>".format(
        html.escape(row["path"]),
        row["covered_lines"],
        row["total_lines"],
        row["percent_covered"],
        row["covered_functions"],
        row["total_functions"],
        row["function_percent_covered"],
    )
    for row in file_rows
)
(output_dir / "index.html").write_text(
    "<!doctype html><html><head><meta charset='utf-8'><title>hash-cracker Bash coverage</title>"
    "<style>body{font:14px sans-serif;margin:2rem}table{border-collapse:collapse}"
    "th,td{border:1px solid #ccc;padding:.4rem;text-align:left}</style></head><body>"
    f"<h1>Bash executable-line coverage: {percent:.2f}%</h1>"
    f"<p>Covered {total_covered} of {total_lines} executable Bash lines.</p>"
    f"<p>Covered {total_functions_covered} of {total_functions} functions ({function_percent:.2f}%).</p>"
    "<table><thead><tr><th>File</th><th>Lines covered</th><th>Lines total</th><th>Line coverage</th>"
    "<th>Functions covered</th><th>Functions total</th><th>Function coverage</th></tr></thead>"
    f"<tbody>{rows}</tbody></table></body></html>\n"
)

print(f"Bash executable-line coverage: {percent:.2f}%")
print(f"Bash function coverage: {function_percent:.2f}%")
print(f"Coverage report: {output_dir}")

if baseline_path.is_file() and re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", baseline_path.read_text().strip()):
    baseline = float(baseline_path.read_text().strip())
    reported_percent = float(f"{percent:.2f}")
    if reported_percent < baseline:
        print(f"Coverage regressed: {percent:.2f}% < baseline {baseline:.2f}%", file=sys.stderr)
        raise SystemExit(1)
    print(f"Coverage baseline satisfied: {baseline:.2f}%")
else:
    (output_dir / "coverage-baseline-candidate.txt").write_text(f"{percent:.2f}\n")
    print(f"No committed coverage baseline found; candidate written to {output_dir}/coverage-baseline-candidate.txt")
PY
