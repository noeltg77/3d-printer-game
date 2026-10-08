"""Printed item generator: the things that come off the print bed.

These use the tint material, so the game colours each one to match its filament.
Sizes are exaggerated a little so items read at the game's camera distance.

blender --background --factory-startup --python tools/generators/prints.py -- \
    --variant desk_organiser --out assets/models/prints/desk_organiser.glb
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="desk_organiser")


def build(args, rng):
    builder = MeshBuilder(material=common.TINT_MATERIAL_NAME)
    VARIANTS[args.variant](builder)
    builder.finish(args.out.stem)


def _desk_organiser(builder):
    """Tray with a tall pen pot, a mid pot and a low card slot."""
    builder.box((0.2, 0.12, 0.015), (0, 0, 0.0075), "white", bevel=0.004)
    builder.box((0.07, 0.09, 0.11), (-0.055, 0.005, 0.07), "white", bevel=0.006)
    builder.box((0.055, 0.09, 0.07), (0.015, 0.005, 0.05), "white", bevel=0.006)
    builder.box((0.045, 0.09, 0.04), (0.07, 0.005, 0.035), "white", bevel=0.006)


VARIANTS = {"desk_organiser": _desk_organiser}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
