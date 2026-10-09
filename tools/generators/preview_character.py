"""Renders a character beside the desk and chair, front on and three-quarter,
to judge its proportions against the furniture before importing. Writes
tools/previews/character_scale_front.png and character_scale_three_quarter.png.
Exports nothing.

blender --background --factory-startup --python tools/generators/preview_character.py -- \
    --top teal --hair wood_dark --hair-style short --apron orange
"""

import argparse
import random
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import bpy
import character
import common
import furniture

VIEWS = {"front": (0.0, -1.0, 0.18), "three_quarter": (0.75, -1.0, 0.45)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=0)
    character.add_arguments(parser)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    common.reset_scene()
    character.build(args, random.Random(args.seed))
    bpy.data.objects["body"].location.x += 1.15
    for variant, position in (("desk", (0.0, 0.0, 0.0)), ("chair", (-0.1, -0.75, 0.0))):
        builder = common.MeshBuilder()
        furniture.VARIANTS[variant](builder, argparse.Namespace(colour="teal"), random.Random(0))
        builder.finish(variant).location = position
    for name, direction in VIEWS.items():
        common.render_preview(common.PREVIEW_DIR / f"character_scale_{name}.png", resolution=768, direction=direction)


main()
