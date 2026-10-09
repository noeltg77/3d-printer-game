"""Packaging generator: the boxes, bags and envelopes orders go out in (data/packaging.json).

Each kind is built twice: made up as a parcel, and as a flat pile for the
packing station's shelves (`--variant stack`).

A parcel's flaps are separate objects hinged on the edge they are named for
(`flap_xp` on the +X edge, `flap_xn`, `flap_yp`, `flap_yn`), built shut, so the
game can lay the packaging open and close it. A box has four, a letterbox box
one lid, and a bag one flap over its end.

blender --background --factory-startup --python tools/generators/parcels.py -- \
    --kind box --size 0.26 0.2 0.14 --out assets/models/packaging/small_cardboard_box.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder

CARD = 0.008
# A box this shallow has one lid rather than four flaps.
LID_BELOW = 0.08
# Every pile is this size, whatever it is a pile of, to fit the station's shelves.
STACK_SIZE = (0.26, 0.2)


def add_arguments(parser):
    parser.add_argument("--variant", choices=("parcel", "stack"), default="parcel")
    parser.add_argument("--kind", choices=("box", "bag"), default="box")
    parser.add_argument("--size", type=float, nargs=3, default=(0.26, 0.2, 0.14), metavar=("W", "D", "H"))
    parser.add_argument("--colour", default="cardboard")
    parser.add_argument("--accent", default="tape", help="tape, seal or printed band")


def build(args, rng):
    if args.variant == "stack":
        _stack(args, rng)
    elif args.kind == "bag":
        _bag(args)
    else:
        _box(args)


def _flap(parent, name, size, centre, pivot, colour, trim=None):
    """One flap, shut. `trim` is an optional (size, centre, colour) strip on it."""
    flap = MeshBuilder()
    flap.box(size, centre, colour)
    if trim is not None:
        flap.box(*trim)
    flap.finish(name, pivot=pivot, parent=parent)


def _box(args):
    width, depth, height = args.size
    colour, accent = args.colour, args.accent
    body = MeshBuilder()
    body.tray((width, depth, height), CARD, colour)
    if accent != "tape":
        # A printed band right round, proud of the card.
        body.tray((width + 0.004, depth + 0.004, height * 0.3), 0.002, accent, centre=(0, 0, height * 0.35), floor=0.0)
    if height >= LID_BELOW:
        body.box((width * 0.34, 0.004, height * 0.34), (-width * 0.16, -depth / 2 - 0.002, height * 0.55), "white")
    body_obj = body.finish(args.out.stem)

    if height < LID_BELOW:
        _flap(body_obj, "flap_yp", (width, depth, CARD), (0, 0, height + CARD / 2), (0, depth / 2, height), colour,
              trim=((width * 0.3, depth * 0.4, 0.003), (-width * 0.15, 0, height + CARD + 0.0015), "white"))
        return
    # The end flaps fold in first and the side flaps over them, taped along the seam.
    for side, name in ((1, "flap_yp"), (-1, "flap_yn")):
        _flap(body_obj, name, (width - 0.004, depth / 2, CARD), (0, side * depth / 4, height + CARD / 2),
              (0, side * depth / 2, height), colour)
    top = height + CARD
    for side, name in ((1, "flap_xp"), (-1, "flap_xn")):
        _flap(body_obj, name, (width / 2, depth - 0.004, CARD), (side * width / 4, 0, top + CARD / 2),
              (side * width / 2, 0, top), colour,
              trim=((0.02, depth - 0.004, 0.003), (side * 0.01, 0, top + CARD + 0.0015), accent))


def _bag(args):
    width, depth, height = args.size
    colour, accent = args.colour, args.accent
    body = MeshBuilder()
    body.box((width, depth, height), (0, 0, height / 2), colour, bevel=min(0.008, height / 3))
    body.box((width * 0.3, depth * 0.42, 0.003), (-width * 0.14, 0, height + 0.0015), "white")
    body_obj = body.finish(args.out.stem)
    reach = width * 0.26
    _flap(body_obj, "flap_xp", (reach, depth, 0.006), (width / 2 - reach / 2, 0, height + 0.003), (width / 2, 0, height), colour,
          trim=((0.014, depth * 0.9, 0.003), (width / 2 - reach + 0.01, 0, height + 0.0075), accent))


def _stack(args, rng):
    """A pile of the packaging, flat, as it is kept until it is needed."""
    width, depth = STACK_SIZE
    sheet = 0.007 if args.kind == "bag" else 0.012
    count = 7 if args.kind == "bag" else 5
    builder = MeshBuilder()
    z = 0.0
    for index in range(count):
        turn = math.radians(rng.uniform(-5.0, 5.0))
        centre = (rng.uniform(-0.008, 0.008), rng.uniform(-0.008, 0.008), z + sheet / 2)
        builder.box((width, depth, sheet - 0.001), centre, args.colour, rotation=(0, 0, turn))
        if index == count - 1 and args.accent != "tape":
            builder.box((width * 0.2, depth, 0.002), (centre[0] + width * 0.3, centre[1], z + sheet + 0.0005), args.accent,
                        rotation=(0, 0, turn))
        z += sheet
    builder.finish(args.out.stem)


if __name__ == "__main__":
    common.run(sys.modules[__name__])
