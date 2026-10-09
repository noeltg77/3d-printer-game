"""Parameterised shapes shared by the printed item generators (prints*.py).

Many products are variations on one form, so the form lives here and each
product is a call with its own numbers. Everything is built in "white": the
tint material ignores the palette and takes the colour of the filament in game.
"""

import math

from mathutils import Vector

COLOUR = "white"


def grid(columns, rows, pitch_x, pitch_y):
    """Centred (x, y) positions for a set of items laid out as they come off the bed."""
    return [
        ((column - (columns - 1) / 2) * pitch_x, (row - (rows - 1) / 2) * pitch_y)
        for row in range(rows) for column in range(columns)
    ]


def slot_rack(builder, width, depth, heights, lean=8.0, base=0.014, panel=0.012):
    """Base plate with upright panels across it, front to back, leaving slots between.

    One panel per entry in `heights`, the first at the front. `lean` tips them
    back, in degrees. Covers letter racks, napkin holders, lid racks and card stands.
    """
    builder.box((width, depth, base), (0, 0, base / 2), COLOUR, bevel=0.004)
    tilt = math.radians(lean)
    # The top of the tallest panel overhangs its foot, so the feet stop short of the back edge.
    front = -depth / 2 + panel
    back = depth / 2 - panel - max(heights) * math.sin(tilt)
    for index, height in enumerate(heights):
        foot = front + (back - front) * index / max(len(heights) - 1, 1)
        centre = (0, foot + math.sin(tilt) * height / 2, base - 0.002 + math.cos(tilt) * height / 2)
        builder.box((width - 0.016, panel, height), centre, COLOUR, rotation=(-tilt, 0, 0), bevel=0.004)


def easel(builder, width, depth, rest, lean=20.0, lip=0.03, base=0.016, panel=0.016):
    """Stand that props something flat: base, front lip, leaning back rest and a block behind it.

    `rest` is the length of the back rest and `lean` how far it tips back, in
    degrees. Covers tablet, planner, recipe card and record stands.
    """
    tilt = math.radians(lean)
    builder.box((width, depth, base), (0, 0, base / 2), COLOUR, bevel=0.004)
    builder.box((width, 0.018, lip), (0, -depth / 2 + 0.009, base - 0.002 + lip / 2), COLOUR, bevel=0.004)
    foot = -depth / 2 + 0.048
    centre = (0, foot + math.sin(tilt) * rest / 2, base - 0.002 + math.cos(tilt) * rest / 2)
    builder.box((width, panel, rest), centre, COLOUR, rotation=(-tilt, 0, 0), bevel=0.004)
    # The block meets the back of the rest halfway up and runs to the back of the base.
    block_front = centre[1] + 0.006
    block_back = max(depth / 2 - 0.006, block_front + 0.03)
    block_height = math.cos(tilt) * rest / 2
    builder.box(
        (0.035, block_back - block_front, block_height),
        (0, (block_front + block_back) / 2, base - 0.002 + block_height / 2), COLOUR)


def divided_tray(builder, size, wall, across=0, along=0, centre=(0.0, 0.0, 0.0), divider_height=None, **tray):
    """Tray split into compartments: drawer organisers, caddies, grids.

    `across` dividers run front to back and `along` dividers run side to side,
    evenly spaced. They stop just short of the rim unless `divider_height` says
    otherwise. Other arguments go to `MeshBuilder.tray` (not `taper`: the
    dividers are square ended).
    """
    width, depth, height = size
    builder.tray(size, wall, COLOUR, centre=centre, **tray)
    tall = height - 0.004 if divider_height is None else divider_height
    thick = wall * 0.8
    z = centre[2] + tall / 2
    # Each divider ends halfway into the walls, so there is no gap and nothing pokes out.
    for index in range(across):
        x = centre[0] + (index + 1) / (across + 1) * (width - wall) - (width - wall) / 2
        builder.box((thick, depth - wall, tall), (x, centre[1], z), COLOUR)
    for index in range(along):
        y = centre[1] + (index + 1) / (along + 1) * (depth - wall) - (depth - wall) / 2
        builder.box((width - wall, thick, tall), (centre[0], y, z), COLOUR)


def stepped_rack(builder, width, steps, tread, first, rise, lip=0.012):
    """Staircase of shelves rising to the back, each with a lip along its front edge.

    `tread` is the depth of each step, `first` the height of the front one and
    `rise` the gain per step. Covers spice racks, polish racks and display risers.
    """
    for index in range(steps):
        height = first + index * rise
        y = (index - (steps - 1) / 2) * tread
        builder.box((width, tread + 0.004, height), (0, y, height / 2), COLOUR, bevel=0.004)
        if lip > 0.0:
            builder.box((width, 0.008, lip), (0, y - tread / 2 + 0.002, height + lip / 2 - 0.002), COLOUR)


def strut(builder, start, end, thickness):
    """Square bar running between two points, for arms, struts and hangers at any angle."""
    start, end = Vector(start), Vector(end)
    span = end - start
    builder.box(
        (thickness, thickness, span.length), tuple((start + end) / 2), COLOUR,
        rotation=tuple(span.to_track_quat("Z", "Y").to_euler()))


def limb(builder, start, end, radius, radius_end=None, segments=6):
    """Round bar or cone running between two points: horns, tails, arms, curved hooks in sections."""
    start, end = Vector(start), Vector(end)
    span = end - start
    builder.cylinder(
        radius, span.length, tuple((start + end) / 2), COLOUR, segments=segments,
        rotation=tuple(span.to_track_quat("Z", "Y").to_euler()), radius_top=radius_end)


def gear_points(teeth, radius, depth=0.22, turn=0.0):
    """Outline of a gear with pointed teeth, anticlockwise: `radius` at the tips,
    `depth` the share of it the teeth cut in."""
    return [
        ((radius if index % 2 == 0 else radius * (1.0 - depth)) * math.cos(turn + math.pi * index / teeth),
         (radius if index % 2 == 0 else radius * (1.0 - depth)) * math.sin(turn + math.pi * index / teeth))
        for index in range(teeth * 2)
    ]


def gear(builder, teeth, radius, thickness, centre=(0.0, 0.0, 0.0), turn=0.0, boss=0.0):
    """Gear lying flat, standing on `centre`. `boss` is the radius of a raised hub, if any."""
    builder.plate(gear_points(teeth, radius, turn=turn), thickness, COLOUR, centre=centre)
    if boss > 0.0:
        builder.cylinder(boss, thickness * 0.5, (centre[0], centre[1], centre[2] + thickness * 1.25), COLOUR, segments=6)


def hoop(builder, radius, thick, depth, centre, pieces=8, start=0.0, sweep=math.tau):
    """Upright ring, or part of one, built from blocks: bearing mounts, arches, shrouds.

    Stands in the x-z plane round `centre`, `depth` thick front to back. `radius`
    is to the middle of the band. `start` and `sweep` (radians, anticlockwise from
    +X) pick an arc; the default is the whole ring.
    """
    step = sweep / pieces
    length = 2.0 * (radius + thick / 2) * math.tan(step / 2)
    for index in range(pieces):
        angle = start + (index + 0.5) * step
        builder.box(
            (length, depth, thick), (centre[0] + radius * math.cos(angle), centre[1], centre[2] + radius * math.sin(angle)),
            COLOUR, rotation=(0, -(angle + math.pi / 2), 0))
