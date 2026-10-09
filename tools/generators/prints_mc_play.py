"""Printed item generator for multicolour designs: gaming and tabletop, toys and fidgets.

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


def _channel(builder, start, end, width=0.032, floor=0.006, wall=0.014):
    """Open ended marble trough between two (x, z) points, running along X."""
    (x1, z1), (x2, z2) = start, end
    length = math.hypot(x2 - x1, z2 - z1)
    slope = math.atan2(z1 - z2, x2 - x1)
    x, z = (x1 + x2) / 2, (z1 + z2) / 2
    builder.box((length, width, floor), (x, 0, z), COLOUR, rotation=(0, slope, 0))
    lift = (floor + wall) / 2 - 0.001
    for side in (-1, 1):
        centre = (x + math.sin(slope) * lift, side * (width / 2 - 0.003), z + math.cos(slope) * lift)
        builder.box((length, 0.006, wall), centre, COLOUR, rotation=(0, slope, 0))


def _dice_tower(parts):
    """Square open-topped tower with a tray in front; battlements, doorway, baffle and exit ramp in the second colour."""
    parts.main.shell(0.0707, 0.2, 0.008, COLOUR, segments=4, centre=(0, 0.06, 0), turn=math.pi / 4)
    parts.main.tray((0.1, 0.122, 0.03), 0.008, COLOUR, centre=(0, -0.049, 0))
    trim = parts.colour(2)
    for x in (-0.041, 0.041):
        for y in (0.019, 0.101):
            trim.box((0.022, 0.022, 0.02), (x, y, 0.208), COLOUR)
    trim.box((0.06, 0.004, 0.07), (0, 0.009, 0.045), COLOUR)
    trim.box((0.08, 0.075, 0.006), (0, -0.03, 0.03), COLOUR, rotation=(math.radians(24), 0, 0))
    trim.box((0.082, 0.07, 0.006), (0, 0.05, 0.165), COLOUR, rotation=(math.radians(-35), 0, 0))


def _dice_tray(parts):
    """Hexagonal rolling tray with a liner in the second colour set into its floor."""
    parts.main.shell(0.115, 0.036, 0.012, COLOUR, segments=6, chamfer=0.004)
    parts.colour(2).shell(0.1, 0.006, 0.004, COLOUR, segments=6, centre=(0, 0, 0.011), floor=0.004)


def _card_deck_box(parts):
    """Deck box printed as two pieces: the open body with a diamond badge, and its lid beside it in the second colour."""
    parts.main.tray((0.1, 0.07, 0.115), 0.007, COLOUR, centre=(-0.058, 0, 0))
    lid = parts.colour(2)
    lid.tray((0.108, 0.078, 0.042), 0.007, COLOUR, centre=(0.058, 0, 0))
    lid.box((0.034, 0.004, 0.034), (-0.058, -0.036, 0.062), COLOUR, rotation=(0, math.pi / 4, 0))


MEEPLE = (
    (-0.022, -0.026), (-0.006, -0.026), (0.0, -0.014), (0.006, -0.026), (0.022, -0.026), (0.014, -0.002),
    (0.027, 0.006), (0.009, 0.012), (0.009, 0.026), (-0.009, 0.026), (-0.009, 0.012), (-0.027, 0.006),
    (-0.014, -0.002),
)


def _token_and_meeple_set(parts):
    """Three flat meeples (two in the first colour, one in the second) and three tokens: triangle, hexagon and square."""
    for index, x in enumerate((-0.062, 0.0, 0.062)):
        parts.colour(2 if index == 2 else 1).plate(MEEPLE, 0.012, COLOUR, centre=(x, 0.03, 0))
    parts.main.cylinder(0.024, 0.008, (-0.06, -0.034, 0.004), COLOUR, segments=3)
    parts.colour(3).cylinder(0.022, 0.008, (0.0, -0.034, 0.004), COLOUR, segments=6)
    parts.colour(4).box((0.036, 0.036, 0.008), (0.062, -0.034, 0.004), COLOUR)


def _initiative_tracker(parts):
    """Long slotted rail with a turn pointer at one end and five name tags standing in it in the second colour."""
    parts.main.box((0.23, 0.05, 0.022), (0, 0, 0.011), COLOUR, bevel=0.004)
    parts.main.box((0.02, 0.05, 0.03), (-0.105, 0, 0.035), COLOUR, taper=(0.3, 1.0))
    for index in range(5):
        x = -0.064 + index * 0.04
        parts.colour(2).box((0.03, 0.008, 0.05), (x, 0.004, 0.045), COLOUR, rotation=(math.radians(-10), 0, 0))


def _damage_counter_dials(parts):
    """Two round dials: a base disc with a pointer block, a turning wheel in the second colour and a centre pin."""
    for x in (-0.046, 0.046):
        parts.main.cylinder(0.042, 0.008, (x, 0, 0.004), COLOUR, segments=8)
        parts.main.box((0.012, 0.014, 0.008), (x, 0.033, 0.012), COLOUR)
        parts.colour(2).cylinder(0.03, 0.006, (x, -0.004, 0.011), COLOUR, segments=6)
        parts.main.cylinder(0.008, 0.01, (x, -0.004, 0.013), COLOUR, segments=6)


def _game_master_screen(parts):
    """Three upright panels, the outer two angled back, each with a raised art panel and a top rail in the second colour."""
    angle = math.radians(35)
    layout = [(0.0, 0.0, 0.14, 0.0)]
    for side in (-1, 1):
        layout.append((side * (0.07 + 0.05 * math.cos(angle)), 0.05 * math.sin(angle), 0.104, side * angle))
    for x, y, length, turn in layout:
        parts.main.box((length, 0.01, 0.13), (x, y, 0.065), COLOUR, rotation=(0, 0, turn))
        nx, ny = math.sin(turn), -math.cos(turn)
        parts.colour(2).box(
            (length - 0.024, 0.006, 0.086), (x + nx * 0.005, y + ny * 0.005, 0.062), COLOUR, rotation=(0, 0, turn))
        parts.colour(2).box((length + 0.002, 0.016, 0.01), (x, y, 0.135), COLOUR, rotation=(0, 0, turn))


def _chess_set(parts):
    """Chess board with the alternate squares in the second colour, and a rook, king and two pawns standing on it."""
    parts.main.box((0.24, 0.24, 0.012), (0, 0, 0.006), COLOUR)
    squares = parts.colour(2)
    cell, top, faces = 0.0275, 0.0135, []
    for row in range(8):
        for column in range(8):
            if (row + column) % 2:
                continue
            x, y = (column - 4) * cell, (row - 4) * cell
            corners = ((x, y), (x + cell, y), (x + cell, y + cell), (x, y + cell))
            faces.append(squares.bm.faces.new([squares.bm.verts.new((cx, cy, top)) for cx, cy in corners]))
    squares.paint(faces, COLOUR)

    def square(column, row):
        return ((column - 3.5) * cell, (row - 3.5) * cell)

    # Rook and pawn in the first colour at the back, king and pawn in the second at the front.
    x, y = square(0, 7)
    parts.main.cylinder(0.013, 0.044, (x, y, 0.034), COLOUR, segments=5, radius_top=0.009)
    parts.main.cylinder(0.014, 0.014, (x, y, 0.063), COLOUR, segments=5)
    x, y = square(3, 6)
    parts.main.cylinder(0.012, 0.03, (x, y, 0.027), COLOUR, segments=5, radius_top=0.006)
    parts.main.ball(0.011, (x, y, 0.05), COLOUR, subdivisions=1)
    x, y = square(4, 0)
    squares.cylinder(0.013, 0.058, (x, y, 0.041), COLOUR, segments=5, radius_top=0.008)
    squares.box((0.007, 0.007, 0.022), (x, y, 0.079), COLOUR)
    squares.box((0.018, 0.007, 0.007), (x, y, 0.081), COLOUR)
    x, y = square(5, 1)
    squares.cylinder(0.012, 0.03, (x, y, 0.027), COLOUR, segments=5, radius_top=0.006)
    squares.ball(0.011, (x, y, 0.05), COLOUR, subdivisions=1)


def _life_counter_mtg(parts):
    """Flat life counter: a case and cover bar, with two thumb wheels and two number windows in the second colour."""
    parts.main.box((0.15, 0.075, 0.018), (0, 0, 0.009), COLOUR, bevel=0.004)
    parts.main.box((0.15, 0.034, 0.008), (0, 0.016, 0.03), COLOUR)
    wheels = parts.colour(2)
    for x in (-0.037, 0.037):
        wheels.cylinder(0.034, 0.008, (x, -0.014, 0.022), COLOUR, segments=8)
        wheels.box((0.024, 0.018, 0.003), (x, 0.016, 0.0355), COLOUR)


def _puzzle_box(parts):
    """Closed puzzle box with sliding bars and a knob on the lid and a locking strip on the front, in the second colour."""
    parts.main.box((0.17, 0.12, 0.085), (0, 0, 0.0425), COLOUR, bevel=0.005)
    trick = parts.colour(2)
    trick.box((0.11, 0.016, 0.005), (-0.012, 0.028, 0.087), COLOUR)
    trick.box((0.016, 0.07, 0.005), (0.052, 0.0, 0.087), COLOUR)
    trick.box((0.06, 0.016, 0.005), (-0.01, -0.03, 0.087), COLOUR)
    trick.cylinder(0.014, 0.012, (-0.055, -0.03, 0.09), COLOUR, segments=6)
    trick.box((0.1, 0.005, 0.016), (0, -0.0605, 0.05), COLOUR)


def _fidget_slider(parts):
    """Small bar with a stop at each end; the track and the thumb slider on it are in the second colour."""
    parts.main.box((0.12, 0.046, 0.014), (0, 0, 0.007), COLOUR, bevel=0.004)
    for x in (-0.048, 0.048):
        parts.main.box((0.012, 0.034, 0.008), (x, 0, 0.017), COLOUR)
    slider = parts.colour(2)
    slider.box((0.084, 0.012, 0.003), (0, 0, 0.0152), COLOUR)
    slider.box((0.03, 0.032, 0.01), (0.012, 0, 0.0185), COLOUR, taper=0.8)


def _infinity_cube(parts):
    """Eight small cubes laid out flat, two by four, in a chequer of the two colours."""
    for index, (x, y) in enumerate(print_shapes.grid(4, 2, 0.041, 0.041)):
        colour = 1 + (index % 4 + index // 4) % 2
        parts.colour(colour).box((0.039, 0.039, 0.039), (x, y, 0.0195), COLOUR)


def _articulated_snake(parts):
    """Snake lying in a wave: body links alternating two colours, with eyes and a tongue in a third."""
    count = 10
    for index in range(count):
        x = -0.066 + index * 0.019
        y = 0.03 * math.sin(index * 0.75)
        turn = math.atan(0.03 * 0.75 / 0.019 * math.cos(index * 0.75))
        thin = 1.0 if index < 6 else 1.0 - (index - 5) * 0.16
        size = (0.021, 0.028 * thin, 0.022 * thin)
        parts.colour(1 + index % 2).box(size, (x, y, size[2] / 2), COLOUR, rotation=(0, 0, turn))
    parts.main.box((0.04, 0.036, 0.024), (-0.094, -0.012, 0.012), COLOUR, rotation=(0, 0, 0.5), taper=0.75)
    face = parts.colour(3)
    for side in (-1, 1):
        face.box((0.008, 0.008, 0.005), (-0.097 - side * 0.005, -0.013 + side * 0.009, 0.0255), COLOUR)
    face.box((0.022, 0.007, 0.004), (-0.119, -0.026, 0.002), COLOUR, rotation=(0, 0, 0.5))


def _articulated_lizard(parts):
    """Flat lizard: head, three body links, tapering tail and four splayed legs, with diamonds down the back and eyes in the second colour."""
    marks = parts.colour(2)
    parts.main.box((0.036, 0.03, 0.018), (-0.078, 0, 0.009), COLOUR, taper=0.7)
    for x, width in ((-0.047, 0.034), (-0.02, 0.042), (0.007, 0.036)):
        parts.main.box((0.025, width, 0.02), (x, 0, 0.01), COLOUR)
        marks.box((0.014, 0.014, 0.004), (x, 0, 0.021), COLOUR, rotation=(0, 0, math.pi / 4))
    for x, width in ((0.034, 0.024), (0.06, 0.015), (0.085, 0.008)):
        parts.main.box((0.025, width, width * 0.7), (x, 0, width * 0.35), COLOUR)
    for x in (-0.044, 0.008):
        for side in (-1, 1):
            parts.main.box((0.012, 0.036, 0.01), (x - 0.006, side * 0.03, 0.005), COLOUR, rotation=(0, 0, side * 0.5))
    for side in (-1, 1):
        marks.box((0.007, 0.007, 0.004), (-0.08, side * 0.008, 0.019), COLOUR)


REX_HEAD = (
    (-0.03, -0.02), (0.018, -0.02), (0.018, 0.02), (-0.012, 0.024), (-0.035, 0.012), (-0.035, 0.002),
    (-0.008, -0.004), (-0.03, -0.012),
)


def _flexi_rex(parts):
    """Jointed dinosaur lying on its side: open-jawed head, body and tail links, a leg and an arm, with stripes and an eye in the second colour."""
    thick = 0.026
    parts.main.plate(REX_HEAD, thick, COLOUR, centre=(-0.073, 0.004, 0))
    links = ((-0.04, 0.0, 0.05), (-0.01, 0.0, 0.056), (0.019, 0.0, 0.046), (0.046, 0.003, 0.034),
             (0.07, 0.006, 0.02))
    for index, (x, y, height) in enumerate(links):
        parts.main.box((0.026 if index < 4 else 0.022, height, thick), (x, y, thick / 2), COLOUR)
        if index < 4:
            parts.colour(2).box((0.008, height * 0.7, 0.004), (x, y, thick + 0.001), COLOUR)
    parts.main.box((0.022, 0.04, thick), (-0.006, -0.042, thick / 2), COLOUR)
    parts.main.box((0.038, 0.012, thick), (-0.013, -0.066, thick / 2), COLOUR)
    parts.main.box((0.022, 0.008, thick), (-0.052, -0.027, thick / 2), COLOUR, rotation=(0, 0, 0.5))
    parts.colour(2).box((0.009, 0.009, 0.004), (-0.078, 0.014, thick + 0.001), COLOUR)


def _fidget_gear_spinner(parts):
    """Flat lozenge plate carrying three meshing eight-toothed gears in the second colour, each on a pin."""
    outline = ((-0.075, -0.036), (0.075, -0.036), (0.094, 0.0), (0.075, 0.036), (-0.075, 0.036), (-0.094, 0.0))
    parts.main.plate(outline, 0.008, COLOUR)
    for index, x in enumerate((-0.054, 0.0, 0.054)):
        turn = math.radians(22.5) * (index % 2)
        for extra in (0.0, math.pi / 4):
            parts.colour(2).box((0.038, 0.038, 0.008), (x, 0, 0.012), COLOUR, rotation=(0, 0, turn + extra))
        parts.main.cylinder(0.009, 0.014, (x, 0, 0.015), COLOUR, segments=6)


def _clicker_keyring(parts):
    """Chunky switch block with a keyring loop on one side and a pressable keycap in the second colour."""
    parts.main.box((0.062, 0.062, 0.022), (-0.012, 0, 0.011), COLOUR, bevel=0.004)
    parts.main.shell(0.018, 0.007, 0.006, COLOUR, segments=6, centre=(0.032, 0, 0), open_base=True)
    parts.colour(2).box((0.044, 0.044, 0.016), (-0.012, 0, 0.029), COLOUR, taper=0.78)


def _fidget_octopus(parts):
    """Domed octopus with eight legs splayed flat: the outer link of each leg and the eyes are in the second colour."""
    parts.main.cylinder(0.04, 0.034, (0, 0, 0.017), COLOUR, segments=6, radius_top=0.036)
    parts.main.cylinder(0.036, 0.02, (0, 0, 0.044), COLOUR, segments=6, radius_top=0.016)
    for index in range(8):
        turn = math.radians(22.5 + index * 45)
        cos, sin = math.cos(turn), math.sin(turn)
        parts.main.box((0.032, 0.016, 0.016), (cos * 0.052, sin * 0.052, 0.008), COLOUR, rotation=(0, 0, turn))
        parts.colour(2).box((0.028, 0.012, 0.012), (cos * 0.083, sin * 0.083, 0.006), COLOUR, rotation=(0, 0, turn))
    for x in (-0.014, 0.014):
        parts.colour(2).box((0.012, 0.006, 0.012), (x, -0.036, 0.027), COLOUR)


def _print_in_place_robot(parts):
    """Boxy robot standing upright, with feet, hands, visor, chest panel and antenna in the second colour."""
    trim = parts.colour(2)
    for side in (-1, 1):
        parts.main.box((0.03, 0.034, 0.04), (side * 0.022, 0, 0.03), COLOUR)
        trim.box((0.036, 0.046, 0.012), (side * 0.022, -0.004, 0.006), COLOUR)
        parts.main.box((0.02, 0.03, 0.046), (side * 0.056, 0, 0.087), COLOUR)
        trim.box((0.026, 0.036, 0.016), (side * 0.056, 0, 0.056), COLOUR)
    parts.main.box((0.088, 0.05, 0.062), (0, 0, 0.08), COLOUR)
    parts.main.box((0.066, 0.05, 0.044), (0, 0, 0.136), COLOUR)
    trim.box((0.046, 0.005, 0.014), (0, -0.0265, 0.14), COLOUR)
    trim.box((0.034, 0.005, 0.026), (0, -0.0265, 0.084), COLOUR)
    trim.cylinder(0.009, 0.022, (0, 0, 0.169), COLOUR, segments=6, radius_top=0.005)


def _spinning_top(parts):
    """Spinning top standing on its point, with a wide band round the rim and a knob on the stem in the second colour."""
    parts.main.cylinder(0.004, 0.045, (0, 0, 0.0225), COLOUR, segments=8, radius_top=0.056)
    parts.colour(2).cylinder(0.062, 0.012, (0, 0, 0.051), COLOUR, segments=8)
    parts.main.cylinder(0.044, 0.02, (0, 0, 0.067), COLOUR, segments=8, radius_top=0.012)
    parts.main.cylinder(0.008, 0.034, (0, 0, 0.094), COLOUR, segments=6)
    parts.colour(2).cylinder(0.014, 0.012, (0, 0, 0.117), COLOUR, segments=6)


def _marble_run_starter_set(parts):
    """Base with two towers; two sloping troughs in the second colour; a funnel on top and a catch tray in the third."""
    parts.main.box((0.32, 0.11, 0.012), (0, 0, 0.006), COLOUR)
    parts.main.box((0.034, 0.05, 0.178), (-0.125, 0, 0.101), COLOUR)
    parts.main.box((0.034, 0.05, 0.098), (-0.005, 0, 0.061), COLOUR)
    _channel(parts.colour(2), (-0.125, 0.193), (-0.005, 0.127))
    _channel(parts.colour(2), (-0.005, 0.113), (0.115, 0.04))
    ends = parts.colour(3)
    ends.shell(0.022, 0.034, 0.005, COLOUR, segments=6, centre=(-0.125, 0, 0.2), radius_top=0.04, open_base=True)
    ends.tray((0.06, 0.08, 0.032), 0.006, COLOUR, centre=(0.128, 0, 0.012))


def _marble_run_track_pack(parts):
    """Three straight open troughs laid side by side, with four support posts in the second colour in front."""
    for y, length in ((0.07, 0.21), (0.022, 0.21), (-0.026, 0.15)):
        parts.main.box((length, 0.036, 0.008), (0, y, 0.004), COLOUR)
        for side in (-1, 1):
            parts.main.box((length, 0.007, 0.016), (0, y + side * 0.0145, 0.015), COLOUR)
    for x, _ in print_shapes.grid(4, 1, 0.054, 0):
        parts.colour(2).cylinder(0.019, 0.05, (x, -0.078, 0.025), COLOUR, segments=6, radius_top=0.011)


def _wind_up_car(parts):
    """Chunky toy car with a cabin; the four wheels and the wind-up key on the back deck are in the second colour."""
    parts.main.box((0.2, 0.085, 0.04), (0, 0, 0.034), COLOUR, bevel=0.006)
    parts.main.box((0.094, 0.076, 0.036), (-0.012, 0, 0.071), COLOUR, taper=(0.68, 0.88))
    trim = parts.colour(2)
    for x in (-0.062, 0.062):
        for y in (-0.05, 0.05):
            trim.cylinder(0.026, 0.02, (x, y, 0.026), COLOUR, segments=8, axis="Y")
    trim.box((0.008, 0.008, 0.022), (0.07, 0, 0.064), COLOUR)
    trim.box((0.008, 0.044, 0.024), (0.07, 0, 0.086), COLOUR)


def _rubber_band_gun(parts):
    """Toy band shooter lying on its side: long barrel, grip and fore block, with the trigger, release catch and muzzle notch in the second colour."""
    thick = 0.022
    parts.main.box((0.2, 0.032, thick), (0, 0.03, thick / 2), COLOUR)
    parts.main.box((0.04, 0.085, thick), (0.07, -0.022, thick / 2), COLOUR, rotation=(0, 0, 0.26))
    parts.main.box((0.07, 0.018, thick), (-0.03, 0.008, thick / 2), COLOUR)
    trim = parts.colour(2)
    trim.box((0.012, 0.032, thick + 0.004), (0.03, 0.0, thick / 2 + 0.002), COLOUR, rotation=(0, 0, -0.3))
    trim.box((0.022, 0.03, thick + 0.004), (0.097, 0.052, thick / 2 + 0.002), COLOUR)
    trim.box((0.016, 0.04, thick + 0.004), (-0.1, 0.03, thick / 2 + 0.002), COLOUR)


def _yo_yo(parts):
    """The two halves of a yo-yo side by side, one with the axle, each with a star cap in the second colour."""
    for x in (-0.049, 0.049):
        parts.main.cylinder(0.046, 0.022, (x, 0, 0.011), COLOUR, segments=10, radius_top=0.036)
        for turn in (0.0, math.pi / 4):
            parts.colour(2).box((0.034, 0.034, 0.004), (x, 0, 0.0235), COLOUR, rotation=(0, 0, turn))
    parts.main.cylinder(0.007, 0.022, (-0.049, 0, 0.034), COLOUR, segments=6)


def _kendama(parts):
    """Kendama lying down: handle with spike, cross piece with two cups and a base cup; the ball and a grip band are in the second colour."""
    z = 0.028
    parts.main.cylinder(0.012, 0.13, (0.035, 0, z), COLOUR, segments=6, axis="X")
    parts.main.cylinder(0.004, 0.036, (-0.047, 0, z), COLOUR, segments=6, axis="X", radius_top=0.012)
    parts.main.cylinder(0.014, 0.022, (0.108, 0, z), COLOUR, segments=6, axis="X", radius_top=0.024)
    parts.main.cylinder(0.015, 0.05, (-0.012, 0, z), COLOUR, segments=6, axis="Y")
    parts.main.cylinder(0.016, 0.022, (-0.012, -0.036, z), COLOUR, segments=6, axis="Y", radius_top=0.028)
    parts.main.cylinder(0.028, 0.022, (-0.012, 0.036, z), COLOUR, segments=6, axis="Y", radius_top=0.016)
    parts.colour(2).cylinder(0.015, 0.02, (0.06, 0, z), COLOUR, segments=6, axis="X")
    parts.colour(2).ball(0.033, (-0.09, 0, 0.033), COLOUR, subdivisions=1)


def _building_blocks_x50(parts):
    """A handful of studded bricks laid out flat: four long ones and four cubes, shared between four colours."""
    for index, (x, y) in enumerate(print_shapes.grid(2, 2, 0.108, 0.054)):
        builder = parts.colour((1, 2, 3, 1)[index])
        builder.box((0.096, 0.044, 0.03), (x, y + 0.027, 0.015), COLOUR)
        for stud in (-0.024, 0.024):
            builder.box((0.02, 0.02, 0.008), (x + stud, y + 0.027, 0.034), COLOUR)
    for index, (x, _) in enumerate(print_shapes.grid(4, 1, 0.053, 0)):
        builder = parts.colour((1, 4, 2, 3)[index])
        builder.box((0.044, 0.044, 0.03), (x, -0.054, 0.015), COLOUR)
        builder.box((0.02, 0.02, 0.008), (x, -0.054, 0.034), COLOUR)


def _shape_sorter(parts):
    """Box with a lid in the second colour; three shapes in the third poke out of the lid and two more wait beside it."""
    parts.main.box((0.16, 0.16, 0.1), (-0.03, 0, 0.05), COLOUR)
    parts.colour(2).box((0.168, 0.168, 0.012), (-0.03, 0, 0.106), COLOUR)
    shapes = parts.colour(3)
    shapes.cylinder(0.022, 0.03, (-0.07, 0.036, 0.125), COLOUR, segments=8)
    shapes.box((0.038, 0.038, 0.03), (0.01, 0.036, 0.125), COLOUR)
    shapes.cylinder(0.026, 0.03, (-0.03, -0.036, 0.125), COLOUR, segments=3)
    shapes.cylinder(0.022, 0.04, (0.098, 0.04, 0.02), COLOUR, segments=8)
    shapes.cylinder(0.026, 0.04, (0.098, -0.03, 0.02), COLOUR, segments=3)


def _toy_catapult(parts):
    """Catapult frame of two rails, cross bars and a stop bar on uprights, with the throwing arm and its cup in the second colour."""
    for side in (-1, 1):
        parts.main.box((0.2, 0.016, 0.016), (0, side * 0.04, 0.008), COLOUR)
        parts.main.box((0.016, 0.016, 0.09), (-0.03, side * 0.04, 0.06), COLOUR)
        parts.main.box((0.016, 0.096, 0.016), (side * 0.088, 0, 0.008), COLOUR)
    parts.main.box((0.016, 0.096, 0.016), (-0.03, 0, 0.105), COLOUR)
    arm = parts.colour(2)
    print_shapes.strut(arm, (-0.07, 0, 0.012), (0.07, 0, 0.07), 0.016)
    arm.shell(0.028, 0.024, 0.005, COLOUR, segments=6, centre=(0.082, 0, 0.066))


VARIANTS = {
    "dice_tower": _dice_tower,
    "dice_tray": _dice_tray,
    "card_deck_box": _card_deck_box,
    "token_and_meeple_set": _token_and_meeple_set,
    "initiative_tracker": _initiative_tracker,
    "damage_counter_dials": _damage_counter_dials,
    "game_master_screen": _game_master_screen,
    "chess_set": _chess_set,
    "life_counter_mtg": _life_counter_mtg,
    "puzzle_box": _puzzle_box,
    "fidget_slider": _fidget_slider,
    "infinity_cube": _infinity_cube,
    "articulated_snake": _articulated_snake,
    "articulated_lizard": _articulated_lizard,
    "flexi_rex": _flexi_rex,
    "fidget_gear_spinner": _fidget_gear_spinner,
    "clicker_keyring": _clicker_keyring,
    "fidget_octopus": _fidget_octopus,
    "print_in_place_robot": _print_in_place_robot,
    "spinning_top": _spinning_top,
    "marble_run_starter_set": _marble_run_starter_set,
    "marble_run_track_pack": _marble_run_track_pack,
    "wind_up_car": _wind_up_car,
    "rubber_band_gun": _rubber_band_gun,
    "yo_yo": _yo_yo,
    "kendama": _kendama,
    "building_blocks_x50": _building_blocks_x50,
    "shape_sorter": _shape_sorter,
    "toy_catapult": _toy_catapult,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
