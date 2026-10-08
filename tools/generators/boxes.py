"""Cardboard box generator: delivery boxes, packing boxes, stock boxes.

blender --background --factory-startup --python tools/generators/boxes.py -- \
    --seed 1 --variant closed --out assets/models/props/box_closed_01.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common

THICKNESS = 0.012


def add_arguments(parser):
    parser.add_argument("--variant", choices=("closed", "open"), default="closed")
    parser.add_argument("--size", type=float, nargs=3, default=(0.4, 0.3, 0.28), metavar=("W", "D", "H"))
    parser.add_argument("--colour", default="cardboard")


def build(args, rng):
    builder = common.MeshBuilder()
    colour = args.colour
    width, depth, height = (dimension * rng.uniform(0.92, 1.08) for dimension in args.size)
    builder.box((width, depth, height), (0, 0, height / 2), colour)

    if args.variant == "closed":
        tape_width = min(width, depth) * 0.16
        drop = height * rng.uniform(0.2, 0.35)
        builder.box((width + 0.006, tape_width, 0.004), (0, 0, height + 0.002), "tape")
        for side in (-1, 1):
            builder.box((0.004, tape_width, drop), (side * (width / 2 + 0.002), 0, height - drop / 2), "tape")
        label = (width * 0.34, height * 0.3)
        label_x = rng.uniform(-0.5, 0.5) * (width - label[0] - 0.04)
        builder.box((label[0], 0.004, label[1]), (label_x, -depth / 2 - 0.002, height * 0.58), "white")
    else:
        # Dark inset on top reads as the open inside without needing a hollow mesh.
        builder.box((width - THICKNESS * 2, depth - THICKNESS * 2, 0.004), (0, 0, height + 0.002), "wood_dark")
        for axis, side in ((0, 1), (0, -1), (1, 1), (1, -1)):
            _flap(builder, rng, (width, depth, height), axis, side, colour)
    builder.finish(args.out.stem)


def _flap(builder, rng, size, axis, side, colour):
    """One top flap hinged on the box edge, folded out at a seeded angle."""
    width, depth, height = size
    length = (width if axis == 0 else depth) / 2 - 0.005
    # Angle above horizontal: positive sticks up, negative hangs down the side.
    angle = math.radians(rng.choice((rng.uniform(35, 80), rng.uniform(-75, -40))))
    reach = math.cos(angle) * length / 2
    lift = height + math.sin(angle) * length / 2
    if axis == 0:
        centre = (side * (width / 2 + reach), 0, lift)
        builder.box((length, depth, THICKNESS), centre, colour, rotation=(0, -side * angle, 0))
    else:
        centre = (0, side * (depth / 2 + reach), lift)
        builder.box((width, length, THICKNESS), centre, colour, rotation=(side * angle, 0, 0))


if __name__ == "__main__":
    common.run(sys.modules[__name__])
