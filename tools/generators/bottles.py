"""Resin bottle generator: what resin comes in, where filament comes on a spool.

Stands upright with its origin at the centre of its base, and is about as tall
as a spool so it sits in the same rack slots and mounts.

blender --background --factory-startup --python tools/generators/bottles.py -- \
    --colour stone --out assets/models/filament/bottle_stone.glb
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common

RADIUS = 0.045
HEIGHT = 0.17


def add_arguments(parser):
    parser.add_argument("--colour", default="stone", help="resin colour, shown on the label and cap")
    parser.add_argument("--body", default="charcoal", help="bottle colour: dark, to keep the light off the resin")


def build(args, rng):
    builder = common.MeshBuilder()
    builder.cylinder(RADIUS, HEIGHT * 0.72, (0, 0, HEIGHT * 0.36), args.body, segments=8)
    builder.cylinder(RADIUS, HEIGHT * 0.1, (0, 0, HEIGHT * 0.77), args.body, segments=8, radius_top=RADIUS * 0.45)
    builder.cylinder(RADIUS * 0.45, HEIGHT * 0.08, (0, 0, HEIGHT * 0.86), args.body, segments=8)
    builder.cylinder(RADIUS * 0.55, HEIGHT * 0.1, (0, 0, HEIGHT * 0.95), args.colour, segments=8)
    # A band of the resin's colour round the middle, as the label.
    builder.cylinder(RADIUS + 0.003, HEIGHT * 0.3, (0, 0, HEIGHT * 0.38), args.colour, segments=8)
    builder.finish(args.out.stem)


if __name__ == "__main__":
    common.run(sys.modules[__name__])
