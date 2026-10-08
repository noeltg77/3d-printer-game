"""Filament spool generator. Stands upright on its rim with the axle along Y.

blender --background --factory-startup --python tools/generators/spools.py -- \
    --colour red --fill 0.8 --out assets/models/filament/spool_red.glb
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common

RADIUS = 0.1
WIDTH = 0.065
FLANGE = 0.006
HUB = RADIUS * 0.45
SEGMENTS = 12


def add_arguments(parser):
    parser.add_argument("--colour", default="red", help="filament colour")
    parser.add_argument("--fill", type=float, default=1.0, help="0 is an empty spool, 1 is full")
    parser.add_argument("--flange", default=None, help="spool body colour, seeded if not given")


def build(args, rng):
    builder = common.MeshBuilder()
    flange = args.flange or rng.choice(("charcoal", "ink", "slate"))
    centre = (0, 0, RADIUS)
    for side in (-1, 1):
        offset = side * (WIDTH - FLANGE) / 2
        builder.cylinder(RADIUS, FLANGE, (0, offset, RADIUS), flange, segments=SEGMENTS, axis="Y")
    builder.cylinder(HUB, WIDTH - FLANGE, centre, flange, segments=SEGMENTS, axis="Y")
    if args.fill > 0:
        wound = HUB + (RADIUS * 0.93 - HUB) * min(args.fill, 1.0)
        builder.cylinder(wound, WIDTH - FLANGE * 2, centre, args.colour, segments=SEGMENTS, axis="Y")
    builder.cylinder(RADIUS * 0.26, WIDTH + 0.004, centre, "cream", segments=8, axis="Y")
    builder.finish(args.out.stem)


if __name__ == "__main__":
    common.run(sys.modules[__name__])
