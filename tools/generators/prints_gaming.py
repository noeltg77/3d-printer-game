"""Printed item generator for the Gaming and tabletop category.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints_gaming.py -- \
    --variant movement_tray --out assets/models/prints/movement_tray.glb
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


def _miniature_display_shelf(builder):
    """Three display steps in front of a tall back board."""
    print_shapes.stepped_rack(builder, 0.26, 3, 0.05, 0.03, 0.04, lip=0.0)
    builder.box((0.26, 0.014, 0.17), (0, 0.082, 0.085), COLOUR, bevel=0.004)


def _wargaming_terrain_ruined_building(builder):
    """Corner of a ruin on a base: two broken walls stepping down, a scrap of floor and rubble."""
    builder.box((0.22, 0.2, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    for x, height in ((-0.07, 0.16), (0.0, 0.11), (0.07, 0.06)):
        builder.box((0.07, 0.02, height), (x, 0.085, 0.01 + height / 2), COLOUR)
    for y, height in ((0.02, 0.12), (-0.045, 0.05)):
        builder.box((0.02, 0.07, height), (-0.095, y, 0.01 + height / 2), COLOUR)
    builder.box((0.07, 0.05, 0.01), (-0.05, 0.052, 0.1), COLOUR)
    builder.box((0.035, 0.03, 0.02), (0.04, 0.0, 0.02), COLOUR, rotation=(0, 0, 0.5))
    builder.box((0.025, 0.02, 0.014), (0.0, -0.04, 0.018), COLOUR, rotation=(0, 0, -0.4))


def _wargaming_terrain_crates_and_barrels_x10(builder):
    """Scatter set in two rows: six crates of different sizes (one stacked) and four barrels."""
    spots = print_shapes.grid(5, 2, 0.055, 0.06)
    crates = {0: (0.04, 0.04, 0.04), 2: (0.034, 0.034, 0.034), 3: (0.05, 0.035, 0.03),
              6: (0.042, 0.042, 0.04), 7: (0.036, 0.04, 0.03), 9: (0.04, 0.04, 0.044)}
    for index, (x, y) in enumerate(spots):
        if index in crates:
            size = crates[index]
            builder.box(size, (x, y, size[2] / 2), COLOUR)
        else:
            builder.cylinder(0.018, 0.042, (x, y, 0.021), COLOUR, segments=8, radius_top=0.016)
    x, y = spots[6]
    builder.box((0.026, 0.026, 0.024), (x + 0.004, y - 0.003, 0.052), COLOUR, rotation=(0, 0, 0.4))


def _wargaming_terrain_walls_and_barricades(builder):
    """Three rows: a battlement wall, a pair of sloped barriers and a stack of logs."""
    builder.box((0.24, 0.022, 0.045), (0, 0.065, 0.0225), COLOUR)
    for x, _ in print_shapes.grid(4, 1, 0.07, 0):
        builder.box((0.03, 0.022, 0.018), (x, 0.065, 0.054), COLOUR)
    for side in (-1, 1):
        builder.box((0.115, 0.042, 0.04), (side * 0.06, 0.0, 0.02), COLOUR, taper=(1.0, 0.35))
    for y, z in ((-0.079, 0.014), (-0.051, 0.014), (-0.065, 0.038)):
        builder.cylinder(0.014, 0.22, (0, y, z), COLOUR, segments=6, axis="X")


def _wargaming_terrain_forest_bases(builder):
    """Three flat irregular bases, each with a pair of tree stumps."""
    for x, y, radius, turn in ((-0.07, 0.035, 0.06, 0.3), (0.062, 0.04, 0.05, 1.1), (0.0, -0.062, 0.055, 2.0)):
        builder.cylinder(radius, 0.008, (x, y, 0.004), COLOUR, segments=7, rotation=(0, 0, turn))
        builder.cylinder(0.013, 0.032, (x - radius * 0.3, y + radius * 0.2, 0.022), COLOUR, segments=6, radius_top=0.009)
        builder.cylinder(0.011, 0.02, (x + radius * 0.35, y - radius * 0.25, 0.016), COLOUR, segments=6, radius_top=0.008)


def _dungeon_tiles_x10(builder):
    """Ten square floor tiles in two rows, a few with a length of wall or a pillar."""
    spots = print_shapes.grid(5, 2, 0.056, 0.056)
    for x, y in spots:
        builder.box((0.05, 0.05, 0.008), (x, y, 0.004), COLOUR)
    for index in (5, 6):
        x, y = spots[index]
        builder.box((0.05, 0.01, 0.03), (x, y + 0.02, 0.022), COLOUR)
    for index in (2, 9):
        x, y = spots[index]
        builder.box((0.016, 0.016, 0.036), (x, y, 0.025), COLOUR)


def _sci_fi_bulkheads_x6(builder):
    """Six upright wall panels in two rows, each braced by a tapering pillar at both ends."""
    for x, y in print_shapes.grid(3, 2, 0.095, 0.07):
        builder.box((0.085, 0.012, 0.07), (x, y, 0.035), COLOUR)
        for side in (-1, 1):
            builder.box((0.014, 0.026, 0.078), (x + side * 0.036, y, 0.039), COLOUR, taper=(1.0, 0.6))


def _paint_pot_rack(builder):
    """Three stepped rows of four pockets for paint pots."""
    for row in range(3):
        print_shapes.divided_tray(
            builder, (0.26, 0.062, 0.04 + row * 0.032), 0.007, across=3, centre=(0, (row - 1) * 0.058, 0))


def _hobby_brush_holder(builder):
    """Base with a toothed bar front and back, so brushes lie across the notches."""
    builder.box((0.15, 0.08, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    for y in (-0.028, 0.028):
        builder.box((0.15, 0.01, 0.03), (0, y, 0.025), COLOUR)
        for x, _ in print_shapes.grid(5, 1, 0.032, 0):
            builder.box((0.012, 0.01, 0.014), (x, y, 0.047), COLOUR)


def _miniature_painting_handle(builder):
    """Chunky grip that flares at the foot, with a clamp plate and a mini's base on top."""
    builder.cylinder(0.036, 0.015, (0, 0, 0.0075), COLOUR, segments=8, radius_top=0.028)
    builder.cylinder(0.026, 0.075, (0, 0, 0.0525), COLOUR, segments=8, radius_top=0.03)
    builder.cylinder(0.038, 0.012, (0, 0, 0.096), COLOUR, segments=8)
    builder.cylinder(0.022, 0.006, (0, 0, 0.105), COLOUR, segments=6)


def _card_shuffler_housing(builder):
    """Box body with two card plates sloping in to the middle, end stops and a crank on the front."""
    builder.box((0.2, 0.11, 0.08), (0, 0, 0.04), COLOUR, bevel=0.008)
    for side in (-1, 1):
        builder.box((0.085, 0.1, 0.008), (side * 0.055, 0, 0.098), COLOUR, rotation=(0, math.radians(-18 * side), 0))
        builder.box((0.008, 0.1, 0.03), (side * 0.097, 0, 0.115), COLOUR)
    builder.cylinder(0.02, 0.012, (0, -0.06, 0.045), COLOUR, segments=8, axis="Y")
    builder.box((0.01, 0.03, 0.01), (0.012, -0.078, 0.045), COLOUR)


def _movement_tray(builder):
    """Very shallow tray with eight sockets for a unit's bases."""
    print_shapes.divided_tray(
        builder, (0.17, 0.1, 0.014), 0.006, across=3, along=1, floor=0.005, divider_height=0.012, chamfer=0.003)


def _poker_chip_holder(builder):
    """Five chip channels side by side under a carry handle."""
    print_shapes.divided_tray(builder, (0.26, 0.11, 0.05), 0.008, across=4, chamfer=0.004)
    for y in (-0.049, 0.049):
        builder.box((0.012, 0.012, 0.11), (0, y, 0.055), COLOUR)
    builder.box((0.012, 0.11, 0.012), (0, 0, 0.11), COLOUR)


def _mahjong_tile_rack(builder):
    """Long rack: a low front ledge and a leaning back for a row of tiles."""
    print_shapes.slot_rack(builder, 0.3, 0.07, (0.014, 0.05), lean=18.0, base=0.01, panel=0.01)


def _retro_console_cartridge_holder(builder):
    """Open box with six slots, front to back, for cartridges standing on edge."""
    print_shapes.divided_tray(builder, (0.26, 0.13, 0.055), 0.008, along=5, chamfer=0.004)


# Gaming and tabletop, Spare room tier

def _board_game_insert_organiser(builder):
    """Box insert with wells of different sizes: two for cards, a long one for the board bits and four small ones."""
    builder.tray((0.3, 0.24, 0.045), 0.007, COLOUR, chamfer=0.004)
    builder.box((0.286, 0.006, 0.041), (0, 0.02, 0.0205), COLOUR)
    builder.box((0.006, 0.1, 0.041), (0, 0.068, 0.0205), COLOUR)
    builder.box((0.286, 0.006, 0.041), (0, -0.055, 0.0205), COLOUR)
    for x in (-0.072, 0.0, 0.072):
        builder.box((0.006, 0.062, 0.041), (x, -0.086, 0.0205), COLOUR)


def _wargaming_terrain_hills_x3(builder):
    """Three stepped hills of different sizes, each a wide irregular base with a smaller flat top."""
    for x, y, size, turn in ((-0.08, 0.03, 0.075, 0.2), (0.07, 0.045, 0.06, 1.0), (0.02, -0.07, 0.065, 2.1)):
        builder.cylinder(size, 0.022, (x, y, 0.011), COLOUR, segments=7, radius_top=size * 0.8, rotation=(0, 0, turn))
        builder.cylinder(size * 0.62, 0.02, (x + size * 0.1, y, 0.032), COLOUR, segments=6, radius_top=size * 0.45, rotation=(0, 0, turn + 0.5))


def _fantasy_tavern_set(builder):
    """Tavern furniture: a trestle table with a bench each side, a bar counter, two barrels and two stools."""
    builder.box((0.1, 0.05, 0.008), (-0.07, -0.03, 0.04), COLOUR)
    for x in (-0.105, -0.035):
        builder.box((0.008, 0.04, 0.036), (x, -0.03, 0.018), COLOUR)
    for y in (-0.075, 0.015):
        builder.box((0.09, 0.018, 0.02), (-0.07, y, 0.01), COLOUR)
    builder.box((0.14, 0.04, 0.05), (0.05, 0.07, 0.025), COLOUR, bevel=0.004)
    for x in (0.03, 0.08):
        builder.cylinder(0.022, 0.05, (x, -0.02, 0.025), COLOUR, segments=8, radius_top=0.019)
    for x in (0.02, 0.085):
        builder.cylinder(0.014, 0.022, (x, -0.075, 0.011), COLOUR, segments=6)


def _miniature_carry_case_insert(builder):
    """Foam-style tray with a grid of twenty-four slots for figures."""
    print_shapes.divided_tray(builder, (0.27, 0.19, 0.04), 0.007, across=5, along=3, chamfer=0.004)


VARIANTS = {
    "miniature_display_shelf": _miniature_display_shelf,
    "wargaming_terrain_ruined_building": _wargaming_terrain_ruined_building,
    "wargaming_terrain_crates_and_barrels_x10": _wargaming_terrain_crates_and_barrels_x10,
    "wargaming_terrain_walls_and_barricades": _wargaming_terrain_walls_and_barricades,
    "wargaming_terrain_forest_bases": _wargaming_terrain_forest_bases,
    "dungeon_tiles_x10": _dungeon_tiles_x10,
    "sci_fi_bulkheads_x6": _sci_fi_bulkheads_x6,
    "paint_pot_rack": _paint_pot_rack,
    "hobby_brush_holder": _hobby_brush_holder,
    "miniature_painting_handle": _miniature_painting_handle,
    "card_shuffler_housing": _card_shuffler_housing,
    "movement_tray": _movement_tray,
    "poker_chip_holder": _poker_chip_holder,
    "mahjong_tile_rack": _mahjong_tile_rack,
    "retro_console_cartridge_holder": _retro_console_cartridge_holder,
    "board_game_insert_organiser": _board_game_insert_organiser,
    "wargaming_terrain_hills_x3": _wargaming_terrain_hills_x3,
    "fantasy_tavern_set": _fantasy_tavern_set,
    "miniature_carry_case_insert": _miniature_carry_case_insert,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
