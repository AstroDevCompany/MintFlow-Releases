#!/usr/bin/env python3
"""Fails unless every place that carries the app version agrees (and matches --tag vX.Y.Z when given)."""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def rust_workspace():
    return re.search(r'\[workspace\.package\][^\[]*?version\s*=\s*"([^"]+)"', (ROOT / "Cargo.toml").read_text(), re.S).group(1)


def desktop_crate():
    t = (ROOT / "apps/desktop/src-tauri/Cargo.toml").read_text()
    return re.search(r'^version\s*=\s*"([^"]+)"', t, re.M).group(1)


versions = {
    "Cargo.toml (workspace)": rust_workspace(),
    "apps/desktop/src-tauri/Cargo.toml": desktop_crate(),
    "apps/desktop/src-tauri/tauri.conf.json": json.loads((ROOT / "apps/desktop/src-tauri/tauri.conf.json").read_text())["version"],
    "apps/desktop/package.json": json.loads((ROOT / "apps/desktop/package.json").read_text())["version"],
    "apps/ios/FreshNews/project.yml": re.search(r'MARKETING_VERSION:\s*"([^"]+)"', (ROOT / "apps/ios/FreshNews/project.yml").read_text()).group(1),
}
for k, v in versions.items():
    print(f"{v:>10}  {k}")
bad = len(set(versions.values())) != 1
if "--tag" in sys.argv:
    tag = sys.argv[sys.argv.index("--tag") + 1].lstrip("v")
    if set(versions.values()) != {tag}:
        print(f"tag says {tag}")
        bad = True
if bad:
    sys.exit("versions disagree")
print("versions agree")
