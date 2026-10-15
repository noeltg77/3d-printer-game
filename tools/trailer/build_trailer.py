"""Builds the Steam trailer in Blender: the four premises rebuilt from the
game's own snapshots (tools/trailer/worlds/), a studio of prints, cameras
cut to the music's bars (timeline.py), and the titles in a scene of their own.
Saves tools/trailer/out/trailer.blend, which render.sh renders and joins with
the soundtrack (music.py) into tools/trailer/out/print_shop_tycoon_trailer.mp4.

blender --background --factory-startup --python tools/trailer/build_trailer.py
blender --background --factory-startup --python tools/trailer/build_trailer.py -- --preview
blender ... -- --stills 100,700,1500     # render these frames (picture and titles) to tools/previews/trailer/
"""

import argparse
import json
import zlib
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.append(str(HERE))
import look as L  # noqa: E402
import motion as M  # noqa: E402
import timeline as T  # noqa: E402
import titles as TT  # noqa: E402
import world as W  # noqa: E402

ROOT = HERE.parents[1]
OUT = HERE / "out"
WORLDS = HERE / "worlds"
PREVIEWS = ROOT / "tools" / "previews" / "trailer"
# Each premises far enough from the next that none sees another.
OFFSETS = {"garage": (0, 0, 0), "small_unit": (400, 0, 0), "workshop": (800, 0, 0), "factory": (1200, 0, 0), "studio": (1600, 0, 0)}
PALETTE = {c["name"]: c["hex"] for c in json.loads((ROOT / "data" / "palette.json").read_text())["colours"]}
PLA = next(f for f in json.loads((ROOT / "data" / "filaments.json").read_text())["filaments"] if f["id"] == "pla")["colours"]
# The game looks from the south east, down at the isometric angle.
ISO_YAW, ISO_PITCH = 45.0, 35.26


def colour(name):
    code = PALETTE[name].lstrip("#")
    return (*[W.srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4)], 1.0)


def frames_of(shot):
    for name, a, b in T.SHOTS:
        if name == shot:
            return T.bar(a), T.bar(b)
    raise KeyError(shot)


class Trailer:
    def __init__(self, preview=False):
        self.preview = preview
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.scene = bpy.context.scene
        self.scene.name = "trailer"
        L.setup_render(self.scene, T.WIDTH, T.HEIGHT, T.FPS, samples=24 if preview else 64)
        if preview:
            self.scene.render.resolution_percentage = 50
        self.scene.frame_start, self.scene.frame_end = 0, T.END_FRAME - 1
        self.sun = L.add_sun(self.scene)
        self.sky = L.add_sky(self.scene)
        self.worlds = {}
        for name in ("garage", "small_unit", "workshop", "factory"):
            self.worlds[name] = W.build_world(WORLDS / f"{name}.json", OFFSETS[name], name)
        # Frames each world is on screen, so things only move where seen.
        self.on_screen = {name: [] for name in list(self.worlds) + ["studio"]}
        self.street_lamps = []
        self.cams = []
        self.rng = random.Random(7)

    # --- helpers -------------------------------------------------------------

    def add_model(self, res_path, matrix, colours=None, parent=None, collection=None):
        """Places a copy of a model. colours: one palette name per colour part."""
        lib = W.load_model(res_path)
        coll = collection or self.scene.collection
        root = bpy.data.objects.new(Path(res_path).stem, None)
        root.empty_display_size = 0.05
        coll.objects.link(root)
        if parent:
            root.parent = parent
            root.matrix_parent_inverse = Matrix.Identity(4)
            root.matrix_basis = matrix
        else:
            root.matrix_world = matrix
        copies = {}
        for path, src in lib:
            obj = src.copy()
            coll.objects.link(obj)
            above = path.rpartition("/")[0]
            obj.parent = copies[above] if above else root
            obj.matrix_parent_inverse = Matrix.Identity(4)
            obj.matrix_basis = src.matrix_basis.copy()
            obj["glow"] = 0.0
            copies[path] = obj
            if colours:
                part = int(path.rsplit("colour_", 1)[-1]) - 1 if "colour_" in path.rsplit("/", 1)[-1] else 0
                obj.color = colour(colours[min(part, len(colours) - 1)])
        root["parts"] = list(copies)
        return root, copies

    def bounds(self, res_path):
        """Size of a model's meshes as built: (min corner, max corner)."""
        lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        for _, obj in W.load_model(res_path):
            if obj.type != "MESH":
                continue
            for corner in obj.bound_box:
                p = obj.matrix_world @ Vector(corner)
                lo = Vector(map(min, lo, p))
                hi = Vector(map(max, hi, p))
        return lo, hi

    def printers(self, world):
        return [i for i in self.worlds[world].instances if i.kind == "PrinterStation"]

    def printer_at(self, world, model, x, y):
        best = None
        for inst in self.printers(world):
            if model in inst.model:
                p = inst.root.matrix_world.translation - self.worlds[world].offset
                d = (p.x - x) ** 2 + (p.y - y) ** 2
                if best is None or d < best[0]:
                    best = (d, inst)
        return best[1]

    def prints_on(self, world, printer):
        """Prints the snapshot caught on a printer's plate."""
        plate = printer.part("frame/bed/plate").matrix_world.translation
        found = []
        for inst in self.worlds[world].instances:
            if "/prints/" in inst.scene:
                p = inst.root.matrix_world.translation
                if (Vector((p.x, p.y)) - Vector((plate.x, plate.y))).length < 0.2 and -0.05 < p.z - plate.z < 0.3:
                    found.append(inst)
        return found

    def claim(self, inst, frames):
        """Marks a thing as animated by a shot over frames, so bring_to_life
        leaves it alone there."""
        self.busy.setdefault(inst.name, []).append(frames)

    def is_free(self, inst, span):
        return all(span[1] < a or span[0] > b for a, b in self.busy.get(inst.name, []))

    def show_only(self, objs, frames):
        """Keys objects to render only within frames."""
        for obj in objs:
            for f, hidden in ((0, True), (frames[0], False), (frames[1], True)):
                obj.hide_render = hidden
                obj.keyframe_insert("hide_render", frame=f)

    def hide(self, inst):
        for obj in [inst.root] + list(inst.parts.values()):
            obj.hide_render = obj.hide_viewport = True

    def character(self, world, name_part):
        for inst in self.worlds[world].instances:
            if inst.kind == "CharacterRig" and name_part in inst.name:
                return inst
        raise KeyError(name_part)

    def at(self, world, x, y, z=0.0):
        return self.worlds[world].offset + Vector((x, y, z))

    def camera(self, shot):
        cam = bpy.data.cameras.new("cam_" + shot)
        cam.clip_start, cam.clip_end = 0.02, 400.0
        cam.sensor_width = 36.0
        obj = bpy.data.objects.new("cam_" + shot, cam)
        self.scene.collection.objects.link(obj)
        start, _ = frames_of(shot)
        marker = self.scene.timeline_markers.new(shot, frame=start)
        marker.camera = obj
        self.cams.append(obj)
        return obj

    def move(self, shot, poses, ease=M.smooth, handheld=0.0, world=None):
        """A camera for a shot, moving through poses: [(share of the shot, Pose)].
        Keys run a frame either side, so motion blur at a cut sees the
        camera carry on rather than jump."""
        start, end = frames_of(shot)
        if world:
            self.on_screen[world].append((start, end))
        obj = self.camera(shot)
        for frame in range(start - 2, end + 2):
            t = (frame - start) / (end - start)
            pose = poses[-1][1]
            for (t0, p0), (t1, p1) in zip(poses, poses[1:]):
                if t <= t1:
                    k = (t - t0) / (t1 - t0) if t1 > t0 else 1.0
                    pose = p0.mix(p1, ease(k) if callable(ease) else k)
                    break
            M.key_camera(obj, frame, pose, (handheld, zlib.crc32(shot.encode()) % 7) if handheld else None)
        M.linear_keys(obj)
        M.linear_keys(obj.data)
        # As far out as the shot allows, so depth stays precise on the
        # floor markings of a distant room.
        obj.data.clip_start = max(0.02, min(p.distance for _, p in poses) * 0.04)
        return obj

    def range_of(self, world):
        return self.on_screen[world]

    # --- time of day ---------------------------------------------------------

    def light_at(self, frame, hour):
        """Sun, sky, lamps and lit windows for an hour of the day, after
        the game's DayNight table (scripts/world/day_night.gd)."""
        table = [  # hour, sun energy, sun colour, ambient, ambient colour, lamps, glow
            (0.0, 0.1, (0.55, 0.65, 1.0), 0.33, (0.62, 0.7, 1.0), 1.5, 1.0),
            (5.5, 0.1, (0.55, 0.65, 1.0), 0.33, (0.62, 0.7, 1.0), 1.5, 1.0),
            (7.0, 0.5, (1.0, 0.76, 0.56), 0.36, (1.0, 0.86, 0.8), 1.1, 0.4),
            (9.0, 0.9, (1.0, 0.94, 0.85), 0.45, (1.0, 0.9, 0.8), 1.0, 0.0),
            (16.5, 0.9, (1.0, 0.94, 0.85), 0.45, (1.0, 0.9, 0.8), 1.0, 0.0),
            (18.5, 0.42, (1.0, 0.62, 0.42), 0.36, (1.0, 0.8, 0.7), 1.35, 0.5),
            (20.5, 0.1, (0.55, 0.65, 1.0), 0.33, (0.62, 0.7, 1.0), 1.5, 1.0),
            (24.0, 0.1, (0.55, 0.65, 1.0), 0.33, (0.62, 0.7, 1.0), 1.5, 1.0),
        ]
        for a, b in zip(table, table[1:]):
            if a[0] <= hour <= b[0]:
                k = (hour - a[0]) / (b[0] - a[0])
                row = [M.lerp(x, y, k) if isinstance(x, float) else tuple(M.lerp(p, q, k) for p, q in zip(x, y)) for x, y in zip(a[1:], b[1:])]
                break
        sun_e, sun_c, amb, amb_c, lamps, glow = row
        sun = self.sun
        sun.data.energy = sun_e / 0.9 * 4.2
        sun.data.color = L.lin(sun_c)
        # The sun sinks and swings west through the afternoon (only for looks:
        # the game keeps one direction).
        base = W.godot_view(L.SUN_TRANSFORM)
        day = max(-1.0, min(1.0, (hour - 13.0) / 7.0))
        drop = math.radians(38.0) * max(0.0, abs(day) - 0.15)
        swing = Matrix.Rotation(math.radians(-55.0 * day), 4, "Z")
        axis = (base.to_3x3() @ Vector((1, 0, 0))).normalized()
        sun.matrix_world = swing @ Matrix.Rotation(-drop, 4, axis) @ base
        sun.keyframe_insert("rotation_euler", frame=frame)
        sun.data.keyframe_insert("energy", frame=frame)
        sun.data.keyframe_insert("color", frame=frame)
        bg = self.sky.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (*L.lin(amb_c), 1.0)
        bg.inputs[1].default_value = amb / 0.45 * 0.75
        bg.inputs[0].keyframe_insert("default_value", frame=frame)
        bg.inputs[1].keyframe_insert("default_value", frame=frame)
        for w in self.worlds.values():
            for lamp in w.lights:
                lamp.data.energy = lamp["base_energy"] * lamps
                lamp.data.keyframe_insert("energy", frame=frame)
            for obj in w.glows:
                obj["glow"] = glow * 2.2
                obj.keyframe_insert('["glow"]', frame=frame)
        for lamp in self.street_lamps:
            lamp.data.energy = 220.0 * glow
            lamp.data.keyframe_insert("energy", frame=frame)

    def prepare_lights(self):
        for w in self.worlds.values():
            for lamp in w.lights:
                lamp["base_energy"] = lamp.data.energy
            w.glows = [o for i in w.instances for p, o in i.parts.items()
                       if p.split("/")[-1].startswith("glow_") or "/surroundings/" in i.scene and "glow" in p]
            for inst in w.instances:
                if "/surroundings/" not in inst.scene:
                    continue
                for path, obj in inst.parts.items():
                    if path.split("/")[-1].startswith("lamp_"):
                        light = bpy.data.lights.new("street_" + path, "POINT")
                        light.color = L.lin((1.0, 0.8, 0.5))
                        light.shadow_soft_size = 0.3
                        light.use_shadow = False
                        light.use_custom_distance = True
                        light.cutoff_distance = 14.0
                        lamp_obj = bpy.data.objects.new(light.name, light)
                        lamp_obj.location = obj.matrix_world.translation - Vector((0, 0, 0.3))
                        w.collection.objects.link(lamp_obj)
                        self.street_lamps.append(lamp_obj)

    def time_of_day(self, shot, hours):
        """Keys the light through a shot: hours is a function of 0..1, or a number."""
        start, end = frames_of(shot)
        frames = list(range(start, end, 2)) if callable(hours) else [start]
        for frame in frames + [end - 1]:
            t = M.clamp01((frame - start) / (end - start))
            self.light_at(frame, hours(t) if callable(hours) else hours)

    # --- life in the room ----------------------------------------------------

    def bring_to_life(self):
        """Printers print, prints grow, people breathe, cars drive, wherever
        a world is on screen."""
        for world, ranges in self.on_screen.items():
            if world == "studio" or not ranges:
                continue
            w = self.worlds[world]
            for start, end in ranges:
                span = (start, end - 1)
                for i, inst in enumerate(self.printers(world)):
                    if not self.is_free(inst, span):
                        continue
                    on_plate = self.prints_on(world, inst)
                    height = 0.04
                    if on_plate:
                        height = max(0.01, max(o.root.matrix_world.to_scale().z for o in on_plate) * 0.08)
                    M.animate_printer(inst, span, built=height, seed=i * 1.7, step=2)
                for inst in w.instances:
                    if inst.kind == "CharacterRig" and self.is_free(inst, span):
                        M.Rig(inst).animate(span, "idle", step=2)
                self.traffic(world, span)

    def traffic(self, world, span):
        w = self.worlds[world]
        lanes = []
        for inst in w.instances:
            if "/surroundings/" in inst.scene:
                marks = {p.split("/")[-1]: o.matrix_world.translation.copy() for p, o in inst.parts.items()}
                for name, p in marks.items():
                    if name.endswith("_start") and name.replace("_start", "_end") in marks:
                        lanes.append((p, marks[name.replace("_start", "_end")]))
        if not lanes:
            return
        for inst in w.instances:
            if "/vehicles/" not in inst.scene or "Surroundings" not in inst.name:
                continue
            here = inst.root.matrix_world.translation.copy()

            def distance(lane):
                a, b = lane
                d = (b - a).normalized()
                return ((here - a) - d * (here - a).dot(d)).length

            a, b = min(lanes, key=distance)
            if distance((a, b)) > 1.5:
                continue
            direction = (b - a).normalized()
            length = (b - a).length
            s0 = (here - a).dot(direction)
            base = inst.root.matrix_world.copy()
            for frame in range(span[0], span[1] + 1, 2):
                s = (s0 + 6.0 * frame / T.FPS) % length
                inst.root.matrix_world = Matrix.Translation(a + direction * s - here) @ base
                inst.root.keyframe_insert("location", frame=frame)

    # --- shots ---------------------------------------------------------------

    def first_print_and_garage(self):
        """A dragon prints on the garage's first printer, close up; then the
        camera pulls all the way out to the garage as the game sees it."""
        printer = self.printer_at("garage", "plodder_mini", -2.32, 2.60)
        self.claim(printer, (0, T.END_FRAME))
        for old in self.prints_on("garage", printer):
            self.hide(old)
        plate = printer.part("frame/bed/plate")
        model = "res://assets/models/prints/dragon_miniature_large.glb"
        lo, hi = self.bounds(model)
        size = max(hi.x - lo.x, hi.y - lo.y)
        scale = min(1.0, M.plate_size(printer) * 0.8 / size)
        height = (hi.z - lo.z) * scale
        root, parts = self.add_model(model, Matrix.Scale(scale, 4), ["orange"], parent=plate, collection=self.worlds["garage"].collection)
        a, b = frames_of("first_print")
        _, c = frames_of("garage_reveal")
        build = (a + 20, b - 45)
        M.layer_reveal([o for o in parts.values() if o.type == "MESH"], plate, build, height / plate.matrix_world.to_scale().z, name="dragon_cutter")

        def built(f):
            return height * M.clamp01((f - build[0]) / (build[1] - build[0])) + (0.06 * M.smooth((f - build[1]) / 30.0) if f > build[1] else 0.0)

        def amount(f):
            return 1.0 - M.smooth((f - build[1]) / 12.0)

        M.animate_printer(printer, (a, T.END_FRAME), built=built, amount=amount, step=1)

        nozzle = plate.matrix_world.translation
        close = M.Pose(nozzle + Vector((0, 0, 0.05)), -32.0, 13.0, 0.5, 50.0, fstop=1.8)
        mid = M.Pose(nozzle + Vector((0, 0, 0.07)), 6.0, 17.0, 0.82, 50.0, fstop=2.2)
        self.move("first_print", [(0.0, close), (1.0, mid)], ease=lambda t: M.glide(t, 0.25), world="garage")

        room = self.at("garage", 0.0, 0.3, 0.8)
        wide = M.Pose(room, ISO_YAW, ISO_PITCH - 2, 27.0, 80.0, fstop=16.0, focus=27.0)
        self.move("garage_reveal", [(0.0, mid), (1.0, wide)], ease=lambda t: M.smooth(t) ** 0.85, world="garage")
        cam = self.cams[-1].data
        # Focus follows the distance out.
        for f in range(frames_of("garage_reveal")[0], c + 2):
            t = M.smooth((f - frames_of("garage_reveal")[0]) / (c - frames_of("garage_reveal")[0])) ** 0.85
            cam.dof.focus_distance = math.exp(M.lerp(math.log(0.82), math.log(27.0), t))
            cam.dof.aperture_fstop = M.lerp(2.2, 16.0, t)
            cam.dof.keyframe_insert("focus_distance", frame=f)
            cam.dof.keyframe_insert("aperture_fstop", frame=f)

        # The owner wanders over to see it done.
        owner = self.character("garage", "Player")
        self.claim(owner, (a, c - 1))
        M.Rig(owner).animate((a, b - 1), "idle", step=2)
        M.walk_path(owner, [self.at("garage", -1.18, 0.03), self.at("garage", -1.6, 1.2), self.at("garage", -2.2, 1.85)], (b, c - 1), speed=1.3)
        self.time_of_day("first_print", 10.0)
        self.time_of_day("garage_reveal", 10.0)

    def catalogue(self):
        """A studio of prints on little turntables, the camera tracking past."""
        start, end = frames_of("catalogue")
        coll = bpy.data.collections.new("studio")
        self.scene.collection.children.link(coll)
        base = Vector(OFFSETS["studio"])
        floor = bpy.data.meshes.new("studio_floor")
        floor.from_pydata([(-40, -40, 0), (40, -40, 0), (40, 40, 0), (-40, 40, 0)], [], [(0, 1, 2, 3)])
        mat = bpy.data.materials.new("studio_floor")
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = colour("linen")
        mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
        floor.materials.append(mat)
        obj = bpy.data.objects.new("studio_floor", floor)
        obj.location = base
        coll.objects.link(obj)
        wall = bpy.data.meshes.new("studio_wall")
        wall.from_pydata([(-40, 3, 0), (40, 3, 0), (40, 3, 12), (-40, 3, 12)], [], [(0, 1, 2, 3)])
        wall.materials.append(mat)
        wobj = bpy.data.objects.new("studio_wall", wall)
        wobj.location = base
        coll.objects.link(wobj)
        picks = """dragon_miniature_large garden_gnome_low_poly stacking_rings puzzle_cube_3x3 dice_tower snowman_figurine
vase_mode_vase_tall christmas_village_church phone_stand marble_run_starter_set planet_model_set retro_game_pixel_art
volcano_model flower_bouquet_print_in_place pet_portrait_figurine_custom infinity_style_gauntlet shape_sorter
santa_sleigh_centrepiece dna_helix_model desk_caddy_kids bonfire_table_centrepiece christmas_village_house
easter_egg_fillable abacus articulated_snake bud_vase_set_x3 nativity_set wind_spinner""".split()
        plinth_mat = bpy.data.materials.new("plinth")
        plinth_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = colour("white")
        plinth_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7
        spacing = 0.42
        spin = 2 * math.pi / (T.FPS * 9)
        for row, y in enumerate((0.0, 0.62)):
            for n in range(14):
                pid = picks[(n * 2 + row) % len(picks)]
                x = n * spacing + row * spacing / 2
                where = base + Vector((x, y, 0))
                bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.14, depth=0.06, location=where + Vector((0, 0, 0.04)))
                plinth = bpy.context.active_object
                for c in plinth.users_collection:
                    c.objects.unlink(plinth)
                coll.objects.link(plinth)
                plinth.data.materials.append(plinth_mat)
                model = f"res://assets/models/prints/{pid}.glb"
                lo, hi = self.bounds(model)
                scale = min(1.6, 0.3 / max(hi.x - lo.x, hi.y - lo.y, (hi.z - lo.z) * 0.75))
                colours = [PLA[(n * 5 + row * 3 + k * 4) % len(PLA)] for k in range(6)]
                colours = [c if c != "ink" or k > 0 else "orange" for k, c in enumerate(colours)]
                root, _ = self.add_model(model, Matrix.Translation(where + Vector((0, 0, 0.06))) @ Matrix.Scale(scale, 4), colours, collection=coll)
                turn = self.rng.random() * math.tau
                for f in (start, end - 1):
                    root.rotation_euler.z = turn + spin * f * (1 if (n + row) % 2 else -1)
                    root.keyframe_insert("rotation_euler", index=2, frame=f)
                M.linear_keys(root)
        a = M.Pose(base + Vector((0.6, 0.15, 0.2)), -10.0, 14.0, 1.35, 55.0, fstop=5.6, focus=1.25)
        b = M.Pose(base + Vector((3.6, 0.15, 0.2)), 10.0, 14.0, 1.35, 55.0, fstop=5.6, focus=1.25)
        self.move("catalogue", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.2), world="studio")
        self.time_of_day("catalogue", 11.0)

    def pack_and_post(self):
        owner = self.character("small_unit", "Player")
        start, end = frames_of("pack_and_post")
        self.claim(owner, (start, end - 1))
        M.Rig(owner).animate((start, end - 1), "work", step=1)
        station = next(i for i in self.worlds["small_unit"].instances if i.name == "PackingStation")
        target = station.part("packing_station/pack_spot").matrix_world.translation + Vector((0.15, 0, 0.05))
        target = self.at("small_unit", -3.2, -1.75, 0.75)
        a = M.Pose(target, 18.0, 30.0, 4.4, 35.0, fstop=4.0)
        b = M.Pose(target + Vector((0, 0.2, 0)), 46.0, 33.0, 4.0, 35.0, fstop=4.0)
        self.move("pack_and_post", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.3), world="small_unit")
        self.time_of_day("pack_and_post", 11.0)

    def spaghetti(self):
        printer = self.printer_at("garage", "plodder_mini_pro", -1.48, 2.60)
        start, end = frames_of("spaghetti")
        self.claim(printer, (start, end - 1))
        for old in self.prints_on("garage", printer):
            self.hide(old)
        plate = printer.part("frame/bed/plate")
        root, parts = self.add_model("res://assets/models/fails/spaghetti.glb", Matrix.Identity(4), parent=plate, collection=self.worlds["garage"].collection)
        for obj in parts.values():
            obj.color = colour("lime")
        self.show_only([root] + list(parts.values()), (start, end - 1))
        # The head carries on regardless, as they do.
        M.animate_printer(printer, (start, end - 1), built=0.09, step=1, speed=1.6)
        target = plate.matrix_world.translation + Vector((0, 0, 0.06))
        a = M.Pose(target, -24.0, 26.0, 0.62, 45.0, fstop=2.0)
        b = M.Pose(target, 14.0, 20.0, 0.44, 45.0, fstop=2.0)
        self.move("spaghetti", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.3), world="garage")
        self.time_of_day("spaghetti", 10.5)

    def multicolour(self):
        printer = self.printer_at("workshop", "zippy_x1", 2.46, 0.17)
        self.claim(printer, (0, T.END_FRAME))
        for old in self.prints_on("workshop", printer):
            self.hide(old)
        mount = printer.part("frame/unit_mount")
        coll = self.worlds["workshop"].collection
        unit, unit_parts = self.add_model("res://assets/models/printers/unit_zippy_colourhub.glb", Matrix.Identity(4), parent=mount, collection=coll)
        gnome_colours = ["teal", "yellow", "purple"]
        for k, name in enumerate(gnome_colours + ["red"]):
            slot = unit_parts.get(f"unit_zippy_colourhub/spool_slot_{k + 1}")
            if slot:
                self.add_model(f"res://assets/models/filament/spool_{name}.glb", Matrix.Identity(4), parent=slot, collection=coll)
        # The printer's own spool goes into the unit.
        for inst in self.worlds["workshop"].instances:
            if "/filament/" in inst.scene:
                p = inst.root.matrix_world.translation
                if (p - printer.part("frame/spool_mount").matrix_world.translation).length < 0.05:
                    self.hide(inst)
        plate = printer.part("frame/bed/plate")
        model = "res://assets/models/prints/garden_gnome_low_poly.glb"
        lo, hi = self.bounds(model)
        scale = min(1.0, M.plate_size(printer) * 0.75 / max(hi.x - lo.x, hi.y - lo.y))
        height = (hi.z - lo.z) * scale
        root, parts = self.add_model(model, Matrix.Scale(scale, 4), gnome_colours, parent=plate, collection=coll)
        start, end = frames_of("multicolour")
        build = (start - 30, end - 10)
        M.layer_reveal([o for o in parts.values() if o.type == "MESH"], plate, build, height, name="gnome_cutter")

        def built(f):
            return height * M.clamp01((f - build[0]) / (build[1] - build[0])) + (0.05 * M.smooth((f - build[1]) / 30.0) if f > build[1] else 0.0)

        def amount(f):
            return 1.0 - M.smooth((f - build[1]) / 12.0)

        M.animate_printer(printer, (start, T.END_FRAME), built=built, amount=amount, step=1)
        target = plate.matrix_world.translation + Vector((0, 0, 0.24))
        target = plate.matrix_world.translation + Vector((0, 0, 0.26))
        a = M.Pose(target, -34.0, 12.0, 1.5, 42.0, fstop=2.8)
        b = M.Pose(target + Vector((0, 0, 0.02)), 18.0, 15.0, 1.32, 42.0, fstop=2.8)
        self.move("multicolour", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.3), world="workshop")
        self.time_of_day("multicolour", 12.0)

    def hire_a_team(self):
        start, end = frames_of("hire_a_team")
        staff = self.character("workshop", "Staff_1")
        self.claim(staff, (start, end - 1))
        M.walk_path(staff, [self.at("workshop", -1.9, -0.85), self.at("workshop", 2.1, -0.85)], (start, end - 1), speed=0.9)
        owner = self.character("workshop", "Player")
        self.claim(owner, (start, end - 1))
        M.walk_path(owner, [self.at("workshop", 3.6, 1.2), self.at("workshop", -1.6, 1.2)], (start, end - 1), speed=1.4, carrying=True)
        packer = self.character("workshop", "Staff_2")
        self.claim(packer, (start, end - 1))
        M.Rig(packer).animate((start, end - 1), "work", step=1)
        a = M.Pose(self.at("workshop", -1.3, -0.85, 1.0), 90.0, 12.0, 2.7, 30.0, fstop=3.0)
        b = M.Pose(self.at("workshop", 2.5, -0.85, 1.0), 90.0, 14.0, 2.7, 30.0, fstop=3.0)
        self.move("hire_a_team", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.12), world="workshop")
        self.time_of_day("hire_a_team", 13.0)

    def design_desk(self):
        start, end = frames_of("design_desk")
        owner = self.character("workshop", "Player")
        self.claim(owner, (start, end - 1))
        chair = next(i for i in self.worlds["workshop"].instances if i.name == "Chair")
        seat = chair.root.matrix_world.translation.copy()
        scale = owner.root.matrix_world.to_scale()
        for f in (start, end - 1):
            owner.root.matrix_world = Matrix.Translation(seat + Vector((0, 0.05, 0))) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Diagonal((*scale, 1))
            owner.root.keyframe_insert("location", frame=f)
            owner.root.keyframe_insert("rotation_euler", frame=f)
        M.Rig(owner).animate((start, end - 1), "sit", step=1)
        target = self.at("workshop", 3.85, 4.1, 0.95)
        a = M.Pose(target, -42.0, 30.0, 2.9, 38.0, fstop=3.5)
        b = M.Pose(target, -18.0, 26.0, 2.4, 38.0, fstop=3.5)
        self.move("design_desk", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.3), world="workshop")
        self.time_of_day("design_desk", 15.0)

    def automation(self):
        start, end = frames_of("automation")
        coll = self.worlds["factory"].collection
        conveyor = next(i for i in self.worlds["factory"].instances if "conveyor" in i.model)
        a_mark = conveyor.part("conveyor/belt_start").matrix_world.translation
        b_mark = conveyor.part("conveyor/belt_end").matrix_world.translation
        run = b_mark - a_mark
        picks = ["phone_stand", "stacking_rings", "dice_tower", "snowman_figurine", "vase_mode_vase_tall", "desk_caddy_kids",
                 "puzzle_cube_3x3", "garden_gnome_low_poly"]
        count = 9
        for n in range(count):
            pid = picks[n % len(picks)]
            model = f"res://assets/models/prints/{pid}.glb"
            lo, hi = self.bounds(model)
            scale = 0.16 / max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
            cols = [PLA[(n * 3 + k * 5) % len(PLA)] for k in range(6)]
            root, _ = self.add_model(model, Matrix.Translation(a_mark) @ Matrix.Scale(scale, 4), cols, collection=coll)
            for f in range(start, T.END_FRAME, 3):
                s = ((n / count) + 0.45 * f / T.FPS / run.length) % 1.0
                root.location = a_mark + run * s + Vector((0, 0, 0.01))
                root.keyframe_insert("location", frame=f)
            M.linear_keys(root)
        a = M.Pose(self.at("factory", 1.0, -4.0, 0.9), 22.0, 20.0, 3.8, 30.0, fstop=4.0)
        b = M.Pose(self.at("factory", 0.8, 0.6, 1.3), 52.0, 30.0, 9.5, 30.0, fstop=8.0)
        self.move("automation", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.3), world="factory")
        self.time_of_day("automation", 14.0)

    def round_the_clock(self):
        centre = self.at("factory", 0.0, 0.0, 0.5)
        a = M.Pose(centre, 30.0, 34.0, 56.0, 85.0)
        b = M.Pose(centre, 58.0, 31.0, 51.0, 85.0)
        self.move("round_the_clock", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.2), world="factory")
        self.time_of_day("round_the_clock", lambda t: M.lerp(15.5, 22.5, M.smooth(t)))

    def montage(self):
        """One unbroken orbit from bar 20 to bar 24 that cuts from premises to
        premises on the bar as it goes, garage to factory, without the camera
        ever stopping; then it rises up and away from the factory."""
        spots = [("montage_garage", "garage", 0.3), ("montage_unit", "small_unit", 0.0),
                 ("montage_workshop", "workshop", 0.0), ("montage_factory", "factory", 0.0)]
        a, b = T.bar(T.MONTAGE_BAR), T.bar(T.RISE_BAR)
        rise_end = T.bar(T.LOGO_BAR)
        ease = 0.18

        def orbit(u):
            """Speeds up from rest, then holds its speed into the rise."""
            u = max(0.0, u)
            top = 1.0 / (1.0 - ease / 2.0)
            return 0.5 * top * u * u / ease if u < ease else top * (u - ease / 2.0)

        def pose_at(frame, centre):
            u = (frame - a) / (b - a)
            k = orbit(u)
            near, far = 30.0, 60.0
            pose = M.Pose(centre, 14.0 + 58.0 * k, 32.0, math.exp(M.lerp(math.log(near), math.log(far), k)), 85.0)
            if frame > b:
                # The orbit carries on round at the same speed (orbit() runs
                # on past 1) while the camera climbs away.
                r = M.ease_in((frame - b) / (rise_end - b), 2.4)
                pose.pitch = M.lerp(32.0, 66.0, r)
                pose.distance *= M.lerp(1.0, 1.9, r)
                pose.target = centre + Vector((0, 0, 4.0 * r))
            return pose

        for shot, world, y in spots:
            start, end = frames_of(shot)
            self.on_screen[world].append((start, end))
            cam = self.camera(shot)
            centre = self.at(world, 0.0, y, 0.5)
            for f in range(start - 2, end + 2):
                M.key_camera(cam, f, pose_at(f, centre))
            M.linear_keys(cam)
            M.linear_keys(cam.data)
            cam.data.clip_start = 1.0
            self.time_of_day(shot, 11.5)

    def logo(self):
        centre = self.at("garage", 0.0, 0.5, 0.6)
        a = M.Pose(centre, 22.0, 28.0, 20.0, 80.0, fstop=1.2, focus=7.0)
        b = M.Pose(centre, 40.0, 30.0, 18.5, 80.0, fstop=1.2, focus=7.0)
        self.move("logo", [(0.0, a), (1.0, b)], ease=lambda t: M.glide(t, 0.3), world="garage")
        self.time_of_day("logo", 19.2)

    # --- titles --------------------------------------------------------------

    def build_titles(self):
        t = TT.Titles(T.FPS, T.WIDTH, T.HEIGHT)
        if self.preview:
            t.scene.render.resolution_percentage = 50
            t.scene.eevee.taa_render_samples = 4
        t.scene.frame_start, t.scene.frame_end = 0, T.END_FRAME - 1
        for heading, sub, a, b in T.CARDS:
            t.card(heading, sub, T.bar(a), T.bar(b))
        for label, a, b in T.CHIPS:
            t.chip(label, T.bar(a), T.bar(b))
        for words, a, b, y in T.STATEMENTS:
            t.statement(words, T.bar(a), T.bar(b), y=y, size=96 if y == 0 else 80)
        pc = WORLDS / "pc"
        t.screen(pc / "workshop_craftsy.png", T.bar(6.4), T.bar(7.9))
        t.screen(pc / "workshop_rota.png", T.bar(12.4), T.bar(13.9))
        t.screen(pc / "workshop_skillshed.png", T.bar(14.4), T.bar(15.9))
        # Darken behind the big words, and the logo.
        t.vignette([(0, 0.0), (8, 0.0), (40, 1.0), (T.bar(2.6), 1.0), (T.bar(2.75), 0.6), (T.bar(3.95), 0.6), (T.bar(4.0) + 10, 0.0),
                    (T.bar(20.0) - 1, 0.0), (T.bar(20.0) + 12, 0.5), (T.bar(24.6), 0.5), (T.bar(24.8), 0.0),
                    (T.bar(T.LOGO_BAR) - 1, 0.0), (T.bar(T.LOGO_BAR) + 20, 1.0)], strength=0.7)
        t.logo(T.bar(T.LOGO_BAR) + 6, T.END_FRAME + 60)
        t.button("Wishlist on Steam", T.bar(T.LOGO_BUTTON_BAR), T.END_FRAME + 60)
        t.flash(T.bar(T.LOGO_BAR), length=24, peak=0.85)
        t.flash(T.bar(T.GROOVE_BAR), length=10, peak=0.25)
        t.black([(0, 1.0), (40, 0.0), (T.END_FRAME - 70, 0.0), (T.END_FRAME - 1, 1.0)])
        self.titles = t

    def build(self):
        self.busy = {}
        self.prepare_lights()
        self.first_print_and_garage()
        self.catalogue()
        self.pack_and_post()
        self.spaghetti()
        self.multicolour()
        self.hire_a_team()
        self.design_desk()
        self.automation()
        self.round_the_clock()
        self.montage()
        self.logo()
        self.bring_to_life()
        for obj in (self.sun, self.sun.data, self.sky.node_tree):
            M.linear_keys(obj)
        self.hold_at_cuts()
        self.build_titles()

    def hold_at_cuts(self):
        """Nothing slides from one shot's state to the next: the last key
        before each cut holds. With the shutter opening on the frame (not
        centred on it), motion blur never sees across a cut."""
        self.scene.render.motion_blur_position = "START"
        cuts = sorted({T.bar(a) for _, a, _ in T.SHOTS})
        things = [o for o in bpy.data.objects if o.animation_data and o.animation_data.action and not o.name.startswith("cam_")]
        things += [l for l in bpy.data.lights if l.animation_data and l.animation_data.action]
        things += [self.sky.node_tree]
        for thing in things:
            for fc in M.fcurves_of(thing.animation_data.action):
                keys = fc.keyframe_points
                for k, nxt in zip(keys, keys[1:]):
                    if any(k.co.x < cut <= nxt.co.x for cut in cuts):
                        k.interpolation = "CONSTANT"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true", help="half size, few samples")
    parser.add_argument("--stills", default="", help="frames to render to tools/previews/trailer/")
    parser.add_argument("--no-save", action="store_true")
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    trailer = Trailer(preview=options.preview)
    trailer.build()
    scene = trailer.scene
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.filepath = str(OUT / ("preview_frames" if options.preview else "frames") / "f_")
    scene.render.use_overwrite = False
    scene.render.use_placeholder = True
    titles = trailer.titles.scene
    titles.render.image_settings.file_format = "PNG"
    titles.render.filepath = str(OUT / ("preview_titles" if options.preview else "titles") / "t_")
    titles.render.use_overwrite = False
    titles.render.use_placeholder = True
    if not options.no_save:
        OUT.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / ("trailer_preview.blend" if options.preview else "trailer.blend")))
    if options.stills:
        PREVIEWS.mkdir(parents=True, exist_ok=True)
        for frame in [int(f) for f in options.stills.split(",")]:
            for sc, tag in ((scene, "f"), (titles, "t")):
                sc.frame_set(frame)
                keep = sc.render.filepath
                sc.render.filepath = str(PREVIEWS / f"{tag}_{frame:04d}.png")
                bpy.ops.render.render(write_still=True, scene=sc.name)
                sc.render.filepath = keep


main()
