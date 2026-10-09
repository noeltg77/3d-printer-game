"""Segmented character generator. No skinning: every part is a rigid object on a pivot.

Chunky and rounded to match the props: a head about a third of the height,
short capsule limbs, mitten hands, a torso that widens to the shoulders, and
hair built from a few clumps. Every part is bevelled.

Hierarchy (origin at the feet, facing -Y, left is +X):
  body (pivot: hips)
    head (neck)
    arm_l / arm_r (shoulder) > forearm_l / forearm_r (elbow) > hand_l / hand_r marker
    leg_l / leg_r (hip) > shin_l / shin_r (knee)
    carry_socket marker, in front of the chest
The game animates it by rotating those pivots (scripts/character/character_rig.gd).

blender --background --factory-startup --python tools/generators/character.py -- \
    --top teal --hair wood_dark --hair-style short --apron orange \
    --out assets/models/characters/character_01.glb
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder, marker

# Pivot heights. The rig reads positions from the model, so these can change freely.
KNEE = 0.24
HIP = 0.47
ELBOW = 0.72
SHOULDER = 0.94
NECK = 1.0
HEAD = 1.27
SIDES = 8
HAIR_STYLES = ("short", "bun", "long", "quiff")


def add_arguments(parser):
    parser.add_argument("--skin", default="skin_light")
    parser.add_argument("--hair", default="wood_dark")
    parser.add_argument("--hair-style", choices=HAIR_STYLES, default="short")
    parser.add_argument("--top", default="teal")
    parser.add_argument("--bottom", default="navy")
    parser.add_argument("--shoes", default="charcoal")
    parser.add_argument("--apron", default=None, help="apron colour, none if not given")


def build(args, rng):
    body = MeshBuilder()
    # Torso widens from a 0.27 waist to 0.41 shoulders.
    body.box((0.27, 0.21, 0.46), (0, 0, 0.77), args.top, taper=(1.52, 1.0), bevel=0.045, bevel_segments=3)
    body.box((0.29, 0.215, 0.16), (0, 0, 0.5), args.bottom, bevel=0.04, bevel_segments=3)
    body.cylinder(0.065, 0.08, (0, 0, NECK), args.skin, segments=SIDES)
    if args.apron:
        body.box((0.23, 0.018, 0.42), (0, -0.112, 0.71), args.apron, bevel=0.006, bevel_segments=2)
        body.box((0.13, 0.018, 0.09), (0, -0.124, 0.63), "cream", bevel=0.006, bevel_segments=2)
        for side in (-1, 1):
            body.box((0.035, 0.018, 0.1), (side * 0.09, -0.112, 0.95), args.apron)
    body_obj = body.finish("body", pivot=(0, 0, HIP))
    marker("carry_socket", (0, -0.34, 0.7), body_obj)

    _head(args, rng, body_obj)
    for name, side in (("l", 1), ("r", -1)):
        _arm(args, body_obj, name, side)
        _leg(args, body_obj, name, side * 0.085)


def _head(args, rng, body_obj):
    head = MeshBuilder()
    head.box((0.46, 0.42, 0.48), (0, 0, HEAD), args.skin, bevel=0.1, bevel_segments=3)
    front = -0.212
    for side in (-1, 1):
        head.cylinder(0.03, 0.014, (side * 0.095, front, 1.25), "ink", segments=SIDES, axis="Y")
        head.box((0.08, 0.014, 0.022), (side * 0.095, front, 1.34), args.hair)

    def clump(size, centre, rotation=(0.0, 0.0, 0.0)):
        """One chunk of hair, nudged a little by the seed so no two heads match."""
        size = tuple(dimension * rng.uniform(0.95, 1.05) for dimension in size)
        rotation = tuple(angle + rng.uniform(-0.06, 0.06) for angle in rotation)
        head.box(size, centre, args.hair, rotation=rotation, bevel=min(size) * 0.3, bevel_segments=2)

    style = args.hair_style
    clump((0.5, 0.46, 0.16), (0, 0.01, 1.5))
    if style == "long":
        clump((0.5, 0.14, 0.62), (0, 0.2, 1.22))
        for side in (-1, 1):
            clump((0.1, 0.24, 0.5), (side * 0.245, 0.08, 1.27))
        clump((0.34, 0.12, 0.11), (0.05, -0.19, 1.5), (0, 0, -0.15))
    else:
        clump((0.48, 0.14, 0.34), (0, 0.2, 1.37))
    if style in ("short", "bun"):
        for side in (-1, 1):
            clump((0.1, 0.26, 0.2), (side * 0.24, 0.08, 1.42))
    if style == "short":
        clump((0.36, 0.14, 0.14), (-0.06, -0.19, 1.49), (0, 0.12, 0.18))
    elif style == "bun":
        clump((0.21, 0.21, 0.19), (0, 0.1, 1.66))
    elif style == "quiff":
        clump((0.32, 0.2, 0.16), (0, -0.14, 1.58), (0.4, 0, 0))
        clump((0.22, 0.18, 0.12), (0.04, 0.0, 1.62), (0.2, 0, 0))
    head.finish("head", pivot=(0, 0, NECK), parent=body_obj)


def _arm(args, body_obj, name, side):
    x = side * 0.255
    arm = MeshBuilder()
    arm.capsule(0.062, 0.26, (x, 0, 0.84), args.top, segments=SIDES)
    arm_obj = arm.finish(f"arm_{name}", pivot=(x, 0, SHOULDER), parent=body_obj)
    forearm = MeshBuilder()
    forearm.capsule(0.052, 0.22, (x, 0, 0.62), args.skin, segments=SIDES)
    # Mitten hand: a rounded block with a stub of a thumb on the inside front.
    forearm.box((0.1, 0.11, 0.13), (x, 0, 0.47), args.skin, bevel=0.04, bevel_segments=3)
    forearm.box((0.04, 0.05, 0.055), (x - side * 0.04, -0.06, 0.49), args.skin, bevel=0.014, bevel_segments=2)
    forearm_obj = forearm.finish(f"forearm_{name}", pivot=(x, 0, ELBOW), parent=arm_obj)
    marker(f"hand_{name}", (x, 0, 0.46), forearm_obj)


def _leg(args, body_obj, name, x):
    leg = MeshBuilder()
    leg.capsule(0.078, 0.27, (x, 0, 0.355), args.bottom, segments=SIDES)
    leg_obj = leg.finish(f"leg_{name}", pivot=(x, 0, HIP), parent=body_obj)
    shin = MeshBuilder()
    shin.capsule(0.066, 0.2, (x, 0, 0.16), args.bottom, segments=SIDES)
    shin.box((0.14, 0.24, 0.09), (x, -0.035, 0.045), args.shoes, bevel=0.04, bevel_segments=3)
    shin.finish(f"shin_{name}", pivot=(x, 0, KNEE), parent=leg_obj)


if __name__ == "__main__":
    common.run(sys.modules[__name__])
