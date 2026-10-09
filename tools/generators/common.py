"""Shared helpers for the asset generators. Runs inside Blender's Python (bpy).

Conventions every generator follows:
- 1 unit = 1 metre, Z up in Blender (the glTF exporter converts to Godot's Y up).
- Origin at the centre of the asset's base, so it sits on the floor at y = 0 in Godot.
- The front of an asset faces Blender -Y, which is +Z in Godot.
- All faces are flat shaded and coloured by pointing their UVs at one cell of the
  shared palette texture (data/palette.json -> assets/palette/palette.png).
- Parts that move in game (printer gantry, character limbs) are separate objects
  with their origin on the pivot. Attachment points are empties ("markers").
- Everything random comes from the seeded rng, so the same seed and parameters
  always give the same asset.

A generator module defines `add_arguments(parser)` and `build(args, rng)`, and
ends with `if __name__ == "__main__": common.run(sys.modules[__name__])`.
"""

import argparse
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
PALETTE_JSON = ROOT / "data" / "palette.json"
PALETTE_PNG = ROOT / "assets" / "palette" / "palette.png"
PREVIEW_DIR = ROOT / "tools" / "previews"
# Godot's post-import script swaps the material with this name for the shared one.
MATERIAL_NAME = "palette_flat"
# For meshes the game colours at runtime (printed items): one flat colour set per instance.
TINT_MATERIAL_NAME = "tint_flat"
AXIS_ROTATIONS = {"X": (0.0, math.pi / 2, 0.0), "Y": (math.pi / 2, 0.0, 0.0), "Z": (0.0, 0.0, 0.0)}

# Pivot of each object in asset space, so children can be placed relative to parents.
_pivots = {}


class Palette:
    def __init__(self):
        data = json.loads(PALETTE_JSON.read_text())
        self.names = [colour["name"] for colour in data["colours"]]
        self.columns = data["columns"]
        self.rows = math.ceil(len(self.names) / self.columns)

    def uv(self, name):
        """UV at the centre of the named colour's cell."""
        if name not in self.names:
            raise ValueError(f"Unknown palette colour '{name}'. See data/palette.json")
        index = self.names.index(name)
        column, row = index % self.columns, index // self.columns
        return ((column + 0.5) / self.columns, 1.0 - (row + 0.5) / self.rows)


class MeshBuilder:
    """Builds one flat shaded mesh out of palette-coloured primitives.

    All positions are in asset space, whatever pivot the object ends up with.
    """

    def __init__(self, material=MATERIAL_NAME):
        self.material = material
        self.palette = Palette()
        self.bm = bmesh.new()
        self.uv_layer = self.bm.loops.layers.uv.new("UVMap")

    def box(self, size, centre, colour, rotation=(0.0, 0.0, 0.0), taper=1.0, bevel=0.0, bevel_segments=1):
        """Box of `size` (x, y, z) at `centre`, rotated by XYZ euler radians.

        `taper` scales the top face (a number, or an (x, y) pair). `bevel` chamfers
        every edge; more `bevel_segments` round it off.
        """
        before = set(self.bm.faces)
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        taper_x, taper_y = taper if isinstance(taper, tuple) else (taper, taper)
        for vert in verts:
            if vert.co.z > 0:
                vert.co.x *= taper_x
                vert.co.y *= taper_y
        matrix = _transform(centre, rotation) @ Matrix.Diagonal((*size, 1.0))
        bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)
        if bevel > 0:
            edges = list({edge for vert in verts for edge in vert.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=bevel_segments, affect="EDGES", profile=0.5)
        return self._paint_new(before, colour)

    def capsule(self, radius, length, centre, colour, segments=8, axis="Z", rotation=None, rounding=0.6, round_segments=2):
        """Low poly cylinder with rounded-off ends, `length` long overall, along `axis`."""
        before = set(self.bm.faces)
        verts = bmesh.ops.create_cone(
            self.bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length
        )["verts"]
        # The rim edges are the ones lying flat in a cap.
        rims = [
            edge for edge in {edge for vert in verts for edge in vert.link_edges}
            if abs(edge.verts[0].co.z - edge.verts[1].co.z) < 1e-6
        ]
        offset = min(radius * rounding, length * 0.45)
        bmesh.ops.bevel(self.bm, geom=rims, offset=offset, segments=round_segments, affect="EDGES", profile=0.5)
        faces = [face for face in self.bm.faces if face not in before]
        matrix = _transform(centre, AXIS_ROTATIONS[axis] if rotation is None else rotation)
        bmesh.ops.transform(self.bm, matrix=matrix, verts=list({vert for face in faces for vert in face.verts}))
        self.paint(faces, colour)
        return faces

    def shell(self, radius, height, wall, colour, segments=6, centre=(0.0, 0.0, 0.0), floor=None,
              radius_top=None, chamfer=0.0, turn=0.0, open_base=False):
        """Open-topped hollow container as one clean piece: pots, cups, bins, tubs.

        A prism with `segments` sides (6 hexagonal, 4 square, 12 or more round),
        standing on `centre` with the opening upwards. Corners and the floor are
        right by construction, so prefer this to leaning separate wall boxes together.

        `radius` is centre to outer corner at the base, `radius_top` the same at the
        rim if the sides should flare or narrow. `wall` is the wall thickness and
        `floor` the base thickness (defaults to `wall`). `chamfer` cuts the outer
        top and bottom edges. `turn` rotates it about Z, in radians; at 0 a corner
        points along +X. `open_base` leaves out the floor, for a bare wall open at
        both ends: cutters, rings, sleeves.
        """
        floor = wall if floor is None else floor
        top = radius if radius_top is None else radius_top
        # Thickness is measured square to a wall, so corners move in by a bit more.
        corner_inset = wall / math.cos(math.pi / segments)
        # Rings of points from the outside bottom, up and over the rim, down to the inside floor.
        rings = [
            (radius - chamfer, 0.0),
            (radius, chamfer),
            (top, height - chamfer),
            (top - chamfer, height),
            (top - corner_inset, height),
            (radius + (top - radius) * floor / height - corner_inset, floor),
        ]
        if chamfer <= 0.0:
            rings = [rings[0], rings[3], rings[4], rings[5]]
        if open_base:
            rings[-1] = (radius - corner_inset, 0.0)
        origin = Vector(centre)
        loops = []
        for ring_radius, z in rings:
            loops.append([
                self.bm.verts.new(origin + Vector((
                    ring_radius * math.cos(turn + math.tau * index / segments),
                    ring_radius * math.sin(turn + math.tau * index / segments),
                    z)))
                for index in range(segments)
            ])
        return self._skin(loops, colour, closed=open_base)

    def tray(self, size, wall, colour, centre=(0.0, 0.0, 0.0), floor=None, taper=0.0, chamfer=0.0, rim=None):
        """Open-topped rectangular container as one clean piece: bins, trays, drawers, boxes.

        `size` is the outside (x, y, z) at the top of the walls, standing on `centre`.
        `wall` is the wall thickness and `floor` the base thickness (defaults to
        `wall`). `taper` brings each side of the base in by that much, so the walls
        lean outwards. `chamfer` cuts the outer top and bottom edges. `rim` is an
        (overhang, depth) pair for a band standing proud around the top.
        """
        width, depth, height = size
        floor = wall if floor is None else floor
        # Profile from the outside bottom, up and over the top, down to the inside floor.
        # Each point is (distance out from the base outline, z).
        profile = [(-chamfer, 0.0), (0.0, chamfer)] if chamfer > 0.0 else [(0.0, 0.0)]
        outer = taper
        if rim is not None:
            overhang, rim_depth = rim
            under = height - rim_depth
            profile += [(taper * under / height, under), (taper + overhang, under)]
            outer = taper + overhang
        profile += [(outer, height - chamfer), (outer - chamfer, height)] if chamfer > 0.0 else [(outer, height)]
        profile += [(taper - wall, height), (taper * floor / height - wall, floor)]
        origin = Vector(centre)
        half_x, half_y = width / 2 - taper, depth / 2 - taper
        loops = [
            [
                self.bm.verts.new(origin + Vector((sign_x * (half_x + out), sign_y * (half_y + out), z)))
                for sign_x, sign_y in ((1, 1), (-1, 1), (-1, -1), (1, -1))
            ]
            for out, z in profile
        ]
        return self._skin(loops, colour)

    def plate(self, points, thickness, colour, centre=(0.0, 0.0, 0.0)):
        """Flat solid cut to a 2D outline: silhouettes, templates, tags.

        `points` are (x, y) pairs in order, anticlockwise seen from above.
        """
        origin = Vector(centre)
        loops = [[self.bm.verts.new(origin + Vector((x, y, z))) for x, y in points] for z in (0.0, thickness)]
        return self._skin(loops, colour)

    def outline(self, points, height, wall, colour, centre=(0.0, 0.0, 0.0)):
        """Thin wall following a 2D outline, open top and bottom: cookie cutters of any shape.

        `points` are (x, y) pairs in order, anticlockwise seen from above. The
        wall goes inwards from them.
        """
        origin = Vector(centre)
        inner = _inset(points, wall)
        loops = [
            [self.bm.verts.new(origin + Vector((x, y, z))) for x, y in ring]
            for ring, z in ((points, 0.0), (points, height), (inner, height), (inner, 0.0))
        ]
        return self._skin(loops, colour, closed=True)

    def _skin(self, loops, colour, closed=False):
        """Faces joining a stack of matching point loops, capped at the first and last.

        With `closed` the last loop joins back to the first instead, leaving no caps.
        """
        segments = len(loops[0])
        if closed:
            faces = []
            loops = loops + [loops[0]]
        else:
            faces = [self.bm.faces.new(list(reversed(loops[0]))), self.bm.faces.new(loops[-1])]
        for lower, upper in zip(loops, loops[1:]):
            for index in range(segments):
                following = (index + 1) % segments
                faces.append(self.bm.faces.new((lower[index], lower[following], upper[following], upper[index])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        self.paint(faces, colour)
        return faces

    def cylinder(self, radius, depth, centre, colour, segments=8, axis="Z", rotation=None, radius_top=None):
        """Cylinder along `axis` (or an explicit rotation). `radius_top` makes it a cone."""
        before = set(self.bm.faces)
        verts = bmesh.ops.create_cone(
            self.bm,
            cap_ends=True,
            segments=segments,
            radius1=radius,
            radius2=radius if radius_top is None else radius_top,
            depth=depth,
        )["verts"]
        matrix = _transform(centre, AXIS_ROTATIONS[axis] if rotation is None else rotation)
        bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)
        return self._paint_new(before, colour)

    def ball(self, radius, centre, colour, subdivisions=2, scale=(1.0, 1.0, 1.0), rotation=(0.0, 0.0, 0.0)):
        """Faceted ball (an icosphere) for heads, globes and knobs. `scale` squashes or stretches it.

        `subdivisions` 1 gives 20 triangles, 2 gives 80.
        """
        before = set(self.bm.faces)
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=subdivisions, radius=radius)["verts"]
        matrix = _transform(centre, rotation) @ Matrix.Diagonal((*scale, 1.0))
        bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)
        return self._paint_new(before, colour)

    def paint(self, faces, colour, facing=None):
        """Recolours faces. With `facing`, only those whose normal points that way."""
        uv = self.palette.uv(colour)
        self.bm.normal_update()
        for face in faces:
            if facing is None or face.normal.dot(Vector(facing).normalized()) > 0.9:
                for loop in face.loops:
                    loop[self.uv_layer].uv = uv

    def _paint_new(self, before, colour):
        faces = [face for face in self.bm.faces if face not in before]
        self.paint(faces, colour)
        return faces

    def finish(self, name, pivot=(0.0, 0.0, 0.0), parent=None):
        """Writes the mesh into a new object whose origin is at `pivot`."""
        bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-Vector(pivot))
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.materials.append(tint_material() if self.material == TINT_MATERIAL_NAME else palette_material())
        return _link(bpy.data.objects.new(name, mesh), pivot, parent)


def marker(name, position, parent=None, rotation=(0.0, 0.0, 0.0)):
    """Empty that marks an attachment point. Imports into Godot as a Node3D."""
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_size = 0.05
    empty.rotation_euler = rotation
    return _link(empty, position, parent)


def _link(obj, pivot, parent):
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = Vector(pivot) - Vector(_pivots[parent.name] if parent else (0.0, 0.0, 0.0))
    _pivots[obj.name] = tuple(pivot)
    return obj


def _inset(points, distance):
    """The outline moved inwards by `distance`, with mitred corners. Points run anticlockwise."""
    moved = []
    for index, point in enumerate(points):
        here = Vector(point)
        before = (here - Vector(points[index - 1])).normalized()
        after = (Vector(points[(index + 1) % len(points)]) - here).normalized()
        normal_before, normal_after = Vector((-before.y, before.x)), Vector((-after.y, after.x))
        # Clamped so a very sharp corner does not shoot off into a long spike.
        mitre = (normal_before + normal_after) / max(1.0 + normal_before.dot(normal_after), 0.3)
        moved.append(tuple(here + mitre * distance))
    return moved


def _transform(centre, rotation):
    return Matrix.Translation(centre) @ Euler(rotation).to_matrix().to_4x4()


def reset_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for blocks in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights, bpy.data.worlds, bpy.data.images):
        for block in list(blocks):
            blocks.remove(block)
    _pivots.clear()


def palette_material():
    material = bpy.data.materials.get(MATERIAL_NAME)
    if material is not None:
        return material
    material = bpy.data.materials.new(MATERIAL_NAME)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    shader = nodes["Principled BSDF"]
    shader.inputs["Roughness"].default_value = 1.0
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(PALETTE_PNG))
    texture.interpolation = "Closest"
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    return material


def tint_material():
    material = bpy.data.materials.get(TINT_MATERIAL_NAME)
    if material is None:
        material = bpy.data.materials.new(TINT_MATERIAL_NAME)
        material.use_nodes = True
        shader = material.node_tree.nodes["Principled BSDF"]
        shader.inputs["Roughness"].default_value = 1.0
        shader.inputs["Base Color"].default_value = (0.85, 0.85, 0.85, 1.0)
    return material


def export_glb(path):
    """Exports everything in the scene. Call before render_preview adds its rig."""
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        # Godot supplies the palette texture through the shared material.
        export_image_format="NONE",
    )
    print(f"Exported {path}")


def render_preview(path, resolution=512, direction=None, margin=1.15):
    """Renders the scene's meshes to a PNG.

    From the game's isometric angle by default, or looking back along
    `direction` (a vector from the subject towards the camera). Can be called
    more than once on the same scene for several views. `margin` is the frame
    width as a multiple of the subject, for subjects much wider than tall.
    """
    scene = bpy.context.scene
    for leftover in [obj for obj in scene.objects if obj.name.startswith("preview_")]:
        bpy.data.objects.remove(leftover, do_unlink=True)
    bpy.context.view_layer.update()
    objects = [obj for obj in scene.objects if obj.type == "MESH"]
    corners = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    low = Vector(min(corner[i] for corner in corners) for i in range(3))
    high = Vector(max(corner[i] for corner in corners) for i in range(3))
    centre = (low + high) / 2
    extent = max((high - low).length, 0.1)

    ground = MeshBuilder()
    ground.box((extent * 20, extent * 20, 0.01), (centre.x, centre.y, low.z - 0.005), "cream")
    ground.finish("preview_ground")

    camera = bpy.data.objects.new("preview_camera", bpy.data.cameras.new("preview_camera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = extent * margin
    # True isometric: 45 degrees round, ~35.26 degrees down.
    isometric = (1.0, -1.0, math.sqrt(2.0) * math.tan(math.radians(35.264)))
    offset = Vector(direction or isometric).normalized() * extent * 10
    camera.location = centre + offset
    camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
    camera.data.clip_end = extent * 40
    scene.camera = camera

    sun = bpy.data.objects.new("preview_sun", bpy.data.lights.new("preview_sun", "SUN"))
    scene.collection.objects.link(sun)
    sun.data.energy = 3.0
    sun.data.angle = math.radians(8)
    sun.data.color = (1.0, 0.95, 0.88)
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(-20))

    world = bpy.data.worlds.new("preview_world")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.95, 0.88, 0.80, 1.0)
    background.inputs["Strength"].default_value = 0.6
    scene.world = world

    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.filepath = str(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {path}")


def run(module, argv=None):
    """Runs one generator: parse arguments, build, export, render the preview.

    `argv` defaults to everything after `--` on Blender's command line.
    """
    parser = argparse.ArgumentParser(description=module.__doc__)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--out", type=Path, required=True, help=".glb path, relative to the repo root")
    parser.add_argument("--no-preview", action="store_true", help="skip the preview render")
    module.add_arguments(parser)
    if argv is None:
        argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parser.parse_args(argv)
    if not args.out.is_absolute():
        args.out = ROOT / args.out

    reset_scene()
    module.build(args, random.Random(args.seed))
    export_glb(args.out)
    if not args.no_preview:
        # A module can ask for a bigger render if its asset is a whole scene.
        render_preview(PREVIEW_DIR / f"{args.out.stem}.png", resolution=getattr(module, "PREVIEW_RESOLUTION", 512))
