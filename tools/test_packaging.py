"""Offline package tests in disposable source copies; never overwrite dist."""
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
    def test_clean_bundle_manifest_and_reproducibility(self):
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory) / "source"
            shutil.copytree(ROOT, source, ignore=shutil.ignore_patterns(
                ".git", ".dev-tools", "dist", "__pycache__", "backups", "logs", "updates"))
            historical = (source / "release.manifest").read_bytes()
            state = source / "runtime/network/latest.json"
            state.parent.mkdir(parents=True, exist_ok=True)
            state.write_text('"private test state"')
            command = [sys.executable, str(source / "tools/package-termux.py")]
            subprocess.run(command, check=True, capture_output=True)
            package = source / "dist/NetHunter-Toolkit-Termux-Test.tar.gz"
            first = package.read_bytes()
            with tarfile.open(package) as archive:
                names = archive.getnames()
                self.assertEqual(len(names), len(set(names)))
                self.assertFalse(any("/runtime/network/" in name for name in names))
                prefix = "nht-termux-test/"
                manifest_name = prefix + "termux-package.manifest"
                manifest = archive.extractfile(manifest_name).read().decode()
                expected_names = {manifest_name}
                for line in manifest.splitlines():
                    digest, name = line.split("  ", 1)
                    expected_names.add(prefix + name)
                    self.assertEqual(hashlib.sha256(archive.extractfile(prefix + name).read()).hexdigest(), digest)
                self.assertEqual(set(names), expected_names)
                self.assertEqual(archive.extractfile(prefix + "release.manifest").read(), historical)
                self.assertEqual(archive.getmember(prefix + "nht").mode, 0o755)
                self.assertIn(prefix + "runtime/ubuntu-gui.sh", names)
            checksum = package.with_name(package.name + ".sha256").read_text().split()[0]
            self.assertEqual(checksum, hashlib.sha256(first).hexdigest())
            self.assertEqual((source / "release.manifest").read_bytes(), historical)
            time.sleep(1.1)  # Detect wall-clock timestamps in the gzip header.
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(package.read_bytes(), first, "identical source must produce identical archive bytes")


if __name__ == "__main__":
    unittest.main(verbosity=2)
