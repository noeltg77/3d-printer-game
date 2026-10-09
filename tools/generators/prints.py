"""Printed item generator: the things that come off the print bed.

These use the tint material, so the game colours each one to match its filament.
Sizes are exaggerated a little so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints.py -- \
    --variant desk_organiser --out assets/models/prints/desk_organiser.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
import print_shapes
from common import MeshBuilder


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="desk_organiser")


def build(args, rng):
    builder = MeshBuilder(material=common.TINT_MATERIAL_NAME)
    VARIANTS[args.variant](builder)
    builder.finish(args.out.stem)


def _desk_organiser(builder):
    """Tray with a tall pen pot, a mid pot and a low card slot."""
    builder.box((0.2, 0.12, 0.015), (0, 0, 0.0075), "white", bevel=0.004)
    builder.box((0.07, 0.09, 0.11), (-0.055, 0.005, 0.07), "white", bevel=0.006)
    builder.box((0.055, 0.09, 0.07), (0.015, 0.005, 0.05), "white", bevel=0.006)
    builder.box((0.045, 0.09, 0.04), (0.07, 0.005, 0.035), "white", bevel=0.006)


def _cable_clips(builder):
    """Six little clips laid out in two rows, as they come off the bed."""
    for row in (-1, 1):
        for column in (-1, 0, 1):
            x, y = column * 0.06, row * 0.035
            builder.box((0.045, 0.045, 0.012), (x, y, 0.006), "white", bevel=0.003)
            builder.box((0.012, 0.045, 0.03), (x - 0.0165, y, 0.027), "white", bevel=0.003)
            builder.box((0.012, 0.045, 0.02), (x + 0.0165, y, 0.022), "white", bevel=0.003)


def _phone_stand(builder):
    """Base with a lip and a leaning back rest."""
    builder.box((0.11, 0.13, 0.015), (0, 0, 0.0075), "white", bevel=0.004)
    builder.box((0.11, 0.02, 0.03), (0, -0.055, 0.03), "white", bevel=0.004)
    builder.box((0.11, 0.018, 0.15), (0, 0.035, 0.082), "white", rotation=(math.radians(-18), 0, 0), bevel=0.004)
    builder.box((0.03, 0.05, 0.06), (0, 0.075, 0.04), "white", rotation=(math.radians(25), 0, 0))


def _plant_pot(builder):
    """Faceted pot, wider at the rim."""
    builder.cylinder(0.045, 0.1, (0, 0, 0.05), "white", segments=6, radius_top=0.07)
    builder.cylinder(0.078, 0.02, (0, 0, 0.11), "white", segments=6)


def _flexi_dragon(builder):
    """Chain of body segments curving along the bed, with a head and tail."""
    segments = 7
    for index in range(segments):
        along = index / (segments - 1)
        x = (along - 0.5) * 0.24
        y = math.sin(along * math.pi * 1.6) * 0.035
        size = 0.042 - abs(along - 0.3) * 0.025
        builder.box((0.03, size, size), (x, y, size / 2), "white", bevel=0.005)
        builder.box((0.012, 0.008, size * 0.5), (x, y, size + size * 0.2), "white")
    builder.box((0.05, 0.045, 0.04), (-0.15, -0.005, 0.02), "white", bevel=0.008)
    builder.box((0.03, 0.03, 0.02), (-0.18, -0.005, 0.012), "white", bevel=0.004)
    for side in (-1, 1):
        builder.box((0.008, 0.008, 0.025), (-0.14, -0.005 + side * 0.014, 0.05), "white")


def _pen_pot_hex(builder):
    """Hexagonal pen pot, the Garage product `pen_pot_hex`. About 1.4 times real size."""
    builder.shell(0.065, 0.13, 0.009, "white", segments=6, chamfer=0.006)


def _headphone_stand(builder):
    """Oval base, upright post and a curved cradle on top for the headband."""
    builder.cylinder(0.075, 0.016, (0, 0, 0.008), "white", segments=16, radius_top=0.07)
    builder.box((0.03, 0.03, 0.17), (0, 0, 0.09), "white", bevel=0.006, bevel_segments=2)
    # Cradle: a half ring of short boxes, each turned to follow the curve, opening upwards.
    arc_radius, centre_z, pieces = 0.06, 0.22, 13
    for index in range(pieces):
        angle = math.pi + math.pi * index / (pieces - 1)
        x, z = arc_radius * math.cos(angle), centre_z + arc_radius * math.sin(angle)
        builder.box((0.03, 0.04, 0.014), (x, 0, z), "white", rotation=(0, -(angle + math.pi / 2), 0), bevel=0.003)
    builder.box((0.036, 0.04, 0.03), (0, 0, 0.165), "white", bevel=0.005)


def _mail_sorter(builder):
    """Letter rack, the Garage product `mail_sorter`: three panels stepping up to the back."""
    print_shapes.slot_rack(builder, 0.26, 0.14, (0.07, 0.115, 0.16))


VARIANTS = {
    "desk_organiser": _desk_organiser,
    "cable_clips": _cable_clips,
    "phone_stand": _phone_stand,
    "plant_pot": _plant_pot,
    "flexi_dragon": _flexi_dragon,
    "pen_pot_hex": _pen_pot_hex,
    "headphone_stand": _headphone_stand,
    "mail_sorter": _mail_sorter,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
