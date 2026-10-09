"""Printed item generator for the Automotive and bike category of the Spare room tier.
(The Garage tyre gauge is in prints_small.py.)

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_automotive.py -- \
    --variant bike_bottle_cage --out assets/models/prints/bike_bottle_cage.glb
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


def _car_phone_mount(builder):
    """Upright phone cradle with side grips and a bottom lip, on a ball joint and a vent clip."""
    builder.box((0.075, 0.01, 0.12), (0, -0.01, 0.06), COLOUR, bevel=0.004)
    builder.box((0.075, 0.022, 0.012), (0, -0.02, 0.006), COLOUR)
    for side in (-1, 1):
        builder.box((0.008, 0.022, 0.04), (side * 0.04, -0.02, 0.065), COLOUR)
        builder.box((0.006, 0.04, 0.03), (side * 0.008, 0.045, 0.05), COLOUR)
    builder.ball(0.016, (0, 0.01, 0.055), COLOUR, subdivisions=1)


def _car_cup_holder_adapter(builder):
    """Narrow tapered plug that fits the car's holder, opening out into a wide cup on top."""
    builder.cylinder(0.035, 0.07, (0, 0, 0.035), COLOUR, segments=8, radius_top=0.04)
    builder.shell(0.05, 0.06, 0.006, COLOUR, segments=8, centre=(0, 0, 0.066), radius_top=0.058)


def _car_hook_for_headrest_x2(builder):
    """Two flat hooks side by side: a ring that goes round the headrest post over a J to hang bags on."""
    hook = [(-0.008, 0.02), (-0.008, -0.045), (0.004, -0.06), (0.03, -0.06), (0.03, -0.035), (0.02, -0.035),
            (0.02, -0.048), (0.008, -0.048), (0.008, 0.02)]
    for side in (-1, 1):
        x = side * 0.035 - 0.01
        builder.plate(hook, 0.01, COLOUR, centre=(x, 0, 0))
        builder.shell(0.02, 0.01, 0.007, COLOUR, segments=6, centre=(x, 0.036, 0), open_base=True)


def _sunglasses_visor_clip(builder):
    """Clip that grips the sun visor, with a sprung jaw on top to hold a pair of glasses by the arm."""
    builder.box((0.05, 0.07, 0.006), (0, 0, 0.003), COLOUR)
    builder.box((0.05, 0.006, 0.02), (0, 0.032, 0.01), COLOUR)
    builder.box((0.05, 0.07, 0.006), (0, 0, 0.02), COLOUR)
    builder.box((0.03, 0.05, 0.006), (0, -0.004, 0.036), COLOUR, rotation=(math.radians(-14), 0, 0))
    builder.box((0.03, 0.01, 0.016), (0, 0.02, 0.03), COLOUR)
    builder.enlarge(1.4)


def _bin_for_car_door_pocket(builder):
    """Tall, narrow bin with leaning sides and a lip along the back to hook over the pocket."""
    builder.tray((0.17, 0.075, 0.14), 0.007, COLOUR, taper=0.012, chamfer=0.004)
    builder.box((0.12, 0.014, 0.016), (0, 0.044, 0.132), COLOUR)


def _bike_light_mount(builder):
    """Ring that clamps round the handlebar with a pinch bolt below and a shoe for the light on top."""
    print_shapes.hoop(builder, 0.024, 0.01, 0.03, (0, 0, 0.045))
    builder.box((0.018, 0.03, 0.016), (0, 0, 0.008), COLOUR)
    builder.cylinder(0.006, 0.04, (0, 0, 0.008), COLOUR, segments=6, axis="X")
    builder.box((0.04, 0.03, 0.008), (0, 0, 0.078), COLOUR)
    builder.box((0.024, 0.03, 0.008), (0, 0, 0.086), COLOUR)
    builder.enlarge(1.3)


def _bike_bottle_cage(builder):
    """Bottle cage standing upright: a spine, a ring for the base of the bottle and two arms that wrap round it."""
    builder.box((0.03, 0.01, 0.17), (0, 0.04, 0.085), COLOUR)
    builder.shell(0.042, 0.016, 0.007, COLOUR, segments=8, centre=(0, 0, 0.0), turn=math.pi / 8)
    for side in (-1, 1):
        print_shapes.strut(builder, (side * 0.012, 0.04, 0.12), (side * 0.045, 0.0, 0.11), 0.01)
        print_shapes.strut(builder, (side * 0.045, 0.0, 0.11), (side * 0.02, -0.04, 0.085), 0.01)
    builder.box((0.03, 0.02, 0.01), (0, 0.03, 0.165), COLOUR)


def _bike_phone_mount(builder):
    """Handlebar clamp ring carrying a flat phone plate with a claw at each end."""
    print_shapes.hoop(builder, 0.022, 0.01, 0.03, (0, 0, 0.029))
    builder.box((0.02, 0.03, 0.02), (0, 0, 0.063), COLOUR)
    builder.box((0.07, 0.13, 0.008), (0, 0, 0.077), COLOUR, bevel=0.003)
    for side in (-1, 1):
        builder.box((0.04, 0.008, 0.016), (0, side * 0.064, 0.087), COLOUR)


def _bike_wall_hanger(builder):
    """Wall plate with a thick arm reaching out, braced underneath and turned up at the end."""
    builder.box((0.085, 0.012, 0.15), (0, 0.07, 0.075), COLOUR, bevel=0.004)
    builder.box((0.03, 0.14, 0.03), (0, 0.0, 0.11), COLOUR)
    builder.box((0.03, 0.02, 0.035), (0, -0.06, 0.142), COLOUR)
    print_shapes.strut(builder, (0, 0.064, 0.03), (0, -0.02, 0.1), 0.018)


def _valve_caps_x4(builder):
    """Four tyre valve caps: a six-sided body with a domed top."""
    for x, y in print_shapes.grid(2, 2, 0.03, 0.03):
        builder.cylinder(0.009, 0.014, (x, y, 0.007), COLOUR, segments=6)
        builder.cylinder(0.009, 0.006, (x, y, 0.017), COLOUR, segments=6, radius_top=0.004)
    builder.enlarge(1.6)


def _seat_belt_buckle_guard(builder):
    """Open-topped sleeve that slips over a buckle, with a raised pad over the release button."""
    builder.tray((0.065, 0.04, 0.085), 0.006, COLOUR, chamfer=0.004)
    builder.box((0.036, 0.006, 0.03), (0, -0.022, 0.05), COLOUR)
    builder.enlarge(1.3)


def _car_key_fob_shell(builder):
    """Rounded key fob case lying flat, with three buttons and a loop for the key ring."""
    builder.box((0.045, 0.08, 0.016), (0, 0, 0.008), COLOUR, bevel=0.006, bevel_segments=2)
    for y in (-0.02, 0.0, 0.02):
        builder.box((0.022, 0.012, 0.004), (0, y, 0.017), COLOUR)
    builder.shell(0.011, 0.008, 0.004, COLOUR, segments=6, centre=(0, 0.047, 0.004), open_base=True)
    builder.enlarge(1.4)


def _motorbike_mirror_spacer(builder):
    """Stepped spacer standing on end: a hex base, a round body and a narrower threaded neck."""
    builder.cylinder(0.02, 0.012, (0, 0, 0.006), COLOUR, segments=6)
    builder.cylinder(0.016, 0.03, (0, 0, 0.027), COLOUR, segments=8)
    builder.cylinder(0.011, 0.018, (0, 0, 0.051), COLOUR, segments=8)
    builder.enlarge(1.6)


VARIANTS = {
    "car_phone_mount": _car_phone_mount,
    "car_cup_holder_adapter": _car_cup_holder_adapter,
    "car_hook_for_headrest_x2": _car_hook_for_headrest_x2,
    "sunglasses_visor_clip": _sunglasses_visor_clip,
    "bin_for_car_door_pocket": _bin_for_car_door_pocket,
    "bike_light_mount": _bike_light_mount,
    "bike_bottle_cage": _bike_bottle_cage,
    "bike_phone_mount": _bike_phone_mount,
    "bike_wall_hanger": _bike_wall_hanger,
    "valve_caps_x4": _valve_caps_x4,
    "seat_belt_buckle_guard": _seat_belt_buckle_guard,
    "car_key_fob_shell": _car_key_fob_shell,
    "motorbike_mirror_spacer": _motorbike_mirror_spacer,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
