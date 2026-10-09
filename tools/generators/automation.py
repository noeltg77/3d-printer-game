"""Automation generator: the kit that takes finished prints off the printers.

  eject_tray   an open bin that sits on the bench beside a printer and catches
               what its plate throws off. Marker `tray` is the floor of the bin.
  conveyor     an overhead belt hung from the ceiling, running along Y. Origin
               is on the floor under its middle; the belt top is at --height.
               Markers `belt_start` and `belt_end` are the two ends of its top,
               in the direction things travel (towards +Y).
  control_box  the cabinet on a post that the conveyor is run from.
  moulding_bay      the marking on the floor where an injection moulding machine goes.
  moulding_machine  the machine itself: clamp on the left, barrel and hopper on
                    the right, and a bin at the front that the parts drop into.
                    Stands on the bay with its front, the side it is worked
                    from, facing -Y.

blender --background --factory-startup --python tools/generators/automation.py -- \
    --variant conveyor --length 7.6 --out assets/models/automation/conveyor.glb
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder, marker


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="eject_tray")
    parser.add_argument("--length", type=float, default=7.6, help="conveyor length")
    parser.add_argument("--height", type=float, default=2.05, help="height of the conveyor's belt top")
    parser.add_argument("--ceiling", type=float, default=3.6, help="height the conveyor hangs from")
    parser.add_argument("--colour", default="yellow", help="accent colour")


def build(args, rng):
    VARIANTS[args.variant](args)


def _eject_tray(args):
    builder = MeshBuilder()
    builder.tray((0.24, 0.3, 0.1), 0.012, "metal_dark", chamfer=0.004)
    builder.box((0.24, 0.012, 0.03), (0, -0.156, 0.085), args.colour)
    obj = builder.finish(args.out.stem)
    marker("tray", (0, 0, 0.014), obj)


def _conveyor(args):
    length, top, ceiling, width = args.length, args.height, args.ceiling, 0.42
    builder = MeshBuilder()
    # Side rails with the belt lying between them.
    for side in (-1, 1):
        builder.box((0.035, length, 0.1), (side * width / 2, 0, top - 0.03), "metal_dark")
        builder.box((0.012, length, 0.02), (side * (width / 2 + 0.02), 0, top + 0.01), args.colour)
    builder.box((width - 0.03, length - 0.04, 0.03), (0, 0, top - 0.015), "charcoal")
    # A roller at each end and a motor housing at the far one.
    for end in (-1, 1):
        builder.cylinder(0.05, width, (0, end * length / 2, top - 0.03), "metal_light", segments=8, axis="X")
    builder.box((0.16, 0.22, 0.16), (width / 2 + 0.1, length / 2 - 0.2, top - 0.05), args.colour, bevel=0.01)
    # Hangers up to the ceiling, every couple of metres.
    hangers = max(int(length // 2.4) + 1, 2)
    for index in range(hangers):
        y = -length / 2 + 0.3 + index * (length - 0.6) / (hangers - 1)
        builder.box((width + 0.12, 0.04, 0.04), (0, y, top - 0.1), "metal_dark")
        for side in (-1, 1):
            builder.box((0.03, 0.03, ceiling - top + 0.1), (side * (width / 2 + 0.04), y, (ceiling + top - 0.1) / 2), "metal_dark")
    obj = builder.finish(args.out.stem)
    marker("belt_start", (0, -length / 2 + 0.15, top), obj)
    marker("belt_end", (0, length / 2 - 0.15, top), obj)


def _control_box(args):
    builder = MeshBuilder()
    builder.box((0.16, 0.16, 0.02), (0, 0, 0.01), "ink")
    builder.box((0.05, 0.05, 1.0), (0, 0, 0.5), "metal_dark")
    builder.box((0.26, 0.12, 0.34), (0, 0, 1.15), "metal_light", bevel=0.008)
    builder.box((0.2, 0.006, 0.06), (0, -0.062, 1.25), "ink")
    builder.cylinder(0.022, 0.02, (-0.06, -0.066, 1.12), "green", segments=8, axis="Y")
    builder.cylinder(0.022, 0.02, (0.0, -0.066, 1.12), "red", segments=8, axis="Y")
    builder.box((0.26, 0.124, 0.03), (0, 0, 1.32), args.colour)
    builder.finish(args.out.stem)


def _moulding_bay(args):
    builder = MeshBuilder()
    width, depth = 3.0, 1.5
    builder.box((width, depth, 0.006), (0, 0, 0.003), "slate")
    for y in (-1, 1):
        builder.box((width, 0.07, 0.004), (0, y * (depth / 2 - 0.035), 0.008), args.colour)
    for x in (-1, 1):
        builder.box((0.07, depth, 0.004), (x * (width / 2 - 0.035), 0, 0.008), args.colour)
    builder.finish(args.out.stem)


def _moulding_machine(args):
    accent, body = args.colour, "teal"
    builder = MeshBuilder()
    # The bed everything stands on.
    builder.box((2.7, 0.85, 0.75), (0, 0.15, 0.375), body, bevel=0.02)
    builder.box((2.72, 0.04, 0.06), (0, -0.28, 0.72), "charcoal")
    # Clamp unit on the left, with a guard door and window over the mould.
    builder.box((0.9, 0.8, 0.7), (-0.85, 0.15, 1.1), body, bevel=0.02)
    builder.box((0.7, 0.8, 0.66), (-0.05, 0.15, 1.08), "metal_light", bevel=0.01)
    builder.box((0.56, 0.02, 0.44), (-0.05, -0.255, 1.1), "sky")
    builder.box((0.08, 0.03, 0.12), (0.22, -0.265, 1.1), accent)
    # Barrel and hopper on the right.
    builder.cylinder(0.13, 1.0, (0.8, 0.15, 1.0), "metal_dark", segments=8, axis="X")
    builder.box((0.4, 0.5, 0.5), (1.15, 0.15, 1.0), body, bevel=0.02)
    builder.cylinder(0.08, 0.14, (0.6, 0.15, 1.2), "metal_dark", segments=6)
    builder.cylinder(0.24, 0.3, (0.6, 0.15, 1.42), accent, segments=6, radius_top=0.3)
    # Control panel on an arm, and the chute and bin the parts drop into.
    builder.box((0.04, 0.04, 0.5), (0.5, -0.33, 1.0), "charcoal")
    builder.box((0.34, 0.06, 0.26), (0.5, -0.36, 1.3), "ink", bevel=0.01)
    builder.box((0.26, 0.01, 0.16), (0.5, -0.392, 1.31), "sky")
    builder.box((0.3, 0.3, 0.03), (-0.05, -0.42, 0.62), "metal_light", rotation=(-0.5, 0, 0))
    builder.tray((0.6, 0.45, 0.36), 0.03, "metal_dark", centre=(-0.05, -0.52, 0))
    builder.box((0.6, 0.03, 0.06), (-0.05, -0.745, 0.3), accent)
    builder.finish(args.out.stem)


VARIANTS = {"eject_tray": _eject_tray, "conveyor": _conveyor, "control_box": _control_box,
            "moulding_bay": _moulding_bay, "moulding_machine": _moulding_machine}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
