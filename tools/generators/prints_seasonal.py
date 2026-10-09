"""Printed item generator for the seasonal categories: Halloween, Bonfire Night,
Christmas, Valentine's Day, Easter, Mother's Day and Back to school.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_seasonal.py -- \
    --variant witch_hat --out assets/models/prints/witch_hat.glb
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


def _ngon(sides, radius, turn=0.0, squash=1.0):
    """Regular polygon outline, anticlockwise. `squash` flattens it front to back."""
    return [
        (radius * math.cos(turn + math.tau * index / sides), radius * squash * math.sin(turn + math.tau * index / sides))
        for index in range(sides)
    ]


def _star(points, outer, inner):
    return [
        ((outer if index % 2 == 0 else inner) * math.cos(math.pi / 2 + math.pi * index / points),
         (outer if index % 2 == 0 else inner) * math.sin(math.pi / 2 + math.pi * index / points))
        for index in range(points * 2)
    ]


# Cutter outlines, anticlockwise, about 0.07 across.
BAT = [(0, 0.018), (-0.01, 0.006), (-0.038, 0.016), (-0.022, -0.008), (0, -0.016), (0.022, -0.008), (0.038, 0.016), (0.01, 0.006)]
GHOST = [(-0.026, 0.02), (-0.026, -0.034), (-0.013, -0.024), (0, -0.034), (0.013, -0.024), (0.026, -0.034),
         (0.026, 0.02), (0.012, 0.038), (-0.012, 0.038)]
TOMBSTONE = [(-0.022, -0.034), (0.022, -0.034), (0.022, 0.02), (0.012, 0.036), (-0.012, 0.036), (-0.022, 0.02)]
HAT = [(-0.036, -0.03), (0.036, -0.03), (0.036, -0.02), (0.016, -0.02), (0, 0.036), (-0.016, -0.02), (-0.036, -0.02)]
TREE = [(0, 0.04), (-0.03, -0.015), (-0.008, -0.015), (-0.008, -0.035), (0.008, -0.035), (0.008, -0.015), (0.03, -0.015)]
BELL = [(-0.012, 0.035), (-0.03, -0.02), (-0.034, -0.03), (0.034, -0.03), (0.03, -0.02), (0.012, 0.035)]
STOCKING = [(-0.016, 0.036), (-0.016, -0.034), (0.034, -0.034), (0.034, -0.012), (0.012, -0.008), (0.012, 0.036)]
EGG = [(0, -0.036), (0.02, -0.028), (0.027, -0.006), (0.02, 0.02), (0, 0.036), (-0.02, 0.02), (-0.027, -0.006), (-0.02, -0.028)]
BUNNY = [(-0.022, -0.034), (0.022, -0.034), (0.028, -0.008), (0.02, 0.006), (0.02, 0.038), (0.006, 0.038),
         (0.004, 0.008), (-0.004, 0.008), (-0.006, 0.038), (-0.02, 0.038), (-0.02, 0.006), (-0.028, -0.008)]
CARROT = [(0, -0.04), (0.02, 0.03), (-0.02, 0.03)]


def _cutters(builder, outlines):
    """A set of open cookie cutters laid out in rows of three."""
    rows = math.ceil(len(outlines) / 3)
    for (x, y), outline in zip(print_shapes.grid(3, rows, 0.085, 0.09), outlines):
        builder.outline(outline, 0.026, 0.004, COLOUR, centre=(x, y, 0))


# Halloween

def _skull_candle_holder(builder):
    """Skull with a candle cup set into the top."""
    builder.ball(0.06, (0, 0.01, 0.075), COLOUR, scale=(0.9, 1.05, 0.9))
    builder.box((0.06, 0.05, 0.04), (0, -0.03, 0.02), COLOUR, taper=(1.1, 1.0))
    for side in (-1, 1):
        builder.cylinder(0.016, 0.012, (side * 0.021, -0.052, 0.07), COLOUR, segments=6, axis="Y")
    builder.shell(0.03, 0.03, 0.005, COLOUR, segments=6, centre=(0, 0.01, 0.115))


def _bat_garland_x10(builder):
    """Ten flat bats in two rows, ready to thread on a string."""
    bat = [(x * 0.75, y * 0.75) for x, y in BAT]
    for x, y in print_shapes.grid(5, 2, 0.058, 0.05):
        builder.plate(bat, 0.005, COLOUR, centre=(x, y, 0))


def _spider_web_wall_decor(builder):
    """Flat web: three crossing spokes, two six-sided rings and a spider sitting on it."""
    for index in range(3):
        builder.box((0.26, 0.006, 0.005), (0, 0, 0.0025), COLOUR, rotation=(0, 0, index * math.pi / 3))
    for radius in (0.125, 0.07):
        builder.shell(radius, 0.005, 0.006, COLOUR, segments=6, open_base=True)
    builder.ball(0.016, (0.05, 0.03, 0.014), COLOUR, subdivisions=1, scale=(1.0, 1.2, 0.8))
    builder.ball(0.008, (0.04, 0.012, 0.011), COLOUR, subdivisions=1)


def _witch_hat(builder):
    """Wide brim, a band and a tall cone that kinks over at the tip."""
    builder.cylinder(0.12, 0.008, (0, 0, 0.004), COLOUR, segments=12)
    builder.cylinder(0.064, 0.02, (0, 0, 0.018), COLOUR, segments=10)
    print_shapes.limb(builder, (0, 0, 0.02), (0.01, 0, 0.15), 0.058, 0.02, segments=8)
    print_shapes.limb(builder, (0.008, 0, 0.143), (0.05, 0, 0.19), 0.02, 0.003, segments=8)


def _tombstone_set_x3(builder):
    """Three gravestones on plinths: a round-topped slab, a cross and a capped, tapering slab."""
    for x in (-0.09, 0.0, 0.09):
        builder.box((0.07, 0.04, 0.012), (x, 0, 0.006), COLOUR)
    builder.box((0.055, 0.02, 0.09), (-0.09, 0, 0.057), COLOUR)
    builder.cylinder(0.0275, 0.02, (-0.09, 0, 0.102), COLOUR, segments=8, axis="Y")
    builder.box((0.02, 0.02, 0.13), (0, 0, 0.077), COLOUR)
    builder.box((0.07, 0.02, 0.02), (0, 0, 0.105), COLOUR)
    builder.box((0.06, 0.022, 0.1), (0.09, 0, 0.062), COLOUR, taper=(0.7, 1.0))
    builder.box((0.05, 0.026, 0.01), (0.09, 0, 0.115), COLOUR)


def _skeleton_hand_bowl(builder):
    """Shallow bowl cradled by five bony fingers that reach out from under it and curl up the sides."""
    builder.cylinder(0.05, 0.012, (0, 0, 0.006), COLOUR, segments=8)
    builder.shell(0.045, 0.06, 0.007, COLOUR, segments=8, centre=(0, 0, 0.012), radius_top=0.085)
    for index in range(5):
        angle = math.radians(-90 + index * 72)
        reach = (math.cos(angle), math.sin(angle))
        knuckle = (0.098 * reach[0], 0.098 * reach[1], 0.042)
        print_shapes.strut(builder, (0.045 * reach[0], 0.045 * reach[1], 0.008), knuckle, 0.013)
        print_shapes.strut(builder, knuckle, (0.092 * reach[0], 0.092 * reach[1], 0.09), 0.011)


def _halloween_cookie_cutters_x5(builder):
    """Five open cutters: pumpkin, ghost, bat, tombstone and witch's hat."""
    _cutters(builder, [_ngon(8, 0.036, squash=0.85), GHOST, [(x, y * 1.7) for x, y in BAT], TOMBSTONE, HAT])


def _crow_figurine(builder):
    """Crow facing forwards: plump body, round head, long beak, flat tail and two legs."""
    builder.ball(0.045, (0, 0.005, 0.078), COLOUR, scale=(0.8, 1.5, 0.85), rotation=(math.radians(-18), 0, 0))
    builder.ball(0.028, (0, -0.055, 0.118), COLOUR, subdivisions=1)
    print_shapes.limb(builder, (0, -0.07, 0.118), (0, -0.125, 0.106), 0.012, 0.002)
    builder.box((0.04, 0.07, 0.012), (0, 0.085, 0.052), COLOUR, rotation=(math.radians(-18), 0, 0), taper=(0.7, 1.0))
    for side in (-1, 1):
        builder.box((0.008, 0.008, 0.05), (side * 0.016, 0, 0.025), COLOUR)
        builder.box((0.012, 0.03, 0.006), (side * 0.016, -0.01, 0.003), COLOUR)


def _zombie_hand_garden_stake(builder):
    """Hand clawing up out of a mound of earth: forearm, palm, four bent fingers and a thumb."""
    builder.cylinder(0.055, 0.022, (0, 0, 0.011), COLOUR, segments=7, radius_top=0.035)
    print_shapes.limb(builder, (0, 0, 0.02), (0.005, 0, 0.115), 0.018, 0.016)
    builder.box((0.05, 0.02, 0.04), (0.007, 0, 0.13), COLOUR)
    for index in range(4):
        x = -0.011 + index * 0.012
        print_shapes.strut(builder, (x, 0, 0.146), (x + (index - 1.5) * 0.004, -0.014, 0.188), 0.009)
    print_shapes.strut(builder, (-0.016, 0, 0.122), (-0.042, -0.008, 0.148), 0.009)


def _monster_tooth_necklace(builder):
    """Curved fang lying flat, with a cap and a loop for the cord at the root."""
    print_shapes.limb(builder, (-0.03, 0, 0.012), (0.012, 0, 0.012), 0.012, 0.009)
    print_shapes.limb(builder, (0.01, 0, 0.011), (0.046, 0.014, 0.008), 0.009, 0.002)
    builder.cylinder(0.014, 0.012, (-0.034, 0, 0.014), COLOUR, segments=6, axis="X")
    builder.box((0.01, 0.022, 0.006), (-0.045, 0, 0.014), COLOUR)


# Bonfire Night

def _guy_fawkes_mask(builder):
    """Upright oval mask with brows, a long nose, an upturned moustache and a pointed beard."""
    builder.ball(0.085, (0, 0, 0.085), COLOUR, scale=(0.78, 0.3, 1.0))
    for side in (-1, 1):
        print_shapes.strut(builder, (side * 0.012, -0.03, 0.118), (side * 0.048, -0.022, 0.13), 0.012)
        print_shapes.strut(builder, (side * 0.004, -0.031, 0.06), (side * 0.05, -0.022, 0.082), 0.012)
    builder.box((0.014, 0.026, 0.036), (0, -0.032, 0.09), COLOUR)
    builder.box((0.014, 0.014, 0.04), (0, -0.024, 0.03), COLOUR)


# Christmas

def _reindeer_figurine(builder):
    """Reindeer standing side on: long legs, raised neck and head, and a pair of branching antlers."""
    builder.box((0.11, 0.045, 0.05), (0, 0, 0.1), COLOUR, taper=(0.9, 0.75))
    for x, y in print_shapes.grid(2, 2, 0.08, 0.026):
        builder.box((0.012, 0.012, 0.08), (x, y, 0.04), COLOUR)
    print_shapes.strut(builder, (-0.045, 0, 0.11), (-0.075, 0, 0.165), 0.022)
    builder.box((0.045, 0.034, 0.032), (-0.09, 0, 0.178), COLOUR)
    builder.box((0.02, 0.02, 0.016), (-0.12, 0, 0.172), COLOUR)
    for side in (-1, 1):
        print_shapes.strut(builder, (-0.078, side * 0.012, 0.19), (-0.066, side * 0.03, 0.24), 0.007)
        print_shapes.strut(builder, (-0.07, side * 0.022, 0.215), (-0.092, side * 0.036, 0.236), 0.006)
    builder.box((0.012, 0.012, 0.016), (0.058, 0, 0.118), COLOUR)


def _christmas_cookie_cutters_x6(builder):
    """Six open cutters: star, tree, bell, stocking, bauble and snowflake."""
    _cutters(builder, [_star(5, 0.038, 0.017), TREE, BELL, STOCKING, _ngon(6, 0.032), _ngon(4, 0.036)])


def _candle_arch(builder):
    """Window arch on a long base: a half ring of blocks with five candles on top and a tree inside."""
    builder.box((0.28, 0.05, 0.016), (0, 0, 0.008), COLOUR, bevel=0.004)
    for index in range(7):
        angle = math.radians((index + 0.5) * 180 / 7)
        builder.box(
            (0.056, 0.03, 0.02), (0.115 * math.cos(angle), 0, 0.014 + 0.115 * math.sin(angle)), COLOUR,
            rotation=(0, -(angle + math.pi / 2), 0))
        if 0 < index < 6:
            builder.box((0.012, 0.012, 0.03), (0.135 * math.cos(angle), 0, 0.022 + 0.135 * math.sin(angle)), COLOUR)
    builder.box((0.06, 0.02, 0.075), (0, 0, 0.052), COLOUR, taper=(0.05, 1.0))


def _snow_globe_base(builder):
    """Round stepped plinth with a raised rim for the globe and a wind-up key at the back."""
    builder.cylinder(0.082, 0.03, (0, 0, 0.015), COLOUR, segments=8, radius_top=0.072)
    builder.cylinder(0.066, 0.012, (0, 0, 0.036), COLOUR, segments=8)
    builder.shell(0.06, 0.012, 0.007, COLOUR, segments=8, centre=(0, 0, 0.04), open_base=True)
    builder.box((0.03, 0.014, 0.018), (0, 0.08, 0.015), COLOUR)


def _christmas_lithophane(builder):
    """Upright picture panel on a base bar, with a raised Christmas tree on the front."""
    builder.box((0.2, 0.055, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    builder.box((0.17, 0.008, 0.14), (0, 0.004, 0.082), COLOUR)
    builder.box((0.014, 0.006, 0.02), (0, -0.003, 0.034), COLOUR)
    builder.box((0.08, 0.006, 0.05), (0, -0.003, 0.068), COLOUR, taper=(0.1, 1.0))
    builder.box((0.056, 0.006, 0.045), (0, -0.003, 0.108), COLOUR, taper=(0.05, 1.0))


# Valentine's Day

def _heart_lithophane(builder):
    """Upright heart-shaped panel rising out of a base bar."""
    builder.box((0.13, 0.05, 0.016), (0, 0, 0.008), COLOUR, bevel=0.004)
    builder.box((0.09, 0.01, 0.09), (0, 0, 0.076), COLOUR, rotation=(0, math.pi / 4, 0))
    for side in (-1, 1):
        builder.cylinder(0.045, 0.01, (side * 0.0318, 0, 0.1078), COLOUR, segments=8, axis="Y")


# Easter

def _easter_cookie_cutters_x5(builder):
    """Five open cutters: egg, rabbit, chick, carrot and flower."""
    _cutters(builder, [EGG, BUNNY, _ngon(6, 0.032), CARROT, _ngon(5, 0.034, turn=math.pi / 2)])


# Mother's Day

def _photo_lithophane_frame(builder):
    """Picture panel in a chunky frame, propped up by a strut at the back."""
    builder.box((0.15, 0.006, 0.12), (0, 0, 0.073), COLOUR)
    for z in (0.008, 0.138):
        builder.box((0.18, 0.014, 0.016), (0, 0, z), COLOUR)
    for side in (-1, 1):
        builder.box((0.016, 0.014, 0.146), (side * 0.082, 0, 0.073), COLOUR)
    print_shapes.strut(builder, (0, 0.004, 0.1), (0, 0.07, 0.007), 0.012)


# Back to school

def _locker_shelf(builder):
    """Free-standing shelf: a wide top on two side panels with a brace across the back."""
    builder.box((0.28, 0.18, 0.012), (0, 0, 0.124), COLOUR, bevel=0.004)
    for side in (-1, 1):
        builder.box((0.012, 0.18, 0.12), (side * 0.13, 0, 0.06), COLOUR)
    builder.box((0.25, 0.01, 0.03), (0, 0.08, 0.1), COLOUR)


def _protractor_and_compass_set(builder):
    """Flat set as it comes off the bed: a half-round protractor, a set square and a pair of compasses."""
    arc = [(0.06 * math.cos(math.pi * index / 6), 0.06 * math.sin(math.pi * index / 6)) for index in range(7)]
    builder.plate(arc, 0.005, COLOUR, centre=(-0.035, 0.005, 0))
    builder.plate([(0, 0), (0.085, 0), (0, 0.055)], 0.005, COLOUR, centre=(-0.095, -0.065, 0))
    hinge = (0.075, 0.06, 0.006)
    for foot in ((0.045, -0.06, 0.004), (0.1, -0.055, 0.004)):
        print_shapes.strut(builder, hinge, foot, 0.008)
    builder.cylinder(0.01, 0.012, hinge, COLOUR, segments=6)


VARIANTS = {
    "skull_candle_holder": _skull_candle_holder,
    "bat_garland_x10": _bat_garland_x10,
    "spider_web_wall_decor": _spider_web_wall_decor,
    "witch_hat": _witch_hat,
    "tombstone_set_x3": _tombstone_set_x3,
    "skeleton_hand_bowl": _skeleton_hand_bowl,
    "halloween_cookie_cutters_x5": _halloween_cookie_cutters_x5,
    "crow_figurine": _crow_figurine,
    "zombie_hand_garden_stake": _zombie_hand_garden_stake,
    "monster_tooth_necklace": _monster_tooth_necklace,
    "guy_fawkes_mask": _guy_fawkes_mask,
    "reindeer_figurine": _reindeer_figurine,
    "christmas_cookie_cutters_x6": _christmas_cookie_cutters_x6,
    "candle_arch": _candle_arch,
    "snow_globe_base": _snow_globe_base,
    "christmas_lithophane": _christmas_lithophane,
    "heart_lithophane": _heart_lithophane,
    "easter_cookie_cutters_x5": _easter_cookie_cutters_x5,
    "photo_lithophane_frame": _photo_lithophane_frame,
    "locker_shelf": _locker_shelf,
    "protractor_and_compass_set": _protractor_and_compass_set,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
