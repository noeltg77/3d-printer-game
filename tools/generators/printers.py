"""Printer generator: one variant per printer in data/printers.json, and one
(`unit_<id>`) per multicolour unit in data/upgrades.json.

Moving parts are separate objects so the game can animate them:
  bed slingers: frame > bed (slides Y), frame > gantry (lifts Z) > toolhead (slides X)
  core XY:      frame > bed (drops Z), frame > gantry (slides Y) > toolhead (slides X)
Markers: `plate` (where prints grow), `plate_corner` (its front right corner, so
the game knows how big the plate is), `spool_mount`, `unit_mount`, and on the
multicolour unit `spool_slot_1..4` and `link_mount` (where the next unit stacks).

blender --background --factory-startup --python tools/generators/printers.py -- \
    --variant plodder_mini --out assets/models/printers/printer_plodder_mini.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder, marker

QUARTER_TURN = (0.0, 0.0, math.pi / 2)
# These match PrinterStation: how far a bed slinger's gantry drops from its
# parked height to start a print, and how far a core XY's bed rises to.
GANTRY_DROP = 0.175
CORE_XY_LIFT = 0.14
# The head swings about a point this share of the plate's width left of where
# it is parked, so park it there to keep the swing over the middle.
HEAD_PARK = 0.208


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="plodder_mini")
    parser.add_argument("--colour", default=None, help="accent colour, instead of the variant's own")
    parser.add_argument("--body", default=None, help="panel colour, instead of the variant's own")


def build(args, rng):
    VARIANTS[args.variant](args)


def _feet(builder, half_x, half_y):
    for x in (-half_x, half_x):
        for y in (-half_y, half_y):
            builder.box((0.05, 0.05, 0.012), (x, y, 0.006), "ink")


def _screen(builder, centre, size=(0.11, 0.07), tilt=-25.0, bezel="ink"):
    """Control screen leaning back by `tilt` degrees, facing the front."""
    angle = math.radians(tilt)
    builder.box((size[0], 0.03, size[1]), centre, bezel, rotation=(angle, 0, 0), bevel=0.004)
    normal = (0, -math.cos(angle), -math.sin(angle))
    face = tuple(c + n * 0.016 for c, n in zip(centre, normal))
    builder.box((size[0] - 0.025, 0.004, size[1] - 0.025), face, "sky", rotation=(angle, 0, 0))


def _portal(builder, half_x, y, top, colour, post=(0.04, 0.04), beam=0.04):
    """Two uprights and the beam across their tops. `top` is the top of the beam."""
    foot = 0.08
    for side in (-1, 1):
        builder.box((post[0], post[1], top - beam - foot), (side * half_x, y, (top - beam + foot) / 2), colour)
    builder.box((half_x * 2 + post[0], post[1], beam), (0, y, top - beam / 2), colour)


def _toolhead(parent, position, accent, size=(0.07, 0.055, 0.085), direct_drive=False, probe=False):
    x, y, z = position
    head = MeshBuilder()
    head.box(size, position, accent, bevel=0.007)
    head.box((size[0] * 0.6, 0.004, size[2] * 0.5), (x, y - size[1] / 2 - 0.002, z + 0.005), "ink")
    head.cylinder(0.004, 0.03, (x, y, z - size[2] / 2 - 0.015), "yellow", segments=6, radius_top=0.014)
    if direct_drive:
        # The extruder motor rides on the head instead of sitting on the frame.
        head.box((size[0] * 0.75, size[1] * 0.85, 0.04), (x, y, z + size[2] / 2 + 0.02), "ink", bevel=0.004)
        head.cylinder(0.014, 0.012, (x, y - size[1] * 0.42, z + size[2] / 2 + 0.02), "metal_light", axis="Y")
    if probe:
        head.cylinder(0.007, 0.035, (x + size[0] / 2 + 0.008, y, z - size[2] / 2 + 0.005), "metal_light", segments=6)
    return head.finish("toolhead", pivot=position, parent=parent)


def _plate_markers(bed_obj, plate, top):
    marker("plate", (0, 0, top), bed_obj)
    marker("plate_corner", (plate[0] / 2, -plate[1] / 2, top), bed_obj)


def _sliding_bed(parent, plate, top, carriage=0.08):
    """Bed slinger's bed, on a carriage that runs front to back. `top` is the plate's surface."""
    bed = MeshBuilder()
    bed.box((carriage, plate[1] + 0.05, 0.02), (0, 0, top - 0.022), "metal_dark")
    bed.box((plate[0], plate[1], 0.012), (0, 0, top - 0.006), "ink", bevel=0.003)
    bed_obj = bed.finish("bed", pivot=(0, 0, top - 0.032), parent=parent)
    _plate_markers(bed_obj, plate, top)


def _sinking_bed(parent, plate, top):
    """Core XY's bed, held from the back. `top` is the plate's surface when parked."""
    bed = MeshBuilder()
    bed.box((plate[0] * 0.4, 0.06, 0.02), (0, plate[1] / 2 + 0.02, top - 0.012), "metal_dark")
    bed.box((plate[0], plate[1], 0.012), (0, 0, top - 0.006), "ink", bevel=0.003)
    bed_obj = bed.finish("bed", pivot=(0, 0, top - 0.006), parent=parent)
    _plate_markers(bed_obj, plate, top)


def _lifting_gantry(parent, plate, plate_top, span, accent, ends=(-1,), end_colour="ink",
                    head=(0.07, 0.055, 0.085), bar="metal_light", **head_options):
    """Bed slinger's X bar and head, parked so the drop puts the nozzle on the plate.

    `span` is the bar's left and right ends; `ends` says which have a Z carriage.
    """
    head_z = plate_top + GANTRY_DROP + 0.033 + head[2] / 2
    height = head_z - 0.005
    gantry = MeshBuilder()
    gantry.box((span[1] - span[0], 0.03, 0.04), ((span[0] + span[1]) / 2, 0.015, height), bar)
    for side in ends:
        gantry.box((0.05, 0.06, 0.07), (span[0] if side < 0 else span[1], 0.02, height), end_colour, bevel=0.005)
    gantry_obj = gantry.finish("gantry", pivot=(0, 0, height), parent=parent)
    _toolhead(gantry_obj, (plate[0] * HEAD_PARK, -0.0005 - head[1] / 2, head_z), accent, size=head, **head_options)


def _sliding_gantry(parent, plate, plate_top, width, accent, head=(0.06, 0.05, 0.07), bar="metal_light"):
    """Core XY's bar and head, at the height the bed rises to."""
    head_z = plate_top + CORE_XY_LIFT + 0.033 + head[2] / 2
    # The game slides the bar about a point a little in front of where it is parked.
    y = plate[1] * 0.125
    bar_z = head_z + head[2] / 2 - 0.01
    gantry = MeshBuilder()
    gantry.box((width, 0.025, 0.025), (0, y, bar_z), bar)
    gantry_obj = gantry.finish("gantry", pivot=(0, y, bar_z), parent=parent)
    _toolhead(gantry_obj, (plate[0] * HEAD_PARK, y - 0.03, head_z), accent, size=head)


def _cabinet(builder, size, top, cap, body, plinth="charcoal", post="charcoal", bevel=0.01):
    """Enclosed printer's shell, open at the front: plinth, back and side panels,
    front posts and a cap whose underside is at `top`. `size` is (width, depth)."""
    width, depth = size
    half_x, half_y = width / 2, depth / 2
    builder.box((width, depth, 0.07), (0, 0, 0.047), plinth, bevel=bevel)
    _feet(builder, half_x - 0.05, half_y - 0.05)
    builder.box((width, depth, cap), (0, 0, top + cap / 2), plinth, bevel=bevel)
    tall, middle = top - 0.08, (top + 0.08) / 2
    # Panels: body colour outside, pale inside so prints stay readable.
    back = builder.box((width, 0.02, tall), (0, half_y - 0.01, middle), body)
    builder.paint(back, "metal_light", facing=(0, -1, 0))
    for side in (-1, 1):
        panel = builder.box((0.02, depth, tall), (side * (half_x - 0.01), 0, middle), body)
        builder.paint(panel, "metal_light", facing=(-side, 0, 0))
        builder.box((0.03, 0.03, tall), (side * (half_x - 0.015), -half_y + 0.015, middle), post)
    builder.box((width - 0.04, depth - 0.04, 0.004), (0, 0, 0.084), "metal_dark")


def _side_spool(builder, half_x, y, z):
    """Spool holder on the right hand side, where the camera sees it. `z` is the
    spool's lowest point. Returns where its `spool_mount` marker goes."""
    builder.cylinder(0.015, 0.08, (half_x + 0.04, y, z + 0.1), "ink", axis="X")
    return (half_x + 0.045, y, z)


def _plodder_mini(args):
    """The starter: a bare open frame, one Z screw, the extruder left on the frame."""
    accent, body = args.colour or "orange", args.body or "slate"
    plate = (0.25, 0.25)
    frame = MeshBuilder()
    frame.box((0.44, 0.46, 0.07), (0, 0, 0.047), "charcoal", bevel=0.008)
    _feet(frame, 0.17, 0.19)
    _portal(frame, 0.2, 0.05, 0.62, body)
    frame.box((0.18, 0.004, 0.022), (-0.1, -0.232, 0.047), accent)
    _screen(frame, (0.15, -0.235, 0.1))
    # The extruder, bolted to the left upright, pushing filament up a tube.
    frame.box((0.05, 0.05, 0.06), (-0.2, 0.01, 0.5), "ink", bevel=0.004)
    frame.cylinder(0.016, 0.012, (-0.2, -0.02, 0.5), accent, axis="Y")
    # Cradle on the top bar for the spool.
    frame.box((0.1, 0.09, 0.02), (0, 0.05, 0.63), "charcoal")
    frame_obj = frame.finish("frame")
    marker("spool_mount", (0, 0.05, 0.64), frame_obj)
    marker("unit_mount", (0, 0.05, 0.64), frame_obj)
    _sliding_bed(frame_obj, plate, 0.114)
    _lifting_gantry(frame_obj, plate, 0.114, (-0.24, 0.24), accent)


def _plodder_mini_pro(args):
    """The Mini's frame, braced, with a screw each side and the extruder on the head."""
    accent, body = args.colour or "red", args.body or "slate"
    plate = (0.25, 0.25)
    frame = MeshBuilder()
    frame.box((0.44, 0.46, 0.07), (0, 0, 0.047), "charcoal", bevel=0.008)
    _feet(frame, 0.17, 0.19)
    _portal(frame, 0.2, 0.05, 0.62, body)
    frame.box((0.48, 0.05, 0.02), (0, 0.05, 0.63), accent, bevel=0.004)
    # Braces from the top of the frame down to the back of the base.
    lean = math.atan2(0.14, 0.5)
    for side in (-1, 1):
        frame.box((0.018, 0.018, 0.52), (side * 0.2, 0.14, 0.33), "metal_light", rotation=(lean, 0, 0))
        frame.cylinder(0.007, 0.5, (side * 0.2, 0.022, 0.33), "metal_light", segments=6)
        frame.box((0.05, 0.05, 0.05), (side * 0.2, 0.01, 0.105), "ink", bevel=0.004)
    frame.box((0.3, 0.004, 0.022), (-0.04, -0.232, 0.047), accent)
    _screen(frame, (0.13, -0.24, 0.11), size=(0.15, 0.09), bezel=accent)
    frame.box((0.1, 0.09, 0.02), (0, 0.05, 0.65), "charcoal")
    frame_obj = frame.finish("frame")
    marker("spool_mount", (0, 0.05, 0.66), frame_obj)
    marker("unit_mount", (0, 0.05, 0.66), frame_obj)
    _sliding_bed(frame_obj, plate, 0.114)
    _lifting_gantry(frame_obj, plate, 0.114, (-0.24, 0.24), accent, ends=(-1, 1),
                    head=(0.08, 0.06, 0.085), direct_drive=True, probe=True)


def _plodder_bigslinger_350(args):
    """A Mini scaled up past what its thin frame can really hold steady."""
    accent, body = args.colour or "yellow", args.body or "slate"
    plate = (0.36, 0.36)
    frame = MeshBuilder()
    # The base is open rails rather than a box, with the works in a case at the front.
    for side in (-1, 1):
        frame.box((0.05, 0.6, 0.05), (side * 0.25, 0, 0.037), body)
        frame.box((0.07, 0.07, 0.07), (side * 0.25, 0.06, 0.1), accent, bevel=0.005)
    for y in (-0.275, 0.275):
        frame.box((0.55, 0.05, 0.05), (0, y, 0.037), body)
    frame.box((0.09, 0.56, 0.03), (0, 0, 0.05), "charcoal")
    _feet(frame, 0.25, 0.275)
    _portal(frame, 0.25, 0.06, 0.8, body, post=(0.045, 0.045), beam=0.045)
    frame.box((0.2, 0.1, 0.075), (0.15, -0.3, 0.05), "charcoal", bevel=0.006)
    _screen(frame, (0.15, -0.33, 0.12), size=(0.13, 0.08))
    frame.box((0.1, 0.09, 0.02), (0, 0.06, 0.81), "charcoal")
    frame_obj = frame.finish("frame")
    marker("spool_mount", (0, 0.06, 0.82), frame_obj)
    marker("unit_mount", (0, 0.06, 0.82), frame_obj)
    _sliding_bed(frame_obj, plate, 0.114, carriage=0.12)
    _lifting_gantry(frame_obj, plate, 0.114, (-0.3, 0.3), accent, ends=(-1, 1), head=(0.08, 0.06, 0.09))


def _zippy_a1_mini(args):
    """A cantilever: one pillar on the left and the X arm reaching out from it."""
    accent, body = args.colour or "teal", args.body or "white"
    plate = (0.21, 0.21)
    frame = MeshBuilder()
    frame.box((0.38, 0.36, 0.075), (0, 0, 0.05), body, bevel=0.014, bevel_segments=2)
    _feet(frame, 0.14, 0.13)
    frame.box((0.2, 0.004, 0.018), (-0.07, -0.182, 0.05), accent)
    _screen(frame, (0.13, -0.19, 0.105), size=(0.09, 0.065), bezel="charcoal")
    # The pillar, and an arm off its top for the spool.
    frame.box((0.08, 0.09, 0.44), (-0.145, 0.075, 0.3), body, bevel=0.012)
    frame.box((0.084, 0.094, 0.03), (-0.145, 0.075, 0.5), accent, bevel=0.006)
    frame.box((0.3, 0.07, 0.025), (-0.035, 0.075, 0.53), body, bevel=0.006)
    frame_obj = frame.finish("frame")
    marker("spool_mount", (-0.03, 0.075, 0.543), frame_obj)
    marker("unit_mount", (-0.03, 0.075, 0.543), frame_obj)
    _sliding_bed(frame_obj, plate, 0.114, carriage=0.07)
    _lifting_gantry(frame_obj, plate, 0.114, (-0.145, 0.17), accent, end_colour=body, bar="charcoal",
                    head=(0.065, 0.055, 0.08), direct_drive=True)


def _kestrel_frame(builder, half_x, top, accent):
    """Kestrel's flat plate frame: a printed bracket at the foot of each upright,
    and a post off the top with a cradle for the spool."""
    _portal(builder, half_x, 0.05, top, "ink", post=(0.07, 0.022), beam=0.075)
    for side in (-1, 1):
        builder.box((0.08, 0.06, 0.07), (side * half_x, 0.03, 0.115), accent, bevel=0.006)
        builder.cylinder(0.007, top - 0.2, (side * half_x, 0.022, (top + 0.05) / 2), "metal_light", segments=6)
    builder.box((0.035, 0.035, 0.05), (0, 0.05, top + 0.025), accent)
    builder.box((0.12, 0.09, 0.02), (0, 0.05, top + 0.06), accent, bevel=0.004)


def _kestrel_core_one_mini(args):
    """Small and solid: the plate frame on a closed box of a base."""
    accent, body = args.colour or "green", args.body or "ink"
    plate = (0.21, 0.21)
    top = 0.5
    frame = MeshBuilder()
    frame.box((0.38, 0.38, 0.085), (0, 0, 0.0545), body, bevel=0.01)
    _feet(frame, 0.14, 0.14)
    frame.box((0.38, 0.012, 0.05), (0, -0.19, 0.055), accent, bevel=0.004)
    frame.box((0.1, 0.006, 0.032), (-0.08, -0.198, 0.055), "sky")
    frame.cylinder(0.018, 0.02, (0.08, -0.2, 0.055), "ink", axis="Y")
    _kestrel_frame(frame, 0.18, top, accent)
    frame_obj = frame.finish("frame")
    marker("spool_mount", (0, 0.05, top + 0.07), frame_obj)
    marker("unit_mount", (0, 0.05, top + 0.07), frame_obj)
    _sliding_bed(frame_obj, plate, 0.124, carriage=0.07)
    _lifting_gantry(frame_obj, plate, 0.124, (-0.2, 0.2), accent, ends=(-1, 1), end_colour=accent,
                    head=(0.07, 0.055, 0.08), direct_drive=True)


def _kestrel_mk4(args):
    """The workhorse: the plate frame over open rails, with its screen and power supply hung off it."""
    accent, body = args.colour or "green", args.body or "ink"
    plate = (0.27, 0.24)
    top = 0.64
    frame = MeshBuilder()
    for side in (-1, 1):
        frame.box((0.035, 0.46, 0.035), (side * 0.1, 0, 0.0295), "metal_dark")
    for y in (-0.225, 0.225):
        frame.box((0.34, 0.03, 0.07), (0, y, 0.047), body, bevel=0.004)
    frame.box((0.55, 0.05, 0.035), (0, 0.05, 0.0295), body)
    _feet(frame, 0.14, 0.2)
    _kestrel_frame(frame, 0.24, top, accent)
    # Power supply down the right upright, electronics behind the left one.
    frame.box((0.06, 0.11, 0.24), (0.24, 0.12, 0.2), "metal_light", bevel=0.005)
    frame.box((0.07, 0.09, 0.16), (-0.24, 0.11, 0.16), body, bevel=0.005)
    # The screen sticks out on a bracket at the front right, with its knob.
    frame.box((0.03, 0.08, 0.03), (0.13, -0.26, 0.05), accent)
    _screen(frame, (0.13, -0.3, 0.085), size=(0.17, 0.075), tilt=-35.0)
    frame.cylinder(0.016, 0.02, (0.2, -0.325, 0.075), accent, axis="Y", rotation=(math.radians(55), 0, 0))
    frame_obj = frame.finish("frame")
    marker("spool_mount", (0, 0.05, top + 0.07), frame_obj)
    marker("unit_mount", (0, 0.05, top + 0.07), frame_obj)
    _sliding_bed(frame_obj, plate, 0.114)
    _lifting_gantry(frame_obj, plate, 0.114, (-0.26, 0.26), accent, ends=(-1, 1), end_colour=accent,
                    head=(0.08, 0.06, 0.095), direct_drive=True, probe=True)


def _snapbox_junior(args):
    """A little rounded box in two colours, with a carry handle."""
    accent, body = args.colour or "sky", args.body or "white"
    plate = (0.19, 0.19)
    size, half, top = 0.32, 0.16, 0.37
    frame = MeshBuilder()
    _cabinet(frame, (size, size), top, 0.05, body, plinth=accent, post=body, bevel=0.016)
    frame.cylinder(0.02, 0.01, (0.1, -half - 0.004, top + 0.025), body, axis="Y")
    # The handle on top.
    for side in (-1, 1):
        frame.box((0.025, 0.035, 0.05), (side * 0.07, 0, top + 0.07), accent)
    frame.box((0.19, 0.04, 0.025), (0, 0, top + 0.1), accent, bevel=0.008)
    spool = _side_spool(frame, half, 0.02, 0.06)
    frame_obj = frame.finish("frame")
    marker("spool_mount", spool, frame_obj, rotation=QUARTER_TURN)
    marker("unit_mount", (0, 0, top + 0.05), frame_obj)
    _sinking_bed(frame_obj, plate, 0.13)
    _sliding_gantry(frame_obj, plate, 0.13, size - 0.04, accent, head=(0.055, 0.045, 0.06))


def _snapbox_adventurer_5(args):
    """A white cabinet with a filter hood on top."""
    accent, body = args.colour or "sky", args.body or "white"
    plate = (0.25, 0.25)
    size, half, top = 0.42, 0.21, 0.47
    frame = MeshBuilder()
    _cabinet(frame, (size, size), top, 0.06, body, plinth=body, post=body, bevel=0.012)
    frame.box((size, 0.006, 0.024), (0, -half - 0.001, 0.047), accent)
    frame.box((size * 0.5, 0.004, 0.016), (-0.08, -half - 0.002, top + 0.03), accent)
    frame.box((0.09, 0.004, 0.036), (0.14, -half - 0.002, top + 0.03), "ink")
    frame.box((0.07, 0.004, 0.022), (0.14, -half - 0.004, top + 0.03), "sky")
    # The hood: a raised lid with a vent along the side the camera sees.
    frame.box((0.3, 0.3, 0.05), (0, 0.02, top + 0.085), body, bevel=0.012)
    frame.box((0.004, 0.2, 0.02), (0.151, 0.02, top + 0.085), "charcoal")
    frame.box((0.2, 0.004, 0.02), (0, -0.131, top + 0.085), accent)
    spool = _side_spool(frame, half, 0.03, 0.12)
    frame_obj = frame.finish("frame")
    marker("spool_mount", spool, frame_obj, rotation=QUARTER_TURN)
    marker("unit_mount", (0, 0.02, top + 0.11), frame_obj)
    _sinking_bed(frame_obj, plate, 0.22)
    _sliding_gantry(frame_obj, plate, 0.22, size - 0.04, accent)


def _zippy_x1(args):
    """A tall dark cabinet on a metal frame, with a glass lid."""
    accent, body = args.colour or "orange", args.body or "slate"
    plate = (0.27, 0.25)
    size, half, top = 0.46, 0.23, 0.56
    frame = MeshBuilder()
    _cabinet(frame, (size, size), top, 0.06, body, post="metal_light")
    for side in (-1, 1):
        frame.box((0.03, 0.03, top - 0.08), (side * (half - 0.015), half - 0.015, (top + 0.08) / 2), "metal_light")
    frame.box((size, 0.006, 0.024), (0, -half - 0.001, 0.047), accent)
    frame.box((0.13, 0.006, 0.045), (0.13, -half - 0.002, top + 0.03), "ink")
    frame.box((0.11, 0.004, 0.03), (0.13, -half - 0.005, top + 0.03), "sky")
    frame.box((0.012, 0.012, 0.14), (-half + 0.015, -half - 0.006, 0.34), accent)
    # The lid: a pane sitting in a frame on top.
    frame.box((size - 0.04, size - 0.04, 0.03), (0, 0, top + 0.075), "charcoal", bevel=0.006)
    frame.box((size - 0.1, size - 0.1, 0.006), (0, 0, top + 0.092), "navy")
    spool = _side_spool(frame, half, 0.03, 0.2)
    frame_obj = frame.finish("frame")
    marker("spool_mount", spool, frame_obj, rotation=QUARTER_TURN)
    marker("unit_mount", (0, 0, top + 0.095), frame_obj)
    _sinking_bed(frame_obj, plate, 0.28)
    _sliding_gantry(frame_obj, plate, 0.28, size - 0.04, accent)


def _unit_markers(unit_obj, link=0.24):
    for slot in range(4):
        x = (slot - 1.5) * 0.085
        marker(f"spool_slot_{slot + 1}", (x, 0, 0.03), unit_obj, rotation=QUARTER_TURN)
    # Where a second unit linked to this one sits: clear of the spools.
    marker("link_mount", (0, 0, link), unit_obj)


def _unit_zippy_colourhub(args):
    """The classic: a tub the four spools sit down into."""
    accent, body = args.colour or "teal", args.body or "metal_light"
    width, depth = 0.38, 0.27
    unit = MeshBuilder()
    unit.box((width, depth, 0.03), (0, 0, 0.015), "charcoal", bevel=0.006)
    unit.box((width, 0.025, 0.13), (0, depth / 2 - 0.0125, 0.095), body)
    unit.box((width, 0.025, 0.06), (0, -depth / 2 + 0.0125, 0.06), body)
    for side in (-1, 1):
        unit.box((0.02, depth, 0.1), (side * (width / 2 - 0.01), 0, 0.08), body)
    unit.box((width * 0.9, 0.004, 0.012), (0, -depth / 2 - 0.002, 0.045), accent)
    _unit_markers(unit.finish(args.out.stem))


def _unit_zippy_colourhub_lite(args):
    """The cheap one: no tub, just a rail the spools stand along and a feeder on the front."""
    accent, body = args.colour or "teal", args.body or "white"
    width, depth = 0.38, 0.2
    unit = MeshBuilder()
    unit.box((width, 0.07, 0.03), (0, 0, 0.015), body, bevel=0.006)
    for side in (-1, 1):
        unit.box((0.03, depth, 0.03), (side * (width / 2 - 0.015), 0, 0.015), body, bevel=0.006)
        unit.box((0.02, 0.05, 0.09), (side * (width / 2 - 0.01), 0, 0.075), body, bevel=0.005)
    for y in (-0.05, 0.05):
        unit.cylinder(0.01, width - 0.04, (0, y, 0.03), "metal_light", segments=6, axis="X")
    unit.box((width, 0.03, 0.03), (0, -depth / 2 + 0.015, 0.015), body, bevel=0.006)
    unit.box((0.16, 0.05, 0.045), (0, -depth / 2 + 0.01, 0.0225), accent, bevel=0.006)
    _unit_markers(unit.finish(args.out.stem))


def _unit_zippy_colourhub_2_pro(args):
    """A ColourHub in a dark case with a heated lid hinged along the back."""
    accent, body = args.colour or "orange", args.body or "charcoal"
    width, depth = 0.38, 0.27
    unit = MeshBuilder()
    unit.box((width, depth, 0.03), (0, 0, 0.015), "ink", bevel=0.006)
    unit.box((width, 0.025, 0.215), (0, depth / 2 - 0.0125, 0.1375), body)
    unit.box((width, 0.025, 0.07), (0, -depth / 2 + 0.0125, 0.065), body)
    for side in (-1, 1):
        unit.box((0.02, depth, 0.1), (side * (width / 2 - 0.01), 0, 0.08), body)
        unit.box((0.02, 0.11, 0.115), (side * (width / 2 - 0.01), depth / 2 - 0.055, 0.1875), body)
    # The lid, over the back half so the spools still show.
    unit.box((width, 0.11, 0.016), (0, depth / 2 - 0.055, 0.253), "navy", bevel=0.004)
    unit.box((width * 0.5, 0.012, 0.02), (0, depth / 2 - 0.115, 0.253), accent)
    unit.box((width * 0.9, 0.004, 0.014), (0, -depth / 2 - 0.002, 0.05), accent)
    unit.box((0.07, 0.004, 0.028), (0.12, -depth / 2 - 0.002, 0.08), "sky")
    _unit_markers(unit.finish(args.out.stem), link=0.265)


def _unit_spoolsmith_quad(args):
    """A bolt-on feeder: a bare plate with printed brackets, rollers and a row of feed motors."""
    accent, body = args.colour or "green", args.body or "ink"
    width, depth = 0.38, 0.27
    unit = MeshBuilder()
    unit.box((width, depth, 0.014), (0, 0, 0.007), body)
    for side in (-1, 1):
        for y in (-0.085, 0.085):
            unit.box((0.03, 0.04, 0.07), (side * (width / 2 - 0.015), y, 0.049), accent, bevel=0.005)
    for y in (-0.085, 0.085):
        unit.cylinder(0.01, width - 0.02, (0, y, 0.062), "metal_light", segments=6, axis="X")
    unit.box((width, 0.045, 0.05), (0, -depth / 2 - 0.0225, 0.025), accent, bevel=0.005)
    for slot in range(4):
        x = (slot - 1.5) * 0.085
        unit.box((0.045, 0.04, 0.045), (x, -depth / 2 - 0.02, 0.07), body, bevel=0.004)
        unit.cylinder(0.007, 0.03, (x, -depth / 2 - 0.02, 0.1), "white", segments=6)
    _unit_markers(unit.finish(args.out.stem))


VARIANTS = {
    "plodder_mini": _plodder_mini,
    "plodder_mini_pro": _plodder_mini_pro,
    "snapbox_junior": _snapbox_junior,
    "zippy_a1_mini": _zippy_a1_mini,
    "kestrel_core_one_mini": _kestrel_core_one_mini,
    "plodder_bigslinger_350": _plodder_bigslinger_350,
    "snapbox_adventurer_5": _snapbox_adventurer_5,
    "zippy_x1": _zippy_x1,
    "kestrel_mk4": _kestrel_mk4,
    "unit_zippy_colourhub_lite": _unit_zippy_colourhub_lite,
    "unit_zippy_colourhub": _unit_zippy_colourhub,
    "unit_zippy_colourhub_2_pro": _unit_zippy_colourhub_2_pro,
    "unit_spoolsmith_quad": _unit_spoolsmith_quad,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
