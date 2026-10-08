"""Furniture generator: shelving, filament rack, workbench, desk, chair.

blender --background --factory-startup --python tools/generators/furniture.py -- \
    --variant shelving --out assets/models/furniture/shelving.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder, marker

TOOL_COLOURS = ("red", "orange", "yellow", "teal", "blue", "green")
# (name, position, rotation) of markers a variant wants, added once its mesh object exists.
_pending_markers = []
# Turns a spool so its axle runs along X.
SIDEWAYS = (0.0, 0.0, math.pi / 2)


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="shelving")
    parser.add_argument("--colour", default="teal", help="accent colour (chair fabric)")
    parser.add_argument("--tiers", type=int, default=5, help="filament rack rows")
    parser.add_argument("--per-tier", type=int, default=14, help="filament rack spools per row")


def build(args, rng):
    builder = MeshBuilder()
    _pending_markers.clear()
    VARIANTS[args.variant](builder, args, rng)
    obj = builder.finish(args.out.stem)
    for name, position, rotation in _pending_markers:
        marker(name, position, obj, rotation=rotation)


def _shelving(builder, args, rng):
    """Metal rack, 1.2 x 0.45 x 1.8. Shelf tops are at 0.13 + n * 0.55.

    Markers `item_slot_1..12`: three across each shelf, top shelf first.
    """
    width, depth, height = 1.2, 0.45, 1.8
    slot = 1
    for level in reversed(range(4)):
        for x in (-0.36, 0.0, 0.36):
            _pending_markers.append((f"item_slot_{slot}", (x, 0, 0.13 + level * 0.55), (0.0, 0.0, 0.0)))
            slot += 1
    for x in (-1, 1):
        for y in (-1, 1):
            builder.box((0.04, 0.04, height), (x * (width / 2 - 0.02), y * (depth / 2 - 0.02), height / 2), "metal_dark")
    for level in range(4):
        z = 0.1 + level * 0.55
        builder.box((width - 0.02, depth - 0.02, 0.03), (0, 0, z + 0.015), "wood_light")
        builder.box((width, 0.02, 0.05), (0, -depth / 2 + 0.01, z), "metal_dark")
        builder.box((width, 0.02, 0.05), (0, depth / 2 - 0.01, z), "metal_dark")


def _filament_rack(builder, args, rng):
    """Spool rack: `--tiers` rows of rails with `--per-tier` spools side by side on each.

    The default 5 x 14 is 1.2 wide and 1.72 tall. Markers `spool_slot_1..N` run
    left to right, top tier first.
    """
    tiers, per_tier, pitch = args.tiers, args.per_tier, 0.078
    width, depth, height = per_tier * pitch + 0.108, 0.32, 0.44 + (tiers - 1) * 0.32
    rail_gap, rail_radius, spool_radius = 0.06, 0.012, 0.1
    for x in (-1, 1):
        post_x = x * (width / 2 - 0.015)
        for y in (-1, 1):
            builder.box((0.03, 0.03, height - 0.05), (post_x, y * (depth / 2 - 0.015), 0.05 + (height - 0.05) / 2), "charcoal")
            builder.box((0.05, 0.05, 0.05), (post_x, y * (depth / 2 - 0.015), 0.025), "ink")
        builder.box((0.03, depth, 0.03), (post_x, 0, height - 0.015), "charcoal")
        builder.box((0.03, depth, 0.03), (post_x, 0, 0.09), "charcoal")
    # A spool rests in the V between two rails, so its base sits a little below them.
    rest = (spool_radius + rail_radius) ** 2 - rail_gap ** 2
    drop = spool_radius - rest ** 0.5
    slot = 1
    for tier in reversed(range(tiers)):
        z = 0.14 + tier * 0.32
        for y in (-rail_gap, rail_gap):
            builder.cylinder(rail_radius, width - 0.03, (0, y, z), "charcoal", segments=6, axis="X")
        builder.cylinder(0.008, width - 0.03, (0, depth / 2 - 0.015, z + 0.15), "charcoal", segments=6, axis="X")
        for index in range(per_tier):
            x = (index - (per_tier - 1) / 2) * pitch
            _pending_markers.append((f"spool_slot_{slot}", (x, 0, z - drop), SIDEWAYS))
            slot += 1


def _workbench(builder, args, rng):
    """Chunky wooden bench, 1.6 x 0.7, top at 0.9, with a pegboard and hung tools."""
    width, depth, height = 1.6, 0.7, 0.9
    builder.box((width, depth, 0.07), (0, 0, height - 0.035), "wood", bevel=0.012)
    for x in (-1, 1):
        for y in (-1, 1):
            builder.box((0.09, 0.09, height - 0.07), (x * (width / 2 - 0.09), y * (depth / 2 - 0.08), (height - 0.07) / 2), "wood_dark")
    builder.box((width - 0.12, depth - 0.1, 0.03), (0, 0, 0.22), "wood_light")
    builder.box((width - 0.12, 0.04, 0.1), (0, -depth / 2 + 0.08, height - 0.12), "wood_dark")

    # Pegboard behind the top, with a frame and a row of tools.
    board_y = depth / 2 - 0.02
    builder.box((width, 0.03, 0.62), (0, board_y, height + 0.31), "linen")
    builder.box((width, 0.05, 0.04), (0, board_y, height + 0.62), "wood_dark")
    for x in (-1, 1):
        builder.box((0.05, 0.05, 0.64), (x * (width / 2 - 0.025), board_y, height + 0.32), "wood_dark")
    tool_y = board_y - 0.025
    slots = 6
    for slot in range(slots):
        x = (slot - (slots - 1) / 2) * (width - 0.3) / (slots - 1) + rng.uniform(-0.02, 0.02)
        handle = rng.uniform(0.09, 0.14)
        blade = rng.uniform(0.08, 0.16)
        top = height + 0.5
        builder.box((0.035, 0.02, handle), (x, tool_y, top - handle / 2), rng.choice(TOOL_COLOURS), bevel=0.004)
        builder.box((rng.uniform(0.02, 0.06), 0.01, blade), (x, tool_y, top - handle - blade / 2), "metal_light")


def _desk(builder, args, rng):
    """Office desk, 1.3 x 0.65, top at 0.7. Drawers on the right, sit on the -Y side."""
    width, depth, height = 1.3, 0.65, 0.7
    under = height - 0.04
    builder.box((width, depth, 0.04), (0, 0, height - 0.02), "wood_light", bevel=0.008)
    builder.box((0.04, depth - 0.08, under), (-width / 2 + 0.05, 0, under / 2), "white")
    builder.box((width - 0.5, 0.03, 0.3), (-0.2, depth / 2 - 0.06, under - 0.15), "white")
    drawer_x = width / 2 - 0.23
    builder.box((0.4, depth - 0.08, under), (drawer_x, 0, under / 2), "white")
    front = -(depth - 0.08) / 2
    for index in range(3):
        z = 0.06 + (index + 0.5) * (under - 0.08) / 3
        builder.box((0.36, 0.012, (under - 0.08) / 3 - 0.02), (drawer_x, front - 0.006, z), "cream")
        builder.box((0.12, 0.015, 0.02), (drawer_x, front - 0.018, z + 0.04), "metal_dark")


def _chair(builder, args, rng):
    """Office chair, seat top at 0.4 (sized for the short-legged character). Faces -Y."""
    fabric = args.colour
    for size in ((0.56, 0.06, 0.035), (0.06, 0.56, 0.035)):
        builder.box(size, (0, 0, 0.06), "charcoal", bevel=0.008)
    for x, y in ((0.25, 0), (-0.25, 0), (0, 0.25), (0, -0.25)):
        builder.box((0.05, 0.05, 0.045), (x, y, 0.0225), "ink")
    builder.cylinder(0.03, 0.24, (0, 0, 0.19), "metal_light", segments=6)
    builder.box((0.46, 0.46, 0.09), (0, 0, 0.355), fabric, bevel=0.025)
    builder.box((0.06, 0.04, 0.3), (0, 0.24, 0.44), "charcoal")
    builder.box((0.44, 0.08, 0.46), (0, 0.23, 0.74), fabric, bevel=0.025)


VARIANTS = {"shelving": _shelving, "filament_rack": _filament_rack,"workbench": _workbench, "desk": _desk, "chair": _chair}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
