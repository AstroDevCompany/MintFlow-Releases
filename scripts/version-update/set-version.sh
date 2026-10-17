#!/usr/bin/env bash
# Sets the app version everywhere it lives, e.g. `./scripts/set-version.sh 0.2` or `0.2.0`.
# A short version like "0.2" is written as "0.2.0" (Cargo and npm require three parts).
# Then runs scripts/check_versions.py to confirm every place agrees.
# `-v` or `-view` shows the current version instead of changing it.
set -euo pipefail

if [ $# -ne 1 ] || [[ "$1" == -h || "$1" == --help ]]; then
  echo "usage: $0 <version>   (e.g. 0.2 or 0.2.0)" >&2
  echo "       $0 -v | -view  (show the current version)" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

if [[ "$1" == -v || "$1" == -view || "$1" == --view ]]; then
  python3 scripts/check_versions.py
  exit
fi

python3 - "$1" <<'PY'
import pathlib, re, sys

raw = sys.argv[1].lstrip("v")
m = re.fullmatch(r"(\d+)\.(\d+)(?:\.(\d+))?(-[0-9A-Za-z.-]+)?", raw)
if not m:
    sys.exit(f"not a valid version: {raw!r} (expected X.Y or X.Y.Z)")
new = f"{m[1]}.{m[2]}.{m[3] or 0}{m[4] or ''}"

def edit(path, pattern, repl, flags=0):
    p = pathlib.Path(path)
    text = p.read_text()
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        sys.exit(f"{path}: version line not found")
    p.write_text(out)

ver = r'"[^"]+"'
edit("Cargo.toml", r'(\[workspace\.package\][^\[]*?version\s*=\s*)' + ver, rf'\g<1>"{new}"', re.S)
edit("apps/desktop/src-tauri/Cargo.toml", r'^(version\s*=\s*)' + ver, rf'\g<1>"{new}"', re.M)
edit("apps/desktop/src-tauri/tauri.conf.json", r'^(\s*"version":\s*)' + ver, rf'\g<1>"{new}"', re.M)
edit("apps/desktop/package.json", r'^(\s*"version":\s*)' + ver, rf'\g<1>"{new}"', re.M)
edit("apps/ios/FreshNews/project.yml", r'(MARKETING_VERSION:\s*)' + ver, rf'\g<1>"{new}"')

# Lockfiles record the workspace crates' versions too; keep them in step so cargo --locked passes.
for lock in ("Cargo.lock", "apps/desktop/src-tauri/Cargo.lock"):
    p = pathlib.Path(lock)
    p.write_text(re.sub(r'(name = "fresh-news[^"]*"\nversion = )"[^"]+"', rf'\g<1>"{new}"', p.read_text()))

print(f"version set to {new}")
PY

python3 scripts/check_versions.py
