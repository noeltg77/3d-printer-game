"""Rebuilds a premises in Blender from a snapshot the game wrote
(scripts/dev/trailer_snapshot.gd -> tools/trailer/worlds/<place>.json).

Each model is imported once from its .glb into a hidden library collection
and every instance is a copy of those objects sharing their mesh data, posed
as the game had it (printer gantries, character limbs) and tinted like the
game's tint material. Runs inside Blender's Python.
"""

import json
import re
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
PALETTE_PNG = ROOT / "assets" / "palette" / "palette.png"

# Godot is Y up with the front at +Z; Blender is Z up with the front at -Y.
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_INV = C.inverted()

_library = {}


def godot_matrix(values):
    """A Godot transform (basis columns, then origin) as a Blender matrix."""
    bx, by, bz, origin = values[0:3], values[3:6], values[6:9], values[9:12]
    m = Matrix.Identity(4)
    for row in range(3):
        m[row][0], m[row][1], m[row][2], m[row][3] = bx[row], by[row], bz[row], origin[row]
    return C @ m @ C_INV


def godot_view(values):
    """A Godot camera or light transform as a Blender one. Both look down
    their own -Z with +Y up, so only the world axes change."""
    return godot_matrix(values) @ C


def godot_point(values):
    return Vector((values[0], -values[2], values[1]))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def palette_material():
    mat = bpy.data.materials.get("trailer_palette")
    if mat:
        return mat
    mat = bpy.data.materials.new("trailer_palette")
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(str(PALETTE_PNG), check_existing=True)
    image.interpolation = "Closest"
    links.new(image.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    # Lit windows and lamps after dark: emission driven by the object's
    # "glow" property, which is 0 by day.
    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_type = "OBJECT"
    attr.attribute_name = "glow"
    links.new(image.outputs["Color"], bsdf.inputs["Emission Color"])
    links.new(attr.outputs["Fac"], bsdf.inputs["Emission Strength"])
    return mat


def tint_material():
    mat = bpy.data.materials.get("trailer_tint")
    if mat:
        return mat
    mat = bpy.data.materials.new("trailer_tint")
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    info = nodes.new("ShaderNodeObjectInfo")
    links.new(info.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    return mat


def library_collection():
    coll = bpy.data.collections.get("library")
    if coll is None:
        coll = bpy.data.collections.new("library")
        bpy.context.scene.collection.children.link(coll)
        bpy.context.view_layer.layer_collection.children["library"].exclude = True
    return coll


def load_model(res_path):
    """Imports a .glb once. Returns [(path within the model, object)], parents first."""
    if res_path in _library:
        return _library[res_path]
    file = ROOT / res_path.replace("res://", "")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(file))
    new = [o for o in bpy.data.objects if o not in before]
    lib = library_collection()
    for obj in new:
        for coll in list(obj.users_collection):
            coll.objects.unlink(obj)
        lib.objects.link(obj)
        if obj.type == "MESH":
            for slot in obj.material_slots:
                if slot.material and slot.material.name.startswith("tint_flat"):
                    slot.material = tint_material()
                else:
                    slot.material = palette_material()

    def path_of(obj):
        name = re.sub(r"\.\d{3}$", "", obj.name)
        return name if obj.parent is None else path_of(obj.parent) + "/" + name

    entries = sorted(((path_of(o), o) for o in new), key=lambda e: e[0].count("/"))
    _library[res_path] = entries
    return entries


class Instance:
    def __init__(self, data, root, parts, rest):
        self.name = data["name"]
        self.scene = data["scene"]
        self.kind = data.get("kind", "")
        self.root = root
        self.parts = parts
        # Each part's pose in the model as built, before the game moved it.
        self.rest = rest

    @property
    def model(self):
        return Path(self.scene).stem

    def part(self, path):
        return self.parts.get(path)


class World:
    def __init__(self, name, offset):
        self.name = name
        self.offset = Vector(offset)
        self.instances = []
        self.lights = []
        self.camera = None
        self.collection = None

    def find(self, pattern):
        return [i for i in self.instances if re.search(pattern, i.name) or re.search(pattern, i.scene)]

    def to_world(self, godot_xyz):
        return self.offset + godot_point(godot_xyz)


def build_world(json_path, offset=(0, 0, 0), name=None):
    data = json.loads(Path(json_path).read_text())
    name = name or Path(json_path).stem
    world = World(name, offset)
    coll = bpy.data.collections.new("world_" + name)
    bpy.context.scene.collection.children.link(coll)
    world.collection = coll
    shift = Matrix.Translation(Vector(offset))
    for entry in data["objects"]:
        lib = load_model(entry["scene"])
        root = bpy.data.objects.new(entry["name"].split("/")[-1], None)
        root.empty_display_size = 0.2
        coll.objects.link(root)
        root.matrix_world = shift @ godot_matrix(entry["transform"])
        copies, parts, rest = {}, {}, {}
        hidden = set(entry.get("hidden", []))
        for path, src in lib:
            obj = src.copy()
            coll.objects.link(obj)
            parent_path = path.rpartition("/")[0]
            obj.parent = copies[parent_path] if parent_path else root
            obj.matrix_parent_inverse = Matrix.Identity(4)
            pose = entry["parts"].get(path)
            obj.matrix_basis = godot_matrix(pose) if pose else src.matrix_basis.copy()
            copies[path] = obj
            parts[path] = obj
            rest[path] = src.matrix_basis.copy()
            tint = entry["tints"].get(path)
            if tint:
                obj.color = (*[srgb_to_linear(c) for c in tint], 1.0)
            obj["glow"] = 0.0
        for path in hidden:
            for p, obj in copies.items():
                if p == path or p.startswith(path + "/"):
                    obj.hide_render = obj.hide_viewport = True
        world.instances.append(Instance(entry, root, parts, rest))
    for lamp in data.get("lights", []):
        light = bpy.data.lights.new(name + "_" + lamp["name"], "POINT")
        light.color = [srgb_to_linear(c) for c in lamp["colour"]]
        light.energy = lamp["energy"] * 60.0
        light.shadow_soft_size = 0.4
        # The game's room lamps cast no shadows (the sun does), and four
        # premises of them would overflow EEVEE's shadow pool.
        light.use_shadow = False
        light.use_custom_distance = True
        light.cutoff_distance = lamp["range"] * 1.4
        obj = bpy.data.objects.new(light.name, light)
        obj.location = world.to_world(lamp["position"])
        coll.objects.link(obj)
        world.lights.append(obj)
    world.camera = data["camera"]
    return world
