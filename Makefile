SHELL_SOURCES := $(shell find . -type f -name '*.sh' ! -path './.git/*' ! -path './coverage/*' ! -path './scripts/extensions/*' | sort)
SHELLCHECK_VERSION ?= 0.10.0
SHFMT_VERSION ?= 3.8.0

.PHONY: verify-shellcheck verify-shfmt verify-tools lint format-check format qa test test-smoke test-campaign test-integration coverage coverage-python coverage-check

verify-shellcheck:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not found. Install ShellCheck $(SHELLCHECK_VERSION) to run maintainer checks."; \
		exit 1; \
	fi
	@actual_version=$$(shellcheck --version | sed -n 's/^version: //p'); \
	if [ "$$actual_version" != "$(SHELLCHECK_VERSION)" ]; then \
		echo "ShellCheck $(SHELLCHECK_VERSION) required; found $$actual_version."; \
		exit 1; \
	fi

verify-shfmt:
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt not found. Install shfmt $(SHFMT_VERSION) to run maintainer checks."; \
		exit 1; \
	fi
	@actual_version=$$(shfmt --version | sed 's/^v//'); \
	if [ "$$actual_version" != "$(SHFMT_VERSION)" ]; then \
		echo "shfmt $(SHFMT_VERSION) required; found $$actual_version."; \
		exit 1; \
	fi

verify-tools: verify-shellcheck verify-shfmt

lint: verify-shellcheck
	@echo "Running shellcheck..."
	@shellcheck --severity=warning -e SC2154 $(SHELL_SOURCES)

format-check: verify-shfmt
	@echo "Checking shell formatting..."
	@shfmt -i 4 -ci -bn -d $(SHELL_SOURCES)

format: verify-shfmt
	@echo "Formatting shell scripts..."
	@shfmt -i 4 -ci -bn -w $(SHELL_SOURCES)

qa: lint format-check

test-smoke:
	@echo "Running smoke tests..."
	@bash tests/smoke.sh

test-campaign:
	@echo "Running campaign tests..."
	@python3 -m unittest discover -s tests -p 'test_*.py'

test-integration:
	@echo "Running opt-in real Hashcat integration..."
	@bash tests/integration.sh

test: test-campaign test-smoke

coverage:
	@echo "Running Bash coverage..."
	@bash tests/coverage.sh

coverage-python:
	@echo "Running Python campaign coverage..."
	@python3 tests/python_coverage.py

coverage-check: coverage coverage-python
