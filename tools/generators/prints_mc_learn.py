"""Printed item generator for multicolour designs: cosplay and props, education and STEM, back to school.

Same rules as prints_multicolour.py: a mesh per colour, built through `Parts`.
"""

import math
import sys
from pathlib import Path

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


def _arc(centre, radius, start, end, steps):
    """Points along an arc, angles in degrees, `steps` points including both ends."""
    return [
        (centre[0] + radius * math.cos(math.radians(start + (end - start) * index / (steps - 1))),
         centre[1] + radius * math.sin(math.radians(start + (end - start) * index / (steps - 1))))
        for index in range(steps)
    ]


def _cog(builder, centre, radius, teeth, thickness, phase=0.0):
    """Flat gear wheel as one plate: a zigzag rim of pointed teeth."""
    points = []
    for index in range(teeth * 2):
        angle = phase + math.tau * index / (teeth * 2)
        reach = radius if index % 2 == 0 else radius * 0.8
        points.append((reach * math.cos(angle), reach * math.sin(angle)))
    builder.plate(points, thickness, COLOUR, centre=centre)


# Cosplay and props


def _sci_fi_blaster_prop(parts):
    """Chunky ray gun lying on its side: body, barrel, grip and stock, with the muzzle, scope and side panel in the second colour."""
    z = 0.017
    parts.main.box((0.15, 0.06, 0.034), (-0.04, 0.012, z), COLOUR, bevel=0.005)
    parts.main.cylinder(0.013, 0.11, (0.085, 0.02, z), COLOUR, segments=6, axis="X")
    parts.main.box((0.04, 0.09, 0.028), (-0.08, -0.05, 0.014), COLOUR, rotation=(0, 0, -0.3))
    parts.main.box((0.05, 0.045, 0.03), (-0.135, 0.008, 0.015), COLOUR, taper=0.85)
    trim = parts.colour(2)
    trim.cylinder(0.017, 0.03, (0.145, 0.02, z), COLOUR, segments=6, axis="X")
    trim.cylinder(0.011, 0.09, (-0.04, 0.052, z), COLOUR, segments=6, axis="X")
    trim.cylinder(0.018, 0.005, (-0.075, 0.01, 0.036), COLOUR, segments=6)
    trim.box((0.065, 0.014, 0.005), (-0.005, 0.01, 0.036), COLOUR)


def _fantasy_sword_prop(parts):
    """Short broad sword lying flat: ridged blade and grip, with the crossguard, grip bands and pommel in the second colour."""
    parts.main.plate([(-0.05, -0.021), (0.115, -0.021), (0.165, 0), (0.115, 0.021), (-0.05, 0.021)], 0.01, COLOUR)
    parts.main.plate([(-0.05, -0.007), (0.11, -0.007), (0.135, 0), (0.11, 0.007), (-0.05, 0.007)], 0.016, COLOUR)
    parts.main.cylinder(0.01, 0.08, (-0.1, 0, 0.01), COLOUR, segments=6, axis="X")
    trim = parts.colour(2)
    trim.box((0.022, 0.12, 0.02), (-0.06, 0, 0.01), COLOUR, bevel=0.004)
    for x in (-0.088, -0.112):
        trim.cylinder(0.013, 0.012, (x, 0, 0.013), COLOUR, segments=6, axis="X")
    trim.cylinder(0.017, 0.02, (-0.145, 0, 0.017), COLOUR, segments=6, axis="X")


def _wizard_staff_topper(parts):
    """Staff head lying flat: a socket and a crescent moon, with a collar and a faceted orb in the second colour."""
    parts.main.cylinder(0.024, 0.1, (-0.08, 0, 0.024), COLOUR, segments=8, axis="X")
    moon = _arc((0.05, 0), 0.08, 40, 320, 7) + _arc((0.062, 0), 0.06, 320, 40, 7)
    parts.main.plate(moon, 0.03, COLOUR)
    orb = parts.colour(2)
    orb.cylinder(0.031, 0.02, (-0.04, 0, 0.031), COLOUR, segments=8, axis="X")
    orb.ball(0.04, (0.058, 0, 0.034), COLOUR, subdivisions=2, scale=(1, 1, 0.85))


def _magic_wand(parts):
    """Tapering wand lying flat, with a pommel, two handle bands and a tip in the second colour."""
    # Six sided bars lie on a flat, so the widest one sits its inner radius above the bed.
    z = 0.014 * math.cos(math.pi / 6)
    parts.main.cylinder(0.011, 0.06, (-0.065, 0, z), COLOUR, segments=6, axis="X")
    parts.main.cylinder(0.009, 0.115, (0.0225, 0, z), COLOUR, segments=6, axis="X", radius_top=0.005)
    trim = parts.colour(2)
    trim.cylinder(0.014, 0.014, (-0.098, 0, z), COLOUR, segments=6, axis="X")
    for x in (-0.072, -0.038):
        trim.cylinder(0.014, 0.009, (x, 0, z), COLOUR, segments=6, axis="X")
    trim.cylinder(0.007, 0.016, (0.084, 0, z), COLOUR, segments=6, axis="X", radius_top=0.003)


def _shield_emblem(parts):
    """Heater shield lying flat, with a cross, a top band and a round boss raised in the second colour."""
    outline = [(-0.1, 0.12), (-0.1, -0.01), (-0.06, -0.085), (0, -0.125), (0.06, -0.085), (0.1, -0.01), (0.1, 0.12)]
    parts.main.plate(outline, 0.014, COLOUR)
    emblem = parts.colour(2)
    emblem.box((0.03, 0.2, 0.004), (0, -0.005, 0.016), COLOUR)
    emblem.box((0.17, 0.03, 0.004), (0, 0.04, 0.016), COLOUR)
    emblem.box((0.2, 0.016, 0.004), (0, 0.112, 0.016), COLOUR)
    emblem.cylinder(0.032, 0.012, (0, 0.04, 0.02), COLOUR, segments=8, radius_top=0.024)


def _prop_grenades_x3(parts):
    """Three stubby barrel shaped grenades standing in a row, each with a cap and lever in the second colour."""
    for x in (-0.072, 0, 0.072):
        parts.main.cylinder(0.022, 0.025, (x, 0, 0.0125), COLOUR, segments=6, radius_top=0.031)
        parts.main.cylinder(0.031, 0.04, (x, 0, 0.045), COLOUR, segments=6, radius_top=0.019)
        parts.colour(2).cylinder(0.013, 0.018, (x, 0, 0.073), COLOUR, segments=5)
        print_shapes.strut(parts.colour(2), (x, -0.004, 0.084), (x, -0.036, 0.04), 0.01)


def _prop_dagger(parts):
    """Leaf bladed dagger lying flat with a pommel, and the guard and grip in the second colour."""
    parts.main.plate([(-0.03, -0.022), (0.06, -0.019), (0.125, 0), (0.06, 0.019), (-0.03, 0.022)], 0.01, COLOUR)
    parts.main.plate([(-0.03, -0.007), (0.06, -0.006), (0.1, 0), (0.06, 0.006), (-0.03, 0.007)], 0.015, COLOUR)
    parts.main.cylinder(0.016, 0.016, (-0.11, 0, 0.016), COLOUR, segments=6, axis="X")
    hilt = parts.colour(2)
    hilt.box((0.018, 0.085, 0.018), (-0.038, 0, 0.009), COLOUR)
    for side in (-1, 1):
        hilt.box((0.03, 0.014, 0.018), (-0.03, side * 0.046, 0.009), COLOUR, rotation=(0, 0, side * 0.6))
    hilt.cylinder(0.011, 0.06, (-0.075, 0, 0.011), COLOUR, segments=6, axis="X")


def _steampunk_goggles(parts):
    """Goggles lying lenses up: two round eye cups, a bridge and strap lugs, with a thick rim round each lens in the second colour."""
    parts.main.box((0.03, 0.022, 0.016), (0, 0, 0.02), COLOUR)
    for side in (-1, 1):
        x = side * 0.056
        parts.main.cylinder(0.045, 0.036, (x, 0, 0.018), COLOUR, segments=8)
        parts.main.cylinder(0.033, 0.004, (x, 0, 0.048), COLOUR, segments=6)
        parts.main.box((0.03, 0.032, 0.012), (side * 0.108, 0, 0.015), COLOUR)
        parts.colour(2).cylinder(0.05, 0.012, (x, 0, 0.041), COLOUR, segments=8)


def _infinity_style_gauntlet(parts):
    """Armoured glove lying palm down: cuff, hand, fingers and thumb, with gems on the knuckles and back of the hand and trim in a third colour."""
    parts.main.cylinder(0.05, 0.12, (-0.09, 0, 0.054), COLOUR, segments=8, axis="X", radius_top=0.04)
    parts.main.box((0.09, 0.105, 0.05), (0.005, 0, 0.025), COLOUR)
    for index, length in enumerate((0.075, 0.09, 0.085, 0.065)):
        y = (index - 1.5) * 0.026
        parts.main.box((length, 0.022, 0.028), (0.048 + length / 2, y, 0.014), COLOUR)
        parts.colour(2).box((0.016, 0.016, 0.008), (0.04, y, 0.053), COLOUR, rotation=(0, 0, math.pi / 4))
    parts.main.box((0.065, 0.024, 0.028), (0.03, -0.07, 0.014), COLOUR, rotation=(0, 0, -0.5))
    parts.colour(2).cylinder(0.024, 0.012, (-0.005, 0, 0.06), COLOUR, segments=6, radius_top=0.014)
    trim = parts.colour(3)
    trim.cylinder(0.054, 0.02, (-0.14, 0, 0.054), COLOUR, segments=8, axis="X")
    trim.cylinder(0.046, 0.016, (-0.045, 0, 0.05), COLOUR, segments=8, axis="X")
    trim.box((0.05, 0.07, 0.005), (-0.005, 0, 0.052), COLOUR)


def _replica_lightsaber_hilt(parts):
    """Energy sword hilt lying flat: a tube with a flared emitter and a pommel, with three grip rings and a switch in the second colour."""
    z = 0.028
    parts.main.cylinder(0.02, 0.2, (0, 0, z), COLOUR, segments=8, axis="X")
    parts.main.cylinder(0.02, 0.04, (0.115, 0, z), COLOUR, segments=8, axis="X", radius_top=0.028)
    parts.main.cylinder(0.026, 0.025, (-0.11, 0, z), COLOUR, segments=8, axis="X")
    trim = parts.colour(2)
    for x in (-0.07, -0.04, -0.01):
        trim.cylinder(0.025, 0.018, (x, 0, z), COLOUR, segments=8, axis="X")
    trim.box((0.035, 0.016, 0.01), (0.05, 0, z + 0.02), COLOUR)


# Education and STEM


def _planet_model_set(parts):
    """Long base with five faceted balls on pegs: a sun, then four planets in two more colours, one with a ring."""
    parts.main.box((0.27, 0.06, 0.012), (0, 0, 0.006), COLOUR, taper=0.94)
    planets = ((-0.095, 0.032, 2), (-0.035, 0.014, 3), (0.005, 0.019, 4), (0.06, 0.024, 3), (0.115, 0.016, 4))
    for x, radius, colour in planets:
        z = 0.024 + radius
        parts.main.cylinder(0.005, z - 0.012, (x, 0, 0.012 + (z - 0.012) / 2), COLOUR, segments=4)
        parts.colour(colour).ball(radius, (x, 0, z), COLOUR, subdivisions=1)
    parts.colour(2).cylinder(0.04, 0.004, (0.06, 0, 0.048), COLOUR, segments=8, rotation=(0.4, 0, 0))


def _dna_helix_model(parts):
    """Upright double helix on a round base: one strand in the base colour, one in a second, joined by rungs in two more colours."""
    parts.main.cylinder(0.06, 0.014, (0, 0, 0.007), COLOUR, segments=6)
    steps = 8

    def point(index, side):
        angle = math.tau * 1.2 * index / steps + (math.pi if side else 0.0)
        return (0.045 * math.cos(angle), 0.045 * math.sin(angle), 0.022 + 0.24 * index / steps)

    for index in range(steps):
        print_shapes.limb(parts.main, point(index, 0), point(index + 1, 0), 0.011, segments=3)
        print_shapes.limb(parts.colour(2), point(index, 1), point(index + 1, 1), 0.011, segments=3)
    for index in range(1, steps):
        print_shapes.limb(parts.colour(3 + index % 2), point(index, 0), point(index, 1), 0.007, segments=3)


def _heart_anatomy_model(parts):
    """Upright heart on a small stand: a rounded body narrowing to a point, with a bent artery and two shorter vessels on top in the second colour."""
    parts.main.cylinder(0.045, 0.01, (0, 0, 0.005), COLOUR, segments=6)
    parts.main.box((0.014, 0.014, 0.03), (0.012, 0, 0.024), COLOUR)
    parts.main.ball(0.064, (0, 0, 0.125), COLOUR, subdivisions=2, scale=(1.05, 0.82, 1.0))
    parts.main.cylinder(0.012, 0.085, (0.01, 0, 0.074), COLOUR, segments=6, radius_top=0.056, rotation=(0, -0.18, 0))
    vessels = parts.colour(2)
    print_shapes.limb(vessels, (0.0, 0.005, 0.165), (0.0, 0.005, 0.24), 0.023)
    print_shapes.limb(vessels, (0.012, 0.005, 0.228), (-0.062, 0.005, 0.205), 0.019)
    print_shapes.limb(vessels, (0.03, -0.028, 0.155), (0.058, -0.02, 0.21), 0.018)
    print_shapes.limb(vessels, (-0.045, -0.01, 0.15), (-0.06, -0.012, 0.185), 0.014)


def _geometry_solids_set(parts):
    """Six solids in two rows: cube and cylinder, sphere and pyramid, cone and hexagonal prism, a pair in each colour."""
    spots = print_shapes.grid(3, 2, 0.075, 0.075)
    (x, y) = spots[0]
    parts.main.box((0.05, 0.05, 0.05), (x, y, 0.025), COLOUR)
    (x, y) = spots[1]
    parts.colour(2).ball(0.029, (x, y, 0.029), COLOUR, subdivisions=2)
    (x, y) = spots[2]
    parts.colour(3).cylinder(0.029, 0.062, (x, y, 0.031), COLOUR, segments=8, radius_top=0.001)
    (x, y) = spots[3]
    parts.colour(2).cylinder(0.038, 0.052, (x, y, 0.026), COLOUR, segments=4, radius_top=0.001, rotation=(0, 0, math.pi / 4))
    (x, y) = spots[4]
    parts.colour(3).cylinder(0.029, 0.046, (x, y, 0.023), COLOUR, segments=6)
    (x, y) = spots[5]
    parts.main.cylinder(0.026, 0.058, (x, y, 0.029), COLOUR, segments=8)


def _tactile_map(parts):
    """Shallow framed tray with a row of raised dots, holding an island, a hill and a peak stepped up in the second colour."""
    parts.main.tray((0.25, 0.19, 0.014), 0.01, COLOUR, floor=0.008)
    for x in (0.045, 0.065, 0.085, 0.105):
        parts.main.cylinder(0.008, 0.007, (x, -0.072, 0.0115), COLOUR, segments=4)
    land = parts.colour(2)
    coast = [
        (-0.1, -0.02), (-0.06, -0.055), (-0.01, -0.04), (0.03, -0.055), (0.07, -0.02),
        (0.06, 0.04), (0.02, 0.075), (-0.05, 0.065), (-0.095, 0.03)]
    land.plate(coast, 0.008, COLOUR, centre=(0, 0, 0.008))
    land.plate([(-0.06, -0.01), (-0.02, -0.025), (0.03, -0.01), (0.03, 0.035), (-0.03, 0.045)], 0.008, COLOUR, centre=(0, 0, 0.016))
    land.cylinder(0.022, 0.016, (-0.01, 0.01, 0.032), COLOUR, segments=5, radius_top=0.004)
    land.plate([(0.085, 0.045), (0.108, 0.05), (0.103, 0.076), (0.08, 0.07)], 0.008, COLOUR, centre=(0, 0, 0.008))


def _gear_demonstration_board(parts):
    """Flat board with three meshing gear wheels on hubs: the large and small ones in a second colour, the middle one in a third."""
    parts.main.box((0.27, 0.17, 0.012), (0, 0, 0.006), COLOUR)
    gears = (((-0.062, -0.005), 0.062, 10, 2, 0.0), ((0.04, 0.02), 0.046, 8, 3, 0.2), ((0.096, -0.036), 0.034, 6, 2, 0.0))
    for (x, y), radius, teeth, colour, phase in gears:
        _cog(parts.colour(colour), (x, y, 0.012), radius, teeth, 0.01, phase)
        parts.main.cylinder(0.012, 0.008, (x, y, 0.025), COLOUR, segments=4)


def _volcano_model(parts):
    """Faceted cone on a round base in a third colour, with a crater plug and three lava flows down the sides in the second."""
    parts.colour(3).cylinder(0.125, 0.012, (0, 0, 0.006), COLOUR, segments=8)
    parts.main.cylinder(0.105, 0.12, (0, 0, 0.072), COLOUR, segments=8, radius_top=0.035)
    lava = parts.colour(2)
    lava.cylinder(0.03, 0.01, (0, 0, 0.135), COLOUR, segments=8)
    for degrees, low in ((-67.5, 0.045), (-157.5, 0.075), (22.5, 0.06)):
        angle = math.radians(degrees)
        reach = (0.105 - 0.07 * (low - 0.012) / 0.12) * 0.924 + 0.002
        top = (0.03 * math.cos(angle), 0.03 * math.sin(angle), 0.134)
        print_shapes.strut(lava, top, (reach * math.cos(angle), reach * math.sin(angle), low), 0.02)


def _globe_stand_and_sphere(parts):
    """Faceted globe held in a half ring on a round foot; the stand and two raised continents are in the second colour."""
    centre_z, ring = 0.152, 0.13
    parts.main.ball(0.115, (0, 0, centre_z), COLOUR, subdivisions=2)
    stand = parts.colour(2)
    stand.cylinder(0.11, 0.014, (0, 0, 0.007), COLOUR, segments=8, radius_top=0.095)
    stand.cylinder(0.014, 0.016, (0, 0, 0.02), COLOUR, segments=6)
    points = [
        (ring * math.cos(math.radians(angle)), 0, centre_z + ring * math.sin(math.radians(angle)))
        for angle in (-100, -64, -28, 8, 44, 80)]
    for start, end in zip(points, points[1:]):
        print_shapes.strut(stand, start, end, 0.014)
    for direction in ((-0.45, -0.75, 0.5), (0.5, -0.45, -0.2)):
        length = math.sqrt(sum(part * part for part in direction))
        spot = tuple(part / length * 0.092 for part in direction)
        stand.ball(0.042, (spot[0], spot[1], centre_z + spot[2]), COLOUR, subdivisions=1)


def _abacus(parts):
    """Upright frame with three rods, each carrying four beads in a colour of its own."""
    parts.main.box((0.21, 0.05, 0.012), (0, 0, 0.006), COLOUR)
    parts.main.box((0.21, 0.03, 0.012), (0, 0, 0.148), COLOUR)
    for side in (-1, 1):
        parts.main.box((0.014, 0.03, 0.132), (side * 0.098, 0, 0.077), COLOUR)
    layouts = ((0, 1, 2, 7), (0, 1, 6, 7), (0, 5, 6, 7))
    for row, places in enumerate(layouts):
        z = 0.043 + row * 0.037
        parts.main.cylinder(0.004, 0.19, (0, 0, z), COLOUR, segments=3, axis="X")
        for place in places:
            x = (place - 3.5) * 0.022
            parts.colour(row + 2).cylinder(0.017, 0.018, (x, 0, z), COLOUR, segments=4, axis="X")


def _times_table_spinner(parts):
    """Round dial with a hub and pointer, with a turning wheel and eight number tiles round the rim in the second colour."""
    parts.main.cylinder(0.075, 0.008, (0, 0, 0.004), COLOUR, segments=10)
    parts.main.cylinder(0.013, 0.01, (0, 0, 0.018), COLOUR, segments=6)
    parts.main.box((0.012, 0.03, 0.004), (0, -0.026, 0.0155), COLOUR)
    dial = parts.colour(2)
    dial.cylinder(0.043, 0.006, (0, 0, 0.011), COLOUR, segments=8)
    for index in range(8):
        angle = math.tau * index / 8
        dial.box((0.016, 0.022, 0.004), (0.06 * math.cos(angle), 0.06 * math.sin(angle), 0.01), COLOUR, rotation=(0, 0, angle))


# Back to school


def _pencil_case(parts):
    """Long open box with a divider and a name plate, and a sliding lid with a thumb ridge, half open, in the second colour."""
    parts.main.tray((0.2, 0.085, 0.045), 0.006, COLOUR, centre=(0.025, 0, 0))
    parts.main.box((0.005, 0.078, 0.038), (0.085, 0, 0.019), COLOUR)
    parts.main.box((0.07, 0.03, 0.003), (-0.03, 0, 0.0535), COLOUR)
    lid = parts.colour(2)
    lid.box((0.2, 0.085, 0.007), (-0.025, 0, 0.0485), COLOUR)
    lid.box((0.008, 0.055, 0.006), (-0.108, 0, 0.054), COLOUR)


def _ruler_with_name(parts):
    """Flat ruler with nine tick marks along the back edge and five letter blocks raised in the second colour."""
    parts.main.box((0.2, 0.044, 0.005), (0, 0, 0.0025), COLOUR)
    marks = parts.colour(2)
    for index in range(9):
        length = 0.016 if index % 2 == 0 else 0.01
        marks.box((0.004, length, 0.002), ((index - 4) * 0.021, 0.021 - length / 2, 0.006), COLOUR)
    for index, width in enumerate((0.014, 0.01, 0.015, 0.011, 0.014)):
        marks.box((width, 0.014, 0.002), ((index - 2) * 0.019 - 0.02, -0.009, 0.006), COLOUR)


def _bag_tag_custom(parts):
    """Luggage tag with clipped corners, with an eyelet, four letter blocks and an underline raised in the second colour."""
    outline = [(-0.058, -0.03), (0.04, -0.03), (0.06, -0.012), (0.06, 0.012), (0.04, 0.03), (-0.058, 0.03)]
    parts.main.plate(outline, 0.006, COLOUR)
    trim = parts.colour(2)
    trim.shell(0.013, 0.009, 0.005, COLOUR, segments=6, centre=(0.04, 0, 0), open_base=True)
    for index, width in enumerate((0.013, 0.01, 0.014, 0.011)):
        trim.box((width, 0.022, 0.002), (-0.042 + index * 0.018, 0.004, 0.007), COLOUR)
    trim.box((0.068, 0.005, 0.002), (-0.015, -0.017, 0.007), COLOUR)


def _desk_caddy_kids(parts):
    """Base with a three part tray at the front, a tall hexagonal pen pot in a second colour and a square pot in a third behind."""
    parts.main.box((0.22, 0.145, 0.01), (0, 0, 0.005), COLOUR, bevel=0.003)
    print_shapes.divided_tray(parts.main, (0.2, 0.06, 0.045), 0.006, across=2, centre=(0, -0.036, 0.008))
    parts.colour(2).shell(0.042, 0.11, 0.006, COLOUR, segments=6, centre=(-0.05, 0.032, 0.008))
    parts.colour(3).shell(0.05, 0.08, 0.006, COLOUR, segments=4, centre=(0.052, 0.032, 0.008), turn=math.pi / 4)


def _bookmark_set_x5(parts):
    """Five flat strips side by side, each with a different shape on top and a band near the foot in the second colour."""
    trim = parts.colour(2)
    for index, (x, _) in enumerate(print_shapes.grid(5, 1, 0.027, 0)):
        parts.main.box((0.021, 0.12, 0.003), (x, 0, 0.0015), COLOUR)
        trim.box((0.021, 0.01, 0.002), (x, -0.04, 0.004), COLOUR)
        if index == 1:
            trim.box((0.013, 0.013, 0.003), (x, 0.044, 0.0045), COLOUR, rotation=(0, 0, math.pi / 4))
        else:
            trim.cylinder(0.0095, 0.003, (x, 0.044, 0.0045), COLOUR, segments=(6, 0, 5, 3, 8)[index], rotation=(0, 0, math.pi / 2))


def _pencil_toppers_x10(parts):
    """Ten square sleeves in two rows, topped alternately with a pyramid in the second colour and a cube in the third."""
    for index, (x, y) in enumerate(print_shapes.grid(5, 2, 0.027, 0.032)):
        parts.main.cylinder(0.012, 0.028, (x, y, 0.014), COLOUR, segments=4)
        if index % 2 == 0:
            parts.colour(2).cylinder(0.015, 0.022, (x, y, 0.039), COLOUR, segments=4, radius_top=0.001)
        else:
            parts.colour(3).box((0.02, 0.02, 0.016), (x, y, 0.036), COLOUR)


VARIANTS = {
    "sci_fi_blaster_prop": _sci_fi_blaster_prop,
    "fantasy_sword_prop": _fantasy_sword_prop,
    "wizard_staff_topper": _wizard_staff_topper,
    "magic_wand": _magic_wand,
    "shield_emblem": _shield_emblem,
    "prop_grenades_x3": _prop_grenades_x3,
    "prop_dagger": _prop_dagger,
    "steampunk_goggles": _steampunk_goggles,
    "infinity_style_gauntlet": _infinity_style_gauntlet,
    "replica_lightsaber_hilt": _replica_lightsaber_hilt,
    "planet_model_set": _planet_model_set,
    "dna_helix_model": _dna_helix_model,
    "heart_anatomy_model": _heart_anatomy_model,
    "geometry_solids_set": _geometry_solids_set,
    "tactile_map": _tactile_map,
    "gear_demonstration_board": _gear_demonstration_board,
    "volcano_model": _volcano_model,
    "globe_stand_and_sphere": _globe_stand_and_sphere,
    "abacus": _abacus,
    "times_table_spinner": _times_table_spinner,
    "pencil_case": _pencil_case,
    "ruler_with_name": _ruler_with_name,
    "bag_tag_custom": _bag_tag_custom,
    "desk_caddy_kids": _desk_caddy_kids,
    "bookmark_set_x5": _bookmark_set_x5,
    "pencil_toppers_x10": _pencil_toppers_x10,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
