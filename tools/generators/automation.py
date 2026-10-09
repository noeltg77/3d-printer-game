"""Automation generator: the kit that takes finished prints off the printers.

  eject_tray   an open bin that sits on the bench beside a printer and catches
               what its plate throws off. Marker `tray` is the floor of the bin.
  conveyor     an overhead belt hung from the ceiling, running along Y. Origin
               is on the floor under its middle; the belt top is at --height.
               Markers `belt_start` and `belt_end` are the two ends of its top,
               in the direction things travel (towards +Y).
  control_box  the cabinet on a post that the conveyor is run from.

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


VARIANTS = {"eject_tray": _eject_tray, "conveyor": _conveyor, "control_box": _control_box}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
