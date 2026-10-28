"""Build a source-only device test bundle without changing release.manifest."""
from pathlib import Path
import hashlib
import gzip
import io
import tarfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "dist"
OUTPUT.mkdir(exist_ok=True)
files = [p for p in ROOT.iterdir() if p.is_file() and
         (p.suffix in {".md", ".sh"} or p.name in
          {"nht", "Makefile", "RELEASE_INFO", "release.manifest", ".gitignore"})]
for folder in ["config", "lib", "modules", "tools"]:
    files.extend(p for p in (ROOT / folder).rglob("*") if p.is_file()
                 and "__pycache__" not in p.parts
                 and p.suffix in {".sh", ".py", ".ps1", ".conf"})
files.append(ROOT / "runtime/ubuntu-gui.sh")
manifest = []
archive_path = OUTPUT / "NetHunter-Toolkit-Termux-Test.tar.gz"
with archive_path.open("wb") as raw, gzip.GzipFile(
        filename="", mode="wb", fileobj=raw, mtime=0) as compressed, tarfile.open(
        fileobj=compressed, mode="w") as archive:
    for path in sorted(set(files)):
        if path.is_symlink():
            raise ValueError("Source links are not allowed: " + str(path))
        name = path.relative_to(ROOT).as_posix()
        data = path.read_bytes()
        manifest.append(hashlib.sha256(data).hexdigest() + "  " + name)
        info = tarfile.TarInfo("nht-termux-test/" + name)
        info.size = len(data)
        info.mode = 0o755 if path.suffix == ".sh" or name == "nht" else 0o644
        archive.addfile(info, io.BytesIO(data))
    data = ("\n".join(manifest) + "\n").encode("utf-8")
    info = tarfile.TarInfo("nht-termux-test/termux-package.manifest")
    info.size = len(data)
    info.mode = 0o644
    archive.addfile(info, io.BytesIO(data))
digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
checksum = archive_path.with_name(archive_path.name + ".sha256")
checksum.write_text(digest + "  " + archive_path.name + "\n", encoding="utf-8", newline="\n")
# Verify packaged bytes against the independent per-file manifest.
with tarfile.open(archive_path) as archive:
    for line in manifest:
        expected, name = line.split("  ", 1)
        actual = hashlib.sha256(archive.extractfile("nht-termux-test/" + name).read()).hexdigest()
        if expected != actual:
            raise ValueError("Packaged checksum mismatch: " + name)
print(f"Verified {len(manifest)} source files: {archive_path}")
print(f"SHA256: {digest}")
