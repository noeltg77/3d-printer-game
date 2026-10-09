"""Printed item generator for the single-colour products of the Workshop and Factory tiers.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance. Even the
biggest products here are kept within a shelf slot.

blender --background --factory-startup --python tools/generators/prints_later_tiers.py -- \
    --variant bird_house --out assets/models/prints/bird_house.glb
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


def _digit(builder, bars, x, y, z):
    """A numeral from seven-segment bars, lying flat. `bars` names the segments lit, from "abcdefg"."""
    spots = {"a": (0, 0.028, 0), "b": (0.012, 0.014, 1), "c": (0.012, -0.014, 1), "d": (0, -0.028, 0),
             "e": (-0.012, -0.014, 1), "f": (-0.012, 0.014, 1), "g": (0, 0, 0)}
    for bar in bars:
        dx, dy, upright = spots[bar]
        builder.box((0.008, 0.03, 0.006) if upright else (0.03, 0.008, 0.006), (x + dx, y + dy, z), COLOUR)


# Workshop

def _bird_house(builder):
    """Nest box with a pitched roof, a round entrance with a rim and a perch below it."""
    builder.box((0.14, 0.14, 0.01), (0, 0, 0.005), COLOUR)
    builder.box((0.12, 0.12, 0.13), (0, 0, 0.075), COLOUR)
    for side in (-1, 1):
        builder.box((0.1, 0.15, 0.012), (side * 0.036, 0, 0.165), COLOUR, rotation=(0, side * math.radians(35), 0))
    builder.cylinder(0.026, 0.012, (0, -0.062, 0.095), COLOUR, segments=8, axis="Y")
    print_shapes.limb(builder, (0, -0.06, 0.05), (0, -0.095, 0.05), 0.007)


def _gate_latch(builder):
    """Latch lying flat: a backplate, a bar that swings on a pivot, a keeper it drops into and a thumb lever."""
    builder.box((0.09, 0.05, 0.008), (-0.045, 0, 0.004), COLOUR, bevel=0.003)
    builder.box((0.14, 0.018, 0.01), (0.0, 0, 0.013), COLOUR)
    builder.cylinder(0.012, 0.014, (-0.06, 0, 0.015), COLOUR, segments=6)
    builder.box((0.03, 0.05, 0.008), (0.08, 0, 0.004), COLOUR)
    for y in (-0.016, 0.016):
        builder.box((0.014, 0.008, 0.02), (0.08, y, 0.016), COLOUR)
    builder.box((0.012, 0.012, 0.022), (0.02, 0, 0.028), COLOUR)


def _fence_post_cap_x4(builder):
    """Four post caps: a square skirt under a low pyramid."""
    for x, y in print_shapes.grid(2, 2, 0.075, 0.075):
        builder.box((0.06, 0.06, 0.02), (x, y, 0.01), COLOUR)
        builder.cylinder(0.05, 0.03, (x, y, 0.035), COLOUR, segments=4, radius_top=0.004, rotation=(0, 0, math.pi / 4))


def _outdoor_thermometer_housing(builder):
    """Louvred weather box: a stack of sloping slats between four corner posts, under a wide roof."""
    builder.box((0.12, 0.1, 0.008), (0, 0, 0.004), COLOUR)
    for x, y in print_shapes.grid(2, 2, 0.1, 0.08):
        builder.box((0.01, 0.01, 0.11), (x, y, 0.06), COLOUR)
    for index in range(5):
        builder.box((0.11, 0.09, 0.006), (0, 0, 0.024 + index * 0.02), COLOUR, taper=(0.9, 0.82))
    builder.box((0.15, 0.13, 0.012), (0, 0, 0.121), COLOUR, bevel=0.004)


def _mandalorian_style_helmet(builder):
    """Full helmet: a domed crown over a straight-sided shell, with a T-shaped visor, cheek pieces and a round cap over each ear."""
    builder.cylinder(0.105, 0.15, (0, 0, 0.075), COLOUR, segments=10, radius_top=0.1)
    builder.ball(0.1, (0, 0, 0.15), COLOUR, scale=(1.0, 1.0, 0.75))
    builder.box((0.13, 0.012, 0.024), (0, -0.098, 0.135), COLOUR)
    builder.box((0.026, 0.012, 0.1), (0, -0.1, 0.085), COLOUR)
    for side in (-1, 1):
        builder.box((0.04, 0.014, 0.07), (side * 0.045, -0.096, 0.05), COLOUR, taper=(0.6, 1.0))
        builder.cylinder(0.03, 0.014, (side * 0.106, 0, 0.12), COLOUR, segments=8, axis="X")


def _dash_cam_mount(builder):
    """Suction cup with a locking collar, a ball-jointed arm and a clip plate for the camera."""
    builder.cylinder(0.03, 0.008, (0, 0, 0.004), COLOUR, segments=8, radius_top=0.024)
    builder.cylinder(0.016, 0.014, (0, 0, 0.015), COLOUR, segments=6)
    builder.ball(0.012, (0, 0, 0.03), COLOUR, subdivisions=1)
    print_shapes.limb(builder, (0, 0, 0.03), (0, -0.03, 0.055), 0.007)
    builder.box((0.05, 0.03, 0.006), (0, -0.036, 0.06), COLOUR, rotation=(math.radians(-25), 0, 0))
    builder.enlarge(1.5)


def _trailer_hitch_cover(builder):
    """Square plug with a wider face plate on top carrying a raised star."""
    builder.box((0.05, 0.05, 0.06), (0, 0, 0.03), COLOUR)
    builder.box((0.085, 0.085, 0.014), (0, 0, 0.066), COLOUR, bevel=0.004)
    star = [((0.03 if index % 2 == 0 else 0.013) * math.cos(math.pi / 2 + math.pi * index / 5),
             (0.03 if index % 2 == 0 else 0.013) * math.sin(math.pi / 2 + math.pi * index / 5)) for index in range(10)]
    builder.plate(star, 0.005, COLOUR, centre=(0, 0, 0.072))
    builder.enlarge(1.3)


def _number_plate_screw_caps_x4(builder):
    """Four small domed screw caps, each on a thin washer."""
    for x, y in print_shapes.grid(2, 2, 0.03, 0.03):
        builder.cylinder(0.011, 0.003, (x, y, 0.0015), COLOUR, segments=6)
        builder.cylinder(0.009, 0.008, (x, y, 0.007), COLOUR, segments=8, radius_top=0.004)
    builder.enlarge(1.8)


def _scooter_fender(builder):
    """Curved mudguard resting on its two ends, with a mounting tab at the top of the arch."""
    print_shapes.hoop(builder, 0.13, 0.008, 0.07, (0, 0, -0.059), pieces=6, start=math.radians(28), sweep=math.radians(124))
    builder.box((0.03, 0.03, 0.03), (0, 0.03, 0.088), COLOUR)
    builder.box((0.008, 0.07, 0.03), (0, 0, 0.061), COLOUR)


def _house_number_sign(builder):
    """Plaque lying face up with raised numerals and a screw boss at each end. The number shown is a sample."""
    builder.box((0.2, 0.11, 0.01), (0, 0, 0.005), COLOUR, bevel=0.004)
    _digit(builder, "abdeg", -0.028, 0, 0.013)
    _digit(builder, "bcfg", 0.028, 0, 0.013)
    for side in (-1, 1):
        builder.cylinder(0.008, 0.006, (side * 0.082, 0, 0.012), COLOUR, segments=6)


def _replacement_machine_guard(builder):
    """Bridge-shaped guard: a slatted top between two side walls, each with a bolt-down flange."""
    for side in (-1, 1):
        builder.box((0.008, 0.16, 0.1), (side * 0.11, 0, 0.05), COLOUR)
        builder.box((0.04, 0.16, 0.008), (side * 0.13, 0, 0.004), COLOUR)
    for y, _ in [(value, 0) for value in (-0.064, -0.032, 0.0, 0.032, 0.064)]:
        builder.box((0.228, 0.02, 0.008), (0, y, 0.1), COLOUR)


def _conveyor_guide_rail_x10(builder):
    """Ten long guide rails laid side by side, each with a mounting lug at one end."""
    for index, (_, y) in enumerate(print_shapes.grid(1, 10, 0, 0.02)):
        builder.box((0.27, 0.012, 0.01), (0, y, 0.005), COLOUR)
        builder.box((0.02, 0.012, 0.01), (-0.12 if index % 2 else 0.12, y, 0.015), COLOUR)


def _cable_entry_gland_x20(builder):
    """Rows of hex-bodied cable glands standing on end. Twelve are modelled to stand for the twenty."""
    for x, y in print_shapes.grid(4, 3, 0.045, 0.045):
        builder.cylinder(0.017, 0.03, (x, y, 0.015), COLOUR, segments=6, radius_top=0.011)


def _equipment_label_plates_x50(builder):
    """Sheet of wide label plates as it comes off the bed. Fifteen are modelled to stand for the fifty."""
    builder.box((0.28, 0.19, 0.003), (0, 0, 0.0015), COLOUR)
    for x, y in print_shapes.grid(3, 5, 0.088, 0.035):
        builder.box((0.076, 0.024, 0.005), (x, y, 0.0045), COLOUR)


def _outdoor_sign_enclosure(builder):
    """Wide weatherproof sign box with a framed front, a sloping hood and two pole clamps on the back."""
    builder.box((0.3, 0.05, 0.17), (0, 0.005, 0.085), COLOUR)
    for z in (0.012, 0.158):
        builder.box((0.3, 0.012, 0.024), (0, -0.026, z), COLOUR)
    for side in (-1, 1):
        builder.box((0.024, 0.012, 0.17), (side * 0.138, -0.026, 0.085), COLOUR)
        builder.box((0.03, 0.03, 0.04), (side * 0.07, 0.044, 0.09), COLOUR)
    builder.box((0.32, 0.09, 0.01), (0, -0.005, 0.176), COLOUR, rotation=(math.radians(-10), 0, 0))


# Factory

def _dragon_miniature_large(builder):
    """Rearing dragon on a rock: a raised neck and horned head, two spread wings, hind legs and a tail that sweeps round."""
    builder.cylinder(0.08, 0.02, (0, 0, 0.01), COLOUR, segments=7, radius_top=0.06)
    builder.ball(0.045, (0, 0.01, 0.075), COLOUR, subdivisions=1, scale=(0.9, 1.3, 1.0))
    print_shapes.limb(builder, (0, -0.02, 0.09), (0, -0.04, 0.15), 0.022, 0.016)
    print_shapes.limb(builder, (0, -0.04, 0.15), (0, -0.075, 0.185), 0.016, 0.012)
    builder.box((0.03, 0.05, 0.026), (0, -0.095, 0.19), COLOUR, taper=(0.7, 0.7))
    for side in (-1, 1):
        builder.box((0.006, 0.008, 0.03), (side * 0.01, -0.078, 0.215), COLOUR, taper=0.2)
        builder.plate([(side * 0.02, 0.1), (side * 0.13, 0.2), (side * 0.11, 0.13), (side * 0.12, 0.085), (side * 0.07, 0.09)], 0.008, COLOUR,
                      centre=(0, 0.02, 0), upright=True)
        builder.box((0.02, 0.03, 0.05), (side * 0.035, 0.02, 0.042), COLOUR, taper=(0.7, 0.7))
    print_shapes.limb(builder, (0, 0.055, 0.06), (0.05, 0.1, 0.035), 0.02, 0.012)
    print_shapes.limb(builder, (0.05, 0.1, 0.035), (0.11, 0.07, 0.022), 0.012, 0.003)


def _fantasy_miniatures_squad_of_5(builder):
    """Five little figures in a row on round bases, three of them carrying spears."""
    for index, (x, _) in enumerate(print_shapes.grid(5, 1, 0.045, 0)):
        builder.cylinder(0.018, 0.005, (x, 0, 0.0025), COLOUR, segments=6)
        builder.box((0.02, 0.014, 0.036), (x, 0, 0.023), COLOUR, taper=(0.7, 0.8))
        builder.box((0.014, 0.014, 0.014), (x, 0, 0.048), COLOUR)
        if index % 2 == 0:
            builder.box((0.003, 0.003, 0.07), (x + 0.014, -0.004, 0.04), COLOUR)


def _ring_custom_size(builder):
    """Finger ring standing on edge with a faceted stone in a collet at the top."""
    print_shapes.hoop(builder, 0.012, 0.004, 0.006, (0, 0, 0.0152))
    builder.cylinder(0.005, 0.005, (0, 0, 0.03), COLOUR, segments=6, radius_top=0.007)
    builder.ball(0.007, (0, 0, 0.037), COLOUR, subdivisions=1)
    builder.enlarge(3.0)


def _cufflinks(builder):
    """Pair of cufflinks, face down: a round face, a short post and a toggle bar."""
    for side in (-1, 1):
        builder.cylinder(0.012, 0.004, (side * 0.02, 0, 0.002), COLOUR, segments=8)
        builder.cylinder(0.003, 0.014, (side * 0.02, 0, 0.011), COLOUR, segments=6)
        builder.box((0.006, 0.02, 0.005), (side * 0.02, 0, 0.0205), COLOUR)
    builder.enlarge(2.2)


def _miniature_people_pack_x20(builder):
    """Rows of tiny standing figures for a layout. Ten are modelled to stand for the twenty."""
    for index, (x, y) in enumerate(print_shapes.grid(5, 2, 0.03, 0.035)):
        height = 0.03 + (index % 3) * 0.004
        builder.box((0.012, 0.008, height), (x, y, height / 2), COLOUR, taper=(0.7, 0.8))
        builder.box((0.009, 0.009, 0.009), (x, y, height + 0.0045), COLOUR)
    builder.enlarge(1.4)


def _dental_model_batch(builder):
    """Two horseshoe-shaped dental arches side by side, each with a row of teeth round the curve."""
    arch = [(-0.045, -0.04), (-0.022, -0.04), (-0.022, 0.0), (-0.012, 0.02), (0.012, 0.02), (0.022, 0.0), (0.022, -0.04), (0.045, -0.04),
            (0.045, 0.008), (0.026, 0.042), (-0.026, 0.042), (-0.045, 0.008)]
    for side in (-1, 1):
        x = side * 0.06
        builder.plate(arch, 0.014, COLOUR, centre=(x, 0, 0))
        for tx, ty in ((-0.034, -0.02), (-0.028, 0.012), (-0.012, 0.031), (0.012, 0.031), (0.028, 0.012), (0.034, -0.02)):
            builder.box((0.012, 0.012, 0.012), (x + tx, ty, 0.02), COLOUR, taper=(0.7, 0.7))


VARIANTS = {
    "bird_house": _bird_house,
    "gate_latch": _gate_latch,
    "fence_post_cap_x4": _fence_post_cap_x4,
    "outdoor_thermometer_housing": _outdoor_thermometer_housing,
    "mandalorian_style_helmet": _mandalorian_style_helmet,
    "dash_cam_mount": _dash_cam_mount,
    "trailer_hitch_cover": _trailer_hitch_cover,
    "number_plate_screw_caps_x4": _number_plate_screw_caps_x4,
    "scooter_fender": _scooter_fender,
    "house_number_sign": _house_number_sign,
    "replacement_machine_guard": _replacement_machine_guard,
    "conveyor_guide_rail_x10": _conveyor_guide_rail_x10,
    "cable_entry_gland_x20": _cable_entry_gland_x20,
    "equipment_label_plates_x50": _equipment_label_plates_x50,
    "outdoor_sign_enclosure": _outdoor_sign_enclosure,
    "dragon_miniature_large": _dragon_miniature_large,
    "fantasy_miniatures_squad_of_5": _fantasy_miniatures_squad_of_5,
    "ring_custom_size": _ring_custom_size,
    "cufflinks": _cufflinks,
    "miniature_people_pack_x20": _miniature_people_pack_x20,
    "dental_model_batch": _dental_model_batch,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
