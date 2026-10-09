"""Printed item generator for multicolour designs: Bonfire Night, Christmas, New Year, Father's Day and Summer.

Same rules as prints_multicolour.py: a mesh per colour, built through `Parts`.
"""

import math
import sys
from pathlib import Path

from mathutils import Matrix

sys.path.append(str(Path(__file__).resolve().parent))
import common
import print_shapes
import prints_multicolour
from print_shapes import COLOUR


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), required=True)


def build(args, rng):
    build_item(args.variant, args.out.stem)


def build_item(variant, name, preview=False):
    return prints_multicolour.build_from(VARIANTS, variant, name, preview)


def _on_panel(foot, x, up, out, tilt):
    """A point on a panel that stands on `foot` and leans back by `tilt` radians.

    `up` is measured along the panel from its foot, `out` towards the viewer
    from the middle of its thickness.
    """
    return (
        foot[0] + x,
        foot[1] + up * math.sin(tilt) - out * math.cos(tilt),
        foot[2] + up * math.cos(tilt) + out * math.sin(tilt),
    )


def _leaning(tilt, spin=0.0):
    """Rotation for a box lying in a panel leaning back by `tilt`, turned `spin` clockwise in its plane."""
    return tuple((Matrix.Rotation(-tilt, 3, "X") @ Matrix.Rotation(spin, 3, "Y")).to_euler())


def _turned(points, angle, offset):
    """An outline turned about its origin by `angle` radians and moved to `offset`."""
    cos, sin = math.cos(angle), math.sin(angle)
    return [(offset[0] + x * cos - y * sin, offset[1] + x * sin + y * cos) for x, y in points]


def _star(builder, centre, size):
    """Upright eight pointed star out of two crossed squares, facing the front."""
    builder.box((size, size * 0.25, size), centre, COLOUR)
    builder.box((size, size * 0.25, size), centre, COLOUR, rotation=(0, math.pi / 4, 0))


def _bonfire_table_centrepiece(parts):
    """Round base with five logs leaning into a point, a flame rising between them and its tip in a third colour."""
    parts.main.cylinder(0.095, 0.012, (0, 0, 0.006), COLOUR, segments=8)
    for index in range(5):
        angle = math.tau * index / 5 + math.pi / 2
        out = (math.cos(angle), math.sin(angle))
        print_shapes.limb(
            parts.main, (out[0] * 0.075, out[1] * 0.075, 0.016), (-out[0] * 0.012, -out[1] * 0.012, 0.105), 0.014, segments=5)
    flame = parts.colour(2)
    flame.cylinder(0.046, 0.085, (0, 0, 0.0895), COLOUR, segments=6, radius_top=0.026)
    print_shapes.limb(flame, (-0.03, 0.005, 0.1), (-0.05, 0.0, 0.175), 0.016, radius_end=0.002, segments=5)
    print_shapes.limb(flame, (0.03, -0.005, 0.1), (0.046, 0.0, 0.16), 0.016, radius_end=0.002, segments=5)
    parts.colour(3).cylinder(0.026, 0.085, (0, 0, 0.1745), COLOUR, segments=6, radius_top=0.002)


def _personalised_bauble(parts):
    """Flat round bauble with a cap and hanging loop, a name in raised letters between two lines."""
    parts.main.cylinder(0.062, 0.01, (0, 0, 0.005), COLOUR, segments=10)
    parts.main.box((0.032, 0.02, 0.01), (0, 0.066, 0.005), COLOUR)
    parts.main.shell(0.015, 0.006, 0.005, COLOUR, segments=6, centre=(0, 0.088, 0), open_base=True)
    name = parts.colour(2)
    for index, width in enumerate((0.014, 0.011, 0.015, 0.012, 0.014)):
        name.box((width, 0.026, 0.003), ((index - 2) * 0.02, 0, 0.0115), COLOUR)
    for y in (-0.03, 0.03):
        name.box((0.075, 0.005, 0.003), (0, y, 0.0115), COLOUR)


def _christmas_tree_desk(parts):
    """Three tier tree on a stubby trunk, with a star on top and six baubles in the second colour."""
    parts.main.cylinder(0.03, 0.03, (0, 0, 0.015), COLOUR, segments=6)
    parts.main.cylinder(0.085, 0.08, (0, 0, 0.07), COLOUR, segments=7, radius_top=0.035)
    parts.main.cylinder(0.068, 0.08, (0, 0, 0.13), COLOUR, segments=7, radius_top=0.025)
    parts.main.cylinder(0.05, 0.09, (0, 0, 0.195), COLOUR, segments=7, radius_top=0.004)
    trim = parts.colour(2)
    _star(trim, (0, 0, 0.255), 0.036)
    for z, radius, angles in ((0.058, 0.066, (-90, 20, 150)), (0.118, 0.053, (-40, -150)), (0.18, 0.034, (-80,))):
        for angle in angles:
            turn = math.radians(angle)
            trim.box(
                (0.02, 0.02, 0.02), (math.cos(turn) * radius * 0.97, math.sin(turn) * radius * 0.97, z), COLOUR,
                rotation=(0.6, 0.6, turn))


def _christmas_village_house(parts):
    """Cottage on a slab of ground: walls, a pitched roof in the second colour, door, windows and chimney in a third."""
    parts.main.box((0.18, 0.15, 0.01), (0, 0, 0.005), COLOUR)
    parts.main.box((0.12, 0.1, 0.08), (0, 0, 0.05), COLOUR)
    parts.colour(2).box((0.145, 0.125, 0.06), (0, 0, 0.12), COLOUR, taper=(1.0, 0.0))
    details = parts.colour(3)
    details.box((0.028, 0.005, 0.048), (-0.025, -0.0515, 0.034), COLOUR)
    details.box((0.026, 0.005, 0.026), (0.028, -0.0515, 0.055), COLOUR)
    details.box((0.005, 0.03, 0.026), (0.0615, 0, 0.055), COLOUR)
    details.box((0.024, 0.024, 0.055), (0.035, 0.022, 0.14), COLOUR)


def _christmas_village_church(parts):
    """Church on a slab: nave and square tower, with the roof and spire in a second colour and door, windows, clock and finial in a third."""
    parts.main.box((0.26, 0.14, 0.01), (0, 0, 0.005), COLOUR)
    parts.main.box((0.14, 0.09, 0.09), (0.045, 0, 0.055), COLOUR)
    parts.main.box((0.075, 0.075, 0.17), (-0.065, 0, 0.095), COLOUR)
    roofs = parts.colour(2)
    roofs.box((0.15, 0.108, 0.05), (0.048, 0, 0.125), COLOUR, taper=(1.0, 0.0))
    roofs.cylinder(0.06, 0.09, (-0.065, 0, 0.225), COLOUR, segments=4, radius_top=0.003, rotation=(0, 0, math.pi / 4))
    details = parts.colour(3)
    details.box((0.03, 0.005, 0.055), (-0.065, -0.039, 0.0375), COLOUR)
    details.cylinder(0.017, 0.005, (-0.065, -0.039, 0.14), COLOUR, segments=6, axis="Y")
    for x in (0.015, 0.075):
        details.box((0.02, 0.005, 0.048), (x, -0.0465, 0.06), COLOUR)
    details.ball(0.011, (-0.065, 0, 0.277), COLOUR, subdivisions=1)


def _nativity_set(parts):
    """Open stable (base, gabled back wall, narrow pitched roof) with two robed figures in front, and a manger and roof star in a third colour."""
    parts.main.box((0.26, 0.15, 0.012), (0, 0, 0.006), COLOUR)
    parts.main.box((0.2, 0.012, 0.11), (0, 0.06, 0.067), COLOUR)
    parts.main.box((0.2, 0.012, 0.05), (0, 0.06, 0.147), COLOUR, taper=(0.0, 1.0))
    for side in (-1, 1):
        parts.main.box((0.128, 0.05, 0.01), (side * 0.055, 0.045, 0.152), COLOUR, rotation=(0, side * math.radians(25), 0))
    for x in (-0.065, 0.065):
        parts.colour(2).cylinder(0.03, 0.075, (x, -0.01, 0.0495), COLOUR, segments=6, radius_top=0.013)
        parts.colour(2).ball(0.019, (x, -0.01, 0.1), COLOUR, subdivisions=1)
    extras = parts.colour(3)
    extras.box((0.045, 0.032, 0.026), (0, -0.025, 0.025), COLOUR, taper=1.3)
    extras.ball(0.014, (0, -0.025, 0.044), COLOUR, subdivisions=1, scale=(1.5, 1.0, 0.8))
    _star(extras, (0, 0.045, 0.2), 0.034)


def _advent_calendar_refillable(parts):
    """House shaped cabinet on a plinth: a lattice of bars over a second colour front makes 24 drawer fronts, under a roof in that colour."""
    parts.main.box((0.29, 0.085, 0.012), (0, 0, 0.006), COLOUR)
    parts.main.box((0.27, 0.07, 0.19), (0, 0, 0.107), COLOUR)
    for column in range(5):
        parts.main.box((0.006, 0.006, 0.17), ((column - 2) * 0.0417, -0.04, 0.107), COLOUR)
    for row in range(3):
        parts.main.box((0.25, 0.006, 0.006), (0, -0.04, 0.107 + (row - 1) * 0.0425), COLOUR)
    parts.colour(2).box((0.25, 0.004, 0.17), (0, -0.0365, 0.107), COLOUR)
    parts.colour(2).box((0.29, 0.09, 0.055), (0, 0, 0.2295), COLOUR, taper=(0.0, 1.0))


def _advent_number_tags_x24(parts):
    """Twenty-four small tree shaped (triangular) tags in a six by four grid, alternate ones in the second colour."""
    for index, (x, y) in enumerate(print_shapes.grid(6, 4, 0.032, 0.038)):
        builder = parts.colour(1 + (index + index // 6) % 2)
        builder.plate([(-0.013, -0.015), (0.013, -0.015), (0.0, 0.016)], 0.005, COLOUR, centre=(x, y, 0))


def _santa_sleigh_centrepiece(parts):
    """Open sleigh with a raked back and dash, on runners with upswept fronts in a second colour, loaded with two parcels and a sack in a third."""
    parts.main.tray((0.16, 0.09, 0.05), 0.008, COLOUR, centre=(0, 0, 0.03))
    parts.main.box((0.01, 0.09, 0.055), (-0.08, 0, 0.1), COLOUR, rotation=(0, -0.25, 0))
    parts.main.box((0.01, 0.09, 0.04), (0.086, 0, 0.09), COLOUR, rotation=(0, 0.6, 0))
    runners = parts.colour(2)
    for y in (-0.04, 0.04):
        runners.box((0.21, 0.01, 0.008), (0, y, 0.004), COLOUR)
        print_shapes.strut(runners, (0.1, y, 0.004), (0.138, y, 0.055), 0.01)
        for x in (-0.05, 0.05):
            runners.box((0.01, 0.01, 0.026), (x, y, 0.019), COLOUR)
    load = parts.colour(3)
    load.box((0.048, 0.05, 0.055), (-0.04, 0, 0.0655), COLOUR)
    load.box((0.036, 0.04, 0.07), (0.006, 0.01, 0.073), COLOUR)
    load.ball(0.03, (0.043, -0.005, 0.078), COLOUR, subdivisions=1)


def _snowman_figurine(parts):
    """Snowman on a round base: a big body and a smaller head, a top hat in the second colour, a scarf and carrot nose in a third."""
    parts.main.cylinder(0.06, 0.01, (0, 0, 0.005), COLOUR, segments=8)
    parts.main.ball(0.052, (0, 0, 0.055), COLOUR, subdivisions=2, scale=(1.0, 1.0, 0.9))
    parts.main.ball(0.044, (0, 0, 0.137), COLOUR, subdivisions=1, rotation=(0.55, 0, 0))
    hat = parts.colour(2)
    hat.cylinder(0.034, 0.007, (0, 0, 0.175), COLOUR, segments=6)
    hat.cylinder(0.022, 0.034, (0, 0, 0.195), COLOUR, segments=6)
    extras = parts.colour(3)
    extras.cylinder(0.036, 0.01, (0, 0, 0.099), COLOUR, segments=6)
    print_shapes.limb(extras, (0, -0.03, 0.137), (0, -0.07, 0.135), 0.009, radius_end=0.001, segments=4)


def _stocking_hooks_x4(parts):
    """Four mantelpiece hooks printed on their sides: a flat arm, a drop and an upturned hook, each with a raised strip along the arm."""
    outline = [
        (-0.045, 0.028), (0.015, 0.028), (0.015, -0.045), (0.05, -0.045), (0.05, -0.012),
        (0.037, -0.012), (0.037, -0.032), (0.028, -0.032), (0.028, 0.042), (-0.045, 0.042)]
    for x, y in print_shapes.grid(2, 2, 0.112, 0.102):
        parts.main.plate(outline, 0.018, COLOUR, centre=(x, y, 0))
        parts.colour(2).box((0.055, 0.007, 0.003), (x - 0.012, y + 0.035, 0.0195), COLOUR)


def _gift_tags_x20(parts):
    """Twenty plain rectangular tags in a five by four grid, alternate ones in the second colour."""
    for index, (x, y) in enumerate(print_shapes.grid(5, 4, 0.038, 0.03)):
        parts.colour(1 + index % 2).box((0.032, 0.022, 0.004), (x, y, 0.002), COLOUR)


def _christmas_wreath(parts):
    """Chunky eight sided ring lying flat, with a bow at the bottom in a second colour and six square berries in a third."""
    parts.main.shell(0.15, 0.03, 0.055, COLOUR, segments=8, chamfer=0.008, turn=math.pi / 8, open_base=True)
    bow = parts.colour(2)
    for side in (-1, 1):
        bow.box((0.055, 0.036, 0.012), (side * 0.034, -0.112, 0.036), COLOUR, rotation=(0, 0, side * 0.3), taper=(1.0, 0.6))
        bow.box((0.018, 0.036, 0.006), (side * 0.022, -0.152, 0.003), COLOUR, rotation=(0, 0, side * 0.35))
    bow.box((0.022, 0.024, 0.018), (0, -0.112, 0.039), COLOUR)
    for angle in (25, 65, 115, 155, 200, 340):
        turn = math.radians(angle)
        parts.colour(3).box(
            (0.024, 0.024, 0.012), (math.cos(turn) * 0.112, math.sin(turn) * 0.112, 0.036), COLOUR,
            rotation=(0, 0, turn + math.pi / 4), taper=0.6)


def _elf_door(parts):
    """Little arched door printed lying flat: frame and step, a door panel in the second colour, and knob, hinges and window in a third."""
    arch = [(-0.06, -0.095), (0.06, -0.095), (0.06, 0.045), (0.042, 0.08), (0.0, 0.095), (-0.042, 0.08), (-0.06, 0.045)]
    parts.main.plate(arch, 0.01, COLOUR)
    parts.main.box((0.145, 0.024, 0.016), (0, -0.107, 0.008), COLOUR)
    parts.colour(2).plate([(x * 0.78, y * 0.8 - 0.012) for x, y in arch], 0.004, COLOUR, centre=(0, 0, 0.01))
    details = parts.colour(3)
    details.cylinder(0.009, 0.008, (0.03, -0.02, 0.018), COLOUR, segments=6)
    for y in (-0.06, 0.02):
        details.box((0.032, 0.009, 0.003), (-0.031, y, 0.0155), COLOUR)
    details.box((0.024, 0.024, 0.003), (0, 0.035, 0.0155), COLOUR, rotation=(0, 0, math.pi / 4))


def _elf_on_the_shelf_props_set(parts):
    """Four miniature props laid out flat, one in each colour: a ladder, a mug, a sledge and a pointed hat."""
    for x in (-0.09, -0.052):
        parts.main.box((0.009, 0.15, 0.009), (x, 0, 0.0045), COLOUR)
    for y in (-0.05, -0.017, 0.017, 0.05):
        parts.main.box((0.036, 0.008, 0.007), (-0.071, y, 0.0035), COLOUR)
    mug = parts.colour(2)
    mug.shell(0.026, 0.04, 0.005, COLOUR, segments=6, centre=(0, 0.04, 0))
    mug.box((0.014, 0.007, 0.022), (0.03, 0.04, 0.02), COLOUR)
    sledge = parts.colour(3)
    for y in (-0.062, -0.022):
        sledge.box((0.085, 0.007, 0.014), (0.04, y, 0.007), COLOUR)
    sledge.box((0.07, 0.054, 0.006), (0.036, -0.042, 0.016), COLOUR)
    hat = parts.colour(4)
    hat.cylinder(0.03, 0.007, (0.072, 0.04, 0.0035), COLOUR, segments=6)
    hat.cylinder(0.024, 0.055, (0.072, 0.04, 0.0345), COLOUR, segments=6, radius_top=0.002)


def _gingerbread_house_kit(parts):
    """Assembled gable fronted house on a board, with icing in the second colour: ridge, eaves, door, windows and studs on the roof."""
    slope = math.atan2(0.06, 0.065)
    parts.main.box((0.22, 0.2, 0.01), (0, 0, 0.005), COLOUR)
    parts.main.box((0.13, 0.14, 0.08), (0, 0, 0.05), COLOUR)
    parts.main.box((0.13, 0.14, 0.06), (0, 0, 0.12), COLOUR, taper=(0.0, 1.0))
    icing = parts.colour(2)
    for side in (-1, 1):
        parts.main.box((0.105, 0.165, 0.01), (side * 0.0425, 0, 0.119), COLOUR, rotation=(0, side * slope, 0))
        icing.box((0.014, 0.17, 0.014), (side * 0.083, 0, 0.083), COLOUR)
        for y in (-0.042, 0.042):
            icing.cylinder(
                0.014, 0.006, (side * 0.047, y, 0.123), COLOUR, segments=4, rotation=(0, side * slope, 0), radius_top=0.008)
        icing.box((0.024, 0.005, 0.024), (side * 0.04, -0.0715, 0.055), COLOUR)
    icing.box((0.022, 0.17, 0.014), (0, 0, 0.157), COLOUR)
    icing.box((0.03, 0.005, 0.05), (0, -0.0715, 0.035), COLOUR)
    icing.box((0.022, 0.005, 0.022), (0, -0.0715, 0.112), COLOUR, rotation=(0, math.pi / 4, 0))


def _christmas_cracker_toys_x12(parts):
    """Twelve tiny toys in a four by three grid, a colour to each kind: four cone spinning tops, four dice and four skittles."""
    for index, (x, y) in enumerate(print_shapes.grid(4, 3, 0.046, 0.046)):
        kind = index % 3
        if kind == 0:
            parts.main.cylinder(0.019, 0.024, (x, y, 0.012), COLOUR, segments=6, radius_top=0.003)
        elif kind == 1:
            parts.colour(2).box((0.022, 0.022, 0.022), (x, y, 0.011), COLOUR)
        else:
            parts.colour(3).cylinder(0.012, 0.034, (x, y, 0.017), COLOUR, segments=5, radius_top=0.005)


def _mistletoe_hanger(parts):
    """Flat sprig with a hanging loop: a stem and four paddle leaves, with three berries and a bow in the second colour."""
    leaf = [(0.0, -0.006), (0.04, -0.017), (0.062, 0.0), (0.04, 0.017), (0.0, 0.006)]
    parts.main.box((0.009, 0.11, 0.006), (0, 0.01, 0.003), COLOUR)
    parts.main.shell(0.015, 0.006, 0.005, COLOUR, segments=6, centre=(0, 0.075, 0), open_base=True)
    for y, angle in ((0.0, -35), (0.0, 215), (-0.04, -65), (-0.04, 245)):
        parts.main.plate(_turned(leaf, math.radians(angle), (0, y)), 0.006, COLOUR)
    trim = parts.colour(2)
    for x, y in ((-0.011, -0.036), (0.011, -0.036), (0.0, -0.018)):
        trim.cylinder(0.011, 0.013, (x, y, 0.0065), COLOUR, segments=6, radius_top=0.006)
    for side in (-1, 1):
        trim.box((0.026, 0.014, 0.004), (side * 0.015, 0.045, 0.008), COLOUR, rotation=(0, 0, side * 0.4), taper=(1.0, 0.6))


def _christmas_pudding_trinket_box(parts):
    """Round pudding shaped pot with a domed lid of dripping icing in the second colour, topped with two holly leaves and a berry in a third."""
    parts.main.cylinder(0.05, 0.03, (0, 0, 0.015), COLOUR, segments=8, radius_top=0.063)
    parts.main.cylinder(0.063, 0.03, (0, 0, 0.045), COLOUR, segments=8)
    icing = parts.colour(2)
    icing.cylinder(0.065, 0.024, (0, 0, 0.072), COLOUR, segments=8, radius_top=0.048)
    icing.cylinder(0.048, 0.014, (0, 0, 0.091), COLOUR, segments=8, radius_top=0.022)
    for index in range(4):
        turn = math.radians(67.5 + index * 90)
        icing.box(
            (0.008, 0.022, 0.026), (math.cos(turn) * 0.06, math.sin(turn) * 0.06, 0.05), COLOUR, rotation=(0, 0, turn))
    holly = parts.colour(3)
    for side in (-1, 1):
        holly.box((0.036, 0.018, 0.005), (side * 0.016, 0, 0.1), COLOUR, rotation=(0, 0, side * 0.5), taper=(0.5, 0.5))
    holly.ball(0.01, (0, -0.004, 0.106), COLOUR, subdivisions=1)


def _champagne_glass_charms_x6(parts):
    """Six hexagonal charms in two rows, each with a raised mark in the second colour: diamonds, triangles and bars."""
    for index, (x, y) in enumerate(print_shapes.grid(3, 2, 0.044, 0.044)):
        parts.main.cylinder(0.018, 0.005, (x, y, 0.0025), COLOUR, segments=6)
        marks = parts.colour(2)
        kind = (index + index // 3) % 3
        if kind == 0:
            marks.box((0.014, 0.014, 0.003), (x, y, 0.0065), COLOUR, rotation=(0, 0, math.pi / 4))
        elif kind == 1:
            marks.cylinder(0.011, 0.003, (x, y, 0.0065), COLOUR, segments=3, rotation=(0, 0, math.pi / 2))
        else:
            marks.box((0.022, 0.008, 0.003), (x, y, 0.0065), COLOUR)


def _countdown_clock_prop(parts):
    """Big round clock leaning back on a foot, with hands at five to midnight, four hour marks and two alarm bells on top in the second colour."""
    tilt = math.radians(12)
    foot = (0, -0.008, 0.012)
    parts.main.box((0.16, 0.085, 0.014), (0, 0, 0.007), COLOUR)
    parts.main.cylinder(0.105, 0.03, _on_panel(foot, 0, 0.105, 0, tilt), COLOUR, segments=10, rotation=(math.pi / 2 - tilt, 0, 0))
    face = parts.colour(2)
    for x, up, size in ((0, 0.19, (0.012, 0.004, 0.024)), (0, 0.02, (0.012, 0.004, 0.024)),
                        (-0.085, 0.105, (0.024, 0.004, 0.012)), (0.085, 0.105, (0.024, 0.004, 0.012))):
        face.box(size, _on_panel(foot, x, up, 0.0165, tilt), COLOUR, rotation=_leaning(tilt))
    face.box((0.011, 0.004, 0.05), _on_panel(foot, 0, 0.13, 0.0165, tilt), COLOUR, rotation=_leaning(tilt))
    spin = math.radians(-30)
    face.box(
        (0.011, 0.004, 0.075), _on_panel(foot, math.sin(spin) * 0.0375, 0.105 + math.cos(spin) * 0.0375, 0.0165, tilt), COLOUR,
        rotation=_leaning(tilt, spin))
    face.cylinder(0.013, 0.008, _on_panel(foot, 0, 0.105, 0.018, tilt), COLOUR, segments=6, rotation=(math.pi / 2 - tilt, 0, 0))
    for side in (-1, 1):
        spin = side * math.radians(35)
        face.cylinder(
            0.032, 0.03, _on_panel(foot, math.sin(spin) * 0.115, 0.105 + math.cos(spin) * 0.115, 0, tilt), COLOUR,
            segments=6, rotation=_leaning(tilt, spin), radius_top=0.014)


def _lunar_new_year_lantern(parts):
    """Round bellied lantern standing on its base, with the end caps, a band round the middle and a carrying handle in the second colour."""
    parts.main.cylinder(0.06, 0.085, (0, 0, 0.0625), COLOUR, segments=8, radius_top=0.1)
    parts.main.cylinder(0.1, 0.085, (0, 0, 0.1475), COLOUR, segments=8, radius_top=0.06)
    trim = parts.colour(2)
    trim.cylinder(0.056, 0.02, (0, 0, 0.01), COLOUR, segments=8)
    trim.cylinder(0.056, 0.02, (0, 0, 0.2), COLOUR, segments=8)
    trim.cylinder(0.104, 0.012, (0, 0, 0.105), COLOUR, segments=8)
    for x in (-0.03, 0.03):
        trim.box((0.009, 0.009, 0.035), (x, 0, 0.2275), COLOUR)
    trim.box((0.069, 0.009, 0.009), (0, 0, 0.2455), COLOUR)


def _red_envelope_holder(parts):
    """Leaning stand for envelopes: base, low front panel and tall back panel, with a diamond, a medallion and a top rail in the second colour."""
    tilt = math.radians(12)
    front, back = (0, -0.026, 0.01), (0, 0.02, 0.01)
    parts.main.box((0.15, 0.078, 0.012), (0, 0, 0.006), COLOUR, bevel=0.003)
    parts.main.box((0.14, 0.01, 0.05), _on_panel(front, 0, 0.025, 0, tilt), COLOUR, rotation=_leaning(tilt))
    parts.main.box((0.14, 0.01, 0.1), _on_panel(back, 0, 0.05, 0, tilt), COLOUR, rotation=_leaning(tilt))
    trim = parts.colour(2)
    trim.box((0.03, 0.003, 0.03), _on_panel(front, 0, 0.026, 0.0065, tilt), COLOUR, rotation=_leaning(tilt, math.pi / 4))
    trim.cylinder(0.02, 0.003, _on_panel(back, 0, 0.074, 0.0065, tilt), COLOUR, segments=8, rotation=(math.pi / 2 - tilt, 0, 0))
    trim.box((0.14, 0.013, 0.007), _on_panel(back, 0, 0.1035, 0, tilt), COLOUR, rotation=_leaning(tilt))


def _best_dad_keyring(parts):
    """Flat tag with a ring loop at one end and two rows of raised letters, four over three, in the second colour."""
    parts.main.box((0.1, 0.042, 0.006), (0.012, 0, 0.003), COLOUR, bevel=0.002)
    parts.main.shell(0.015, 0.006, 0.005, COLOUR, segments=6, centre=(-0.047, 0, 0), open_base=True)
    letters = parts.colour(2)
    for index, width in enumerate((0.014, 0.012, 0.013, 0.014)):
        letters.box((width, 0.013, 0.003), (0.016 + (index - 1.5) * 0.02, 0.009, 0.0075), COLOUR)
    for index, width in enumerate((0.014, 0.015, 0.014)):
        letters.box((width, 0.013, 0.003), (0.016 + (index - 1) * 0.02, -0.009, 0.0075), COLOUR)


def _golf_tee_and_marker_set(parts):
    """Four tees standing head down in a row, with three round ball markers in the second colour in front."""
    for x, _ in print_shapes.grid(4, 1, 0.04, 0):
        parts.main.cylinder(0.015, 0.009, (x, 0.028, 0.0045), COLOUR, segments=5, radius_top=0.007)
        parts.main.cylinder(0.007, 0.06, (x, 0.028, 0.039), COLOUR, segments=5, radius_top=0.0015)
    for x, _ in print_shapes.grid(3, 1, 0.05, 0):
        parts.colour(2).cylinder(0.02, 0.005, (x, -0.03, 0.0025), COLOUR, segments=6)


def _desk_valet_tray(parts):
    """Shallow tray with one large and two small compartments, each lined with a pad in the second colour."""
    parts.main.tray((0.24, 0.16, 0.035), 0.008, COLOUR, chamfer=0.004)
    parts.main.box((0.007, 0.148, 0.03), (0.03, 0, 0.015), COLOUR)
    parts.main.box((0.085, 0.007, 0.03), (0.073, 0, 0.015), COLOUR)
    pads = parts.colour(2)
    pads.box((0.126, 0.132, 0.003), (-0.043, 0, 0.0095), COLOUR)
    for y in (-0.0375, 0.0375):
        pads.box((0.068, 0.058, 0.003), (0.073, y, 0.0095), COLOUR)


def _beach_toy_set(parts):
    """Flared bucket with a spade, a rake and a starfish sand mould laid beside it, each in its own colour."""
    parts.main.shell(0.045, 0.09, 0.006, COLOUR, segments=8, centre=(-0.075, 0.03, 0), radius_top=0.062)
    spade = parts.colour(2)
    spade.box((0.048, 0.06, 0.007), (0.03, -0.04, 0.0035), COLOUR, taper=(0.8, 1.0))
    spade.box((0.011, 0.085, 0.009), (0.03, 0.03, 0.0045), COLOUR)
    spade.box((0.038, 0.013, 0.009), (0.03, 0.078, 0.0045), COLOUR)
    rake = parts.colour(3)
    rake.box((0.052, 0.013, 0.009), (0.098, -0.035, 0.0045), COLOUR)
    for offset in (-0.021, 0.0, 0.021):
        rake.box((0.008, 0.028, 0.007), (0.098 + offset, -0.054, 0.0035), COLOUR)
    rake.box((0.011, 0.115, 0.009), (0.098, 0.027, 0.0045), COLOUR)
    star = [
        (math.cos(math.tau * index / 10 + math.pi / 2) * (0.04 if index % 2 == 0 else 0.018),
         math.sin(math.tau * index / 10 + math.pi / 2) * (0.04 if index % 2 == 0 else 0.018))
        for index in range(10)]
    parts.colour(4).plate(star, 0.014, COLOUR, centre=(-0.075, -0.08, 0))


def _water_gun(parts):
    """Toy squirter lying on its side: a one piece body and grip, with the water tank, nozzle, trigger and a side stripe in the second colour."""
    body = [
        (-0.085, -0.07), (-0.05, -0.07), (-0.038, -0.005), (0.02, -0.005), (0.03, 0.008),
        (0.11, 0.008), (0.11, 0.03), (-0.08, 0.03), (-0.1, 0.015)]
    parts.main.plate(body, 0.028, COLOUR)
    trim = parts.colour(2)
    trim.cylinder(0.022, 0.09, (-0.025, 0.05, 0.0225), COLOUR, segments=8, axis="X")
    trim.cylinder(0.009, 0.014, (0.117, 0.019, 0.014), COLOUR, segments=6, axis="X")
    trim.box((0.009, 0.024, 0.02), (-0.016, -0.016, 0.01), COLOUR, rotation=(0, 0, 0.3))
    trim.box((0.085, 0.008, 0.003), (0.045, 0.019, 0.0295), COLOUR)


VARIANTS = {
    "bonfire_table_centrepiece": _bonfire_table_centrepiece,
    "personalised_bauble": _personalised_bauble,
    "christmas_tree_desk": _christmas_tree_desk,
    "christmas_village_house": _christmas_village_house,
    "christmas_village_church": _christmas_village_church,
    "nativity_set": _nativity_set,
    "advent_calendar_refillable": _advent_calendar_refillable,
    "advent_number_tags_x24": _advent_number_tags_x24,
    "santa_sleigh_centrepiece": _santa_sleigh_centrepiece,
    "snowman_figurine": _snowman_figurine,
    "stocking_hooks_x4": _stocking_hooks_x4,
    "gift_tags_x20": _gift_tags_x20,
    "christmas_wreath": _christmas_wreath,
    "elf_door": _elf_door,
    "elf_on_the_shelf_props_set": _elf_on_the_shelf_props_set,
    "gingerbread_house_kit": _gingerbread_house_kit,
    "christmas_cracker_toys_x12": _christmas_cracker_toys_x12,
    "mistletoe_hanger": _mistletoe_hanger,
    "christmas_pudding_trinket_box": _christmas_pudding_trinket_box,
    "champagne_glass_charms_x6": _champagne_glass_charms_x6,
    "countdown_clock_prop": _countdown_clock_prop,
    "lunar_new_year_lantern": _lunar_new_year_lantern,
    "red_envelope_holder": _red_envelope_holder,
    "best_dad_keyring": _best_dad_keyring,
    "golf_tee_and_marker_set": _golf_tee_and_marker_set,
    "desk_valet_tray": _desk_valet_tray,
    "beach_toy_set": _beach_toy_set,
    "water_gun": _water_gun,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
