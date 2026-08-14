# Audit artifacts

This document defines the operational meaning and handling expectations for the
session logs and JSON statistics exports produced by `hash-cracker`.

These files are local audit artifacts. They are useful for reconstructing what
the CLI reported during a run, but they are not a compliance record and are not
tamper-evident, signed, encrypted, or centrally collected by the tool.

## Artifact lifecycle

### Session logs

Unless logging is disabled or an explicit path is configured, each invocation
creates one file under `logs/`:

```text
logs/session-YYYYmmdd-HHMMSS-PID.log
```

The CLI appends timestamped session-stat lines to the active file. For an
auto-created log, `logs/latest.log` is a convenience symlink to that file. The
symlink is not a second copy of the evidence and is not included when an
`all`-scope JSON export reads the `session-*.log` history.

Retention applies only to auto-created `session-*.log` files:

- The default `--session-log-keep 0` keeps all auto-created logs.
- `--session-log-keep N` keeps the most recent `N` auto-created logs when a new
  session starts.
- An explicit `SESSION_STATS_LOGFILE` is not pruned by this setting.
- `--no-session-log` disables file logging. The dashboard still reports that
  logging is disabled, and JSON exports record `logging.enabled` as `false`.

If the CLI cannot create, link, or append a session log, it reports the problem
as a warning and continues. Treat the resulting run as having incomplete audit
evidence; a successful cracking command does not prove that a complete log was
written.

Files created by the CLI use a restrictive process umask. The default `logs/`
directory is created with mode `0700`, and newly created session logs are
created with mode `0600`. An explicitly configured log directory is not
re-permissioned, but files created by the process still receive the restrictive
file mode.

### JSON statistics exports

`--stats-export PATH` writes the current statistics to `PATH` on each refresh
cycle. The export includes the release, hash type, input paths, session delta,
potfile totals, logging state, and an explicit `schema_version` field. The
current schema version is `"1"`.

The default `--stats-export-scope latest` writes the current snapshot and an
empty `history` array. `--stats-export-scope all` additionally parses regular
`session-*.log` files in the configured session-log directory (default
`logs/`), in sorted order, and places their entries in `history`. The parser
preserves ordinary or malformed log lines as message entries so that an export
does not silently discard source text.

Exports are written through a temporary file and replacement step. Failure to
create the parent directory, write the temporary file, or replace the target is
reported as an error and makes the command fail. A partially written JSON file
is not treated as a successful export. Newly created exports receive mode
`0600`.

Campaign manifests created by the current CLI also contain a private artifact
workspace under the manifest state directory. Generated processor inputs and
interrupted-command state are kept there, and legacy manifests without this
metadata continue to use their recorded paths.

## Integrity and limitations

The artifacts are observations made by a local process, not an independent
proof of execution. In particular:

- Anyone who can write the files can alter or delete them; the CLI does not
  generate signatures, checksums, or an append-only store.
- The JSON contains counters and paths, not a copy of the hashlist, potfile,
  Hashcat output, or command transcript.
- A disabled or unavailable session log, process interruption, filesystem
  failure, or later pruning can leave the record incomplete.
- The `all` history is derived from whatever matching log files are present at
  export time. It is not a server-side or immutable event stream.
- The artifacts can reveal local paths, hash types, run metadata, and messages
  imported from session-log files. Handle them as sensitive local data.

The policy assumes the normal single-writer workflow. Concurrent executions
against one campaign manifest are not supported.

## Preservation guidance

If a run needs to be retained for review:

1. Copy the active session log and the relevant JSON export before cleanup or
   retention pruning removes them.
2. Preserve the files in storage with access controls appropriate to the
   hashes, paths, and operational metadata they contain.
3. Record the run context separately when needed, including the configuration
   revision, input-set identity, and Hashcat/tool versions. Do not copy secrets
   from the trusted local configuration into an audit report unnecessarily.
4. Generate and store an external checksum or signature if tamper evidence is
   required by the operating process.
5. Mark the record as incomplete when logging was disabled, unavailable, or an
   export failed. `--session-log-keep` is a convenience cleanup control, not an
   archival or retention policy.

Downstream consumers should inspect `schema_version` and tolerate additional
fields. A future incompatible export shape should use a new schema version.
