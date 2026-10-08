"""Garage shell generator: floor, four walls, window and roller door.

Each wall is its own object so the game can cut away the ones facing the camera.
The roller door is a separate object pivoted at its top edge so it can slide up.
Interior is `--size` W x D, centred on the origin, floor surface at z = 0.
North (+Y) wall has the window, west (-X) wall has the roller door.

blender --background --factory-startup --python tools/generators/garage.py -- \
    --out assets/models/garage/garage.glb
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder

THICKNESS = 0.15
WALL = "cream"
SKIRTING = "sand"
OUTSIDE = "brick"
CAP = "terracotta"


def add_arguments(parser):
    parser.add_argument("--size", type=float, nargs=3, default=(6.0, 5.0, 2.6), metavar=("W", "D", "H"))
    parser.add_argument("--window", type=float, nargs=2, default=(1.5, 1.3), metavar=("X", "WIDTH"))
    parser.add_argument("--door-width", type=float, default=2.4)
    parser.add_argument("--door-height", type=float, default=2.1)


def build(args, rng):
    width, depth, height = args.size
    half_w, half_d, t = width / 2, depth / 2, THICKNESS

    floor = MeshBuilder()
    floor.box((width + t * 2, depth + t * 2, 0.12), (0, 0, -0.06), "stone")
    floor.finish("floor")

    _north_wall(args, half_w, half_d, height)
    _west_wall(args, half_w, half_d, height)

    south = MeshBuilder()
    _wall(south, (-half_w - t, half_w + t), (-half_d - t, -half_d), (0, height), (0, -1, 0))
    south.box((width, 0.02, 0.1), (0, -half_d + 0.01, 0.05), SKIRTING)
    south.finish("wall_south", pivot=(0, -half_d - t / 2, 0))

    east = MeshBuilder()
    _wall(east, (half_w, half_w + t), (-half_d, half_d), (0, height), (1, 0, 0))
    east.box((0.02, depth, 0.1), (half_w - 0.01, 0, 0.05), SKIRTING)
    east.finish("wall_east", pivot=(half_w + t / 2, 0, 0))


def _wall(builder, x_range, y_range, z_range, outward):
    """Wall block between the given extents: painted inside, brick outside."""
    size = tuple(high - low for low, high in (x_range, y_range, z_range))
    centre = tuple((low + high) / 2 for low, high in (x_range, y_range, z_range))
    faces = builder.box(size, centre, WALL)
    builder.paint(faces, OUTSIDE, facing=outward)
    builder.paint(faces, CAP, facing=(0, 0, 1))


def _north_wall(args, half_w, half_d, height):
    t = THICKNESS
    window_x, window_w = args.window
    sill, window_h = 1.0, 1.0
    left, right = window_x - window_w / 2, window_x + window_w / 2
    y_range = (half_d, half_d + t)
    y = half_d + t / 2

    wall = MeshBuilder()
    _wall(wall, (-half_w - t, left), y_range, (0, height), (0, 1, 0))
    _wall(wall, (right, half_w + t), y_range, (0, height), (0, 1, 0))
    _wall(wall, (left, right), y_range, (0, sill), (0, 1, 0))
    _wall(wall, (left, right), y_range, (sill + window_h, height), (0, 1, 0))
    wall.box((half_w * 2, 0.02, 0.1), (0, half_d - 0.01, 0.05), SKIRTING)

    # Window: frame, glass, cross bars and a wooden sill on the inside.
    middle = sill + window_h / 2
    wall.box((window_w, 0.02, window_h), (window_x, y, middle), "sky")
    for z in (sill + 0.03, sill + window_h - 0.03):
        wall.box((window_w, t + 0.02, 0.06), (window_x, y, z), "white")
    for x in (left + 0.03, right - 0.03):
        wall.box((0.06, t + 0.02, window_h), (x, y, middle), "white")
    wall.box((0.04, 0.05, window_h), (window_x, y, middle), "white")
    wall.box((window_w, 0.05, 0.04), (window_x, y, middle), "white")
    wall.box((window_w + 0.16, 0.14, 0.04), (window_x, half_d - 0.05, sill - 0.02), "wood_light")

    # Strip light high on the wall.
    wall.box((1.5, 0.05, 0.1), (-half_w + 1.1, half_d - 0.025, 2.3), "metal_light")
    wall.box((1.4, 0.04, 0.06), (-half_w + 1.1, half_d - 0.06, 2.3), "white")
    wall.finish("wall_north", pivot=(0, y, 0))


def _west_wall(args, half_w, half_d, height):
    t = THICKNESS
    half_door, door_h = args.door_width / 2, args.door_height
    x_range = (-half_w - t, -half_w)
    x = -half_w - t / 2

    wall = MeshBuilder()
    _wall(wall, x_range, (-half_d, -half_door), (0, height), (-1, 0, 0))
    _wall(wall, x_range, (half_door, half_d), (0, height), (-1, 0, 0))
    _wall(wall, x_range, (-half_door, half_door), (door_h, height), (-1, 0, 0))
    side_length = half_d - half_door
    for side in (-1, 1):
        wall.box((0.02, side_length, 0.1), (-half_w + 0.01, side * (half_door + side_length / 2), 0.05), SKIRTING)
    # Housing for the rolled-up door.
    wall.box((0.24, args.door_width + 0.24, 0.26), (-half_w + 0.12, 0, door_h + 0.13), "metal_dark", bevel=0.02)
    wall_obj = wall.finish("wall_west", pivot=(x, 0, 0))

    door = MeshBuilder()
    door.box((0.05, args.door_width, door_h), (x, 0, door_h / 2), "metal_light")
    slat = 0.15
    for index in range(1, int(door_h / slat)):
        door.box((0.06, args.door_width, 0.012), (x, 0, index * slat), "metal_dark")
    door.box((0.08, args.door_width, 0.06), (x, 0, 0.03), "charcoal")
    door.box((0.08, 0.3, 0.04), (x, 0, 0.5), "charcoal")
    door.finish("roller_door", pivot=(x, 0, door_h), parent=wall_obj)


if __name__ == "__main__":
    common.run(sys.modules[__name__])
