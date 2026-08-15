#!/usr/bin/env python3
"""Direct contract tests for campaign manifest and command state handling."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import tempfile
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
            artifact=[str(self.artifact)],
        )

    def test_manifest_records_artifact_fingerprints(self) -> None:
        args = self.create_args()

        campaign.create_manifest(args)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        artifacts = {item["path"]: item["sha256"] for item in manifest["artifacts"]}
        expected_digest = hashlib.sha256(self.artifact.read_bytes()).hexdigest()
        self.assertEqual(artifacts[str(self.artifact.resolve())], expected_digest)

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
        record_args = argparse.Namespace(
            manifest=str(self.manifest),
            index=0,
            step_id="step-001",
            command_index=0,
            preview=(
                f"{self.hashcat} --bitmap-max=24 -d 1 "
                f"--potfile-path={self.potfile} -m1000 {self.hashlist} "
                "--session=fixture --restore-file-path=/tmp/fixture.restore --restore"
            ),
        )

        campaign.record_command(record_args)
        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            manifest["steps"][0]["commands"][0]["executed_argv"][-1], "--restore"
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
