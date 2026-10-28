"""Run offline source checks and isolated maintenance tests, including on Windows."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--syntax-only", action="store_true")
parser.add_argument("--lint-only", action="store_true")
args = parser.parse_args()
env = os.environ.copy()
if os.name == "nt":
    additions = [ROOT / ".dev-tools/git/bin", ROOT / ".dev-tools/git/usr/bin",
                 ROOT / ".dev-tools/git/mingw64/bin", Path(sys.executable).parent]
    env["PATH"] = os.pathsep.join(map(str, additions)) + os.pathsep + env.get("PATH", "")
    # Prevent the Windows Store alias from being selected inside Bash.
    env["PYTHONUTF8"] = "1"
    env["TMP"] = str(ROOT / ".dev-tools/tmp")
    env["TEMP"] = env["TMP"]
    Path(env["TMP"]).mkdir(parents=True, exist_ok=True)
bash = shutil.which("bash", path=env.get("PATH"))
sc_candidates = list((ROOT / ".dev-tools/shellcheck").rglob("shellcheck.exe")) if os.name == "nt" else []
shellcheck = str(sc_candidates[0]) if sc_candidates else shutil.which("shellcheck", path=env.get("PATH"))
if not bash or not shellcheck:
    sys.exit("Bash and ShellCheck are required. See README.md for setup.")
excluded = {".git", ".dev-tools", "backups", "logs", "updates", "dist", "__pycache__"}
files = sorted(p for p in ROOT.rglob("*") if p.is_file()
               and not excluded.intersection(p.relative_to(ROOT).parts)
               and (p.suffix == ".sh" or p.name == "nht"))
probe = subprocess.run([bash, "--version"], env=env, capture_output=True)
if probe.returncode:
    sys.exit("Bash could not start. " + probe.stderr.decode(errors="replace"))
failed = False
for path in ([] if args.lint_only else files):
    result = subprocess.run([bash, "-n", str(path)], env=env)
    failed |= result.returncode != 0
if not args.lint_only:
    print(f"Bash syntax: {len(files)} files, {'FAIL' if failed else 'PASS'}", flush=True)
if args.syntax_only:
    sys.exit(1 if failed else 0)
result = subprocess.run([shellcheck, "--severity=warning", *map(str, files)], cwd=ROOT, env=env)
failed |= result.returncode != 0
print(f"ShellCheck: {'PASS' if result.returncode == 0 else 'FAIL'}", flush=True)
if args.lint_only:
    sys.exit(1 if failed else 0)
result = subprocess.run([sys.executable, str(ROOT / "tools/test_installation.py")], cwd=ROOT, env=env)
failed |= result.returncode != 0
result = subprocess.run([sys.executable, str(ROOT / "tools/test_packaging.py")], cwd=ROOT, env=env)
failed |= result.returncode != 0
sys.exit(1 if failed else 0)
