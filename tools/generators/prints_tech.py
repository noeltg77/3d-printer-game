"""Printed item generator for the Tech accessories category.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_tech.py -- \
    --variant controller_stand --out assets/models/prints/controller_stand.glb
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


def _controller_wall_mount_x2(builder):
    """Two wall brackets side by side: an upright plate with a pair of upturned prongs."""
    for centre in (-0.045, 0.045):
        builder.box((0.07, 0.01, 0.075), (centre, 0.03, 0.0375), COLOUR)
        for side in (-1, 1):
            x = centre + side * 0.022
            builder.box((0.012, 0.06, 0.012), (x, -0.003, 0.02), COLOUR)
            builder.box((0.012, 0.012, 0.03), (x, -0.029, 0.029), COLOUR)


def _controller_stand(builder):
    """Round base, a leaning neck and a cradle bar with upturned ends."""
    builder.cylinder(0.07, 0.016, (0, 0, 0.008), COLOUR, segments=10, radius_top=0.062)
    builder.box((0.04, 0.022, 0.1), (0, 0.012, 0.062), COLOUR, rotation=(math.radians(-14), 0, 0))
    builder.box((0.15, 0.04, 0.022), (0, 0.022, 0.118), COLOUR, bevel=0.005)
    for side in (-1, 1):
        builder.box((0.02, 0.04, 0.03), (side * 0.065, 0.022, 0.14), COLOUR)


def _vr_headset_stand(builder):
    """Tall stand: wide round base, square post and a head-shaped block on top."""
    builder.cylinder(0.085, 0.016, (0, 0, 0.008), COLOUR, segments=12, radius_top=0.078)
    builder.box((0.032, 0.032, 0.18), (0, 0, 0.1), COLOUR, bevel=0.006)
    builder.cylinder(0.062, 0.07, (0, 0, 0.215), COLOUR, segments=8, radius_top=0.05)
    builder.cylinder(0.05, 0.02, (0, 0, 0.26), COLOUR, segments=8, radius_top=0.032)


def _camera_lens_cap_holder(builder):
    """Shallow round cup that a lens cap presses into, with a strap lug on each side."""
    builder.shell(0.042, 0.014, 0.005, COLOUR, segments=10)
    for side in (-1, 1):
        builder.box((0.02, 0.03, 0.006), (side * 0.048, 0, 0.003), COLOUR)


def _sd_card_holder(builder):
    """Small block of six narrow card slots."""
    print_shapes.divided_tray(builder, (0.12, 0.065, 0.032), 0.007, across=5, chamfer=0.003)


def _usb_stick_organiser(builder):
    """Round puck with six square sockets standing proud around the top."""
    builder.cylinder(0.06, 0.03, (0, 0, 0.015), COLOUR, segments=10, radius_top=0.054)
    for index in range(6):
        angle = math.tau * index / 6
        builder.tray(
            (0.022, 0.022, 0.012), 0.004, COLOUR,
            centre=(0.036 * math.cos(angle), 0.036 * math.sin(angle), 0.028))


def _keyboard_case_60(builder):
    """Long shallow keyboard tray with mounting posts inside and a cable port at the back."""
    builder.tray((0.3, 0.115, 0.032), 0.008, COLOUR, floor=0.006, chamfer=0.004)
    for x, y in print_shapes.grid(2, 2, 0.2, 0.05):
        builder.box((0.014, 0.014, 0.014), (x, y, 0.012), COLOUR)
    builder.box((0.04, 0.008, 0.018), (-0.09, 0.059, 0.02), COLOUR)


def _smartwatch_charging_stand(builder):
    """Base with a chunky leaning post and a round charger pad on its face."""
    tilt = math.radians(20)
    builder.box((0.085, 0.095, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    centre = (0, 0.0, 0.012 + math.cos(tilt) * 0.045)
    builder.box((0.06, 0.032, 0.09), centre, COLOUR, rotation=(-tilt, 0, 0), bevel=0.006)
    pad = (0, centre[1] - math.cos(tilt) * 0.02 + math.sin(tilt) * 0.012, centre[2] + math.sin(tilt) * 0.02 + math.cos(tilt) * 0.012)
    builder.cylinder(0.022, 0.01, pad, COLOUR, segments=8, rotation=(math.pi / 2 - tilt, 0, 0))


def _console_vertical_stand(builder):
    """Long low base with two rails that a console stands between."""
    print_shapes.slot_rack(builder, 0.27, 0.1, (0.05, 0.05), lean=0.0, base=0.016)


def _cable_comb_set(builder):
    """Three flat cable combs of different widths, teeth pointing forwards."""
    for y, teeth in ((0.045, 5), (0.0, 4), (-0.045, 3)):
        width = teeth * 0.02 + 0.008
        builder.box((width, 0.012, 0.008), (0, y + 0.012, 0.004), COLOUR)
        for x, _ in print_shapes.grid(teeth + 1, 1, 0.02, 0):
            builder.box((0.008, 0.024, 0.008), (x, y - 0.004, 0.004), COLOUR)


VARIANTS = {
    "controller_wall_mount_x2": _controller_wall_mount_x2,
    "controller_stand": _controller_stand,
    "vr_headset_stand": _vr_headset_stand,
    "camera_lens_cap_holder": _camera_lens_cap_holder,
    "sd_card_holder": _sd_card_holder,
    "usb_stick_organiser": _usb_stick_organiser,
    "keyboard_case_60": _keyboard_case_60,
    "smartwatch_charging_stand": _smartwatch_charging_stand,
    "console_vertical_stand": _console_vertical_stand,
    "cable_comb_set": _cable_comb_set,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
