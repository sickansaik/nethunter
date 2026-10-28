"""Archive security tests; uses the actual Python block in installation.sh.
Run with python tools/test_installation.py. No live installation is modified.
"""
import io
import hashlib
import os
import shutil
import pathlib
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "lib/installation.sh").read_text(encoding="utf-8")
EXTRACTOR = SOURCE.split("<<'PY'\n", 1)[1].split("\nPY\n", 1)[0]
ITEMS = SOURCE.split("NHT_INSTALL_ITEMS=(", 1)[1].split(")", 1)[0].split()
METADATA = SOURCE.split("NHT_RELEASE_METADATA=(", 1)[1].split(")", 1)[0].split()


class ArchiveTests(unittest.TestCase):
    def extract(self, entries, success):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            archive_path = root / "backup.tar.gz"
            output = root / "output"
            output.mkdir()
            with tarfile.open(archive_path, "w:gz") as archive:
                for name, kind in entries:
                    member = tarfile.TarInfo(name)
                    if kind == "file":
                        content = b"saved installation state\n"
                        member.size = len(content)
                        archive.addfile(member, io.BytesIO(content))
                    else:
                        member.type = {"symlink": tarfile.SYMTYPE,
                                       "hardlink": tarfile.LNKTYPE,
                                       "fifo": tarfile.FIFOTYPE}[kind]
                        member.linkname = "../../outside"
                        archive.addfile(member)
            result = subprocess.run(
                [sys.executable, "-c", EXTRACTOR, str(archive_path), str(output),
                 *ITEMS, *METADATA], capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, success, result.stderr)
            if success:
                for name, _ in entries:
                    self.assertEqual((output / name).read_bytes(), b"saved installation state\n")
            else:
                self.assertEqual(list(output.iterdir()), [], "must validate all entries before extraction")

    def test_source_and_network_history_roundtrip(self):
        self.extract([(name, "file") for name in
                      ["feature.sh", "doctor.sh", "lib/installation.sh",
                       "runtime/network/latest.json", "runtime/network/snapshots/old.json",
                       "release.manifest"]], True)

    def test_traversal(self):
        self.extract([("feature.sh", "file"), ("runtime/../../outside", "file")], False)

    def test_absolute_path(self):
        self.extract([("/outside", "file")], False)

    def test_backslash_path(self):
        self.extract([("runtime/..\\outside", "file")], False)

    def test_unowned_files(self):
        self.extract([("logs/install.log", "file")], False)

    def test_links_and_special_files(self):
        for kind in ["symlink", "hardlink", "fifo"]:
            with self.subTest(kind=kind):
                self.extract([("runtime/network/link", kind)], False)

    def test_duplicate_path(self):
        self.extract([("feature.sh", "file"), ("./feature.sh", "file")], False)



@unittest.skipUnless(shutil.which("bash"), "Bash is required for integration tests")
class MaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name) / "toolkit"
        self.root.mkdir()
        for name in ITEMS:
            source = ROOT / name
            if source.is_dir():
                shutil.copytree(source, self.root / name)
            else:
                shutil.copy2(source, self.root / name)
        for name in ["status.sh", "doctor.sh", "repair.sh"]:
            self.mock(self.root, name, 0)
        state = self.root / "runtime/network/latest.json"
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text('{"installation":"original"}')
        self.original = state.read_bytes()

    def mock(self, root, name, code):
        path = root / name
        path.write_text("#!/usr/bin/env bash\nexit " + str(code) + "\n", encoding="utf-8", newline="\n")
        path.chmod(0o755)

    def run_script(self, name, answers=""):
        env = dict(os.environ, TMPDIR=pathlib.Path(self.temporary.name).as_posix())
        result = subprocess.run(["bash", str(self.root / name)], input=answers.encode("utf-8"),
                                capture_output=True, env=env, timeout=60)
        result.stdout = result.stdout.decode("utf-8", errors="replace")
        result.stderr = result.stderr.decode("utf-8", errors="replace")
        return result

    def test_backup_has_all_files_and_state(self):
        result = self.run_script("backup.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        backup = next((self.root / "backups").glob("*.tar.gz"))
        with tarfile.open(backup) as archive:
            names = archive.getnames()
            for name in ITEMS:
                self.assertIn(name, names)
            self.assertEqual(archive.extractfile("runtime/network/latest.json").read(), self.original)

    def test_restore_critical_failure_rolls_back(self):
        self.assertEqual(self.run_script("backup.sh").returncode, 0)
        backup = next((self.root / "backups").glob("*.tar.gz"))
        # Create a backup whose diagnostic fails, preserving a working live copy.
        self.mock(self.root, "repair.sh", 2)
        with tarfile.open(backup, "w:gz") as archive:
            for name in ITEMS:
                archive.add(self.root / name, arcname=name)
        self.mock(self.root, "repair.sh", 0)
        (self.root / "feature.sh").write_text("#!/usr/bin/env bash\n# live version\n", encoding="utf-8", newline="\n")
        before = (self.root / "feature.sh").read_bytes()
        result = self.run_script("restore.sh", "1\ny\n")
        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
        self.assertEqual((self.root / "feature.sh").read_bytes(), before)
        self.assertEqual((self.root / "runtime/network/latest.json").read_bytes(), self.original)
        self.assertFalse((self.root / ".installation-lock").exists())

    def test_restore_success_replaces_files_and_history(self):
        self.assertEqual(self.run_script("backup.sh").returncode, 0)
        before = (self.root / "feature.sh").read_bytes()
        (self.root / "feature.sh").write_text("#!/usr/bin/env bash\n# changed\n", newline="\n")
        (self.root / "runtime/network/latest.json").write_text("changed history")
        result = self.run_script("restore.sh", "1\ny\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / "feature.sh").read_bytes(), before)
        self.assertEqual((self.root / "runtime/network/latest.json").read_bytes(), self.original)
        self.assertEqual(len(list((self.root / "backups").glob("pre-restore-*.tar.gz"))), 1)

    def test_incomplete_backup_leaves_installation_untouched(self):
        (self.root / "backups").mkdir()
        before = (self.root / "feature.sh").read_bytes()
        with tarfile.open(self.root / "backups/nethunter-toolkit-incomplete.tar.gz", "w:gz") as archive:
            archive.add(self.root / "feature.sh", arcname="feature.sh")
        result = self.run_script("restore.sh", "1\ny\n")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual((self.root / "feature.sh").read_bytes(), before)
        self.assertFalse((self.root / ".installation-lock").exists())

    def test_lock_blocks_backup(self):
        (self.root / ".installation-lock").mkdir()
        result = self.run_script("backup.sh")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertTrue((self.root / ".installation-lock").is_dir())

    def test_required_nested_files_and_types(self):
        for name in ["config/settings.conf", "config/version.conf", "lib/network/scan.sh",
                     "modules/01-termux.sh", "runtime/ubuntu-gui.sh", "nht"]:
            with self.subTest(name=name):
                path = self.root / name
                saved = path.read_bytes()
                path.unlink()
                missing_result = self.run_script("backup.sh")
                path.mkdir()
                directory_result = self.run_script("backup.sh")
                path.rmdir()
                path.write_bytes(saved)
                self.assertNotEqual(missing_result.returncode, 0, name + " missing was accepted")
                self.assertNotEqual(directory_result.returncode, 0, name + " directory was accepted")

    def inject_unsafe_tar(self):
        # Simulate a link arriving during archive creation, without requiring
        # Windows symlink privileges or touching files outside this fixture.
        fixture = pathlib.Path(self.temporary.name) / "unsafe.tar.gz"
        with tarfile.open(fixture, "w:gz") as archive:
            for name in ITEMS:
                archive.add(self.root / name, arcname=name)
            link = tarfile.TarInfo("runtime/network/link")
            link.type = tarfile.SYMTYPE
            link.linkname = "latest.json"
            archive.addfile(link)
        return dict(os.environ, NHT_TEST_ARCHIVE=fixture.as_posix())

    def run_with_unsafe_tar(self, name, answers=b""):
        env = self.inject_unsafe_tar()
        marker = self.root / "tar-injected"
        env["NHT_TEST_TAR_MARKER"] = marker.as_posix()
        script = '''tar() {
            if [[ "$1" == -czf ]]; then
                printf 'injected' > "$NHT_TEST_TAR_MARKER"
                cp "$NHT_TEST_ARCHIVE" "$2"
            else
                command tar "$@"
            fi
        }
        export -f tar
        bash "$1"
        '''
        result = subprocess.run(["bash", "-c", script, "test", str(self.root / name)],
                                env=env, input=answers, capture_output=True, timeout=60)
        self.assertTrue(marker.exists(), "archive injection must actually run")
        return result

    def test_backup_rejects_archive_restore_cannot_read(self):
        result = self.run_with_unsafe_tar("backup.sh")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(list((self.root / "backups").glob("*.tar.gz")), [])
        self.assertFalse((self.root / ".installation-lock").exists())

    def test_restore_rejects_unsafe_safety_backup_before_replacement(self):
        self.assertEqual(self.run_script("backup.sh").returncode, 0)
        path = self.root / "feature.sh"
        path.write_text("#!/usr/bin/env bash\n# live marker\n", newline="\n")
        before = path.read_bytes()
        result = self.run_with_unsafe_tar("restore.sh", b"1\ny\n")
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertEqual(path.read_bytes(), before)
        self.assertFalse(list((self.root / "backups").glob("pre-restore-*.tar.gz")))
        self.assertFalse((self.root / ".installation-lock").exists())

    def test_update_rejects_unsafe_safety_backup_before_replacement(self):
        self.make_update(False)
        before = (self.root / "feature.sh").read_bytes()
        result = self.run_with_unsafe_tar("update.sh")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual((self.root / "feature.sh").read_bytes(), before)
        self.assertEqual((self.root / "runtime/network/latest.json").read_bytes(), self.original)
        self.assertFalse(list((self.root / "backups").glob("*.tar.gz")))
        self.assertFalse((self.root / ".installation-lock").exists())

    def test_restore_rejects_missing_nested_source_before_replacement(self):
        (self.root / "backups").mkdir()
        backup = self.root / "backups/nethunter-toolkit-incomplete.tar.gz"
        with tarfile.open(backup, "w:gz") as archive:
            for name in ITEMS:
                archive.add(self.root / name, arcname=name,
                            filter=lambda entry: None if entry.name == "lib/network/scan.sh" else entry)
        before = (self.root / "feature.sh").read_bytes()
        result = self.run_script("restore.sh", "1\ny\n")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual((self.root / "feature.sh").read_bytes(), before)
        self.assertFalse((self.root / ".installation-lock").exists())

    def test_termux_package_failure_stops_module(self):
        for failure in ["update", "upgrade", "install", "none"]:
            with self.subTest(failure=failure):
                # Exported Bash function guarantees no real package command runs.
                script = '''pkg() {
                    printf '%s\\n' "$1" >> "$NHT_TEST_CALLS"
                    [[ "$1" != "$NHT_TEST_FAILURE" ]] || return 23
                }
                export -f pkg
                bash "$1"
                '''
                calls = self.root / "pkg-calls"
                calls.write_text("")
                env = dict(os.environ, NHT_TEST_FAILURE=failure,
                           NHT_TEST_CALLS=calls.as_posix())
                result = subprocess.run(["bash", "-c", script, "test",
                                         str(self.root / "modules/01-termux.sh")],
                                        env=env, capture_output=True, timeout=30)
                expected = ["update", "upgrade", "install"]
                if failure != "none":
                    expected = expected[:expected.index(failure) + 1]
                    self.assertEqual(result.returncode, 23, result.stdout)
                    self.assertNotIn("Termux är uppdaterat".encode(), result.stdout)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(calls.read_text().splitlines(), expected)

    def test_modified_update_rejected_before_changes(self):
        self.make_update(False)
        before = (self.root / "feature.sh").read_bytes()
        (self.root / "updates/0.5.1/feature.sh").write_text("#!/usr/bin/env bash\n# tampered\n", newline="\n")
        result = self.run_script("update.sh")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual((self.root / "feature.sh").read_bytes(), before)
        self.assertEqual((self.root / "runtime/network/latest.json").read_bytes(), self.original)

    def make_update(self, fail):
        candidate = self.root / "updates/0.5.1"
        candidate.mkdir(parents=True)
        for name in ITEMS:
            source = self.root / name
            if source.is_dir():
                shutil.copytree(source, candidate / name)
            else:
                shutil.copy2(source, candidate / name)
        shutil.rmtree(candidate / "runtime/network")
        version = candidate / "config/version.conf"
        version.write_text(version.read_text().replace('"0.5.0"', '"0.5.1"'), encoding="utf-8", newline="\n")
        (candidate / "feature.sh").write_text("#!/usr/bin/env bash\n# updated feature\n", encoding="utf-8", newline="\n")
        self.mock(candidate, "doctor.sh", 2 if fail else 0)
        manifest = []
        for path in sorted(candidate.rglob("*")):
            if path.is_file():
                manifest.append(hashlib.sha256(path.read_bytes()).hexdigest() + "  ./" + path.relative_to(candidate).as_posix())
        (candidate / "release.manifest").write_text("\n".join(manifest) + "\n", encoding="utf-8", newline="\n")

    def test_update_preserves_state_and_updates_feature(self):
        self.make_update(False)
        result = self.run_script("update.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("updated feature", (self.root / "feature.sh").read_text())
        self.assertEqual((self.root / "runtime/network/latest.json").read_bytes(), self.original)
        self.assertIn('"0.5.1"', (self.root / "config/version.conf").read_text())

    def test_update_failure_restores_files_and_state(self):
        before = (self.root / "feature.sh").read_bytes()
        self.make_update(True)
        result = self.run_script("update.sh")
        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
        self.assertEqual((self.root / "feature.sh").read_bytes(), before)
        self.assertEqual((self.root / "runtime/network/latest.json").read_bytes(), self.original)
        self.assertIn('"0.5.0"', (self.root / "config/version.conf").read_text())

if __name__ == "__main__":
    unittest.main(verbosity=2)
