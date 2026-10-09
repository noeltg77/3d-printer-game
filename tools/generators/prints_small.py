"""Printed item generator for the categories with only a few Garage products each:
Bathroom, Garden and outdoor, Toys and fidgets, Cosplay and props, Jewellery and
fashion, Automotive and bike, Party and events, Personalised and custom,
Accessibility aids, Replacement parts, and Industrial and B2B batch.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_small.py -- \
    --variant hair_tie_holder --out assets/models/prints/hair_tie_holder.glb
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


# Bathroom

def _cotton_bud_dispenser(builder):
    """Tall open hopper with a small catch tray sticking out at the front."""
    builder.tray((0.1, 0.08, 0.15), 0.007, COLOUR, centre=(0, 0.02, 0), chamfer=0.004)
    builder.tray((0.1, 0.05, 0.03), 0.007, COLOUR, centre=(0, -0.042, 0), chamfer=0.003)


def _toothpaste_squeezer(builder):
    """Slotted bar the tube slides through, with a round turn key at one end."""
    for side in (-1, 1):
        builder.box((0.09, 0.008, 0.022), (0, side * 0.011, 0.011), COLOUR)
        builder.box((0.008, 0.03, 0.022), (side * 0.045, 0, 0.011), COLOUR)
    builder.cylinder(0.022, 0.01, (0.058, 0, 0.022), COLOUR, segments=8, axis="X")


def _nail_polish_rack(builder):
    """Three narrow steps for bottles, closed in by a cheek at each end."""
    print_shapes.stepped_rack(builder, 0.24, 3, 0.05, 0.03, 0.04, lip=0.014)
    for side in (-1, 1):
        builder.box((0.01, 0.154, 0.13), (side * 0.125, 0, 0.065), COLOUR, taper=(1.0, 0.75))


def _hair_tie_holder(builder):
    """Round base with a tall post to loop hair ties over and a wider cap on top."""
    builder.cylinder(0.048, 0.014, (0, 0, 0.007), COLOUR, segments=10, radius_top=0.042)
    builder.cylinder(0.015, 0.14, (0, 0, 0.082), COLOUR, segments=8)
    builder.cylinder(0.022, 0.014, (0, 0, 0.157), COLOUR, segments=8, radius_top=0.016)


# Garden and outdoor

def _hanging_planter(builder):
    """Flared round pot with three arms rising from the rim to a hanging ring."""
    builder.shell(0.05, 0.09, 0.008, COLOUR, segments=8, radius_top=0.075, chamfer=0.004)
    for index in range(3):
        angle = math.pi / 2 + math.tau * index / 3
        rim = (0.068 * math.cos(angle), 0.068 * math.sin(angle), 0.086)
        print_shapes.strut(builder, rim, (0, 0, 0.215), 0.008)
    builder.cylinder(0.014, 0.012, (0, 0, 0.218), COLOUR, segments=6)


# Toys and fidgets

def _train_track_pieces_x10(builder):
    """Ten wooden-style track pieces in two rows, each a plank with a joining tab at one end."""
    for x, y in print_shapes.grid(5, 2, 0.054, 0.118):
        builder.box((0.046, 0.094, 0.01), (x, y - 0.006, 0.005), COLOUR)
        builder.box((0.016, 0.016, 0.01), (x, y + 0.047, 0.005), COLOUR)


def _dino_skeleton_kit(builder):
    """Assembled dinosaur skeleton facing left: spine, ribs, skull and jaw, tail and four legs."""
    builder.box((0.13, 0.012, 0.012), (0.0, 0, 0.1), COLOUR)
    print_shapes.strut(builder, (-0.06, 0, 0.1), (-0.095, 0, 0.14), 0.011)
    builder.box((0.05, 0.026, 0.024), (-0.115, 0, 0.15), COLOUR, taper=(0.6, 0.8))
    builder.box((0.04, 0.02, 0.008), (-0.118, 0, 0.13), COLOUR, rotation=(0, math.radians(-12), 0))
    print_shapes.strut(builder, (0.06, 0, 0.1), (0.14, 0, 0.05), 0.009)
    for x in (-0.04, -0.015, 0.01, 0.035):
        builder.box((0.008, 0.05, 0.04), (x, 0, 0.078), COLOUR, taper=(1.0, 0.5))
    for x, y in print_shapes.grid(2, 2, 0.09, 0.04):
        print_shapes.strut(builder, (x + 0.012, y, 0.001), (x, y * 0.4, 0.098), 0.01)


# Cosplay and props

def _mask_half_face(builder):
    """Upright eye mask curving round the face: brow band, cheek band and nose, with gaps for the eyes."""
    angle = math.radians(40)
    panels = [(0.0, 0.0, 0.0)] + [
        (side * (0.035 + 0.035 * math.cos(angle)), 0.035 * math.sin(angle), side * angle) for side in (-1, 1)]
    for x, y, turn in panels:
        builder.box((0.074, 0.012, 0.045), (x, y, 0.1075), COLOUR, rotation=(0, 0, turn))
        builder.box((0.074, 0.012, 0.045), (x, y, 0.0225), COLOUR, rotation=(0, 0, turn))
    for side in (-1, 1):
        edge = (side * (0.035 + 0.064 * math.cos(angle)), 0.064 * math.sin(angle))
        builder.box((0.014, 0.012, 0.05), (edge[0], edge[1], 0.065), COLOUR, rotation=(0, 0, side * angle))
    builder.box((0.024, 0.024, 0.06), (0, -0.008, 0.062), COLOUR, taper=(0.5, 0.6))


def _plague_doctor_mask(builder):
    """Rounded head piece with a long drooping beak and two round goggle rims."""
    builder.ball(0.07, (0, 0.07, 0.063), COLOUR, scale=(0.95, 1.0, 0.9))
    print_shapes.limb(builder, (0, 0.03, 0.066), (0, -0.13, 0.036), 0.042, 0.007)
    for side in (-1, 1):
        builder.cylinder(0.02, 0.014, (side * 0.03, 0.012, 0.098), COLOUR, segments=6, rotation=(math.radians(70), 0, side * 0.35))


def _horns_pair(builder):
    """Two horns on round pads, each curving up and out to a point."""
    for side in (-1, 1):
        x = side * 0.05
        builder.cylinder(0.04, 0.01, (x, 0, 0.005), COLOUR, segments=8)
        points = [(x, 0, 0.012), (x + side * 0.012, 0.01, 0.065), (x + side * 0.045, 0.03, 0.115), (x + side * 0.09, 0.04, 0.145)]
        radii = [0.03, 0.023, 0.014, 0.003]
        for index in range(3):
            print_shapes.limb(builder, points[index], points[index + 1], radii[index], radii[index + 1])


def _potion_bottle_stoppers_x6(builder):
    """Six tapered stoppers in two rows, each topped with a faceted gem."""
    for x, y in print_shapes.grid(3, 2, 0.06, 0.06):
        builder.cylinder(0.014, 0.03, (x, y, 0.015), COLOUR, segments=6, radius_top=0.02)
        builder.ball(0.019, (x, y, 0.044), COLOUR, subdivisions=1)


# Jewellery and fashion

def _hair_comb(builder):
    """Flat comb: a spine with a row of long teeth."""
    builder.box((0.15, 0.028, 0.007), (0, 0.035, 0.0035), COLOUR)
    for x, _ in print_shapes.grid(8, 1, 0.019, 0):
        builder.box((0.008, 0.07, 0.007), (x, -0.012, 0.0035), COLOUR)


def _jewellery_stand_tree(builder):
    """Tree on a round base: a tapering trunk with six branches reaching up and out."""
    builder.cylinder(0.065, 0.014, (0, 0, 0.007), COLOUR, segments=10, radius_top=0.058)
    print_shapes.limb(builder, (0, 0, 0.012), (0, 0, 0.21), 0.014, 0.006)
    for index in range(6):
        angle = math.radians(20 + index * 125)
        height = 0.07 + index * 0.022
        reach = 0.085 - index * 0.007
        print_shapes.strut(
            builder, (0, 0, height), (reach * math.cos(angle), reach * math.sin(angle), height + 0.045), 0.009)


def _earring_display_card_stand(builder):
    """Small upright easel that holds a card of earrings."""
    print_shapes.easel(builder, 0.1, 0.085, 0.11, lean=12.0, lip=0.012, base=0.01, panel=0.008)


def _button_set_x10(builder):
    """Ten flat buttons in two rows."""
    for x, y in print_shapes.grid(5, 2, 0.032, 0.032):
        builder.cylinder(0.013, 0.006, (x, y, 0.003), COLOUR, segments=6)


# Automotive and bike

def _tyre_tread_depth_gauge(builder):
    """Flat gauge body with a sliding probe that pokes out of one end and a thumb tab."""
    builder.box((0.045, 0.12, 0.01), (0, 0.01, 0.005), COLOUR, bevel=0.003)
    builder.box((0.014, 0.16, 0.006), (0, -0.01, 0.012), COLOUR)
    builder.box((0.026, 0.02, 0.01), (0, 0.03, 0.019), COLOUR)


# Party and events

def _table_number_stands_x10(builder):
    """Ten little table stands in two rows, each a foot with an upright number card."""
    for x, y in print_shapes.grid(5, 2, 0.044, 0.05):
        builder.box((0.034, 0.024, 0.008), (x, y, 0.004), COLOUR)
        builder.box((0.03, 0.005, 0.042), (x, y + 0.004, 0.027), COLOUR)


def _balloon_weights_x4(builder):
    """Four chunky five-sided weights, each with a knob on top to tie the ribbon to."""
    for x, y in print_shapes.grid(2, 2, 0.07, 0.07):
        builder.cylinder(0.03, 0.036, (x, y, 0.018), COLOUR, segments=5, radius_top=0.012)
        builder.ball(0.012, (x, y, 0.043), COLOUR, subdivisions=1)


def _birthday_number_topper(builder):
    """Flat number five on two stakes, as it comes off the bed."""
    for y in (0.095, 0.045, -0.005):
        builder.box((0.085, 0.02, 0.006), (0, y, 0.003), COLOUR)
    builder.box((0.02, 0.05, 0.006), (-0.0325, 0.07, 0.003), COLOUR)
    builder.box((0.02, 0.05, 0.006), (0.0325, 0.02, 0.003), COLOUR)
    for x in (-0.025, 0.025):
        builder.box((0.008, 0.085, 0.006), (x, -0.055, 0.003), COLOUR)


# Personalised and custom

def _custom_cookie_cutter_logo(builder):
    """Five-sided cutter with a wide grip flange round the base and a small logo outline inside."""
    builder.shell(0.06, 0.028, 0.004, COLOUR, segments=5, turn=math.pi / 2, open_base=True)
    builder.shell(0.07, 0.005, 0.012, COLOUR, segments=5, turn=math.pi / 2, open_base=True)
    builder.shell(0.024, 0.02, 0.004, COLOUR, segments=4, open_base=True)


def _initial_letter_shelf_decor(builder):
    """Chunky free-standing letter A: two leaning legs, a crossbar and a flat top."""
    lean = math.radians(17)
    for side in (-1, 1):
        builder.box(
            (0.036, 0.045, 0.2), (side * 0.035, 0, 0.1), COLOUR,
            rotation=(0, -side * lean, 0), bevel=0.004)
    builder.box((0.08, 0.04, 0.03), (0, 0, 0.075), COLOUR)
    builder.box((0.05, 0.045, 0.02), (0, 0, 0.189), COLOUR)


# Accessibility aids

def _card_holder_for_games(builder):
    """Long rack with three rising rows, so a hand of cards can stand without being held."""
    print_shapes.slot_rack(builder, 0.3, 0.075, (0.02, 0.032, 0.044), lean=14.0, base=0.01, panel=0.008)


def _tablet_stylus_holder(builder):
    """Short tube for the stylus on a clip plate with a lip."""
    builder.box((0.04, 0.05, 0.006), (0, 0, 0.003), COLOUR)
    builder.box((0.04, 0.006, 0.016), (0, -0.022, 0.008), COLOUR)
    builder.shell(0.014, 0.055, 0.004, COLOUR, segments=6, centre=(0, 0.01, 0.004))


# Replacement parts

def _cabinet_hinge_cover_x4(builder):
    """Four small rounded caps in two rows."""
    for x, y in print_shapes.grid(2, 2, 0.055, 0.04):
        builder.box((0.045, 0.028, 0.014), (x, y, 0.007), COLOUR, bevel=0.004)


def _toy_battery_cover(builder):
    """Flat cover plate with grip ribs, two hinge tabs at the back and a latch at the front."""
    builder.box((0.07, 0.085, 0.006), (0, 0, 0.003), COLOUR, bevel=0.002)
    for y in (-0.012, 0.0, 0.012):
        builder.box((0.04, 0.005, 0.003), (0, y, 0.0065), COLOUR)
    for x in (-0.02, 0.02):
        builder.box((0.012, 0.01, 0.004), (x, 0.047, 0.002), COLOUR)
    builder.box((0.02, 0.01, 0.012), (0, -0.044, 0.006), COLOUR)


def _remote_battery_door(builder):
    """Long narrow door with an arrow, two tabs at one end and a latch at the other."""
    builder.box((0.05, 0.12, 0.006), (0, 0, 0.003), COLOUR, bevel=0.002)
    builder.cylinder(0.014, 0.003, (0, -0.02, 0.0065), COLOUR, segments=3, rotation=(0, 0, -math.pi / 2))
    for x in (-0.014, 0.014):
        builder.box((0.01, 0.01, 0.004), (x, 0.064, 0.002), COLOUR)
    builder.box((0.018, 0.008, 0.012), (0, -0.062, 0.006), COLOUR)


# Industrial and B2B batch

def _restaurant_menu_holders_x20(builder):
    """Twenty small wedge-shaped table holders in four rows."""
    for x, y in print_shapes.grid(5, 4, 0.05, 0.04):
        builder.box((0.04, 0.028, 0.02), (x, y, 0.01), COLOUR, taper=(1.0, 0.25))


def _museum_replica_artefact(builder):
    """Two-handled vase on a square plinth: foot, swelling body, shoulder, neck and lip."""
    builder.box((0.1, 0.1, 0.02), (0, 0, 0.01), COLOUR)
    builder.cylinder(0.03, 0.02, (0, 0, 0.03), COLOUR, segments=8, radius_top=0.022)
    builder.cylinder(0.025, 0.05, (0, 0, 0.065), COLOUR, segments=8, radius_top=0.055)
    builder.cylinder(0.055, 0.06, (0, 0, 0.12), COLOUR, segments=8, radius_top=0.03)
    builder.cylinder(0.022, 0.04, (0, 0, 0.17), COLOUR, segments=8)
    builder.cylinder(0.024, 0.012, (0, 0, 0.196), COLOUR, segments=8, radius_top=0.034)
    for side in (-1, 1):
        print_shapes.strut(builder, (side * 0.024, 0, 0.185), (side * 0.062, 0, 0.165), 0.009)
        print_shapes.strut(builder, (side * 0.062, 0, 0.165), (side * 0.05, 0, 0.125), 0.009)


VARIANTS = {
    "cotton_bud_dispenser": _cotton_bud_dispenser,
    "toothpaste_squeezer": _toothpaste_squeezer,
    "nail_polish_rack": _nail_polish_rack,
    "hair_tie_holder": _hair_tie_holder,
    "hanging_planter": _hanging_planter,
    "train_track_pieces_x10": _train_track_pieces_x10,
    "dino_skeleton_kit": _dino_skeleton_kit,
    "mask_half_face": _mask_half_face,
    "plague_doctor_mask": _plague_doctor_mask,
    "horns_pair": _horns_pair,
    "potion_bottle_stoppers_x6": _potion_bottle_stoppers_x6,
    "hair_comb": _hair_comb,
    "jewellery_stand_tree": _jewellery_stand_tree,
    "earring_display_card_stand": _earring_display_card_stand,
    "button_set_x10": _button_set_x10,
    "tyre_tread_depth_gauge": _tyre_tread_depth_gauge,
    "table_number_stands_x10": _table_number_stands_x10,
    "balloon_weights_x4": _balloon_weights_x4,
    "birthday_number_topper": _birthday_number_topper,
    "custom_cookie_cutter_logo": _custom_cookie_cutter_logo,
    "initial_letter_shelf_decor": _initial_letter_shelf_decor,
    "card_holder_for_games": _card_holder_for_games,
    "tablet_stylus_holder": _tablet_stylus_holder,
    "cabinet_hinge_cover_x4": _cabinet_hinge_cover_x4,
    "toy_battery_cover": _toy_battery_cover,
    "remote_battery_door": _remote_battery_door,
    "restaurant_menu_holders_x20": _restaurant_menu_holders_x20,
    "museum_replica_artefact": _museum_replica_artefact,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
