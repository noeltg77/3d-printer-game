"""Printed item generator for the Tools and workshop and Education and STEM categories.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_workshop.py -- \
    --variant marking_gauge --out assets/models/prints/marking_gauge.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
import print_shapes
from common import MeshBuilder
from print_shapes import COLOUR


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), required=True)


def build(args, rng):
    builder = MeshBuilder(material=common.TINT_MATERIAL_NAME)
    VARIANTS[args.variant](builder)
    builder.finish(args.out.stem)


# Tools and workshop

def _marking_gauge(builder):
    """Long beam through a fence block, with a thumbscrew on top and a scribing pin at one end."""
    builder.box((0.035, 0.075, 0.055), (0.02, 0, 0.0275), COLOUR, bevel=0.005)
    builder.box((0.21, 0.018, 0.018), (0, 0, 0.028), COLOUR)
    builder.cylinder(0.012, 0.016, (0.02, 0, 0.062), COLOUR, segments=6)
    builder.box((0.006, 0.006, 0.02), (-0.097, 0, 0.012), COLOUR)


def _hex_key_holder(builder):
    """Narrow strip of seven slots, one for each key size."""
    print_shapes.divided_tray(builder, (0.15, 0.035, 0.045), 0.006, across=6, chamfer=0.003)


def _glue_bottle_holder(builder):
    """Solid block with three sockets on top for bottles standing nozzle down."""
    builder.box((0.2, 0.08, 0.03), (0, 0, 0.015), COLOUR, bevel=0.005)
    for x, _ in print_shapes.grid(3, 1, 0.062, 0):
        builder.shell(0.03, 0.03, 0.006, COLOUR, segments=6, centre=(x, 0, 0.026), turn=math.pi / 6)


def _filament_clip_set_x10(builder):
    """Ten tiny spool clips in two rows, each an L with a hooked end."""
    for x, y in print_shapes.grid(5, 2, 0.032, 0.045):
        builder.box((0.022, 0.034, 0.006), (x, y, 0.003), COLOUR)
        builder.box((0.022, 0.008, 0.014), (x, y + 0.013, 0.007), COLOUR)


def _nozzle_and_tool_caddy(builder):
    """Low row of small pockets for nozzles in front of two tall pockets for tools."""
    print_shapes.divided_tray(builder, (0.2, 0.06, 0.035), 0.007, across=4, centre=(0, -0.034, 0), chamfer=0.003)
    print_shapes.divided_tray(builder, (0.2, 0.075, 0.1), 0.007, across=1, centre=(0, 0.0295, 0), chamfer=0.003)


def _calibration_cube_pack_of_10(builder):
    """Ten small test cubes in two rows, each with a raised mark on top."""
    for x, y in print_shapes.grid(5, 2, 0.034, 0.034):
        builder.box((0.024, 0.024, 0.024), (x, y, 0.012), COLOUR)
        builder.box((0.01, 0.01, 0.003), (x, y, 0.0255), COLOUR)


def _benchy_pack_of_5(builder):
    """Five little tug boats in a row: hull with a pointed bow, cabin and funnel."""
    for x, _ in print_shapes.grid(5, 1, 0.05, 0):
        builder.box((0.032, 0.06, 0.018), (x, 0.008, 0.009), COLOUR)
        builder.box((0.0226, 0.0226, 0.018), (x, -0.022, 0.009), COLOUR, rotation=(0, 0, math.pi / 4))
        builder.box((0.024, 0.024, 0.02), (x, 0.012, 0.028), COLOUR)
        builder.box((0.009, 0.009, 0.014), (x, 0.03, 0.025), COLOUR)


# Education and STEM

def _skull_anatomy_model(builder):
    """Skull: a large faceted cranium over a narrower face and jaw, with eye sockets and a nose."""
    builder.ball(0.075, (0, 0.012, 0.115), COLOUR, scale=(0.9, 1.05, 0.9))
    builder.box((0.085, 0.05, 0.07), (0, -0.04, 0.07), COLOUR, taper=(1.1, 1.0))
    builder.box((0.07, 0.06, 0.035), (0, -0.036, 0.0175), COLOUR, taper=(1.15, 1.0))
    for side in (-1, 1):
        builder.cylinder(0.019, 0.014, (side * 0.024, -0.064, 0.098), COLOUR, segments=6, axis="Y")
    builder.box((0.014, 0.012, 0.022), (0, -0.068, 0.066), COLOUR, taper=(0.3, 1.0))


def _braille_alphabet_tiles(builder):
    """Six square tiles in two rows, each with its letter in raised dots."""
    letters = (((0, 0),), ((0, 0), (0, 1)), ((0, 0), (1, 0)), ((0, 0), (1, 0), (1, 1)), ((0, 0), (1, 1)), ((0, 0), (1, 0), (0, 1)))
    for (x, y), dots in zip(print_shapes.grid(3, 2, 0.06, 0.06), letters):
        builder.box((0.052, 0.052, 0.008), (x, y, 0.004), COLOUR)
        for column, row in dots:
            builder.box((0.009, 0.009, 0.005), (x - 0.008 + column * 0.016, y + 0.014 - row * 0.014, 0.0095), COLOUR)


def _bridge_building_kit(builder):
    """Assembled truss bridge: a deck with a zigzag truss and top chord down each side."""
    builder.box((0.29, 0.07, 0.008), (0, 0, 0.004), COLOUR)
    nodes = [(-0.14, 0.006), (-0.093, 0.075), (-0.047, 0.006), (0.0, 0.075), (0.047, 0.006), (0.093, 0.075), (0.14, 0.006)]
    for y in (-0.03, 0.03):
        builder.box((0.2, 0.008, 0.008), (0, y, 0.075), COLOUR)
        for (x1, z1), (x2, z2) in zip(nodes, nodes[1:]):
            print_shapes.strut(builder, (x1, y, z1), (x2, y, z2), 0.007)


def _fossil_replica(builder):
    """Coiled ammonite standing proud of a rough stone slab."""
    builder.box((0.17, 0.14, 0.016), (0, 0, 0.008), COLOUR, bevel=0.005, rotation=(0, 0, 0.12))
    points = []
    for step in range(9):
        along = step / 8
        angle = math.radians(200 - step * 62)
        reach = 0.05 * (1.0 - along * 0.82)
        points.append((reach * math.cos(angle), reach * math.sin(angle), 0.021, 0.015 - along * 0.011))
    for start, end in zip(points, points[1:]):
        print_shapes.limb(builder, start[:3], end[:3], start[3], end[3])


def _pendulum_wave_kit(builder):
    """Frame with a top rail and five pendulums of different lengths hanging in a row."""
    builder.box((0.28, 0.1, 0.012), (0, 0, 0.006), COLOUR)
    for side in (-1, 1):
        builder.box((0.012, 0.016, 0.17), (side * 0.13, 0, 0.095), COLOUR)
    builder.box((0.272, 0.016, 0.012), (0, 0, 0.176), COLOUR)
    for index, (x, _) in enumerate(print_shapes.grid(5, 1, 0.045, 0)):
        drop = 0.06 + index * 0.017
        print_shapes.strut(builder, (x, 0, 0.172), (x, 0, 0.172 - drop), 0.004)
        builder.ball(0.014, (x, 0, 0.172 - drop - 0.01), COLOUR, subdivisions=1)


VARIANTS = {
    "marking_gauge": _marking_gauge,
    "hex_key_holder": _hex_key_holder,
    "glue_bottle_holder": _glue_bottle_holder,
    "filament_clip_set_x10": _filament_clip_set_x10,
    "nozzle_and_tool_caddy": _nozzle_and_tool_caddy,
    "calibration_cube_pack_of_10": _calibration_cube_pack_of_10,
    "benchy_pack_of_5": _benchy_pack_of_5,
    "skull_anatomy_model": _skull_anatomy_model,
    "braille_alphabet_tiles": _braille_alphabet_tiles,
    "bridge_building_kit": _bridge_building_kit,
    "fossil_replica": _fossil_replica,
    "pendulum_wave_kit": _pendulum_wave_kit,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
