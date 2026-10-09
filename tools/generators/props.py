"""Small prop generator: PC, bin, plant, rug, desk lamp.

blender --background --factory-startup --python tools/generators/props.py -- \
    --variant plant --seed 3 --out assets/models/props/plant.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder

SCREEN_COLOURS = ("orange", "yellow", "pink", "lime", "teal", "white")
SCRAP_COLOURS = ("red", "orange", "yellow", "green", "sky", "purple", "pink")
SIDEWAYS = (0.0, 0.0, math.pi / 2)
_pending_markers = []


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="pc")
    parser.add_argument("--colour", default="terracotta", help="main colour (rug, lamp shade, mug)")


def build(args, rng):
    builder = MeshBuilder()
    _pending_markers.clear()
    VARIANTS[args.variant](builder, args, rng)
    obj = builder.finish(args.out.stem)
    for name, position, rotation in _pending_markers:
        common.marker(name, position, obj, rotation=rotation)


def _pc(builder, args, rng):
    """Everything that sits on the desk: monitor, keyboard, mouse, tower, mug.

    Origin is the middle of the desk top. Screen faces -Y.
    """
    x, y = -0.12, 0.12
    builder.box((0.24, 0.16, 0.016), (x, y, 0.008), "charcoal", bevel=0.004)
    builder.box((0.05, 0.03, 0.15), (x, y + 0.03, 0.085), "charcoal")
    builder.box((0.6, 0.035, 0.36), (x, y, 0.32), "ink", bevel=0.008)
    face = y - 0.0185
    builder.box((0.55, 0.004, 0.31), (x, face, 0.32), "navy")
    # A little shop page: header bar, three listing cards, a sales bar chart.
    builder.box((0.51, 0.004, 0.035), (x, face - 0.002, 0.44), "sky")
    for index, colour in enumerate(rng.sample(SCREEN_COLOURS, 3)):
        builder.box((0.15, 0.004, 0.11), (x + (index - 1) * 0.18, face - 0.002, 0.345), colour)
    for index in range(8):
        bar = rng.uniform(0.02, 0.085)
        builder.box((0.04, 0.004, bar), (x + (index - 3.5) * 0.063, face - 0.002, 0.185 + bar / 2), "green")

    builder.box((0.36, 0.13, 0.018), (x, -0.15, 0.009), "white", bevel=0.004)
    builder.box((0.33, 0.1, 0.004), (x, -0.15, 0.02), "metal_light")
    builder.box((0.055, 0.09, 0.026), (x + 0.28, -0.15, 0.013), "white", bevel=0.008)

    builder.box((0.19, 0.4, 0.4), (0.44, 0.04, 0.2), "charcoal", bevel=0.01)
    builder.box((0.15, 0.004, 0.02), (0.44, -0.162, 0.33), "slate")
    builder.box((0.02, 0.004, 0.02), (0.38, -0.162, 0.36), "green")
    for index in range(4):
        builder.box((0.15, 0.004, 0.012), (0.44, -0.162, 0.08 + index * 0.035), "ink")

    builder.cylinder(0.04, 0.09, (x - 0.38, -0.12, 0.045), args.colour, segments=8)
    builder.cylinder(0.032, 0.004, (x - 0.38, -0.12, 0.091), "wood_dark", segments=8)


def _bin(builder, args, rng):
    """Waste bin with a few failed prints poking out of the top."""
    builder.cylinder(0.15, 0.42, (0, 0, 0.21), "slate", segments=10, radius_top=0.19)
    builder.cylinder(0.17, 0.004, (0, 0, 0.421), "ink", segments=10)
    for _ in range(4):
        angle = rng.uniform(0, math.tau)
        radius = rng.uniform(0.0, 0.1)
        rotation = (rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), rng.uniform(0, math.pi))
        size = (rng.uniform(0.04, 0.09), rng.uniform(0.03, 0.06), rng.uniform(0.08, 0.16))
        builder.box(size, (math.cos(angle) * radius, math.sin(angle) * radius, 0.44), rng.choice(SCRAP_COLOURS), rotation=rotation)


def _plant(builder, args, rng):
    """Potted plant with seeded leaves."""
    builder.cylinder(0.11, 0.24, (0, 0, 0.12), "terracotta", segments=8, radius_top=0.15)
    builder.cylinder(0.165, 0.045, (0, 0, 0.245), "terracotta", segments=8)
    builder.cylinder(0.14, 0.004, (0, 0, 0.269), "wood_dark", segments=8)
    leaves = rng.randint(7, 9)
    for index in range(leaves):
        # The first few leaves stand upright in the middle, the rest fan out.
        upright = index < 3
        tilt = math.radians(rng.uniform(5, 18) if upright else rng.uniform(30, 60))
        yaw = index / leaves * math.tau + rng.uniform(-0.3, 0.3)
        length = rng.uniform(0.4, 0.55) if upright else rng.uniform(0.28, 0.42)
        direction = (math.sin(tilt) * math.sin(yaw), -math.sin(tilt) * math.cos(yaw), math.cos(tilt))
        centre = tuple(base + axis * length / 2 for base, axis in zip((0, 0, 0.26), direction))
        builder.box((0.11, 0.02, length), centre, rng.choice(("green", "green", "lime")), rotation=(tilt, 0, yaw), taper=(0.15, 1.0))


def _rug(builder, args, rng):
    """Flat rug, 2.2 x 1.5, with a border and two stripes."""
    builder.box((2.2, 1.5, 0.012), (0, 0, 0.006), args.colour)
    builder.box((2.0, 1.3, 0.004), (0, 0, 0.014), "cream")
    builder.box((1.8, 1.1, 0.004), (0, 0, 0.016), args.colour)
    for side in (-1, 1):
        builder.box((0.08, 1.1, 0.004), (side * 0.55, 0, 0.018), "tape")


def _floor_mat(builder, args, rng):
    """Marked square on the floor showing where parcels wait for the courier."""
    builder.box((0.9, 0.9, 0.008), (0, 0, 0.004), "charcoal")
    builder.box((0.8, 0.8, 0.004), (0, 0, 0.01), args.colour)
    builder.box((0.66, 0.66, 0.004), (0, 0, 0.012), "charcoal")


def _desk_lamp(builder, args, rng):
    """Desk lamp with the shade leaning over the front (-Y)."""
    builder.cylinder(0.075, 0.02, (0, 0, 0.01), "charcoal", segments=8)
    builder.box((0.02, 0.02, 0.32), (0, 0.03, 0.17), "charcoal", rotation=(math.radians(10), 0, 0))
    builder.box((0.02, 0.22, 0.02), (0, -0.04, 0.36), "charcoal", rotation=(math.radians(-20), 0, 0))
    builder.cylinder(0.08, 0.1, (0, -0.16, 0.35), args.colour, segments=8, radius_top=0.03)
    builder.cylinder(0.06, 0.004, (0, -0.16, 0.298), "white", segments=8)


def _dryer(builder, args, rng):
    """Filament dryer: a warm box on short legs with a cradle for two spools on top.

    Markers `spool_slot_1` and `spool_slot_2` sit side by side in the cradle.
    """
    width, depth, top = 0.4, 0.32, 0.52
    for x in (-1, 1):
        for y in (-1, 1):
            builder.box((0.04, 0.04, 0.12), (x * (width / 2 - 0.04), y * (depth / 2 - 0.04), 0.06), "charcoal")
    builder.box((width, depth, top - 0.12), (0, 0, 0.12 + (top - 0.12) / 2), "cream", bevel=0.02, bevel_segments=2)
    builder.box((width + 0.02, depth + 0.02, 0.03), (0, 0, 0.135), "charcoal", bevel=0.008)
    # Front: vent slots, a dial and a little warm display.
    front = -depth / 2 - 0.004
    for index in range(4):
        builder.box((0.16, 0.01, 0.014), (-0.08, front, 0.24 + index * 0.035), "charcoal")
    builder.cylinder(0.035, 0.02, (0.1, front - 0.006, 0.3), args.colour, segments=10, axis="Y")
    builder.box((0.012, 0.012, 0.03), (0.1, front - 0.018, 0.312), "white")
    builder.box((0.09, 0.01, 0.04), (0.1, front, 0.4), "ink")
    builder.box((0.06, 0.012, 0.018), (0.1, front - 0.002, 0.4), args.colour)
    # Cradle on top: two end cheeks and a pair of rails the spools rest on.
    for x in (-1, 1):
        builder.box((0.02, 0.2, 0.07), (x * 0.115, 0, top + 0.035), "charcoal", bevel=0.006)
    rail_gap, rail_radius, spool_radius = 0.06, 0.012, 0.1
    for y in (-rail_gap, rail_gap):
        builder.cylinder(rail_radius, 0.23, (0, y, top + 0.04), "charcoal", segments=6, axis="X")
    rest = (spool_radius + rail_radius) ** 2 - rail_gap ** 2
    drop = spool_radius - rest ** 0.5
    for slot, x in enumerate((-0.045, 0.045), start=1):
        _pending_markers.append((f"spool_slot_{slot}", (x, 0, top + 0.04 - drop), SIDEWAYS))


VARIANTS = {"dryer": _dryer, "pc": _pc, "bin": _bin, "plant": _plant, "rug": _rug, "desk_lamp": _desk_lamp, "floor_mat": _floor_mat}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
