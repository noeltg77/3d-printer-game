"""Filament spool generator. Stands upright on its rim with the axle along Y.

blender --background --factory-startup --python tools/generators/spools.py -- \
    --colour red --fill 0.8 --out assets/models/filament/spool_red.glb

`--kilos 5` makes the big reel a print farm buys: wider across and a little
deeper, but still narrow enough for a rack slot.
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
# The 5 kg reel: radius and width. A rack's slots are 0.078 apart and its tiers 0.32.
BULK_RADIUS = 0.14
BULK_WIDTH = 0.074


def add_arguments(parser):
    parser.add_argument("--colour", default="red", help="filament colour")
    parser.add_argument("--fill", type=float, default=1.0, help="0 is an empty spool, 1 is full")
    parser.add_argument("--flange", default=None, help="spool body colour, seeded if not given")
    parser.add_argument("--kilos", type=int, default=1, choices=(1, 5), help="1 for a spool, 5 for a bulk reel")


def build(args, rng):
    builder = common.MeshBuilder()
    bulk = args.kilos > 1
    radius, width = (BULK_RADIUS, BULK_WIDTH) if bulk else (RADIUS, WIDTH)
    hub = RADIUS * 0.45
    segments = 16 if bulk else SEGMENTS
    flange = args.flange or rng.choice(("charcoal", "ink", "slate"))
    centre = (0, 0, radius)
    for side in (-1, 1):
        offset = side * (width - FLANGE) / 2
        builder.cylinder(radius, FLANGE, (0, offset, radius), flange, segments=segments, axis="Y")
    builder.cylinder(hub, width - FLANGE, centre, flange, segments=segments, axis="Y")
    if args.fill > 0:
        wound = hub + (radius * 0.93 - hub) * min(args.fill, 1.0)
        builder.cylinder(wound, width - FLANGE * 2, centre, args.colour, segments=segments, axis="Y")
    builder.cylinder(RADIUS * 0.26, width + 0.004, centre, "cream", segments=8, axis="Y")
    if bulk:
        # A cardboard reel has a ring of the filament's colour on each face, so its kind shows side on.
        for side in (-1, 1):
            builder.cylinder(RADIUS * 0.62, 0.003, (0, side * (width / 2 + 0.0005), radius), args.colour, segments=segments, axis="Y")
            builder.cylinder(RADIUS * 0.4, 0.004, (0, side * (width / 2 + 0.001), radius), flange, segments=segments, axis="Y")
    builder.finish(args.out.stem)


if __name__ == "__main__":
    common.run(sys.modules[__name__])
