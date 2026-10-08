"""Segmented character generator. No skinning: every part is a rigid object on a pivot.

Hierarchy (origin at the feet, facing -Y, left is +X):
  body (pivot: hips)
    head (neck)
    arm_l / arm_r (shoulder) > forearm_l / forearm_r (elbow) > hand_l / hand_r marker
    leg_l / leg_r (hip) > shin_l / shin_r (knee)
    carry_socket marker, in front of the chest
The game animates it by rotating those pivots (scripts/character/character_rig.gd).

blender --background --factory-startup --python tools/generators/character.py -- \
    --top teal --hair wood_dark --out assets/models/characters/character_01.glb
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder, marker

HIP = 0.6
KNEE = 0.32
NECK = 1.08
SHOULDER = 1.01
ELBOW = 0.8


def add_arguments(parser):
    parser.add_argument("--skin", default="skin_light")
    parser.add_argument("--hair", default="wood_dark")
    parser.add_argument("--hair-style", choices=("short", "bun", "long"), default="short")
    parser.add_argument("--top", default="teal")
    parser.add_argument("--bottom", default="navy")
    parser.add_argument("--shoes", default="charcoal")
    parser.add_argument("--apron", default=None, help="apron colour, none if not given")


def build(args, rng):
    body = MeshBuilder()
    body.box((0.36, 0.22, 0.36), (0, 0, 0.88), args.top, bevel=0.025)
    body.box((0.35, 0.215, 0.14), (0, 0, 0.66), args.bottom, bevel=0.02)
    body.box((0.12, 0.12, 0.06), (0, 0, 1.07), args.skin)
    if args.apron:
        body.box((0.27, 0.012, 0.34), (0, -0.114, 0.82), args.apron)
        body.box((0.13, 0.012, 0.09), (0, -0.122, 0.76), "cream")
    body_obj = body.finish("body", pivot=(0, 0, HIP))
    marker("carry_socket", (0, -0.3, 0.8), body_obj)

    _head(args, body_obj)
    for name, side in (("l", 1), ("r", -1)):
        _arm(args, body_obj, name, side * 0.235)
        _leg(args, body_obj, name, side * 0.09)


def _head(args, body_obj):
    head = MeshBuilder()
    head.box((0.42, 0.36, 0.36), (0, 0, 1.28), args.skin, bevel=0.04)
    for side in (-1, 1):
        head.box((0.042, 0.012, 0.065), (side * 0.09, -0.181, 1.27), "ink")
        head.box((0.055, 0.008, 0.026), (side * 0.14, -0.18, 1.205), "pink")
    head.box((0.45, 0.39, 0.12), (0, 0.005, 1.44), args.hair, bevel=0.025)
    head.box((0.45, 0.04, 0.06), (0, -0.18, 1.425), args.hair)
    back_length = 0.48 if args.hair_style == "long" else 0.28
    head.box((0.45, 0.11, back_length), (0, 0.15, 1.48 - back_length / 2), args.hair, bevel=0.025)
    if args.hair_style == "bun":
        head.box((0.17, 0.17, 0.15), (0, 0.1, 1.55), args.hair, bevel=0.035)
    if args.hair_style == "long":
        for side in (-1, 1):
            head.box((0.045, 0.24, 0.34), (side * 0.215, 0.07, 1.29), args.hair, bevel=0.012)
    head.finish("head", pivot=(0, 0, NECK), parent=body_obj)


def _arm(args, body_obj, name, x):
    arm = MeshBuilder()
    arm.box((0.1, 0.12, 0.25), (x, 0, 0.925), args.top, bevel=0.02)
    arm_obj = arm.finish(f"arm_{name}", pivot=(x, 0, SHOULDER), parent=body_obj)
    forearm = MeshBuilder()
    forearm.box((0.09, 0.105, 0.2), (x, 0, 0.71), args.skin, bevel=0.015)
    forearm.box((0.105, 0.12, 0.09), (x, 0, 0.585), args.skin, bevel=0.02)
    forearm_obj = forearm.finish(f"forearm_{name}", pivot=(x, 0, ELBOW), parent=arm_obj)
    marker(f"hand_{name}", (x, 0, 0.56), forearm_obj)


def _leg(args, body_obj, name, x):
    leg = MeshBuilder()
    leg.box((0.15, 0.16, 0.3), (x, 0, 0.46), args.bottom, bevel=0.02)
    leg_obj = leg.finish(f"leg_{name}", pivot=(x, 0, HIP), parent=body_obj)
    shin = MeshBuilder()
    shin.box((0.14, 0.15, 0.27), (x, 0, 0.195), args.bottom)
    shin.box((0.155, 0.23, 0.08), (x, -0.03, 0.04), args.shoes, bevel=0.02)
    shin.finish(f"shin_{name}", pivot=(x, 0, KNEE), parent=leg_obj)


if __name__ == "__main__":
    common.run(sys.modules[__name__])
