"""Printed item generator for multicolour designs: party and events, Halloween,
Valentine's Day, Easter and Mother's Day.

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

# Turns an eight sided shell or cylinder so a flat side faces the front.
FLAT_8 = math.pi / 8

HEART = ((0, -0.5), (0.5, 0.08), (0.5, 0.32), (0.32, 0.5), (0.14, 0.5), (0, 0.34),
         (-0.14, 0.5), (-0.32, 0.5), (-0.5, 0.32), (-0.5, 0.08))


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), required=True)


def build(args, rng):
    build_item(args.variant, args.out.stem)


def build_item(variant, name, preview=False):
    return prints_multicolour.build_from(VARIANTS, variant, name, preview)


def _heart(width, height):
    """Outline of a heart, point to the front, for `plate`."""
    return [(x * width, y * height) for x, y in HEART]


def _glyph(builder, kind, x, y, width, height, z, thick=0.003):
    """A raised block letter made of bars: "m", "u", "t", "l", "h" or a plain "block"."""
    stroke = width * 0.3
    side = (width - stroke) / 2
    bars = {
        "block": [(width, height, 0, 0)],
        "m": [(stroke, height, -side, 0), (stroke, height, side, 0), (width, stroke, 0, (height - stroke) / 2)],
        "u": [(stroke, height, -side, 0), (stroke, height, side, 0), (width, stroke, 0, -(height - stroke) / 2)],
        "h": [(stroke, height, -side, 0), (stroke, height, side, 0), (width, stroke, 0, 0)],
        "t": [(width, stroke, 0, (height - stroke) / 2), (stroke, height, 0, 0)],
        "l": [(stroke, height, -side, 0), (width, stroke, 0, -(height - stroke) / 2)],
    }[kind]
    for bar_x, bar_y, off_x, off_y in bars:
        builder.box((bar_x, bar_y, thick), (x + off_x, y + off_y, z + thick / 2), COLOUR)


def _arch(builder, half_width, base_z, rise, thickness, steps=5):
    """Carrying handle: a hoop of straight bars from one side to the other."""
    points = [
        (-half_width * math.cos(math.pi * step / steps), 0, base_z + rise * math.sin(math.pi * step / steps))
        for step in range(steps + 1)
    ]
    for start, end in zip(points, points[1:]):
        print_shapes.strut(builder, start, end, thickness)


def _pumpkin(builder, radius, height, segments=8, turn=0.0, low=0.3, middle=0.36):
    """Squat faceted pumpkin body in three bands, widest round the middle.

    `low` and `middle` are the shares of the height taken by the bottom and middle bands.
    """
    spin = (0, 0, turn)
    top = 1.0 - low - middle
    builder.cylinder(radius * 0.62, height * low, (0, 0, height * low / 2), COLOUR, segments=segments,
                     rotation=spin, radius_top=radius)
    builder.cylinder(radius, height * middle, (0, 0, height * (low + middle / 2)), COLOUR, segments=segments,
                     rotation=spin)
    builder.cylinder(radius, height * top, (0, 0, height * (1.0 - top / 2)), COLOUR, segments=segments,
                     rotation=spin, radius_top=radius * 0.5)


def _party_favour_boxes_x10(parts):
    """Ten small square boxes in two rows, each with a lid in the second colour."""
    for x, y in print_shapes.grid(5, 2, 0.05, 0.06):
        parts.main.box((0.04, 0.04, 0.034), (x, y, 0.017), COLOUR)
        parts.colour(2).box((0.045, 0.045, 0.01), (x, y, 0.038), COLOUR)


def _name_keyrings_x10(parts):
    """Ten oblong keyring tags in two columns, each with a raised name bar of its own length."""
    lengths = (0.044, 0.036, 0.05, 0.04, 0.046)
    for index, (x, y) in enumerate(print_shapes.grid(2, 5, 0.088, 0.032)):
        parts.main.box((0.076, 0.024, 0.006), (x, y, 0.003), COLOUR)
        length = lengths[(index + index // 2) % len(lengths)]
        parts.colour(2).box((length, 0.01, 0.003), (x + 0.008, y, 0.0075), COLOUR)


def _event_lanyard_badges_x50(parts):
    """Five stacks of ten badges, the top of each stack skewed and carrying a name panel."""
    for index in range(5):
        x = (index - 2) * 0.056
        skew = (0, 0, 0.14 if index % 2 == 0 else -0.14)
        parts.main.box((0.046, 0.07, 0.03), (x, 0, 0.015), COLOUR)
        parts.main.box((0.046, 0.07, 0.02), (x, 0, 0.04), COLOUR, rotation=skew)
        parts.colour(2).box((0.034, 0.028, 0.003), (x, -0.008, 0.0515), COLOUR, rotation=skew)


def _gender_reveal_confetti_cannon(parts):
    """Tube lying on its side with a flared mouth, and a twist grip and band in the second colour."""
    radius = 0.036
    parts.main.cylinder(0.028, 0.15, (0, 0, radius), COLOUR, segments=8, axis="X")
    parts.main.cylinder(0.028, 0.03, (0.09, 0, radius), COLOUR, segments=8, axis="X", radius_top=radius)
    trim = parts.colour(2)
    trim.cylinder(radius, 0.06, (-0.105, 0, radius), COLOUR, segments=8, axis="X")
    trim.cylinder(0.032, 0.022, (0.03, 0, radius), COLOUR, segments=8, axis="X")


def _graduation_cap_topper(parts):
    """Mortarboard: a round cap under a square board set cornerwise, with a button, cord and tassel."""
    parts.main.cylinder(0.05, 0.04, (0, 0, 0.02), COLOUR, segments=8, radius_top=0.045)
    parts.main.box((0.125, 0.125, 0.008), (0, 0, 0.044), COLOUR, rotation=(0, 0, math.pi / 4))
    tassel = parts.colour(2)
    tassel.cylinder(0.012, 0.006, (0, 0, 0.051), COLOUR, segments=6)
    tassel.box((0.007, 0.096, 0.003), (0, -0.048, 0.0495), COLOUR)
    tassel.cylinder(0.004, 0.04, (0, -0.093, 0.03), COLOUR, segments=5, radius_top=0.008, rotation=(math.pi, 0, 0))


def _baby_shower_gift_tags_x20(parts):
    """Twenty plain oblong tags in a five by four grid: three columns in one colour, two in the other."""
    for index, (x, y) in enumerate(print_shapes.grid(5, 4, 0.036, 0.048)):
        builder = parts.colour(2) if index % 5 in (1, 3) else parts.main
        builder.box((0.028, 0.04, 0.005), (x, y, 0.0025), COLOUR)


def _bunting_letters_custom(parts):
    """Five pennants lying flat in a row, a raised block letter on each and a cord along the top."""
    letters = parts.colour(2)
    letters.box((0.286, 0.008, 0.004), (0, 0.037, 0.008), COLOUR)
    for index, kind in enumerate("tlhtl"):
        x = (index - 2) * 0.056
        parts.main.plate([(-0.026, 0.04), (0, -0.04), (0.026, 0.04)], 0.006, COLOUR, centre=(x, 0, 0))
        _glyph(letters, kind, x, 0.017, 0.018, 0.022, 0.006)


def _pumpkin_low_poly(parts):
    """Squat faceted pumpkin with a leaning stem and a leaf in the second colour."""
    _pumpkin(parts.main, 0.1, 0.13)
    stalk = parts.colour(2)
    print_shapes.limb(stalk, (0, 0, 0.125), (0.014, 0, 0.17), 0.018, 0.011, segments=5)
    stalk.box((0.05, 0.026, 0.005), (-0.034, -0.012, 0.132), COLOUR, rotation=(0, 0, 0.5))


def _jack_o_lantern_light(parts):
    """Large pumpkin with triangle eyes, a nose and a wide mouth standing proud of the front, and a stem."""
    _pumpkin(parts.main, 0.12, 0.18, segments=10, turn=math.pi / 10, low=0.25, middle=0.47)
    front = -0.12 * math.cos(math.pi / 10)
    face = parts.colour(2)
    for x in (-0.03, 0.03):
        face.cylinder(0.02, 0.016, (x, front, 0.102), COLOUR, segments=3, axis="Y")
    face.cylinder(0.01, 0.016, (0, front, 0.08), COLOUR, segments=3, axis="Y")
    face.box((0.07, 0.016, 0.016), (0, front, 0.058), COLOUR)
    print_shapes.limb(face, (0, 0, 0.175), (0.012, 0, 0.22), 0.02, 0.012, segments=5)


def _pumpkin_tea_light_cover(parts):
    """Hollow pumpkin open at the top, with a face on the front and a tea light and flame inside."""
    parts.main.shell(0.055, 0.045, 0.006, COLOUR, segments=8, radius_top=0.075, turn=FLAT_8)
    parts.main.shell(0.075, 0.035, 0.006, COLOUR, segments=8, centre=(0, 0, 0.045), radius_top=0.052,
                     turn=FLAT_8, open_base=True)
    glow = parts.colour(2)
    glow.cylinder(0.032, 0.02, (0, 0, 0.016), COLOUR, segments=8)
    glow.cylinder(0.011, 0.034, (0, 0, 0.043), COLOUR, segments=5, radius_top=0.002)
    for x in (-0.02, 0.02):
        glow.cylinder(0.011, 0.016, (x, -0.057, 0.06), COLOUR, segments=3, axis="Y")
    glow.box((0.05, 0.012, 0.01), (0, -0.062, 0.03), COLOUR)


def _haunted_house_lantern(parts):
    """House with a steep roof, a chimney and a side tower; lit windows, a door and the tower's spire in the second colour."""
    parts.main.box((0.15, 0.12, 0.12), (-0.035, 0, 0.06), COLOUR)
    parts.main.box((0.17, 0.14, 0.075), (-0.035, 0, 0.1575), COLOUR, taper=(0.85, 0.05))
    parts.main.box((0.022, 0.022, 0.06), (-0.08, 0.02, 0.185), COLOUR)
    parts.main.box((0.07, 0.12, 0.2), (0.08, 0, 0.1), COLOUR)
    lit = parts.colour(2)
    lit.cylinder(0.066, 0.08, (0.08, 0, 0.24), COLOUR, segments=4, radius_top=0.003, rotation=(0, 0, math.pi / 4))
    for x in (-0.085, 0.015):
        lit.box((0.026, 0.006, 0.036), (x, -0.062, 0.078), COLOUR)
    lit.box((0.03, 0.006, 0.055), (-0.035, -0.062, 0.0275), COLOUR)
    lit.box((0.024, 0.006, 0.045), (0.08, -0.062, 0.14), COLOUR)


def _cauldron_sweet_bowl(parts):
    """Pot bellied bowl, open at the top, with a thick rim and two lug handles in the second colour."""
    parts.main.shell(0.075, 0.06, 0.008, COLOUR, segments=8, radius_top=0.115)
    parts.main.shell(0.115, 0.045, 0.008, COLOUR, segments=8, centre=(0, 0, 0.06), radius_top=0.095, open_base=True)
    trim = parts.colour(2)
    trim.shell(0.106, 0.014, 0.016, COLOUR, segments=8, centre=(0, 0, 0.102), open_base=True)
    for x in (-0.12, 0.12):
        trim.box((0.03, 0.03, 0.012), (x, 0, 0.07), COLOUR)


def _coffin_trinket_box(parts):
    """Six sided coffin lying flat, with a lid in the second colour and a raised cross on it."""
    outline = [(-0.115, -0.028), (-0.055, -0.055), (0.115, -0.026), (0.115, 0.026), (-0.055, 0.055), (-0.115, 0.028)]
    parts.main.plate(outline, 0.04, COLOUR)
    parts.colour(2).plate([(x * 1.04, y * 1.06) for x, y in outline], 0.01, COLOUR, centre=(0, 0, 0.04))
    parts.main.box((0.1, 0.012, 0.004), (-0.02, 0, 0.052), COLOUR)
    parts.main.box((0.012, 0.045, 0.004), (-0.048, 0, 0.052), COLOUR)


def _halloween_door_wreath(parts):
    """Flat ring with three small pumpkins round it, and a bat and two diamonds in a third colour."""
    parts.main.shell(0.15, 0.022, 0.045, COLOUR, segments=10, open_base=True)
    for degrees in (90, 215, 325):
        angle = math.radians(degrees)
        x, y = 0.122 * math.cos(angle), 0.122 * math.sin(angle)
        parts.colour(2).cylinder(0.028, 0.02, (x, y, 0.032), COLOUR, segments=6, radius_top=0.018)
    wing = [(0.014, -0.006), (0.03, -0.018), (0.042, -0.005), (0.064, -0.014), (0.054, 0.02), (0.016, 0.01), (0.01, 0.028)]
    bat = [(0, -0.018)] + wing + [(0, 0.014)] + [(-x, y) for x, y in reversed(wing)]
    parts.colour(3).plate(bat, 0.006, COLOUR, centre=(0, -0.122, 0.022))
    for degrees in (30, 150):
        angle = math.radians(degrees)
        x, y = 0.122 * math.cos(angle), 0.122 * math.sin(angle)
        parts.colour(3).box((0.026, 0.026, 0.006), (x, y, 0.025), COLOUR, rotation=(0, 0, math.pi / 4))


def _trick_or_treat_bucket(parts):
    """Flared eight sided bucket with a hoop handle and a pumpkin face on the front in the second colour."""
    parts.main.shell(0.085, 0.13, 0.007, COLOUR, segments=8, radius_top=0.11, turn=FLAT_8)
    face = parts.colour(2)
    _arch(face, 0.1, 0.125, 0.085, 0.01)
    for x in (-0.03, 0.03):
        face.cylinder(0.017, 0.014, (x, -0.093, 0.085), COLOUR, segments=3, axis="Y")
    face.box((0.07, 0.014, 0.012), (0, -0.087, 0.05), COLOUR)


def _heart_box(parts):
    """Heart shaped box with an overhanging lid in the second colour and a small heart knob on top."""
    parts.main.plate(_heart(0.15, 0.14), 0.04, COLOUR)
    parts.colour(2).plate(_heart(0.16, 0.15), 0.012, COLOUR, centre=(0, 0, 0.04))
    parts.main.plate(_heart(0.05, 0.046), 0.008, COLOUR, centre=(0, 0.004, 0.052))


def _love_lock_keyring_pair(parts):
    """Two flat padlocks side by side, each with a square shackle and a raised heart on the body."""
    for x in (-0.03, 0.03):
        parts.main.box((0.046, 0.038, 0.01), (x, -0.012, 0.005), COLOUR)
        for side in (-0.013, 0.013):
            parts.main.box((0.007, 0.024, 0.007), (x + side, 0.017, 0.0035), COLOUR)
        parts.main.box((0.033, 0.007, 0.007), (x, 0.0295, 0.0035), COLOUR)
        parts.colour(2).plate(_heart(0.026, 0.024), 0.003, COLOUR, centre=(x, -0.012, 0.01))


def _couples_name_sign(parts):
    """Long flat plaque with two raised block names and a heart between them."""
    parts.main.box((0.25, 0.07, 0.008), (0, 0, 0.004), COLOUR)
    names = parts.colour(2)
    for side, kinds in ((-1, "tlh"), (1, "ltu")):
        for index, kind in enumerate(kinds):
            _glyph(names, kind, side * 0.07 + (index - 1) * 0.029, 0, 0.021, 0.032, 0.008)
    names.plate(_heart(0.032, 0.03), 0.003, COLOUR, centre=(0, 0, 0.008))


def _heart_puzzle(parts):
    """Heart shaped tray holding four puzzle pieces in alternating colours, with a round tab on each join."""
    width, height = 0.17, 0.16
    parts.main.plate(_heart(width + 0.012, height + 0.012), 0.004, COLOUR)
    top_right = [(0, 0.08), (0.5, 0.08), (0.5, 0.32), (0.32, 0.5), (0.14, 0.5), (0, 0.34)]
    bottom_right = [(0, -0.5), (0.5, 0.08), (0, 0.08)]
    pieces = (
        (parts.main, bottom_right),
        (parts.colour(2), [(-x, y) for x, y in reversed(bottom_right)]),
        (parts.colour(2), top_right),
        (parts.main, [(-x, y) for x, y in reversed(top_right)]),
    )
    for builder, outline in pieces:
        mid_x = sum(x for x, _ in outline) / len(outline)
        mid_y = sum(y for _, y in outline) / len(outline)
        shrunk = [((mid_x + (x - mid_x) * 0.9) * width, (mid_y + (y - mid_y) * 0.9) * height) for x, y in outline]
        builder.plate(shrunk, 0.009, COLOUR, centre=(0, 0, 0.004))
    # Each tab belongs to one piece and reaches over on to its neighbour.
    tabs = ((parts.main, -0.07, -0.16), (parts.colour(2), -0.07, 0.24), (parts.colour(2), 0.2, 0.02), (parts.main, -0.2, 0.02))
    for builder, x, y in tabs:
        builder.cylinder(0.011, 0.011, (x * width, y * height, 0.0095), COLOUR, segments=6)


def _valentine_s_card_stand(parts):
    """Base with a low front lip and a leaning back rest, and an upright heart on the front."""
    tilt = math.radians(12)
    parts.main.box((0.16, 0.075, 0.014), (0, 0, 0.007), COLOUR, bevel=0.003)
    parts.main.box((0.15, 0.01, 0.022), (0, -0.012, 0.024), COLOUR)
    parts.main.box((0.15, 0.01, 0.075), (0, 0.008 + math.sin(tilt) * 0.0375, 0.012 + math.cos(tilt) * 0.0375),
                   COLOUR, rotation=(-tilt, 0, 0))
    heart = parts.colour(2)
    for x in (-0.014, 0.014):
        heart.cylinder(0.016, 0.012, (x, -0.03, 0.05), COLOUR, segments=6, axis="Y")
    heart.box((0.036, 0.012, 0.036), (0, -0.03, 0.032), COLOUR, rotation=(0, math.pi / 4, 0))


def _easter_egg_fillable(parts):
    """Egg in two halves as printed: a cup with a rim band and a dome with a band and a cap, three colours."""
    flat = math.radians(38.57)
    parts.main.shell(0.032, 0.04, 0.006, COLOUR, segments=7, centre=(-0.06, 0, 0), radius_top=0.05, turn=flat)
    parts.colour(2).shell(0.051, 0.016, 0.007, COLOUR, segments=7, centre=(-0.06, 0, 0.04), radius_top=0.053,
                          turn=flat, open_base=True)
    parts.colour(3).box((0.016, 0.01, 0.016), (-0.06, -0.037, 0.022), COLOUR, rotation=(0, math.pi / 4, 0))
    spin = (0, 0, 0)
    parts.main.cylinder(0.052, 0.03, (0.06, 0, 0.015), COLOUR, segments=7, rotation=spin, radius_top=0.05)
    parts.colour(2).cylinder(0.053, 0.012, (0.06, 0, 0.036), COLOUR, segments=7, rotation=spin, radius_top=0.051)
    parts.main.cylinder(0.049, 0.03, (0.06, 0, 0.057), COLOUR, segments=7, rotation=spin, radius_top=0.032)
    parts.colour(3).cylinder(0.032, 0.024, (0.06, 0, 0.084), COLOUR, segments=7, rotation=spin, radius_top=0.008)


def _bunny_figurine(parts):
    """Sitting rabbit: stout body, round head, two tall ears and front paws; tail, inner ears and nose in the second colour."""
    parts.main.cylinder(0.055, 0.075, (0, 0.005, 0.0375), COLOUR, segments=7, radius_top=0.036)
    parts.main.ball(0.042, (0, -0.008, 0.105), COLOUR, subdivisions=1)
    detail = parts.colour(2)
    for side in (-1, 1):
        print_shapes.limb(parts.main, (side * 0.018, 0, 0.13), (side * 0.028, 0.008, 0.215), 0.014, 0.007, segments=5)
        print_shapes.limb(detail, (side * 0.02, -0.008, 0.15), (side * 0.027, -0.001, 0.2), 0.008, 0.005, segments=4)
        parts.main.box((0.026, 0.04, 0.018), (side * 0.03, -0.05, 0.009), COLOUR)
    detail.ball(0.022, (0, 0.062, 0.026), COLOUR, subdivisions=1)
    detail.box((0.014, 0.01, 0.011), (0, -0.045, 0.103), COLOUR)


def _egg_cup_bunny(parts):
    """Egg cup with two ears rising from the back of the rim; paws, tail, nose and inner ears in the second colour."""
    parts.main.shell(0.042, 0.06, 0.007, COLOUR, segments=8, radius_top=0.056, turn=FLAT_8)
    detail = parts.colour(2)
    for side in (-1, 1):
        print_shapes.limb(parts.main, (side * 0.02, 0.044, 0.05), (side * 0.032, 0.056, 0.135), 0.014, 0.007, segments=5)
        print_shapes.limb(detail, (side * 0.022, 0.036, 0.07), (side * 0.03, 0.046, 0.12), 0.008, 0.005, segments=4)
        detail.box((0.028, 0.035, 0.016), (side * 0.028, -0.058, 0.008), COLOUR)
    detail.ball(0.02, (0, 0.066, 0.026), COLOUR, subdivisions=1)
    detail.box((0.014, 0.01, 0.011), (0, -0.049, 0.04), COLOUR)


def _easter_basket(parts):
    """Round flared basket with a rim band and a tall hoop handle in the second colour."""
    parts.main.shell(0.085, 0.085, 0.008, COLOUR, segments=8, radius_top=0.115, turn=FLAT_8)
    trim = parts.colour(2)
    trim.shell(0.119, 0.014, 0.014, COLOUR, segments=8, centre=(0, 0, 0.078), turn=FLAT_8, open_base=True)
    _arch(trim, 0.104, 0.085, 0.105, 0.012)


def _easter_egg_hunt_markers_x10(parts):
    """Ten garden markers lying flat in two rows: an egg shaped head on a pointed stake in the second colour."""
    egg = [(0.008, -0.02), (0.015, -0.004), (0.008, 0.022), (-0.008, 0.022), (-0.015, -0.004), (-0.008, -0.02)]
    stake = [(-0.007, -0.016), (0, -0.066), (0.007, -0.016)]
    for x, y in print_shapes.grid(5, 2, 0.036, 0.094):
        parts.main.plate(egg, 0.006, COLOUR, centre=(x, y + 0.021, 0))
        parts.colour(2).plate(stake, 0.004, COLOUR, centre=(x, y + 0.021, 0))


def _chick_figurine(parts):
    """Plump chick with a round head and stubby wings; beak, feet and a head tuft in the second colour."""
    parts.main.cylinder(0.05, 0.045, (0, 0, 0.0225), COLOUR, segments=8, radius_top=0.062)
    parts.main.cylinder(0.062, 0.045, (0, 0, 0.0675), COLOUR, segments=8, radius_top=0.035)
    parts.main.ball(0.04, (0, -0.01, 0.115), COLOUR, subdivisions=1)
    detail = parts.colour(2)
    for side in (-1, 1):
        parts.main.box((0.014, 0.05, 0.03), (side * 0.058, 0.006, 0.046), COLOUR, rotation=(0, -side * 0.5, 0))
        detail.box((0.022, 0.03, 0.008), (side * 0.022, -0.058, 0.004), COLOUR)
    print_shapes.limb(detail, (0, -0.036, 0.112), (0, -0.074, 0.104), 0.016, 0.002, segments=4)
    print_shapes.limb(detail, (0, -0.01, 0.145), (0, 0.006, 0.172), 0.012, 0.004, segments=4)


def _spring_flower_garland(parts):
    """Four five petalled flowers lying flat in a zigzag, with centres in a second colour and a vine joining them in a third."""
    petals = [
        ((0.035 if index % 2 == 0 else 0.023) * math.sin(index * math.pi / 5),
         (0.035 if index % 2 == 0 else 0.023) * -math.cos(index * math.pi / 5))
        for index in range(10)
    ]
    centres = [((index - 1.5) * 0.072, 0.016 if index % 2 == 0 else -0.016) for index in range(4)]
    for x, y in centres:
        parts.main.plate(petals, 0.006, COLOUR, centre=(x, y, 0))
        parts.colour(2).cylinder(0.013, 0.004, (x, y, 0.008), COLOUR, segments=4)
    for (x, y), (next_x, next_y) in zip(centres, centres[1:]):
        length = math.hypot(next_x - x, next_y - y)
        parts.colour(3).box((length, 0.012, 0.004), ((x + next_x) / 2, (y + next_y) / 2, 0.002), COLOUR,
                            rotation=(0, 0, math.atan2(next_y - y, next_x - x)))


def _best_mum_plaque(parts):
    """Heart shaped plaque lying flat with raised lettering: a row of four small blocks above three larger ones."""
    parts.main.plate(_heart(0.23, 0.21), 0.008, COLOUR)
    letters = parts.colour(2)
    for index, width in enumerate((0.02, 0.016, 0.02, 0.018)):
        _glyph(letters, "block", (index - 1.5) * 0.027, 0.054, width, 0.02, 0.008)
    # Plain blocks, not letter shapes: at this size bar-built letters misread.
    for index in range(3):
        _glyph(letters, "block", (index - 1) * 0.044, 0.004, 0.034, 0.044, 0.008)


def _flower_bouquet_print_in_place(parts):
    """Upright bouquet: a paper cone on a foot, five flower heads fanning out of it, their centres and a bow in a third colour."""
    parts.main.cylinder(0.045, 0.01, (0, 0, 0.005), COLOUR, segments=7)
    parts.main.cylinder(0.028, 0.13, (0, 0, 0.075), COLOUR, segments=7, radius_top=0.085)
    heads = [((0, 0, 0.15), (0, 0, 1))]
    for quarter in range(4):
        angle = quarter * math.pi / 2
        heads.append(((0.06 * math.cos(angle), 0.06 * math.sin(angle), 0.135),
                      (0.5 * math.cos(angle), 0.5 * math.sin(angle), 0.866)))
    for start, lean in heads:
        tip = tuple(start[axis] + lean[axis] * 0.03 for axis in range(3))
        print_shapes.limb(parts.colour(2), start, tip, 0.03, 0.045, segments=6)
        top = tuple(start[axis] + lean[axis] * 0.04 for axis in range(3))
        print_shapes.limb(parts.colour(3), tip, top, 0.018, 0.012, segments=4)
    parts.colour(3).box((0.06, 0.016, 0.016), (0, -0.046, 0.06), COLOUR)


VARIANTS = {
    "party_favour_boxes_x10": _party_favour_boxes_x10,
    "name_keyrings_x10": _name_keyrings_x10,
    "event_lanyard_badges_x50": _event_lanyard_badges_x50,
    "gender_reveal_confetti_cannon": _gender_reveal_confetti_cannon,
    "graduation_cap_topper": _graduation_cap_topper,
    "baby_shower_gift_tags_x20": _baby_shower_gift_tags_x20,
    "bunting_letters_custom": _bunting_letters_custom,
    "pumpkin_low_poly": _pumpkin_low_poly,
    "jack_o_lantern_light": _jack_o_lantern_light,
    "pumpkin_tea_light_cover": _pumpkin_tea_light_cover,
    "haunted_house_lantern": _haunted_house_lantern,
    "cauldron_sweet_bowl": _cauldron_sweet_bowl,
    "coffin_trinket_box": _coffin_trinket_box,
    "halloween_door_wreath": _halloween_door_wreath,
    "trick_or_treat_bucket": _trick_or_treat_bucket,
    "heart_box": _heart_box,
    "love_lock_keyring_pair": _love_lock_keyring_pair,
    "couples_name_sign": _couples_name_sign,
    "heart_puzzle": _heart_puzzle,
    "valentine_s_card_stand": _valentine_s_card_stand,
    "easter_egg_fillable": _easter_egg_fillable,
    "bunny_figurine": _bunny_figurine,
    "egg_cup_bunny": _egg_cup_bunny,
    "easter_basket": _easter_basket,
    "easter_egg_hunt_markers_x10": _easter_egg_hunt_markers_x10,
    "chick_figurine": _chick_figurine,
    "spring_flower_garland": _spring_flower_garland,
    "best_mum_plaque": _best_mum_plaque,
    "flower_bouquet_print_in_place": _flower_bouquet_print_in_place,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
