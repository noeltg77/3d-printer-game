"""Builds every asset listed in manifest.json in one Blender session.

blender --background --factory-startup --python tools/generators/build_all.py
blender --background --factory-startup --python tools/generators/build_all.py -- --only spool --no-preview

--only keeps the entries whose output path contains the given text.
"""

import argparse
import importlib
import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", default="")
    parser.add_argument("--no-preview", action="store_true")
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    manifest = json.loads((Path(__file__).resolve().parent / "manifest.json").read_text())
    entries = [entry for entry in manifest["assets"] if options.only in entry["out"]]
    for entry in entries:
        argv = ["--out", entry["out"]]
        for key, value in entry.get("args", {}).items():
            values = value if isinstance(value, list) else [value]
            argv += [f"--{key}", *(str(item) for item in values)]
        if options.no_preview:
            argv.append("--no-preview")
        common.run(importlib.import_module(entry["generator"]), argv)
    print(f"Built {len(entries)} assets")


main()
