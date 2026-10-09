"""Printed item generator for the Kitchen category.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_kitchen.py -- \
    --variant utensil_holder --out assets/models/prints/utensil_holder.glb
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


def _cookie_cutter_set_x6(builder):
    """Six open cutters in two rows, each a different outline."""
    outlines = ((3, math.pi / 2), (4, math.pi / 4), (5, math.pi / 2), (6, 0.0), (8, 0.0), (4, 0.0))
    for (x, y), (sides, turn) in zip(print_shapes.grid(3, 2, 0.075, 0.075), outlines):
        builder.shell(0.034, 0.026, 0.004, COLOUR, segments=sides, centre=(x, y, 0), turn=turn, open_base=True)


def _herb_stripper(builder):
    """Flat hand-sized plate with a row of raised stripping holes, small to large."""
    builder.box((0.17, 0.065, 0.007), (0, 0, 0.0035), COLOUR, bevel=0.003)
    for x, radius in ((-0.058, 0.007), (-0.03, 0.01), (0.005, 0.013), (0.048, 0.017)):
        builder.shell(radius + 0.004, 0.011, 0.004, COLOUR, segments=6, centre=(x, 0, 0), floor=0.004)


def _bag_sealing_clips_x8(builder):
    """Eight slide-on sealing sticks side by side, each with a grip block at one end."""
    for x, _ in print_shapes.grid(8, 1, 0.024, 0):
        builder.box((0.012, 0.13, 0.012), (x, 0, 0.006), COLOUR)
        builder.box((0.018, 0.022, 0.02), (x, 0.054, 0.01), COLOUR)


def _spice_rack_insert(builder):
    """Three steps rising to the back, each with a lip along its front edge."""
    print_shapes.stepped_rack(builder, 0.28, 3, 0.06, 0.03, 0.035)


def _tea_bag_caddy(builder):
    """Deep box split into six pockets for tea bags."""
    print_shapes.divided_tray(builder, (0.2, 0.14, 0.08), 0.008, across=2, along=1, chamfer=0.005)


def _coffee_scoop(builder):
    """Round measuring cup with a long flat handle."""
    builder.shell(0.03, 0.032, 0.005, COLOUR, segments=8, centre=(0, 0.04, 0))
    builder.box((0.016, 0.1, 0.007), (0, -0.03, 0.0285), COLOUR)


def _coffee_pod_holder(builder):
    """Two tall open towers on a wide base that pods stack inside."""
    builder.box((0.22, 0.13, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    for side in (-1, 1):
        builder.tray((0.08, 0.08, 0.22), 0.007, COLOUR, centre=(side * 0.05, 0, 0.012), chamfer=0.004)


def _recipe_card_stand(builder):
    """Small upright easel for a recipe card."""
    print_shapes.easel(builder, 0.13, 0.1, 0.09, lean=15.0, lip=0.018, base=0.012, panel=0.012)


def _utensil_holder(builder):
    """Tall round pot, slightly wider at the rim."""
    builder.shell(0.068, 0.17, 0.009, COLOUR, segments=10, radius_top=0.078, chamfer=0.005)


def _cake_topper_custom_text(builder):
    """Flat banner with raised letters and two stakes, as it comes off the bed."""
    builder.box((0.18, 0.05, 0.005), (0, 0.035, 0.0025), COLOUR)
    for side in (-1, 1):
        builder.box((0.008, 0.08, 0.005), (side * 0.06, -0.03, 0.0025), COLOUR)
    for x, _ in print_shapes.grid(5, 1, 0.032, 0):
        builder.box((0.022, 0.03, 0.006), (x, 0.035, 0.008), COLOUR)


def _napkin_holder(builder):
    """Two tall upright panels on a narrow base."""
    print_shapes.slot_rack(builder, 0.17, 0.08, (0.12, 0.12), lean=0.0)


def _fruit_bowl_low_poly(builder):
    """Wide faceted bowl flaring out from a small foot."""
    builder.shell(0.06, 0.1, 0.01, COLOUR, segments=7, radius_top=0.145, chamfer=0.004)


def _wine_bottle_holder(builder):
    """Long base with two V cradles, a big one for the body and a small one for the neck."""
    builder.box((0.26, 0.12, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    for x, scale in ((-0.07, 1.0), (0.09, 0.65)):
        for side in (-1, 1):
            length = 0.09 * scale
            builder.box(
                (0.034, 0.016, length), (x, side * (0.012 + length * 0.29), 0.012 + length * 0.41), COLOUR,
                rotation=(math.radians(-35 * side), 0, 0))


def _pasta_measure(builder):
    """Row of four joined rings, small to large, one for each number of portions."""
    edge = -0.0945
    for radius in (0.02, 0.026, 0.032, 0.038):
        # Turned so a flat side faces each neighbour; they share a wall.
        half = radius * math.cos(math.pi / 6)
        builder.shell(radius, 0.008, 0.005, COLOUR, segments=6, centre=(edge + half, 0, 0), turn=math.pi / 6, open_base=True)
        edge += half * 2 - 0.004


def _cookie_stamp_set(builder):
    """Three round stamps face down, each with a chunky handle."""
    for x, _ in print_shapes.grid(3, 1, 0.08, 0):
        builder.cylinder(0.034, 0.012, (x, 0, 0.006), COLOUR, segments=8)
        builder.cylinder(0.014, 0.04, (x, 0, 0.032), COLOUR, segments=6, radius_top=0.02)


def _drawer_bin_for_cutlery(builder):
    """Cutlery tray: three long lanes and one wide compartment across the back."""
    builder.tray((0.3, 0.22, 0.05), 0.008, COLOUR, chamfer=0.004)
    builder.box((0.292, 0.006, 0.046), (0, 0.05, 0.023), COLOUR)
    for x in (-0.049, 0.049):
        builder.box((0.006, 0.156, 0.046), (x, -0.028, 0.023), COLOUR)


# Kitchen, Spare room tier

def _knife_block_insert(builder):
    """Sloping block with five slots across the top, marked by raised guides."""
    builder.plate([(-0.11, 0.0), (0.11, 0.0), (0.11, 0.06), (-0.11, 0.14)], 0.11, COLOUR, upright=True)
    tilt = math.atan2(0.08, 0.22)
    for index in range(5):
        along = (index + 0.5) / 5
        builder.box((0.008, 0.09, 0.008), (-0.11 + along * 0.22, 0, 0.142 - along * 0.08), COLOUR, rotation=(0, tilt, 0))


def _pan_lid_rack(builder):
    """Two upright rails joined by four cradles, one above another, that pan lids rest in."""
    for side in (-1, 1):
        builder.box((0.014, 0.014, 0.21), (side * 0.1, 0.03, 0.105), COLOUR)
    for index in range(4):
        z = 0.02 + index * 0.05
        builder.box((0.214, 0.01, 0.01), (0, 0.03, z + 0.005), COLOUR)
        for side in (-1, 1):
            builder.box((0.01, 0.06, 0.01), (side * 0.07, 0.0, z + 0.012), COLOUR, rotation=(math.radians(-18), 0, 0))
    builder.box((0.214, 0.05, 0.01), (0, 0.012, 0.005), COLOUR)


def _sink_sponge_holder(builder):
    """Small tray for a sponge with a strap up the back that hooks over the edge of the sink."""
    builder.tray((0.12, 0.07, 0.04), 0.006, COLOUR, chamfer=0.003)
    for y in (-0.015, 0.015):
        builder.box((0.1, 0.006, 0.006), (0, y, 0.009), COLOUR)
    builder.box((0.05, 0.006, 0.06), (0, 0.038, 0.07), COLOUR)
    builder.box((0.05, 0.03, 0.006), (0, 0.05, 0.097), COLOUR)


def _bottle_opener(builder):
    """Flat opener: a ring with a lip that catches the cap, on a long handle."""
    builder.shell(0.03, 0.007, 0.009, COLOUR, segments=8, centre=(0, 0.05, 0), turn=math.pi / 8, open_base=True)
    builder.plate([(-0.012, 0.026), (-0.016, -0.07), (0.016, -0.07), (0.012, 0.026)], 0.007, COLOUR)
    builder.box((0.02, 0.008, 0.007), (0, 0.068, 0.0035), COLOUR)


def _jar_opener_grip(builder):
    """Ring with teeth round the inside that grips a jar lid, and a handle to turn it by."""
    builder.shell(0.055, 0.014, 0.008, COLOUR, segments=10, open_base=True)
    for index in range(5):
        angle = math.tau * index / 5
        builder.box((0.012, 0.008, 0.014), (0.043 * math.cos(angle), 0.043 * math.sin(angle), 0.007), COLOUR, rotation=(0, 0, angle))
    builder.box((0.03, 0.09, 0.014), (0, -0.095, 0.007), COLOUR, bevel=0.004)


def _measuring_spoon_set(builder):
    """Four measuring spoons in a row, small to large, each a five-sided bowl on a flat handle."""
    for (x, _), radius in zip(print_shapes.grid(4, 1, 0.046, 0), (0.012, 0.015, 0.018, 0.021)):
        builder.shell(radius, radius * 0.9, 0.004, COLOUR, segments=5, centre=(x, 0.035, 0), turn=math.pi / 2)
        builder.box((0.01, 0.075, 0.004), (x, -0.012, radius * 0.9 - 0.002), COLOUR)


def _cling_film_cutter(builder):
    """Long rail with a raised track along it, a slider that carries the blade and a stop at each end."""
    builder.box((0.28, 0.035, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    builder.box((0.26, 0.008, 0.006), (0, 0, 0.016), COLOUR)
    builder.box((0.03, 0.04, 0.02), (0.05, 0, 0.022), COLOUR)
    for side in (-1, 1):
        builder.box((0.012, 0.035, 0.012), (side * 0.134, 0, 0.02), COLOUR)


def _cereal_clip_with_spout(builder):
    """Wide bag clip with a round pouring spout and cap rising from the top jaw."""
    builder.box((0.12, 0.03, 0.01), (0, 0, 0.005), COLOUR)
    builder.box((0.12, 0.03, 0.01), (0, 0, 0.02), COLOUR)
    builder.box((0.12, 0.008, 0.016), (0, 0.016, 0.0125), COLOUR)
    builder.cylinder(0.018, 0.03, (0.02, 0, 0.04), COLOUR, segments=8)
    builder.cylinder(0.021, 0.01, (0.02, 0, 0.06), COLOUR, segments=8)


VARIANTS = {
    "cookie_cutter_set_x6": _cookie_cutter_set_x6,
    "herb_stripper": _herb_stripper,
    "bag_sealing_clips_x8": _bag_sealing_clips_x8,
    "spice_rack_insert": _spice_rack_insert,
    "tea_bag_caddy": _tea_bag_caddy,
    "coffee_scoop": _coffee_scoop,
    "coffee_pod_holder": _coffee_pod_holder,
    "recipe_card_stand": _recipe_card_stand,
    "utensil_holder": _utensil_holder,
    "cake_topper_custom_text": _cake_topper_custom_text,
    "napkin_holder": _napkin_holder,
    "fruit_bowl_low_poly": _fruit_bowl_low_poly,
    "wine_bottle_holder": _wine_bottle_holder,
    "pasta_measure": _pasta_measure,
    "cookie_stamp_set": _cookie_stamp_set,
    "drawer_bin_for_cutlery": _drawer_bin_for_cutlery,
    "knife_block_insert": _knife_block_insert,
    "pan_lid_rack": _pan_lid_rack,
    "sink_sponge_holder": _sink_sponge_holder,
    "bottle_opener": _bottle_opener,
    "jar_opener_grip": _jar_opener_grip,
    "measuring_spoon_set": _measuring_spoon_set,
    "cling_film_cutter": _cling_film_cutter,
    "cereal_clip_with_spout": _cereal_clip_with_spout,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
