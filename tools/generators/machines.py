"""Floor standing machines bought as fittings: the filament recycler and the resin wash and cure stations.

Each is a cabinet with the working parts on top, at a height the character can
reach. The front faces -Y. They go in assets/models/furniture/ with the other
fittings, since they are stood about the room the same way.

blender --background --factory-startup --python tools/generators/machines.py -- \
    --variant recycler --colour green --out assets/models/furniture/recycler.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder

SCRAP_COLOURS = ("red", "orange", "yellow", "green", "sky", "purple", "pink", "teal")
_pending_markers = []


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="recycler")
    parser.add_argument("--colour", default="green", help="the maker's colour: trim, dials and panels")


def build(args, rng):
    builder = MeshBuilder()
    _pending_markers.clear()
    VARIANTS[args.variant](builder, args, rng)
    obj = builder.finish(args.out.stem)
    for name, position, rotation in _pending_markers:
        common.marker(name, position, obj, rotation=rotation)


def _cabinet(builder, width, depth, top, colour):
    """A cream cabinet on feet with a worktop, a trim line and a pair of doors. Returns its front face."""
    for x in (-1, 1):
        for y in (-1, 1):
            builder.box((0.05, 0.05, 0.08), (x * (width / 2 - 0.05), y * (depth / 2 - 0.05), 0.04), "charcoal")
    builder.box((width, depth, top - 0.12), (0, 0, 0.08 + (top - 0.12) / 2), "cream", bevel=0.015, bevel_segments=2)
    builder.box((width + 0.03, depth + 0.03, 0.04), (0, 0, top - 0.02), "charcoal", bevel=0.008)
    front = -depth / 2 - 0.004
    builder.box((width, 0.01, 0.03), (0, front, top - 0.075), colour)
    doors = 2 if width < 1.0 else 3
    door = (width - 0.06) / doors
    for index in range(doors):
        x = (index - (doors - 1) / 2) * door
        builder.box((door - 0.03, 0.01, top - 0.3), (x, front, 0.13 + (top - 0.3) / 2), "linen", bevel=0.004)
        builder.box((0.015, 0.016, 0.1), (x + door / 2 - 0.05, front - 0.006, top - 0.3), "charcoal")
    return front


def _recycler(builder, args, rng):
    """Filament recycler, 0.95 x 0.45, worktop at 0.75: shredder, extruder and winder in a row.

    Leftover filament goes in the hopper on the left, is ground up and melted
    along the barrel, and is wound onto a fresh spool on the right. Markers:
    `hopper`, over the mouth of the shredder, and `spool_out`, where the spool
    being wound stands on its rollers.
    """
    width, depth, top = 0.95, 0.45, 0.75
    front = _cabinet(builder, width, depth, top, args.colour)

    # Shredder: a squat body with a wide hopper, heaped with chopped up scrap.
    shred_x = -0.3
    builder.box((0.3, 0.32, 0.2), (shred_x, 0.02, top + 0.1), "slate", bevel=0.012)
    builder.box((0.2, 0.22, 0.18), (shred_x, 0.02, top + 0.29), args.colour, taper=1.55, rotation=(math.pi, 0, 0))
    builder.box((0.3, 0.33, 0.02), (shred_x, 0.02, top + 0.385), "charcoal", bevel=0.005)
    builder.box((0.25, 0.28, 0.012), (shred_x, 0.02, top + 0.392), "ink")
    for _ in range(9):
        size = (rng.uniform(0.025, 0.05), rng.uniform(0.02, 0.04), rng.uniform(0.012, 0.025))
        spot = (shred_x + rng.uniform(-0.09, 0.09), 0.02 + rng.uniform(-0.1, 0.1), top + 0.4 + rng.uniform(0.0, 0.012))
        builder.box(size, spot, rng.choice(SCRAP_COLOURS), rotation=(rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(0, math.pi)))
    _pending_markers.append(("hopper", (shred_x, 0.02, top + 0.42), (0, 0, 0)))
    # Its controls: a start button and a guard rail of bolts.
    builder.cylinder(0.03, 0.02, (shred_x - 0.07, -0.145, top + 0.11), "red", segments=10, axis="Y")
    builder.cylinder(0.022, 0.02, (shred_x + 0.01, -0.145, top + 0.11), "green", segments=10, axis="Y")
    builder.box((0.06, 0.012, 0.035), (shred_x + 0.09, -0.142, top + 0.11), "ink")

    # Extruder: a barrel with heater bands running to a nozzle, on a motor block.
    builder.box((0.12, 0.2, 0.16), (-0.1, 0.04, top + 0.08), "charcoal", bevel=0.01)
    builder.cylinder(0.035, 0.3, (0.06, 0.04, top + 0.11), "metal_light", segments=10, axis="X")
    for index in range(3):
        builder.cylinder(0.045, 0.035, (-0.01 + index * 0.075, 0.04, top + 0.11), "orange", segments=10, axis="X")
    builder.cylinder(0.02, 0.04, (0.22, 0.04, top + 0.11), "metal_dark", segments=8, axis="X", radius_top=0.008)
    for x in (-0.02, 0.14):
        builder.box((0.03, 0.08, 0.075), (x, 0.04, top + 0.0375), "metal_dark")
    # A cooling fan over the strand, and the strand itself running on to the winder.
    builder.box((0.07, 0.07, 0.03), (0.2, 0.04, top + 0.2), "charcoal", bevel=0.006)
    builder.box((0.012, 0.012, 0.1), (0.2, 0.085, top + 0.14), "charcoal")
    builder.box((0.012, 0.03, 0.1), (0.2, 0.085, top + 0.05), "charcoal")
    builder.cylinder(0.004, 0.14, (0.3, 0.04, top + 0.115), args.colour, segments=5, axis="X", rotation=(0, math.pi / 2 - 0.12, 0))

    # Winder: two rollers the new spool turns on, between a pair of cheeks.
    wind_x, rail_gap, rail_radius, spool_radius = 0.36, 0.06, 0.012, 0.1
    for y in (-1, 1):
        builder.box((0.16, 0.02, 0.09), (wind_x, 0.04 + y * 0.075, top + 0.045), "charcoal", bevel=0.006)
    for x in (-rail_gap, rail_gap):
        builder.cylinder(rail_radius, 0.16, (wind_x + x, 0.04, top + 0.05), "metal_light", segments=6, axis="Y")
    rest = (spool_radius + rail_radius) ** 2 - rail_gap ** 2
    drop = spool_radius - rest ** 0.5
    _pending_markers.append(("spool_out", (wind_x, 0.04, top + 0.05 - drop), (0, 0, 0)))

    # A display and a dial for the colour on the front.
    builder.box((0.2, 0.012, 0.09), (0.26, front, top - 0.17), "ink")
    builder.box((0.16, 0.014, 0.05), (0.26, front - 0.002, top - 0.17), args.colour)
    builder.cylinder(0.028, 0.02, (0.08, front - 0.006, top - 0.17), "charcoal", segments=10, axis="Y")
    builder.box((0.01, 0.012, 0.025), (0.08, front - 0.018, top - 0.16), "white")


def _wash_bay(builder, x, top, colour, index, rng):
    """One wash tub and one curing bay side by side, 0.52 across, centred on `x`.

    The tub is open topped and the hood open to the front and the right, so
    what stands in either shows from where the game looks. Markers
    `wash_slot_<index>` and `cure_slot_<index>`.
    """
    # Wash: a base with a paddle motor, and a tub of cleaner with a basket rim.
    tub_x = x - 0.13
    builder.box((0.22, 0.24, 0.06), (tub_x, 0, top + 0.03), "charcoal", bevel=0.01)
    builder.box((0.2, 0.22, 0.012), (tub_x, 0, top + 0.066), "sky")
    wall, tall = 0.012, 0.1
    builder.box((0.2, wall, tall), (tub_x, 0.11 - wall / 2, top + 0.06 + tall / 2), "white")
    builder.box((wall, 0.22, tall), (tub_x - 0.1 + wall / 2, 0, top + 0.06 + tall / 2), "white")
    # Low at the front and the right: just a lip, to keep the print in view.
    builder.box((0.2, wall, 0.035), (tub_x, -0.11 + wall / 2, top + 0.0775), "white")
    builder.box((wall, 0.22, 0.035), (tub_x + 0.1 - wall / 2, 0, top + 0.0775), "white")
    builder.box((0.22, 0.02, 0.012), (tub_x, 0.11, top + 0.166), colour)
    builder.box((0.02, 0.24, 0.012), (tub_x - 0.1, 0, top + 0.166), colour)
    builder.cylinder(0.014, 0.012, (tub_x - 0.07, -0.125, top + 0.03), colour, segments=8, axis="Y")
    _pending_markers.append((f"wash_slot_{index}", (tub_x, 0, top + 0.074), (0, 0, 0)))

    # Cure: a turntable under a hood that keeps the light in, with a lamp bar down the back.
    cure_x = x + 0.13
    builder.box((0.22, 0.24, 0.05), (cure_x, 0, top + 0.025), "charcoal", bevel=0.01)
    builder.cylinder(0.085, 0.012, (cure_x, 0, top + 0.056), "metal_light", segments=12)
    hood = 0.26
    builder.box((0.22, 0.012, hood), (cure_x, 0.114, top + 0.05 + hood / 2), colour)
    builder.box((0.012, 0.24, hood), (cure_x - 0.104, 0, top + 0.05 + hood / 2), colour)
    builder.box((0.23, 0.25, 0.02), (cure_x, 0, top + 0.05 + hood + 0.01), "charcoal", bevel=0.006)
    builder.box((0.03, 0.01, hood - 0.06), (cure_x, 0.104, top + 0.05 + hood / 2), "purple")
    for step in range(4):
        builder.box((0.036, 0.012, 0.02), (cure_x, 0.1, top + 0.11 + step * 0.05), "pink")
    builder.box((0.07, 0.012, 0.022), (cure_x + 0.04, -0.125, top + 0.025), "ink")
    builder.box((0.022, 0.014, 0.012), (cure_x + 0.04, -0.127, top + 0.025), colour)
    _pending_markers.append((f"cure_slot_{index}", (cure_x, 0, top + 0.062), (0, 0, 0)))


def _wash_station(builder, args, rng):
    """Wash and cure station, 0.7 x 0.45, worktop at 0.75: one tub and one curing bay."""
    width, depth, top = 0.7, 0.45, 0.75
    _cabinet(builder, width, depth, top, args.colour)
    _wash_bay(builder, -0.04, top, args.colour, 1, rng)
    # A bottle of cleaner standing by.
    builder.cylinder(0.035, 0.14, (0.29, 0.1, top + 0.07), "white", segments=8)
    builder.cylinder(0.016, 0.03, (0.29, 0.1, top + 0.155), args.colour, segments=8)


def _wash_station_max(builder, args, rng):
    """The big wash and cure station, 1.2 x 0.45: two tubs and two curing bays, for two plates at once."""
    width, depth, top = 1.2, 0.45, 0.75
    _cabinet(builder, width, depth, top, args.colour)
    for index, x in enumerate((-0.3, 0.28)):
        _wash_bay(builder, x, top, args.colour, index + 1, rng)
    # An extractor stack at the back, for the fumes of two tubs.
    builder.cylinder(0.03, 0.34, (-0.01, 0.16, top + 0.17), "metal_light", segments=8)
    builder.cylinder(0.045, 0.025, (-0.01, 0.16, top + 0.35), "charcoal", segments=8)


VARIANTS = {"recycler": _recycler, "wash_station": _wash_station, "wash_station_max": _wash_station_max}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
