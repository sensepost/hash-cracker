#!/usr/bin/env python3
"""Direct contract tests for campaign manifest and command state handling."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN_PATH = REPO_ROOT / "scripts" / "campaign.py"
SPEC = importlib.util.spec_from_file_location("campaign", CAMPAIGN_PATH)
assert SPEC and SPEC.loader
campaign = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(campaign)


class CampaignContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.config = self.root / "hash-cracker.conf"
        self.hashlist = self.root / "hashes"
        self.potfile = self.root / "hash-cracker.pot"
        self.wordlist = self.root / "wordlist.txt"
        self.wordlist2 = self.root / "wordlist2.txt"
        self.hashcat = self.root / "hashcat"
        self.artifact = self.root / "processor.sh"
        for path, content in (
            (self.config, "HASHCAT=hashcat\n"),
            (self.hashlist, "hash:password\n"),
            (self.potfile, ""),
            (self.wordlist, "password\n"),
            (self.wordlist2, "welcome\n"),
            (self.hashcat, "#!/bin/sh\nexit 0\n"),
            (self.artifact, "#!/bin/sh\nexit 0\n"),
        ):
            path.write_text(content, encoding="utf-8")
        self.steps = self.root / "steps"
        self.commands = self.root / "commands"
        self.steps.write_text(
            "step-001\t1\tFixture\tscripts/processors/1-bruteforce.sh\n",
            encoding="utf-8",
        )
        self.commands.write_text(
            f"step-001\t{self.hashcat} --bitmap-max=24 -d 1 "
            f"--potfile-path={self.potfile} -m1000 {self.hashlist}\n",
            encoding="utf-8",
        )
        self.manifest = self.root / "campaign.json"

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def create_args(self, output: Path | None = None) -> argparse.Namespace:
        return argparse.Namespace(
            output=str(output or self.manifest),
            name="fixture",
            kind="job",
            release="test",
            steps_file=str(self.steps),
            commands_file=str(self.commands),
            config=str(self.config),
            hashlist=str(self.hashlist),
            potfile=str(self.potfile),
            wordlist=str(self.wordlist),
            wordlist2=str(self.wordlist2),
            hashcat=str(self.hashcat),
            hashtype="1000",
            machine="Linux",
            kernel=" ",
            loopback=" ",
            hwmon=" ",
            showcracked=" ",
            fingerprint_segment_max="8",
            artifact=[str(self.artifact)],
        )

    def test_manifest_records_artifact_fingerprints(self) -> None:
        args = self.create_args()

        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        artifacts = {item["path"]: item["sha256"] for item in manifest["artifacts"]}
        expected_digest = hashlib.sha256(self.artifact.read_bytes()).hexdigest()
        self.assertEqual(artifacts[str(self.artifact.resolve())], expected_digest)

    def test_manifest_records_rule_artifact_fingerprints(self) -> None:
        rule = self.root / "rules" / "fixture.rule"
        rule.parent.mkdir()
        rule.write_text("$1\n", encoding="utf-8")
        args = self.create_args()
        args.artifact.append(str(rule))

        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        artifacts = {item["path"]: item["sha256"] for item in manifest["artifacts"]}
        self.assertEqual(artifacts[str(rule.resolve())], campaign.file_fingerprint(str(rule)))

    def test_validation_rejects_changed_rule_artifact(self) -> None:
        rule = self.root / "rules" / "fixture.rule"
        rule.parent.mkdir()
        rule.write_text("$1\n", encoding="utf-8")
        args = self.create_args()
        args.artifact.append(str(rule))
        campaign.create_manifest(args)

        rule.write_text("$2\n", encoding="utf-8")
        with self.assertRaisesRegex(campaign.CampaignError, "campaign artifact changed"):
            campaign.validate_manifest(
                argparse.Namespace(**vars(args), manifest=str(self.manifest))
            )

    def test_manifest_records_fingerprint_runtime_setting(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(manifest["runtime"]["fingerprint_segment_max"], "8")

        args.manifest = str(self.manifest)
        args.fingerprint_segment_max = "1"
        with self.assertRaisesRegex(campaign.CampaignError, "fingerprint_segment_max"):
            campaign.validate_manifest(args)

    def test_fingerprint_runtime_is_canonical_decimal_and_bounded(self) -> None:
        args = self.create_args()
        args.fingerprint_segment_max = "010"
        campaign.create_manifest(args)
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(manifest["runtime"]["fingerprint_segment_max"], "10")

        args.manifest = str(self.manifest)
        args.fingerprint_segment_max = "00010"
        campaign.validate_manifest(args)

        manifest["runtime"]["fingerprint_segment_max"] = "00010"
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        args.fingerprint_segment_max = "10"
        campaign.validate_manifest(args)

        for value in ("1", "64", "064"):
            with self.subTest(valid_boundary=value):
                args.fingerprint_segment_max = value
                self.assertEqual(
                    campaign.runtime_metadata(args)["fingerprint_segment_max"],
                    str(int(value)),
                )

        for value in ("", "00", "65", "9223372036854775808", "８", "8x"):
            with self.subTest(value=value):
                args.fingerprint_segment_max = value
                with self.assertRaisesRegex(campaign.CampaignError, "decimal integer from 1 to 64"):
                    campaign.runtime_metadata(args)

    def test_potfile_identity_allows_content_changes_but_rejects_target_changes(self) -> None:
        first = self.root / "pot-a"
        second = self.root / "pot-b"
        alias = self.root / "potfile"
        first.write_text("hash:one\n", encoding="utf-8")
        second.write_text("hash:two\n", encoding="utf-8")
        alias.symlink_to(first)
        args = self.create_args()
        args.potfile = str(alias)
        campaign.create_manifest(args)
        args.manifest = str(self.manifest)

        first.write_text("hash:one\nhash:another\n", encoding="utf-8")
        campaign.validate_manifest(args)

        alias.unlink()
        alias.symlink_to(second)
        with self.assertRaisesRegex(campaign.CampaignError, "campaign potfile path changed"):
            campaign.validate_manifest(args)

    def test_potfile_identity_allows_legacy_absence_and_rejects_malformed_presence(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        del manifest["inputs"]["potfile"]
        args.manifest = str(self.manifest)
        args.potfile = str(self.root / "different-potfile")
        Path(args.potfile).write_text("", encoding="utf-8")
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        campaign.validate_manifest(args)

        manifest["inputs"]["potfile"] = None
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(campaign.CampaignError, "invalid potfile identity"):
            campaign.validate_manifest(args)

    def test_validation_allows_legacy_missing_fingerprint_setting(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        del manifest["runtime"]["fingerprint_segment_max"]
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")

        campaign.validate_manifest(
            argparse.Namespace(**vars(args), manifest=str(self.manifest))
        )

    def test_validation_rejects_missing_existing_runtime_field(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        del manifest["runtime"]["kernel"]
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")

        with self.assertRaisesRegex(campaign.CampaignError, "runtime changed for kernel"):
            campaign.validate_manifest(
                argparse.Namespace(**vars(args), manifest=str(self.manifest))
            )

    def test_manifest_records_private_workspace(self) -> None:
        args = self.create_args()
        workspace = Path(f"{self.manifest}.state") / "workspace"
        args.workspace = str(workspace)

        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(manifest["campaign"]["workspace"], str(workspace.resolve()))
        self.assertEqual(workspace.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.manifest.stat().st_mode & 0o777, 0o600)

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            campaign.print_workspace(argparse.Namespace(manifest=str(self.manifest)))
        self.assertEqual(output.getvalue().strip(), str(workspace.resolve()))

    def test_private_workspace_rejects_symlink_and_file(self) -> None:
        target = self.root / "workspace-target"
        target.mkdir()
        link = self.root / "workspace-link"
        link.symlink_to(target, target_is_directory=True)
        with self.assertRaisesRegex(campaign.CampaignError, "is a symlink"):
            campaign.ensure_private_directory(link)

        file_path = self.root / "workspace-file"
        file_path.write_text("not a directory\n", encoding="utf-8")
        with self.assertRaises(campaign.CampaignError):
            campaign.ensure_private_directory(file_path)

    def test_campaign_lock_refuses_competitor_and_releases(self) -> None:
        args = self.create_args()
        args.workspace = str(Path(f"{self.manifest}.state") / "workspace")
        campaign.create_manifest(args)
        state_dir = Path(f"{self.manifest}.state")
        ready = state_dir / "first.ready"
        release = state_dir / "first.release"

        def lock_command(
            manifest_path: Path,
            ready_path: Path,
            release_path: Path,
            owner_pid: int | None = None,
        ) -> list[str]:
            return [
                "python3",
                str(CAMPAIGN_PATH),
                "lock-hold",
                "--manifest",
                str(manifest_path),
                "--ready",
                str(ready_path),
                "--release",
                str(release_path),
                "--owner",
                str(owner_pid or os.getpid()),
            ]

        owner = subprocess.Popen(lock_command(self.manifest, ready, release))
        try:
            deadline = time.monotonic() + 5
            while not ready.is_file() and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(ready.is_file(), "campaign lock owner did not report readiness")
            self.assertEqual(ready.read_text(encoding="utf-8").strip(), "acquired")

            other_manifest = self.root / "other-campaign.json"
            other_args = self.create_args(output=other_manifest)
            other_args.workspace = str(Path(f"{other_manifest}.state") / "workspace")
            campaign.create_manifest(other_args)
            other_state_dir = Path(f"{other_manifest}.state")
            other_ready = other_state_dir / "other.ready"
            other_release = other_state_dir / "other.release"
            other_owner = subprocess.Popen(
                lock_command(other_manifest, other_ready, other_release)
            )
            try:
                deadline = time.monotonic() + 5
                while not other_ready.is_file() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(other_ready.is_file(), "distinct campaign lock was blocked")
                self.assertEqual(
                    other_ready.read_text(encoding="utf-8").strip(), "acquired"
                )
            finally:
                other_release.touch()
                other_owner.wait(timeout=5)
            self.assertEqual(other_owner.returncode, 0)

            competitor_ready = state_dir / "second.ready"
            competitor = subprocess.run(
                lock_command(
                    self.manifest, competitor_ready, state_dir / "second.release"
                ),
                check=False,
            )
            self.assertEqual(competitor.returncode, 1)
            self.assertEqual(competitor_ready.read_text(encoding="utf-8").strip(), "busy")
        finally:
            release.touch()
            owner.wait(timeout=5)
        self.assertEqual(owner.returncode, 0)

        ready.unlink()
        release.unlink()
        stale_ready = state_dir / "stale.ready"
        stale_release = state_dir / "stale.release"
        stale = subprocess.run(
            lock_command(self.manifest, stale_ready, stale_release, 2**31 - 1),
            check=False,
            timeout=5,
        )
        self.assertEqual(stale.returncode, 0)
        self.assertEqual(stale_ready.read_text(encoding="utf-8").strip(), "acquired")
        stale_ready.unlink()

        reacquired = subprocess.Popen(lock_command(self.manifest, ready, release))
        try:
            deadline = time.monotonic() + 5
            while not ready.is_file() and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(ready.is_file(), "campaign lock was not reacquired")
            self.assertEqual(ready.read_text(encoding="utf-8").strip(), "acquired")
        finally:
            release.touch()
            reacquired.wait(timeout=5)
        self.assertEqual(reacquired.returncode, 0)
        self.assertEqual(ready.read_text(encoding="utf-8").strip(), "acquired")

    def test_manifest_rejects_workspace_escape(self) -> None:
        args = self.create_args()
        args.workspace = str(Path(f"{self.manifest}.state") / "workspace")
        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        manifest["campaign"]["workspace"] = str(self.root / "outside-workspace")
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")

        with self.assertRaisesRegex(campaign.CampaignError, "escapes private state"):
            campaign.load_manifest(str(self.manifest))

    def test_manifest_rejects_restore_path_escape(self) -> None:
        args = self.create_args()
        args.workspace = str(Path(f"{self.manifest}.state") / "workspace")
        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        command = manifest["steps"][0]["commands"][0]
        command["session"] = "hc-safe-session"
        command["restore_file"] = str(self.root / "outside.restore")
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")

        with self.assertRaisesRegex(campaign.CampaignError, "escapes private state"):
            campaign.load_manifest(str(self.manifest))

    def test_manifest_rejects_preserved_input_escape(self) -> None:
        args = self.create_args()
        args.workspace = str(Path(f"{self.manifest}.state") / "workspace")
        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        manifest["steps"][0]["commands"][0]["preserved_inputs"] = [
            str(self.root / "outside-input")
        ]
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")

        with self.assertRaisesRegex(campaign.CampaignError, "escapes private state"):
            campaign.load_manifest(str(self.manifest))

    def test_manifest_rejects_unsafe_session_component(self) -> None:
        args = self.create_args()
        args.workspace = str(Path(f"{self.manifest}.state") / "workspace")
        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        manifest["steps"][0]["commands"][0]["session"] = "../outside"
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")

        with self.assertRaisesRegex(campaign.CampaignError, "invalid command session"):
            campaign.load_manifest(str(self.manifest))

    def test_legacy_preserved_inputs_are_limited_to_generated_temp_files(self) -> None:
        campaign.create_manifest(self.create_args())
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        legacy_input = self.root / "hash-cracker-campaign-step-input"
        legacy_input.write_text("temporary input\n", encoding="utf-8")
        manifest["steps"][0]["commands"][0]["preserved_inputs"] = [
            str(legacy_input)
        ]
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")

        campaign.load_manifest(str(self.manifest))

        manifest["steps"][0]["commands"][0]["preserved_inputs"] = [
            str(self.root / "ordinary-user-file")
        ]
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(campaign.CampaignError, "generated legacy input"):
            campaign.load_manifest(str(self.manifest))

        manifest["steps"][0]["commands"][0]["preserved_inputs"] = [
            "/etc/hash-cracker-campaign-outside"
        ]
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(campaign.CampaignError, "outside the temporary root"):
            campaign.load_manifest(str(self.manifest))

    def test_negative_step_and_command_indexes_are_rejected(self) -> None:
        campaign.create_manifest(self.create_args())
        manifest = campaign.load_manifest(str(self.manifest))

        with self.assertRaisesRegex(campaign.CampaignError, "invalid campaign step index"):
            campaign.get_step(manifest, -1, "step-001")
        with self.assertRaisesRegex(campaign.CampaignError, "invalid campaign command index"):
            campaign.get_command(manifest["steps"][0], -1)

    def test_resumed_command_history_is_deduplicated(self) -> None:
        campaign.create_manifest(self.create_args())
        first_commands = self.root / "first-commands"
        first_commands.write_text(
            json.dumps(
                {
                    "step_id": "step-001",
                    "preview": f"{self.hashcat} --session=first",
                    "argv": [str(self.hashcat), "--session=first", "--restore-file-path=/tmp/first"],
                }
            )
            + "\n",
            encoding="utf-8",
        )
        campaign.update_step(
            argparse.Namespace(
                manifest=str(self.manifest),
                index=0,
                step_id="step-001",
                state="interrupted",
                exit_code=130,
                duration=1,
                commands_file=str(first_commands),
            )
        )

        resumed_commands = self.root / "resumed-commands"
        resumed_commands.write_text(
            json.dumps(
                {
                    "step_id": "step-001",
                    "preview": f"{self.hashcat} --session=first --restore",
                    "argv": [
                        str(self.hashcat),
                        "--session=first",
                        "--restore-file-path=/tmp/first",
                        "--restore",
                    ],
                }
            )
            + "\n",
            encoding="utf-8",
        )
        campaign.update_step(
            argparse.Namespace(
                manifest=str(self.manifest),
                index=0,
                step_id="step-001",
                state="completed",
                exit_code=0,
                duration=1,
                commands_file=str(resumed_commands),
            )
        )

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["steps"][0]["executed_commands"]), 1)

    def test_print_workspace_supports_legacy_and_rejects_invalid_metadata(self) -> None:
        campaign.create_manifest(self.create_args())
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            campaign.print_workspace(argparse.Namespace(manifest=str(self.manifest)))
        self.assertEqual(output.getvalue(), "")

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        manifest["campaign"]["workspace"] = 123
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(campaign.CampaignError, "invalid artifact workspace"):
            campaign.print_workspace(argparse.Namespace(manifest=str(self.manifest)))

    def test_validation_rejects_changed_artifact(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)
        campaign.validate_manifest(
            argparse.Namespace(**vars(args), manifest=str(self.manifest))
        )

        self.artifact.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        with self.assertRaisesRegex(campaign.CampaignError, "campaign artifact changed"):
            campaign.validate_manifest(
                argparse.Namespace(**vars(args), manifest=str(self.manifest))
            )

    def test_validation_rejects_changed_configuration(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)
        self.config.write_text("HASHCAT=changed\n", encoding="utf-8")

        with self.assertRaisesRegex(campaign.CampaignError, "campaign input changed for config"):
            campaign.validate_manifest(
                argparse.Namespace(**vars(args), manifest=str(self.manifest))
            )

    def test_plan_rejects_protected_output_path(self) -> None:
        args = self.create_args(output=self.hashlist)

        with self.assertRaisesRegex(campaign.CampaignError, "conflicts with protected path"):
            campaign.create_manifest(args)

    def test_validation_allows_legacy_manifest_without_artifacts(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        del manifest["artifacts"]
        self.manifest.write_text(json.dumps(manifest), encoding="utf-8")

        campaign.validate_manifest(
            argparse.Namespace(**vars(args), manifest=str(self.manifest))
        )

    def test_command_record_allows_only_campaign_generated_flags_to_differ(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)
        start_args = argparse.Namespace(
            manifest=str(self.manifest), index=0, step_id="step-001", command_index=0
        )
        campaign.command_start(start_args)
        command = campaign.load_manifest(str(self.manifest))["steps"][0]["commands"][0]
        record_args = argparse.Namespace(
            manifest=str(self.manifest),
            index=0,
            step_id="step-001",
            command_index=0,
            preview=(
                f"{self.hashcat} --bitmap-max=24 -d 1 "
                f"--potfile-path={self.potfile} -m1000 {self.hashlist} "
                f"--session={command['session']} "
                f"--restore-file-path={command['restore_file']}"
            ),
        )

        campaign.record_command(record_args)
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        executed_argv = manifest["steps"][0]["commands"][0]["executed_argv"]
        self.assertEqual(
            executed_argv[-2:],
            [f"--session={command['session']}", f"--restore-file-path={command['restore_file']}"]
        )

    def test_command_record_rejects_processor_argument_drift(self) -> None:
        args = self.create_args()
        campaign.create_manifest(args)
        record_args = argparse.Namespace(
            manifest=str(self.manifest),
            index=0,
            step_id="step-001",
            command_index=0,
            preview=(
                f"{self.hashcat} --bitmap-max=24 -d 1 "
                f"--potfile-path={self.potfile} -m1000 {self.hashlist} --changed"
            ),
        )

        with self.assertRaisesRegex(campaign.CampaignError, "command changed"):
            campaign.record_command(record_args)


if __name__ == "__main__":
    unittest.main()
