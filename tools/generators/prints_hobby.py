"""Printed item generator for the hobby categories: Music, Photography and film,
RC and drones, and Model railway and dioramas.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_hobby.py -- \
    --variant ocarina --out assets/models/prints/ocarina.glb
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


# Music

def _guitar_pick_holder(builder):
    """Pick-shaped triangular dish, point to the front."""
    builder.shell(0.07, 0.03, 0.008, COLOUR, segments=3, chamfer=0.004, turn=-math.pi / 2)


def _recorder(builder):
    """Recorder standing on its bell: flared foot, long body with finger holes and a tapered mouthpiece."""
    builder.cylinder(0.026, 0.045, (0, 0, 0.0225), COLOUR, segments=8, radius_top=0.016)
    builder.cylinder(0.016, 0.17, (0, 0, 0.13), COLOUR, segments=8)
    builder.cylinder(0.018, 0.045, (0, 0, 0.2375), COLOUR, segments=8, radius_top=0.01)
    for index in range(6):
        builder.box((0.009, 0.006, 0.009), (0, -0.015, 0.07 + index * 0.022), COLOUR)


def _ocarina(builder):
    """Squashed egg-shaped body with a mouthpiece out of one side and finger holes on top."""
    builder.ball(0.05, (0, 0, 0.034), COLOUR, scale=(1.5, 0.95, 0.68))
    print_shapes.limb(builder, (0.01, -0.03, 0.03), (0.035, -0.085, 0.022), 0.02, 0.012)
    for x, y in ((-0.04, 0.0), (-0.015, 0.012), (0.012, 0.0), (0.038, 0.012)):
        builder.box((0.012, 0.012, 0.006), (x, y, 0.066 - abs(x) * 0.12), COLOUR)


def _sheet_music_stand_clip(builder):
    """Big sprung clip: two long jaws that meet at the front, a pivot between and splayed finger ends."""
    builder.box((0.035, 0.11, 0.008), (0, 0, 0.004), COLOUR)
    builder.box((0.035, 0.11, 0.008), (0, 0, 0.023), COLOUR, rotation=(math.radians(-14), 0, 0))
    builder.cylinder(0.01, 0.035, (0, 0.012, 0.014), COLOUR, segments=6, axis="X")


def _vinyl_record_display_stand(builder):
    """Two side brackets joined by a bar; a record sleeve leans back between the lips and the struts."""
    builder.box((0.2, 0.016, 0.012), (0, 0.03, 0.006), COLOUR)
    for side in (-1, 1):
        x = side * 0.09
        builder.box((0.022, 0.13, 0.014), (x, 0, 0.007), COLOUR)
        builder.box((0.022, 0.012, 0.03), (x, -0.059, 0.026), COLOUR)
        print_shapes.strut(builder, (x, -0.02, 0.012), (x, 0.055, 0.12), 0.016)


def _vinyl_wall_mount_x3(builder):
    """Three slim wall ledges, one behind the other: a back plate, a shelf and a front lip."""
    for _, y in print_shapes.grid(1, 3, 0, 0.05):
        builder.box((0.09, 0.007, 0.04), (0, y + 0.014, 0.02), COLOUR)
        builder.box((0.09, 0.026, 0.007), (0, y, 0.0035), COLOUR)
        builder.box((0.09, 0.005, 0.014), (0, y - 0.0105, 0.007), COLOUR)


# Photography and film

def _film_canister_holder(builder):
    """Four six-sided tubes joined in a block of two by two."""
    half = 0.034 * math.cos(math.pi / 6)
    for x, y in print_shapes.grid(2, 2, half * 2 - 0.005, 0.063):
        builder.shell(0.034, 0.075, 0.005, COLOUR, segments=6, centre=(x, y, 0), turn=math.pi / 6)


def _battery_case_camera(builder):
    """Small closed box with an overhanging lid and a latch on the front."""
    builder.box((0.1, 0.065, 0.03), (0, 0, 0.015), COLOUR, bevel=0.005)
    builder.box((0.106, 0.071, 0.016), (0, 0, 0.036), COLOUR, bevel=0.005)
    builder.box((0.024, 0.008, 0.018), (0, -0.036, 0.026), COLOUR)


def _filter_case(builder):
    """Flat round case with a slightly wider lid, a hinge at the back and a thumb tab at the front."""
    builder.cylinder(0.058, 0.014, (0, 0, 0.007), COLOUR, segments=10)
    builder.cylinder(0.062, 0.01, (0, 0, 0.019), COLOUR, segments=10, radius_top=0.056)
    builder.box((0.03, 0.012, 0.016), (0, 0.06, 0.012), COLOUR)
    builder.box((0.02, 0.012, 0.006), (0, -0.062, 0.019), COLOUR)


# RC and drones

def _rc_transmitter_stand(builder):
    """Base with two tapering side cheeks, a hook at the front of each and a bar across the back."""
    builder.box((0.19, 0.13, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    for side in (-1, 1):
        x = side * 0.08
        builder.box((0.014, 0.11, 0.1), (x, 0.005, 0.06), COLOUR, taper=(1.0, 0.35))
        builder.box((0.014, 0.014, 0.035), (x, -0.052, 0.028), COLOUR)
    builder.box((0.16, 0.012, 0.012), (0, 0.02, 0.1), COLOUR)


# Model railway and dioramas

def _platform_benches_x10(builder):
    """Ten tiny benches in two rows, each a seat block with a back rest."""
    for x, y in print_shapes.grid(5, 2, 0.042, 0.04):
        builder.box((0.034, 0.016, 0.012), (x, y - 0.002, 0.006), COLOUR)
        builder.box((0.034, 0.005, 0.026), (x, y + 0.008, 0.013), COLOUR)


def _diorama_base_hex(builder):
    """Shallow six-sided scenery tray with a couple of rocks in it."""
    builder.shell(0.115, 0.028, 0.008, COLOUR, segments=6, chamfer=0.004)
    builder.ball(0.026, (-0.03, 0.02, 0.024), COLOUR, subdivisions=1, scale=(1.2, 1.0, 0.8))
    builder.ball(0.016, (0.035, -0.025, 0.02), COLOUR, subdivisions=1)


def _model_railway_tunnel_portal(builder):
    """Stone portal: a wall each side, an arch of five blocks between them and a parapet across the top."""
    for side in (-1, 1):
        builder.box((0.055, 0.035, 0.165), (side * 0.0775, 0, 0.0825), COLOUR)
    for index in range(5):
        angle = math.radians(18 + index * 36)
        builder.box(
            (0.047, 0.035, 0.026), (0.0625 * math.cos(angle), 0, 0.09 + 0.0625 * math.sin(angle)), COLOUR,
            rotation=(0, -(angle + math.pi / 2), 0))
    builder.box((0.22, 0.04, 0.022), (0, 0, 0.174), COLOUR)


def _bridge_girder_set(builder):
    """Pair of long plate girders (web, flanges and stiffeners) joined by three cross beams."""
    for y in (-0.04, 0.04):
        builder.box((0.28, 0.006, 0.05), (0, y, 0.027), COLOUR)
        builder.box((0.28, 0.022, 0.005), (0, y, 0.0025), COLOUR)
        builder.box((0.28, 0.022, 0.005), (0, y, 0.0525), COLOUR)
        for x, _ in print_shapes.grid(3, 1, 0.09, 0):
            builder.box((0.006, 0.02, 0.046), (x, y, 0.027), COLOUR)
    for x, _ in print_shapes.grid(3, 1, 0.09, 0):
        builder.box((0.008, 0.08, 0.008), (x, 0, 0.03), COLOUR)


# RC and drones, Spare room tier

def _fpv_drone_camera_mount(builder):
    """Tilted cradle for a small camera: a base, an ear either side and the camera block between them."""
    builder.box((0.04, 0.03, 0.006), (0, 0, 0.003), COLOUR)
    for side in (-1, 1):
        builder.box((0.006, 0.026, 0.03), (side * 0.017, 0, 0.02), COLOUR, taper=(1.0, 0.6))
    builder.box((0.026, 0.02, 0.02), (0, -0.002, 0.022), COLOUR, rotation=(math.radians(-25), 0, 0))
    builder.cylinder(0.007, 0.008, (0, -0.014, 0.027), COLOUR, segments=6, rotation=(math.radians(65), 0, 0))
    builder.enlarge(2.2)


def _propeller_guards_x4(builder):
    """Four six-sided guard rings, each with a mounting arm."""
    for x, y in print_shapes.grid(2, 2, 0.105, 0.1):
        builder.shell(0.042, 0.01, 0.006, COLOUR, segments=6, centre=(x, y, 0), open_base=True)
        builder.box((0.012, 0.016, 0.01), (x * 0.52, y * 0.52, 0.005), COLOUR, rotation=(0, 0, math.atan2(y, x)))


def _rc_car_body_shell(builder):
    """Car body: a long lower shell, a tapered cabin, a bonnet scoop and a rear wing on two posts."""
    builder.box((0.27, 0.115, 0.045), (0, 0, 0.0225), COLOUR, bevel=0.01)
    builder.box((0.13, 0.095, 0.04), (0.015, 0, 0.062), COLOUR, taper=(0.7, 0.85))
    builder.box((0.04, 0.04, 0.01), (-0.085, 0, 0.049), COLOUR)
    for side in (-1, 1):
        builder.box((0.01, 0.01, 0.03), (0.115, side * 0.035, 0.058), COLOUR)
    builder.box((0.03, 0.11, 0.006), (0.118, 0, 0.076), COLOUR)


def _rc_crawler_tyres_x4(builder):
    """Four chunky tyres lying flat, open through the middle for the wheel."""
    for x, y in print_shapes.grid(2, 2, 0.095, 0.095):
        builder.shell(0.044, 0.034, 0.014, COLOUR, segments=8, centre=(x, y, 0), open_base=True)


def _battery_strap_holder(builder):
    """Flat pad with a raised bridge at each end for a strap to thread under."""
    builder.box((0.05, 0.03, 0.004), (0, 0, 0.002), COLOUR)
    for side in (-1, 1):
        builder.box((0.008, 0.03, 0.006), (side * 0.018, 0, 0.007), COLOUR)
        for y in (-0.013, 0.013):
            builder.box((0.008, 0.004, 0.006), (side * 0.018, y, 0.004), COLOUR)
    builder.enlarge(2.0)


def _antenna_mount(builder):
    """Small base with two tubes angled up and apart in a V for a pair of antennas."""
    builder.box((0.03, 0.02, 0.008), (0, 0, 0.004), COLOUR)
    for side in (-1, 1):
        print_shapes.limb(builder, (side * 0.006, 0, 0.006), (side * 0.024, 0, 0.036), 0.006, 0.005)
    builder.enlarge(2.0)


def _landing_gear_x4(builder):
    """Four landing legs: a mounting pad, a leg that sweeps down and out, and a foot."""
    for x, y in print_shapes.grid(2, 2, 0.06, 0.05):
        builder.box((0.022, 0.016, 0.005), (x - 0.012, y, 0.0425), COLOUR)
        print_shapes.strut(builder, (x - 0.012, y, 0.042), (x + 0.012, y, 0.006), 0.008)
        builder.box((0.02, 0.016, 0.006), (x + 0.014, y, 0.003), COLOUR)


def _servo_saver(builder):
    """Servo horn: a round hub with a sprung collar and a tapering arm."""
    builder.cylinder(0.014, 0.012, (0, 0, 0.006), COLOUR, segments=8)
    builder.cylinder(0.01, 0.008, (0, 0, 0.016), COLOUR, segments=6)
    builder.plate([(-0.008, 0.0), (0.008, 0.0), (0.004, 0.04), (-0.004, 0.04)], 0.006, COLOUR)
    builder.enlarge(2.0)


def _rc_boat_hull(builder):
    """Open boat hull with a pointed bow, a foredeck and a motor mount inside at the stern."""
    hull = [(-0.05, -0.14), (0.05, -0.14), (0.055, 0.04), (0.0, 0.15), (-0.055, 0.04)]
    builder.plate(hull, 0.008, COLOUR)
    builder.outline(hull, 0.055, 0.007, COLOUR)
    builder.plate([(-0.048, 0.045), (0.048, 0.045), (0.0, 0.14)], 0.006, COLOUR, centre=(0, 0, 0.049))
    builder.box((0.04, 0.03, 0.025), (0, -0.11, 0.02), COLOUR)


VARIANTS = {
    "guitar_pick_holder": _guitar_pick_holder,
    "recorder": _recorder,
    "ocarina": _ocarina,
    "sheet_music_stand_clip": _sheet_music_stand_clip,
    "vinyl_record_display_stand": _vinyl_record_display_stand,
    "vinyl_wall_mount_x3": _vinyl_wall_mount_x3,
    "film_canister_holder": _film_canister_holder,
    "battery_case_camera": _battery_case_camera,
    "filter_case": _filter_case,
    "rc_transmitter_stand": _rc_transmitter_stand,
    "platform_benches_x10": _platform_benches_x10,
    "diorama_base_hex": _diorama_base_hex,
    "model_railway_tunnel_portal": _model_railway_tunnel_portal,
    "bridge_girder_set": _bridge_girder_set,
    "fpv_drone_camera_mount": _fpv_drone_camera_mount,
    "propeller_guards_x4": _propeller_guards_x4,
    "rc_car_body_shell": _rc_car_body_shell,
    "rc_crawler_tyres_x4": _rc_crawler_tyres_x4,
    "battery_strap_holder": _battery_strap_holder,
    "antenna_mount": _antenna_mount,
    "landing_gear_x4": _landing_gear_x4,
    "servo_saver": _servo_saver,
    "rc_boat_hull": _rc_boat_hull,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
