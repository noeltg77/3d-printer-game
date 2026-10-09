"""Printed item generator for the Home decor category.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_decor.py -- \
    --variant moon_lamp --out assets/models/prints/moon_lamp.glb
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


def _low_poly_planter(builder):
    """Five-sided faceted pot, wider at the rim."""
    builder.shell(0.052, 0.11, 0.009, COLOUR, segments=5, radius_top=0.085, chamfer=0.005, turn=math.pi / 2)


def _lithophane_photo_panel(builder):
    """Thin upright picture panel held between two posts on a base bar."""
    builder.box((0.21, 0.055, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    builder.box((0.18, 0.006, 0.13), (0, 0, 0.077), COLOUR)
    for side in (-1, 1):
        builder.box((0.012, 0.016, 0.14), (side * 0.094, 0, 0.082), COLOUR)


def _lithophane_lamp(builder):
    """Round lamp: a wide base, a tall thin picture sleeve and a cap."""
    builder.cylinder(0.075, 0.03, (0, 0, 0.015), COLOUR, segments=10, radius_top=0.068)
    builder.cylinder(0.06, 0.15, (0, 0, 0.105), COLOUR, segments=10)
    builder.cylinder(0.066, 0.014, (0, 0, 0.187), COLOUR, segments=10, radius_top=0.058)


def _moon_lamp(builder):
    """Faceted globe sitting in a small tapered stand."""
    builder.cylinder(0.055, 0.035, (0, 0, 0.0175), COLOUR, segments=6, radius_top=0.036)
    builder.ball(0.085, (0, 0, 0.112), COLOUR)


def _tea_light_lantern(builder):
    """Square lantern: base, four corner posts, a pyramid roof and a knob."""
    builder.box((0.11, 0.11, 0.016), (0, 0, 0.008), COLOUR, bevel=0.004)
    for x, y in print_shapes.grid(2, 2, 0.086, 0.086):
        builder.box((0.012, 0.012, 0.1), (x, y, 0.064), COLOUR)
    builder.box((0.11, 0.11, 0.01), (0, 0, 0.117), COLOUR)
    builder.cylinder(0.082, 0.05, (0, 0, 0.147), COLOUR, segments=4, radius_top=0.014, rotation=(0, 0, math.pi / 4))
    builder.box((0.02, 0.02, 0.016), (0, 0, 0.178), COLOUR)


def _air_plant_holder_x3(builder):
    """Three small faceted cups of different shapes and sizes."""
    for x, y, sides, radius, height in ((-0.06, 0.0, 3, 0.03, 0.04), (0.0, 0.015, 5, 0.026, 0.05), (0.058, -0.005, 4, 0.026, 0.035)):
        builder.shell(radius * 0.6, height, 0.005, COLOUR, segments=sides, centre=(x, y, 0), radius_top=radius, turn=math.pi / 2)


def _bust_sculpture_classical(builder):
    """Head and shoulders on a square plinth."""
    builder.box((0.1, 0.09, 0.05), (0, 0, 0.025), COLOUR, bevel=0.005)
    builder.box((0.15, 0.075, 0.065), (0, 0, 0.08), COLOUR, taper=(0.45, 0.75))
    builder.cylinder(0.022, 0.04, (0, 0, 0.125), COLOUR, segments=6)
    builder.ball(0.05, (0, -0.004, 0.185), COLOUR, scale=(0.85, 0.95, 1.12))
    builder.box((0.014, 0.022, 0.026), (0, -0.05, 0.18), COLOUR, taper=(0.6, 0.3))


def _low_poly_animal_figurine(builder):
    """Faceted fox standing side on: body, four legs, head with snout and pointed ears, and a tail."""
    builder.box((0.13, 0.05, 0.05), (0.005, 0, 0.07), COLOUR, taper=(0.85, 0.7))
    for x, y in print_shapes.grid(2, 2, 0.09, 0.03):
        builder.box((0.016, 0.014, 0.05), (x + 0.005, y, 0.025), COLOUR)
    builder.box((0.05, 0.048, 0.046), (-0.078, 0, 0.108), COLOUR, taper=(0.7, 0.7))
    builder.box((0.04, 0.024, 0.02), (-0.115, 0, 0.098), COLOUR, taper=(0.6, 0.6))
    for side in (-1, 1):
        builder.box((0.012, 0.016, 0.028), (-0.066, side * 0.015, 0.143), COLOUR, taper=0.1)
    print_shapes.limb(builder, (0.065, 0, 0.08), (0.14, 0, 0.115), 0.016, 0.004)


def _wall_shelf_hexagon(builder):
    """Hexagonal frame standing on one flat side, with a shelf across the middle."""
    corner, depth, thick = 0.13, 0.09, 0.012
    inner = corner * math.cos(math.pi / 6) - thick / 2
    for index in range(6):
        angle = -math.pi / 2 + index * math.pi / 3
        builder.box(
            (corner, depth, thick), (inner * math.cos(angle), 0, inner * math.sin(angle) + inner + thick / 2),
            COLOUR, rotation=(0, -(angle + math.pi / 2), 0))
    builder.box((corner * 1.85, depth, 0.01), (0, 0, inner + thick / 2), COLOUR)


def _plant_mister_holder(builder):
    """Wall plate with a ring sticking out for the bottle to drop into, and a strut under it."""
    builder.box((0.075, 0.01, 0.11), (0, 0.04, 0.055), COLOUR)
    builder.shell(0.042, 0.014, 0.007, COLOUR, segments=8, centre=(0, -0.002, 0.07), turn=math.pi / 8, open_base=True)
    print_shapes.strut(builder, (0, 0.036, 0.02), (0, -0.01, 0.07), 0.01)


def _curtain_tie_backs_pair(builder):
    """Two wall hooks: a round plate with an arm that reaches forward and curls up to a knob."""
    for x in (-0.05, 0.05):
        builder.cylinder(0.036, 0.01, (x, 0.04, 0.036), COLOUR, segments=8, axis="Y")
        points = [(x, 0.04, 0.04), (x, -0.02, 0.03), (x, -0.05, 0.055), (x, -0.055, 0.09)]
        for start, end in zip(points, points[1:]):
            print_shapes.limb(builder, start, end, 0.01)
        builder.ball(0.016, points[-1], COLOUR, subdivisions=1)


def _light_switch_cover(builder):
    """Flat square plate with a tilted rocker in the middle and two screw heads."""
    builder.box((0.12, 0.12, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    builder.box((0.034, 0.05, 0.012), (0, 0, 0.015), COLOUR, rotation=(math.radians(8), 0, 0))
    for side in (-1, 1):
        builder.cylinder(0.007, 0.004, (side * 0.04, 0, 0.013), COLOUR, segments=6)


# Home decor, Spare room tier

def _vase_mode_vase_tall(builder):
    """Tall vase: a body that swells out, draws in at the shoulder and opens again at the neck."""
    builder.cylinder(0.04, 0.1, (0, 0, 0.05), COLOUR, segments=10, radius_top=0.062)
    builder.cylinder(0.062, 0.08, (0, 0, 0.14), COLOUR, segments=10, radius_top=0.034)
    builder.shell(0.034, 0.07, 0.005, COLOUR, segments=10, centre=(0, 0, 0.176), radius_top=0.048, open_base=True)


def _self_watering_mini_planter(builder):
    """Square reservoir with a taller square pot sitting in it and a filling spout at one corner."""
    builder.tray((0.12, 0.12, 0.05), 0.007, COLOUR, chamfer=0.004)
    builder.tray((0.092, 0.092, 0.085), 0.006, COLOUR, centre=(0, 0, 0.022), taper=0.008)
    builder.box((0.026, 0.026, 0.04), (0.055, -0.055, 0.04), COLOUR, rotation=(0, 0, math.pi / 4))


def _low_poly_animal_head_wall(builder):
    """Stag's head on a shield-shaped wall plaque: neck, head, muzzle, ears and branching antlers."""
    builder.plate([(-0.07, 0.07), (0, 0.0), (0.07, 0.07), (0.07, 0.2), (-0.07, 0.2)], 0.012, COLOUR, centre=(0, 0.07, 0), upright=True)
    print_shapes.limb(builder, (0, 0.064, 0.1), (0, 0.0, 0.15), 0.034, 0.026, segments=6)
    builder.box((0.05, 0.06, 0.05), (0, -0.02, 0.165), COLOUR, taper=(0.8, 0.8))
    builder.box((0.028, 0.045, 0.026), (0, -0.065, 0.152), COLOUR, taper=(0.8, 0.8))
    for side in (-1, 1):
        builder.box((0.02, 0.008, 0.03), (side * 0.034, -0.005, 0.185), COLOUR, taper=0.2)
        print_shapes.strut(builder, (side * 0.016, -0.005, 0.185), (side * 0.07, 0.01, 0.26), 0.009)
        print_shapes.strut(builder, (side * 0.045, 0.003, 0.225), (side * 0.035, -0.03, 0.262), 0.007)
        print_shapes.strut(builder, (side * 0.062, 0.008, 0.248), (side * 0.105, 0.0, 0.272), 0.007)


def _candle_holder(builder):
    """Candlestick: a wide foot, a slim stem, a drip tray and a cup for the candle."""
    builder.cylinder(0.055, 0.014, (0, 0, 0.007), COLOUR, segments=10, radius_top=0.045)
    builder.cylinder(0.014, 0.09, (0, 0, 0.058), COLOUR, segments=8, radius_top=0.01)
    builder.cylinder(0.04, 0.008, (0, 0, 0.106), COLOUR, segments=10)
    builder.shell(0.022, 0.03, 0.005, COLOUR, segments=8, centre=(0, 0, 0.108))


def _picture_frame(builder):
    """Standing picture frame with a block at each corner and a prop behind."""
    builder.box((0.15, 0.006, 0.11), (0, 0, 0.073), COLOUR)
    for z in (0.009, 0.137):
        builder.box((0.17, 0.014, 0.018), (0, 0, z), COLOUR)
    for side in (-1, 1):
        builder.box((0.018, 0.014, 0.146), (side * 0.085, 0, 0.073), COLOUR)
        for z in (0.011, 0.135):
            builder.box((0.026, 0.02, 0.026), (side * 0.085, 0, z + 0.002), COLOUR)
    print_shapes.strut(builder, (0, 0.004, 0.1), (0, 0.07, 0.007), 0.012)


def _mirror_frame(builder):
    """Round frame standing on two feet, with a flat back for the mirror glass."""
    print_shapes.hoop(builder, 0.11, 0.022, 0.022, (0, 0, 0.126), pieces=10)
    builder.cylinder(0.105, 0.006, (0, 0.006, 0.126), COLOUR, segments=10, axis="Y")
    for side in (-1, 1):
        builder.box((0.03, 0.08, 0.012), (side * 0.05, 0, 0.006), COLOUR)


def _trinket_dish(builder):
    """Shallow seven-sided dish that flares from a small foot."""
    builder.shell(0.04, 0.026, 0.006, COLOUR, segments=7, radius_top=0.068, chamfer=0.003)


def _bud_vase_set_x3(builder):
    """Three small vases for single stems: a squat one, a tall one and a cone, each with an open neck."""
    for x, low, high, height in ((-0.06, 0.03, 0.02, 0.045), (0.0, 0.02, 0.026, 0.085), (0.06, 0.032, 0.012, 0.06)):
        builder.cylinder(low, height, (x, 0, height / 2), COLOUR, segments=6, radius_top=high)
        builder.shell(min(high, 0.016), 0.03, 0.004, COLOUR, segments=6, centre=(x, 0, height - 0.004), radius_top=0.016, open_base=True)


def _hanging_lamp_shade(builder):
    """Large pendant shade in three stepped tiers under a collar for the fitting."""
    builder.cylinder(0.14, 0.05, (0, 0, 0.025), COLOUR, segments=10, radius_top=0.12)
    builder.cylinder(0.11, 0.05, (0, 0, 0.07), COLOUR, segments=10, radius_top=0.085)
    builder.cylinder(0.075, 0.045, (0, 0, 0.115), COLOUR, segments=10, radius_top=0.045)
    builder.cylinder(0.028, 0.03, (0, 0, 0.15), COLOUR, segments=8)


def _incense_holder(builder):
    """Long narrow ash tray with a raised block at one end that holds the stick."""
    builder.tray((0.2, 0.04, 0.012), 0.005, COLOUR, floor=0.005)
    builder.box((0.022, 0.03, 0.022), (-0.085, 0, 0.011), COLOUR, taper=(0.5, 0.8))


def _door_stop(builder):
    """Plain wedge with grip ridges across the slope."""
    builder.plate([(-0.085, 0.0), (0.085, 0.0), (0.085, 0.048), (-0.085, 0.006)], 0.055, COLOUR, upright=True)
    for x, z in ((-0.03, 0.021), (0.01, 0.031), (0.05, 0.041)):
        builder.box((0.008, 0.055, 0.006), (x, 0, z), COLOUR, rotation=(0, math.radians(-14), 0))


def _window_plant_shelf(builder):
    """Shelf with a front rail, held up by a braced bracket at each end."""
    builder.box((0.28, 0.11, 0.012), (0, 0, 0.114), COLOUR, bevel=0.004)
    builder.box((0.28, 0.008, 0.02), (0, -0.051, 0.13), COLOUR)
    for side in (-1, 1):
        builder.box((0.014, 0.014, 0.11), (side * 0.11, 0.045, 0.055), COLOUR)
        print_shapes.strut(builder, (side * 0.11, 0.045, 0.012), (side * 0.11, -0.04, 0.108), 0.012)


VARIANTS = {
    "low_poly_planter": _low_poly_planter,
    "lithophane_photo_panel": _lithophane_photo_panel,
    "lithophane_lamp": _lithophane_lamp,
    "moon_lamp": _moon_lamp,
    "tea_light_lantern": _tea_light_lantern,
    "air_plant_holder_x3": _air_plant_holder_x3,
    "bust_sculpture_classical": _bust_sculpture_classical,
    "low_poly_animal_figurine": _low_poly_animal_figurine,
    "wall_shelf_hexagon": _wall_shelf_hexagon,
    "plant_mister_holder": _plant_mister_holder,
    "curtain_tie_backs_pair": _curtain_tie_backs_pair,
    "light_switch_cover": _light_switch_cover,
    "vase_mode_vase_tall": _vase_mode_vase_tall,
    "self_watering_mini_planter": _self_watering_mini_planter,
    "low_poly_animal_head_wall": _low_poly_animal_head_wall,
    "candle_holder": _candle_holder,
    "picture_frame": _picture_frame,
    "mirror_frame": _mirror_frame,
    "trinket_dish": _trinket_dish,
    "bud_vase_set_x3": _bud_vase_set_x3,
    "hanging_lamp_shade": _hanging_lamp_shade,
    "incense_holder": _incense_holder,
    "door_stop": _door_stop,
    "window_plant_shelf": _window_plant_shelf,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
