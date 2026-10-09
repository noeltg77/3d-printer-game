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


# Spare room tier: Music, Photography and film

def _guitar_pick_set_x10(builder):
    """Ten guitar picks in two rows."""
    pick = [(0, -0.016), (0.013, 0.004), (0.008, 0.014), (-0.008, 0.014), (-0.013, 0.004)]
    for x, y in print_shapes.grid(5, 2, 0.032, 0.038):
        builder.plate(pick, 0.003, COLOUR, centre=(x, y, 0))
    builder.enlarge(1.2)


def _guitar_wall_hanger(builder):
    """Wall plate with an arm that ends in a padded yoke, two prongs turned up at the tips."""
    builder.box((0.07, 0.012, 0.11), (0, 0.07, 0.055), COLOUR, bevel=0.004)
    builder.box((0.022, 0.08, 0.022), (0, 0.025, 0.06), COLOUR)
    for side in (-1, 1):
        builder.box((0.016, 0.07, 0.016), (side * 0.035, -0.04, 0.06), COLOUR, rotation=(0, 0, side * 0.35))
        builder.box((0.016, 0.016, 0.03), (side * 0.047, -0.07, 0.072), COLOUR)


def _capo(builder):
    """C-shaped clamp with a pad along the top jaw and a lever to squeeze."""
    builder.plate([(-0.04, 0.0), (0.04, 0.0), (0.04, 0.012), (-0.028, 0.012), (-0.028, 0.04), (0.04, 0.04), (0.04, 0.052), (-0.04, 0.052)],
                  0.02, COLOUR, upright=True)
    builder.box((0.06, 0.022, 0.006), (0.008, 0, 0.037), COLOUR)
    print_shapes.strut(builder, (-0.036, 0, 0.01), (-0.075, 0, 0.045), 0.012)
    builder.enlarge(1.4)


def _drum_stick_holder(builder):
    """Clamp block with two open tubes side by side for a pair of sticks."""
    builder.box((0.07, 0.03, 0.04), (0, 0.03, 0.02), COLOUR)
    for side in (-1, 1):
        builder.shell(0.02, 0.07, 0.005, COLOUR, segments=6, centre=(side * 0.02, -0.004, 0))
    builder.cylinder(0.006, 0.02, (0, 0.05, 0.02), COLOUR, segments=6, axis="Y")


def _headphone_hook_studio(builder):
    """Desk-edge clamp with a screw underneath and a J hook hanging off the front."""
    builder.box((0.04, 0.06, 0.01), (0, 0.01, 0.105), COLOUR)
    builder.box((0.04, 0.01, 0.05), (0, 0.035, 0.08), COLOUR)
    builder.box((0.04, 0.06, 0.01), (0, 0.01, 0.06), COLOUR)
    builder.cylinder(0.006, 0.03, (0, 0.0, 0.072), COLOUR, segments=6)
    builder.box((0.03, 0.01, 0.06), (0, -0.02, 0.035), COLOUR)
    builder.box((0.03, 0.05, 0.01), (0, -0.04, 0.005), COLOUR)
    builder.box((0.03, 0.01, 0.03), (0, -0.06, 0.02), COLOUR)


def _pedalboard_cable_clips_x10(builder):
    """Ten small cable clips in two rows: a stick-down pad with a hoop over it."""
    for x, y in print_shapes.grid(5, 2, 0.028, 0.03):
        builder.box((0.02, 0.02, 0.004), (x, y, 0.002), COLOUR)
        builder.box((0.02, 0.008, 0.012), (x, y, 0.009), COLOUR, taper=(0.6, 1.0))
    builder.enlarge(1.2)


def _speaker_stand_bookshelf_pair(builder):
    """Two wedge stands that tilt a speaker back, each with a lip along the low edge."""
    for side in (-1, 1):
        builder.plate([(-0.07, 0.0), (0.07, 0.0), (0.07, 0.05), (-0.07, 0.012)], 0.11, COLOUR, centre=(0, side * 0.065, 0), upright=True)
        builder.box((0.01, 0.11, 0.014), (-0.066, side * 0.065, 0.02), COLOUR)


def _camera_hot_shoe_mount(builder):
    """Foot that slides into a camera's shoe, with a locking wheel and a threaded stud on top."""
    builder.box((0.024, 0.024, 0.004), (0, 0, 0.002), COLOUR)
    builder.box((0.016, 0.024, 0.006), (0, 0, 0.007), COLOUR)
    builder.cylinder(0.016, 0.006, (0, 0, 0.013), COLOUR, segments=8)
    builder.cylinder(0.005, 0.014, (0, 0, 0.023), COLOUR, segments=6)
    builder.enlarge(2.2)


def _lens_hood(builder):
    """Short flared tube, open both ends, with a narrower collar where it fits the lens."""
    builder.shell(0.046, 0.016, 0.006, COLOUR, segments=10, open_base=True)
    builder.shell(0.048, 0.05, 0.005, COLOUR, segments=10, centre=(0, 0, 0.014), radius_top=0.066, open_base=True)


def _tripod_phone_adapter(builder):
    """Sprung phone clamp, two jaws on a back bar, standing on a threaded foot block."""
    builder.box((0.03, 0.03, 0.02), (0, 0, 0.01), COLOUR)
    builder.box((0.016, 0.02, 0.1), (0, 0.006, 0.07), COLOUR)
    for z in (0.028, 0.114):
        builder.box((0.03, 0.03, 0.012), (0, -0.008, z), COLOUR)
    builder.cylinder(0.01, 0.008, (0.019, 0, 0.01), COLOUR, segments=6, axis="X")


def _gopro_mount_set(builder):
    """Three action camera mounts: a three-finger base, a two-finger buckle and a thumbscrew."""
    builder.box((0.04, 0.04, 0.006), (-0.045, 0, 0.003), COLOUR)
    for x in (-0.012, 0.0, 0.012):
        builder.box((0.005, 0.02, 0.022), (-0.045 + x, 0, 0.017), COLOUR)
    builder.box((0.03, 0.05, 0.008), (0.005, 0, 0.004), COLOUR)
    for x in (-0.006, 0.006):
        builder.box((0.005, 0.02, 0.022), (0.005 + x, 0.008, 0.019), COLOUR)
    builder.cylinder(0.005, 0.04, (0.05, 0, 0.005), COLOUR, segments=6, axis="Y")
    builder.cylinder(0.014, 0.008, (0.05, 0.022, 0.014), COLOUR, segments=6, axis="Y")
    builder.enlarge(1.3)


def _light_stand_cold_shoe_adapter(builder):
    """Round spigot that drops onto a light stand, with a shoe slot on top and a thumbscrew at the side."""
    builder.cylinder(0.012, 0.03, (0, 0, 0.015), COLOUR, segments=8)
    builder.box((0.03, 0.03, 0.01), (0, 0, 0.035), COLOUR)
    for side in (-1, 1):
        builder.box((0.006, 0.03, 0.008), (side * 0.012, 0, 0.044), COLOUR)
    builder.cylinder(0.006, 0.014, (0.02, 0, 0.016), COLOUR, segments=6, axis="X")
    builder.enlarge(1.8)


def _gimbal_counterweight(builder):
    """Three stacked weight discs on a threaded rod with a clamp block at the end."""
    for index in range(3):
        builder.cylinder(0.03, 0.014, (0, 0, 0.007 + index * 0.016), COLOUR, segments=10)
    builder.cylinder(0.007, 0.05, (0, 0, 0.07), COLOUR, segments=6)
    builder.box((0.03, 0.022, 0.016), (0, 0, 0.1), COLOUR)


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
    "guitar_pick_set_x10": _guitar_pick_set_x10,
    "guitar_wall_hanger": _guitar_wall_hanger,
    "capo": _capo,
    "drum_stick_holder": _drum_stick_holder,
    "headphone_hook_studio": _headphone_hook_studio,
    "pedalboard_cable_clips_x10": _pedalboard_cable_clips_x10,
    "speaker_stand_bookshelf_pair": _speaker_stand_bookshelf_pair,
    "camera_hot_shoe_mount": _camera_hot_shoe_mount,
    "lens_hood": _lens_hood,
    "tripod_phone_adapter": _tripod_phone_adapter,
    "gopro_mount_set": _gopro_mount_set,
    "light_stand_cold_shoe_adapter": _light_stand_cold_shoe_adapter,
    "gimbal_counterweight": _gimbal_counterweight,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
