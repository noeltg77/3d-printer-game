"""Shared helpers for the asset generators. Runs inside Blender's Python (bpy).

Conventions every generator follows:
- 1 unit = 1 metre, Z up in Blender (the glTF exporter converts to Godot's Y up).
- Origin at the centre of the asset's base, so it sits on the floor at y = 0 in Godot.
- All faces are flat shaded and coloured by pointing their UVs at one cell of the
  shared palette texture (data/palette.json -> assets/palette/palette.png).
- Everything random comes from the seeded rng, so the same seed and parameters
  always give the same asset.
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


def make_parser(description):
    """Argument parser with the options every generator shares."""
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--out", type=Path, required=True, help=".glb path, relative to the repo root")
    parser.add_argument("--no-preview", action="store_true", help="skip the preview render")
    return parser


def parse_args(parser):
    """Parses the arguments after Blender's own, i.e. everything following `--`."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parser.parse_args(argv)
    if not args.out.is_absolute():
        args.out = ROOT / args.out
    return args


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
    """Builds one flat shaded mesh out of palette-coloured primitives."""

    def __init__(self, palette):
        self.palette = palette
        self.bm = bmesh.new()
        self.uv_layer = self.bm.loops.layers.uv.new("UVMap")

    def box(self, size, centre, colour, rotation=(0.0, 0.0, 0.0)):
        """Box of `size` (x, y, z) at `centre`, rotated by XYZ euler radians."""
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        return self._place(verts, Matrix.Diagonal((*size, 1.0)), centre, rotation, colour)

    def cylinder(self, radius, depth, centre, colour, segments=8, rotation=(0.0, 0.0, 0.0), radius_top=None):
        """Cylinder (or cone, with radius_top) along Z before rotation."""
        verts = bmesh.ops.create_cone(
            self.bm,
            cap_ends=True,
            segments=segments,
            radius1=radius,
            radius2=radius if radius_top is None else radius_top,
            depth=depth,
        )["verts"]
        return self._place(verts, Matrix.Identity(4), centre, rotation, colour)

    def paint(self, faces, colour, facing=None):
        """Recolours faces. With `facing`, only those whose normal points that way."""
        uv = self.palette.uv(colour)
        self.bm.normal_update()
        for face in faces:
            if facing is None or face.normal.dot(Vector(facing).normalized()) > 0.9:
                for loop in face.loops:
                    loop[self.uv_layer].uv = uv

    def _place(self, verts, scale, centre, rotation, colour):
        matrix = Matrix.Translation(centre) @ Euler(rotation).to_matrix().to_4x4() @ scale
        bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)
        faces = list({face for vert in verts for face in vert.link_faces})
        self.paint(faces, colour)
        return faces

    def finish(self, name):
        """Writes the mesh into a new object linked to the scene."""
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.materials.append(palette_material())
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


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


def render_preview(path, resolution=768):
    """Renders the scene's meshes from the game's isometric angle to a PNG."""
    scene = bpy.context.scene
    objects = [obj for obj in scene.objects if obj.type == "MESH"]
    corners = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    low = Vector(min(corner[i] for corner in corners) for i in range(3))
    high = Vector(max(corner[i] for corner in corners) for i in range(3))
    centre = (low + high) / 2
    extent = max((high - low).length, 0.1)

    ground = MeshBuilder(Palette())
    ground.box((extent * 20, extent * 20, 0.01), (centre.x, centre.y, low.z - 0.005), "cream")
    ground.finish("preview_ground")

    camera = bpy.data.objects.new("preview_camera", bpy.data.cameras.new("preview_camera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = extent * 1.25
    # True isometric: 45 degrees round, ~35.26 degrees down.
    offset = Vector((1.0, -1.0, math.sqrt(2.0) * math.tan(math.radians(35.264)))).normalized() * extent * 10
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


def finish(args):
    """Standard tail for a generator: export, then render the preview next to it."""
    export_glb(args.out)
    if not args.no_preview:
        render_preview(PREVIEW_DIR / f"{args.out.stem}.png")


def make_rng(seed):
    return random.Random(seed)
