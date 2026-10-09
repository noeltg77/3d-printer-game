"""Failed print generator: the messes a print leaves on the bed when it goes wrong.

Like printed items these use the tint material, so the mess takes the colour of
the filament that made it. Strands are far thicker than real filament so they
read at the game's camera distance.

blender --background --factory-startup --python tools/generators/print_fails.py -- \
    --seed 1 --variant spaghetti --out assets/models/fails/spaghetti.glb
"""

import math
import sys
from pathlib import Path

from mathutils import Vector

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder

STRAND = 0.007


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="spaghetti")


def build(args, rng):
    builder = MeshBuilder(material=common.TINT_MATERIAL_NAME)
    VARIANTS[args.variant](builder, rng)
    builder.finish(args.out.stem)


def _strand(builder, points, thickness=STRAND):
    """Chain of thin square bars joining `points`, overlapping a little at each bend."""
    for start, end in zip(points, points[1:]):
        span = Vector(end) - Vector(start)
        if span.length < 1e-5:
            continue
        rotation = Vector((0.0, 0.0, 1.0)).rotation_difference(span.normalized()).to_euler()
        centre = (Vector(start) + Vector(end)) / 2
        builder.box((thickness, thickness, span.length + thickness), tuple(centre), "white", rotation=tuple(rotation))


def _spaghetti(builder, rng):
    """A nest of tangled loops, widest near the bed, with a few strands flung out."""
    for _ in range(11):
        radius = rng.uniform(0.035, 0.075)
        height = rng.uniform(0.012, 0.085)
        tilt = rng.uniform(-0.5, 0.5)
        turn = rng.uniform(0.0, math.tau)
        offset = Vector((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), 0.0))
        steps = rng.randint(7, 10)
        sweep = rng.uniform(0.7, 1.0) * math.tau
        points = []
        for step in range(steps + 1):
            angle = turn + sweep * step / steps
            wobble = radius * rng.uniform(0.8, 1.15)
            z = height + math.sin(angle - turn) * tilt * radius + rng.uniform(-0.006, 0.006)
            points.append(offset + Vector((math.cos(angle) * wobble, math.sin(angle) * wobble, max(z, STRAND / 2))))
        _strand(builder, points)
    # Loose ends trailing off across the bed.
    for _ in range(3):
        angle = rng.uniform(0.0, math.tau)
        points = []
        for step in range(5):
            reach = 0.05 + step * 0.018
            bend = angle + math.sin(step * 1.7) * 0.35
            points.append(Vector((math.cos(bend) * reach, math.sin(bend) * reach, STRAND / 2 + max(0.03 - step * 0.01, 0.0))))
        _strand(builder, points)


def _noodles(builder, rng):
    """A first layer that never stuck: wavy lines lying on the bed and one lifted curl."""
    for row in range(5):
        y = (row - 2) * 0.022 + rng.uniform(-0.004, 0.004)
        phase = rng.uniform(0.0, math.tau)
        length = rng.uniform(0.09, 0.14)
        points = []
        for step in range(9):
            along = step / 8
            x = (along - 0.5) * length
            lift = 0.012 * max(0.0, math.sin(along * math.pi * 2.0 + phase)) if row % 2 else 0.0
            points.append(Vector((x, y + math.sin(along * math.tau * 1.5 + phase) * 0.008, STRAND / 2 + lift)))
        _strand(builder, points)
    curl = [Vector((0.05 + math.cos(a) * 0.016, -0.03 + math.sin(a) * 0.016, STRAND / 2 + a * 0.005))
            for a in [step * 0.8 for step in range(8)]]
    _strand(builder, curl)


VARIANTS = {
    "spaghetti": _spaghetti,
    "noodles": _noodles,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
