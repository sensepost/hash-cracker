SHELL_SOURCES := $(shell find . -type f -name '*.sh' ! -path './.git/*' ! -path './coverage/*' ! -path './scripts/extensions/*' | sort)

.PHONY: lint format-check format qa test test-smoke test-campaign coverage coverage-check

lint:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not found. Install it locally to run maintainer lint checks."; \
		exit 1; \
	fi
	@echo "Running shellcheck..."
	@shellcheck --severity=warning -e SC2154 $(SHELL_SOURCES)

format-check:
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt not found. Install it locally to run maintainer format checks."; \
		exit 1; \
	fi
	@echo "Checking shell formatting..."
	@shfmt -i 4 -ci -bn -d $(SHELL_SOURCES)

format:
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt not found. Install it locally to apply maintainer formatting."; \
		exit 1; \
	fi
	@echo "Formatting shell scripts..."
	@shfmt -i 4 -ci -bn -w $(SHELL_SOURCES)

qa: lint format-check

test-smoke:
	@echo "Running smoke tests..."
	@bash tests/smoke.sh

test-campaign:
	@echo "Running campaign tests..."
	@python3 -m unittest discover -s tests -p 'test_*.py'

test: test-campaign test-smoke

coverage:
	@echo "Running Bash coverage..."
	@bash tests/coverage.sh

coverage-check: coverage
