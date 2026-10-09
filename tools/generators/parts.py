"""Spare part and upgrade kit generator: one variant per row in data/parts.json
and per plain kit in data/upgrades.json (a multicolour unit is built by
printers.py instead).

Each is the part itself, drawn big enough to read on the shelving and in the
shop: no more than 0.22 m across, 0.16 m deep and 0.2 m tall, to fit a shelf slot.

blender --background --factory-startup --python tools/generators/parts.py -- \
    --variant brass_nozzle_0_4mm --out assets/models/parts/brass_nozzle_0_4mm.glb
"""

import math
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="brass_nozzle_0_4mm")


def build(args, rng):
    builder = MeshBuilder()
    VARIANTS[args.variant](builder)
    builder.finish(args.out.stem)


def _nozzle(builder, metal, tip, band=None):
    """A nozzle standing on its thread, tip up."""
    builder.cylinder(0.034, 0.07, (0, 0, 0.035), metal, segments=10)
    for ring in range(3):
        builder.cylinder(0.039, 0.008, (0, 0, 0.014 + ring * 0.02), metal, segments=10)
    builder.cylinder(0.062, 0.05, (0, 0, 0.095), metal, segments=6)
    builder.cylinder(0.05, 0.065, (0, 0, 0.1525), metal, segments=10, radius_top=0.014)
    builder.cylinder(0.014, 0.012, (0, 0, 0.191), tip, segments=8, radius_top=0.008)
    if band is not None:
        builder.cylinder(0.064, 0.012, (0, 0, 0.095), band, segments=6)


def _brass_nozzle(builder):
    _nozzle(builder, "yellow", "tape")


def _hardened_steel_nozzle(builder):
    _nozzle(builder, "metal_dark", "ink", band="red")


def _ptfe_tube(builder):
    """A coil of white tube with a push-fit coupler on each end."""
    for turn in range(3):
        builder.cylinder(0.092, 0.022, (0, 0, 0.013 + turn * 0.024), "white", segments=14)
        builder.cylinder(0.094, 0.004, (0, 0, 0.025 + turn * 0.024), "linen", segments=14)
    builder.cylinder(0.062, 0.006, (0, 0, 0.074), "ink", segments=14)
    builder.capsule(0.012, 0.1, (0.06, -0.085, 0.06), "white", axis="X")
    builder.cylinder(0.018, 0.03, (0.105, -0.085, 0.06), "sky", segments=8, axis="X")
    builder.cylinder(0.022, 0.012, (0.092, -0.085, 0.06), "metal_light", segments=6, axis="X")


def _textured_pei_plate(builder):
    """A build plate propped up to show its gold face, with the two tabs it is lifted by."""
    lean = math.radians(-28)
    up = (0.0, -math.sin(lean), math.cos(lean))
    out = (0.0, -math.cos(lean), -math.sin(lean))
    centre = (0.0, up[1] * 0.1 - 0.05, up[2] * 0.1 + 0.006)
    builder.box((0.2, 0.012, 0.2), centre, "ink", rotation=(lean, 0, 0))
    builder.box((0.186, 0.004, 0.186), tuple(c + n * 0.007 for c, n in zip(centre, out)), "tape", rotation=(lean, 0, 0))
    for x in (-0.06, 0.06):
        builder.box((0.036, 0.012, 0.03), (x, centre[1] + up[1] * 0.108, centre[2] + up[2] * 0.108), "ink", rotation=(lean, 0, 0))
    builder.box((0.12, 0.05, 0.1), (0, 0.05, 0.05), "charcoal", bevel=0.004)


def _gt2_timing_belt(builder):
    """A loop of toothed belt round its two pulleys."""
    half, radius = 0.06, 0.045
    points = []
    for end, start in ((1, -90), (-1, 90)):
        for step in range(7):
            angle = math.radians(start + step * 30)
            points.append((end * half + math.cos(angle) * radius, math.sin(angle) * radius))
    builder.outline(points, 0.035, 0.008, "ink", centre=(0, 0, 0.01))
    for end in (-1, 1):
        builder.cylinder(0.034, 0.04, (end * half, 0, 0.03), "metal_light", segments=10)
        builder.cylinder(0.04, 0.008, (end * half, 0, 0.005), "metal_dark", segments=10)
        builder.cylinder(0.04, 0.008, (end * half, 0, 0.055), "metal_dark", segments=10)
        builder.cylinder(0.01, 0.07, (end * half, 0, 0.035), "ink", segments=6)


def _hotend_assembly(builder):
    """Heat sink, heater block and nozzle in one piece, with its wires."""
    builder.cylinder(0.006, 0.03, (0, 0, 0.015), "yellow", segments=6, radius_top=0.02)
    builder.box((0.085, 0.07, 0.05), (0.012, 0, 0.055), "red", bevel=0.005)
    builder.cylinder(0.012, 0.03, (0, 0, 0.095), "metal_dark", segments=8)
    for fin in range(5):
        builder.cylinder(0.042, 0.01, (0, 0, 0.112 + fin * 0.018), "metal_light", segments=10)
    builder.cylinder(0.02, 0.09, (0, 0, 0.148), "metal_dark", segments=8)
    builder.cylinder(0.014, 0.014, (0, 0, 0.2), "sky", segments=8)
    for y, colour in ((-0.018, "ink"), (0.018, "white")):
        builder.capsule(0.007, 0.09, (0.095, y, 0.055), colour, axis="X")


def _fan_frame(builder, size, depth, centre, hub):
    """A square fan standing up, facing the front."""
    x, y, z = centre
    builder.box((size, depth, size), centre, "ink", bevel=0.008)
    builder.cylinder(size * 0.43, 0.006, (x, y - depth / 2 - 0.001, z), "charcoal", segments=12, axis="Y")
    for blade in range(5):
        angle = blade * math.tau / 5
        builder.box((size * 0.36, 0.006, size * 0.13), (x + math.cos(angle) * size * 0.2, y - depth / 2 - 0.004,
                    z + math.sin(angle) * size * 0.2), "metal_dark", rotation=(0, -angle + 0.5, 0))
    builder.cylinder(size * 0.15, 0.012, (x, y - depth / 2 - 0.006, z), hub, segments=10, axis="Y")


def _hotend_cooling_fan(builder):
    _fan_frame(builder, 0.15, 0.045, (0, 0, 0.075), "cream")
    builder.capsule(0.006, 0.07, (0.1, 0.01, 0.012), "red", axis="X")


def _part_cooling_fan(builder):
    """A blower: a round drum that draws air in at its face and throws it out of a duct."""
    builder.cylinder(0.075, 0.05, (-0.01, 0, 0.085), "navy", segments=14, axis="Y")
    builder.box((0.1, 0.05, 0.065), (0.045, 0, 0.0325), "navy", bevel=0.004)
    builder.box((0.012, 0.04, 0.05), (0.096, 0, 0.0325), "ink")
    builder.cylinder(0.045, 0.006, (-0.01, -0.027, 0.085), "ink", segments=12, axis="Y")
    builder.cylinder(0.02, 0.012, (-0.01, -0.03, 0.085), "sky", segments=10, axis="Y")
    for spoke in range(6):
        angle = spoke * math.tau / 6
        builder.box((0.022, 0.006, 0.008), (-0.01 + math.cos(angle) * 0.032, -0.031, 0.085 + math.sin(angle) * 0.032),
                    "metal_light", rotation=(0, -angle, 0))


def _feeder_rollers(builder):
    """Two shafts of rubber rollers in their bracket."""
    builder.box((0.2, 0.13, 0.016), (0, 0, 0.008), "charcoal", bevel=0.004)
    for side in (-1, 1):
        builder.box((0.016, 0.13, 0.085), (side * 0.092, 0, 0.0505), "charcoal", bevel=0.004)
    for y in (-0.034, 0.034):
        builder.cylinder(0.008, 0.2, (0, y, 0.062), "metal_light", segments=6, axis="X")
        for x in (-0.045, 0.0, 0.045):
            builder.cylinder(0.03, 0.03, (x, y, 0.062), "terracotta", segments=10, axis="X")


def _wiper_and_purge_kit(builder):
    """A silicone wiper blade on its mount, beside the chute the purged plastic drops down."""
    builder.box((0.1, 0.06, 0.035), (-0.055, 0, 0.0175), "charcoal", bevel=0.004)
    builder.box((0.085, 0.012, 0.075), (-0.055, 0, 0.07), "sky")
    builder.box((0.085, 0.02, 0.012), (-0.055, 0, 0.04), "metal_light")
    builder.tray((0.09, 0.11, 0.07), 0.008, "white", centre=(0.06, 0, 0), taper=0.012)
    for x, y, colour in ((0.05, 0.015, "orange"), (0.07, -0.01, "green"), (0.06, 0.0, "purple")):
        builder.ball(0.016, (x, y, 0.022), colour, subdivisions=1)


def _auto_bed_levelling_kit(builder):
    """A bed probe on its bracket, pin up, with its lead."""
    builder.box((0.14, 0.09, 0.014), (0, 0, 0.007), "metal_dark", bevel=0.003)
    builder.box((0.014, 0.09, 0.07), (-0.063, 0, 0.049), "metal_dark", bevel=0.003)
    builder.cylinder(0.034, 0.1, (0.01, 0, 0.064), "white", segments=10)
    builder.cylinder(0.036, 0.022, (0.01, 0, 0.03), "red", segments=10)
    builder.cylinder(0.012, 0.03, (0.01, 0, 0.129), "metal_dark", segments=8)
    builder.cylinder(0.006, 0.045, (0.01, 0, 0.165), "metal_light", segments=6)
    builder.capsule(0.006, 0.08, (0.085, 0.02, 0.02), "ink", axis="X")


def _frame_stiffening_braces(builder):
    """A pair of rods with a bracket on each end, laid across each other."""
    for turn, z in ((0.5, 0.012), (-0.5, 0.034)):
        builder.box((0.2, 0.018, 0.018), (0, 0, z), "metal_light", rotation=(0, 0, turn))
        for end in (-1, 1):
            x, y = end * 0.1 * math.cos(turn), end * 0.1 * math.sin(turn)
            builder.box((0.04, 0.036, 0.024), (x, y, z), "orange", rotation=(0, 0, turn), bevel=0.004)
            builder.cylinder(0.008, 0.03, (x, y, z), "ink", segments=6)


def _direct_drive_conversion(builder):
    """An extruder: its motor, the geared body bolted to the front and the lever that grips the filament."""
    builder.box((0.1, 0.09, 0.1), (0, 0.03, 0.05), "ink", bevel=0.008)
    builder.box((0.104, 0.012, 0.104), (0, 0.03, 0.05), "metal_light")
    builder.box((0.1, 0.04, 0.1), (0, -0.035, 0.05), "red", bevel=0.006)
    builder.cylinder(0.03, 0.014, (-0.012, -0.06, 0.05), "yellow", segments=10, axis="Y")
    builder.cylinder(0.012, 0.02, (-0.012, -0.064, 0.05), "metal_dark", segments=6, axis="Y")
    builder.box((0.03, 0.03, 0.09), (0.062, -0.035, 0.07), "red", rotation=(0, 0.35, 0), bevel=0.005)
    builder.cylinder(0.007, 0.07, (0.02, -0.035, 0.13), "white", segments=6)
    builder.cylinder(0.014, 0.014, (0.02, -0.035, 0.105), "sky", segments=8)


def _snap_on_enclosure(builder):
    """A fabric tent on a pole frame, with a window in the front flap and one in the side."""
    width, depth, height = 0.21, 0.16, 0.19
    builder.box((width, depth, height), (0, 0, height / 2), "charcoal", bevel=0.01)
    builder.box((width * 0.62, 0.004, height * 0.55), (-0.01, -depth / 2 - 0.001, height * 0.52), "sky")
    builder.box((0.004, depth * 0.6, height * 0.45), (width / 2 + 0.001, 0, height * 0.55), "sky")
    builder.box((0.008, 0.006, height * 0.8), (width * 0.38, -depth / 2 - 0.002, height * 0.48), "orange")
    builder.box((0.02, 0.008, 0.02), (width * 0.38, -depth / 2 - 0.004, height * 0.2), "orange")
    builder.box((width * 0.5, 0.05, 0.012), (0, 0, height + 0.012), "ink", bevel=0.004)


def _anti_vibration_feet(builder):
    """Four squashy feet."""
    for x in (-0.055, 0.055):
        for y in (-0.04, 0.04):
            builder.cylinder(0.042, 0.03, (x, y, 0.015), "teal", segments=10, radius_top=0.036)
            builder.cylinder(0.036, 0.02, (x, y, 0.04), "teal", segments=10, radius_top=0.03)
            builder.cylinder(0.02, 0.008, (x, y, 0.053), "metal_light", segments=8)
            builder.cylinder(0.008, 0.02, (x, y, 0.065), "metal_dark", segments=6)


def _cable_chain_kit(builder):
    """A length of drag chain, curled over on itself the way it runs on a printer."""
    links = 9
    for index in range(links):
        angle = math.pi * index / (links - 1)
        x, z = -math.cos(angle) * 0.075, 0.03 + math.sin(angle) * 0.075
        builder.box((0.042, 0.06, 0.026), (x, 0, z), "ink" if index % 2 else "charcoal", rotation=(0, angle - math.pi / 2, 0),
                    bevel=0.004)
    for side in (-1, 1):
        builder.box((0.05, 0.07, 0.02), (side * 0.075, 0, 0.01), "orange", bevel=0.004)


VARIANTS = {
    "brass_nozzle_0_4mm": _brass_nozzle,
    "hardened_steel_nozzle_0_4mm": _hardened_steel_nozzle,
    "ptfe_tube": _ptfe_tube,
    "textured_pei_plate": _textured_pei_plate,
    "gt2_timing_belt": _gt2_timing_belt,
    "hotend_assembly": _hotend_assembly,
    "hotend_cooling_fan": _hotend_cooling_fan,
    "part_cooling_fan": _part_cooling_fan,
    "feeder_rollers_multicolour": _feeder_rollers,
    "wiper_and_purge_kit": _wiper_and_purge_kit,
    "auto_bed_levelling_kit": _auto_bed_levelling_kit,
    "frame_stiffening_braces": _frame_stiffening_braces,
    "direct_drive_conversion": _direct_drive_conversion,
    "snap_on_enclosure": _snap_on_enclosure,
    "anti_vibration_feet": _anti_vibration_feet,
    "cable_chain_kit": _cable_chain_kit,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
