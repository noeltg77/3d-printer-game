"""Printed item generator for designs made in more than one colour.

Same rules as prints.py: tint material, origin at the centre of the base, a
little larger than life so items read at the game's camera distance.

A multicolour item is several meshes. The main one is named after the product
and holds everything printed in the first colour. Each further colour is a
child mesh named `colour_2`, `colour_3` and so on. The game tints each mesh
with the colour of the spool that printed it (`PrintedItem`), so nothing here
chooses the actual colours: only which parts share one. Put the bulk of the
item in the main mesh, because the first colour takes most of the filament.

Each variant is given a `Parts`: `parts.main` is the builder for the first
colour and `parts.colour(n)` the builder for the nth.

blender --background --factory-startup --python tools/generators/prints_multicolour.py -- \
    --variant desk_nameplate --out assets/models/prints/desk_nameplate.glb
"""

import math
import sys
from pathlib import Path

import bpy

sys.path.append(str(Path(__file__).resolve().parent))
import common
import print_shapes
from common import MeshBuilder
from print_shapes import COLOUR

# Stand-in colours for the second colour onwards in preview sheets. The first
# keeps the sheet's own tint.
PREVIEW_TINTS = ((0.95, 0.9, 0.8, 1.0), (0.85, 0.3, 0.25, 1.0), (0.95, 0.75, 0.3, 1.0), (0.25, 0.3, 0.5, 1.0), (0.5, 0.7, 0.35, 1.0))


class Parts:
    """One mesh builder for each colour of a design."""

    def __init__(self):
        self.main = MeshBuilder(material=common.TINT_MATERIAL_NAME)
        self._others = {}

    def colour(self, number):
        """The builder for the design's nth colour, counting from 1."""
        if number == 1:
            return self.main
        if number not in self._others:
            self._others[number] = MeshBuilder(material=common.TINT_MATERIAL_NAME)
        return self._others[number]

    def finish(self, name, preview=False):
        """Writes the meshes out, the further colours as children of the main one.

        With `preview` each further colour gets a material of its own so the
        colours can be told apart in a render. Never export those.
        """
        main = self.main.finish(name)
        for number in sorted(self._others):
            part = self._others[number].finish(f"colour_{number}", parent=main)
            if preview:
                material = bpy.data.materials.new(f"preview_colour_{number}")
                material.use_nodes = True
                tint = PREVIEW_TINTS[(number - 2) % len(PREVIEW_TINTS)]
                material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = tint
                part.data.materials[0] = material
        return main


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), required=True)


def build(args, rng):
    build_item(args.variant, args.out.stem)


def build_item(variant, name, preview=False):
    """Builds one item and returns its main object. Used by preview_prints.py too."""
    parts = Parts()
    VARIANTS[variant](parts)
    return parts.finish(name, preview)


def _desk_nameplate(parts):
    """Wedge shaped plaque with a row of raised letters across its sloping face."""
    lean = math.radians(-20)
    parts.main.box((0.21, 0.05, 0.012), (0, 0, 0.006), COLOUR, bevel=0.003)
    parts.main.box((0.21, 0.014, 0.06), (0, 0.008, 0.038), COLOUR, rotation=(lean, 0, 0), bevel=0.003)
    letters = parts.colour(2)
    for index, width in enumerate((0.022, 0.016, 0.024, 0.018, 0.022, 0.016)):
        x = (index - 2.5) * 0.031
        letters.box((width, 0.006, 0.03), (x, -0.0015, 0.04), COLOUR, rotation=(lean, 0, 0))


def _coasters_x4(parts):
    """Four round coasters, each with a hexagon inlaid in the second colour."""
    for x, y in print_shapes.grid(2, 2, 0.118, 0.118):
        parts.main.cylinder(0.055, 0.008, (x, y, 0.004), COLOUR, segments=10)
        parts.colour(2).cylinder(0.036, 0.003, (x, y, 0.0095), COLOUR, segments=6)


def _key_holder_wall_rack(parts):
    """Back plate, printed lying down, with a rail and four pegs in the second colour."""
    parts.main.box((0.23, 0.085, 0.012), (0, 0, 0.006), COLOUR, bevel=0.004)
    parts.main.box((0.19, 0.012, 0.01), (0, 0.027, 0.017), COLOUR)
    pegs = parts.colour(2)
    pegs.box((0.2, 0.014, 0.006), (0, -0.012, 0.015), COLOUR)
    for x, _ in print_shapes.grid(4, 1, 0.052, 0):
        pegs.cylinder(0.009, 0.034, (x, -0.012, 0.029), COLOUR, segments=6)
        pegs.cylinder(0.014, 0.008, (x, -0.012, 0.05), COLOUR, segments=6)


def _fridge_magnets_x6(parts):
    """Six small tiles: three with a round badge on top, three with a diamond, in two more colours."""
    for index, (x, y) in enumerate(print_shapes.grid(3, 2, 0.054, 0.054)):
        parts.main.box((0.042, 0.042, 0.008), (x, y, 0.004), COLOUR, taper=0.9)
        if index % 2 == 0:
            parts.colour(2).cylinder(0.013, 0.005, (x, y, 0.0105), COLOUR, segments=8)
        else:
            parts.colour(3).box((0.02, 0.02, 0.005), (x, y, 0.0105), COLOUR, rotation=(0, 0, math.pi / 4))


def _garden_gnome_low_poly(parts):
    """Faceted gnome: a stout body, a tall pointed hat and a beard under a round nose."""
    parts.main.cylinder(0.062, 0.1, (0, 0, 0.05), COLOUR, segments=7, radius_top=0.045)
    parts.main.ball(0.014, (0, -0.045, 0.108), COLOUR, subdivisions=1)
    hat = parts.colour(2)
    hat.cylinder(0.056, 0.012, (0, 0, 0.116), COLOUR, segments=7)
    hat.cylinder(0.05, 0.1, (0, 0, 0.172), COLOUR, segments=7, radius_top=0.004)
    beard = parts.colour(3)
    beard.cylinder(0.032, 0.05, (0, -0.036, 0.074), COLOUR, segments=5, radius_top=0.012, rotation=(math.pi, 0, 0))


def _stacking_rings(parts):
    """Round base and post with three rings on it, each smaller than the last and its own colour."""
    parts.main.cylinder(0.068, 0.014, (0, 0, 0.007), COLOUR, segments=14, radius_top=0.062)
    parts.main.cylinder(0.012, 0.12, (0, 0, 0.074), COLOUR, segments=8)
    parts.main.ball(0.017, (0, 0, 0.138), COLOUR, subdivisions=1)
    for index, radius in enumerate((0.058, 0.048, 0.038)):
        parts.colour(index + 2).cylinder(radius, 0.03, (0, 0, 0.031 + index * 0.032), COLOUR, segments=10, radius_top=radius * 0.86)


VARIANTS = {
    "desk_nameplate": _desk_nameplate,
    "coasters_x4": _coasters_x4,
    "key_holder_wall_rack": _key_holder_wall_rack,
    "fridge_magnets_x6": _fridge_magnets_x6,
    "garden_gnome_low_poly": _garden_gnome_low_poly,
    "stacking_rings": _stacking_rings,
}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
