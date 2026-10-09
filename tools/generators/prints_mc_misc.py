"""Printed item generator for multicolour designs: home, desk, kitchen, bathroom, garden,
tech, pets, automotive, maker parts, music, accessibility, film, model railway and sports.

Same rules as prints_multicolour.py: a mesh per colour, built through `Parts`.
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
import print_shapes
import prints_multicolour
from print_shapes import COLOUR


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), required=True)


def build(args, rng):
    build_item(args.variant, args.out.stem)


def build_item(variant, name, preview=False):
    return prints_multicolour.build_from(VARIANTS, variant, name, preview)


def _washi_tape_dispenser(parts):
    """Base with two cheeks and a front cutter bar; the roller with its two dividers and the cutter edge are the second colour."""
    parts.main.box((0.2, 0.1, 0.012), (0, 0, 0.006), COLOUR, bevel=0.003)
    for x in (-0.094, 0.094):
        parts.main.box((0.012, 0.07, 0.066), (x, 0.012, 0.043), COLOUR, taper=(1.0, 0.6))
    parts.main.box((0.2, 0.01, 0.026), (0, -0.045, 0.023), COLOUR)
    roller = parts.colour(2)
    roller.cylinder(0.022, 0.176, (0, 0.012, 0.05), COLOUR, segments=8, axis="X")
    for x in (-0.03, 0.03):
        roller.cylinder(0.032, 0.008, (x, 0.012, 0.05), COLOUR, segments=8, axis="X")
    roller.box((0.19, 0.005, 0.008), (0, -0.045, 0.039), COLOUR)


def _bookends_pair(parts):
    """Two L shaped bookends side by side, each with a brace, a diamond badge on its face and a cap strip in the second colour."""
    for side in (-1, 1):
        x = side * 0.056
        parts.main.box((0.09, 0.09, 0.008), (x, 0, 0.004), COLOUR)
        parts.main.box((0.09, 0.01, 0.13), (x, 0.04, 0.065), COLOUR)
        print_shapes.strut(parts.main, (x + side * 0.034, 0.036, 0.085), (x + side * 0.034, -0.03, 0.008), 0.012)
        trim = parts.colour(2)
        trim.box((0.036, 0.005, 0.036), (x - side * 0.008, 0.0345, 0.08), COLOUR, rotation=(0, math.pi / 4, 0))
        trim.box((0.09, 0.014, 0.006), (x, 0.04, 0.133), COLOUR)


def _calendar_block_perpetual(parts):
    """Stand with two date cubes on it; the numerals on the cubes and the month bar in front are the second colour."""
    parts.main.box((0.19, 0.08, 0.018), (0, 0, 0.009), COLOUR, bevel=0.003)
    for x in (-0.032, 0.032):
        parts.main.box((0.06, 0.06, 0.06), (x, 0.008, 0.048), COLOUR)
    marks = parts.colour(2)
    marks.box((0.13, 0.016, 0.018), (0, -0.03, 0.027), COLOUR)
    # A "1" on the left cube and a "7" on the right, on the front and again on top.
    marks.box((0.008, 0.004, 0.036), (-0.032, -0.023, 0.048), COLOUR)
    marks.box((0.026, 0.004, 0.008), (0.032, -0.023, 0.062), COLOUR)
    marks.box((0.008, 0.004, 0.036), (0.041, -0.023, 0.048), COLOUR)
    marks.box((0.008, 0.036, 0.003), (-0.032, 0.008, 0.079), COLOUR)
    marks.box((0.026, 0.008, 0.003), (0.032, 0.022, 0.079), COLOUR)
    marks.box((0.008, 0.036, 0.003), (0.041, 0.008, 0.079), COLOUR)


def _egg_cup_set_x4(parts):
    """Four flared hexagonal egg cups, each standing on a wide saucer foot in the second colour."""
    for x, y in print_shapes.grid(2, 2, 0.086, 0.086):
        parts.colour(2).cylinder(0.04, 0.008, (x, y, 0.004), COLOUR, segments=6)
        parts.main.shell(0.02, 0.05, 0.005, COLOUR, segments=6, centre=(x, y, 0.008), radius_top=0.031)


def _makeup_brush_holder(parts):
    """Three hexagonal tubes of different heights in a cluster, on a round base plate in the second colour."""
    parts.colour(2).cylinder(0.098, 0.01, (0, 0, 0.005), COLOUR, segments=8)
    for (x, y), height in zip(((0, 0.042), (-0.0364, -0.021), (0.0364, -0.021)), (0.15, 0.115, 0.085)):
        parts.main.shell(0.042, height, 0.005, COLOUR, segments=6, centre=(x, y, 0.01))


def _wind_spinner(parts):
    """Flat wheel: an outer ring, hub and hanging tab, with six tilted vanes between them alternating two more colours."""
    parts.main.shell(0.12, 0.014, 0.02, COLOUR, segments=10, open_base=True)
    parts.main.cylinder(0.032, 0.02, (0, 0, 0.01), COLOUR, segments=8)
    parts.main.box((0.024, 0.03, 0.008), (0, 0.128, 0.004), COLOUR)
    for index in range(6):
        angle = math.tau * index / 6 + math.pi / 6
        centre = (0.064 * math.cos(angle), 0.064 * math.sin(angle), 0.012)
        parts.colour(2 + index % 2).box((0.07, 0.042, 0.004), centre, COLOUR, rotation=(0.4, 0, angle))


def _raspberry_pi_case(parts):
    """Small computer case: a bevelled box with vent slats and a fan grille on the lid and three ports on the front in the second colour."""
    parts.main.box((0.18, 0.125, 0.05), (0, 0, 0.025), COLOUR, bevel=0.005)
    detail = parts.colour(2)
    for y in (-0.033, -0.011, 0.011, 0.033):
        detail.box((0.07, 0.011, 0.004), (-0.04, y, 0.0505), COLOUR)
    detail.cylinder(0.03, 0.004, (0.045, 0, 0.0505), COLOUR, segments=6)
    detail.box((0.03, 0.005, 0.02), (-0.055, -0.0625, 0.024), COLOUR)
    detail.box((0.03, 0.005, 0.02), (-0.015, -0.0625, 0.024), COLOUR)
    detail.box((0.045, 0.005, 0.012), (0.045, -0.0625, 0.02), COLOUR)


def _charging_station_dock(parts):
    """Base with three leaning dividers and a watch post; slot liners, a round charging pad and the post's disc are the second colour."""
    parts.main.box((0.27, 0.15, 0.02), (0, 0, 0.01), COLOUR, bevel=0.004)
    for y, height in ((-0.035, 0.045), (0.01, 0.06), (0.055, 0.075)):
        parts.main.box((0.15, 0.012, height), (-0.05, y, 0.018 + height / 2), COLOUR, rotation=(-0.17, 0, 0))
    parts.main.box((0.04, 0.03, 0.06), (0.085, 0.045, 0.049), COLOUR)
    pads = parts.colour(2)
    for y in (-0.016, 0.03):
        pads.box((0.14, 0.022, 0.003), (-0.05, y, 0.0205), COLOUR)
    pads.cylinder(0.036, 0.006, (0.085, -0.028, 0.022), COLOUR, segments=8)
    pads.cylinder(0.016, 0.006, (0.085, 0.029, 0.058), COLOUR, segments=8, axis="Y")


def _pet_name_tag(parts):
    """Bone shaped tag lying flat with an eyelet at the top and four raised letters in the second colour."""
    parts.main.box((0.08, 0.036, 0.008), (0, 0, 0.004), COLOUR)
    for x in (-0.042, 0.042):
        for y in (-0.016, 0.016):
            parts.main.cylinder(0.02, 0.008, (x, y, 0.004), COLOUR, segments=6)
    parts.main.shell(0.013, 0.008, 0.004, COLOUR, segments=6, centre=(0, 0.028, 0), open_base=True)
    for x, width in ((-0.027, 0.012), (-0.009, 0.009), (0.008, 0.013), (0.026, 0.01)):
        parts.colour(2).box((width, 0.022, 0.003), (x, 0, 0.0095), COLOUR)


def _cat_toy_ball(parts):
    """Faceted ball with six round studs in the second colour, one on top and five around the shoulder, standing for the holes that show the rattle."""
    radius = 0.06
    parts.main.ball(radius, (0, 0, radius), COLOUR, subdivisions=2)
    directions = [(0.0, 0.0, 1.0)]
    for index in range(5):
        angle = -math.pi / 2 + math.tau * index / 5
        directions.append((math.cos(angle) * 0.9, math.sin(angle) * 0.9, 0.436))
    for x, y, z in directions:
        print_shapes.limb(
            parts.colour(2), (x * 0.05, y * 0.05, radius + z * 0.05), (x * 0.064, y * 0.064, radius + z * 0.064), 0.017, segments=5)


def _gear_knob_custom(parts):
    """Squat round knob on a tapered collar, with a shift pattern on top and a ring round the collar in the second colour."""
    parts.main.cylinder(0.032, 0.06, (0, 0, 0.03), COLOUR, segments=8, radius_top=0.024)
    parts.main.ball(0.08, (0, 0, 0.115), COLOUR, subdivisions=2, scale=(1.0, 1.0, 0.75))
    inlay = parts.colour(2)
    inlay.cylinder(0.037, 0.012, (0, 0, 0.012), COLOUR, segments=8)
    for x in (-0.03, 0, 0.03):
        inlay.box((0.007, 0.052, 0.012), (x, 0, 0.1715), COLOUR)
    inlay.box((0.066, 0.007, 0.012), (0, 0, 0.1715), COLOUR)


def _knob_set_potentiometer_x6(parts):
    """Six small tapered knobs in a grid, each with a pointer line on top in the second colour."""
    for x, y in print_shapes.grid(3, 2, 0.046, 0.046):
        parts.main.cylinder(0.019, 0.024, (x, y, 0.012), COLOUR, segments=6, radius_top=0.015)
        parts.colour(2).box((0.006, 0.017, 0.003), (x, y - 0.006, 0.025), COLOUR)


def _ukulele(parts):
    """Ukulele lying on its back: two round bouts, neck and headstock, with the fretboard, sound hole, bridge and four pegs in the second colour."""
    parts.main.cylinder(0.064, 0.035, (0, -0.098, 0.0175), COLOUR, segments=10)
    parts.main.cylinder(0.05, 0.035, (0, -0.02, 0.0175), COLOUR, segments=10)
    parts.main.box((0.03, 0.11, 0.035), (0, 0.075, 0.0175), COLOUR)
    parts.main.box((0.044, 0.04, 0.022), (0, 0.145, 0.011), COLOUR, taper=(1.0, 0.9))
    trim = parts.colour(2)
    trim.box((0.024, 0.126, 0.004), (0, 0.062, 0.0365), COLOUR)
    trim.cylinder(0.02, 0.003, (0, -0.036, 0.036), COLOUR, segments=8)
    trim.box((0.05, 0.012, 0.007), (0, -0.115, 0.038), COLOUR)
    for x in (-0.013, 0.013):
        for y in (0.136, 0.154):
            trim.box((0.01, 0.01, 0.008), (x, y, 0.025), COLOUR)


def _pill_organiser_weekly(parts):
    """Row of seven compartments with a lid each in the second colour: four shut, three standing open at the back."""
    size = (0.25, 0.05, 0.03)
    print_shapes.divided_tray(parts.main, size, 0.004, across=6)
    pitch = (size[0] - 0.004) / 7
    for index in range(7):
        x = (index - 3) * pitch
        if index < 4:
            parts.colour(2).box((pitch - 0.004, 0.046, 0.004), (x, 0, 0.032), COLOUR)
        else:
            parts.colour(2).box((pitch - 0.004, 0.004, 0.046), (x, 0.034, 0.05), COLOUR, rotation=(-0.3, 0, 0))


def _slate_clapperboard(parts):
    """Clapperboard lying flat with its stick swung open; the diagonal stripes on both sticks and three writing lines are the second colour."""
    parts.main.box((0.2, 0.13, 0.008), (0, -0.02, 0.004), COLOUR)
    parts.main.box((0.2, 0.024, 0.012), (0, 0.057, 0.006), COLOUR)
    swing = 0.21
    along = (math.cos(swing), math.sin(swing))
    across = (-along[1], along[0])
    hinge = (-0.1, 0.071)

    def on_stick(distance):
        return (hinge[0] + along[0] * distance + across[0] * 0.012, hinge[1] + along[1] * distance + across[1] * 0.012)

    x, y = on_stick(0.1)
    parts.main.box((0.2, 0.024, 0.012), (x, y, 0.006), COLOUR, rotation=(0, 0, swing))
    marks = parts.colour(2)
    for index in range(4):
        marks.box((0.018, 0.018, 0.003), (-0.075 + index * 0.05, 0.057, 0.0135), COLOUR, rotation=(0, 0, 0.5))
        x, y = on_stick(0.025 + index * 0.05)
        marks.box((0.018, 0.018, 0.003), (x, y, 0.0135), COLOUR, rotation=(0, 0, swing + 0.5))
    for y in (-0.005, -0.038, -0.071):
        marks.box((0.16, 0.006, 0.003), (0, y, 0.0085), COLOUR)


def _oo_gauge_station_building(parts):
    """Station building on a platform slab with two chimneys; the pitched roof, door and four windows are the second colour."""
    parts.main.box((0.28, 0.14, 0.008), (0, -0.012, 0.004), COLOUR)
    parts.main.box((0.24, 0.09, 0.075), (0, 0, 0.0455), COLOUR)
    for x in (-0.07, 0.07):
        parts.main.box((0.022, 0.022, 0.045), (x, 0.012, 0.118), COLOUR)
    trim = parts.colour(2)
    trim.box((0.26, 0.11, 0.04), (0, 0, 0.103), COLOUR, taper=(1.0, 0.05))
    for x in (-0.09, -0.045, 0.045, 0.09):
        trim.box((0.028, 0.005, 0.03), (x, -0.0455, 0.052), COLOUR)
    trim.box((0.03, 0.005, 0.052), (0, -0.0455, 0.034), COLOUR)


def _model_railway_signals_x4(parts):
    """Four semaphore signals lying flat in a row: a post, foot and lamp block each, with the arm in the second colour."""
    for index, (x, _) in enumerate(print_shapes.grid(4, 1, 0.044, 0)):
        x -= 0.008
        parts.main.box((0.01, 0.13, 0.008), (x, 0, 0.004), COLOUR)
        parts.main.box((0.026, 0.02, 0.01), (x, -0.06, 0.005), COLOUR)
        parts.main.box((0.016, 0.022, 0.012), (x, 0.05, 0.006), COLOUR)
        tilt = 0.5 if index % 2 else 0.0
        centre = (x + 0.012 * math.cos(tilt), 0.05 + 0.012 * math.sin(tilt), 0.0135)
        parts.colour(2).box((0.04, 0.012, 0.004), centre, COLOUR, rotation=(0, 0, tilt))


def _miniature_trees_x10(parts):
    """Ten upright fir trees in two rows: pyramid canopies of varying height on tapered square bases in the second colour."""
    for index, (x, y) in enumerate(print_shapes.grid(5, 2, 0.052, 0.058)):
        height = 0.065 + 0.012 * ((index * 3) % 4)
        parts.colour(2).cylinder(0.026, 0.028, (x, y, 0.014), COLOUR, segments=4, radius_top=0.015)
        parts.main.cylinder(
            0.021, height, (x, y, 0.026 + height / 2), COLOUR, segments=4, radius_top=0.002, rotation=(0, 0, math.pi / 4))


def _level_crossing_set(parts):
    """Road deck with ramped edges, two barrier posts and two rests; the pair of rails and the two barrier arms are the second colour."""
    parts.main.box((0.2, 0.15, 0.008), (0, 0, 0.004), COLOUR, taper=(1.0, 0.85))
    trim = parts.colour(2)
    for y in (-0.02, 0.02):
        trim.box((0.2, 0.007, 0.005), (0, y, 0.009), COLOUR)
    for side in (-1, 1):
        parts.main.box((0.016, 0.016, 0.06), (side * 0.088, side * 0.05, 0.03), COLOUR)
        parts.main.box((0.01, 0.014, 0.046), (-side * 0.06, side * 0.05, 0.023), COLOUR)
        trim.box((0.16, 0.009, 0.012), (side * 0.016, side * 0.05, 0.05), COLOUR)


def _shop_front_kit(parts):
    """Upright shop facade on a pavement strip with pilasters and a cornice; the sign, awning, window and door are the second colour."""
    parts.main.box((0.2, 0.07, 0.008), (0, -0.005, 0.004), COLOUR)
    parts.main.box((0.19, 0.02, 0.14), (0, 0.015, 0.078), COLOUR)
    parts.main.box((0.2, 0.03, 0.01), (0, 0.012, 0.153), COLOUR)
    for x in (-0.087, 0.087):
        parts.main.box((0.016, 0.008, 0.1), (x, 0.003, 0.058), COLOUR)
    trim = parts.colour(2)
    trim.box((0.155, 0.008, 0.02), (0, 0.003, 0.134), COLOUR)
    trim.box((0.085, 0.005, 0.06), (-0.03, 0.0035, 0.05), COLOUR)
    trim.box((0.04, 0.005, 0.078), (0.05, 0.0035, 0.047), COLOUR)
    trim.box((0.155, 0.038, 0.004), (0, -0.011, 0.094), COLOUR, rotation=(0.45, 0, 0))


def _medal_hanger_custom(parts):
    """Long back plate lying flat with five hooks along the front edge and a row of raised letters in the second colour."""
    parts.main.box((0.28, 0.08, 0.01), (0, 0, 0.005), COLOUR, taper=0.97)
    for x, _ in print_shapes.grid(5, 1, 0.056, 0):
        parts.main.box((0.014, 0.012, 0.03), (x, -0.022, 0.024), COLOUR)
        parts.main.box((0.014, 0.022, 0.007), (x, -0.027, 0.0395), COLOUR)
    for index, width in enumerate((0.026, 0.018, 0.028, 0.02, 0.026, 0.018, 0.024)):
        parts.colour(2).box((width, 0.03, 0.004), ((index - 3) * 0.036, 0.016, 0.0115), COLOUR)


def _golf_ball_marker_set(parts):
    """Four flat round markers: two with a hexagon inlay and two with a slanted stripe, in the second colour."""
    for index, (x, y) in enumerate(print_shapes.grid(2, 2, 0.054, 0.054)):
        parts.main.cylinder(0.023, 0.005, (x, y, 0.0025), COLOUR, segments=8)
        if index in (0, 3):
            parts.colour(2).cylinder(0.013, 0.003, (x, y, 0.006), COLOUR, segments=6)
        else:
            parts.colour(2).box((0.034, 0.009, 0.003), (x, y, 0.006), COLOUR, rotation=(0, 0, math.pi / 4))


VARIANTS = {
    "washi_tape_dispenser": _washi_tape_dispenser,
    "bookends_pair": _bookends_pair,
    "calendar_block_perpetual": _calendar_block_perpetual,
    "egg_cup_set_x4": _egg_cup_set_x4,
    "makeup_brush_holder": _makeup_brush_holder,
    "wind_spinner": _wind_spinner,
    "raspberry_pi_case": _raspberry_pi_case,
    "charging_station_dock": _charging_station_dock,
    "pet_name_tag": _pet_name_tag,
    "cat_toy_ball": _cat_toy_ball,
    "gear_knob_custom": _gear_knob_custom,
    "knob_set_potentiometer_x6": _knob_set_potentiometer_x6,
    "ukulele": _ukulele,
    "pill_organiser_weekly": _pill_organiser_weekly,
    "slate_clapperboard": _slate_clapperboard,
    "oo_gauge_station_building": _oo_gauge_station_building,
    "model_railway_signals_x4": _model_railway_signals_x4,
    "miniature_trees_x10": _miniature_trees_x10,
    "level_crossing_set": _level_crossing_set,
    "shop_front_kit": _shop_front_kit,
    "medal_hanger_custom": _medal_hanger_custom,
    "golf_ball_marker_set": _golf_ball_marker_set,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
