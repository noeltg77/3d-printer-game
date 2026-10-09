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


# Home organisation, Spare room tier

HOOK = [(-0.008, 0.03), (-0.008, -0.04), (0.004, -0.055), (0.03, -0.055), (0.03, -0.03), (0.02, -0.03),
        (0.02, -0.043), (0.008, -0.043), (0.008, 0.03)]


def _under_shelf_basket(builder):
    """Wide basket with two arms that rise at the back and reach forward to slide over a shelf."""
    builder.tray((0.26, 0.18, 0.075), 0.007, COLOUR, chamfer=0.004)
    for side in (-1, 1):
        builder.box((0.02, 0.008, 0.07), (side * 0.11, 0.086, 0.105), COLOUR)
        builder.box((0.02, 0.17, 0.008), (side * 0.11, 0.005, 0.14), COLOUR)


def _adhesive_wall_hooks_x4(builder):
    """Four stick-on hooks lying on their backs: a flat pad with an upturned hook."""
    for x, y in print_shapes.grid(2, 2, 0.045, 0.055):
        builder.box((0.032, 0.044, 0.005), (x, y, 0.0025), COLOUR)
        builder.box((0.014, 0.012, 0.02), (x, y - 0.01, 0.014), COLOUR)
        builder.box((0.014, 0.022, 0.006), (x, y - 0.005, 0.026), COLOUR)
    builder.enlarge(1.3)


def _shoe_rack_spacer_clips_x8(builder):
    """Eight U-shaped spacer clips in two rows."""
    clip = [(-0.016, -0.016), (0.016, -0.016), (0.016, 0.016), (0.007, 0.016), (0.007, -0.006), (-0.007, -0.006), (-0.007, 0.016), (-0.016, 0.016)]
    for x, y in print_shapes.grid(4, 2, 0.042, 0.045):
        builder.plate(clip, 0.014, COLOUR, centre=(x, y, 0))


def _wardrobe_hanger_hooks_x4(builder):
    """Four flat hooks side by side, each a shank with a J at the bottom to hang the next hanger from."""
    for x, _ in print_shapes.grid(4, 1, 0.05, 0):
        builder.plate(HOOK, 0.008, COLOUR, centre=(x - 0.01, 0.012, 0))


def _plastic_bag_dispenser(builder):
    """Tall square bin, wider at the top, with a pull slot surround low on the front and a hanging tab behind."""
    builder.tray((0.11, 0.11, 0.24), 0.007, COLOUR, taper=0.012, chamfer=0.004)
    builder.box((0.06, 0.012, 0.04), (0, -0.048, 0.045), COLOUR)
    builder.plate([(-0.02, 0.0), (0.02, 0.0), (0.02, 0.03), (0.0, 0.045), (-0.02, 0.03)], 0.007, COLOUR, centre=(0, 0.052, 0.235), upright=True)


def _cupboard_door_caddy(builder):
    """Long caddy with two straps up the back that hook over the top of a cupboard door."""
    builder.tray((0.24, 0.085, 0.1), 0.007, COLOUR, chamfer=0.004)
    for side in (-1, 1):
        builder.box((0.022, 0.007, 0.12), (side * 0.08, 0.046, 0.155), COLOUR)
        builder.box((0.022, 0.03, 0.007), (side * 0.08, 0.058, 0.2115), COLOUR)
        builder.box((0.022, 0.007, 0.03), (side * 0.08, 0.07, 0.2), COLOUR)


def _shelf_bracket_pair(builder):
    """Two L brackets standing side by side, each with a diagonal brace."""
    for side in (-1, 1):
        x = side * 0.04
        builder.box((0.022, 0.012, 0.12), (x, 0.05, 0.06), COLOUR)
        builder.box((0.022, 0.11, 0.012), (x, 0.001, 0.114), COLOUR)
        print_shapes.strut(builder, (x, 0.046, 0.018), (x, -0.04, 0.108), 0.014)


def _floating_shelf_support_pair(builder):
    """Two wall plates, each with a pair of long rods that slide into the back of a shelf."""
    for side in (-1, 1):
        x = side * 0.05
        builder.box((0.035, 0.01, 0.11), (x, 0.06, 0.055), COLOUR)
        for z in (0.03, 0.08):
            print_shapes.limb(builder, (x, 0.058, z), (x, -0.07, z), 0.009, 0.007)


def _over_door_hook_x2(builder):
    """Two over-door hooks: a top that sits over the door, a long strap down the front and an upturned hook."""
    for side in (-1, 1):
        x = side * 0.035
        builder.box((0.03, 0.007, 0.16), (x, 0.0, 0.08), COLOUR)
        builder.box((0.03, 0.05, 0.007), (x, 0.022, 0.1565), COLOUR)
        builder.box((0.03, 0.007, 0.035), (x, 0.044, 0.142), COLOUR)
        builder.box((0.03, 0.04, 0.007), (x, -0.02, 0.0035), COLOUR)
        builder.box((0.03, 0.007, 0.035), (x, -0.037, 0.0175), COLOUR)


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
    "under_shelf_basket": _under_shelf_basket,
    "adhesive_wall_hooks_x4": _adhesive_wall_hooks_x4,
    "shoe_rack_spacer_clips_x8": _shoe_rack_spacer_clips_x8,
    "wardrobe_hanger_hooks_x4": _wardrobe_hanger_hooks_x4,
    "plastic_bag_dispenser": _plastic_bag_dispenser,
    "cupboard_door_caddy": _cupboard_door_caddy,
    "shelf_bracket_pair": _shelf_bracket_pair,
    "floating_shelf_support_pair": _floating_shelf_support_pair,
    "over_door_hook_x2": _over_door_hook_x2,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
