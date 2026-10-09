"""Printed item generator for the Replacement parts category of the Spare room tier.
(The three Garage replacement parts are in prints_small.py.)

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_replacement.py -- \
    --variant appliance_knob --out assets/models/prints/appliance_knob.glb
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


def _appliance_knob(builder):
    """Round control knob: a wide skirt, a tapering grip and a pointer ridge across the top."""
    builder.cylinder(0.034, 0.008, (0, 0, 0.004), COLOUR, segments=10)
    builder.cylinder(0.027, 0.026, (0, 0, 0.021), COLOUR, segments=10, radius_top=0.022)
    builder.box((0.008, 0.044, 0.008), (0, 0, 0.036), COLOUR)
    builder.enlarge(1.5)


def _washing_machine_drawer_handle(builder):
    """Long front panel standing on edge, with a finger lip along the bottom and three clips behind."""
    builder.box((0.19, 0.012, 0.055), (0, -0.01, 0.0275), COLOUR, bevel=0.004)
    builder.box((0.15, 0.02, 0.008), (0, -0.024, 0.008), COLOUR)
    for x, _ in print_shapes.grid(3, 1, 0.07, 0):
        builder.box((0.014, 0.024, 0.02), (x, 0.008, 0.03), COLOUR, taper=(1.0, 0.5))


def _fridge_shelf_clip(builder):
    """C-shaped clip with a tab on the back to pull it off by."""
    builder.box((0.05, 0.03, 0.008), (0, 0, 0.004), COLOUR)
    builder.box((0.008, 0.03, 0.035), (-0.021, 0, 0.0215), COLOUR)
    builder.box((0.05, 0.03, 0.008), (0, 0, 0.039), COLOUR)
    builder.box((0.02, 0.03, 0.006), (-0.033, 0, 0.02), COLOUR)
    builder.enlarge(1.6)


def _dishwasher_wheel_x4(builder):
    """Four small basket wheels lying flat, each with a raised hub."""
    for x, y in print_shapes.grid(2, 2, 0.055, 0.055):
        builder.cylinder(0.023, 0.012, (x, y, 0.006), COLOUR, segments=8)
        builder.cylinder(0.01, 0.008, (x, y, 0.016), COLOUR, segments=6)


def _vacuum_cleaner_clip(builder):
    """Sprung ring, open at the top, on a mounting block: the tube snaps in."""
    builder.box((0.05, 0.03, 0.014), (0, 0, 0.007), COLOUR)
    print_shapes.hoop(builder, 0.026, 0.008, 0.03, (0, 0, 0.042), pieces=6, start=math.radians(120), sweep=math.radians(300))
    builder.enlarge(1.5)


def _blind_end_cap(builder):
    """Small rounded cap with a plug that pushes into the end of a rail."""
    builder.box((0.036, 0.026, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    builder.box((0.026, 0.016, 0.02), (0, 0, 0.022), COLOUR)
    builder.enlarge(2.0)


def _window_handle(builder):
    """Lever handle: a long rose plate, a round neck and a lever arm reaching out to one side."""
    builder.box((0.036, 0.085, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    builder.cylinder(0.014, 0.03, (0, 0.02, 0.025), COLOUR, segments=6)
    builder.box((0.14, 0.026, 0.018), (0.055, 0.02, 0.047), COLOUR, bevel=0.006)


def _furniture_foot_pads_x4(builder):
    """Four low round pads."""
    for x, y in print_shapes.grid(2, 2, 0.042, 0.042):
        builder.cylinder(0.017, 0.007, (x, y, 0.0035), COLOUR, segments=8, radius_top=0.014)
    builder.enlarge(1.4)


def _chair_glide_x4(builder):
    """Four chair glides, sole down: a domed foot with a stem that pushes into the leg."""
    for x, y in print_shapes.grid(2, 2, 0.045, 0.045):
        builder.cylinder(0.014, 0.01, (x, y, 0.005), COLOUR, segments=8, radius_top=0.018)
        builder.cylinder(0.008, 0.022, (x, y, 0.021), COLOUR, segments=6)
    builder.enlarge(1.3)


def _drawer_runner_stop_x4(builder):
    """Four small wedge stops, each with a locating peg."""
    for x, y in print_shapes.grid(2, 2, 0.04, 0.04):
        builder.box((0.026, 0.018, 0.012), (x, y, 0.006), COLOUR, taper=(0.4, 1.0))
        builder.box((0.007, 0.007, 0.008), (x, y + 0.012, 0.004), COLOUR)
    builder.enlarge(1.5)


def _lawnmower_height_clip(builder):
    """Flat notched lever with a finger tab one end and a pivot pin the other."""
    builder.plate([(-0.05, -0.012), (0.05, -0.012), (0.05, 0.012), (0.02, 0.012), (0.012, 0.004), (0.004, 0.012),
                   (-0.004, 0.004), (-0.012, 0.012), (-0.05, 0.012)], 0.006, COLOUR)
    builder.cylinder(0.008, 0.016, (-0.04, 0, 0.008), COLOUR, segments=6)
    builder.box((0.014, 0.03, 0.012), (0.05, 0, 0.006), COLOUR)
    builder.enlarge(1.4)


def _game_controller_trigger(builder):
    """Curved trigger blade on a pivot barrel, with a lip at the tip."""
    builder.cylinder(0.008, 0.03, (0, 0.016, 0.007), COLOUR, segments=6, axis="X")
    builder.box((0.026, 0.04, 0.008), (0, -0.004, 0.009), COLOUR, rotation=(math.radians(12), 0, 0))
    builder.box((0.026, 0.008, 0.012), (0, -0.024, 0.011), COLOUR)
    builder.enlarge(2.2)


def _shower_head_bracket(builder):
    """Wall plate with a short arm and a tapered socket the shower handle drops into."""
    builder.box((0.05, 0.012, 0.075), (0, 0.035, 0.0375), COLOUR, bevel=0.004)
    builder.box((0.02, 0.03, 0.02), (0, 0.02, 0.045), COLOUR)
    builder.shell(0.019, 0.034, 0.006, COLOUR, segments=6, centre=(0, -0.012, 0.028), radius_top=0.027, open_base=True)
    builder.enlarge(1.5)


def _kettle_lid_catch(builder):
    """Small latch: a body on two pivot pins with a hooked nose and a thumb tab."""
    builder.box((0.02, 0.05, 0.012), (0, 0, 0.006), COLOUR)
    builder.cylinder(0.005, 0.036, (0, 0.012, 0.006), COLOUR, segments=6, axis="X")
    builder.box((0.02, 0.01, 0.022), (0, -0.022, 0.011), COLOUR, taper=(1.0, 0.4))
    builder.box((0.02, 0.016, 0.006), (0, 0.03, 0.013), COLOUR, rotation=(math.radians(-20), 0, 0))
    builder.enlarge(2.0)


def _pram_buggy_clip(builder):
    """Big hook that hangs bags from a pushchair handle: an open ring under a strap bar."""
    print_shapes.hoop(builder, 0.032, 0.01, 0.022, (0, 0, 0.039), pieces=6, start=math.radians(60), sweep=math.radians(270))
    for side in (-1, 1):
        builder.box((0.008, 0.022, 0.022), (side * 0.02, 0, 0.085), COLOUR)
    builder.box((0.048, 0.022, 0.008), (0, 0, 0.1), COLOUR)
    builder.enlarge(1.3)


VARIANTS = {
    "appliance_knob": _appliance_knob,
    "washing_machine_drawer_handle": _washing_machine_drawer_handle,
    "fridge_shelf_clip": _fridge_shelf_clip,
    "dishwasher_wheel_x4": _dishwasher_wheel_x4,
    "vacuum_cleaner_clip": _vacuum_cleaner_clip,
    "blind_end_cap": _blind_end_cap,
    "window_handle": _window_handle,
    "furniture_foot_pads_x4": _furniture_foot_pads_x4,
    "chair_glide_x4": _chair_glide_x4,
    "drawer_runner_stop_x4": _drawer_runner_stop_x4,
    "lawnmower_height_clip": _lawnmower_height_clip,
    "game_controller_trigger": _game_controller_trigger,
    "shower_head_bracket": _shower_head_bracket,
    "kettle_lid_catch": _kettle_lid_catch,
    "pram_buggy_clip": _pram_buggy_clip,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
