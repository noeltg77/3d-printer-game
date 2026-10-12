"""Premises shell generator: floor, four walls, window and door, in the style of
one of the places the business works from.

Each wall is its own object so the game can cut away the ones facing the camera.
The door is a separate object pivoted at its top edge so it can slide up.
Interior is `--size` W x D, centred on the origin, floor surface at z = 0.
North (+Y) wall has the window, west (-X) wall has the door.

`--style` picks the look, and each has its own walls, floor, window and door:
  garage    bare brick, a stained and cracked concrete floor, a panelled door
  lockup    painted blockwork with a blue dado, a grey painted floor, a barred window
  workshop  boarded lower walls under plaster and timber, a plank floor, a tall steel window
  factory   ribbed steel cladding on a steel frame, marked walkways, a sectional door

What covers a wall stands no more than RELIEF proud of it, because the furniture
in the scenes is pushed right up against the walls. The few things that stick out
further hang above head height or beside the door, where nothing stands. What is
painted on the floor is a few millimetres thick, so nothing has to step over it.

blender --background --factory-startup --python tools/generators/garage.py -- \
    --style garage --out assets/models/garage/garage.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder

THICKNESS = 0.15
RELIEF = 0.03
# Paint on the floor is built in layers this thick, so one can lie on another.
LAYER = 0.003

LOOKS = {
    "garage": {
        "wall": "brick", "outside": "brick", "cap": "terracotta", "floor": "stone", "skirting": None,
        "window": {"sill": 1.0, "height": 1.0, "frame": "white", "columns": 2, "rows": 2, "ledge": "wood_light"},
        "door": "panelled",
    },
    "lockup": {
        "wall": "white", "outside": "slate", "cap": "navy", "floor": "metal_light", "skirting": None,
        "window": {"sill": 1.15, "height": 0.85, "frame": "white", "columns": 3, "rows": 1, "ledge": "metal_light", "bars": 0.2},
        "door": "roller", "door_colours": ("metal_light", "metal_dark"),
    },
    "workshop": {
        "wall": "cream", "outside": "brick", "cap": "charcoal", "floor": "wood_dark", "skirting": None,
        "window": {"sill": 1.2, "height": 1.35, "frame": "charcoal", "columns": 5, "rows": 3, "ledge": "wood"},
        "door": "roller", "door_colours": ("teal", "navy"),
    },
    "factory": {
        "wall": "white", "outside": "metal_light", "cap": "teal", "floor": "metal_light", "skirting": None,
        "window": {"sill": 1.3, "height": 1.3, "frame": "metal_dark", "columns": 4, "rows": 2, "ledge": "metal_light"},
        "door": "sectional",
    },
}


def add_arguments(parser):
    parser.add_argument("--style", choices=sorted(LOOKS), default="garage")
    parser.add_argument("--size", type=float, nargs=3, default=(6.0, 5.0, 2.6), metavar=("W", "D", "H"))
    parser.add_argument("--window", type=float, nargs=2, default=(1.5, 1.3), metavar=("X", "WIDTH"))
    parser.add_argument("--door-width", type=float, default=2.4)
    parser.add_argument("--door-height", type=float, default=2.1)


class Room:
    """The measurements and look every part of the shell is built from."""

    def __init__(self, args, rng):
        self.style = args.style
        self.look = LOOKS[args.style]
        self.rng = rng
        self.width, self.depth, self.height = args.size
        self.half_w, self.half_d = self.width / 2, self.depth / 2
        self.window_x, self.window_w = args.window
        self.sill, self.window_h = self.look["window"]["sill"], self.look["window"]["height"]
        self.half_door, self.door_h = args.door_width / 2, args.door_height
        self.door_w = args.door_width


class Face:
    """The inside of one wall, for dressing it. `u` runs along the wall from its
    left end as seen from in the room, z is height, and depth is out into the room.
    Whatever is added is cut back from the wall's `holes` (its window or door)."""

    def __init__(self, builder, origin, along, inward, length, height, holes=()):
        self.builder = builder
        self.origin, self.along, self.inward = origin, along, inward
        self.length, self.height = length, height
        self.holes = list(holes)

    def slab(self, u_range, z_range, colour, depth=0.012, whole=False, bevel=0.0):
        """Flat piece standing `depth` off the wall. With `whole` it is left out
        altogether if a hole would cut into it."""
        rect = (max(u_range[0], 0.0), min(u_range[1], self.length), max(z_range[0], 0.0), min(z_range[1], self.height))
        if rect[1] - rect[0] < 0.005 or rect[3] - rect[2] < 0.005:
            return
        pieces = [rect]
        for hole in self.holes:
            pieces = _cut(pieces, hole)
        if whole and pieces != [rect]:
            return
        for u0, u1, z0, z1 in pieces:
            if u1 - u0 < 0.005 or z1 - z0 < 0.005:
                continue
            self.box((u0 + u1) / 2, (z0 + z1) / 2, (u1 - u0, depth, z1 - z0), colour, bevel=bevel)

    def box(self, u, z, size, colour, out=0.0, bevel=0.0):
        """Box of `size` (along, deep, high) with its back `out` from the wall."""
        along, deep, high = size
        centre = tuple(self.origin[i] + self.along[i] * u + self.inward[i] * (out + deep / 2) for i in range(2)) + (z,)
        shape = tuple(abs(self.along[i]) * along + abs(self.inward[i]) * deep for i in range(2)) + (high,)
        return self.builder.box(shape, centre, colour, bevel=bevel)

    def point(self, u, z, out=0.0):
        return tuple(self.origin[i] + self.along[i] * u + self.inward[i] * out for i in range(2)) + (z,)


def _cut(rects, hole):
    """The rectangles (u0, u1, z0, z1) with the hole taken out of them."""
    hole_u0, hole_u1, hole_z0, hole_z1 = hole
    out = []
    for u0, u1, z0, z1 in rects:
        if u1 <= hole_u0 or u0 >= hole_u1 or z1 <= hole_z0 or z0 >= hole_z1:
            out.append((u0, u1, z0, z1))
            continue
        if u0 < hole_u0:
            out.append((u0, hole_u0, z0, z1))
        if u1 > hole_u1:
            out.append((hole_u1, u1, z0, z1))
        mid_u0, mid_u1 = max(u0, hole_u0), min(u1, hole_u1)
        if z0 < hole_z0:
            out.append((mid_u0, mid_u1, z0, hole_z0))
        if z1 > hole_z1:
            out.append((mid_u0, mid_u1, hole_z1, z1))
    return out


def build(args, rng):
    room = Room(args, rng)
    half_w, half_d, t = room.half_w, room.half_d, THICKNESS
    dress_wall, dress_floor = WALLS[room.style], FLOORS[room.style]

    floor = MeshBuilder()
    floor.box((room.width + t * 2, room.depth + t * 2, 0.12), (0, 0, -0.06), room.look["floor"])
    dress_floor(room, floor)
    floor.finish("floor")

    _north_wall(room, dress_wall)
    _west_wall(room, dress_wall)

    south = MeshBuilder()
    _wall(room, south, (-half_w - t, half_w + t), (-half_d - t, -half_d), (0, room.height), (0, -1, 0))
    dress_wall(room, Face(south, (half_w, -half_d), (-1, 0), (0, 1), room.width, room.height), "south")
    south.finish("wall_south", pivot=(0, -half_d - t / 2, 0))

    east = MeshBuilder()
    _wall(room, east, (half_w, half_w + t), (-half_d, half_d), (0, room.height), (1, 0, 0))
    dress_wall(room, Face(east, (half_w, half_d), (0, -1), (-1, 0), room.depth, room.height), "east")
    east.finish("wall_east", pivot=(half_w + t / 2, 0, 0))


def _wall(room, builder, x_range, y_range, z_range, outward):
    """Wall block between the given extents, in the look's inside and outside colours."""
    size = tuple(high - low for low, high in (x_range, y_range, z_range))
    centre = tuple((low + high) / 2 for low, high in (x_range, y_range, z_range))
    faces = builder.box(size, centre, room.look["wall"])
    builder.paint(faces, room.look["outside"], facing=outward)
    builder.paint(faces, room.look["cap"], facing=(0, 0, 1))


def _north_wall(room, dress_wall):
    t, half_w, half_d, height = THICKNESS, room.half_w, room.half_d, room.height
    window_x, window_w, sill, window_h = room.window_x, room.window_w, room.sill, room.window_h
    left, right = window_x - window_w / 2, window_x + window_w / 2
    y_range = (half_d, half_d + t)
    y = half_d + t / 2
    panes = room.look["window"]
    frame = panes["frame"]

    wall = MeshBuilder()
    _wall(room, wall, (-half_w - t, left), y_range, (0, height), (0, 1, 0))
    _wall(room, wall, (right, half_w + t), y_range, (0, height), (0, 1, 0))
    _wall(room, wall, (left, right), y_range, (0, sill), (0, 1, 0))
    _wall(room, wall, (left, right), y_range, (sill + window_h, height), (0, 1, 0))

    # Window: frame, glass, glazing bars and a sill on the inside.
    middle = sill + window_h / 2
    wall.box((window_w, 0.02, window_h), (window_x, y, middle), "sky")
    for z in (sill + 0.03, sill + window_h - 0.03):
        wall.box((window_w, t + 0.02, 0.06), (window_x, y, z), frame)
    for x in (left + 0.03, right - 0.03):
        wall.box((0.06, t + 0.02, window_h), (x, y, middle), frame)
    for column in range(1, panes["columns"]):
        wall.box((0.04, 0.05, window_h), (left + window_w * column / panes["columns"], y, middle), frame)
    for row in range(1, panes["rows"]):
        wall.box((window_w, 0.05, 0.04), (window_x, y, sill + window_h * row / panes["rows"]), frame)
    if "bars" in panes:
        # Security bars across the inside of the opening.
        count = int(window_w / panes["bars"])
        for index in range(1, count):
            wall.cylinder(0.012, window_h, (left + window_w * index / count, half_d - 0.02, middle), "metal_dark", segments=5)
    wall.box((window_w + 0.16, 0.14, 0.04), (window_x, half_d - 0.05, sill - 0.02), panes["ledge"])

    # Strip light high on the wall.
    light_z = min(2.3, height - 0.3)
    wall.box((1.5, 0.05, 0.1), (-half_w + 1.1, half_d - 0.025 - RELIEF, light_z), "metal_light")
    wall.box((1.4, 0.04, 0.06), (-half_w + 1.1, half_d - 0.06 - RELIEF, light_z), "white")

    hole = (left + half_w - 0.08, right + half_w + 0.08, sill - 0.05, sill + window_h)
    dress_wall(room, Face(wall, (-half_w, half_d), (1, 0), (0, -1), room.width, height, [hole]), "north")
    wall.finish("wall_north", pivot=(0, y, 0))


def _west_wall(room, dress_wall):
    t, half_w, half_d, height = THICKNESS, room.half_w, room.half_d, room.height
    half_door, door_h, door_w = room.half_door, room.door_h, room.door_w
    x_range = (-half_w - t, -half_w)
    x = -half_w - t / 2

    wall = MeshBuilder()
    _wall(room, wall, x_range, (-half_d, -half_door), (0, height), (-1, 0, 0))
    _wall(room, wall, x_range, (half_door, half_d), (0, height), (-1, 0, 0))
    _wall(room, wall, x_range, (-half_door, half_door), (door_h, height), (-1, 0, 0))
    # Housing for the rolled-up door.
    wall.box((0.24, door_w + 0.24, 0.26), (-half_w + 0.12, 0, door_h + 0.13), "metal_dark", bevel=0.02)

    hole = (half_d - half_door - 0.12, half_d + half_door + 0.12, 0.0, door_h + 0.26)
    dress_wall(room, Face(wall, (-half_w, -half_d), (0, 1), (1, 0), room.depth, height, [hole]), "west")
    wall_obj = wall.finish("wall_west", pivot=(x, 0, 0))

    door = MeshBuilder()
    DOORS[room.look["door"]](room, door, x)
    door.finish("roller_door", pivot=(x, 0, door_h), parent=wall_obj)


# Doors. Each fills the opening with a slab at the wall's centre line, x.

def _roller_door(room, door, x):
    panel, lines = room.look["door_colours"]
    door_w, door_h = room.door_w, room.door_h
    door.box((0.05, door_w, door_h), (x, 0, door_h / 2), panel)
    slat = 0.15
    for index in range(1, int(door_h / slat)):
        door.box((0.06, door_w, 0.012), (x, 0, index * slat), lines)
    door.box((0.08, door_w, 0.06), (x, 0, 0.03), "charcoal")
    door.box((0.08, 0.3, 0.04), (x, 0, 0.5), "charcoal")


def _panelled_door(room, door, x):
    """An up-and-over garage door: a painted sheet pressed into panels."""
    door_w, door_h = room.door_w, room.door_h
    door.box((0.05, door_w, door_h), (x, 0, door_h / 2), "cream")
    columns, rows = 4, 3
    gap = 0.09
    panel_w = (door_w - gap * (columns + 1)) / columns
    panel_h = (door_h - 0.1 - gap * (rows + 1)) / rows
    for row in range(rows):
        for column in range(columns):
            y = -door_w / 2 + gap + panel_w / 2 + column * (panel_w + gap)
            z = 0.1 + gap + panel_h / 2 + row * (panel_h + gap)
            door.box((0.07, panel_w, panel_h), (x, y, z), "linen", bevel=0.01)
    door.box((0.08, door_w, 0.07), (x, 0, 0.035), "charcoal")
    door.box((0.1, 0.22, 0.05), (x, 0, 0.1 + gap + panel_h + gap / 2), "metal_dark")


def _sectional_door(room, door, x):
    """A loading door in sections, with a row of lights and a striped bottom edge."""
    door_w, door_h = room.door_w, room.door_h
    door.box((0.05, door_w, door_h), (x, 0, door_h / 2), "metal_light")
    sections = 5
    section_h = door_h / sections
    for index in range(1, sections):
        door.box((0.06, door_w, 0.02), (x, 0, index * section_h), "metal_dark")
    lights = 4
    for index in range(lights):
        y = -door_w / 2 + door_w * (index + 0.5) / lights
        door.box((0.07, door_w / lights - 0.3, section_h - 0.22), (x, y, section_h * 3.5), "sky", bevel=0.01)
    stripes = 10
    for index in range(stripes):
        y = -door_w / 2 + door_w * (index + 0.5) / stripes
        door.box((0.08, door_w / stripes, 0.1), (x, y, 0.05), "yellow" if index % 2 == 0 else "charcoal")


DOORS = {"roller": _roller_door, "panelled": _panelled_door, "sectional": _sectional_door}


# Walls. Each dresses the inside Face of one wall; `side` is which wall it is.

def _garage_walls(room, face, side):
    """Bare brick: a scatter of lighter and darker bricks, and mortar showing in places."""
    rng = room.rng
    course, length = 0.1, 0.3
    rows = int(face.height / course)
    for _ in range(int(face.length * face.height * 4.5)):
        row = rng.randrange(rows)
        u = rng.randrange(int(face.length / length) + 1) * length - (length / 2 if row % 2 else 0.0)
        colour = rng.choice(("terracotta", "terracotta", "wood_dark", "wood"))
        face.slab((u + 0.012, u + length - 0.012), (row * course + 0.012, (row + 1) * course - 0.012), colour, depth=0.008, whole=True)
    # A concrete footing along the bottom.
    face.slab((0, face.length), (0, 0.12), "stone", depth=0.02)
    if side == "west":
        _paint_shelf(room, face)


def _paint_shelf(room, face):
    """A plank on brackets beside the door, with the tins left over from the house."""
    start = room.half_d + room.half_door + 0.45
    end = face.length - 0.3
    if end - start < 0.8:
        return
    z = 1.78
    face.box((start + end) / 2, z, (end - start, 0.2, 0.03), "wood_light")
    for u in (start + 0.12, end - 0.12):
        face.box(u, z - 0.09, (0.03, 0.16, 0.15), "wood_dark")
    tins = ("red", "teal", "white", "yellow", "navy")
    count = min(len(tins), int((end - start - 0.2) / 0.22))
    for index in range(count):
        u = start + 0.18 + index * (end - start - 0.36) / max(count - 1, 1)
        high = room.rng.choice((0.14, 0.16, 0.19))
        centre = face.point(u, z + 0.015 + high / 2, out=0.1)
        face.builder.cylinder(0.065, high, centre, "metal_light", segments=8)
        face.builder.cylinder(0.067, high * 0.55, centre, tins[index], segments=8)


def _lockup_walls(room, face, side):
    """Painted blockwork: the joints show through the paint, over a blue dado."""
    dado = 0.95
    face.slab((0, face.length), (0, dado), "blue", depth=0.006)
    face.slab((0, face.length), (dado, dado + 0.05), "navy", depth=0.008)
    face.slab((0, face.length), (0, 0.1), "navy", depth=0.012)
    block_h, block_w, joint = 0.44, 0.9, 0.014
    row = 0
    z = dado + 0.05 + block_h * 0.6
    while z < face.height - 0.1:
        face.slab((0, face.length), (z, z + joint), "linen", depth=0.004)
        u = block_w * (0.5 if row % 2 else 1.0)
        while u < face.length - 0.1:
            face.slab((u, u + joint), (z - block_h + joint, z), "linen", depth=0.004)
            u += block_w
        row += 1
        z += block_h
    if side == "west":
        # Fire point: a red board with an extinguisher on it, beside the door.
        u = room.half_d + room.half_door + 0.4
        face.slab((u, u + 0.36), (1.05, 1.75), "red", depth=0.012, whole=True)
        face.builder.cylinder(0.06, 0.4, face.point(u + 0.18, 1.33, out=0.012 + 0.06), "red", segments=8)
        face.builder.cylinder(0.025, 0.08, face.point(u + 0.18, 1.57, out=0.012 + 0.06), "charcoal", segments=6)


def _workshop_walls(room, face, side):
    """Painted boarding to waist height, then plaster between timber posts."""
    boards, rail = 1.05, 0.07
    face.slab((0, face.length), (0, boards), "teal", depth=0.014)
    u = 0.18
    while u < face.length:
        face.slab((u, u + 0.012), (0.14, boards), "navy", depth=0.016)
        u += 0.18
    face.slab((0, face.length), (0, 0.14), "wood_dark", depth=0.022)
    face.slab((0, face.length), (boards, boards + rail), "wood", depth=RELIEF)
    beam = face.height - 0.16
    face.slab((0, face.length), (beam, face.height), "wood_dark", depth=0.024)
    bays = max(2, round(face.length / 3.0))
    for index in range(bays + 1):
        u = min(max(face.length * index / bays - 0.07, 0.0), face.length - 0.14)
        face.slab((u, u + 0.14), (boards + rail, beam), "wood_dark", depth=0.024, whole=True)


def _factory_walls(room, face, side):
    """Ribbed steel sheet above a blockwork plinth, on a painted steel frame."""
    plinth = 0.75
    face.slab((0, face.length), (0, plinth), "slate", depth=0.018)
    face.slab((0, face.length), (plinth, plinth + 0.05), "yellow", depth=0.02)
    u = 0.14
    while u < face.length:
        face.slab((u, u + 0.14), (plinth + 0.05, face.height), "metal_light", depth=0.01)
        u += 0.28
    eaves = face.height - 0.22
    face.slab((0, face.length), (eaves, face.height), "teal", depth=0.022)
    bays = max(2, round(face.length / 4.5))
    for index in range(bays + 1):
        u = min(max(face.length * index / bays - 0.13, 0.0), face.length - 0.26)
        face.slab((u, u + 0.26), (0, eaves), "teal", depth=RELIEF, whole=True)
        face.slab((u - 0.05, u + 0.31), (0, 0.06), "metal_dark", depth=RELIEF, whole=True)


WALLS = {"garage": _garage_walls, "lockup": _lockup_walls, "workshop": _workshop_walls, "factory": _factory_walls}


# Floors. Paint and marks are laid in layers on the slab the room already has.

def _mark(floor, size, centre, colour, layer=1, angle=0.0):
    """A flat patch of `size` (x, y) on the floor at `centre` (x, y), turned by `angle`."""
    high = LAYER * layer
    floor.box((size[0], size[1], high), (centre[0], centre[1], high / 2), colour, rotation=(0.0, 0.0, angle))


def _blot(floor, rng, centre, radius, colour, layer=1, points=9):
    """An uneven round stain."""
    outline = []
    for index in range(points):
        turn = math.tau * index / points
        reach = radius * rng.uniform(0.8, 1.1)
        outline.append((math.cos(turn) * reach, math.sin(turn) * reach))
    floor.plate(outline, LAYER * layer, colour, centre=(centre[0], centre[1], 0.0))


def _trail(floor, rng, start, heading, length, colour, step=0.3, wander=0.6, width=0.018):
    """A crack: short straight pieces that wander off the heading."""
    x, y = start
    travelled = 0.0
    while travelled < length:
        turn = heading + rng.uniform(-wander, wander)
        reach = step * rng.uniform(0.6, 1.2)
        end = (x + math.cos(turn) * reach, y + math.sin(turn) * reach)
        _mark(floor, (reach + width, width), ((x + end[0]) / 2, (y + end[1]) / 2), colour, angle=turn)
        x, y = end
        travelled += reach


def _garage_floor(room, floor):
    """A concrete slab cast in four, cracked, with oil where the car used to stand."""
    rng = room.rng
    _mark(floor, (room.width, 0.03), (0, 0.4), "slate")
    _mark(floor, (0.03, room.depth), (0.5, 0), "slate")
    # The car stood nose in from the door; the sump dripped about here.
    spot = (-0.9, -0.55)
    _blot(floor, rng, spot, 0.5, "slate", layer=2, points=11)
    _blot(floor, rng, (spot[0] + 0.05, spot[1] - 0.03), 0.27, "charcoal", layer=3)
    for offset, radius in (((0.62, 0.3), 0.09), ((0.5, -0.42), 0.06), ((-0.55, 0.38), 0.07), ((0.9, 0.05), 0.05)):
        _blot(floor, rng, (spot[0] + offset[0], spot[1] + offset[1]), radius, "charcoal", layer=2, points=6)
    _trail(floor, rng, (room.half_w - 0.05, -room.half_d + 1.5), math.pi * 0.86, 2.4, "slate")
    _trail(floor, rng, (-room.half_w + 1.2, room.half_d - 0.05), -math.pi * 0.42, 1.3, "slate")


def _lockup_floor(room, floor):
    """Grey floor paint, a yellow line round the working area and stripes at the door."""
    inset, line = 0.85, 0.07
    half_w, half_d = room.half_w - inset, room.half_d - inset
    for y in (-half_d, half_d):
        _mark(floor, (half_w * 2 + line, line), (0, y), "yellow")
    _mark(floor, (line, half_d * 2), (half_w, 0), "yellow")
    # The line on the door's side stops either side of the way in.
    side = half_d - room.half_door - 0.25
    for sign in (-1, 1):
        _mark(floor, (line, side), (-half_w, sign * (half_d - side / 2)), "yellow")
    _threshold(room, floor)


def _threshold(room, floor, deep=0.22):
    """Yellow and black stripes across the inside of the doorway."""
    stripes = max(6, int(room.door_w / 0.3))
    wide = room.door_w / stripes
    for index in range(stripes):
        y = -room.half_door + wide * (index + 0.5)
        _mark(floor, (deep, wide), (-room.half_w + deep / 2, y), "yellow" if index % 2 == 0 else "charcoal")


def _workshop_floor(room, floor):
    """Old floorboards, some of them replaced over the years."""
    rng = room.rng
    board = 0.3
    rows = int(room.depth / board)
    for row in range(rows):
        y = -room.half_d + board * (row + 0.5)
        x = -room.half_w
        while x < room.half_w - 0.01:
            length = min(rng.uniform(1.4, 3.2), room.half_w - x)
            colour = rng.choice(("wood", "skin_dark", None, None, None))
            if colour is not None and length > 0.5:
                _mark(floor, (length - 0.02, board - 0.02), (x + length / 2, y), colour)
            else:
                # The end of a board in the old floor.
                _mark(floor, (0.015, board), (x + length, y), "charcoal")
            x += length
    for row in range(1, rows):
        _mark(floor, (room.width, 0.012), (0, -room.half_d + board * row), "charcoal", layer=2)


def _factory_floor(room, floor):
    """Sealed concrete with green walkways edged in yellow, and stripes at the door."""
    lane, edge = 1.0, 0.06
    # One walkway in from the door and down the aisle between the benches, one across the door end.
    aisle_y = -0.6
    cross_x = -room.half_w + room.width * 0.245
    runs = [
        ((-room.half_w, room.half_w - 2.6), (aisle_y - lane / 2, aisle_y + lane / 2)),
        ((cross_x - lane / 2, cross_x + lane / 2), (-room.half_d + 1.2, room.half_d - 1.3)),
    ]
    for (x0, x1), (y0, y1) in runs:
        _mark(floor, (x1 - x0 + edge * 2, y1 - y0 + edge * 2), ((x0 + x1) / 2, (y0 + y1) / 2), "yellow")
    for (x0, x1), (y0, y1) in runs:
        _mark(floor, (x1 - x0, y1 - y0), ((x0 + x1) / 2, (y0 + y1) / 2), "green", layer=2)
    # The slab's joints, in a grid under it all.
    bay = 3.0
    for index in range(1, int(room.width / bay)):
        _mark(floor, (0.02, room.depth), (-room.half_w + index * bay, 0), "stone")
    for index in range(1, int(room.depth / bay)):
        _mark(floor, (room.width, 0.02), (0, -room.half_d + index * bay), "stone")
    _threshold(room, floor, deep=0.3)


FLOORS = {"garage": _garage_floor, "lockup": _lockup_floor, "workshop": _workshop_floor, "factory": _factory_floor}


if __name__ == "__main__":
    common.run(sys.modules[__name__])
