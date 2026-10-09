"""Printer generator: open frame bed slinger, enclosed core XY, multicolour unit.

Moving parts are separate objects so the game can animate them:
  open_frame: frame > bed (slides Y), frame > gantry (lifts Z) > toolhead (slides X)
  enclosed:   frame > bed (drops Z), frame > gantry (slides Y) > toolhead (slides X)
Markers: `plate` (where prints grow), `spool_mount`, `unit_mount`, and on the
multicolour unit `spool_slot_1..4` and `link_mount` (where the next unit stacks).

blender --background --factory-startup --python tools/generators/printers.py -- \
    --variant open_frame --colour orange --out assets/models/printers/printer_open_frame.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder, marker

QUARTER_TURN = (0.0, 0.0, math.pi / 2)


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="open_frame")
    parser.add_argument("--colour", default="orange", help="accent colour")
    parser.add_argument("--body", default="slate", help="panel colour")


def build(args, rng):
    VARIANTS[args.variant](args)


def _feet(builder, half_x, half_y):
    for x in (-half_x, half_x):
        for y in (-half_y, half_y):
            builder.box((0.05, 0.05, 0.012), (x, y, 0.006), "ink")


def _toolhead(parent, position, accent, size=(0.07, 0.055, 0.085)):
    x, y, z = position
    head = MeshBuilder()
    head.box(size, position, accent, bevel=0.007)
    head.box((size[0] * 0.6, 0.004, size[2] * 0.5), (x, y - size[1] / 2 - 0.002, z + 0.005), "ink")
    head.cylinder(0.004, 0.03, (x, y, z - size[2] / 2 - 0.015), "yellow", segments=6, radius_top=0.014)
    return head.finish("toolhead", pivot=position, parent=parent)


def _open_frame(args):
    accent = args.colour
    frame = MeshBuilder()
    frame.box((0.44, 0.46, 0.07), (0, 0, 0.047), "charcoal", bevel=0.008)
    _feet(frame, 0.17, 0.19)
    for side in (-1, 1):
        frame.box((0.04, 0.04, 0.5), (side * 0.2, 0.05, 0.33), args.body)
    frame.box((0.44, 0.04, 0.04), (0, 0.05, 0.6), args.body)
    frame.box((0.18, 0.004, 0.022), (-0.1, -0.232, 0.047), accent)
    # Tilted screen on the front right corner.
    tilt = math.radians(-25)
    frame.box((0.11, 0.03, 0.07), (0.15, -0.235, 0.1), "ink", rotation=(tilt, 0, 0), bevel=0.004)
    normal = (0, -math.cos(tilt), -math.sin(tilt))
    screen = tuple(c + n * 0.016 for c, n in zip((0.15, -0.235, 0.1), normal))
    frame.box((0.085, 0.004, 0.045), screen, "sky", rotation=(tilt, 0, 0))
    # Cradle on the top bar for the spool.
    frame.box((0.1, 0.09, 0.02), (0, 0.05, 0.63), "charcoal")
    frame_obj = frame.finish("frame")
    marker("spool_mount", (0, 0.05, 0.64), frame_obj)
    marker("unit_mount", (0, 0.05, 0.64), frame_obj)

    bed = MeshBuilder()
    bed.box((0.08, 0.3, 0.02), (0, 0, 0.092), "metal_dark")
    bed.box((0.25, 0.25, 0.012), (0, 0, 0.108), "ink", bevel=0.003)
    bed_obj = bed.finish("bed", pivot=(0, 0, 0.082), parent=frame_obj)
    marker("plate", (0, 0, 0.114), bed_obj)

    height = 0.36
    gantry = MeshBuilder()
    gantry.box((0.48, 0.03, 0.04), (0, 0.015, height), "metal_light")
    gantry.box((0.05, 0.06, 0.07), (-0.24, 0.02, height), "ink", bevel=0.005)
    gantry_obj = gantry.finish("gantry", pivot=(0, 0, height), parent=frame_obj)
    _toolhead(gantry_obj, (0.05, -0.028, height + 0.005), accent)


def _enclosed(args):
    accent, body = args.colour, args.body
    size, half = 0.42, 0.21
    frame = MeshBuilder()
    frame.box((size, size, 0.07), (0, 0, 0.047), "charcoal", bevel=0.01)
    _feet(frame, 0.16, 0.16)
    frame.box((size, size, 0.06), (0, 0, 0.47), "charcoal", bevel=0.01)
    # Panels: body colour outside, pale inside so prints stay readable.
    back = frame.box((size, 0.02, 0.36), (0, half - 0.01, 0.26), body)
    frame.paint(back, "metal_light", facing=(0, -1, 0))
    for side in (-1, 1):
        panel = frame.box((0.02, size, 0.36), (side * (half - 0.01), 0, 0.26), body)
        frame.paint(panel, "metal_light", facing=(-side, 0, 0))
        frame.box((0.03, 0.03, 0.36), (side * (half - 0.015), -half + 0.015, 0.26), "charcoal")
    frame.box((size - 0.04, size - 0.04, 0.004), (0, 0, 0.084), "metal_dark")
    frame.box((size * 0.55, 0.004, 0.016), (-0.07, -half - 0.002, 0.47), accent)
    frame.box((0.08, 0.004, 0.034), (0.14, -half - 0.002, 0.47), "sky")
    frame.cylinder(0.015, 0.08, (half + 0.04, 0, 0.26), "ink", axis="X")
    frame_obj = frame.finish("frame")
    marker("spool_mount", (half + 0.045, 0, 0.16), frame_obj, rotation=QUARTER_TURN)
    marker("unit_mount", (0, 0, 0.5), frame_obj)

    bed = MeshBuilder()
    bed.box((0.1, 0.08, 0.02), (0, 0.15, 0.185), "metal_dark")
    bed.box((0.27, 0.27, 0.012), (0, 0, 0.2), "ink", bevel=0.003)
    bed_obj = bed.finish("bed", pivot=(0, 0, 0.2), parent=frame_obj)
    marker("plate", (0, 0, 0.206), bed_obj)

    gantry = MeshBuilder()
    gantry.box((0.36, 0.025, 0.025), (0, 0, 0.415), "metal_light")
    gantry_obj = gantry.finish("gantry", pivot=(0, 0, 0.415), parent=frame_obj)
    _toolhead(gantry_obj, (0.04, -0.03, 0.39), accent, size=(0.06, 0.05, 0.07))


def _multicolour_unit(args):
    accent = args.colour
    width, depth = 0.38, 0.27
    unit = MeshBuilder()
    unit.box((width, depth, 0.03), (0, 0, 0.015), "charcoal", bevel=0.006)
    unit.box((width, 0.025, 0.13), (0, depth / 2 - 0.0125, 0.095), "metal_light")
    unit.box((width, 0.025, 0.06), (0, -depth / 2 + 0.0125, 0.06), "metal_light")
    for side in (-1, 1):
        unit.box((0.02, depth, 0.1), (side * (width / 2 - 0.01), 0, 0.08), "metal_light")
    unit.box((width * 0.9, 0.004, 0.012), (0, -depth / 2 - 0.002, 0.045), accent)
    unit_obj = unit.finish(args.out.stem)
    for slot in range(4):
        x = (slot - 1.5) * 0.085
        marker(f"spool_slot_{slot + 1}", (x, 0, 0.03), unit_obj, rotation=QUARTER_TURN)
    # Where a second unit linked to this one sits: clear of the spools.
    marker("link_mount", (0, 0, 0.24), unit_obj)


VARIANTS = {"open_frame": _open_frame, "enclosed": _enclosed, "multicolour_unit": _multicolour_unit}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
