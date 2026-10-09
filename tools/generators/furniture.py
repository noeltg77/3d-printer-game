"""Furniture generator: shelving, filament rack, workbench, packing station, finishing bench, desk, chair.

The finishing bench's blowtorch is a separate object (`torch`, with its `flame`
beneath it) so the game can pick it up and light it.

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
# Functions that add a variant's moving parts, called with its mesh object once that exists.
_pending_parts = []
# Turns a spool so its axle runs along X.
SIDEWAYS = (0.0, 0.0, math.pi / 2)


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="shelving")
    parser.add_argument("--colour", default="teal", help="accent colour (chair fabric)")
    parser.add_argument("--tiers", type=int, default=5, help="filament rack rows")
    parser.add_argument("--per-tier", type=int, default=14, help="filament rack spools per row")
    parser.add_argument("--bays", type=int, default=1, help="shelving bays side by side, 1.2 m each")
    parser.add_argument("--width", type=float, default=1.6, help="workbench width")


def build(args, rng):
    builder = MeshBuilder()
    _pending_markers.clear()
    _pending_parts.clear()
    VARIANTS[args.variant](builder, args, rng)
    obj = builder.finish(args.out.stem)
    for name, position, rotation in _pending_markers:
        marker(name, position, obj, rotation=rotation)
    for add_part in _pending_parts:
        add_part(obj)


def _shelving(builder, args, rng):
    """Metal rack, 1.2 wide for each bay, 0.45 deep and 1.8 tall. Shelf tops are at 0.13 + n * 0.55.

    Markers `item_slot_1..N`: three across each bay of each shelf, top shelf first.
    """
    bay = 1.2
    width, depth, height = bay * args.bays, 0.45, 1.8
    slot = 1
    for level in reversed(range(4)):
        for index in range(args.bays):
            for x in (-0.36, 0.0, 0.36):
                centre = (index - (args.bays - 1) / 2) * bay + x
                _pending_markers.append((f"item_slot_{slot}", (centre, 0, 0.13 + level * 0.55), (0.0, 0.0, 0.0)))
                slot += 1
    # A pair of posts at each end and wherever two bays meet.
    for index in range(args.bays + 1):
        x = -width / 2 + index * bay
        x = min(max(x, -width / 2 + 0.02), width / 2 - 0.02)
        for y in (-1, 1):
            builder.box((0.04, 0.04, height), (x, y * (depth / 2 - 0.02), height / 2), "metal_dark")
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
        # A bar across each end frame carries the rails, or they hang in mid-air between the posts.
        for x in (-1, 1):
            builder.box((0.03, depth, 0.03), (x * (width / 2 - 0.015), 0, z), "charcoal")
        builder.cylinder(0.008, width - 0.03, (0, depth / 2 - 0.015, z + 0.15), "charcoal", segments=6, axis="X")
        for index in range(per_tier):
            x = (index - (per_tier - 1) / 2) * pitch
            _pending_markers.append((f"spool_slot_{slot}", (x, 0, z - drop), SIDEWAYS))
            slot += 1


def _workbench(builder, args, rng):
    """Chunky wooden bench, 1.6 x 0.7 unless given a width, top at 0.9, with a pegboard and hung tools."""
    width, depth, height = args.width, 0.7, 0.9
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
    slots = round(6 * width / 1.6)
    for slot in range(slots):
        x = (slot - (slots - 1) / 2) * (width - 0.3) / (slots - 1) + rng.uniform(-0.02, 0.02)
        handle = rng.uniform(0.09, 0.14)
        blade = rng.uniform(0.08, 0.16)
        top = height + 0.5
        builder.box((0.035, 0.02, handle), (x, tool_y, top - handle / 2), rng.choice(TOOL_COLOURS), bevel=0.004)
        builder.box((rng.uniform(0.02, 0.06), 0.01, blade), (x, tool_y, top - handle - blade / 2), "metal_light")


def _bench_frame(builder, width, depth, height, top="wood"):
    """Legs, a low shelf and a top, in the workbench's style."""
    builder.box((width, depth, 0.07), (0, 0, height - 0.035), top, bevel=0.012)
    for x in (-1, 1):
        for y in (-1, 1):
            builder.box((0.09, 0.09, height - 0.07), (x * (width / 2 - 0.09), y * (depth / 2 - 0.08), (height - 0.07) / 2), "wood_dark")
    builder.box((width - 0.12, depth - 0.1, 0.03), (0, 0, 0.22), "wood_light")
    builder.box((width - 0.12, 0.04, 0.1), (0, -depth / 2 + 0.08, height - 0.12), "wood_dark")


def _packing_station(builder, args, rng):
    """Packing bench, 1.7 x 0.7, top at 0.9, with pigeonholes along the back for the packaging.

    Markers: `stock_slot_1` to `stock_slot_8`, the floors of the pigeonholes,
    and `pack_spot`, where an order is packed.
    """
    width, depth, height = 1.7, 0.7, 0.9
    _bench_frame(builder, width, depth, height)
    # Pigeonholes: two rows of four, open to the front.
    columns, rows = 4, 2
    cell_w, cell_h, cell_d = (width - 0.06) / columns, 0.21, 0.27
    back_y = depth / 2 - cell_d / 2 - 0.01
    unit_h = rows * cell_h + 0.03
    builder.box((width, 0.02, unit_h), (0, depth / 2 - 0.01, height + unit_h / 2), "wood_dark")
    for column in range(columns + 1):
        x = -width / 2 + 0.03 + column * cell_w
        builder.box((0.025, cell_d, unit_h), (x, back_y, height + unit_h / 2), "wood")
    for row in range(1, rows + 1):
        builder.box((width, cell_d + 0.02, 0.025), (0, back_y, height + row * cell_h + 0.0125), "wood")
    slot = 1
    for row in range(rows):
        for column in range(columns):
            x = -width / 2 + 0.03 + (column + 0.5) * cell_w
            floor = height + row * cell_h + (0.025 if row > 0 else 0.0)
            _pending_markers.append((f"stock_slot_{slot}", (x, back_y - 0.01, floor), (0, 0, 0)))
            slot += 1
    # A cutting mat to pack on, a tape gun and a roll of labels.
    builder.box((0.5, 0.34, 0.006), (0, -0.14, height + 0.003), "teal")
    _pending_markers.append(("pack_spot", (0, -0.14, height + 0.006), (0, 0, 0)))
    builder.box((0.11, 0.05, 0.05), (0.55, -0.2, height + 0.025), "red", bevel=0.008)
    builder.cylinder(0.04, 0.045, (0.52, -0.2, height + 0.075), "tape", axis="Y")
    builder.cylinder(0.035, 0.07, (-0.6, -0.18, height + 0.035), "white")
    builder.cylinder(0.012, 0.075, (-0.6, -0.18, height + 0.0375), "cardboard_dark")
    # A roll of bubble wrap and a spare box on the shelf underneath.
    builder.cylinder(0.11, 0.6, (-0.3, 0, 0.345), "sky", axis="X", segments=10)
    builder.box((0.36, 0.3, 0.22), (0.45, 0, 0.345), "cardboard")


def _finishing_bench(builder, args, rng):
    """Finishing bench, 1.3 x 0.65, top at 0.9: a heatproof slab to work on, a gas bottle and a blowtorch.

    Marker: `work_spot`, where the print sits. Objects: `torch`, on its stand
    with the nozzle pointing down at the slab, and `flame` under it.
    """
    width, depth, height = 1.3, 0.65, 0.9
    _bench_frame(builder, width, depth, height)
    # A low back with a rail of files and brushes.
    board_y = depth / 2 - 0.02
    builder.box((width, 0.03, 0.34), (0, board_y, height + 0.17), "slate")
    builder.box((width, 0.05, 0.04), (0, board_y, height + 0.34), "wood_dark")
    for slot in range(4):
        x = -0.12 + slot * 0.13 + rng.uniform(-0.01, 0.01)
        handle = rng.uniform(0.07, 0.1)
        builder.box((0.03, 0.02, handle), (x, board_y - 0.025, height + 0.28 - handle / 2), rng.choice(TOOL_COLOURS), bevel=0.004)
        builder.box((0.018, 0.01, 0.1), (x, board_y - 0.025, height + 0.28 - handle - 0.05), "metal_light")
    # The slab, on a steel tray.
    builder.box((0.52, 0.4, 0.012), (-0.05, -0.06, height + 0.006), "metal_dark")
    builder.box((0.46, 0.34, 0.03), (-0.05, -0.06, height + 0.027), "stone", bevel=0.004)
    _pending_markers.append(("work_spot", (-0.05, -0.06, height + 0.042), (0, 0, 0)))
    # Gas bottle at the back left.
    builder.cylinder(0.07, 0.24, (-0.5, 0.14, height + 0.12), "blue", segments=10)
    builder.cylinder(0.03, 0.05, (-0.5, 0.14, height + 0.265), "metal_light")
    builder.cylinder(0.045, 0.012, (-0.5, 0.14, height + 0.29), "red", segments=6)
    # The torch's stand at the right: a post with a cradle.
    stand = (0.45, -0.05)
    builder.box((0.14, 0.12, 0.015), (stand[0], stand[1], height + 0.0075), "metal_dark")
    builder.box((0.02, 0.02, 0.14), (stand[0] + 0.04, stand[1], height + 0.085), "metal_dark")
    builder.box((0.07, 0.03, 0.015), (stand[0] + 0.01, stand[1], height + 0.15), "metal_dark")

    def add_torch(parent):
        # Built about its grip, leaning so the nozzle points down and to the left.
        grip = (stand[0], stand[1], height + 0.2)
        lean = (0.0, math.radians(-125.0), 0.0)
        along = (math.sin(lean[1]), 0.0, math.cos(lean[1]))

        def at(distance):
            return tuple(g + a * distance for g, a in zip(grip, along))

        torch = MeshBuilder()
        torch.cylinder(0.028, 0.13, at(-0.03), "red", rotation=lean, segments=8)
        torch.cylinder(0.018, 0.03, at(0.05), "metal_dark", rotation=lean, segments=8)
        torch.cylinder(0.012, 0.09, at(0.105), "metal_light", rotation=lean, segments=6)
        torch.cylinder(0.017, 0.03, at(0.16), "metal_light", rotation=lean, segments=6)
        torch.box((0.02, 0.03, 0.03), at(0.03), "ink", rotation=lean)
        torch_obj = torch.finish("torch", pivot=grip, parent=parent)
        tip = at(0.175)
        flame = MeshBuilder()
        flame.cylinder(0.022, 0.13, tuple(t + a * 0.065 for t, a in zip(tip, along)), "orange", rotation=lean, segments=6, radius_top=0.002)
        flame.cylinder(0.013, 0.08, tuple(t + a * 0.045 for t, a in zip(tip, along)), "yellow", rotation=lean, segments=6, radius_top=0.001)
        flame.finish("flame", pivot=tip, parent=torch_obj)

    _pending_parts.append(add_torch)


def _printer_rack(builder, args, rng):
    """Open rack that stacks printers: `--tiers` shelves, one printer to each, 0.8 x 0.68.

    Posts and shelves only, so the printers show from the front and the side.
    Markers: `printer_spot_1` (the lowest shelf) upwards.
    """
    width, depth, pitch = 0.8, 0.68, 0.88
    tiers = args.tiers
    first = 0.26 if tiers <= 2 else 0.1
    top = first + tiers * pitch
    half_x, half_y = width / 2 - 0.025, depth / 2 - 0.025
    for x in (-half_x, half_x):
        for y in (-half_y, half_y):
            builder.box((0.05, 0.05, top), (x, y, top / 2), "charcoal")
            builder.cylinder(0.03, 0.02, (x, y, 0.01), "ink", segments=6)
    # The back is closed in, pale so the printers stand out against it.
    builder.box((width - 0.06, 0.015, top - first), (0, half_y, (top + first) / 2), "metal_light")
    for tier in range(tiers):
        z = first + tier * pitch
        builder.box((width, depth, 0.035), (0, 0, z - 0.0175), "slate", bevel=0.004)
        # A strip light under the shelf above.
        builder.box((width - 0.12, 0.02, 0.012), (0, -half_y + 0.03, z + pitch - 0.045), args.colour)
        _pending_markers.append((f"printer_spot_{tier + 1}", (0, 0.0, z), (0, 0, 0)))
    builder.box((width, depth, 0.05), (0, 0, top - 0.025), "charcoal", bevel=0.006)
    if tiers <= 2:
        # Room underneath for a drawer.
        builder.box((width - 0.08, depth - 0.06, first - 0.08), (0, 0, (first - 0.035) / 2 + 0.02), "charcoal", bevel=0.006)
        builder.box((0.26, 0.012, 0.03), (0, -depth / 2 + 0.025, first * 0.5), "metal_light")


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


VARIANTS = {"shelving": _shelving, "filament_rack": _filament_rack, "workbench": _workbench, "packing_station": _packing_station,
            "finishing_bench": _finishing_bench, "printer_rack": _printer_rack, "desk": _desk, "chair": _chair}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
