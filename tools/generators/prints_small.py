"""Printed item generator for the categories with only a few Garage products each:
Bathroom, Garden and outdoor, Toys and fidgets, Cosplay and props, Jewellery and
fashion, Automotive and bike, Party and events, Personalised and custom,
Accessibility aids, Replacement parts, Industrial and B2B batch, Glow in the dark, and Wall art and signs.

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


# Cosplay and props, Spare room tier

def _armour_gauntlet(builder):
    """Gauntlet standing on its cuff: a flared cuff, a forearm tube, a hand plate and four finger plates."""
    builder.cylinder(0.068, 0.045, (0, 0, 0.0225), COLOUR, segments=8, radius_top=0.05)
    builder.cylinder(0.05, 0.13, (0, 0, 0.11), COLOUR, segments=8, radius_top=0.042)
    builder.box((0.085, 0.05, 0.055), (0, 0, 0.2), COLOUR, taper=(0.9, 0.9))
    for x, _ in print_shapes.grid(4, 1, 0.021, 0):
        builder.box((0.018, 0.03, 0.05), (x, -0.004, 0.25), COLOUR, taper=(0.8, 0.6))
    for z in (0.085, 0.13):
        builder.cylinder(0.052, 0.008, (0, 0, z), COLOUR, segments=8)


def _shoulder_pauldron_pair(builder):
    """Two domed shoulder plates, each stepped in three overlapping bands."""
    for side in (-1, 1):
        x = side * 0.075
        builder.cylinder(0.07, 0.03, (x, 0, 0.015), COLOUR, segments=8, radius_top=0.062)
        builder.cylinder(0.056, 0.03, (x, 0, 0.045), COLOUR, segments=8, radius_top=0.042)
        builder.cylinder(0.038, 0.022, (x, 0, 0.071), COLOUR, segments=8, radius_top=0.014)


def _crown(builder):
    """Round band with five tall points standing up from it."""
    builder.shell(0.07, 0.035, 0.006, COLOUR, segments=10, open_base=True)
    for index in range(5):
        angle = math.pi / 2 + math.tau * index / 5
        builder.box((0.03, 0.006, 0.05), (0.064 * math.cos(angle), 0.064 * math.sin(angle), 0.058), COLOUR,
                    rotation=(0, 0, angle + math.pi / 2), taper=(0.1, 1.0))


def _tiara(builder):
    """Half band standing on edge, curving round the front, with three peaks, the middle one tallest."""
    for index in range(6):
        angle = math.pi + (index + 0.5) * math.pi / 6
        builder.box((0.036, 0.006, 0.014), (0.065 * math.cos(angle), 0.03 + 0.065 * math.sin(angle), 0.007), COLOUR,
                    rotation=(0, 0, angle + math.pi / 2))
    for index, height in ((2, 0.03), (3, 0.03), (2.5, 0.05)):
        angle = math.pi + (index + 0.5) * math.pi / 6
        builder.box((0.028, 0.006, height), (0.065 * math.cos(angle), 0.03 + 0.065 * math.sin(angle), 0.012 + height / 2), COLOUR,
                    rotation=(0, 0, angle + math.pi / 2), taper=(0.1, 1.0))
    builder.enlarge(1.2)


def _elf_ears_flexible(builder):
    """Pair of flat pointed ear tips, mirror images, each with a ridge inside the curve."""
    for side in (-1, 1):
        ear = [(side * x, y) for x, y in ((0.0, -0.04), (0.03, -0.03), (0.036, 0.0), (0.016, 0.06), (0.004, 0.02))]
        if side < 0:
            ear.reverse()
        builder.plate(ear, 0.008, COLOUR, centre=(side * 0.012, 0, 0))
        builder.box((0.006, 0.05, 0.006), (side * 0.03, 0.0, 0.01), COLOUR, rotation=(0, 0, side * 0.25))


def _prop_coins_x20(builder):
    """Twenty prop coins: three stacks of five, with the last five loose in front."""
    for x in (-0.035, 0.0, 0.035):
        builder.cylinder(0.016, 0.02, (x, 0.02, 0.01), COLOUR, segments=8)
    for x, _ in print_shapes.grid(5, 1, 0.034, 0):
        builder.cylinder(0.016, 0.004, (x, -0.022, 0.002), COLOUR, segments=8)


def _cyberpunk_visor(builder):
    """Wrap-round visor band standing on edge: a flat front, angled sides, an arm each end and a nose notch."""
    angle = math.radians(40)
    builder.box((0.09, 0.008, 0.04), (0, -0.03, 0.03), COLOUR)
    for side in (-1, 1):
        builder.box((0.06, 0.008, 0.04), (side * (0.045 + 0.03 * math.cos(angle)), -0.03 + 0.03 * math.sin(angle), 0.03), COLOUR,
                    rotation=(0, 0, side * angle))
        builder.box((0.008, 0.08, 0.014), (side * 0.091, 0.048, 0.036), COLOUR)
    builder.box((0.022, 0.014, 0.014), (0, -0.03, 0.007), COLOUR, taper=(0.5, 1.0))


def _prop_book_cover_corners_x4(builder):
    """Four corner plates for a prop book, each with a raised stud."""
    corner = [(-0.022, -0.022), (0.022, -0.022), (0.022, -0.006), (-0.006, 0.022), (-0.022, 0.022)]
    for x, y in print_shapes.grid(2, 2, 0.055, 0.055):
        builder.plate(corner, 0.005, COLOUR, centre=(x, y, 0))
        builder.cylinder(0.006, 0.006, (x - 0.008, y - 0.008, 0.006), COLOUR, segments=6)
    builder.enlarge(1.2)


def _movie_prop_badge(builder):
    """Seven-pointed star on a shield, with a round boss in the middle."""
    builder.plate([(-0.04, 0.045), (-0.04, -0.01), (0.0, -0.05), (0.04, -0.01), (0.04, 0.045), (0.0, 0.035)], 0.005, COLOUR)
    star = [((0.034 if index % 2 == 0 else 0.017) * math.cos(math.pi / 2 + math.pi * index / 7),
             (0.034 if index % 2 == 0 else 0.017) * math.sin(math.pi / 2 + math.pi * index / 7)) for index in range(14)]
    builder.plate(star, 0.005, COLOUR, centre=(0, 0.002, 0.004))
    builder.cylinder(0.012, 0.005, (0, 0.002, 0.011), COLOUR, segments=8)
    builder.enlarge(1.3)


# Spare room tier: Jewellery and fashion, Glow in the dark, Bathroom, Accessibility aids, Toys and fidgets

def _star(points, outer, inner):
    return [((outer if index % 2 == 0 else inner) * math.cos(math.pi / 2 + math.pi * index / points),
             (outer if index % 2 == 0 else inner) * math.sin(math.pi / 2 + math.pi * index / points)) for index in range(points * 2)]


def _ngon(sides, radius, turn=0.0):
    return [(radius * math.cos(turn + math.tau * index / sides), radius * math.sin(turn + math.tau * index / sides)) for index in range(sides)]


def _statement_earrings(builder):
    """Pair of flat teardrop earrings, each with a hook loop at the top."""
    drop = [(0, -0.03), (0.016, -0.014), (0.012, 0.012), (0, 0.026), (-0.012, 0.012), (-0.016, -0.014)]
    for side in (-1, 1):
        builder.plate(drop, 0.004, COLOUR, centre=(side * 0.022, 0, 0))
        builder.shell(0.006, 0.004, 0.0025, COLOUR, segments=6, centre=(side * 0.022, 0.03, 0), open_base=True)
    builder.enlarge(1.6)


def _geometric_pendant(builder):
    """Six-sided frame with a solid triangle set inside it and a bail for the chain."""
    builder.outline(_ngon(6, 0.03, math.pi / 6), 0.005, 0.005, COLOUR)
    builder.plate(_ngon(3, 0.02, -math.pi / 2), 0.005, COLOUR)
    builder.shell(0.007, 0.005, 0.003, COLOUR, segments=6, centre=(0, 0.035, 0), open_base=True)
    builder.enlarge(1.6)


def _bangle(builder):
    """Plain round bangle lying flat."""
    builder.shell(0.045, 0.018, 0.007, COLOUR, segments=12, open_base=True)


def _brooch(builder):
    """Six-pointed flower with a domed centre."""
    builder.plate(_star(6, 0.03, 0.016), 0.005, COLOUR)
    builder.ball(0.012, (0, 0, 0.007), COLOUR, subdivisions=1, scale=(1.0, 1.0, 0.6))
    builder.enlarge(1.5)


def _belt_buckle(builder):
    """Rectangular frame buckle with a centre bar and a prong lying across it."""
    builder.outline([(-0.04, -0.028), (0.04, -0.028), (0.04, 0.028), (-0.04, 0.028)], 0.008, 0.008, COLOUR)
    builder.box((0.008, 0.05, 0.008), (-0.01, 0, 0.004), COLOUR)
    builder.box((0.052, 0.006, 0.006), (0.016, 0, 0.011), COLOUR)


def _watch_strap_flexible(builder):
    """Two strap halves lying side by side: one ending in a buckle frame, the other ridged where the holes go."""
    builder.box((0.022, 0.1, 0.004), (-0.02, -0.01, 0.002), COLOUR)
    builder.outline([(-0.036, 0.04), (-0.004, 0.04), (-0.004, 0.062), (-0.036, 0.062)], 0.006, 0.005, COLOUR)
    builder.box((0.022, 0.13, 0.004), (0.02, 0, 0.002), COLOUR)
    for index in range(5):
        builder.box((0.012, 0.005, 0.003), (0.02, -0.05 + index * 0.014, 0.0055), COLOUR)


def _sunglasses_frame(builder):
    """Glasses front lying flat, two six-sided rims joined by a bridge, with the arms laid out behind."""
    for side in (-1, 1):
        rim = [(side * 0.034 + x * 1.15, -0.03 + y * 0.85) for x, y in _ngon(6, 0.026)]
        builder.outline(rim, 0.006, 0.005, COLOUR)
        builder.box((0.008, 0.11, 0.005), (side * 0.045, 0.045, 0.0025), COLOUR)
    builder.box((0.014, 0.006, 0.006), (0, -0.025, 0.003), COLOUR)


def _ring_dish(builder):
    """Shallow dish with a cone standing in the middle to slip rings over."""
    builder.shell(0.04, 0.02, 0.006, COLOUR, segments=8, radius_top=0.058)
    builder.cylinder(0.014, 0.055, (0, 0, 0.032), COLOUR, segments=6, radius_top=0.003)


def _glow_stars_x30(builder):
    """A scatter of four-pointed ceiling stars in three sizes. Ten are modelled to stand for the thirty."""
    sizes = (0.02, 0.014, 0.017, 0.012, 0.02, 0.013, 0.016, 0.02, 0.012, 0.016)
    for (x, y), size in zip(print_shapes.grid(5, 2, 0.044, 0.046), sizes):
        builder.plate(_star(4, size, size * 0.4), 0.004, COLOUR, centre=(x, y, 0))


def _glow_light_switch_surround(builder):
    """Square frame that goes round a light switch, with a stepped inner edge."""
    builder.outline([(-0.065, -0.065), (0.065, -0.065), (0.065, 0.065), (-0.065, 0.065)], 0.005, 0.02, COLOUR)
    builder.outline([(-0.05, -0.05), (0.05, -0.05), (0.05, 0.05), (-0.05, 0.05)], 0.009, 0.006, COLOUR)


def _glow_moon(builder):
    """Crescent moon standing on a round base."""
    builder.cylinder(0.05, 0.014, (0, 0, 0.007), COLOUR, segments=8, radius_top=0.042)
    outer = [(0.07 * math.cos(math.radians(a)), 0.085 + 0.07 * math.sin(math.radians(a))) for a in (50, 90, 130, 170, 210, 250, 290, 310)]
    inner = [(0.03 + 0.055 * math.cos(math.radians(a)), 0.085 + 0.055 * math.sin(math.radians(a))) for a in (250, 215, 180, 145, 110)]
    builder.plate(outer + inner, 0.02, COLOUR, upright=True)


def _glow_skeleton_keychain(builder):
    """Tiny flat skeleton with a ring above the skull."""
    builder.cylinder(0.011, 0.005, (0, 0.03, 0.0025), COLOUR, segments=6)
    builder.box((0.02, 0.022, 0.005), (0, 0.008, 0.0025), COLOUR)
    builder.box((0.014, 0.008, 0.005), (0, -0.01, 0.0025), COLOUR)
    for side in (-1, 1):
        builder.box((0.004, 0.026, 0.005), (side * 0.016, 0.004, 0.0025), COLOUR, rotation=(0, 0, side * 0.3))
        builder.box((0.005, 0.03, 0.005), (side * 0.007, -0.03, 0.0025), COLOUR)
    builder.shell(0.007, 0.005, 0.003, COLOUR, segments=6, centre=(0, 0.046, 0), open_base=True)
    builder.enlarge(1.8)


def _glow_path_markers_x6(builder):
    """Six low domed studs in two rows."""
    for x, y in print_shapes.grid(3, 2, 0.05, 0.05):
        builder.cylinder(0.02, 0.01, (x, y, 0.005), COLOUR, segments=6, radius_top=0.016)
        builder.cylinder(0.016, 0.006, (x, y, 0.013), COLOUR, segments=6, radius_top=0.007)


def _glow_night_light(builder):
    """Mushroom-shaped night light: a base, a stem and a wide domed cap."""
    builder.cylinder(0.05, 0.016, (0, 0, 0.008), COLOUR, segments=10, radius_top=0.042)
    builder.cylinder(0.022, 0.06, (0, 0, 0.046), COLOUR, segments=8, radius_top=0.018)
    builder.ball(0.065, (0, 0, 0.09), COLOUR, scale=(1.0, 1.0, 0.6))


def _glow_dice_set(builder):
    """Five dice of different shapes: a cube, a four-sided, an eight-sided, a ten-sided and a twenty-sided."""
    builder.box((0.022, 0.022, 0.022), (-0.06, 0, 0.011), COLOUR)
    builder.cylinder(0.018, 0.026, (-0.028, 0.004, 0.013), COLOUR, segments=3, radius_top=0.0005)
    for x, sides in ((0.004, 4), (0.036, 5)):
        for z, low, high in ((0.009, 0.0005, 0.016), (0.027, 0.016, 0.0005)):
            builder.cylinder(low, 0.018, (x, 0, z), COLOUR, segments=sides, radius_top=high)
    builder.ball(0.016, (0.07, 0, 0.016), COLOUR, subdivisions=1)
    builder.enlarge(1.3)


def _glow_fishing_floats_x4(builder):
    """Four slim fishing floats lying side by side, each with a stem at both ends."""
    for x, _ in print_shapes.grid(4, 1, 0.022, 0):
        builder.ball(0.008, (x, 0, 0.008), COLOUR, subdivisions=1, scale=(1.0, 2.6, 1.0))
        builder.box((0.003, 0.07, 0.003), (x, 0, 0.008), COLOUR)
    builder.enlarge(1.5)


def _toothbrush_holder(builder):
    """Round cup with a cross piece across the top that keeps four brushes apart."""
    builder.shell(0.04, 0.1, 0.006, COLOUR, segments=8, radius_top=0.044)
    builder.box((0.08, 0.007, 0.01), (0, 0, 0.095), COLOUR)
    builder.box((0.007, 0.08, 0.01), (0, 0, 0.095), COLOUR)


def _razor_stand(builder):
    """Round base with an arm that rises, leans forward and ends in a fork to hang a razor from."""
    builder.cylinder(0.04, 0.012, (0, 0, 0.006), COLOUR, segments=10, radius_top=0.034)
    print_shapes.limb(builder, (0, 0.012, 0.01), (0, 0.012, 0.1), 0.008)
    print_shapes.limb(builder, (0, 0.012, 0.098), (0, -0.02, 0.12), 0.008, 0.006)
    for side in (-1, 1):
        builder.box((0.006, 0.02, 0.006), (side * 0.009, -0.028, 0.12), COLOUR)
    builder.box((0.024, 0.006, 0.006), (0, -0.02, 0.12), COLOUR)


def _soap_dish_draining(builder):
    """Shallow dish with ridges to keep the soap out of the water and a spout at the front to drain it."""
    builder.tray((0.13, 0.09, 0.022), 0.006, COLOUR, chamfer=0.003)
    for x, _ in print_shapes.grid(5, 1, 0.022, 0):
        builder.box((0.006, 0.07, 0.008), (x, 0, 0.01), COLOUR)
    builder.box((0.03, 0.016, 0.01), (0, -0.05, 0.011), COLOUR)


def _toilet_roll_holder(builder):
    """Wall plate with an arm reaching out and turning up at the end to keep the roll on."""
    builder.box((0.07, 0.012, 0.09), (0, 0.065, 0.045), COLOUR, bevel=0.004)
    builder.box((0.02, 0.14, 0.02), (0, -0.005, 0.05), COLOUR)
    builder.box((0.02, 0.02, 0.035), (0, -0.065, 0.0775), COLOUR)


def _hair_dryer_wall_mount(builder):
    """Wall plate with a ring the dryer's nozzle drops through and a hook underneath for the cable."""
    builder.box((0.1, 0.012, 0.14), (0, 0.075, 0.07), COLOUR, bevel=0.004)
    builder.shell(0.052, 0.02, 0.008, COLOUR, segments=10, centre=(0, 0.018, 0.09), open_base=True)
    builder.box((0.014, 0.05, 0.012), (0, 0.045, 0.02), COLOUR)
    builder.box((0.014, 0.012, 0.03), (0, 0.022, 0.029), COLOUR)


def _shower_caddy_hook_x2(builder):
    """Two flat S hooks: one end over the rail, the other for the caddy."""
    hook = [(-0.006, 0.0), (-0.006, -0.04), (0.004, -0.052), (0.026, -0.052), (0.026, -0.03), (0.016, -0.03), (0.016, -0.042),
            (0.006, -0.042), (0.006, 0.03), (-0.004, 0.042), (-0.026, 0.042), (-0.026, 0.02), (-0.016, 0.02), (-0.016, 0.032), (-0.006, 0.032)]
    for side in (-1, 1):
        builder.plate(hook, 0.008, COLOUR, centre=(side * 0.035, 0.005, 0))


def _bath_plug_chain_clip(builder):
    """Small ring for the chain joined to a flat clip that grips the plug."""
    builder.shell(0.009, 0.005, 0.003, COLOUR, segments=6, centre=(0, 0.016, 0), open_base=True)
    builder.plate([(-0.008, 0.008), (-0.012, -0.024), (-0.004, -0.024), (0.0, -0.008), (0.004, -0.024), (0.012, -0.024), (0.008, 0.008)], 0.005, COLOUR)
    builder.enlarge(2.2)


def _cutlery_grip_x3(builder):
    """Three fat soft sleeves standing on end, to push cutlery handles into."""
    for x, _ in print_shapes.grid(3, 1, 0.05, 0):
        builder.shell(0.02, 0.09, 0.008, COLOUR, segments=8, centre=(x, 0, 0), open_base=True)


def _pen_grip_x5(builder):
    """Five little three-sided sleeves standing in a row."""
    for x, _ in print_shapes.grid(5, 1, 0.024, 0):
        builder.shell(0.01, 0.03, 0.004, COLOUR, segments=3, centre=(x, 0, 0), turn=math.pi / 2, open_base=True)
    builder.enlarge(1.6)


def _key_turner_aid(builder):
    """Wide, chunky handle with a clamp at one end that holds a key."""
    builder.box((0.035, 0.12, 0.02), (0, -0.02, 0.01), COLOUR, bevel=0.006)
    builder.box((0.02, 0.03, 0.012), (0, 0.052, 0.006), COLOUR)
    builder.cylinder(0.006, 0.006, (0, 0.05, 0.015), COLOUR, segments=6)
    builder.box((0.006, 0.03, 0.004), (0, 0.08, 0.004), COLOUR)


def _tap_turner(builder):
    """Long lever with a four-pronged head that fits over a cross-head tap."""
    builder.box((0.03, 0.16, 0.018), (0, -0.04, 0.009), COLOUR, bevel=0.005)
    builder.box((0.07, 0.07, 0.01), (0, 0.065, 0.005), COLOUR)
    for x, y in print_shapes.grid(2, 2, 0.05, 0.05):
        builder.box((0.02, 0.02, 0.03), (x, 0.065 + y, 0.025), COLOUR)


def _button_hook_and_zip_puller(builder):
    """Fat handle with a wire loop at one end for buttons and a hook at the other for zips."""
    builder.box((0.028, 0.1, 0.02), (0, 0, 0.01), COLOUR, bevel=0.006)
    builder.outline([(0.0, 0.05), (0.012, 0.085), (0.0, 0.12), (-0.012, 0.085)], 0.005, 0.003, COLOUR, centre=(0, 0, 0.008))
    builder.box((0.006, 0.04, 0.006), (0, -0.068, 0.01), COLOUR)
    builder.box((0.016, 0.006, 0.006), (0.005, -0.088, 0.01), COLOUR)


def _bottle_and_jar_opener(builder):
    """Flat lever with a toothed V jaw for jar lids and a ring at the end of the handle for bottle caps."""
    builder.plate([(-0.02, -0.07), (0.02, -0.07), (0.025, 0.0), (0.055, 0.07), (0.035, 0.07), (0.0, 0.02), (-0.035, 0.07), (-0.055, 0.07), (-0.025, 0.0)], 0.008, COLOUR)
    for side in (-1, 1):
        for along in (0.3, 0.7):
            builder.box((0.008, 0.008, 0.006), (side * (0.01 + along * 0.033), 0.03 + along * 0.045, 0.011), COLOUR)
    builder.shell(0.022, 0.008, 0.007, COLOUR, segments=8, centre=(0, -0.09, 0), open_base=True)


def _door_handle_extension(builder):
    """Ring that clamps over a door handle, with a long lever reaching out from it."""
    print_shapes.hoop(builder, 0.024, 0.01, 0.04, (0.06, 0, 0.031))
    builder.box((0.16, 0.04, 0.018), (-0.04, 0, 0.029), COLOUR, bevel=0.005)
    builder.box((0.03, 0.04, 0.03), (-0.11, 0, 0.015), COLOUR)


def _articulated_dragon(builder):
    """Jointed dragon lying in an S: a chain of tapering segments with a spine ridge, a horned head, a tail spike and four legs."""
    count = 9
    for index in range(count):
        along = index / (count - 1)
        x = (along - 0.5) * 0.2
        y = math.sin(along * math.tau * 0.8) * 0.03
        size = 0.04 - abs(along - 0.35) * 0.03
        builder.box((0.022, size, size * 0.9), (x, y, size * 0.45), COLOUR, taper=(1.0, 0.7))
        if index % 2 == 0:
            builder.box((0.01, 0.006, size * 0.4), (x, y, size * 1.05), COLOUR, taper=(0.2, 1.0))
        if index in (2, 5):
            for side in (-1, 1):
                builder.box((0.012, 0.016, 0.012), (x, y + side * (size / 2 + 0.006), 0.006), COLOUR)
    builder.box((0.04, 0.036, 0.03), (-0.125, 0.0, 0.015), COLOUR, taper=(0.8, 0.8))
    builder.box((0.028, 0.024, 0.016), (-0.155, 0.0, 0.01), COLOUR)
    for side in (-1, 1):
        builder.box((0.008, 0.008, 0.024), (-0.115, side * 0.012, 0.04), COLOUR, taper=0.2)
    builder.box((0.03, 0.01, 0.01), (0.122, -0.028, 0.005), COLOUR, taper=(0.3, 1.0))


def _flexi_fish(builder):
    """Jointed fish lying flat: six body segments that swell and taper, a forked tail and a fin on its back."""
    widths = (0.02, 0.032, 0.036, 0.03, 0.022, 0.014)
    for index, width in enumerate(widths):
        builder.box((0.02, width, 0.016), (-0.055 + index * 0.022, 0, 0.008), COLOUR)
    builder.plate([(0.07, 0.0), (0.1, -0.022), (0.092, 0.0), (0.1, 0.022)], 0.016, COLOUR)
    builder.box((0.03, 0.004, 0.012), (-0.015, 0, 0.02), COLOUR, taper=(0.4, 1.0))


def _spiral_cone_toy(builder):
    """Cone built of five stepped rings, each smaller than the one below, with a knob on top."""
    for index, radius in enumerate((0.045, 0.037, 0.029, 0.021, 0.013)):
        builder.cylinder(radius, 0.018, (0, 0, 0.009 + index * 0.018), COLOUR, segments=8, radius_top=radius * 0.8,
                         rotation=(0, 0, index * 0.25))
    builder.ball(0.01, (0, 0, 0.096), COLOUR, subdivisions=1)


def _toy_boat(builder):
    """Bath boat with a raised gunwale round the deck, a cabin, a funnel and a flag on a mast."""
    hull = [(-0.035, -0.085), (0.035, -0.085), (0.042, 0.03), (0.0, 0.095), (-0.042, 0.03)]
    builder.plate(hull, 0.028, COLOUR)
    builder.outline(hull, 0.01, 0.005, COLOUR, centre=(0, 0, 0.026))
    builder.box((0.045, 0.05, 0.03), (0, -0.03, 0.043), COLOUR)
    builder.cylinder(0.01, 0.03, (0, -0.04, 0.072), COLOUR, segments=6)
    builder.box((0.004, 0.004, 0.06), (0, 0.03, 0.058), COLOUR)
    builder.box((0.004, 0.024, 0.014), (0, 0.042, 0.08), COLOUR)


def _bouncy_squishy_tpu(builder):
    """Soft faceted ball, a little squashed, with a band round its middle."""
    builder.ball(0.045, (0, 0, 0.038), COLOUR, scale=(1.0, 1.0, 0.85))
    builder.cylinder(0.047, 0.008, (0, 0, 0.038), COLOUR, segments=10)


def _spinning_saturn_desk_toy(builder):
    """Ringed planet on a stem and a round base."""
    builder.cylinder(0.04, 0.012, (0, 0, 0.006), COLOUR, segments=8, radius_top=0.032)
    builder.cylinder(0.008, 0.04, (0, 0, 0.03), COLOUR, segments=6)
    builder.ball(0.04, (0, 0, 0.085), COLOUR)
    builder.shell(0.07, 0.005, 0.02, COLOUR, segments=10, centre=(0, 0, 0.083), open_base=True)


# Spare room tier: Industrial and B2B batch, Party and events, Personalised and custom, Wall art and signs

def _retail_display_stand(builder):
    """Counter display: three steps for stock under a tall header board, between two side cheeks."""
    print_shapes.stepped_rack(builder, 0.26, 3, 0.05, 0.03, 0.035, lip=0.012)
    builder.box((0.26, 0.014, 0.24), (0, 0.082, 0.12), COLOUR, bevel=0.004)
    for side in (-1, 1):
        builder.box((0.01, 0.16, 0.12), (side * 0.135, 0.005, 0.06), COLOUR, taper=(1.0, 0.6))


def _price_tag_holders_x50(builder):
    """Rows of little wedge-shaped ticket holders. Twenty are modelled to stand for the fifty."""
    for x, y in print_shapes.grid(5, 4, 0.04, 0.032):
        builder.box((0.032, 0.022, 0.016), (x, y, 0.008), COLOUR, taper=(1.0, 0.25))


def _product_prototype_housing(builder):
    """Two halves of a hand-held casing lying side by side, open faces up, one with four screw posts."""
    half = [(-0.03, -0.07), (0.03, -0.07), (0.04, -0.02), (0.035, 0.07), (-0.035, 0.07), (-0.04, -0.02)]
    for side in (-1, 1):
        builder.plate(half, 0.006, COLOUR, centre=(side * 0.05, 0, 0))
        builder.outline(half, 0.022 if side < 0 else 0.014, 0.005, COLOUR, centre=(side * 0.05, 0, 0))
    for x, y in print_shapes.grid(2, 2, 0.044, 0.09):
        builder.box((0.008, 0.008, 0.018), (-0.05 + x, y, 0.012), COLOUR)


def _architectural_model_block(builder):
    """City block on a base: six buildings of different heights, one with a set-back top."""
    builder.box((0.24, 0.18, 0.01), (0, 0, 0.005), COLOUR, bevel=0.003)
    for x, y, width, depth, height in ((-0.075, 0.045, 0.06, 0.06, 0.13), (0.0, 0.05, 0.05, 0.05, 0.07), (0.075, 0.04, 0.06, 0.07, 0.1),
                                       (-0.07, -0.045, 0.07, 0.06, 0.05), (0.01, -0.045, 0.05, 0.06, 0.16), (0.08, -0.05, 0.05, 0.05, 0.06)):
        builder.box((width, depth, height), (x, y, 0.01 + height / 2), COLOUR)
    builder.box((0.034, 0.04, 0.04), (0.01, -0.045, 0.19), COLOUR)


def _gym_locker_number_tags_x100(builder):
    """Sheet of round-cornered number tags as it comes off the bed. Twenty are modelled to stand for the hundred."""
    builder.box((0.27, 0.19, 0.003), (0, 0, 0.0015), COLOUR)
    for x, y in print_shapes.grid(5, 4, 0.05, 0.044):
        builder.box((0.038, 0.03, 0.005), (x, y, 0.0045), COLOUR)


def _engineering_fixtures_x20(builder):
    """Rows of small L-shaped fixture blocks. Ten are modelled to stand for the twenty."""
    for x, y in print_shapes.grid(5, 2, 0.052, 0.07):
        builder.box((0.04, 0.05, 0.014), (x, y, 0.007), COLOUR)
        builder.box((0.04, 0.014, 0.03), (x, y + 0.018, 0.029), COLOUR)


def _drone_parts_batch(builder):
    """A batch off the bed: one small X frame, four spare arms laid out beside it and four stand-offs."""
    builder.box((0.05, 0.05, 0.008), (-0.06, 0, 0.004), COLOUR)
    for index in range(4):
        angle = math.pi / 4 + index * math.pi / 2
        builder.box((0.07, 0.014, 0.006), (-0.06 + 0.052 * math.cos(angle), 0.052 * math.sin(angle), 0.003), COLOUR, rotation=(0, 0, angle))
    for index in range(4):
        builder.box((0.014, 0.1, 0.006), (0.04 + index * 0.024, 0.02, 0.003), COLOUR)
        builder.box((0.012, 0.012, 0.022), (0.04 + index * 0.024, -0.06, 0.011), COLOUR)


def _wedding_cake_topper(builder):
    """Two simple figures side by side on a round base, in front of an upright heart."""
    builder.cylinder(0.06, 0.008, (0, 0, 0.004), COLOUR, segments=10)
    for side in (-1, 1):
        builder.cylinder(0.02, 0.06, (side * 0.022, -0.008, 0.038), COLOUR, segments=6, radius_top=0.008)
        builder.ball(0.014, (side * 0.022, -0.008, 0.078), COLOUR, subdivisions=1)
    heart = [(x * 1.8, 0.062 + y * 1.8) for x, y in ((0, -0.03), (0.022, -0.008), (0.028, 0.008), (0.02, 0.022), (0.008, 0.024), (0, 0.014),
                                                    (-0.008, 0.024), (-0.02, 0.022), (-0.028, 0.008), (-0.022, -0.008))]
    builder.plate(heart, 0.008, COLOUR, centre=(0, 0.03, 0), upright=True)


def _place_card_holders_x20(builder):
    """Twenty little wedge card holders in four rows of five."""
    for x, y in print_shapes.grid(5, 4, 0.034, 0.03):
        builder.box((0.026, 0.02, 0.014), (x, y, 0.007), COLOUR, taper=(0.9, 0.2))


def _hen_party_crowns_x6(builder):
    """Six small flared crowns in two rows."""
    for x, y in print_shapes.grid(3, 2, 0.07, 0.07):
        builder.shell(0.022, 0.03, 0.004, COLOUR, segments=5, centre=(x, y, 0), radius_top=0.03, turn=math.pi / 2, open_base=True)


def _trophy_custom(builder):
    """Cup trophy: a square plinth with a plaque, a stem, a flared bowl and a handle each side."""
    builder.box((0.09, 0.09, 0.05), (0, 0, 0.025), COLOUR, bevel=0.005)
    builder.box((0.05, 0.006, 0.02), (0, -0.046, 0.025), COLOUR)
    builder.cylinder(0.016, 0.05, (0, 0, 0.075), COLOUR, segments=8, radius_top=0.01)
    builder.shell(0.03, 0.09, 0.006, COLOUR, segments=8, centre=(0, 0, 0.098), radius_top=0.06, chamfer=0.003)
    for side in (-1, 1):
        print_shapes.strut(builder, (side * 0.05, 0, 0.17), (side * 0.085, 0, 0.15), 0.01)
        print_shapes.strut(builder, (side * 0.085, 0, 0.15), (side * 0.036, 0, 0.11), 0.01)


def _medal_custom_x10(builder):
    """Ten round medals in two rows, the back row with ribbon lugs."""
    for x, y in print_shapes.grid(5, 2, 0.05, 0.055):
        builder.cylinder(0.021, 0.005, (x, y, 0.0025), COLOUR, segments=6)
        if y > 0:
            builder.box((0.018, 0.008, 0.005), (x, y + 0.024, 0.0025), COLOUR)


def _custom_stamp(builder):
    """Rubber stamp: a round knob on a neck above a block with the die underneath."""
    builder.box((0.07, 0.045, 0.006), (0, 0, 0.003), COLOUR)
    builder.box((0.08, 0.055, 0.022), (0, 0, 0.017), COLOUR, bevel=0.004)
    builder.cylinder(0.012, 0.03, (0, 0, 0.043), COLOUR, segments=6)
    builder.ball(0.022, (0, 0, 0.07), COLOUR, subdivisions=1)


def _map_pendant_your_town(builder):
    """Round pendant with raised streets crossing it and a loop for the cord."""
    builder.cylinder(0.024, 0.004, (0, 0, 0.002), COLOUR, segments=8)
    for turn, offset in ((0.2, -0.006), (0.2, 0.01), (1.5, 0.0), (2.4, 0.006)):
        builder.box((0.04, 0.003, 0.003), (offset * -math.sin(turn), offset * math.cos(turn), 0.005), COLOUR, rotation=(0, 0, turn))
    builder.shell(0.007, 0.004, 0.003, COLOUR, segments=6, centre=(0, 0.03, 0), open_base=True)
    builder.enlarge(2.0)


def _constellation_wall_art(builder):
    """Flat panel with seven raised stars joined by lines into a constellation."""
    builder.box((0.27, 0.18, 0.005), (0, 0, 0.0025), COLOUR)
    stars = [(-0.1, 0.05), (-0.055, 0.02), (-0.01, 0.03), (0.03, -0.01), (0.03, -0.055), (0.09, -0.06), (0.1, -0.01)]
    for x, y in stars:
        builder.cylinder(0.01, 0.006, (x, y, 0.008), COLOUR, segments=5)
    for (x1, y1), (x2, y2) in list(zip(stars, stars[1:])) + [(stars[6], stars[3])]:
        print_shapes.strut(builder, (x1, y1, 0.0065), (x2, y2, 0.0065), 0.004)


def _mandala_panel(builder):
    """Round panel with two raised rings and six petals between them."""
    builder.cylinder(0.125, 0.005, (0, 0, 0.0025), COLOUR, segments=12)
    builder.shell(0.12, 0.006, 0.008, COLOUR, segments=12, centre=(0, 0, 0.004), open_base=True)
    builder.shell(0.05, 0.006, 0.008, COLOUR, segments=6, centre=(0, 0, 0.004), open_base=True)
    for index in range(6):
        angle = math.tau * index / 6
        builder.box((0.05, 0.02, 0.006), (0.08 * math.cos(angle), 0.08 * math.sin(angle), 0.007), COLOUR, rotation=(0, 0, angle), taper=(0.3, 0.3))


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
    "armour_gauntlet": _armour_gauntlet,
    "shoulder_pauldron_pair": _shoulder_pauldron_pair,
    "crown": _crown,
    "tiara": _tiara,
    "elf_ears_flexible": _elf_ears_flexible,
    "prop_coins_x20": _prop_coins_x20,
    "cyberpunk_visor": _cyberpunk_visor,
    "prop_book_cover_corners_x4": _prop_book_cover_corners_x4,
    "movie_prop_badge": _movie_prop_badge,
    "statement_earrings": _statement_earrings,
    "geometric_pendant": _geometric_pendant,
    "bangle": _bangle,
    "brooch": _brooch,
    "belt_buckle": _belt_buckle,
    "watch_strap_flexible": _watch_strap_flexible,
    "sunglasses_frame": _sunglasses_frame,
    "ring_dish": _ring_dish,
    "glow_stars_x30": _glow_stars_x30,
    "glow_light_switch_surround": _glow_light_switch_surround,
    "glow_moon": _glow_moon,
    "glow_skeleton_keychain": _glow_skeleton_keychain,
    "glow_path_markers_x6": _glow_path_markers_x6,
    "glow_night_light": _glow_night_light,
    "glow_dice_set": _glow_dice_set,
    "glow_fishing_floats_x4": _glow_fishing_floats_x4,
    "toothbrush_holder": _toothbrush_holder,
    "razor_stand": _razor_stand,
    "soap_dish_draining": _soap_dish_draining,
    "toilet_roll_holder": _toilet_roll_holder,
    "hair_dryer_wall_mount": _hair_dryer_wall_mount,
    "shower_caddy_hook_x2": _shower_caddy_hook_x2,
    "bath_plug_chain_clip": _bath_plug_chain_clip,
    "cutlery_grip_x3": _cutlery_grip_x3,
    "pen_grip_x5": _pen_grip_x5,
    "key_turner_aid": _key_turner_aid,
    "tap_turner": _tap_turner,
    "button_hook_and_zip_puller": _button_hook_and_zip_puller,
    "bottle_and_jar_opener": _bottle_and_jar_opener,
    "door_handle_extension": _door_handle_extension,
    "articulated_dragon": _articulated_dragon,
    "flexi_fish": _flexi_fish,
    "spiral_cone_toy": _spiral_cone_toy,
    "toy_boat": _toy_boat,
    "bouncy_squishy_tpu": _bouncy_squishy_tpu,
    "spinning_saturn_desk_toy": _spinning_saturn_desk_toy,
    "retail_display_stand": _retail_display_stand,
    "price_tag_holders_x50": _price_tag_holders_x50,
    "product_prototype_housing": _product_prototype_housing,
    "architectural_model_block": _architectural_model_block,
    "gym_locker_number_tags_x100": _gym_locker_number_tags_x100,
    "engineering_fixtures_x20": _engineering_fixtures_x20,
    "drone_parts_batch": _drone_parts_batch,
    "wedding_cake_topper": _wedding_cake_topper,
    "place_card_holders_x20": _place_card_holders_x20,
    "hen_party_crowns_x6": _hen_party_crowns_x6,
    "trophy_custom": _trophy_custom,
    "medal_custom_x10": _medal_custom_x10,
    "custom_stamp": _custom_stamp,
    "map_pendant_your_town": _map_pendant_your_town,
    "constellation_wall_art": _constellation_wall_art,
    "mandala_panel": _mandala_panel,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
