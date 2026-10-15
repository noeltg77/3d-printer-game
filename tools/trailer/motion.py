"""Animation for the trailer: easing, camera moves, printers printing,
characters idling and walking, and prints being built layer by layer.
The printer and character maths follow the game's own (PrinterStation._process,
CharacterRig._pose_target) so they move as they do in game.
Runs inside Blender's Python."""

import math
import zlib

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

from world import C, C_INV


# --- Easing -----------------------------------------------------------------

def clamp01(t):
    return max(0.0, min(1.0, t))


def smooth(t):
    """Ease in and out (smootherstep), for camera moves that start and stop."""
    t = clamp01(t)
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def ease_out(t, power=3.0):
    t = clamp01(t)
    return 1.0 - (1.0 - t) ** power


def ease_in(t, power=3.0):
    return clamp01(t) ** power


def back_out(t, overshoot=1.6):
    """Overshoots a little and settles, for UI that pops in."""
    t = clamp01(t) - 1.0
    return t * t * ((overshoot + 1.0) * t + overshoot) + 1.0


def glide(t, ease=0.35):
    """Constant speed through the middle with eased ends: a dolly that is
    already moving reads better than one that stops dead, so the shot never
    looks parked. `ease` is the share of the time spent speeding up (and
    the same slowing down)."""
    t = clamp01(t)
    e = max(1e-4, min(0.5, ease))
    v = 1.0 / (1.0 - e)  # top speed so that the area is one
    if t < e:
        return 0.5 * v * t * t / e
    if t > 1.0 - e:
        u = 1.0 - t
        return 1.0 - 0.5 * v * u * u / e
    return 0.5 * v * e + v * (t - e)


def lerp(a, b, t):
    return a + (b - a) * t


# --- Camera -----------------------------------------------------------------

class Pose:
    """A camera as where it looks, from which direction and how far:
    yaw and pitch in degrees (yaw 0 looks north, along +Y; the game looks
    from the south east, yaw about -45), distance in metres, lens in mm."""

    def __init__(self, target, yaw, pitch, distance, lens=50.0, roll=0.0, fstop=None, focus=None):
        self.target = Vector(target)
        self.yaw, self.pitch, self.distance = yaw, pitch, distance
        self.lens, self.roll = lens, roll
        self.fstop, self.focus = fstop, focus

    def mix(self, other, t):
        return Pose(self.target.lerp(other.target, t), lerp(self.yaw, other.yaw, t), lerp(self.pitch, other.pitch, t),
                    math.exp(lerp(math.log(self.distance), math.log(other.distance), t)),
                    lerp(self.lens, other.lens, t), lerp(self.roll, other.roll, t),
                    None if self.fstop is None else lerp(self.fstop, other.fstop if other.fstop else self.fstop, t),
                    None if self.focus is None else lerp(self.focus, other.focus if other.focus else self.focus, t))

    def matrix(self):
        yaw, pitch = math.radians(self.yaw), math.radians(self.pitch)
        # Direction from the camera to the target.
        look = Vector((-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), -math.sin(pitch)))
        eye = self.target - look * self.distance
        rot = look.to_track_quat("-Z", "Y")
        if self.roll:
            rot = rot @ Quaternion((0, 0, 1), math.radians(self.roll))
        return Matrix.Translation(eye) @ rot.to_matrix().to_4x4()


def key_camera(cam_obj, frame, pose, handheld=None):
    """Keys the camera at a frame. `handheld` (amount, seed) adds a slow,
    small drift so a still shot breathes."""
    m = pose.matrix()
    if handheld:
        amount, seed = handheld
        t = frame / 60.0
        dx = (math.sin(t * 0.9 + seed) + 0.5 * math.sin(t * 2.3 + seed * 2.1)) * amount
        dy = (math.sin(t * 0.7 + seed * 1.7) + 0.5 * math.sin(t * 1.9 + seed * 0.3)) * amount
        m = m @ Euler((math.radians(dy), math.radians(dx), 0.0)).to_matrix().to_4x4()
    cam_obj.matrix_world = m
    cam_obj.keyframe_insert("location", frame=frame)
    cam_obj.rotation_mode = "QUATERNION"
    cam_obj.keyframe_insert("rotation_quaternion", frame=frame)
    cam = cam_obj.data
    cam.lens = pose.lens
    cam.keyframe_insert("lens", frame=frame)
    if pose.fstop:
        cam.dof.use_dof = True
        cam.dof.aperture_fstop = pose.fstop
        cam.dof.focus_distance = pose.focus if pose.focus else pose.distance
        cam.dof.keyframe_insert("aperture_fstop", frame=frame)
        cam.dof.keyframe_insert("focus_distance", frame=frame)


def linear_keys(id_data):
    anim = id_data.animation_data
    if anim and anim.action:
        for fc in fcurves_of(anim.action):
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"


def fcurves_of(action):
    """F-curves of an action, for both the old and the layered action API."""
    if hasattr(action, "fcurves") and len(getattr(action, "fcurves", [])):
        return list(action.fcurves)
    found = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                found.extend(bag.fcurves)
    return found


# --- Printers ---------------------------------------------------------------

CORE_XY_LIFT = 0.14
GANTRY_DROP = 0.175
PLATE_SIZE = 0.24


def godot_offset(dx, dy, dz):
    return Vector((dx, -dz, dy))


def printer_motion(inst):
    name = inst.model.replace("printer_", "")
    if name.startswith("lumina"):
        return "resin_lift"
    if name in ("snapbox_junior", "snapbox_adventurer_5", "zippy_x1", "forge_industrial_600"):
        return "core_xy"
    return "bed_slinger"


def plate_size(inst):
    plate, corner = inst.part("frame/bed/plate"), inst.part("frame/bed/plate_corner")
    if plate is None or corner is None:
        return PLATE_SIZE
    reach = corner.matrix_basis.translation - plate.matrix_basis.translation
    return 2.0 * min(abs(reach.x), abs(reach.y))


def animate_printer(inst, frames, built=0.0, seed=0.0, step=2, speed=1.0, amount=None, fps=60):
    """Keys a printer's bed, gantry and toolhead as PrinterStation._process
    moves them while printing, across `frames` (start, end). `built` is how
    tall the print on the plate is in metres, a number or a function of the
    frame; `amount`, a function of the frame from 0 to 1, scales the head's
    darting about (0 when it is parked)."""
    bed, gantry, head = inst.part("frame/bed"), inst.part("frame/gantry"), inst.part("frame/gantry/toolhead")
    if not (bed and gantry and head):
        return
    motion = printer_motion(inst)
    reach = plate_size(inst) / PLATE_SIZE
    rest = {o: inst.rest[p].translation.copy() for o, p in
            ((bed, "frame/bed"), (gantry, "frame/gantry"), (head, "frame/gantry/toolhead"))}
    start, end = frames
    for frame in sorted(set(range(start, end + 1, step)) | {end}):
        t = frame / fps * speed + seed
        h = built(frame) if callable(built) else built
        a = amount(frame) if amount else 1.0
        # A quick jitter over the game's slow sweep, so a close look reads as printing.
        dart = (math.sin(t * 5.0) * 0.09 - 0.05 + math.sin(t * 23.0) * 0.012) * reach * a
        b, g, th = Vector(), Vector(), Vector()
        if motion == "resin_lift":
            g = godot_offset(0, h, 0)
        elif motion == "core_xy":
            th = godot_offset(dart, 0, 0)
            b = godot_offset(0, CORE_XY_LIFT - h, 0)
            g = godot_offset(0, 0, (math.sin(t * 3.7) * 0.07 + 0.03 + math.sin(t * 17.0) * 0.01) * reach * a)
        else:
            th = godot_offset(dart, 0, 0)
            g = godot_offset(0, h - GANTRY_DROP, 0)
            b = godot_offset(0, 0, (math.sin(t * 3.1) * 0.05 + math.sin(t * 19.0) * 0.008) * reach * a)
        for obj, delta in ((bed, b), (gantry, g), (head, th)):
            obj.location = rest[obj] + delta
            obj.keyframe_insert("location", frame=frame)


# --- Characters -------------------------------------------------------------

JOINTS = ("body", "body/head", "body/arm_l", "body/arm_r", "body/arm_l/forearm_l", "body/arm_r/forearm_r",
          "body/leg_l", "body/leg_r", "body/leg_l/shin_l", "body/leg_r/shin_r")
WALK_RATE = 9.0


def _godot_rotation(x, y, z):
    """A Godot Node3D rotation (Euler YXZ) as a Blender rotation matrix."""
    r = Matrix.Rotation(y, 4, "Y") @ Matrix.Rotation(x, 4, "X") @ Matrix.Rotation(z, 4, "Z")
    return C @ r @ C_INV


def pose_targets(pose, t, carrying=False, rate=1.0):
    """CharacterRig._pose_target: joint -> godot euler, and the body's lift."""
    target, lift = {}, 0.0
    if pose == "idle":
        breath = math.sin(t * 2.0)
        lift = breath * 0.006
        target["head"] = (breath * 0.02, math.sin(t * 0.7) * 0.15, 0.0)
        target["arm_l"] = (0.0, 0.0, 0.07 + breath * 0.02)
        target["arm_r"] = (0.0, 0.0, -0.07 - breath * 0.02)
    elif pose == "walk":
        phase = t * WALK_RATE * rate
        swing = math.sin(phase)
        lift = abs(math.cos(phase)) * 0.025
        target["body"] = (0.06, 0.0, swing * 0.03)
        target["head"] = (-0.04, 0.0, -swing * 0.03)
        target["leg_l"] = (-swing * 0.65, 0.0, 0.0)
        target["leg_r"] = (swing * 0.65, 0.0, 0.0)
        target["shin_l"] = (max(math.cos(phase), 0.0) * 0.9, 0.0, 0.0)
        target["shin_r"] = (max(-math.cos(phase), 0.0) * 0.9, 0.0, 0.0)
        target["arm_l"] = (swing * 0.5, 0.0, 0.05)
        target["arm_r"] = (-swing * 0.5, 0.0, -0.05)
        target["forearm_l"] = (-0.25, 0.0, 0.0)
        target["forearm_r"] = (-0.25, 0.0, 0.0)
    elif pose == "work":
        # Busy at a bench: hands forward, working.
        tap = math.sin(t * 7.0)
        lift = math.sin(t * 2.0) * 0.004
        target["body"] = (0.1, 0.0, 0.0)
        target["head"] = (0.25, math.sin(t * 0.8) * 0.1, 0.0)
        target["arm_l"] = (-0.75 + tap * 0.08, 0.0, 0.05)
        target["arm_r"] = (-0.75 - tap * 0.08, 0.0, -0.05)
        target["forearm_l"] = (-0.9 + tap * 0.1, 0.0, 0.0)
        target["forearm_r"] = (-0.9 - tap * 0.12, 0.0, 0.0)
    elif pose == "sit":
        tap = math.sin(t * 13.0) * 0.07
        target["head"] = (0.08, math.sin(t * 0.5) * 0.08, 0.0)
        target["leg_l"] = target["leg_r"] = (-1.4, 0.0, 0.0)
        target["shin_l"] = target["shin_r"] = (1.4, 0.0, 0.0)
        target["arm_l"] = target["arm_r"] = (-0.9, 0.0, 0.0)
        target["forearm_l"] = (-0.85 + tap, 0.0, 0.0)
        target["forearm_r"] = (-0.85 - tap, 0.0, 0.0)
    if carrying and pose != "sit":
        target["arm_l"] = target["arm_r"] = (-0.45, 0.0, 0.0)
        target["forearm_l"] = target["forearm_r"] = (-1.05, 0.0, 0.0)
    return target, lift


class Rig:
    """Keys a character's joints from a pose over time."""

    def __init__(self, inst):
        self.inst = inst
        self.joints = {p.rsplit("/", 1)[-1]: inst.part(p) for p in JOINTS if inst.part(p)}
        self.rest = {p.rsplit("/", 1)[-1]: inst.rest[p].translation.copy() for p in JOINTS if inst.part(p)}
        self.phase = (zlib.crc32(inst.name.encode()) % 1000) / 159.0

    def key(self, frame, pose, carrying=False, fps=60, rate=1.0):
        target, lift = pose_targets(pose, frame / fps + self.phase, carrying, rate)
        for name, joint in self.joints.items():
            rot = _godot_rotation(*target.get(name, (0.0, 0.0, 0.0)))
            loc = self.rest[name] + (Vector((0, 0, lift)) if name == "body" else Vector())
            joint.matrix_basis = Matrix.Translation(loc) @ rot
            joint.rotation_mode = "QUATERNION"
            joint.keyframe_insert("location", frame=frame)
            joint.keyframe_insert("rotation_quaternion", frame=frame)

    def animate(self, frames, pose, carrying=False, step=2):
        for frame in sorted(set(range(frames[0], frames[1] + 1, step)) | {frames[1]}):
            self.key(frame, pose, carrying)


def walk_path(inst, points, frames, speed=1.6, step=1, carrying=False):
    """Walks a character along points (Blender world, on the floor) at the
    game's walking speed, starting at frames[0], then idles until frames[1]."""
    rig = Rig(inst)
    root = inst.root
    scale = root.matrix_world.to_scale()
    pts = [Vector(p) for p in points]
    lengths = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    total = sum(lengths)
    start, end = frames
    walk_frames = total / speed * 60.0
    heading = None
    for frame in range(start, end + 1, step):
        d = min(total, (frame - start) / 60.0 * speed)
        walking = d < total - 1e-3
        i, acc = 0, 0.0
        while i < len(lengths) - 1 and acc + lengths[i] < d:
            acc += lengths[i]
            i += 1
        seg = pts[i + 1] - pts[i]
        pos = pts[i].lerp(pts[i + 1], (d - acc) / lengths[i] if lengths[i] else 0.0)
        if walking or heading is None:
            want = math.atan2(seg.x, -seg.y)  # the model faces -Y
            heading = want if heading is None else heading + math.atan2(math.sin(want - heading), math.cos(want - heading)) * 0.25
        root.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(heading, 4, "Z") @ Matrix.Diagonal((*scale, 1.0))
        root.keyframe_insert("location", frame=frame)
        root.keyframe_insert("rotation_euler", frame=frame)
        rig.key(frame, "walk" if walking else "idle", carrying, rate=speed / 1.6)
    return start + walk_frames


# --- Prints built layer by layer --------------------------------------------

def layer_reveal(meshes, parent, frames, height, name="cutter", layer=0.002):
    """Builds meshes up from their parent's origin to `height` (metres, in
    the parent's frame, up its Z) over frames, a layer at a time. An empty
    hanging from `parent` (the printer's plate, so it moves with the bed)
    rises with the print; each mesh's material shows only what is below it,
    with the layer being laid down glowing hot. Back faces show through the
    cut in the same colour, so the print reads as solid."""
    cutter = bpy.data.objects.new(name, None)
    cutter.empty_display_size = 0.1
    meshes[0].users_collection[0].objects.link(cutter)
    cutter.parent = parent
    start, end = frames
    for frame in range(start - 2, end + 3):
        t = clamp01((frame - start) / max(1, end - start))
        z = math.floor(height * t / layer) * layer if t < 1.0 else height + 0.05
        cutter.location = (0.0, 0.0, z if frame >= start else -0.01)
        cutter.keyframe_insert("location", frame=frame)
    for fc in fcurves_of(cutter.animation_data.action):
        for k in fc.keyframe_points:
            k.interpolation = "CONSTANT"
    made = {}
    for obj in meshes:
        if obj.type != "MESH":
            continue
        # The hot layer fades once the print is done.
        for f, v in ((start, 1.0), (end, 1.0), (end + 20, 0.0)):
            obj["hot_glow"] = v
            obj.keyframe_insert('["hot_glow"]', frame=f)
        for slot in obj.material_slots:
            base = slot.material
            if base is None:
                continue
            if base.name not in made:
                made[base.name] = _clipped(base, cutter)
            slot.link = "OBJECT"
            slot.material = made[base.name]
    return cutter


def _clipped(base, cutter):
    mat = base.copy()
    mat.name = base.name + "_" + cutter.name
    mat.use_backface_culling = False
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    out = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
    surface = out.inputs["Surface"].links[0].from_socket
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    coords = nodes.new("ShaderNodeTexCoord")
    coords.object = cutter
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], xyz.inputs[0])
    below = nodes.new("ShaderNodeMath")
    below.operation = "LESS_THAN"
    below.inputs[1].default_value = 0.0
    links.new(xyz.outputs["Z"], below.inputs[0])
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(below.outputs[0], mix.inputs["Fac"])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(surface, mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])
    # The fresh layer: a thin band just under the cut, glowing.
    band = nodes.new("ShaderNodeMath")
    band.operation = "GREATER_THAN"
    band.inputs[1].default_value = -0.0035
    links.new(xyz.outputs["Z"], band.inputs[0])
    hot = nodes.new("ShaderNodeAttribute")
    hot.attribute_type = "OBJECT"
    hot.attribute_name = "hot_glow"
    glow = nodes.new("ShaderNodeMath")
    glow.operation = "MULTIPLY"
    links.new(band.outputs[0], glow.inputs[0])
    links.new(hot.outputs["Fac"], glow.inputs[1])
    strength = nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY"
    strength.inputs[1].default_value = 3.0
    links.new(glow.outputs[0], strength.inputs[0])
    links.new(strength.outputs[0], bsdf.inputs["Emission Strength"])
    if bsdf.inputs["Base Color"].links:
        links.new(bsdf.inputs["Base Color"].links[0].from_socket, bsdf.inputs["Emission Color"])
    return mat
