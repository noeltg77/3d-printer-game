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


# Tech accessories, Spare room tier

def _phone_case_custom(builder):
    """Phone case lying open side up, with a raised surround for the camera at one corner."""
    builder.tray((0.08, 0.16, 0.014), 0.004, COLOUR, floor=0.003, chamfer=0.003)
    builder.outline([(-0.03, 0.035), (-0.004, 0.035), (-0.004, 0.068), (-0.03, 0.068)], 0.008, 0.004, COLOUR)


def _earbuds_case_cover(builder):
    """Rounded pebble-shaped cover with a seam round the middle and a loop for a clip."""
    builder.ball(0.034, (0, 0, 0.0244), COLOUR, scale=(1.0, 0.75, 0.72))
    builder.cylinder(0.034, 0.004, (0, 0, 0.026), COLOUR, segments=10)
    builder.shell(0.01, 0.006, 0.004, COLOUR, segments=6, centre=(0.042, 0, 0.02), open_base=True)
    builder.enlarge(1.5)


def _smart_speaker_wall_mount(builder):
    """Wall plate with a round cradle on a braced arm for a small speaker to sit in."""
    builder.box((0.1, 0.012, 0.13), (0, 0.07, 0.065), COLOUR, bevel=0.004)
    builder.shell(0.055, 0.022, 0.008, COLOUR, segments=10, centre=(0, 0.008, 0.03), open_base=True)
    builder.box((0.03, 0.03, 0.012), (0, 0.056, 0.036), COLOUR)
    print_shapes.strut(builder, (0, 0.064, 0.008), (0, 0.02, 0.03), 0.012)


def _router_wall_mount(builder):
    """Wall plate with an L-shaped claw at each corner that grips the edges of a router."""
    builder.box((0.2, 0.012, 0.13), (0, 0.03, 0.065), COLOUR, bevel=0.004)
    for x, z in print_shapes.grid(2, 2, 0.16, 0.09):
        builder.box((0.022, 0.04, 0.012), (x, 0.006, 0.065 + z), COLOUR)
        builder.box((0.022, 0.01, 0.026), (x, -0.012, 0.065 + z * 0.84), COLOUR)


def _cable_strain_relief_x10(builder):
    """Ten little tapered sleeves in two rows."""
    for x, y in print_shapes.grid(5, 2, 0.028, 0.03):
        builder.cylinder(0.01, 0.026, (x, y, 0.013), COLOUR, segments=6, radius_top=0.005)
    builder.enlarge(1.2)


def _laptop_vent_stand(builder):
    """Sloping stand: two side rails rising to the back, slats across them and a lip at the front."""
    for side in (-1, 1):
        x = side * 0.12
        builder.box((0.016, 0.2, 0.012), (x, 0, 0.006), COLOUR)
        builder.box((0.016, 0.016, 0.075), (x, 0.092, 0.0375), COLOUR)
        print_shapes.strut(builder, (x, -0.095, 0.012), (x, 0.095, 0.07), 0.014)
    for index in range(5):
        along = (index + 0.5) / 5
        builder.box((0.256, 0.016, 0.008), (0, -0.095 + along * 0.19, 0.022 + along * 0.058), COLOUR, rotation=(math.radians(17), 0, 0))
    builder.box((0.256, 0.01, 0.022), (0, -0.098, 0.022), COLOUR)


def _phone_grip_ring(builder):
    """Round sticky base with a finger ring standing up from it."""
    builder.cylinder(0.022, 0.005, (0, 0, 0.0025), COLOUR, segments=8)
    print_shapes.hoop(builder, 0.016, 0.005, 0.008, (0, 0, 0.022))
    builder.enlarge(1.8)


def _tablet_wall_mount(builder):
    """Wall plate with a ledge along the bottom and a grip either side for a tablet to slide into."""
    builder.box((0.19, 0.01, 0.13), (0, 0.02, 0.065), COLOUR, bevel=0.004)
    builder.box((0.19, 0.03, 0.01), (0, 0.004, 0.012), COLOUR)
    builder.box((0.19, 0.008, 0.024), (0, -0.008, 0.019), COLOUR)
    for side in (-1, 1):
        builder.box((0.01, 0.03, 0.07), (side * 0.092, 0.004, 0.06), COLOUR)
        builder.box((0.018, 0.008, 0.07), (side * 0.086, -0.008, 0.06), COLOUR)


def _mini_pc_wall_bracket(builder):
    """Deep cradle for a small computer: a wall plate, a floor, a front lip and a strap up each side."""
    builder.box((0.16, 0.012, 0.13), (0, 0.045, 0.065), COLOUR, bevel=0.004)
    builder.box((0.16, 0.08, 0.012), (0, 0.0, 0.006), COLOUR)
    builder.box((0.16, 0.01, 0.04), (0, -0.036, 0.03), COLOUR)
    for side in (-1, 1):
        builder.box((0.012, 0.08, 0.09), (side * 0.074, 0.0, 0.055), COLOUR, taper=(1.0, 0.5))


def _screen_corner_protectors_x4(builder):
    """Four L-shaped corner pieces."""
    corner = [(-0.02, -0.02), (0.02, -0.02), (0.02, -0.008), (-0.008, -0.008), (-0.008, 0.02), (-0.02, 0.02)]
    for x, y in print_shapes.grid(2, 2, 0.05, 0.05):
        builder.plate(corner, 0.018, COLOUR, centre=(x, y, 0))
    builder.enlarge(1.3)


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
    "phone_case_custom": _phone_case_custom,
    "earbuds_case_cover": _earbuds_case_cover,
    "smart_speaker_wall_mount": _smart_speaker_wall_mount,
    "router_wall_mount": _router_wall_mount,
    "cable_strain_relief_x10": _cable_strain_relief_x10,
    "laptop_vent_stand": _laptop_vent_stand,
    "phone_grip_ring": _phone_grip_ring,
    "tablet_wall_mount": _tablet_wall_mount,
    "mini_pc_wall_bracket": _mini_pc_wall_bracket,
    "screen_corner_protectors_x4": _screen_corner_protectors_x4,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
