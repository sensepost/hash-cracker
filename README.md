# hash-cracker

Simple Bash wrapper around `hashcat` for running a curated set of cracking workflows from an interactive menu. Background and usage philosophy are covered in [this blog post](https://sensepost.com/blog/2023/hash-cracker-password-cracking-done-effectively/).

Useful wordlist sources:

- <https://weakpass.com/>
- <https://hashmob.net/>

If `hashcat` outputs values as `$HEX[...]`, see [hex-to-readable](https://github.com/crypt0rr/hex-to-readable) or use [CyberChef](https://cyberchef.offsec.nl/).

## Installation

```bash
git clone https://github.com/crypt0rr/hash-cracker
cd hash-cracker
chmod +x hash-cracker.sh
```

## Requirements

### Mandatory

- `hashcat` must be installed and executable
- `hash-cracker.conf` must exist in the repository root

At startup, `hash-cracker` checks that:

- `HASHCAT` points to an executable `hashcat` binary
- `POTFILE` exists, or can be created
- the required config keys are set in `hash-cracker.conf`

### Optional Dependencies

These are only needed for specific menu options.

#### Linux

- `python3`
  - Needed for option `12` (PACK rulegen) and option `13` (PACK mask)
  - Option `12` requires `pyenchant`:
  - `python3 -m pip install pyenchant==3.3.0`
- `cewl`
  - Needed for option `18`
- `scripts/extensions/common-substr-linux`
  - Needed for options `10` and `11`
- `scripts/extensions/hashcat-utils-linux/bin/expander.bin`
  - Needed for option `14`

#### macOS

- `cewl` command in PATH, or `scripts/extensions/cewl/cewl.rb`
  - Needed for option `18`
- `scripts/extensions/common-substr-mac`
  - Needed for options `10` and `11`
- `scripts/extensions/hashcat-utils-mac/bin/expander.bin`
  - Needed for option `14`
- `python3`
  - Used by option `13` (PACK mask)

Notes:

- Option `12` is currently unavailable on macOS.
- Option `13` uses the bundled PACK scripts and generates masks from the existing potfile.

## Configuration

`hash-cracker.conf` is required and is loaded automatically on every start.

The file must live in the repository root and define these settings:

- `HASHCAT` - path to the `hashcat` binary
- `DEVICE` - value passed to `hashcat -d`
- `HASHTYPE` - hash mode, for example `1000` for NTLM
- `HASHLIST` - file containing target hashes
- `POTFILE` - potfile path to use or create
- `WORDLIST` - primary wordlist path
- `WORDLIST2` - secondary wordlist path used by combinator-style workflows

Current example:

```bash
# Hashcat path
HASHCAT=(/usr/local/bin/hashcat)

# Device to Use (hashcat -d $DEVICE)
DEVICE=1

# Hashtype
HASHTYPE=1000

# File containing target hashes
HASHLIST=input

# Potfile you want to use
POTFILE=hash-cracker.pot

# Wordlist(s)
WORDLIST=wordlists/ignis-1M.txt
WORDLIST2=wordlists/ignis-1K.txt
```

## Usage

Run from the repository root:

```bash
./hash-cracker.sh
```

With flags:

```bash
./hash-cracker.sh [FLAG]
```

Help:

```bash
./hash-cracker.sh --help
```

Show module descriptions:

```bash
./hash-cracker.sh --module-info
```

Search the local hash type list:

```bash
./hash-cracker.sh --search ntlm
```

Run in dry-run mode:

```bash
./hash-cracker.sh --dry-run
```

List available jobs and exit:

```bash
./hash-cracker.sh --list-jobs
```

Run one job non-interactively:

```bash
./hash-cracker.sh --job 8
```

Run with session logging disabled:

```bash
./hash-cracker.sh --no-session-log
```

Export stats JSON to a file:

```bash
./hash-cracker.sh --stats-export /tmp/hash-cracker-stats.json
```

Export stats JSON with full log history:

```bash
./hash-cracker.sh --stats-export /tmp/hash-cracker-stats.json --stats-export-scope all
```

Run non-interactive health checks:

```bash
./hash-cracker.sh --self-test
```

## Flags

By default, `hash-cracker` enables optimized kernels, enables loopback, disables hardware monitoring, and shows cracked hashes on stdout.

- `-l`, `--no-loopback` - disable loopback functionality
- `-n`, `--no-limit` - disable optimized kernels
- `--hwmon-enable` - enable hardware monitoring
- `-m`, `--module-info` - print descriptions of the available modules and exit
- `-s [hash-name]`, `--search [hash-name]` - search the local hash type database and exit
- `-d`, `--disable-cracked` - suppress cracked hashes on stdout by writing them to `/dev/null`
- `--dry-run` - print the resolved hashcat commands without executing them; preprocessor file/tool actions are reported and skipped
- `--no-session-log` - disable session stats logging to file
- `--session-log-keep [N]`, `--session-log-keep=N` - keep last `N` auto-created session logs in `logs/` (default: `0`, no pruning)
- `--stats-debug` - print whether stats refresh used incremental update or full recount
- `--stats-export [PATH]`, `--stats-export=PATH` - export machine-readable session stats JSON to `PATH`
- `--stats-export-scope [latest|all]`, `--stats-export-scope=...` - export latest snapshot only (`latest`, default) or include all parsed entries from `logs/session-*.log` (`all`)
- `--job [ID]`, `--job=ID` - run one menu option non-interactively and exit (supports `1-22` and `99`)
- `--list-jobs` - print available job IDs and exit
- `--self-test`, `--doctor` - run non-interactive configuration and dependency checks, then exit with status code

## Menu Options

When the tool starts successfully, it opens an interactive menu with these options:

1. Brute force
2. Light rules
3. Heavy rules
4. Enter specific word/name/company
5. Enter specific word/name/company (brute force)
6. Hybrid
7. Toggle-case
8. Combinator
9. Iterate results
10. Prefix suffix
11. Common substring
12. PACK rulegen
13. PACK mask
14. Fingerprint attack
15. Directory of word lists plain and then with `OneRuleToRuleThemAll`
16. Username iteration (only complete NTDS)
17. Markov-chain passwords generator
18. CeWL wordlist generator
19. Digit remover
20. Stacker
21. Custom brute force
22. Directory of word lists plain and then with `buka_400k`
99. Session stats dashboard

## Module Notes

- Options `2`, `3`, `6`, `7`, and `20` ask whether to use a single wordlist or multiple wordlists.
- Option `8` uses `WORDLIST` and `WORDLIST2` from the config file.
- Options `15` and `22` accept either a directory of wordlists or a single wordlist file.
- Options `4` and `5` prompt for a custom word or company name.
- Option `16` expects an NTDS-style input file and extracts usernames from `HASHLIST`.
- Option `17` can generate candidates from either the potfile or a selected wordlist.
- Option `18` prompts for a URL, output wordlist name, spider depth, and minimum word length.
- Option `21` prompts for brute-force length and whether increment mode should be enabled.
- `--job` mode runs selected options directly without entering the interactive menu.
- In non-interactive contexts, prompt-dependent jobs (for example `4`, `5`, `8`, `15`, `17`, `18`, `21`, `22`) fail fast with a clear message.

## Runtime Status Output

- At startup, before initial counters are built, the tool prints:
  - `Preparing session stats (counting potfile and input hashes)...`
- After a job, if the potfile changed and unique plaintext recount is needed, the tool prints:
  - `Refreshing session stats (recounting unique potfile plaintexts, this may take a moment)...`
- Option `99` prints a dedicated ASCII dashboard with:
  - session delta (`new ... lines`, `... unique`, `... bytes`)
  - total cracked passwords in potfile (`... lines`)
  - unique input hashes from the active `HASHLIST`
  - log status/retention/current log file
- Session stats are written to a timestamped log file:
  - Default per-session file: `logs/session-YYYYmmdd-HHMMSS-PID.log`
  - Convenience pointer: `logs/latest.log` points to the current session file
  - Retention for auto-created logs defaults to `0` (no pruning)
  - Set `--session-log-keep [N]` to tune retention
  - Override path with `SESSION_STATS_LOGFILE`
  - Set `--no-session-log` to disable file logging
- With `--stats-debug`, the tool prints which refresh path was used (`incremental` or `full recount`).
- With `--stats-export`, current stats are written as JSON on each refresh cycle.
- Exported JSON includes a top-level `"schema_version"` for stable downstream parsing.
- With `--stats-export-scope latest` (default), JSON contains the latest snapshot only.
- With `--stats-export-scope all`, JSON also includes parsed history from `logs/session-*.log`.

## Example Hashes

Sample hashes are provided in `example-hashes/`:

- MD5 (`-m 0`)
- SHA1 (`-m 100`)
- NTLM (`-m 1000`)

For large public datasets, see [Have I Been Pwned Passwords](https://haveibeenpwned.com/Passwords).

## Version Log

See [VERSION.md](VERSION.md).

## Maintainer Quality Checks

These checks are maintainer-only and are not required for end users running `hash-cracker`.

```bash
make lint
make format-check
make format
make qa
make test-smoke
```

- `make lint` runs `shellcheck` on project shell scripts.
- `make format-check` verifies formatting with `shfmt`.
- `make format` applies `shfmt` formatting changes.
- `make test-smoke` runs non-interactive menu and dry-run smoke checks.
- CI runs `make lint`, `make format-check`, and `make test-smoke` automatically on push and pull request.

## License

GNU GPLv3
