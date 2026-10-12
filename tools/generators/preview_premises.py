"""Renders each premises shell in the manifest from the game's angle, with the
two near walls taken away as the game does, to judge its style before importing.
Writes tools/previews/premises/<name>.png. Exports nothing.

blender --background --factory-startup --python tools/generators/preview_premises.py
blender --background --factory-startup --python tools/generators/preview_premises.py -- --only workshop
"""

import argparse
import json
import random
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import bpy
import common
import garage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", default="")
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    manifest = json.loads((Path(__file__).resolve().parent / "manifest.json").read_text())
    for entry in manifest["assets"]:
        if entry["generator"] != "garage" or options.only not in entry["out"]:
            continue
        argv = ["--out", entry["out"]]
        for key, value in entry.get("args", {}).items():
            values = value if isinstance(value, list) else [value]
            argv += [f"--{key}", *(str(item) for item in values)]
        shell = argparse.ArgumentParser()
        shell.add_argument("--seed", type=int, default=0)
        shell.add_argument("--out", type=Path)
        garage.add_arguments(shell)
        args = shell.parse_args(argv)

        common.reset_scene()
        garage.build(args, random.Random(args.seed))
        for near in ("wall_south", "wall_east"):
            bpy.data.objects.remove(bpy.data.objects[near], do_unlink=True)
        common.render_preview(common.PREVIEW_DIR / "premises" / f"{args.out.stem}.png", resolution=1100, margin=0.95)


main()
