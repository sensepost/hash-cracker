# Improvement backlog

This backlog tracks the evidence-backed improvements identified in the
repository review. Items are ordered by priority and dependency. The default
workflow remains local, deterministic, and GPU-optional.

## Completed

- **F1 — Private artifact lifecycle (P2):** new campaign manifests now use a
  private per-campaign workspace; wrapper-created logs, exports, caches,
  processor inputs, manifests, and campaign state receive restrictive creation
  modes; leaf symlink checks and legacy-manifest path compatibility are covered
  by regression tests.
- **F2 — Fail-closed potfile validation (P2):** normal runs now require an
  existing regular, readable, writable potfile and reject invalid paths before
  Hashcat starts; dry-run handling remains non-mutating for a missing potfile.
- **F3 — Runtime contract validation (P2):** wordlist-mode processors now
  reject invalid selections consistently, and self-test validates the Markov
  helper alongside the other job-specific dependencies.

## Planned

- **F4 — Supported macOS portability (P2):** remove GNU-only filesystem
  assumptions and validate the documented Apple Silicon paths on a real target.
- **F5 — Interactive EOF handling (P3):** terminate the menu promptly when stdin
  closes instead of spinning.

## Validate or defer

- **Campaign manifest trust (Px):** decide whether manifests may come from an
  untrusted user or automation before constraining cleanup paths.
- **Bundled-helper coverage boundary (Px):** decide whether PACK helpers need
  separate first-party contract coverage or remain integration-only assets.
- **GPU integration:** run the manual real-Hashcat workflow when a suitable
  self-hosted runner is available.

## Explicitly out of scope unless requirements change

- Intel macOS support.
- Concurrent execution against one campaign manifest.
- Encryption, centralized audit collection, or native-helper provenance work.
