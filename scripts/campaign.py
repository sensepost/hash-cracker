#!/usr/bin/env python3
"""Create and update reproducible hash-cracker campaign manifests."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shlex
import sys
import tempfile
from pathlib import Path


SCHEMA_VERSION = "1"


class CampaignError(Exception):
    """An expected campaign validation or state error."""


def timestamp() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def resolved_path(value: str) -> str:
    return str(Path(value).expanduser().resolve(strict=False))


def file_fingerprint(value: str) -> str:
    path = Path(value)
    if not path.is_file():
        return "missing"

    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_manifest(path: str) -> dict:
    manifest_path = Path(path)
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise CampaignError(f"cannot read manifest {path}: {error}") from error

    if manifest.get("schema_version") != SCHEMA_VERSION:
        raise CampaignError(
            f"unsupported campaign schema: {manifest.get('schema_version', 'missing')}"
        )
    if not isinstance(manifest.get("steps"), list) or not manifest["steps"]:
        raise CampaignError("campaign manifest has no steps")
    return manifest


def write_manifest(path: str, manifest: dict) -> None:
    destination = Path(path).expanduser()
    destination.parent.mkdir(parents=True, exist_ok=True)
    manifest["updated_at"] = timestamp()

    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=destination.parent,
            prefix=f".{destination.name}.",
            suffix=".tmp",
            delete=False,
        ) as stream:
            temporary_path = Path(stream.name)
            json.dump(manifest, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_path, destination)
    finally:
        if temporary_path and temporary_path.exists():
            temporary_path.unlink()


def read_steps(path: str) -> list[dict]:
    steps = []
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        if not raw_line.strip():
            continue
        fields = raw_line.split("\t")
        if len(fields) != 4:
            raise CampaignError(f"invalid campaign step record: {raw_line}")
        step_id, job, name, processor = fields
        steps.append(
            {
                "id": step_id,
                "job": int(job),
                "name": name,
                "processor": processor,
                "commands": [],
                "executed_commands": [],
                "state": "pending",
                "attempts": 0,
                "exit_code": None,
                "started_at": None,
                "finished_at": None,
                "duration_seconds": None,
            }
        )
    if not steps:
        raise CampaignError("campaign plan contains no steps")
    return steps


def read_commands(path: str) -> dict[str, list[dict]]:
    commands: dict[str, list[dict]] = {}
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        if not raw_line.strip():
            continue
        try:
            step_id, preview = raw_line.split("\t", 1)
        except ValueError as error:
            raise CampaignError(f"invalid campaign command record: {raw_line}") from error
        try:
            argv = shlex.split(preview)
        except ValueError:
            argv = [preview]
        commands.setdefault(step_id, []).append(
            {"preview": preview, "argv": argv}
        )
    return commands


def input_metadata(args: argparse.Namespace) -> dict:
    paths = {
        "config": args.config,
        "hashlist": args.hashlist,
        "wordlist": args.wordlist,
        "wordlist2": args.wordlist2,
    }
    metadata = {
        name: {"path": resolved_path(path), "sha256": file_fingerprint(path)}
        for name, path in paths.items()
    }
    metadata["potfile"] = {"path": resolved_path(args.potfile), "mutable": True}
    return metadata


def runtime_metadata(args: argparse.Namespace) -> dict:
    return {
        "hashcat": args.hashcat,
        "hashtype": args.hashtype,
        "machine": args.machine,
        "kernel": args.kernel,
        "loopback": args.loopback,
        "hwmon": args.hwmon,
        "showcracked": args.showcracked,
    }


def create_manifest(args: argparse.Namespace) -> None:
    steps = read_steps(args.steps_file)
    commands = read_commands(args.commands_file)
    for step in steps:
        step["commands"] = commands.get(step["id"], [])

    manifest = {
        "schema_version": SCHEMA_VERSION,
        "release": args.release,
        "created_at": timestamp(),
        "updated_at": timestamp(),
        "status": "planned",
        "campaign": {
            "name": args.name,
            "kind": args.kind,
            "jobs": [step["job"] for step in steps],
        },
        "inputs": input_metadata(args),
        "runtime": runtime_metadata(args),
        "steps": steps,
    }
    write_manifest(args.output, manifest)
    print(f"Campaign plan written to {args.output}")
    print(f"Campaign: {args.name} | steps: {len(steps)} | status: planned")


def validate_manifest(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    current_paths = {
        "config": args.config,
        "hashlist": args.hashlist,
        "wordlist": args.wordlist,
        "wordlist2": args.wordlist2,
    }
    for name, current_path in current_paths.items():
        expected = manifest["inputs"].get(name, {})
        current_resolved = resolved_path(current_path)
        if expected.get("path") != current_resolved:
            raise CampaignError(
                f"campaign input path changed for {name}: "
                f"expected {expected.get('path')}, got {current_resolved}"
            )
        current_digest = file_fingerprint(current_path)
        if expected.get("sha256") != current_digest:
            raise CampaignError(
                f"campaign input changed for {name}: {current_resolved}"
            )
    expected_runtime = manifest.get("runtime", {})
    for name, current_value in runtime_metadata(args).items():
        if expected_runtime.get(name) != current_value:
            raise CampaignError(
                f"campaign runtime changed for {name}: "
                f"expected {expected_runtime.get(name)!r}, got {current_value!r}"
            )
    print(f"Campaign validated: {args.manifest}")


def next_step(args: argparse.Namespace) -> int:
    manifest = load_manifest(args.manifest)
    for index, step in enumerate(manifest["steps"]):
        if step.get("state") != "completed":
            print(f"{index}|{step['id']}|{step['job']}|{step['name']}")
            return 0
    return 2


def mark_running(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    try:
        step = manifest["steps"][args.index]
    except (IndexError, TypeError) as error:
        raise CampaignError(f"invalid campaign step index: {args.index}") from error
    if step["id"] != args.step_id:
        raise CampaignError(
            f"campaign step mismatch: expected {step['id']}, got {args.step_id}"
        )
    step["state"] = "running"
    step["attempts"] = int(step.get("attempts", 0)) + 1
    step["started_at"] = timestamp()
    step["finished_at"] = None
    step["exit_code"] = None
    manifest["status"] = "running"
    write_manifest(args.manifest, manifest)


def update_step(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    try:
        step = manifest["steps"][args.index]
    except (IndexError, TypeError) as error:
        raise CampaignError(f"invalid campaign step index: {args.index}") from error
    if step["id"] != args.step_id:
        raise CampaignError(
            f"campaign step mismatch: expected {step['id']}, got {args.step_id}"
        )

    step["state"] = args.state
    step["exit_code"] = args.exit_code
    step["duration_seconds"] = args.duration
    step["finished_at"] = timestamp()
    if args.commands_file and Path(args.commands_file).is_file():
        step["executed_commands"].extend(read_commands(args.commands_file).get(step["id"], []))

    if args.state == "completed":
        manifest["status"] = (
            "completed"
            if all(item.get("state") == "completed" for item in manifest["steps"])
            else "running"
        )
    elif args.state == "interrupted":
        manifest["status"] = "paused"
    else:
        manifest["status"] = "failed"
    write_manifest(args.manifest, manifest)


def parser() -> argparse.ArgumentParser:
    command_parser = argparse.ArgumentParser(
        description="Manage hash-cracker campaign manifests."
    )
    commands = command_parser.add_subparsers(dest="command", required=True)

    create = commands.add_parser("create")
    create.add_argument("--output", required=True)
    create.add_argument("--name", required=True)
    create.add_argument("--kind", required=True)
    create.add_argument("--release", required=True)
    create.add_argument("--steps-file", required=True)
    create.add_argument("--commands-file", required=True)
    create.add_argument("--config", required=True)
    create.add_argument("--hashlist", required=True)
    create.add_argument("--potfile", required=True)
    create.add_argument("--wordlist", required=True)
    create.add_argument("--wordlist2", required=True)
    create.add_argument("--hashcat", required=True)
    create.add_argument("--hashtype", required=True)
    create.add_argument("--machine", required=True)
    create.add_argument("--kernel", required=True)
    create.add_argument("--loopback", required=True)
    create.add_argument("--hwmon", required=True)
    create.add_argument("--showcracked", required=True)
    create.set_defaults(handler=create_manifest)

    validate = commands.add_parser("validate")
    validate.add_argument("--manifest", required=True)
    validate.add_argument("--config", required=True)
    validate.add_argument("--hashlist", required=True)
    validate.add_argument("--wordlist", required=True)
    validate.add_argument("--wordlist2", required=True)
    validate.add_argument("--hashcat", required=True)
    validate.add_argument("--hashtype", required=True)
    validate.add_argument("--machine", required=True)
    validate.add_argument("--kernel", required=True)
    validate.add_argument("--loopback", required=True)
    validate.add_argument("--hwmon", required=True)
    validate.add_argument("--showcracked", required=True)
    validate.set_defaults(handler=validate_manifest)

    next_command = commands.add_parser("next")
    next_command.add_argument("--manifest", required=True)
    next_command.set_defaults(handler=next_step)

    running = commands.add_parser("mark-running")
    running.add_argument("--manifest", required=True)
    running.add_argument("--index", type=int, required=True)
    running.add_argument("--step-id", required=True)
    running.set_defaults(handler=mark_running)

    update = commands.add_parser("update")
    update.add_argument("--manifest", required=True)
    update.add_argument("--index", type=int, required=True)
    update.add_argument("--step-id", required=True)
    update.add_argument(
        "--state", choices=("completed", "failed", "interrupted"), required=True
    )
    update.add_argument("--exit-code", type=int, required=True)
    update.add_argument("--duration", type=int, required=True)
    update.add_argument("--commands-file")
    update.set_defaults(handler=update_step)

    return command_parser


def main() -> int:
    args = parser().parse_args()
    try:
        result = args.handler(args)
    except (CampaignError, OSError, ValueError) as error:
        print(f"campaign: {error}", file=sys.stderr)
        return 1
    return result if isinstance(result, int) else 0


if __name__ == "__main__":
    raise SystemExit(main())
