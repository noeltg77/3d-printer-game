"""Printed item generator for the Desk and office category.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_desk.py -- \
    --variant tablet_stand --out assets/models/prints/tablet_stand.glb
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


def _tablet_stand(builder):
    """Tall easel: base, front lip and a steep back rest."""
    print_shapes.easel(builder, 0.18, 0.17, 0.2, lean=20.0, lip=0.035)


def _business_card_holder(builder):
    """Small sloping holder: a low front and a taller back with one slot between."""
    print_shapes.slot_rack(builder, 0.14, 0.075, (0.03, 0.065), lean=14.0, base=0.012, panel=0.01)


def _cable_management_clips_x12(builder):
    """Twelve tiny wedge-topped clips in three rows."""
    for x, y in print_shapes.grid(4, 3, 0.034, 0.034):
        builder.box((0.024, 0.024, 0.016), (x, y, 0.008), COLOUR, taper=(1.0, 0.4))


def _webcam_cover_slider_x3(builder):
    """Three flat sliders, each a thin plate with a raised cover pushed to one side."""
    for x, y in print_shapes.grid(1, 3, 0, 0.04):
        builder.box((0.07, 0.026, 0.005), (x, y, 0.0025), COLOUR)
        builder.box((0.03, 0.03, 0.01), (x + 0.016, y, 0.005), COLOUR)


def _paper_tray_stackable(builder):
    """Wide shallow letter tray with a post at each corner for the next tray to sit on."""
    builder.tray((0.28, 0.22, 0.055), 0.009, COLOUR, chamfer=0.004)
    for x, y in print_shapes.grid(2, 2, 0.262, 0.202):
        builder.box((0.018, 0.018, 0.085), (x, y, 0.0425), COLOUR)


def _keyboard_wrist_rest_frame(builder):
    """Long, low, shallow frame that a gel pad drops into."""
    builder.tray((0.3, 0.085, 0.022), 0.007, COLOUR, floor=0.006, chamfer=0.004)


def _mouse_bungee(builder):
    """Weighted round base with a leaning arm and a fork at the top that holds the cable."""
    builder.cylinder(0.05, 0.016, (0, 0, 0.008), COLOUR, segments=10, radius_top=0.044)
    builder.box((0.014, 0.014, 0.12), (0, 0.012, 0.072), COLOUR, rotation=(math.radians(-14), 0, 0))
    builder.box((0.04, 0.014, 0.012), (0, 0.027, 0.133), COLOUR)
    for side in (-1, 1):
        builder.box((0.01, 0.014, 0.02), (side * 0.015, 0.027, 0.147), COLOUR)


def _planner_stand(builder):
    """Wide, laid-back easel for an open planner."""
    print_shapes.easel(builder, 0.24, 0.16, 0.13, lean=32.0, lip=0.025)


def _stapler_dock(builder):
    """Long cradle for the stapler with a small compartment for staples at one end."""
    builder.tray((0.18, 0.07, 0.038), 0.007, COLOUR, chamfer=0.004)
    builder.box((0.006, 0.063, 0.034), (0.045, 0, 0.017), COLOUR)


def _desk_lamp_shade(builder):
    """Faceted cone shade, wide end down, with a collar for the lamp fitting."""
    builder.cylinder(0.115, 0.13, (0, 0, 0.065), COLOUR, segments=8, radius_top=0.05)
    builder.cylinder(0.04, 0.03, (0, 0, 0.145), COLOUR, segments=8)


def _bulldog_clip_display_wall(builder):
    """Upright board on a foot with two rows of pegs for hanging clips."""
    builder.box((0.22, 0.07, 0.012), (0, 0, 0.006), COLOUR)
    builder.box((0.22, 0.014, 0.17), (0, 0.02, 0.095), COLOUR, bevel=0.004)
    for x, z in print_shapes.grid(3, 2, 0.065, 0.065):
        builder.box((0.014, 0.026, 0.012), (x, 0.002, 0.1 + z), COLOUR)


def _ruler_and_template_set(builder):
    """Flat set as it comes off the bed: a ruler, a set square and a circle template."""
    builder.box((0.2, 0.03, 0.005), (0, -0.045, 0.0025), COLOUR)
    builder.cylinder(0.055, 0.005, (-0.05, 0.03, 0.0025), COLOUR, segments=3, rotation=(0, 0, math.radians(90)))
    builder.cylinder(0.042, 0.005, (0.055, 0.025, 0.0025), COLOUR, segments=10)


# Desk and office, Spare room tier

def _monitor_stand_riser(builder):
    """Wide platform on two side panels, with a shelf underneath for the keyboard."""
    builder.box((0.3, 0.19, 0.014), (0, 0, 0.097), COLOUR, bevel=0.004)
    for side in (-1, 1):
        builder.box((0.014, 0.17, 0.092), (side * 0.135, 0, 0.046), COLOUR)
    builder.box((0.258, 0.15, 0.008), (0, 0.005, 0.03), COLOUR)


def _laptop_riser(builder):
    """Open frame that lifts and tilts a laptop: a U-shaped foot, two rising arms and a cradle bar with a lip each end."""
    for side in (-1, 1):
        x = side * 0.1
        builder.box((0.018, 0.2, 0.012), (x, 0, 0.006), COLOUR)
        print_shapes.strut(builder, (x, -0.09, 0.01), (x, 0.075, 0.11), 0.016)
        builder.box((0.018, 0.014, 0.03), (x, -0.094, 0.025), COLOUR)
    builder.box((0.218, 0.018, 0.012), (0, 0.09, 0.006), COLOUR)
    builder.box((0.218, 0.016, 0.016), (0, 0.075, 0.108), COLOUR)


def _under_desk_headphone_hook(builder):
    """Plate that screws up under a desk, with an arm dropping down and curling forward into a hook."""
    builder.box((0.06, 0.05, 0.007), (0, 0.01, 0.0865), COLOUR)
    builder.box((0.03, 0.01, 0.08), (0, 0.03, 0.045), COLOUR)
    builder.box((0.03, 0.06, 0.01), (0, 0.005, 0.005), COLOUR)
    builder.box((0.03, 0.01, 0.03), (0, -0.02, 0.02), COLOUR)


def _desk_drawer_bolt_on(builder):
    """Sleeve that bolts under a desk with a drawer pulled part way out of it."""
    builder.box((0.26, 0.18, 0.008), (0, 0.02, 0.066), COLOUR)
    for side in (-1, 1):
        builder.box((0.008, 0.18, 0.066), (side * 0.126, 0.02, 0.033), COLOUR)
    builder.tray((0.24, 0.17, 0.05), 0.006, COLOUR, centre=(0, -0.03, 0.004))
    builder.box((0.07, 0.012, 0.014), (0, -0.12, 0.03), COLOUR)


def _desk_clamp_cup_holder(builder):
    """C clamp for the edge of a desk carrying a round cup holder out to one side."""
    builder.box((0.05, 0.06, 0.01), (-0.07, 0, 0.06), COLOUR)
    builder.box((0.05, 0.01, 0.06), (-0.07, 0.025, 0.03), COLOUR)
    builder.box((0.05, 0.06, 0.01), (-0.07, 0, 0.005), COLOUR)
    builder.cylinder(0.007, 0.03, (-0.07, -0.008, 0.018), COLOUR, segments=6)
    builder.shell(0.05, 0.06, 0.006, COLOUR, segments=10, centre=(0.03, 0, 0))
    builder.box((0.03, 0.03, 0.01), (-0.035, 0, 0.055), COLOUR)


VARIANTS = {
    "tablet_stand": _tablet_stand,
    "business_card_holder": _business_card_holder,
    "cable_management_clips_x12": _cable_management_clips_x12,
    "webcam_cover_slider_x3": _webcam_cover_slider_x3,
    "paper_tray_stackable": _paper_tray_stackable,
    "keyboard_wrist_rest_frame": _keyboard_wrist_rest_frame,
    "mouse_bungee": _mouse_bungee,
    "planner_stand": _planner_stand,
    "stapler_dock": _stapler_dock,
    "desk_lamp_shade": _desk_lamp_shade,
    "bulldog_clip_display_wall": _bulldog_clip_display_wall,
    "ruler_and_template_set": _ruler_and_template_set,
    "monitor_stand_riser": _monitor_stand_riser,
    "laptop_riser": _laptop_riser,
    "under_desk_headphone_hook": _under_desk_headphone_hook,
    "desk_drawer_bolt_on": _desk_drawer_bolt_on,
    "desk_clamp_cup_holder": _desk_clamp_cup_holder,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
