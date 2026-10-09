"""Outdoor surroundings generator: everything outside a premises' walls.

One model per premises, centred on the room, so it drops into the scene at the
origin. `--room` is the inside of the building it goes round (the garage
generator's `--size`). North is +Y. The game looks from the south-east, so the
south and east faces of things are the ones that show, and anything tall to the
south or east of the room has to stand at least its own height away or it would
cover the floor.

Objects:
  ground             lawn, road, pavements, drive and paths
  scenery            buildings, trees, fences and street furniture
  glow_windows_<n>   the windows of one building, lit in the evening
  glow_lamps         the street lamp heads, lit at night
Markers:
  lamp_<n>                under each street lamp head, for a light
  lane_<n>_start, _end    each lane of the road, in the direction traffic drives
  kerb_stop               where a delivery van pulls up, on lane 1

blender --background --factory-startup --python tools/generators/outdoors.py -- \
    --variant street --out assets/models/surroundings/street.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
import vehicles
from common import MeshBuilder

PREVIEW_RESOLUTION = 1400
EXTENT = 30.0
WALL_THICKNESS = 0.15
# Heights of the ground: paving is level with the floor indoors.
LAWN, PAVED, ROAD = -0.02, 0.0, -0.06
BLOOMS = ("pink", "yellow", "white", "red", "purple", "orange")
CAR_COLOURS = ("red", "teal", "yellow", "blue", "cream", "orange")


class Yard:
    """The meshes one layout draws into."""

    def __init__(self, rng):
        self.rng = rng
        self.ground = MeshBuilder()
        self.scenery = MeshBuilder()
        self.glows = {}
        self.markers = []
        self.lamps = 0
        self.buildings = 0

    def glow(self, name):
        return self.glows.setdefault(name, MeshBuilder())

    def windows(self):
        self.buildings += 1
        return self.glow(f"glow_windows_{self.buildings}")

    def finish(self):
        self.ground.finish("ground")
        self.scenery.finish("scenery")
        for name, builder in self.glows.items():
            builder.finish(name)
        for name, position in self.markers:
            common.marker(name, position)


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="street")
    parser.add_argument("--room", type=float, nargs=2, default=(6.0, 5.0), metavar=("W", "D"))


def build(args, rng):
    yard = Yard(rng)
    half_w = args.room[0] / 2 + WALL_THICKNESS
    half_d = args.room[1] / 2 + WALL_THICKNESS
    VARIANTS[args.variant](yard, half_w, half_d)
    yard.finish()


# Ground

def _flat(builder, x0, x1, y0, y1, colour, top=PAVED, depth=0.3):
    builder.box((x1 - x0, y1 - y0, depth), ((x0 + x1) / 2, (y0 + y1) / 2, top - depth / 2), colour)


def _road(yard, x0, x1, pavement, surface="charcoal", paving="stone"):
    """Road running north to south between x0 and x1, with a pavement either side.

    Traffic keeps left: lane 1 is the east side, heading south, and lane 2 the
    west side, heading north.
    """
    ground = yard.ground
    _flat(ground, x0, x1, -EXTENT, EXTENT, surface, top=ROAD)
    for low, high in ((x0 - pavement, x0), (x1, x1 + pavement)):
        _flat(ground, low, high, -EXTENT, EXTENT, paving)
        y = -EXTENT + 0.7
        while y < EXTENT:
            _flat(ground, low, high, y - 0.02, y + 0.02, "sand", top=PAVED + 0.003, depth=0.02)
            y += 1.4
    for x in (x0, x1):
        _flat(ground, x - 0.08, x + 0.08, -EXTENT, EXTENT, "linen", top=PAVED + 0.005)
    middle = (x0 + x1) / 2
    y = -EXTENT + 1.0
    while y < EXTENT - 1.4:
        _flat(ground, middle - 0.07, middle + 0.07, y, y + 1.4, "linen", top=ROAD + 0.004, depth=0.02)
        y += 3.2
    quarter = (x1 - x0) / 4
    yard.markers += [
        ("lane_1_start", (middle + quarter, EXTENT, 0)), ("lane_1_end", (middle + quarter, -EXTENT, 0)),
        ("lane_2_start", (middle - quarter, -EXTENT, 0)), ("lane_2_end", (middle - quarter, EXTENT, 0)),
        ("kerb_stop", (middle + quarter + 0.25, 1.2, 0)),
    ]


def _slabs(builder, x0, x1, y0, y1, colour, joint="sand", size=0.75):
    """Paved area with the joints between the slabs drawn in."""
    _flat(builder, x0, x1, y0, y1, colour)
    for index in range(1, round((x1 - x0) / size)):
        x = x0 + (x1 - x0) * index / round((x1 - x0) / size)
        _flat(builder, x - 0.015, x + 0.015, y0, y1, joint, top=PAVED + 0.003, depth=0.02)
    for index in range(1, round((y1 - y0) / size)):
        y = y0 + (y1 - y0) * index / round((y1 - y0) / size)
        _flat(builder, x0, x1, y - 0.015, y + 0.015, joint, top=PAVED + 0.003, depth=0.02)


def _tufts(yard, x0, x1, y0, y1, count, keep_out=()):
    """Scatters longer grass and the odd daisy over a lawn, missing the `keep_out` rectangles."""
    rng = yard.rng
    for _ in range(count):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        if any(a - 0.2 < x < b + 0.2 and c - 0.2 < y < d + 0.2 for a, b, c, d in keep_out):
            continue
        if rng.random() < 0.25:
            yard.ground.box((0.06, 0.06, 0.05), (x, y, LAWN + 0.025), rng.choice(("white", "yellow", "white", "pink")))
        else:
            size = rng.uniform(0.1, 0.2)
            yard.ground.box((size, size * 0.45, 0.02), (x, y, LAWN + 0.004), "lime", rotation=(0, 0, rng.uniform(0, 3)))


# Buildings

def _wall_box(builder, rect, side, along, z, width, height, thick, colour, out=0.0):
    """Box flat against one side of `rect`: `along` metres from its west or south end, centred `out` from the face."""
    x0, x1, y0, y1 = rect
    if side in "SN":
        centre = (x0 + along, y0 - out if side == "S" else y1 + out, z)
        return builder.box((width, thick, height), centre, colour)
    centre = (x1 + out if side == "E" else x0 - out, y0 + along, z)
    return builder.box((thick, width, height), centre, colour)


def _window(yard, glow, rect, side, along, z, width=1.0, height=1.1):
    scenery = yard.scenery
    _wall_box(scenery, rect, side, along, z, width + 0.16, height + 0.16, 0.08, "white")
    _wall_box(glow, rect, side, along, z, width, height, 0.06, "sky", out=0.02)
    _wall_box(scenery, rect, side, along, z, 0.05, height, 0.04, "white", out=0.045)
    _wall_box(scenery, rect, side, along, z, width, 0.05, 0.04, "white", out=0.045)
    _wall_box(scenery, rect, side, along, z - height / 2 - 0.1, width + 0.3, 0.07, 0.18, "linen", out=0.03)


def _door(yard, rect, side, along, colour, width=0.95, height=2.0):
    scenery = yard.scenery
    _wall_box(scenery, rect, side, along, height / 2 + 0.05, width + 0.18, height + 0.14, 0.08, "white")
    _wall_box(scenery, rect, side, along, height / 2, width, height, 0.06, colour, out=0.03)
    _wall_box(scenery, rect, side, along + width * 0.3, height * 0.5, 0.07, 0.07, 0.05, "yellow", out=0.07)
    _wall_box(scenery, rect, side, along, 0.06, width + 0.5, 0.12, 0.6, "stone", out=0.3)


def _house(yard, rect, wall="brick", roof="terracotta", storeys=2, ridge="x", doors=(), door_colour="teal", windows="SE"):
    """House filling `rect` (x0, x1, y0, y1), with windows on the named sides.

    `doors` are (side, along) pairs. `ridge` is the axis the roof ridge runs along.
    """
    x0, x1, y0, y1 = rect
    rng, scenery = yard.rng, yard.scenery
    width, depth = x1 - x0, y1 - y0
    centre_x, centre_y = (x0 + x1) / 2, (y0 + y1) / 2
    wall_h = 2.75 * storeys + 0.1
    roof_h = 1.9 if storeys > 1 else 1.6
    scenery.box((width, depth, wall_h), (centre_x, centre_y, wall_h / 2), wall)
    scenery.box((width + 0.08, depth + 0.08, 0.3), (centre_x, centre_y, 0.15), "slate")
    if ridge == "x":
        faces = scenery.box((width + 0.1, depth + 0.7, roof_h), (centre_x, centre_y, wall_h + roof_h / 2), roof, taper=(1.0, 0.04))
        for facing in ((1, 0, 0), (-1, 0, 0)):
            scenery.paint(faces, wall, facing=facing)
    else:
        faces = scenery.box((width + 0.7, depth + 0.1, roof_h), (centre_x, centre_y, wall_h + roof_h / 2), roof, taper=(0.04, 1.0))
        for facing in ((0, 1, 0), (0, -1, 0)):
            scenery.paint(faces, wall, facing=facing)
    chimney = (centre_x + width * 0.28, centre_y) if ridge == "x" else (centre_x, centre_y + depth * 0.28)
    scenery.box((0.55, 0.55, 1.3), (*chimney, wall_h + roof_h - 0.2), "brick" if wall != "brick" else "wood_dark")
    scenery.cylinder(0.14, 0.3, (*chimney, wall_h + roof_h + 0.55), "terracotta", segments=8)

    glow = yard.windows()
    for side in windows:
        length = width if side in "SN" else depth
        count = max(1, int((length - 0.6) / 2.3))
        for index in range(count):
            along = length * (index + 0.5) / count
            for storey in range(storeys):
                if storey == 0 and any(door_side == side and abs(door_along - along) < 1.2 for door_side, door_along in doors):
                    continue
                _window(yard, glow, rect, side, along, 1.55 + storey * 2.75, width=rng.choice((0.9, 1.0, 1.2)))
    for door_side, door_along in doors:
        _door(yard, rect, door_side, door_along, door_colour)
        _wall_box(scenery, rect, door_side, door_along, 2.35, 1.6, 0.1, 0.7, roof, out=0.35)


def _unit(yard, rect, height=3.6, wall="slate", trim="navy", sign="orange", shutter=None, windows="E", door=None):
    """Flat-roofed industrial unit filling `rect`. `shutter` is the side its roller door is on."""
    x0, x1, y0, y1 = rect
    rng, scenery = yard.rng, yard.scenery
    width, depth = x1 - x0, y1 - y0
    centre_x, centre_y = (x0 + x1) / 2, (y0 + y1) / 2
    faces = scenery.box((width, depth, height), (centre_x, centre_y, height / 2), wall)
    scenery.paint(faces, "stone", facing=(0, 0, 1))
    # Parapet round the roof and a painted band below it.
    for low, high, colour, out in ((height - 0.5, height - 0.15, trim, 0.02), (height - 0.15, height + 0.2, "metal_dark", 0.06)):
        for side, length in (("S", width), ("N", width), ("E", depth), ("W", depth)):
            _wall_box(scenery, rect, side, length / 2, (low + high) / 2, length + out * 2, high - low, out * 2 + 0.12, colour)
    for _ in range(max(1, int(width * depth / 18))):
        x, y = rng.uniform(x0 + 1, x1 - 1), rng.uniform(y0 + 1, y1 - 1)
        if rng.random() < 0.5:
            scenery.box((0.8, 0.8, 0.5), (x, y, height + 0.25), "metal_light", bevel=0.04)
        else:
            scenery.box((1.4, 0.9, 0.16), (x, y, height + 0.08), "sky", taper=0.8)

    glow = yard.windows()
    for side in windows:
        length = width if side in "SN" else depth
        count = max(1, int(length / 3.2))
        for index in range(count):
            along = length * (index + 0.5) / count
            if door is not None and door[0] == side and abs(door[1] - along) < 1.2:
                continue
            if shutter == side and abs(length / 2 - along) < 2.2:
                continue
            _window(yard, glow, rect, side, along, 1.9 if height < 4.5 else 2.4, width=1.4, height=0.8)
    if door is not None:
        _door(yard, rect, door[0], door[1], trim)
    if shutter is not None:
        length = width if shutter in "SN" else depth
        _wall_box(scenery, rect, shutter, length / 2, 1.35, 2.6, 2.7, 0.08, "metal_light", out=0.02)
        for index in range(1, 9):
            _wall_box(scenery, rect, shutter, length / 2, index * 0.3, 2.6, 0.02, 0.04, "metal_dark", out=0.05)
        _wall_box(scenery, rect, shutter, length / 2, 2.82, 2.9, 0.26, 0.2, "metal_dark", out=0.08)
        _wall_box(scenery, rect, shutter, length / 2, height - 0.33, 3.2, 0.5, 0.06, sign, out=0.07)
        _wall_box(scenery, rect, shutter, length / 2, height - 0.33, 2.2, 0.14, 0.04, "white", out=0.1)


# Plants

def _tree(yard, x, y, kind="round", colour="lime", scale=1.0):
    rng, scenery = yard.rng, yard.scenery
    if kind == "conifer":
        scenery.cylinder(0.14 * scale, 0.9 * scale, (x, y, 0.45 * scale), "wood_dark", segments=6)
        for index in range(3):
            radius = (1.15 - index * 0.3) * scale
            scenery.cylinder(radius, 1.5 * scale, (x, y, (1.3 + index * 1.0) * scale), colour, segments=7, radius_top=0.05)
        return
    trunk = 1.7 * scale
    scenery.cylinder(0.17 * scale, trunk, (x, y, trunk / 2), "wood_dark", segments=6, radius_top=0.12 * scale)
    scenery.ball(1.25 * scale, (x, y, trunk + 0.8 * scale), colour, scale=(1.0, 1.0, 0.85), rotation=(0, 0, rng.uniform(0, 3)))
    for _ in range(3):
        angle = rng.uniform(0, math.tau)
        offset = 0.75 * scale
        scenery.ball(
            rng.uniform(0.6, 0.85) * scale,
            (x + math.cos(angle) * offset, y + math.sin(angle) * offset, trunk + rng.uniform(0.4, 1.4) * scale),
            colour, subdivisions=1, rotation=(rng.uniform(0, 3), 0, rng.uniform(0, 3)))


def _shrub(yard, x, y, colour="teal", size=0.5):
    yard.scenery.ball(size, (x, y, size * 0.55), colour, subdivisions=1, scale=(1.0, 1.0, 0.75), rotation=(0, 0, yard.rng.uniform(0, 3)))


def _hedge(yard, x0, x1, y0, y1, height=0.9, colour="teal"):
    yard.scenery.box((x1 - x0, y1 - y0, height), ((x0 + x1) / 2, (y0 + y1) / 2, height / 2), colour, bevel=0.1, bevel_segments=2)


def _flower_bed(yard, x0, x1, y0, y1, density=7.0):
    rng, scenery = yard.rng, yard.scenery
    _flat(scenery, x0, x1, y0, y1, "wood_dark", top=0.05, depth=0.1)
    for _ in range(int((x1 - x0) * (y1 - y0) * density)):
        x, y = rng.uniform(x0 + 0.08, x1 - 0.08), rng.uniform(y0 + 0.08, y1 - 0.08)
        height = rng.uniform(0.12, 0.26)
        scenery.box((0.11, 0.11, height), (x, y, 0.05 + height / 2), rng.choice(("green", "green", "lime")))
        if rng.random() < 0.7:
            scenery.box((0.1, 0.1, 0.07), (x, y, 0.05 + height + 0.03), rng.choice(BLOOMS), rotation=(0, 0, rng.uniform(0, 1.5)))


def _raised_bed(yard, x0, x1, y0, y1):
    rng, scenery = yard.rng, yard.scenery
    centre = ((x0 + x1) / 2, (y0 + y1) / 2, 0.0)
    scenery.tray((x1 - x0, y1 - y0, 0.3), 0.06, "wood", centre=centre, floor=0.22)
    crop = rng.choice(("lime", "green", "orange", "red"))
    rows = max(2, int((y1 - y0) / 0.3))
    for row in range(rows):
        y = y0 + (y1 - y0) * (row + 0.5) / rows
        x = x0 + 0.2
        while x < x1 - 0.15:
            scenery.box((0.14, 0.14, 0.16), (x, y, 0.3), "green" if crop != "lime" else "lime", rotation=(0, 0, rng.uniform(0, 1.5)))
            if crop in ("orange", "red") and rng.random() < 0.6:
                scenery.box((0.07, 0.07, 0.07), (x + 0.06, y, 0.36), crop)
            x += 0.28


# Garden and street furniture

def _fence(yard, start, end, height=1.4, board="wood", post="wood_dark"):
    """Fence between two points on the same north-south or east-west line."""
    scenery = yard.scenery
    (x0, y0), (x1, y1) = start, end
    length = abs(x1 - x0) + abs(y1 - y0)
    along_x = abs(x1 - x0) > abs(y1 - y0)
    centre = ((x0 + x1) / 2, (y0 + y1) / 2)
    scenery.box((length, 0.05, height) if along_x else (0.05, length, height), (*centre, height / 2 + 0.03), board)
    posts = max(1, round(length / 1.8))
    for index in range(posts + 1):
        x, y = x0 + (x1 - x0) * index / posts, y0 + (y1 - y0) * index / posts
        scenery.box((0.11, 0.11, height + 0.12), (x, y, (height + 0.12) / 2), post)


def _railings(yard, start, end, height=1.7):
    """See-through metal fence: posts and two rails."""
    scenery = yard.scenery
    (x0, y0), (x1, y1) = start, end
    length = abs(x1 - x0) + abs(y1 - y0)
    along_x = abs(x1 - x0) > abs(y1 - y0)
    centre = ((x0 + x1) / 2, (y0 + y1) / 2)
    for z in (0.35, height - 0.2):
        scenery.box((length, 0.04, 0.05) if along_x else (0.04, length, 0.05), (*centre, z), "metal_dark")
    posts = max(1, round(length / 0.5))
    for index in range(posts + 1):
        x, y = x0 + (x1 - x0) * index / posts, y0 + (y1 - y0) * index / posts
        thick = 0.09 if index % 5 == 0 else 0.03
        scenery.box((thick, thick, height), (x, y, height / 2), "metal_dark", taper=1.0 if thick > 0.05 else 0.3)


def _lamp_post(yard, x, y, reach):
    """Street lamp with its head `reach` metres east of the pole (negative for west)."""
    scenery = yard.scenery
    yard.lamps += 1
    scenery.cylinder(0.1, 0.5, (x, y, 0.25), "charcoal", segments=8)
    scenery.cylinder(0.055, 3.7, (x, y, 1.85), "metal_dark", segments=6)
    scenery.box((abs(reach) + 0.1, 0.07, 0.07), (x + reach / 2, y, 3.68), "metal_dark")
    scenery.box((0.5, 0.26, 0.1), (x + reach, y, 3.66), "charcoal", bevel=0.02)
    yard.glow("glow_lamps").box((0.4, 0.18, 0.05), (x + reach, y, 3.59), "white")
    yard.markers.append((f"lamp_{yard.lamps}", (x + reach, y, 3.4)))


def _wheelie_bin(yard, x, y, colour):
    scenery = yard.scenery
    scenery.box((0.5, 0.56, 0.9), (x, y, 0.5), colour, taper=1.14)
    scenery.box((0.6, 0.66, 0.07), (x, y, 0.985), colour, bevel=0.015)
    for side in (-1, 1):
        scenery.cylinder(0.09, 0.05, (x + side * 0.22, y + 0.27, 0.09), "charcoal", segments=8, axis="X")


def _pillar_box(yard, x, y):
    scenery = yard.scenery
    scenery.cylinder(0.25, 0.12, (x, y, 0.06), "charcoal", segments=10)
    scenery.cylinder(0.22, 1.15, (x, y, 0.69), "red", segments=10)
    scenery.cylinder(0.26, 0.1, (x, y, 1.3), "red", segments=10, radius_top=0.2)
    scenery.box((0.02, 0.24, 0.035), (x + 0.215, y, 1.05), "ink")
    scenery.box((0.02, 0.16, 0.2), (x + 0.215, y, 0.75), "white")


def _bench(yard, x, y):
    """Garden bench facing south."""
    scenery = yard.scenery
    for side in (-0.65, 0.65):
        scenery.box((0.07, 0.5, 0.42), (x + side, y, 0.21), "charcoal")
        scenery.box((0.07, 0.07, 0.9), (x + side, y + 0.24, 0.45), "charcoal")
    scenery.box((1.5, 0.46, 0.06), (x, y - 0.02, 0.45), "wood", bevel=0.01)
    for z in (0.66, 0.84):
        scenery.box((1.5, 0.05, 0.12), (x, y + 0.24, z), "wood")


def _shed(yard, x, y):
    scenery = yard.scenery
    scenery.box((2.2, 1.8, 1.9), (x, y, 0.95), "wood")
    for index in range(1, 8):
        scenery.box((0.02, 1.8, 0.02), (x + 1.1, y, index * 0.24), "wood_dark")
    scenery.box((2.5, 1.9, 0.6), (x, y, 2.2), "slate", taper=(0.04, 1.0))
    scenery.box((0.8, 0.05, 1.6), (x - 0.4, y - 0.9, 0.82), "wood_dark")
    scenery.box((0.6, 0.05, 0.5), (x + 0.55, y - 0.9, 1.2), "sky")


def _washing_line(yard, x, y):
    rng, scenery = yard.rng, yard.scenery
    scenery.cylinder(0.035, 1.9, (x, y, 0.95), "metal_light", segments=6)
    for turn in range(4):
        angle = math.pi / 4 + turn * math.pi / 2
        dx, dy = math.cos(angle), math.sin(angle)
        scenery.box((1.1, 0.03, 0.03), (x + dx * 0.55, y + dy * 0.55, 1.88), "metal_light", rotation=(0, 0, angle))
        # A line strung across to the next arm, with washing on two of them.
        next_angle = angle + math.pi / 2
        middle = (x + (dx + math.cos(next_angle)) * 0.5, y + (dy + math.sin(next_angle)) * 0.5)
        scenery.box((1.5, 0.015, 0.015), (*middle, 1.86), "white", rotation=(0, 0, angle + math.pi * 0.75))
        if turn % 2 == 0:
            for step in (-0.4, 0.0, 0.4):
                drop = rng.uniform(0.3, 0.55)
                spot = (middle[0] + math.cos(angle + math.pi * 0.75) * step, middle[1] + math.sin(angle + math.pi * 0.75) * step, 1.86 - drop / 2)
                scenery.box((0.3, 0.02, drop), spot, rng.choice(("white", "sky", "pink", "yellow", "red")), rotation=(0, 0, angle + math.pi * 0.75))


def _patio_set(yard, x, y, colour="red"):
    """Round table, two chairs and a parasol."""
    scenery = yard.scenery
    scenery.cylinder(0.55, 0.05, (x, y, 0.7), "wood_light", segments=10)
    scenery.cylinder(0.05, 0.7, (x, y, 0.35), "charcoal", segments=6)
    scenery.cylinder(0.3, 0.04, (x, y, 0.02), "charcoal", segments=8)
    scenery.cylinder(0.025, 2.3, (x, y, 1.15), "wood_dark", segments=6)
    scenery.cylinder(1.25, 0.45, (x, y, 2.2), colour, segments=8, radius_top=0.05)
    scenery.cylinder(1.25, 0.08, (x, y, 1.94), "cream", segments=8)
    for dx, dy in ((0.95, 0.1), (-0.3, -0.95)):
        scenery.box((0.42, 0.42, 0.05), (x + dx, y + dy, 0.42), "wood", bevel=0.01)
        for leg_x in (-0.17, 0.17):
            for leg_y in (-0.17, 0.17):
                scenery.box((0.04, 0.04, 0.42), (x + dx + leg_x, y + dy + leg_y, 0.21), "charcoal")
        back = (0.19, 0.0) if dx > 0.5 else (0.0, -0.19)
        size = (0.05, 0.42, 0.45) if dx > 0.5 else (0.42, 0.05, 0.45)
        scenery.box(size, (x + dx + back[0], y + dy + back[1], 0.66), "wood")


def _pond(yard, x, y, radius=1.0):
    rng, scenery = yard.rng, yard.scenery
    scenery.cylinder(radius + 0.16, 0.08, (x, y, 0.01), "stone", segments=9)
    scenery.cylinder(radius, 0.04, (x, y, 0.04), "sky", segments=9)
    for _ in range(4):
        angle, distance = rng.uniform(0, math.tau), rng.uniform(0.1, radius - 0.3)
        scenery.cylinder(0.16, 0.02, (x + math.cos(angle) * distance, y + math.sin(angle) * distance, 0.065), "lime", segments=6)
    for _ in range(5):
        angle = rng.uniform(0, math.tau)
        scenery.ball(rng.uniform(0.14, 0.26), (x + math.cos(angle) * (radius + 0.1), y + math.sin(angle) * (radius + 0.1), 0.06), rng.choice(("stone", "slate")), subdivisions=1)


def _stepping_stones(yard, start, end, colour="linen"):
    (x0, y0), (x1, y1) = start, end
    count = max(2, round(math.hypot(x1 - x0, y1 - y0) / 0.75))
    for index in range(count + 1):
        x, y = x0 + (x1 - x0) * index / count, y0 + (y1 - y0) * index / count
        wobble = yard.rng.uniform(-0.08, 0.08)
        yard.ground.cylinder(0.27, 0.04, (x + wobble, y - wobble, LAWN + 0.005), colour, segments=7, rotation=(0, 0, yard.rng.uniform(0, 1)))


def _plant_pot(yard, x, y, bloom):
    scenery = yard.scenery
    scenery.cylinder(0.16, 0.3, (x, y, 0.15), "terracotta", segments=8, radius_top=0.2)
    scenery.ball(0.22, (x, y, 0.4), "green", subdivisions=1)
    for dx, dy in ((0.1, 0.05), (-0.08, 0.1), (0.0, -0.12)):
        scenery.box((0.08, 0.08, 0.08), (x + dx, y + dy, 0.6), bloom)


def _pallets(yard, x, y, count, turn=0.0):
    scenery = yard.scenery
    for level in range(count):
        z = level * 0.15
        angle = turn + yard.rng.uniform(-0.08, 0.08)
        scenery.box((1.2, 1.0, 0.03), (x, y, z + 0.135), "wood_light", rotation=(0, 0, angle))
        for offset in (-0.5, 0.0, 0.5):
            dx, dy = -math.sin(angle) * offset * 0.9, math.cos(angle) * offset * 0.9
            scenery.box((1.2, 0.1, 0.1), (x + dx, y + dy, z + 0.07), "wood", rotation=(0, 0, angle))


def _skip(yard, x, y, colour="yellow"):
    rng, scenery = yard.rng, yard.scenery
    scenery.tray((3.0, 1.7, 1.1), 0.08, colour, centre=(x, y, 0.08), taper=0.35, rim=(0.05, 0.1))
    for foot in (-0.9, 0.9):
        scenery.box((0.2, 1.3, 0.08), (x + foot, y, 0.04), "charcoal")
    for _ in range(9):
        size = (rng.uniform(0.3, 0.9), rng.uniform(0.2, 0.6), rng.uniform(0.1, 0.3))
        scenery.box(size, (x + rng.uniform(-1.0, 1.0), y + rng.uniform(-0.5, 0.5), 0.95), rng.choice(("cardboard", "cardboard_dark", "wood", "slate", "linen")), rotation=(0, rng.uniform(-0.2, 0.2), rng.uniform(0, 3)))


def _bollard(yard, x, y, colour="yellow"):
    yard.scenery.cylinder(0.08, 0.9, (x, y, 0.45), colour, segments=8)
    yard.scenery.cylinder(0.085, 0.12, (x, y, 0.7), "charcoal", segments=8)


def _cone(yard, x, y):
    yard.scenery.box((0.3, 0.3, 0.04), (x, y, 0.02), "orange")
    yard.scenery.cylinder(0.11, 0.45, (x, y, 0.26), "orange", segments=8, radius_top=0.03)
    yard.scenery.cylinder(0.075, 0.08, (x, y, 0.3), "white", segments=8, radius_top=0.06)


def _parked(yard, x, y, turns, variant="car", colour=None):
    colour = colour or yard.rng.choice(CAR_COLOURS)
    vehicles.add(yard.scenery, yard.scenery, variant, colour, origin=(x, y), turns=turns)


# Layouts

def _street(yard, half_w, half_d):
    """A residential street: the garage beside its house, gardens all round and neighbours over the road."""
    rng, ground = yard.rng, yard.ground
    road = (-12.7, -7.7)
    pavement = 1.2
    front = road[1] + pavement
    plot = (front, 11.5, -9.6, 14.0)
    house = (-3.4, 4.2, half_d + 3.2, half_d + 9.4)
    north_house, south_house = (-3.6, 3.6, 15.8, 22.0), (-4.2, 3.0, -19.6, -13.4)

    _flat(ground, front, EXTENT, -EXTENT, EXTENT, "green", top=LAWN)
    _flat(ground, -EXTENT, road[0] - pavement, -EXTENT, EXTENT, "green", top=LAWN)
    _road(yard, road[0], road[1], pavement)

    # The drive, and paths round the garage to the house and the back garden.
    drive = (front, -half_w, -1.75, 1.75)
    _flat(ground, *drive, "sand")
    for y in (-1.75, 1.75):
        _flat(ground, front, -half_w, y - 0.07, y + 0.07, "linen", top=PAVED + 0.004)
    x = front + 0.6
    while x < -half_w - 0.3:
        _flat(ground, x - 0.015, x + 0.015, -1.68, 1.68, "linen", top=PAVED + 0.003, depth=0.02)
        x += 0.6
    passage = (-half_w - 1.0, half_w + 1.1, half_d, half_d + 1.1)
    side_path = (half_w, half_w + 1.1, -half_d + 1.0, half_d)
    front_path = (front, house[0], house[2] + 2.5, house[2] + 3.6)
    patio = (half_w + 1.1, half_w + 4.3, -4.4, -1.2)
    _slabs(ground, *passage, "sand", joint="linen")
    _slabs(ground, *side_path, "sand", joint="linen")
    _slabs(ground, *front_path, "sand", joint="linen")
    _slabs(ground, -half_w - 1.0, -half_w, 1.75, half_d, "sand", joint="linen")
    _slabs(ground, *patio, "linen", joint="sand", size=0.8)

    _house(yard, house, doors=(("W", 3.05), ("E", 1.55)), windows="SEW")
    for offset, bloom in ((-1.0, "pink"), (1.0, "yellow")):
        _plant_pot(yard, house[1] + 0.35, house[2] + 1.55 + offset, bloom)
    _flower_bed(yard, house[0] + 0.4, house[1] - 0.4, house[2] - 0.75, house[2] - 0.15)

    # Front garden: hedge along the pavement, a tree, bins by the garage.
    for low, high in ((plot[2], drive[2] - 0.35), (drive[3] + 0.35, front_path[2] - 0.2), (front_path[3] + 0.2, plot[3])):
        _hedge(yard, front + 0.08, front + 0.62, low, high)
    _tree(yard, -2.5, -7.0, colour="lime")
    _tree(yard, -5.0, 12.4, kind="conifer", colour="teal", scale=0.9)
    _wheelie_bin(yard, -half_w - 0.5, -half_d - 0.55, "green")
    _wheelie_bin(yard, -half_w - 1.15, -half_d - 0.55, "charcoal")
    _flower_bed(yard, -2.7, 2.7, -half_d - 1.15, -half_d - 0.5)
    _bench(yard, 0.6, -5.4)
    _shrub(yard, -1.0, -5.5, size=0.45)
    _shrub(yard, 2.3, -5.6, colour="lime", size=0.4)
    _stepping_stones(yard, (-half_w - 1.2, -2.2), (-0.4, -4.4))
    _flower_bed(yard, front + 0.8, front + 1.4, -9.2, -3.2, density=6.0)

    # Back garden.
    _patio_set(yard, half_w + 2.8, -2.8)
    _raised_bed(yard, half_w + 1.5, half_w + 3.1, -0.4, 0.6)
    _raised_bed(yard, half_w + 1.5, half_w + 3.1, 1.0, 2.0)
    _stepping_stones(yard, (7.8, -4.8), (8.6, -6.0))
    _pond(yard, 9.2, -7.2)
    _washing_line(yard, 9.3, 0.2)
    _shed(yard, 9.9, 10.4)
    _tree(yard, 7.3, 2.3, colour="pink", scale=0.85)
    _tree(yard, 8.6, 7.4, kind="conifer", colour="teal", scale=0.8)
    _tree(yard, 4.6, -7.6, colour="orange", scale=0.8)
    _flower_bed(yard, plot[1] - 0.8, plot[1] - 0.2, -9.0, 0.5)
    _flower_bed(yard, 1.0, plot[1] - 1.0, plot[2] + 0.2, plot[2] + 0.8, density=6.0)
    for x, y in ((10.6, 3.2), (10.4, 7.6), (6.8, 11.9), (2.0, -8.4)):
        _shrub(yard, x, y, colour=rng.choice(("teal", "lime")), size=rng.uniform(0.4, 0.6))
    _fence(yard, (plot[0], plot[2]), (plot[1], plot[2]))
    _fence(yard, (plot[1], plot[2]), (plot[1], plot[3]))
    _fence(yard, (plot[0], plot[3]), (plot[1], plot[3]))
    room = (-half_w, half_w, -half_d, half_d)
    paved = (room, house, drive, passage, side_path, front_path, patio)
    _tufts(yard, plot[0] + 0.7, plot[1] - 0.9, plot[2] + 0.9, plot[3] - 0.3, 150, keep_out=paved)

    # Street furniture.
    _pillar_box(yard, front - 0.45, -3.6)
    for y in (-22.4, -2.4, 17.6):
        _lamp_post(yard, front - 0.3, y, -1.1)
    for y in (-12.4, 7.6):
        _lamp_post(yard, road[0] - 0.9, y, 1.1)

    # Neighbours either side.
    for rect, wall, roof, colour in ((north_house, "cream", "slate", "red"), (south_house, "linen", "navy", "yellow")):
        _house(yard, rect, wall=wall, roof=roof, doors=(("W", 3.0),), door_colour=colour, windows="SEW")
        _flat(ground, front, rect[0], rect[2] + 2.5, rect[2] + 3.5, "sand")
        _hedge(yard, front + 0.08, front + 0.62, rect[2] - 1.5, rect[2] + 2.2)
        _hedge(yard, front + 0.08, front + 0.62, rect[2] + 3.8, rect[3] + 1.5)
    _fence(yard, (plot[0], -21.8), (plot[1], -21.8))
    _fence(yard, (plot[1], -21.8), (plot[1], plot[2]))
    _fence(yard, (plot[1], plot[3]), (plot[1], 24.2))
    _tree(yard, 7.5, 18.7, colour="lime", scale=1.1)
    _tree(yard, 6.4, -15.0, kind="conifer", colour="teal")
    _tree(yard, -1.5, -11.6, colour="yellow", scale=0.7)
    _tufts(yard, plot[0] + 0.8, plot[1] - 0.5, plot[3] + 0.4, 24.0, 60, keep_out=(north_house,))
    _tufts(yard, plot[0] + 0.8, plot[1] - 0.5, -21.4, plot[2] - 0.4, 60, keep_out=(south_house,))

    # The gardens backing on to ours, and the houses beyond them.
    for rect, wall, roof in (((16.5, 23.0, -13.0, -6.2), "sand", "brick"), ((16.5, 23.0, 0.4, 7.2), "cream", "terracotta"), ((16.5, 23.0, 13.0, 19.8), "brick", "slate")):
        _house(yard, rect, wall=wall, roof=roof, ridge="y", windows="SE")
    for y in (-3.0, 10.2):
        _fence(yard, (plot[1], y), (16.5, y))
    for x, y, kind, colour in ((13.6, -6.5, "round", "lime"), (14.2, 4.4, "conifer", "teal"), (13.4, 14.5, "round", "orange"), (13.8, -16.0, "round", "pink")):
        _tree(yard, x, y, kind=kind, colour=colour, scale=rng.uniform(0.85, 1.05))
    _tufts(yard, plot[1] + 0.4, 16.2, -20.0, 22.0, 70)

    # Over the road.
    far = road[0] - pavement
    for index, (rect, wall, roof, colour) in enumerate((
            ((-23.0, -16.6, -15.4, -8.6), "cream", "slate", "blue"),
            ((-23.0, -16.6, -3.4, 3.4), "linen", "terracotta", "red"),
            ((-23.0, -16.6, 8.6, 15.4), "sand", "navy", "green"))):
        _house(yard, rect, wall=wall, roof=roof, ridge="y", doors=(("E", 2.2),), door_colour=colour, windows="SE")
        _flat(ground, rect[1], far, rect[2] + 1.7, rect[2] + 2.7, "sand")
        _flat(ground, rect[1] - 1.0, far, rect[3] + 0.3, rect[3] + 2.7, "sand")
        _parked(yard, rect[1] + 1.2, rect[3] + 1.5, 1, colour=CAR_COLOURS[index * 2])
        _hedge(yard, far - 0.62, far - 0.08, rect[2] - 2.0, rect[2] + 1.4)
        _hedge(yard, far - 0.62, far - 0.08, rect[2] + 3.0, rect[3] + 0.2)
        _flower_bed(yard, rect[1] + 0.15, rect[1] + 0.7, rect[2] + 3.2, rect[3] - 0.2, density=6.0)
        _tree(yard, rect[1] + 1.6, rect[2] - 0.6, kind=("round", "conifer", "round")[index], colour=("pink", "teal", "lime")[index], scale=0.85)
        _fence(yard, (-EXTENT, rect[2] - 2.3), (rect[1] - 1.0, rect[2] - 2.3))
    _tufts(yard, -16.2, far - 0.8, -22.0, 22.0, 90)


def _estate(yard, half_w, half_d):
    """A trading estate: a terrace of units on a concrete yard, with warehouses over the road.

    Laid out round the small unit (8 x 7). A bigger room pushes the road further
    west and the yard further south by as much as it has grown, so the forecourt
    and the gap to the yard's clutter stay the same.
    """
    rng, ground = yard.rng, yard.ground
    west = half_w - (4.0 + WALL_THICKNESS)
    south = half_d - (3.5 + WALL_THICKNESS)
    road = (-18.2 - west, -12.2 - west)
    pavement = 1.2
    front = road[1] + pavement
    back = half_w + 4.6

    _flat(ground, front, back, -EXTENT, EXTENT, "linen", top=LAWN)
    _flat(ground, back, EXTENT, -EXTENT, EXTENT, "green", top=LAWN)
    _flat(ground, -EXTENT, road[0] - pavement, -EXTENT, EXTENT, "linen", top=LAWN)
    _road(yard, road[0], road[1], pavement)

    # Forecourt: tarmac in front of the units, parking bays along the verge.
    forecourt = (front + 1.4, -half_w, -EXTENT, EXTENT)
    _flat(ground, *forecourt, "slate")
    for y in range(-24, 25, 3):
        if abs(y) > 3:
            _flat(ground, forecourt[0], forecourt[0] + 3.4, y - 0.05, y + 0.05, "linen", top=PAVED + 0.003, depth=0.02)
    for low, high in ((-EXTENT, -3.4), (3.4, EXTENT)):
        _flat(ground, front, forecourt[0], low, high, "green", top=PAVED + 0.02)
        _flat(ground, forecourt[0] - 0.1, forecourt[0], low, high, "linen", top=PAVED + 0.04)
    _flat(ground, front, forecourt[0], -3.4, 3.4, "slate")
    for y in (-19.5, -7.5, 9.0, 21.0):
        _tree(yard, front + 0.7, y, colour=rng.choice(("lime", "teal")), scale=0.7)
    for y in (-13.5, 15.0):
        _shrub(yard, front + 0.7, y, size=0.45)
    for y, colour in ((-7.5, "teal"), (-13.5, "cream"), (7.5, "red"), (16.5, "blue")):
        _parked(yard, forecourt[0] + 1.75, y, 1, colour=colour)
    _parked(yard, forecourt[0] + 2.2, -19.5, 3, variant="van", colour="white")

    # The rest of the terrace to the north, and the next block to the south.
    for rect, trim, sign in (((-half_w, half_w, half_d + 1.7, half_d + 9.2), "teal", "yellow"), ((-half_w, half_w, half_d + 9.5, half_d + 17.0), "brick", "white"), ((-half_w, half_w, -22.5 - south, -14.8 - south), "blue", "orange")):
        _unit(yard, rect, trim=trim, sign=sign, shutter="W", windows="E", door=("S", 1.4))
        _flat(ground, rect[0] - 0.2, rect[0], (rect[2] + rect[3]) / 2 - 1.5, (rect[2] + rect[3]) / 2 + 1.5, "yellow", top=PAVED + 0.004)
    for y in (-1.6, 1.6):
        _bollard(yard, -half_w - 0.35, y)

    # The yard to the south: somewhere to eat lunch, and the usual clutter.
    island = (-1.2, 3.4, -10.6 - south, -7.2 - south)
    _flat(ground, *island, "green", top=PAVED + 0.03)
    for low, high, start, end in ((island[0] - 0.1, island[1] + 0.1, island[2] - 0.1, island[2]), (island[0] - 0.1, island[1] + 0.1, island[3], island[3] + 0.1),
                                  (island[0] - 0.1, island[0], island[2], island[3]), (island[1], island[1] + 0.1, island[2], island[3])):
        _flat(ground, low, high, start, end, "linen", top=PAVED + 0.05)
    _tree(yard, 2.2, -9.3 - south, colour="lime", scale=0.85)
    _bench(yard, 0.2, -8.3 - south)
    _tufts(yard, island[0] + 0.2, island[1] - 0.2, island[2] + 0.2, island[3] - 0.2, 14)
    _skip(yard, -1.6, -12.6 - south)
    _pallets(yard, 2.6, -5.0 - south, 4, turn=0.2)
    _pallets(yard, 1.2, -5.3 - south, 2, turn=-0.1)
    _pallets(yard, half_w + 1.3, -1.5, 3)
    for x, y in ((-3.6, -5.2 - south), (-3.0, -5.6 - south), (half_w + 1.2, 1.4)):
        _cone(yard, x, y)
    _wheelie_bin(yard, half_w + 1.7, 2.9, "blue")
    _wheelie_bin(yard, half_w + 2.35, 2.9, "green")
    for y in (-2.0, -0.2):
        _flat(ground, half_w + 0.3, half_w + 2.3, y - 0.04, y + 0.04, "yellow", top=LAWN + 0.004, depth=0.02)

    # Along the back: railings, then a bank of grass and trees.
    _railings(yard, (back, -EXTENT), (back, EXTENT))
    for index in range(13):
        y = -24.0 + index * 4.0 + rng.uniform(-1.0, 1.0)
        kind = rng.choice(("round", "round", "conifer"))
        colour = "teal" if kind == "conifer" else rng.choice(("lime", "lime", "orange", "yellow"))
        _tree(yard, back + rng.uniform(2.0, 6.5), y, kind=kind, colour=colour, scale=rng.uniform(0.8, 1.15))
    for _ in range(9):
        _shrub(yard, back + rng.uniform(0.8, 9.0), rng.uniform(-24.0, 24.0), colour=rng.choice(("teal", "lime")), size=rng.uniform(0.35, 0.6))
    _tufts(yard, back + 0.3, EXTENT - 0.5, -EXTENT + 0.5, EXTENT - 0.5, 220)

    for y in (-21.0, -1.9, 17.0):
        _lamp_post(yard, front - 0.3, y, -1.1)
    for y in (-11.5, 7.5):
        _lamp_post(yard, road[0] - 0.9, y, 1.1)

    # Over the road: bigger sheds with their loading doors facing us.
    far = road[0] - pavement
    for rect, height, trim, sign in (((-EXTENT + 0.5, far - 3.2, -17.0, -1.5), 5.0, "navy", "red"), ((-EXTENT + 0.5, far - 3.2, 2.0, 14.5), 4.2, "teal", "yellow"), ((-EXTENT + 0.5, far - 3.2, 17.0, EXTENT - 0.5), 4.6, "brick", "white")):
        _unit(yard, rect, height=height, trim=trim, sign=sign, shutter="E", windows="ES", door=("E", 1.5))
    _flat(ground, far - 3.2, far, -EXTENT, EXTENT, "slate")
    _pallets(yard, far - 2.0, -4.5, 5)
    _pallets(yard, far - 2.2, 16.0, 3, turn=0.3)
    _skip(yard, far - 1.6, 0.4, colour="blue")
    _parked(yard, far - 1.6, -19.5, 2, variant="van", colour="orange")
    _parked(yard, far - 1.5, 9.0, 0, colour="yellow")


VARIANTS = {"street": _street, "estate": _estate}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
