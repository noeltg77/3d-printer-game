"""Printed item generator for the Home organisation category.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_home.py -- \
    --variant drawer_divider_set --out assets/models/prints/drawer_divider_set.glb
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


def _drawer_divider_set(builder):
    """Shallow tray split into six compartments."""
    print_shapes.divided_tray(builder, (0.24, 0.16, 0.045), 0.008, across=2, along=1, chamfer=0.004)


def _stackable_storage_bin(builder):
    """Deep bin with leaning sides and a proud rim for the next one to sit in, plus a label tab."""
    builder.tray((0.24, 0.18, 0.12), 0.009, COLOUR, taper=0.016, chamfer=0.004, rim=(0.008, 0.022))
    builder.box((0.08, 0.008, 0.03), (0, -0.092, 0.07), COLOUR, rotation=(math.radians(-7.6), 0, 0))


def _gridfinity_baseplate_4x4(builder):
    """Flat square plate with a four by four grid of shallow sockets."""
    print_shapes.divided_tray(
        builder, (0.2, 0.2, 0.018), 0.008, across=3, along=3, floor=0.007, divider_height=0.016, chamfer=0.003)


def _gridfinity_bin_pack_x6(builder):
    """Six small square bins in two rows, the back row taller."""
    for x, y in print_shapes.grid(3, 2, 0.072, 0.072):
        builder.tray((0.062, 0.062, 0.07 if y > 0 else 0.042), 0.005, COLOUR, centre=(x, y, 0))


def _label_holder_clips_x10(builder):
    """Ten little label clips in two rows: a flat plate with an upturned lip at the front."""
    for x, y in print_shapes.grid(5, 2, 0.038, 0.056):
        builder.box((0.03, 0.044, 0.005), (x, y, 0.0025), COLOUR)
        builder.box((0.03, 0.006, 0.016), (x, y - 0.019, 0.008), COLOUR)


def _cable_tidy_box(builder):
    """Long closed box with an overhanging lid and a cable port at each end."""
    builder.box((0.27, 0.12, 0.085), (0, 0, 0.0425), COLOUR, bevel=0.008)
    builder.box((0.285, 0.135, 0.03), (0, 0, 0.097), COLOUR, bevel=0.007)
    for side in (-1, 1):
        builder.box((0.014, 0.055, 0.03), (side * 0.136, 0, 0.05), COLOUR)


def _hook_rail_x5_hooks(builder):
    """Rail standing on its long edge with five upturned hooks along the front."""
    builder.box((0.27, 0.014, 0.065), (0, 0.019, 0.0325), COLOUR, bevel=0.004)
    for x, _ in print_shapes.grid(5, 1, 0.054, 0):
        builder.box((0.016, 0.036, 0.012), (x, -0.004, 0.02), COLOUR)
        builder.box((0.016, 0.012, 0.03), (x, -0.02, 0.029), COLOUR)


def _battery_organiser(builder):
    """Two stepped rows of four cells, the back row taller."""
    print_shapes.divided_tray(builder, (0.2, 0.07, 0.095), 0.008, across=3, centre=(0, 0.034, 0), chamfer=0.003)
    print_shapes.divided_tray(builder, (0.2, 0.07, 0.055), 0.008, across=3, centre=(0, -0.034, 0), chamfer=0.003)


def _remote_control_holder(builder):
    """Three upright slots side by side with a tall back."""
    print_shapes.divided_tray(builder, (0.2, 0.1, 0.1), 0.009, across=2, centre=(0, -0.004, 0), chamfer=0.005)
    builder.box((0.2, 0.012, 0.15), (0, 0.048, 0.075), COLOUR, bevel=0.004)


def _bag_clip_set_x6(builder):
    """Six long clips side by side, each a pair of jaws hinged at the back and slightly open."""
    for x, _ in print_shapes.grid(6, 1, 0.03, 0):
        builder.box((0.018, 0.12, 0.01), (x, 0, 0.005), COLOUR)
        builder.box((0.018, 0.12, 0.01), (x, 0, 0.022), COLOUR, rotation=(math.radians(-5), 0, 0))
        builder.box((0.018, 0.018, 0.022), (x, 0.051, 0.011), COLOUR)


def _spice_jar_lid_adapters_x6(builder):
    """Six round screw-on lids in two rows."""
    for x, y in print_shapes.grid(3, 2, 0.064, 0.064):
        builder.cylinder(0.028, 0.02, (x, y, 0.01), COLOUR, segments=10, radius_top=0.025)


def _sock_and_underwear_drawer_grid(builder):
    """Big drawer insert, four by three compartments."""
    print_shapes.divided_tray(builder, (0.3, 0.22, 0.075), 0.008, across=3, along=2, chamfer=0.004)


def _sticky_note_holder(builder):
    """Square tray for the pad, a tall back and a pen rest along the front."""
    builder.tray((0.12, 0.12, 0.03), 0.007, COLOUR, centre=(0, 0.008, 0), chamfer=0.003)
    builder.box((0.12, 0.01, 0.08), (0, 0.063, 0.04), COLOUR, bevel=0.003)
    builder.box((0.12, 0.018, 0.014), (0, -0.059, 0.007), COLOUR)


def _charging_cable_spool(builder):
    """Cable spool lying flat: two round flanges on a narrow hub."""
    builder.cylinder(0.062, 0.008, (0, 0, 0.004), COLOUR, segments=12)
    builder.cylinder(0.026, 0.03, (0, 0, 0.022), COLOUR, segments=8)
    builder.cylinder(0.062, 0.008, (0, 0, 0.04), COLOUR, segments=12)


def _coat_peg_x3(builder):
    """Three pegs standing on their wall plates, each with a knob on the end."""
    for x, _ in print_shapes.grid(3, 1, 0.072, 0):
        builder.cylinder(0.03, 0.008, (x, 0, 0.004), COLOUR, segments=8)
        builder.cylinder(0.012, 0.052, (x, 0, 0.034), COLOUR, segments=6, radius_top=0.009)
        builder.cylinder(0.018, 0.014, (x, 0, 0.066), COLOUR, segments=6, radius_top=0.015)


def _lid_organiser_rack(builder):
    """Wide rack of four equal upright panels for pan lids."""
    print_shapes.slot_rack(builder, 0.28, 0.18, (0.1, 0.1, 0.1, 0.1), lean=0.0)


VARIANTS = {
    "drawer_divider_set": _drawer_divider_set,
    "stackable_storage_bin": _stackable_storage_bin,
    "gridfinity_baseplate_4x4": _gridfinity_baseplate_4x4,
    "gridfinity_bin_pack_x6": _gridfinity_bin_pack_x6,
    "label_holder_clips_x10": _label_holder_clips_x10,
    "cable_tidy_box": _cable_tidy_box,
    "hook_rail_x5_hooks": _hook_rail_x5_hooks,
    "battery_organiser": _battery_organiser,
    "remote_control_holder": _remote_control_holder,
    "bag_clip_set_x6": _bag_clip_set_x6,
    "spice_jar_lid_adapters_x6": _spice_jar_lid_adapters_x6,
    "sock_and_underwear_drawer_grid": _sock_and_underwear_drawer_grid,
    "sticky_note_holder": _sticky_note_holder,
    "charging_cable_spool": _charging_cable_spool,
    "coat_peg_x3": _coat_peg_x3,
    "lid_organiser_rack": _lid_organiser_rack,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
