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


# Tools and workshop, Spare room tier

def _screwdriver_rack(builder):
    """Wall plate with a toothed rail that screwdrivers drop into and a rest bar below it."""
    builder.box((0.27, 0.012, 0.13), (0, 0.03, 0.065), COLOUR, bevel=0.004)
    for x, _ in print_shapes.grid(8, 1, 0.035, 0):
        builder.box((0.012, 0.05, 0.012), (x, 0.0, 0.105), COLOUR)
    builder.box((0.27, 0.03, 0.012), (0, 0.01, 0.03), COLOUR)


def _drill_bit_index(builder):
    """Two-step block with a row of collars on each step, growing in size from left to right."""
    print_shapes.stepped_rack(builder, 0.2, 2, 0.04, 0.03, 0.03, lip=0.0)
    for row, y, z in ((0, -0.02, 0.03), (1, 0.02, 0.06)):
        for index, (x, _) in enumerate(print_shapes.grid(5, 1, 0.036, 0)):
            side = 0.01 + (index + row * 5) * 0.0014
            builder.box((side, side, 0.008), (x, y, z + 0.003), COLOUR)


def _wrench_organiser(builder):
    """Long base with eight leaning fins that hold spanners on edge."""
    builder.box((0.27, 0.11, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    for x, _ in print_shapes.grid(8, 1, 0.03, 0):
        builder.box((0.006, 0.1, 0.055), (x + 0.008, 0, 0.036), COLOUR, rotation=(0, math.radians(22), 0))


def _socket_rail(builder):
    """Long rail with eight pegs for sockets, smallest to largest."""
    builder.box((0.28, 0.04, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    for index, (x, _) in enumerate(print_shapes.grid(8, 1, 0.032, 0)):
        builder.cylinder(0.006 + index * 0.0009, 0.02, (x, 0, 0.022), COLOUR, segments=6)


def _pegboard_hooks_x10(builder):
    """Ten pegboard hooks lying flat in two rows: an arm with an upturned tip."""
    for x, y in print_shapes.grid(5, 2, 0.026, 0.06):
        builder.box((0.01, 0.045, 0.008), (x, y, 0.004), COLOUR)
        builder.box((0.01, 0.008, 0.02), (x, y - 0.0185, 0.01), COLOUR)


def _battery_wall_mount_power_tools(builder):
    """Wall plate with two docks, one above the other, that tool batteries slide into."""
    builder.box((0.13, 0.012, 0.17), (0, 0.03, 0.085), COLOUR, bevel=0.004)
    for z in (0.045, 0.125):
        builder.box((0.1, 0.05, 0.008), (0, 0.0, z + 0.03), COLOUR)
        for side in (-1, 1):
            builder.box((0.012, 0.05, 0.03), (side * 0.044, 0.0, z + 0.012), COLOUR)


def _sanding_block(builder):
    """Flat sole with a rounded grip on top and a clamp bar at each end for the paper."""
    builder.box((0.13, 0.07, 0.016), (0, 0, 0.008), COLOUR)
    builder.box((0.085, 0.05, 0.03), (0, 0, 0.03), COLOUR, bevel=0.008, bevel_segments=2)
    for side in (-1, 1):
        builder.box((0.012, 0.07, 0.008), (side * 0.056, 0, 0.02), COLOUR)


def _clamp_blocks_x4(builder):
    """Four V blocks: a low base with two wedges that leave a notch for round work."""
    for x, y in print_shapes.grid(2, 2, 0.06, 0.055):
        builder.box((0.046, 0.04, 0.012), (x, y, 0.006), COLOUR)
        for side in (-1, 1):
            builder.box((0.016, 0.04, 0.022), (x + side * 0.015, y, 0.022), COLOUR, taper=(0.35, 1.0))


def _dust_extraction_adapter(builder):
    """Stepped hose adapter: a wide collar, a cone and a narrow collar, open through the middle."""
    builder.shell(0.048, 0.04, 0.005, COLOUR, segments=8, open_base=True)
    builder.cylinder(0.048, 0.03, (0, 0, 0.055), COLOUR, segments=8, radius_top=0.032)
    builder.shell(0.032, 0.04, 0.005, COLOUR, segments=8, centre=(0, 0, 0.068), open_base=True)


def _saw_guide(builder):
    """Base plate with an upright fence in two halves, leaving a slot for the blade, and a gusset behind each."""
    builder.box((0.2, 0.085, 0.008), (0, 0, 0.004), COLOUR)
    for side in (-1, 1):
        builder.box((0.092, 0.01, 0.055), (side * 0.054, 0.01, 0.0335), COLOUR)
        builder.box((0.008, 0.04, 0.045), (side * 0.07, 0.03, 0.03), COLOUR, taper=(1.0, 0.15))
    builder.box((0.05, 0.03, 0.012), (0, -0.025, 0.014), COLOUR)


def _router_template(builder):
    """Flat frame with a rectangular opening to rout round, a clamping ear each end and a guide bush."""
    builder.outline([(-0.09, -0.065), (0.09, -0.065), (0.09, 0.065), (-0.09, 0.065)], 0.008, 0.028, COLOUR)
    for side in (-1, 1):
        builder.box((0.03, 0.05, 0.008), (side * 0.1, 0, 0.004), COLOUR)
    builder.shell(0.02, 0.016, 0.006, COLOUR, segments=6, centre=(0.02, -0.01, 0), open_base=True)


def _tape_measure_holder(builder):
    """Open pocket for a tape measure with a belt clip down the back."""
    builder.tray((0.085, 0.04, 0.07), 0.006, COLOUR, centre=(0, -0.005, 0), chamfer=0.004)
    builder.box((0.05, 0.006, 0.085), (0, 0.028, 0.0425), COLOUR)
    builder.box((0.05, 0.012, 0.01), (0, 0.021, 0.075), COLOUR)


def _cable_reel(builder):
    """Big reel on an A-frame stand with a crank handle on one side."""
    for side in (-1, 1):
        builder.cylinder(0.09, 0.008, (side * 0.045, 0, 0.1), COLOUR, segments=10, axis="X")
        print_shapes.strut(builder, (side * 0.062, -0.07, 0.006), (side * 0.062, 0, 0.1), 0.012)
        print_shapes.strut(builder, (side * 0.062, 0.07, 0.006), (side * 0.062, 0, 0.1), 0.012)
    builder.cylinder(0.035, 0.09, (0, 0, 0.1), COLOUR, segments=8, axis="X")
    for y in (-0.07, 0.07):
        builder.box((0.15, 0.016, 0.012), (0, y, 0.006), COLOUR)
    builder.box((0.01, 0.012, 0.05), (0.074, 0, 0.12), COLOUR)
    builder.box((0.03, 0.012, 0.012), (0.09, 0, 0.142), COLOUR)


def _workbench_vice_jaws_soft(builder):
    """Pair of soft jaw pads facing each other, each a ridged face with a lip that hooks over the vice."""
    for side in (-1, 1):
        y = side * 0.025
        builder.box((0.12, 0.01, 0.045), (0, y, 0.0225), COLOUR)
        builder.box((0.12, 0.022, 0.006), (0, y + side * 0.012, 0.042), COLOUR)
        for z in (0.012, 0.024):
            builder.box((0.12, 0.004, 0.005), (0, y - side * 0.006, z), COLOUR)


def _hammer_holder(builder):
    """Wall plate with two sturdy prongs that cradle a hammer head."""
    builder.box((0.085, 0.012, 0.1), (0, 0.03, 0.05), COLOUR, bevel=0.004)
    for side in (-1, 1):
        builder.box((0.016, 0.06, 0.016), (side * 0.024, -0.003, 0.05), COLOUR)
        builder.box((0.016, 0.014, 0.034), (side * 0.024, -0.026, 0.059), COLOUR)


def _spool_holder_filament(builder):
    """Open stand for a spool of filament: two A-frames on runners with an axle across the top."""
    for side in (-1, 1):
        x = side * 0.085
        builder.box((0.022, 0.2, 0.012), (x, 0, 0.006), COLOUR)
        print_shapes.strut(builder, (x, -0.085, 0.01), (x, 0, 0.18), 0.016)
        print_shapes.strut(builder, (x, 0.085, 0.01), (x, 0, 0.18), 0.016)
    builder.cylinder(0.012, 0.22, (0, 0, 0.178), COLOUR, segments=8, axis="X")
    builder.box((0.17, 0.016, 0.012), (0, 0.085, 0.006), COLOUR)


def _print_removal_scraper(builder):
    """Flat scraper: a chunky handle with a thin blade that widens to the edge."""
    builder.box((0.035, 0.1, 0.014), (0, 0.045, 0.007), COLOUR, bevel=0.004)
    builder.plate([(-0.014, 0.0), (-0.035, -0.07), (0.035, -0.07), (0.014, 0.0)], 0.004, COLOUR)


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
    "screwdriver_rack": _screwdriver_rack,
    "drill_bit_index": _drill_bit_index,
    "wrench_organiser": _wrench_organiser,
    "socket_rail": _socket_rail,
    "pegboard_hooks_x10": _pegboard_hooks_x10,
    "battery_wall_mount_power_tools": _battery_wall_mount_power_tools,
    "sanding_block": _sanding_block,
    "clamp_blocks_x4": _clamp_blocks_x4,
    "dust_extraction_adapter": _dust_extraction_adapter,
    "saw_guide": _saw_guide,
    "router_template": _router_template,
    "tape_measure_holder": _tape_measure_holder,
    "cable_reel": _cable_reel,
    "workbench_vice_jaws_soft": _workbench_vice_jaws_soft,
    "hammer_holder": _hammer_holder,
    "spool_holder_filament": _spool_holder_filament,
    "print_removal_scraper": _print_removal_scraper,
    "skull_anatomy_model": _skull_anatomy_model,
    "braille_alphabet_tiles": _braille_alphabet_tiles,
    "bridge_building_kit": _bridge_building_kit,
    "fossil_replica": _fossil_replica,
    "pendulum_wave_kit": _pendulum_wave_kit,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
