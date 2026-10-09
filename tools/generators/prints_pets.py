"""Printed item generator for the Pets category (Spare room tier).

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_pets.py -- \
    --variant hamster_hideout --out assets/models/prints/hamster_hideout.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
import print_shapes
from common import MeshBuilder
from print_shapes import COLOUR

BONE = [(-0.028, -0.006), (0.028, -0.006), (0.034, -0.015), (0.046, -0.011), (0.042, 0.0), (0.046, 0.011), (0.034, 0.015),
        (0.028, 0.006), (-0.028, 0.006), (-0.034, 0.015), (-0.046, 0.011), (-0.042, 0.0), (-0.046, -0.011), (-0.034, -0.015)]


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), required=True)


def build(args, rng):
    builder = MeshBuilder(material=common.TINT_MATERIAL_NAME)
    VARIANTS[args.variant](builder)
    builder.finish(args.out.stem)


def _dog_bowl_stand(builder):
    """Raised feeding stand: two rings for the bowls joined by rails, on four legs."""
    for side in (-1, 1):
        builder.shell(0.062, 0.02, 0.01, COLOUR, segments=8, centre=(side * 0.068, 0, 0.09), turn=math.pi / 8, open_base=True)
        builder.box((0.26, 0.012, 0.02), (0, side * 0.056, 0.1), COLOUR)
    for x, y in print_shapes.grid(2, 2, 0.25, 0.1):
        builder.box((0.016, 0.016, 0.1), (x, y, 0.05), COLOUR)


def _cat_scratcher_frame(builder):
    """Wide base with a tall square post, a platform on top and a toy ball hanging off one corner."""
    builder.box((0.26, 0.2, 0.016), (0, 0, 0.008), COLOUR, bevel=0.004)
    builder.box((0.05, 0.05, 0.25), (-0.03, 0, 0.139), COLOUR)
    builder.box((0.15, 0.14, 0.014), (-0.01, 0, 0.271), COLOUR)
    print_shapes.strut(builder, (0.06, -0.06, 0.265), (0.085, -0.075, 0.2), 0.006)
    builder.ball(0.018, (0.087, -0.076, 0.185), COLOUR, subdivisions=1)


def _bird_perch(builder):
    """Branch-like rod with a side twig, fixed to a round clamp plate that grips the cage bars."""
    builder.cylinder(0.03, 0.01, (0, 0.06, 0.03), COLOUR, segments=8, axis="Y")
    builder.box((0.02, 0.012, 0.02), (0, 0.072, 0.03), COLOUR)
    print_shapes.limb(builder, (0, 0.06, 0.03), (0, -0.08, 0.03), 0.01, 0.007)
    print_shapes.limb(builder, (0, -0.01, 0.03), (0.035, -0.045, 0.045), 0.006, 0.003)


def _aquarium_decoration_castle(builder):
    """Little castle on a rock: two round towers with pointed roofs and a battlement wall between them."""
    builder.box((0.19, 0.1, 0.03), (0, 0, 0.015), COLOUR, bevel=0.01)
    for x, height in ((-0.06, 0.1), (0.06, 0.075)):
        builder.cylinder(0.03, height, (x, 0, 0.025 + height / 2), COLOUR, segments=8)
        builder.cylinder(0.036, 0.045, (x, 0, 0.047 + height), COLOUR, segments=8, radius_top=0.003)
    builder.box((0.08, 0.03, 0.055), (0, 0, 0.055), COLOUR)
    for x in (-0.026, 0.0, 0.026):
        builder.box((0.014, 0.03, 0.012), (x, 0, 0.088), COLOUR)


def _aquarium_plant_anchor_x6(builder):
    """Six five-sided weighted rings in two rows, to hold plant stems down."""
    for x, y in print_shapes.grid(3, 2, 0.045, 0.045):
        builder.shell(0.02, 0.012, 0.007, COLOUR, segments=5, centre=(x, y, 0), turn=math.pi / 2, open_base=True)


def _hamster_hideout(builder):
    """Small house with a pitched roof, a chimney and a porch round the doorway."""
    builder.outline([(-0.07, -0.05), (0.07, -0.05), (0.07, 0.05), (-0.07, 0.05)], 0.07, 0.008, COLOUR)
    for side in (-1, 1):
        builder.box((0.095, 0.12, 0.01), (side * 0.04, 0, 0.09), COLOUR, rotation=(0, side * math.radians(28), 0))
    builder.box((0.02, 0.02, 0.04), (0.035, 0.02, 0.105), COLOUR)
    builder.box((0.05, 0.016, 0.05), (0, -0.054, 0.025), COLOUR, taper=(0.6, 1.0))


def _treat_dispenser_puzzle(builder):
    """Round puzzle board with six sliding covers round a central knob."""
    builder.cylinder(0.105, 0.016, (0, 0, 0.008), COLOUR, segments=12)
    for index in range(6):
        angle = math.tau * index / 6
        builder.box((0.04, 0.03, 0.01), (0.068 * math.cos(angle), 0.068 * math.sin(angle), 0.021), COLOUR, rotation=(0, 0, angle))
    builder.cylinder(0.024, 0.02, (0, 0, 0.026), COLOUR, segments=8, radius_top=0.018)


def _lead_hook_wall_rack(builder):
    """Bone-shaped wall plate standing on its edge with three hooks along the front."""
    builder.box((0.19, 0.012, 0.045), (0, 0.02, 0.04), COLOUR)
    for x, z in print_shapes.grid(2, 2, 0.2, 0.034):
        builder.cylinder(0.023, 0.012, (x, 0.02, 0.04 + z), COLOUR, segments=6, axis="Y")
    for x, _ in print_shapes.grid(3, 1, 0.06, 0):
        builder.box((0.014, 0.034, 0.012), (x, -0.002, 0.028), COLOUR)
        builder.box((0.014, 0.012, 0.028), (x, -0.016, 0.036), COLOUR)


def _poop_bag_dispenser(builder):
    """Capsule that holds a roll of bags, with a clip loop on top and a slot down the front."""
    builder.cylinder(0.018, 0.012, (0, 0, 0.006), COLOUR, segments=8, radius_top=0.024)
    builder.cylinder(0.024, 0.06, (0, 0, 0.042), COLOUR, segments=8)
    builder.cylinder(0.024, 0.012, (0, 0, 0.078), COLOUR, segments=8, radius_top=0.016)
    builder.box((0.006, 0.006, 0.05), (0, -0.024, 0.042), COLOUR)
    for side in (-1, 1):
        builder.box((0.006, 0.01, 0.022), (side * 0.009, 0, 0.094), COLOUR)
    builder.box((0.024, 0.01, 0.006), (0, 0, 0.106), COLOUR)
    builder.enlarge(1.2)


def _pet_bowl_anti_slip_feet_x4(builder):
    """Four square rubber feet with rounded edges."""
    for x, y in print_shapes.grid(2, 2, 0.045, 0.045):
        builder.box((0.034, 0.034, 0.01), (x, y, 0.005), COLOUR, bevel=0.003)


def _collar_charm(builder):
    """Flat bone-shaped tag with a ring to hang it from the collar."""
    builder.plate(BONE, 0.005, COLOUR)
    builder.shell(0.01, 0.005, 0.004, COLOUR, segments=6, centre=(0, 0.014, 0), open_base=True)
    builder.enlarge(1.3)


def _cat_window_perch_brackets(builder):
    """Pair of triangular brackets, each with two suction cups down the upright."""
    for side in (-1, 1):
        x = side * 0.07
        builder.box((0.016, 0.016, 0.16), (x, 0.06, 0.08), COLOUR)
        builder.box((0.016, 0.14, 0.016), (x, -0.002, 0.152), COLOUR)
        print_shapes.strut(builder, (x, 0.056, 0.02), (x, -0.06, 0.148), 0.014)
        for z in (0.035, 0.12):
            builder.cylinder(0.022, 0.008, (x, 0.072, z), COLOUR, segments=8, axis="Y")


def _reptile_hide_rock(builder):
    """Low faceted rock with an arched entrance at the front."""
    builder.cylinder(0.125, 0.06, (0, 0.01, 0.03), COLOUR, segments=7, radius_top=0.085, rotation=(0, 0, 0.3))
    builder.cylinder(0.085, 0.03, (0.008, 0.016, 0.075), COLOUR, segments=6, radius_top=0.04, rotation=(0, 0, 0.9))
    print_shapes.hoop(builder, 0.034, 0.014, 0.03, (0, -0.105, 0.006), pieces=4, start=0.0, sweep=math.pi)


VARIANTS = {
    "dog_bowl_stand": _dog_bowl_stand,
    "cat_scratcher_frame": _cat_scratcher_frame,
    "bird_perch": _bird_perch,
    "aquarium_decoration_castle": _aquarium_decoration_castle,
    "aquarium_plant_anchor_x6": _aquarium_plant_anchor_x6,
    "hamster_hideout": _hamster_hideout,
    "treat_dispenser_puzzle": _treat_dispenser_puzzle,
    "lead_hook_wall_rack": _lead_hook_wall_rack,
    "poop_bag_dispenser": _poop_bag_dispenser,
    "pet_bowl_anti_slip_feet_x4": _pet_bowl_anti_slip_feet_x4,
    "collar_charm": _collar_charm,
    "cat_window_perch_brackets": _cat_window_perch_brackets,
    "reptile_hide_rock": _reptile_hide_rock,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
