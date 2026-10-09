"""Printed item generator for the multicolour designs the other files leave out: the
Workshop and Factory ones, and the contract only batches.

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


def _wedge(radius, start, sweep, steps):
    """Outline of a slice of a circle, anticlockwise from its point at the centre."""
    return [(0.0, 0.0)] + [
        (radius * math.cos(start + sweep * step / steps), radius * math.sin(start + sweep * step / steps))
        for step in range(steps + 1)
    ]


# Workshop

def _puzzle_cube_3x3(parts):
    """Twist puzzle cube. The core and the back face are the first colour; the top, front and right
    faces are nine tiles each in three more, and the left face and the base are the last two."""
    parts.main.box((0.1, 0.1, 0.1), (0, 0, 0.054), COLOUR)
    parts.main.box((0.094, 0.004, 0.094), (0, 0.052, 0.054), COLOUR)
    for column, row in ((c, r) for c in (-1, 0, 1) for r in (-1, 0, 1)):
        parts.colour(2).box((0.029, 0.029, 0.004), (column * 0.033, row * 0.033, 0.106), COLOUR)
        parts.colour(3).box((0.029, 0.004, 0.029), (column * 0.033, -0.052, 0.054 + row * 0.033), COLOUR)
        parts.colour(4).box((0.004, 0.029, 0.029), (0.052, column * 0.033, 0.054 + row * 0.033), COLOUR)
    parts.colour(5).box((0.004, 0.094, 0.094), (-0.052, 0, 0.054), COLOUR)
    parts.colour(6).box((0.094, 0.094, 0.004), (0, 0, 0.002), COLOUR)


def _molecule_kit(parts):
    """A small molecule laid flat: two large atoms in the first colour, others in three more by kind,
    and the bonds between them in the fifth."""
    atoms = {"c1": (-0.03, 0.0, 0.022, 1), "c2": (0.03, 0.01, 0.022, 1), "o": (0.075, -0.025, 0.018, 2), "n": (-0.075, 0.03, 0.018, 4),
             "h1": (-0.04, -0.05, 0.013, 3), "h2": (0.035, 0.062, 0.013, 3), "h3": (0.115, -0.005, 0.013, 3), "h4": (-0.115, 0.01, 0.013, 3)}
    for x, y, radius, colour in atoms.values():
        parts.colour(colour).ball(radius, (x, y, radius), COLOUR, subdivisions=1)
    for first, second in (("c1", "c2"), ("c2", "o"), ("c1", "n"), ("c1", "h1"), ("c2", "h2"), ("o", "h3"), ("n", "h4")):
        a, b = atoms[first], atoms[second]
        print_shapes.strut(parts.colour(5), (a[0], a[1], 0.013), (b[0], b[1], 0.013), 0.007)


def _fraction_circles(parts):
    """Six flat circles in six colours: a whole one, then halves, thirds, quarters, sixths and eighths."""
    spots = print_shapes.grid(3, 2, 0.092, 0.092)
    for index, slices in enumerate((1, 2, 3, 4, 6, 8)):
        x, y = spots[index]
        builder = parts.colour(index + 1)
        if slices == 1:
            builder.cylinder(0.042, 0.006, (x, y, 0.003), COLOUR, segments=10)
            continue
        steps = 4 if slices == 2 else (2 if slices <= 4 else 1)
        sweep = math.tau / slices
        for piece in range(slices):
            # Each slice is drawn a little short of its neighbours and nudged outwards, so the cuts show.
            middle = (piece + 0.5) * sweep
            builder.plate(_wedge(0.04, piece * sweep + 0.04, sweep - 0.08, steps), 0.006, COLOUR,
                          centre=(x + 0.003 * math.cos(middle), y + 0.003 * math.sin(middle), 0))


# Factory

def _keycaps_artisan_set(parts):
    """Six sculpted keycaps in two rows; the little figure on top of each is the second colour."""
    for index, (x, y) in enumerate(print_shapes.grid(3, 2, 0.03, 0.03)):
        parts.main.box((0.022, 0.022, 0.014), (x, y, 0.007), COLOUR, taper=(0.72, 0.72))
        art = parts.colour(2)
        if index % 3 == 0:
            art.ball(0.005, (x, y, 0.0165), COLOUR, subdivisions=1)
        elif index % 3 == 1:
            art.cylinder(0.006, 0.008, (x, y, 0.018), COLOUR, segments=4, radius_top=0.0005)
        else:
            art.box((0.009, 0.009, 0.004), (x, y, 0.016), COLOUR, rotation=(0, 0, math.pi / 4))
    for builder in (parts.main, parts.colour(2)):
        builder.enlarge(2.2)


# Contract only batches

def _branded_promo_keyring_x100(parts):
    """Rows of rounded keyring tags, each with a raised logo block in the second colour.
    Twelve are modelled to stand for the hundred."""
    for x, y in print_shapes.grid(4, 3, 0.058, 0.05):
        parts.main.box((0.05, 0.03, 0.005), (x, y, 0.0025), COLOUR, taper=(0.9, 0.85))
        parts.colour(2).box((0.024, 0.014, 0.003), (x + 0.006, y, 0.0065), COLOUR)


def _shelf_wobblers_x50(parts):
    """Shelf wobblers lying flat: a clip, a springy arm and a round sign with a mark in the second colour.
    Four are modelled to stand for the fifty."""
    for x, y in print_shapes.grid(2, 2, 0.08, 0.11):
        parts.main.box((0.03, 0.014, 0.006), (x, y + 0.04, 0.003), COLOUR)
        parts.main.box((0.006, 0.05, 0.004), (x, y + 0.012, 0.002), COLOUR)
        parts.main.cylinder(0.026, 0.005, (x, y - 0.03, 0.0025), COLOUR, segments=8)
        parts.colour(2).box((0.03, 0.008, 0.003), (x, y - 0.03, 0.0065), COLOUR)


def _hotel_key_card_holders_x50(parts):
    """Wall pockets for key cards, lying on their backs, each with a band across the front in the second colour.
    Eight are modelled to stand for the fifty."""
    for x, y in print_shapes.grid(4, 2, 0.066, 0.1):
        parts.main.box((0.054, 0.085, 0.005), (x, y, 0.0025), COLOUR)
        parts.main.box((0.054, 0.05, 0.008), (x, y - 0.0175, 0.009), COLOUR)
        parts.colour(2).box((0.054, 0.014, 0.003), (x, y - 0.012, 0.0145), COLOUR)


def _film_and_theatre_props_batch(parts):
    """A batch of stage props: a chest, a goblet and a sword, with the chest's bands, the goblet's
    rim and the sword's hilt in the second colour."""
    trim = parts.colour(2)
    parts.main.box((0.12, 0.08, 0.06), (-0.07, 0.03, 0.03), COLOUR)
    parts.main.box((0.124, 0.084, 0.03), (-0.07, 0.03, 0.075), COLOUR, taper=(1.0, 0.6))
    for x in (-0.11, -0.07, -0.03):
        trim.box((0.01, 0.088, 0.064), (x, 0.03, 0.032), COLOUR)
    trim.box((0.02, 0.008, 0.02), (-0.07, -0.012, 0.055), COLOUR)
    parts.main.cylinder(0.03, 0.01, (0.07, 0.04, 0.005), COLOUR, segments=8)
    parts.main.cylinder(0.008, 0.05, (0.07, 0.04, 0.035), COLOUR, segments=6)
    parts.main.shell(0.016, 0.05, 0.005, COLOUR, segments=8, centre=(0.07, 0.04, 0.058), radius_top=0.034)
    trim.shell(0.036, 0.008, 0.005, COLOUR, segments=8, centre=(0.07, 0.04, 0.1), open_base=True)
    parts.main.plate([(-0.1, -0.012), (0.03, -0.012), (0.05, 0.0), (0.03, 0.012), (-0.1, 0.012)], 0.006, COLOUR, centre=(0.02, -0.075, 0))
    trim.box((0.012, 0.07, 0.01), (-0.085, -0.075, 0.005), COLOUR)
    trim.box((0.045, 0.016, 0.012), (-0.112, -0.075, 0.006), COLOUR)
    trim.ball(0.012, (-0.14, -0.075, 0.012), COLOUR, subdivisions=1)


def _medical_training_model(parts):
    """Anatomical heart on a stand, with the great vessels at the top in the second colour."""
    parts.main.cylinder(0.055, 0.014, (0, 0, 0.007), COLOUR, segments=8, radius_top=0.046)
    parts.main.cylinder(0.01, 0.04, (0, 0, 0.032), COLOUR, segments=6)
    parts.main.ball(0.05, (0, 0, 0.098), COLOUR, scale=(0.95, 0.8, 1.15), rotation=(0, math.radians(-12), 0))
    vessels = parts.colour(2)
    print_shapes.limb(vessels, (-0.008, 0, 0.14), (-0.022, 0, 0.185), 0.016, 0.012)
    print_shapes.limb(vessels, (-0.022, 0, 0.183), (0.02, 0, 0.2), 0.012, 0.009)
    print_shapes.limb(vessels, (0.022, 0, 0.135), (0.04, 0.008, 0.172), 0.012, 0.009)


VARIANTS = {
    "puzzle_cube_3x3": _puzzle_cube_3x3,
    "molecule_kit": _molecule_kit,
    "fraction_circles": _fraction_circles,
    "keycaps_artisan_set": _keycaps_artisan_set,
    "branded_promo_keyring_x100": _branded_promo_keyring_x100,
    "shelf_wobblers_x50": _shelf_wobblers_x50,
    "hotel_key_card_holders_x50": _hotel_key_card_holders_x50,
    "film_and_theatre_props_batch": _film_and_theatre_props_batch,
    "medical_training_model": _medical_training_model,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
