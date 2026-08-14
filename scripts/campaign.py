#!/usr/bin/env python3
"""Create and update reproducible hash-cracker campaign manifests."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shlex
import shutil
import sys
import tempfile
from pathlib import Path


SCHEMA_VERSION = "2"
LEGACY_SCHEMA_VERSION = "1"


class CampaignError(Exception):
    """An expected campaign validation or state error."""


def timestamp() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def resolved_path(value: str) -> str:
    return str(Path(value).expanduser().resolve(strict=False))


def ensure_private_directory(path: Path) -> None:
    """Create or tighten a directory used for private campaign state."""
    if path.is_symlink():
        raise CampaignError(f"private campaign directory is a symlink: {path}")
    try:
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        if path.is_symlink() or not path.is_dir():
            raise CampaignError(f"private campaign path is not a directory: {path}")
        if path.stat().st_uid != os.geteuid():
            raise CampaignError(f"private campaign directory is not user-owned: {path}")
        path.chmod(0o700)
    except OSError as error:
        raise CampaignError(
            f"unable to secure private campaign directory {path}: {error}"
        ) from error


def resolved_executable(value: str) -> str:
    candidate = value
    if os.sep not in value:
        candidate = shutil.which(value) or value
    return resolved_path(candidate)


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

    if not isinstance(manifest, dict):
        raise CampaignError("campaign manifest must contain a JSON object")
    if manifest.get("schema_version") not in (LEGACY_SCHEMA_VERSION, SCHEMA_VERSION):
        raise CampaignError(
            f"unsupported campaign schema: {manifest.get('schema_version', 'missing')}"
        )
    if not isinstance(manifest.get("steps"), list) or not manifest["steps"]:
        raise CampaignError("campaign manifest has no steps")
    campaign = manifest.setdefault("campaign", {})
    if not isinstance(campaign, dict):
        raise CampaignError("campaign manifest has invalid campaign metadata")
    campaign.setdefault(
        "session_prefix",
        f"hc-{hashlib.sha256(resolved_path(path).encode()).hexdigest()[:12]}",
    )
    for step in manifest["steps"]:
        if not isinstance(step, dict):
            raise CampaignError("campaign manifest contains an invalid step")
        for field in ("id", "job", "name"):
            if field not in step:
                raise CampaignError(f"campaign step is missing '{field}'")
        step.setdefault("commands", [])
        step.setdefault("current_command", None)
        if not isinstance(step["commands"], list):
            raise CampaignError(f"campaign step has invalid commands: {step['id']}")
        for command in step["commands"]:
            if not isinstance(command, dict):
                raise CampaignError(
                    f"campaign step has an invalid command: {step['id']}"
                )
            command.setdefault("state", "pending")
            command.setdefault("session", None)
            command.setdefault("restore_file", None)
            command.setdefault("attempts", 0)
            command.setdefault("exit_code", None)
            command.setdefault("started_at", None)
            command.setdefault("finished_at", None)
            command.setdefault("duration_seconds", None)
            command.setdefault("executed_preview", None)
            command.setdefault("executed_argv", None)
            command.setdefault("preserved_inputs", [])
    return manifest


def write_manifest(path: str, manifest: dict) -> None:
    destination = Path(path).expanduser()
    destination.parent.mkdir(parents=True, exist_ok=True)
    manifest["schema_version"] = SCHEMA_VERSION
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
        destination.chmod(0o600)
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


def command_record(preview: str, argv: list[str] | None = None) -> dict:
    if argv is None:
        try:
            argv = shlex.split(preview)
        except ValueError as error:
            raise CampaignError(f"invalid campaign command preview: {error}") from error
    return {
        "preview": preview,
        "argv": list(argv),
        "state": "pending",
        "session": None,
        "restore_file": None,
        "attempts": 0,
        "exit_code": None,
        "started_at": None,
        "finished_at": None,
        "duration_seconds": None,
        "executed_preview": None,
        "executed_argv": None,
        "preserved_inputs": [],
    }


def read_commands(path: str) -> dict[str, list[dict]]:
    commands: dict[str, list[dict]] = {}
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        if not raw_line.strip():
            continue
        if raw_line.lstrip().startswith("{"):
            try:
                record = json.loads(raw_line)
                step_id = record["step_id"]
                preview = record["preview"]
                argv = record["argv"]
            except (KeyError, TypeError, json.JSONDecodeError) as error:
                raise CampaignError(
                    f"invalid campaign command record: {raw_line}"
                ) from error
            if not isinstance(step_id, str) or not isinstance(preview, str):
                raise CampaignError(f"invalid campaign command record: {raw_line}")
            if not isinstance(argv, list) or not all(
                isinstance(value, str) for value in argv
            ):
                raise CampaignError(f"invalid campaign command arguments: {raw_line}")
            commands.setdefault(step_id, []).append(command_record(preview, argv))
            continue
        try:
            step_id, preview = raw_line.split("\t", 1)
        except ValueError as error:
            raise CampaignError(f"invalid campaign command record: {raw_line}") from error
        commands.setdefault(step_id, []).append(command_record(preview))
    return commands


def input_metadata(args: argparse.Namespace) -> dict:
    paths = {
        "config": args.config,
        "hashlist": args.hashlist,
        "wordlist": args.wordlist,
        "wordlist2": args.wordlist2,
    }
    for name, path in paths.items():
        if not Path(path).is_file():
            raise CampaignError(f"campaign input missing for {name}: {resolved_path(path)}")
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


def artifact_metadata(paths: list[str]) -> list[dict[str, str]]:
    artifacts = []
    seen = set()
    for value in paths:
        if not value:
            continue
        path = resolved_executable(value)
        if path in seen:
            continue
        seen.add(path)
        artifacts.append({"path": path, "sha256": file_fingerprint(path)})
    return artifacts


def validate_output_path(args: argparse.Namespace, artifacts: list[dict[str, str]]) -> None:
    output = resolved_path(args.output)
    protected = [args.config, args.hashlist, args.wordlist, args.wordlist2, args.potfile]
    protected.extend(item["path"] for item in artifacts)
    for path in protected:
        if output == resolved_path(path):
            raise CampaignError(
                f"campaign output conflicts with protected path: {output}"
            )


def create_manifest(args: argparse.Namespace) -> None:
    steps = read_steps(args.steps_file)
    commands = read_commands(args.commands_file)
    step_ids = {step["id"] for step in steps}
    unknown_commands = set(commands) - step_ids
    if unknown_commands:
        raise CampaignError(
            f"campaign commands contain unknown steps: {', '.join(sorted(unknown_commands))}"
        )
    for step in steps:
        step["commands"] = commands.get(step["id"], [])
        if not step["commands"]:
            raise CampaignError(f"campaign step has no recorded commands: {step['id']}")

    artifacts = artifact_metadata(getattr(args, "artifact", []))
    validate_output_path(args, artifacts)

    workspace = getattr(args, "workspace", None)
    if workspace:
        ensure_private_directory(Path(workspace))

    campaign_metadata = {
        "name": args.name,
        "kind": args.kind,
        "jobs": [step["job"] for step in steps],
        "session_prefix": (
            f"hc-{hashlib.sha256(resolved_path(args.output).encode()).hexdigest()[:12]}"
        ),
    }
    if workspace:
        campaign_metadata["workspace"] = resolved_path(workspace)

    manifest = {
        "schema_version": SCHEMA_VERSION,
        "release": args.release,
        "created_at": timestamp(),
        "updated_at": timestamp(),
        "status": "planned",
        "campaign": campaign_metadata,
        "inputs": input_metadata(args),
        "runtime": runtime_metadata(args),
        "artifacts": artifacts,
        "steps": steps,
    }
    write_manifest(args.output, manifest)
    print(f"Campaign plan written to {args.output}")
    print(f"Campaign: {args.name} | steps: {len(steps)} | status: planned")


def print_workspace(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    workspace = manifest.get("campaign", {}).get("workspace")
    if workspace is None:
        return
    if not isinstance(workspace, str) or not workspace:
        raise CampaignError("campaign manifest has an invalid artifact workspace")
    print(workspace)


def validate_manifest(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    expected_artifacts = manifest.get("artifacts")
    if expected_artifacts is not None:
        if not isinstance(expected_artifacts, list) or not expected_artifacts:
            raise CampaignError("campaign manifest has invalid artifact fingerprints")
        if any(
            not isinstance(artifact, dict)
            or not isinstance(artifact.get("path"), str)
            or not isinstance(artifact.get("sha256"), str)
            for artifact in expected_artifacts
        ):
            raise CampaignError("campaign manifest has invalid artifact fingerprints")
        current_artifacts = artifact_metadata(getattr(args, "artifact", []))
        expected_by_path = {
            artifact.get("path"): artifact for artifact in expected_artifacts
        }
        current_by_path = {artifact["path"]: artifact for artifact in current_artifacts}
        if set(expected_by_path) != set(current_by_path):
            raise CampaignError("campaign artifact set changed; create a new plan")
        for path, expected in expected_by_path.items():
            if expected.get("sha256") != current_by_path[path].get("sha256"):
                raise CampaignError(f"campaign artifact changed: {path}")

    current_paths = {
        "config": args.config,
        "hashlist": args.hashlist,
        "wordlist": args.wordlist,
        "wordlist2": args.wordlist2,
    }
    for name, current_path in current_paths.items():
        if not Path(current_path).is_file():
            raise CampaignError(
                f"campaign input missing for {name}: {resolved_path(current_path)}"
            )
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
        if step.get("state") != "completed" or any(
            command.get("state") != "completed" for command in step["commands"]
        ):
            print(f"{index}|{step['id']}|{step['job']}|{step['name']}")
            return 0
    return 2


def get_step(manifest: dict, index: int, step_id: str) -> dict:
    try:
        step = manifest["steps"][index]
    except (IndexError, TypeError) as error:
        raise CampaignError(f"invalid campaign step index: {index}") from error
    if step["id"] != step_id:
        raise CampaignError(
            f"campaign step mismatch: expected {step['id']}, got {step_id}"
        )
    return step


def mark_running(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    step = get_step(manifest, args.index, args.step_id)
    step["state"] = "running"
    step["attempts"] = int(step.get("attempts", 0)) + 1
    step["started_at"] = timestamp()
    step["finished_at"] = None
    step["exit_code"] = None
    manifest["status"] = "running"
    write_manifest(args.manifest, manifest)


def campaign_state_dir(manifest_path: str) -> Path:
    return Path(f"{Path(manifest_path).expanduser().resolve(strict=False)}.state")


def command_start(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    step = get_step(manifest, args.index, args.step_id)
    state_dir = campaign_state_dir(args.manifest)
    ensure_private_directory(state_dir)
    try:
        command = step["commands"][args.command_index]
    except (IndexError, TypeError) as error:
        raise CampaignError(
            f"invalid campaign command index: {args.command_index}"
        ) from error

    for previous in step["commands"][: args.command_index]:
        if previous.get("state") not in ("completed", "failed"):
            raise CampaignError(
                f"campaign command order is blocked before index {args.command_index}"
            )

    if command.get("state") == "completed":
        print("completed\t\t\t0\t")
        return

    was_running = command.get("state") == "running" and bool(
        command.get("session")
    )
    if not was_running:
        if command.get("restore_file"):
            Path(command["restore_file"]).unlink(missing_ok=True)
        if command.get("session"):
            Path(
                campaign_state_dir(args.manifest) / f"{command['session']}.argv"
            ).unlink(missing_ok=True)
        for preserved in command.get("preserved_inputs", []):
            Path(preserved).unlink(missing_ok=True)
        command["preserved_inputs"] = []
        command["attempts"] = int(command.get("attempts", 0)) + 1
        command["session"] = (
            f"{manifest['campaign']['session_prefix']}-"
            f"{step['id']}-cmd-{args.command_index:03d}-attempt-"
            f"{command['attempts']:02d}"
        )
        command["restore_file"] = str(
            campaign_state_dir(args.manifest) / f"{command['session']}.restore"
        )
        command["state"] = "running"
        command["started_at"] = timestamp()
        command["finished_at"] = None
        command["exit_code"] = None
        command["duration_seconds"] = None

    restore_file = command.get("restore_file") or ""
    restore = int(was_running and bool(restore_file) and Path(restore_file).is_file())
    argv_file = ""
    if was_running and command.get("executed_argv"):
        argv_file = str(state_dir / f"{command['session']}.argv")
        with Path(argv_file).open("wb") as stream:
            for argument in command["executed_argv"]:
                stream.write(argument.encode() + b"\0")
        Path(argv_file).chmod(0o600)
    step["current_command"] = args.command_index
    manifest["status"] = "running"
    write_manifest(args.manifest, manifest)
    print(f"running\t{command['session']}\t{restore_file}\t{restore}\t{argv_file}")


def record_command(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    step = get_step(manifest, args.index, args.step_id)
    try:
        command = step["commands"][args.command_index]
    except (IndexError, TypeError) as error:
        raise CampaignError(
            f"invalid campaign command index: {args.command_index}"
        ) from error
    if getattr(args, "argv_file", None):
        try:
            raw_args = Path(args.argv_file).read_bytes()
            if raw_args and not raw_args.endswith(b"\0"):
                raise CampaignError("campaign command argument record is not NUL terminated")
            argv = [value.decode("utf-8") for value in raw_args.split(b"\0")[:-1]]
        except (OSError, UnicodeDecodeError) as error:
            raise CampaignError(f"invalid campaign command arguments: {error}") from error
    else:
        try:
            argv = shlex.split(args.preview)
        except ValueError as error:
            raise CampaignError(f"invalid campaign command preview: {error}") from error
    if not argv:
        raise CampaignError("campaign command preview is empty")
    planned_argv = command.get("argv") or []
    stable_planned_argv = [
        value
        for value in planned_argv
        if value != "--restore"
        and not value.startswith("--session=")
        and not value.startswith("--restore-file-path=")
    ]
    stable_executed_argv = [
        value
        for value in argv
        if value != "--restore"
        and not value.startswith("--session=")
        and not value.startswith("--restore-file-path=")
    ]
    if stable_executed_argv != stable_planned_argv:
        raise CampaignError(
            f"campaign command changed at step {args.step_id}, command {args.command_index}; "
            "create a new plan"
        )
    command["executed_preview"] = args.preview
    command["executed_argv"] = argv
    write_manifest(args.manifest, manifest)


def preserve_command_inputs(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    step = get_step(manifest, args.index, args.step_id)
    try:
        command = step["commands"][args.command_index]
    except (IndexError, TypeError) as error:
        raise CampaignError(
            f"invalid campaign command index: {args.command_index}"
        ) from error
    preserved = command.setdefault("preserved_inputs", [])
    for value in args.path:
        if Path(value).is_file() and value not in preserved:
            preserved.append(value)
    write_manifest(args.manifest, manifest)


def command_finish(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    step = get_step(manifest, args.index, args.step_id)
    state_dir = campaign_state_dir(args.manifest)
    ensure_private_directory(state_dir)
    try:
        command = step["commands"][args.command_index]
    except (IndexError, TypeError) as error:
        raise CampaignError(
            f"invalid campaign command index: {args.command_index}"
        ) from error
    if command.get("state") == "completed":
        return
    command["state"] = args.state
    command["exit_code"] = args.exit_code
    command["duration_seconds"] = args.duration
    command["finished_at"] = timestamp()
    if args.state == "completed" and command.get("restore_file"):
        Path(command["restore_file"]).unlink(missing_ok=True)
    if args.state == "completed" and command.get("session"):
        Path(state_dir / f"{command['session']}.argv").unlink(missing_ok=True)
    if args.state == "completed":
        for preserved in command.get("preserved_inputs", []):
            Path(preserved).unlink(missing_ok=True)
        command["preserved_inputs"] = []
    if args.state == "completed":
        step["current_command"] = None
    write_manifest(args.manifest, manifest)


def update_step(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    step = get_step(manifest, args.index, args.step_id)

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
    create.add_argument("--workspace")
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
    create.add_argument("--artifact", action="append", default=[])
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
    validate.add_argument("--artifact", action="append", default=[])
    validate.set_defaults(handler=validate_manifest)

    workspace = commands.add_parser("workspace")
    workspace.add_argument("--manifest", required=True)
    workspace.set_defaults(handler=print_workspace)

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

    command_start_parser = commands.add_parser("command-start")
    command_start_parser.add_argument("--manifest", required=True)
    command_start_parser.add_argument("--index", type=int, required=True)
    command_start_parser.add_argument("--step-id", required=True)
    command_start_parser.add_argument("--command-index", type=int, required=True)
    command_start_parser.set_defaults(handler=command_start)

    command_finish_parser = commands.add_parser("command-finish")
    command_finish_parser.add_argument("--manifest", required=True)
    command_finish_parser.add_argument("--index", type=int, required=True)
    command_finish_parser.add_argument("--step-id", required=True)
    command_finish_parser.add_argument("--command-index", type=int, required=True)
    command_finish_parser.add_argument(
        "--state", choices=("completed", "failed"), required=True
    )
    command_finish_parser.add_argument("--exit-code", type=int, required=True)
    command_finish_parser.add_argument("--duration", type=int, required=True)
    command_finish_parser.set_defaults(handler=command_finish)

    command_record_parser = commands.add_parser("command-record")
    command_record_parser.add_argument("--manifest", required=True)
    command_record_parser.add_argument("--index", type=int, required=True)
    command_record_parser.add_argument("--step-id", required=True)
    command_record_parser.add_argument("--command-index", type=int, required=True)
    command_record_parser.add_argument("--preview", required=True)
    command_record_parser.add_argument("--argv-file")
    command_record_parser.set_defaults(handler=record_command)

    command_preserve_parser = commands.add_parser("command-preserve")
    command_preserve_parser.add_argument("--manifest", required=True)
    command_preserve_parser.add_argument("--index", type=int, required=True)
    command_preserve_parser.add_argument("--step-id", required=True)
    command_preserve_parser.add_argument("--command-index", type=int, required=True)
    command_preserve_parser.add_argument("--path", action="append", required=True)
    command_preserve_parser.set_defaults(handler=preserve_command_inputs)

    return command_parser


def main() -> int:
    args = parser().parse_args()
    try:
        result = args.handler(args)
    except (
        CampaignError,
        OSError,
        UnicodeError,
        ValueError,
        KeyError,
        TypeError,
        AttributeError,
    ) as error:
        print(f"campaign: {error}", file=sys.stderr)
        return 1
    return result if isinstance(result, int) else 0


if __name__ == "__main__":
    raise SystemExit(main())
