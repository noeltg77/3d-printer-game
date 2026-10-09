"""Vehicle generator: the cars and vans that drive past outside.

Chunky and toy-like, to sit beside the character. The front faces -Y. Headlights
are a separate child object, `glow_headlights`, so the game can light them at night.

blender --background --factory-startup --python tools/generators/vehicles.py -- \
    --variant car --colour red --out assets/models/vehicles/car_red.glb
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common
from common import MeshBuilder

GLASS = "navy"


def add_arguments(parser):
    parser.add_argument("--variant", choices=tuple(VARIANTS), default="car")
    parser.add_argument("--colour", default="red", help="body colour")
    parser.add_argument("--accent", default="orange", help="stripe along a van's side")


def build(args, rng):
    body, glow = MeshBuilder(), MeshBuilder()
    add(body, glow, args.variant, args.colour, accent=args.accent)
    obj = body.finish(args.out.stem)
    glow.finish("glow_headlights", parent=obj)


def add(body, glow, variant, colour, origin=(0.0, 0.0), turns=0, accent="orange"):
    """Draws a vehicle into `body`, and its headlights into `glow`.

    `origin` is where the middle of it stands and `turns` how many quarter turns
    anticlockwise it has made from facing -Y, so other generators can park one
    in their own scenery. Pass the same builder twice for lights that never come on.
    """
    VARIANTS[variant](_Placer(body, origin, turns), _Placer(glow, origin, turns), colour, accent)


class _Placer:
    """Draws boxes and wheels turned and moved to where the vehicle stands."""

    def __init__(self, builder, origin, turns):
        self.builder, self.origin, self.turns = builder, origin, turns % 4

    def _point(self, point):
        x, y, z = point
        for _ in range(self.turns):
            x, y = -y, x
        return (self.origin[0] + x, self.origin[1] + y, z)

    def box(self, size, centre, colour, taper=1.0, bevel=0.0):
        taper = taper if isinstance(taper, tuple) else (taper, taper)
        if self.turns % 2:
            size, taper = (size[1], size[0], size[2]), (taper[1], taper[0])
        return self.builder.box(size, self._point(centre), colour, taper=taper, bevel=bevel, bevel_segments=2)

    def wheel(self, radius, width, centre):
        axis = "Y" if self.turns % 2 else "X"
        self.builder.cylinder(radius, width, self._point(centre), "charcoal", segments=10, axis=axis)
        self.builder.cylinder(radius * 0.5, width + 0.02, self._point(centre), "metal_light", segments=8, axis=axis)


def _wheels(body, half_track, axles, radius):
    for x in (-half_track, half_track):
        for y in axles:
            body.wheel(radius, 0.22, (x, y, radius))


def _lights(body, glow, half_width, front, back, z):
    for x in (-half_width, half_width):
        glow.box((0.26, 0.06, 0.14), (x, front - 0.01, z), "white")
        body.box((0.24, 0.06, 0.12), (x, back + 0.01, z), "red")
    body.box((half_width * 2 + 0.5, 0.1, 0.14), (0, front + 0.02, z - 0.2), "charcoal", bevel=0.02)
    body.box((half_width * 2 + 0.5, 0.1, 0.14), (0, back - 0.02, z - 0.2), "charcoal", bevel=0.02)


def _car(body, glow, colour, accent):
    """Small hatchback, 3.2 m long."""
    body.box((1.45, 3.2, 0.58), (0, 0, 0.54), colour, bevel=0.1)
    body.box((1.3, 1.75, 0.46), (0, 0.2, 1.04), GLASS, taper=(0.86, 0.72))
    body.box((1.14, 1.3, 0.07), (0, 0.2, 1.3), colour, bevel=0.02)
    _wheels(body, 0.66, (-1.0, 1.0), 0.3)
    _lights(body, glow, 0.48, -1.6, 1.6, 0.6)


def _van(body, glow, colour, accent):
    """Delivery van, 4.2 m long: a cab at the front and a tall box behind."""
    body.box((1.6, 1.5, 0.75), (0, -1.35, 0.7), colour, bevel=0.1)
    body.box((1.46, 0.95, 0.55), (0, -1.1, 1.32), GLASS, taper=(0.9, 0.7))
    body.box((1.3, 0.72, 0.07), (0, -1.08, 1.62), colour, bevel=0.02)
    body.box((1.66, 2.75, 1.5), (0, 0.72, 1.1), colour, bevel=0.08)
    for x in (-0.835, 0.835):
        body.box((0.02, 2.4, 0.3), (x, 0.72, 1.2), accent)
    body.box((1.2, 0.02, 1.1), (0, 2.1, 1.05), "linen")
    _wheels(body, 0.72, (-1.35, 1.3), 0.33)
    _lights(body, glow, 0.55, -2.1, 2.1, 0.62)


VARIANTS = {"car": _car, "van": _van}

if __name__ == "__main__":
    common.run(sys.modules[__name__])
