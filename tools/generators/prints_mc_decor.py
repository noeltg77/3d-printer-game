"""Printed item generator for multicolour designs: home decor, jewellery and
fashion, personalised and custom, wall art and signs.

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


# Outline of a heart one unit across each way, anticlockwise from the bottom tip.
HEART = ((0, -0.9), (0.9, 0.1), (0.9, 0.6), (0.5, 0.9), (0, 0.55), (-0.5, 0.9), (-0.9, 0.6), (-0.9, 0.1))


def _scaled(points, scale_x, scale_y=None, offset=(0.0, 0.0)):
    """A unit outline scaled and moved."""
    scale_y = scale_x if scale_y is None else scale_y
    return [(x * scale_x + offset[0], y * scale_y + offset[1]) for x, y in points]


def _chamfered(width, depth, cut):
    """Rectangle outline with its corners cut off, anticlockwise."""
    half_x, half_y = width / 2, depth / 2
    return [
        (-half_x + cut, -half_y), (half_x - cut, -half_y), (half_x, -half_y + cut), (half_x, half_y - cut),
        (half_x - cut, half_y), (-half_x + cut, half_y), (-half_x, half_y - cut), (-half_x, -half_y + cut),
    ]


def _ellipse(radius_x, radius_y, count, start=0.0, sweep=math.tau):
    """Points round an ellipse (or part of one), anticlockwise."""
    steps = count if sweep >= math.tau else count - 1
    return [
        (radius_x * math.cos(start + sweep * index / steps), radius_y * math.sin(start + sweep * index / steps))
        for index in range(count)
    ]


def _star(outer, inner, points=5):
    """Star outline with one point upwards, anticlockwise."""
    return [
        ((outer if index % 2 == 0 else inner) * math.cos(math.pi / 2 + math.pi * index / points),
         (outer if index % 2 == 0 else inner) * math.sin(math.pi / 2 + math.pi * index / points))
        for index in range(points * 2)
    ]


def _letters(builder, widths, centre_x, base_y, depth, z, height=0.003, gap=0.006):
    """Row of raised blocks standing in for lettering, lying flat and reading along X.

    `base_y` is the line the letters stand on and `depth` how tall they are on
    the page (one number, or one per letter). `z` is the surface they sit on.
    """
    depths = depth if isinstance(depth, (tuple, list)) else [depth] * len(widths)
    x = centre_x - (sum(widths) + gap * (len(widths) - 1)) / 2
    for width, tall in zip(widths, depths):
        builder.box((width, tall, height), (x + width / 2, base_y + tall / 2, z + height / 2), COLOUR)
        x += width + gap


def _geometric_wall_art_panel_x6(parts):
    """Six square tiles, each with a raised triangle across one corner, turned a step from tile to tile."""
    half = 0.037
    for index, (x, y) in enumerate(print_shapes.grid(3, 2, 0.097, 0.097)):
        parts.main.box((0.088, 0.088, 0.008), (x, y, 0.004), COLOUR)
        turn = index * math.pi / 2
        cos, sin = math.cos(turn), math.sin(turn)
        corners = [(-half, -half), (half, -half), (-half, half)]
        points = [(px * cos - py * sin, px * sin + py * cos) for px, py in corners]
        parts.colour(2).plate(points, 0.004, COLOUR, centre=(x, y, 0.008))


def _clock_case(parts):
    """Round wall clock case lying flat: a rimmed dish with four hour markers, two hands and a hub."""
    parts.main.shell(0.125, 0.016, 0.014, COLOUR, segments=12, floor=0.006)
    face = parts.colour(2)
    for quarter in range(4):
        angle = quarter * math.pi / 2
        face.box((0.012, 0.03, 0.003), (math.sin(angle) * 0.085, math.cos(angle) * 0.085, 0.0075), COLOUR, rotation=(0, 0, -angle))
    for angle, length, width in ((math.radians(60), 0.05, 0.013), (math.radians(-40), 0.078, 0.009)):
        face.box(
            (width, length, 0.004), (math.sin(angle) * length / 2, math.cos(angle) * length / 2, 0.008), COLOUR,
            rotation=(0, 0, -angle))
    face.cylinder(0.013, 0.007, (0, 0, 0.0095), COLOUR, segments=6)


def _bonsai_style_tree_sculpture(parts):
    """Shallow pot with a bent trunk and one side branch, carrying three flattened pads of foliage."""
    parts.main.box((0.13, 0.085, 0.035), (0, 0, 0.0175), COLOUR, taper=1.15)
    print_shapes.limb(parts.main, (-0.01, 0, 0.03), (0.03, 0, 0.1), 0.018, 0.013)
    print_shapes.limb(parts.main, (0.03, 0, 0.095), (-0.025, 0, 0.16), 0.013, 0.008)
    print_shapes.limb(parts.main, (0.03, 0, 0.095), (0.085, 0, 0.125), 0.009, 0.006, segments=5)
    foliage = parts.colour(2)
    foliage.ball(0.052, (-0.035, 0, 0.175), COLOUR, subdivisions=1, scale=(1.2, 1.0, 0.55))
    foliage.ball(0.04, (0.09, 0, 0.14), COLOUR, subdivisions=1, scale=(1.2, 1.0, 0.55))
    foliage.ball(0.036, (0.025, 0, 0.215), COLOUR, subdivisions=1, scale=(1.2, 1.0, 0.6))


def _pet_portrait_figurine_custom(parts):
    """Sitting dog on a plinth: body, head, muzzle, paws and tail in one colour, plinth in a second, ears, collar and nose in a third."""
    parts.colour(2).box((0.17, 0.125, 0.016), (0, 0, 0.008), COLOUR, taper=0.92)
    dog = parts.main
    dog.cylinder(0.05, 0.085, (0, 0.012, 0.0585), COLOUR, segments=7, radius_top=0.034)
    dog.ball(0.042, (0, -0.003, 0.142), COLOUR, subdivisions=1)
    dog.box((0.034, 0.036, 0.026), (0, -0.045, 0.13), COLOUR)
    for side in (-1, 1):
        dog.box((0.022, 0.036, 0.018), (side * 0.026, -0.042, 0.025), COLOUR)
    print_shapes.limb(dog, (0, 0.04, 0.03), (0, 0.058, 0.075), 0.011, 0.004, segments=5)
    trim = parts.colour(3)
    trim.cylinder(0.041, 0.012, (0, 0.01, 0.1), COLOUR, segments=7)
    trim.box((0.017, 0.01, 0.013), (0, -0.066, 0.139), COLOUR)
    for side in (-1, 1):
        trim.box((0.016, 0.03, 0.05), (side * 0.044, 0.002, 0.136), COLOUR, rotation=(0, side * -0.3, 0))


def _topographic_city_map(parts):
    """Square map tile with two stepped contours of high ground in one corner, a river in a second colour and six blocks of buildings in a third."""
    parts.main.box((0.25, 0.25, 0.008), (0, 0, 0.004), COLOUR)
    parts.main.plate([(0.02, 0.125), (0.0, 0.06), (0.05, 0.0), (0.125, -0.02), (0.125, 0.125)], 0.006, COLOUR, centre=(0, 0, 0.008))
    parts.main.plate([(0.07, 0.125), (0.06, 0.08), (0.09, 0.05), (0.125, 0.04), (0.125, 0.125)], 0.006, COLOUR, centre=(0, 0, 0.014))
    river = [(-0.125, 0.07), (-0.125, 0.04), (-0.05, 0.0), (-0.03, -0.125), (0.0, -0.125), (-0.02, 0.02)]
    parts.colour(2).plate(river, 0.002, COLOUR, centre=(0, 0, 0.008))
    blocks = (
        (-0.095, -0.085, 0.036, 0.025), (-0.09, -0.035, 0.03, 0.042), (0.04, -0.08, 0.034, 0.055),
        (0.09, -0.085, 0.036, 0.03), (-0.075, 0.095, 0.04, 0.02), (-0.025, 0.085, 0.028, 0.036),
    )
    for x, y, side, height in blocks:
        parts.colour(3).box((side, side, height), (x, y, 0.008 + height / 2), COLOUR)


def _hair_clip_set_x4(parts):
    """Four flat teardrop clips, each with a stripe and a round or diamond stud in the second colour."""
    outline = [(-0.029, 0), (-0.012, -0.01), (0.022, -0.006), (0.029, 0), (0.022, 0.006), (-0.012, 0.01)]
    for index, (x, y) in enumerate(print_shapes.grid(2, 2, 0.066, 0.036)):
        parts.main.plate(outline, 0.005, COLOUR, centre=(x, y, 0))
        trim = parts.colour(2)
        trim.box((0.022, 0.004, 0.002), (x + 0.012, y, 0.006), COLOUR)
        if index in (0, 3):
            trim.cylinder(0.008, 0.004, (x - 0.012, y, 0.007), COLOUR, segments=6)
        else:
            trim.box((0.012, 0.012, 0.004), (x - 0.012, y, 0.007), COLOUR, rotation=(0, 0, math.pi / 4))


def _bag_charm(parts):
    """Flat star charm with a tab at its top point, a smaller star inlaid on it and a split ring, both in the second colour."""
    shift = -0.026
    parts.main.plate(_scaled(_star(0.045, 0.022), 1.0, offset=(0, shift)), 0.006, COLOUR)
    parts.main.box((0.016, 0.02, 0.006), (0, 0.048 + shift, 0.003), COLOUR)
    parts.colour(2).plate(_scaled(_star(0.026, 0.013), 1.0, offset=(0, shift)), 0.002, COLOUR, centre=(0, 0, 0.006))
    parts.colour(2).shell(0.019, 0.005, 0.005, COLOUR, segments=8, centre=(0, 0.069 + shift, 0), open_base=True)


def _shoe_charms_x5(parts):
    """Five small studs laid out three and two (round, hexagonal and square), each with a raised motif in one of two more colours."""
    spots = [(-0.042, 0.021), (0, 0.021), (0.042, 0.021), (-0.021, -0.021), (0.021, -0.021)]
    for index, (x, y) in enumerate(spots):
        if index == 2:
            parts.main.box((0.032, 0.032, 0.007), (x, y, 0.0035), COLOUR)
        else:
            parts.main.cylinder(0.018 if index % 3 == 0 else 0.019, 0.007, (x, y, 0.0035), COLOUR, segments=8 if index % 3 == 0 else 6)
    top = 0.0085
    parts.colour(2).cylinder(0.01, 0.003, (spots[0][0], spots[0][1], top), COLOUR, segments=5)
    parts.colour(3).box((0.014, 0.014, 0.003), (spots[1][0], spots[1][1], top), COLOUR, rotation=(0, 0, math.pi / 4))
    parts.colour(2).cylinder(0.01, 0.003, (spots[2][0], spots[2][1], top), COLOUR, segments=6)
    parts.colour(3).cylinder(0.012, 0.003, (spots[3][0], spots[3][1], top), COLOUR, segments=3)
    parts.colour(2).box((0.022, 0.008, 0.003), (spots[4][0], spots[4][1], top), COLOUR)


def _badge_and_pin_custom(parts):
    """Shield badge and a small round pin side by side, each with an inner field in a second colour and an emblem in a third."""
    shield = [(0, -0.045), (0.036, -0.01), (0.036, 0.04), (-0.036, 0.04), (-0.036, -0.01)]
    badge_x, pin_x = -0.028, 0.045
    parts.main.plate(_scaled(shield, 1.0, offset=(badge_x, 0)), 0.006, COLOUR)
    parts.colour(2).plate(_scaled(shield, 0.74, offset=(badge_x, 0.001)), 0.002, COLOUR, centre=(0, 0, 0.006))
    parts.colour(3).cylinder(0.011, 0.003, (badge_x, 0.012, 0.0095), COLOUR, segments=5)
    parts.colour(3).box((0.034, 0.007, 0.003), (badge_x, -0.008, 0.0095), COLOUR)
    parts.main.cylinder(0.022, 0.006, (pin_x, 0, 0.003), COLOUR, segments=8)
    parts.colour(2).cylinder(0.016, 0.002, (pin_x, 0, 0.007), COLOUR, segments=8)
    parts.colour(3).box((0.013, 0.013, 0.003), (pin_x, 0, 0.0095), COLOUR, rotation=(0, 0, math.pi / 4))


def _name_keyring(parts):
    """Flat tag with cut corners and a ring loop at one end, with five raised letters along it."""
    parts.main.plate(_scaled(_chamfered(0.1, 0.034, 0.007), 1.0, offset=(0.012, 0)), 0.006, COLOUR)
    parts.main.shell(0.015, 0.006, 0.005, COLOUR, segments=6, centre=(-0.048, 0, 0), open_base=True)
    _letters(parts.colour(2), (0.013, 0.01, 0.014, 0.01, 0.013), 0.014, -0.009, 0.018, 0.006, gap=0.004)


def _custom_name_sign(parts):
    """Long flat sign with cut corners: a tall capital and five smaller raised letters over an underline."""
    parts.main.plate(_chamfered(0.25, 0.085, 0.02), 0.008, COLOUR)
    name = parts.colour(2)
    _letters(name, (0.03, 0.022, 0.018, 0.024, 0.018, 0.022), 0, -0.014, (0.05, 0.032, 0.032, 0.032, 0.032, 0.032), 0.008, height=0.006)
    name.box((0.17, 0.006, 0.004), (0.005, -0.027, 0.01), COLOUR)


def _family_name_plaque(parts):
    """Arch topped plaque lying flat with three rows of raised lettering (small, large, small) and a rule between."""
    arch = [(-0.14, -0.085), (0.14, -0.085), (0.14, 0.04), (0.1, 0.07), (0.04, 0.085), (-0.04, 0.085), (-0.1, 0.07), (-0.14, 0.04)]
    parts.main.plate(arch, 0.008, COLOUR)
    words = parts.colour(2)
    _letters(words, (0.016, 0.012, 0.016), 0, 0.045, 0.018, 0.008, gap=0.005)
    _letters(words, (0.03, 0.024, 0.03, 0.022, 0.028, 0.024), 0, -0.02, 0.048, 0.008, height=0.005, gap=0.008)
    words.box((0.2, 0.005, 0.003), (0, -0.034, 0.0095), COLOUR)
    _letters(words, (0.03, 0.04), 0, -0.065, 0.016, 0.008, gap=0.012)


def _custom_logo_sign_business(parts):
    """Flat sign with cut corners: a roundel and a tagline bar in a second colour, a triangle emblem and four letters in a third."""
    parts.main.plate(_chamfered(0.28, 0.17, 0.022), 0.008, COLOUR)
    parts.colour(2).cylinder(0.055, 0.004, (-0.072, 0.005, 0.01), COLOUR, segments=8)
    parts.colour(2).box((0.125, 0.01, 0.003), (0.07, -0.04, 0.0095), COLOUR)
    parts.colour(3).plate([(-0.032, -0.022), (0.032, -0.022), (0, 0.034)], 0.003, COLOUR, centre=(-0.072, 0.005, 0.012))
    _letters(parts.colour(3), (0.026, 0.02, 0.026, 0.022), 0.07, -0.018, 0.045, 0.008, height=0.005, gap=0.008)


def _personalised_bookmark(parts):
    """Flat strip with a notched end, five raised letters along it and a small five sided stud at the other end."""
    strip = [(-0.065, -0.017), (0.065, -0.017), (0.052, 0), (0.065, 0.017), (-0.065, 0.017)]
    parts.main.plate(strip, 0.004, COLOUR)
    _letters(parts.colour(2), (0.012, 0.01, 0.013, 0.01, 0.012), 0.0, -0.008, 0.016, 0.004, height=0.002, gap=0.004)
    parts.colour(2).cylinder(0.008, 0.002, (-0.05, 0, 0.005), COLOUR, segments=5)


def _wedding_date_plaque(parts):
    """Heart shaped plaque lying flat with two linked rings and a three part date in raised blocks."""
    parts.main.plate(_scaled(HEART, 0.105), 0.008, COLOUR)
    detail = parts.colour(2)
    detail.shell(0.028, 0.004, 0.006, COLOUR, segments=6, centre=(-0.018, 0.028, 0.008), open_base=True)
    detail.shell(0.028, 0.0055, 0.006, COLOUR, segments=6, centre=(0.018, 0.028, 0.008), open_base=True, turn=math.pi / 6)
    _letters(detail, (0.022, 0.022, 0.022), 0, -0.042, 0.02, 0.008, gap=0.008)


def _pet_memorial_plaque(parts):
    """Oval plaque lying flat with a paw print beside a raised name and a bar for the dates."""
    parts.main.plate(_ellipse(0.11, 0.075, 12), 0.008, COLOUR)
    detail = parts.colour(2)
    detail.cylinder(0.022, 0.003, (-0.055, -0.014, 0.0095), COLOUR, segments=6)
    for index in range(4):
        angle = math.radians(145 - index * 37)
        detail.cylinder(0.009, 0.003, (-0.055 + math.cos(angle) * 0.034, -0.012 + math.sin(angle) * 0.034, 0.0095), COLOUR, segments=5)
    _letters(detail, (0.018, 0.014, 0.018, 0.014), 0.04, -0.004, 0.028, 0.008, gap=0.005)
    detail.box((0.06, 0.008, 0.003), (0.04, -0.022, 0.0095), COLOUR)


def _street_sign_replica(parts):
    """Long flat street sign with a raised border, six letters and a small district block in the second colour."""
    parts.main.box((0.3, 0.09, 0.008), (0, 0, 0.004), COLOUR)
    trim = parts.colour(2)
    for side in (-1, 1):
        trim.box((0.29, 0.006, 0.003), (0, side * 0.038, 0.0095), COLOUR)
        trim.box((0.006, 0.07, 0.003), (side * 0.142, 0, 0.0095), COLOUR)
    _letters(trim, (0.022, 0.018, 0.024, 0.018, 0.022, 0.02), -0.025, -0.018, 0.036, 0.008, gap=0.007)
    trim.box((0.03, 0.02, 0.003), (0.108, -0.01, 0.0095), COLOUR)


def _custom_fridge_magnet_photo_relief(parts):
    """Square magnet framing a relief portrait: a backdrop, two head and shoulders figures and a sun, each in its own colour."""
    parts.main.box((0.1, 0.1, 0.008), (0, 0, 0.004), COLOUR)
    parts.colour(2).box((0.08, 0.08, 0.002), (0, 0, 0.009), COLOUR)
    for x, scale in ((-0.016, 1.0), (0.02, 0.8)):
        shoulders = [(-0.02, 0.0), (0.02, 0.0), (0.012, 0.024), (-0.012, 0.024)]
        parts.colour(3).plate(_scaled(shoulders, scale, offset=(x, -0.036)), 0.003, COLOUR, centre=(0, 0, 0.01))
        parts.colour(3).cylinder(0.012 * scale, 0.003, (x, -0.036 + 0.034 * scale, 0.0115), COLOUR, segments=6)
    parts.colour(4).cylinder(0.009, 0.003, (0.024, 0.024, 0.0115), COLOUR, segments=6)


def _spotify_code_plaque(parts):
    """Music code plaque: a flat tag with a roundel and a row of nine bars of different lengths, like a scannable sound wave."""
    parts.main.plate(_chamfered(0.19, 0.065, 0.012), 0.006, COLOUR)
    code = parts.colour(2)
    code.cylinder(0.02, 0.003, (-0.066, 0, 0.0075), COLOUR, segments=8)
    for index, length in enumerate((0.014, 0.03, 0.022, 0.042, 0.018, 0.036, 0.026, 0.012, 0.03)):
        code.box((0.007, length, 0.003), (-0.033 + index * 0.0135, 0, 0.0075), COLOUR)


def _child_height_chart(parts):
    """Long flat ruler with a pointed end: seven tick marks in a second colour, four number blocks and a stud at the tip in a third."""
    board = [(-0.165, -0.035), (0.14, -0.035), (0.165, 0), (0.14, 0.035), (-0.165, 0.035)]
    parts.main.plate(board, 0.006, COLOUR)
    for index in range(7):
        x = -0.145 + index * 0.04
        length = 0.03 if index % 2 == 0 else 0.018
        parts.colour(2).box((0.006, length, 0.003), (x, -0.035 + length / 2, 0.0075), COLOUR)
        if index % 2 == 0:
            parts.colour(3).box((0.016, 0.018, 0.003), (x + 0.004, 0.014, 0.0075), COLOUR)
    parts.colour(3).cylinder(0.011, 0.003, (0.143, 0, 0.0075), COLOUR, segments=5)


def _multicolour_mountain_landscape(parts):
    """Layered relief panel: a back board, a far range of two peaks, nearer hills in front, and snow caps and a sun in a fourth colour."""
    parts.main.box((0.27, 0.18, 0.006), (0, 0, 0.003), COLOUR)
    far = [(-0.135, -0.09), (0.135, -0.09), (0.135, -0.01), (0.07, 0.06), (0.02, 0.0), (-0.04, 0.075), (-0.135, -0.02)]
    parts.colour(2).plate(far, 0.004, COLOUR, centre=(0, 0, 0.006))
    near = [(-0.135, -0.09), (0.135, -0.09), (0.135, -0.05), (0.08, -0.025), (0.01, -0.055), (-0.07, -0.015), (-0.135, -0.045)]
    parts.colour(3).plate(near, 0.009, COLOUR, centre=(0, 0, 0.006))
    snow = parts.colour(4)
    snow.plate([(0.07, 0.06), (0.05, 0.036), (0.096, 0.032)], 0.002, COLOUR, centre=(0, 0, 0.01))
    snow.plate([(-0.04, 0.075), (-0.073, 0.042), (-0.016, 0.045)], 0.002, COLOUR, centre=(0, 0, 0.01))
    snow.cylinder(0.018, 0.003, (-0.105, 0.06, 0.0075), COLOUR, segments=8)


def _word_art_sign_home(parts):
    """The word as flat block letters on a joining bar: H, M and E in one colour, with a heart in a second standing in for the O."""
    thick, stroke, tall = 0.012, 0.014, 0.075
    word = parts.main
    word.box((0.24, 0.014, 0.008), (0, -0.0445, 0.004), COLOUR)
    for x in (-0.108, -0.072, 0.012, 0.048, 0.072):
        word.box((stroke, tall, thick), (x, 0, thick / 2), COLOUR)
    word.box((0.022, stroke, thick), (-0.09, 0, thick / 2), COLOUR)
    for side in (-1, 1):
        print_shapes.strut(word, (0.03 + side * 0.018, 0.031, thick / 2), (0.03, -0.004, thick / 2), thick)
    for y in (-0.0305, 0, 0.0305):
        word.box((0.036, stroke, thick), (0.097, y, thick / 2), COLOUR)
    parts.colour(2).plate(_scaled(HEART, 0.036, offset=(-0.03, -0.005)), thick, COLOUR)


def _layered_sunset_panel(parts):
    """Round panel lying flat: a sun and its two reflections, a raised half of sea across the bottom, and an island with a palm in a fourth colour."""
    parts.main.cylinder(0.13, 0.006, (0, 0, 0.003), COLOUR, segments=12)
    parts.colour(2).cylinder(0.055, 0.003, (0, 0, 0.0075), COLOUR, segments=10)
    parts.colour(3).plate(_ellipse(0.118, 0.118, 7, start=math.pi, sweep=math.pi), 0.005, COLOUR, centre=(0, 0, 0.006))
    parts.colour(2).box((0.07, 0.008, 0.002), (0.01, -0.025, 0.012), COLOUR)
    parts.colour(2).box((0.045, 0.008, 0.002), (0.01, -0.05, 0.012), COLOUR)
    palm = parts.colour(4)
    palm.plate([(-0.08, -0.078), (-0.02, -0.085), (-0.04, -0.06), (-0.07, -0.055)], 0.003, COLOUR, centre=(0, 0, 0.011))
    palm.box((0.008, 0.05, 0.003), (-0.056, -0.036, 0.0125), COLOUR, rotation=(0, 0, -0.12))
    for turn in (-0.35, 0.35):
        palm.box((0.046, 0.01, 0.003), (-0.053, -0.015, 0.0125), COLOUR, rotation=(0, 0, turn))


def _neon_style_sign_led_channel(parts):
    """Back board carrying raised light channels in the second colour: a hollow lightning bolt, three hollow letter loops and an underline."""
    parts.main.box((0.27, 0.16, 0.006), (0, 0, 0.003), COLOUR)
    bolt = [(0.2, 1.0), (-0.5, -0.1), (-0.05, -0.1), (-0.25, -1.0), (0.5, 0.2), (0.05, 0.2)]
    tubes = parts.colour(2)
    tubes.outline(_scaled(bolt, 0.065, 0.062), 0.012, 0.008, COLOUR, centre=(-0.08, 0, 0.006))
    for x in (0.0, 0.045, 0.09):
        loop = [(-0.017, -0.022), (0.017, -0.022), (0.017, 0.04), (-0.017, 0.04)]
        tubes.outline(loop, 0.012, 0.007, COLOUR, centre=(x, 0, 0.006))
    tubes.box((0.125, 0.008, 0.012), (0.045, -0.042, 0.012), COLOUR)


def _retro_game_pixel_art(parts):
    """Pixel art heart on a back board: the heart in rows of square pixels, a highlight at its top left and a shaded edge down its right, each a colour."""
    pixel = 0.03
    parts.main.box((0.25, 0.22, 0.006), (0, 0, 0.003), COLOUR)

    def run(builder, column, row, across, down, z, height):
        builder.box((across * pixel, down * pixel, height), ((column - 3) * pixel, (2.5 - row) * pixel, z + height / 2), COLOUR)

    fill = parts.colour(2)
    run(fill, 1.5, 0, 2, 1, 0.006, 0.006)
    run(fill, 4.5, 0, 2, 1, 0.006, 0.006)
    run(fill, 3, 1.5, 7, 2, 0.006, 0.006)
    run(fill, 3, 3, 5, 1, 0.006, 0.006)
    run(fill, 3, 4, 3, 1, 0.006, 0.006)
    run(fill, 3, 5, 1, 1, 0.006, 0.006)
    run(parts.colour(3), 1, 0.5, 1, 2, 0.012, 0.002)
    run(parts.colour(4), 6, 1.5, 1, 2, 0.012, 0.002)
    run(parts.colour(4), 5, 3, 1, 1, 0.012, 0.002)
    run(parts.colour(4), 4, 4, 1, 1, 0.012, 0.002)


def _hexagon_light_panel_set(parts):
    """Five hexagonal light panels in a honeycomb cluster, each a body with a raised diffuser face in the second colour."""
    radius = 0.055
    pitch = radius * math.sqrt(3)
    spots = [(-pitch, 0), (0, 0), (pitch, 0), (-pitch / 2, radius * 1.5), (pitch / 2, radius * 1.5)]
    for x, y in spots:
        y -= radius * 0.75
        parts.main.cylinder(radius - 0.002, 0.014, (x, y, 0.007), COLOUR, segments=6)
        parts.colour(2).cylinder(radius - 0.012, 0.003, (x, y, 0.0155), COLOUR, segments=6)


def _bar_sign_custom(parts):
    """Flat bar sign: three big letters, a small row beneath and a head of foam in a second colour, a tankard and two rails in a third."""
    parts.main.box((0.28, 0.15, 0.008), (0, 0, 0.004), COLOUR)
    words = parts.colour(2)
    _letters(words, (0.038, 0.038, 0.038), -0.045, -0.02, 0.06, 0.008, height=0.005, gap=0.01)
    _letters(words, (0.03, 0.04, 0.03), -0.045, -0.048, 0.014, 0.008, gap=0.008)
    words.box((0.048, 0.016, 0.006), (0.082, 0.03, 0.011), COLOUR)
    trim = parts.colour(3)
    trim.box((0.04, 0.055, 0.004), (0.082, -0.005, 0.01), COLOUR)
    trim.box((0.014, 0.03, 0.004), (0.108, -0.005, 0.01), COLOUR)
    for side in (-1, 1):
        trim.box((0.26, 0.006, 0.003), (0, side * 0.065, 0.0095), COLOUR)


def _shop_opening_hours_sign(parts):
    """Upright format sign lying flat: a raised heading bar and five rows of a short day block and a longer hours block."""
    parts.main.box((0.17, 0.22, 0.008), (0, 0, 0.004), COLOUR)
    rows = parts.colour(2)
    rows.box((0.13, 0.024, 0.004), (0, 0.082, 0.01), COLOUR)
    for index in range(5):
        y = 0.046 - index * 0.031
        rows.box((0.036, 0.015, 0.003), (-0.05, y, 0.0095), COLOUR)
        hours = 0.07 if index < 4 else 0.042
        rows.box((hours, 0.015, 0.003), (-0.018 + hours / 2, y, 0.0095), COLOUR)


VARIANTS = {
    "geometric_wall_art_panel_x6": _geometric_wall_art_panel_x6,
    "clock_case": _clock_case,
    "bonsai_style_tree_sculpture": _bonsai_style_tree_sculpture,
    "pet_portrait_figurine_custom": _pet_portrait_figurine_custom,
    "topographic_city_map": _topographic_city_map,
    "hair_clip_set_x4": _hair_clip_set_x4,
    "bag_charm": _bag_charm,
    "shoe_charms_x5": _shoe_charms_x5,
    "badge_and_pin_custom": _badge_and_pin_custom,
    "name_keyring": _name_keyring,
    "custom_name_sign": _custom_name_sign,
    "family_name_plaque": _family_name_plaque,
    "custom_logo_sign_business": _custom_logo_sign_business,
    "personalised_bookmark": _personalised_bookmark,
    "wedding_date_plaque": _wedding_date_plaque,
    "pet_memorial_plaque": _pet_memorial_plaque,
    "street_sign_replica": _street_sign_replica,
    "custom_fridge_magnet_photo_relief": _custom_fridge_magnet_photo_relief,
    "spotify_code_plaque": _spotify_code_plaque,
    "child_height_chart": _child_height_chart,
    "multicolour_mountain_landscape": _multicolour_mountain_landscape,
    "word_art_sign_home": _word_art_sign_home,
    "layered_sunset_panel": _layered_sunset_panel,
    "neon_style_sign_led_channel": _neon_style_sign_led_channel,
    "retro_game_pixel_art": _retro_game_pixel_art,
    "hexagon_light_panel_set": _hexagon_light_panel_set,
    "bar_sign_custom": _bar_sign_custom,
    "shop_opening_hours_sign": _shop_opening_hours_sign,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
