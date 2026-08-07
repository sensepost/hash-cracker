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
    return {
        number
        for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1)
        if line.strip() and not line.lstrip().startswith("#")
    }


file_rows = []
total_lines = 0
total_covered = 0
for path in source_files:
    measured = measured_lines(path)
    covered_lines = len(covered[path] & measured)
    total_lines += len(measured)
    total_covered += covered_lines
    percent = (covered_lines / len(measured) * 100) if measured else 100.0
    file_rows.append(
        {
            "path": str(path.relative_to(root)),
            "covered_lines": covered_lines,
            "total_lines": len(measured),
            "percent_covered": round(percent, 2),
        }
    )

percent = (total_covered / total_lines * 100) if total_lines else 100.0
summary = {
    "schema_version": "1",
    "tool": "bash-xtrace",
    "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    "covered_lines": total_covered,
    "total_lines": total_lines,
    "percent_covered": round(percent, 2),
    "files": file_rows,
}

(output_dir / "coverage.json").write_text(json.dumps(summary, indent=2) + "\n")
(output_dir / "line-percent.txt").write_text(f"{percent:.2f}\n")

rows = "\n".join(
    "<tr><td>{}</td><td>{}</td><td>{}</td><td>{:.2f}%</td></tr>".format(
        html.escape(row["path"]),
        row["covered_lines"],
        row["total_lines"],
        row["percent_covered"],
    )
    for row in file_rows
)
(output_dir / "index.html").write_text(
    "<!doctype html><html><head><meta charset='utf-8'><title>hash-cracker Bash coverage</title>"
    "<style>body{font:14px sans-serif;margin:2rem}table{border-collapse:collapse}"
    "th,td{border:1px solid #ccc;padding:.4rem;text-align:left}</style></head><body>"
    f"<h1>Bash line coverage: {percent:.2f}%</h1>"
    f"<p>Covered {total_covered} of {total_lines} measured lines.</p>"
    "<table><thead><tr><th>File</th><th>Covered</th><th>Total</th><th>Coverage</th></tr></thead>"
    f"<tbody>{rows}</tbody></table></body></html>\n"
)

print(f"Bash line coverage: {percent:.2f}%")
print(f"Coverage report: {output_dir}")

if baseline_path.is_file() and re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", baseline_path.read_text().strip()):
    baseline = float(baseline_path.read_text().strip())
    if percent + 1e-9 < baseline:
        print(f"Coverage regressed: {percent:.2f}% < baseline {baseline:.2f}%", file=sys.stderr)
        raise SystemExit(1)
    print(f"Coverage baseline satisfied: {baseline:.2f}%")
else:
    (output_dir / "coverage-baseline-candidate.txt").write_text(f"{percent:.2f}\n")
    print(f"No committed coverage baseline found; candidate written to {output_dir}/coverage-baseline-candidate.txt")
PY
