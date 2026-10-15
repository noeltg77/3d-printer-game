"""The trailer's titles, in the game's own UI style (scripts/ui/ui.gd and
docs/mockups/pc_screens.html): cream cards with a flat shadow dropped
straight down, Fredoka headings, Nunito text, dark chips and the chunky orange
button. They are built in a scene of their own, seen by an orthographic
camera at 100 pixels to the unit, and rendered with a transparent background
to be laid over the footage. Runs inside Blender's Python."""

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

from motion import back_out, clamp01, ease_in, ease_out, smooth
from world import srgb_to_linear

FONTS = Path(__file__).resolve().parent / "fonts"
PX = 0.01  # units per pixel


def hex_colour(code, alpha=1.0):
    code = code.lstrip("#")
    return (*[srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4)], alpha)


INK = hex_colour("22313A")
MUTED = hex_colour("5A6A72")
CREAM = hex_colour("FBF8F3")
LINE = hex_colour("EAE1D2")
TRACK = hex_colour("E0D6C6")
ORANGE = hex_colour("E8792B")
ORANGE_DARK = hex_colour("B85A17")
GREEN = hex_colour("2F8F6B")
TASKBAR = hex_colour("1E2A30")
CHIP_TEXT = hex_colour("C9D3D7")
WHITE = (1.0, 1.0, 1.0, 1.0)
BLACK = (0.0, 0.0, 0.0, 1.0)


class Titles:
    def __init__(self, fps=60, width=1920, height=1080):
        self.scene = bpy.data.scenes.new("titles")
        self.fps = fps
        self.width, self.height = width, height
        self.scene.render.resolution_x, self.scene.render.resolution_y = width, height
        self.scene.render.fps = fps
        self.scene.render.engine = "BLENDER_EEVEE"
        self.scene.eevee.taa_render_samples = 16
        self.scene.render.film_transparent = True
        self.scene.view_settings.view_transform = "Standard"
        self.scene.render.image_settings.color_mode = "RGBA"
        self.scene.render.use_motion_blur = False
        cam = bpy.data.cameras.new("titles_cam")
        cam.type = "ORTHO"
        cam.ortho_scale = width * PX
        cam_obj = bpy.data.objects.new("titles_cam", cam)
        cam_obj.location = (0, 0, 10)
        self.scene.collection.objects.link(cam_obj)
        self.scene.camera = cam_obj
        self.fonts = {}
        self.materials = {}
        self.depth = 0.0

    # --- building blocks -----------------------------------------------------

    def font(self, name):
        if name not in self.fonts:
            self.fonts[name] = bpy.data.fonts.load(str(FONTS / f"{name}.ttf"))
        return self.fonts[name]

    def material(self, colour):
        key = tuple(round(c, 4) for c in colour)
        if key in self.materials:
            return self.materials[key]
        mat = bpy.data.materials.new("title_%d" % len(self.materials))
        mat.surface_render_method = "BLENDED"
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = (*colour[:3], 1.0)
        clear = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        info = nodes.new("ShaderNodeObjectInfo")
        # The object's colour alpha fades it, times the colour's own alpha.
        times = nodes.new("ShaderNodeMath")
        times.operation = "MULTIPLY"
        times.inputs[1].default_value = colour[3]
        links.new(info.outputs["Alpha"], times.inputs[0])
        links.new(times.outputs[0], mix.inputs["Fac"])
        links.new(clear.outputs[0], mix.inputs[1])
        links.new(emit.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs["Surface"])
        self.materials[key] = mat
        return mat

    def image_material(self, path):
        """Shows a picture as it is, faded by the object's colour alpha."""
        mat = bpy.data.materials.new("title_image")
        mat.surface_render_method = "BLENDED"
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        image = nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(str(path), check_existing=True)
        image.interpolation = "Cubic"
        emit = nodes.new("ShaderNodeEmission")
        clear = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        info = nodes.new("ShaderNodeObjectInfo")
        links.new(image.outputs["Color"], emit.inputs["Color"])
        links.new(info.outputs["Alpha"], mix.inputs["Fac"])
        links.new(clear.outputs[0], mix.inputs[1])
        links.new(emit.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs["Surface"])
        return mat

    def _z(self):
        self.depth += 0.001
        return self.depth

    def group(self, name, x, y):
        """An empty that a title's pieces hang from, so it moves as one."""
        root = bpy.data.objects.new(name, None)
        root.location = (x, y, self._z())
        self.scene.collection.objects.link(root)
        return root

    def rect(self, parent, w, h, r, colour, x=0.0, y=0.0, name="rect"):
        """A rounded rectangle centred on (x, y), in pixels."""
        w, h, r = w * PX, h * PX, min(r * PX, w * PX / 2, h * PX / 2)
        bm = bmesh.new()
        pts = []
        steps = 12 if r > 0 else 0
        for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
            for s in range(steps + 1):
                a = math.radians(a0 + 90.0 * s / max(steps, 1))
                pts.append(bm.verts.new((cx + r * math.cos(a), cy + r * math.sin(a), 0.0)))
        face = bm.faces.new(pts)
        uv = bm.loops.layers.uv.new("uv")
        for loop in face.loops:
            loop[uv].uv = (loop.vert.co.x / w + 0.5, loop.vert.co.y / h + 0.5)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(colour if isinstance(colour, bpy.types.Material) else self.material(colour))
        obj = bpy.data.objects.new(name, mesh)
        self.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = (x * PX, y * PX, self._z())
        return obj

    def text(self, parent, body, font, size, colour, x=0.0, y=0.0, align="LEFT", name="text", spacing=1.0):
        """Text with its baseline at y, in pixels. Returns (object, width px)."""
        curve = bpy.data.curves.new(name, "FONT")
        curve.body = body
        curve.font = self.font(font)
        curve.size = size * PX
        curve.align_x = align
        curve.align_y = "BOTTOM_BASELINE"
        curve.space_character = spacing
        curve.materials.append(self.material(colour))
        obj = bpy.data.objects.new(name, curve)
        self.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = (x * PX, y * PX, self._z())
        dg = self.scene.view_layers[0].depsgraph
        dg.update()
        mesh = obj.evaluated_get(dg).to_mesh()
        xs = [v.co.x for v in mesh.vertices] or [0.0]
        width = (max(xs) - min(xs)) / PX
        obj.evaluated_get(dg).to_mesh_clear()
        return obj, width

    # --- animation -----------------------------------------------------------

    def fade(self, objs, frame, alpha):
        for obj in objs:
            obj.color[3] = alpha
            obj.keyframe_insert("color", index=3, frame=frame)

    def pieces(self, root):
        return [c for c in root.children_recursive if c.type in ("MESH", "FONT")]

    def pop(self, root, start, end, rise=40.0, inn=18, out=14, scale_from=0.92):
        """Pops a title in at start (rising and settling with a little
        overshoot) and drops it out by end."""
        base = root.location.copy()
        objs = self.pieces(root)
        for f in range(start - 1, start + inn + 1):
            t = (f - start) / inn
            k = back_out(t, 1.3)
            root.location = base + Vector((0, -rise * PX * (1.0 - k), 0))
            s = scale_from + (1.0 - scale_from) * k
            root.scale = (s, s, 1)
            root.keyframe_insert("location", frame=f)
            root.keyframe_insert("scale", frame=f)
            self.fade(objs, f, ease_out(t, 2.0))
        for f in range(end - out, end + 1):
            t = (f - (end - out)) / out
            k = ease_in(t, 2.0)
            root.location = base + Vector((0, -rise * 0.6 * PX * k, 0))
            s = 1.0 - (1.0 - scale_from) * k
            root.scale = (s, s, 1)
            root.keyframe_insert("location", frame=f)
            root.keyframe_insert("scale", frame=f)
            self.fade(objs, f, 1.0 - k)

    def slide(self, root, start, end, dx=-80.0, inn=20, out=14):
        """Slides in from the side, settles, and slides on out."""
        base = root.location.copy()
        objs = self.pieces(root)
        self.fade(objs, start - 1, 0.0)
        for f in range(start, start + inn + 1):
            t = (f - start) / inn
            root.location = base + Vector((dx * PX * (1.0 - back_out(t, 1.1)), 0, 0))
            root.keyframe_insert("location", frame=f)
            self.fade(objs, f, ease_out(t, 2.0))
        for f in range(end - out, end + 1):
            t = (f - (end - out)) / out
            root.location = base + Vector((-dx * 0.6 * PX * ease_in(t, 2.0), 0, 0))
            root.keyframe_insert("location", frame=f)
            self.fade(objs, f, 1.0 - ease_in(t, 2.0))

    # --- titles --------------------------------------------------------------

    def card(self, heading, sub, start, end, x=110.0, y=-330.0):
        """A feature caption: a cream card at the lower left with an orange
        tab, a heading and a line under it. x, y is its left middle, px from
        the centre of the frame."""
        root = self.group("card_" + heading[:12], 0, 0)
        head, hw = self.text(root, heading, "fredoka_bold", 58, INK, 0, 0, name="heading")
        lines = sub.split("\n") if sub else []
        widths = []
        subs = []
        for line in lines:
            obj, w = self.text(root, line, "nunito_bold", 28, MUTED, 0, 0, name="sub")
            subs.append(obj)
            widths.append(w)
        pad_x, pad_top, pad_bottom = 46, 38, 36
        inner = max([hw] + widths)
        width = inner + pad_x * 2 + 18
        height = pad_top + 46 + (len(lines) * 40 + 10 if lines else 0) + pad_bottom
        left = -self.width / 2 + x
        cx = left + width / 2
        root.location = (cx * PX, y * PX, root.location.z)
        self.rect(root, width, height, 26, (*INK[:3], 0.28), 0, -9, name="shadow")
        self.rect(root, width, height, 26, LINE, 0, -4, name="edge")
        self.rect(root, width, height, 26, CREAM, 0, 0, name="face")
        self.rect(root, 10, height - 52, 5, ORANGE, -width / 2 + 30, 0, name="tab")
        tx = -width / 2 + pad_x + 18
        top = height / 2 - pad_top
        head.location = (tx * PX, (top - 44) * PX, self._z())
        for i, obj in enumerate(subs):
            obj.location = (tx * PX, (top - 44 - 50 - i * 40) * PX, self._z())
        self.slide(root, start, end)
        return root

    def chip(self, label, start, end, x=-110.0, y=-430.0, dot=ORANGE):
        """A dark chip at the lower right with a coloured dot, like the main
        menu's 'Workshop cam'. x is its right edge from the frame's right."""
        root = self.group("chip_" + label, 0, 0)
        obj, w = self.text(root, label, "fredoka_bold", 34, WHITE, 0, 0, name="chip_text")
        width, height = w + 100, 68
        right = self.width / 2 + x
        root.location = ((right - width / 2) * PX, y * PX, root.location.z)
        self.rect(root, width, height, 22, (*BLACK[:3], 0.25), 0, -5, name="chip_shadow")
        self.rect(root, width, height, 22, TASKBAR, 0, 0, name="chip_face")
        self.rect(root, 18, 18, 9, dot, -width / 2 + 34, 0, name="dot")
        obj.location = ((-width / 2 + 58) * PX, -12 * PX, self._z())
        self.pop(root, start, end, rise=24)
        return root

    def statement(self, line, start, end, y=0.0, size=86, colour=WHITE, shadow=True, words=True):
        """Big centred words over the picture, each word rising in turn."""
        root = self.group("statement", 0, y * PX)
        parts = line.split(" ") if words else [line]
        objs = []
        total = 0.0
        gap = size * 0.28
        for word in parts:
            obj, w = self.text(root, word, "fredoka_bold", size, colour, 0, 0, name="word")
            objs.append((obj, w))
            total += w + gap
        total -= gap
        x = -total / 2
        delay = 5
        for i, (obj, w) in enumerate(objs):
            word_root = bpy.data.objects.new("word_root", None)
            self.scene.collection.objects.link(word_root)
            word_root.parent = root
            word_root.location = (x * PX, -size * 0.35 * PX, 0)
            obj.parent = word_root
            obj.location = (0, 0, self._z())
            if shadow:
                sh, _ = self.text(word_root, obj.data.body, "fredoka_bold", size, (*INK[:3], 0.45), 0, -6, name="word_shadow")
                sh.location.z = obj.location.z - 0.0005
            x += w + gap
            self.pop(word_root, start + i * delay, end, rise=34, inn=20, out=12, scale_from=0.85)
        return root

    def flash(self, start, length=10, colour=WHITE, peak=0.6):
        """A quick wash of colour over the frame, for a beat."""
        root = self.group("flash", 0, 0)
        root.location.z = 5.0
        r = self.rect(root, self.width + 40, self.height + 40, 0, colour)
        self.fade([r], start - 1, 0.0)
        for f in range(start, start + length + 1):
            t = (f - start) / length
            self.fade([r], f, peak * (1.0 - smooth(t)))
        return root

    def black(self, keys):
        """A black frame over everything, faded by (frame, alpha) keys."""
        root = self.group("black", 0, 0)
        root.location.z = 6.0
        r = self.rect(root, self.width + 40, self.height + 40, 0, BLACK)
        for frame, alpha in keys:
            self.fade([r], frame, alpha)
        return root

    def screen(self, path, start, end, x=455.0, y=150.0, width=880.0, tilt=-1.5):
        """A screenshot of the game's PC, floating at the upper right in a
        frame like a PlateOS window."""
        height = width * 9.0 / 16.0
        root = self.group("screen", x * PX, y * PX)
        root.rotation_euler.z = math.radians(tilt)
        border = 12
        self.rect(root, width + border * 2, height + border * 2, 26, (*BLACK[:3], 0.3), 0, -12, name="screen_shadow")
        self.rect(root, width + border * 2, height + border * 2, 26, TASKBAR, 0, 0, name="screen_frame")
        self.rect(root, width, height, 14, self.image_material(path), 0, 0, name="screen_image")
        self.pop(root, start, end, rise=50, inn=22, out=14, scale_from=0.9)
        return root

    def logo(self, start, end, y=70.0):
        """The game's name as the main menu sets it: 'Print Shop' in white
        over 'Tycoon' in orange, the words dropping in one at a time."""
        root = self.group("logo", 0, y * PX)
        lines = (("Print Shop", WHITE, 70), ("Tycoon", ORANGE, -100))
        delay = 0
        for text, colour, line_y in lines:
            for word in [text]:
                word_root = bpy.data.objects.new("logo_word", None)
                self.scene.collection.objects.link(word_root)
                word_root.parent = root
                word_root.location = (0, line_y * PX, 0)
                obj, w = self.text(word_root, word, "fredoka_bold", 170, colour, 0, 0, align="CENTER", name="logo_text")
                sh, _ = self.text(word_root, word, "fredoka_bold", 170, (*INK[:3], 0.55), 0, -10, align="CENTER", name="logo_shadow")
                sh.location.z = obj.location.z - 0.0005
                self.pop(word_root, start + delay, end, rise=60, inn=26, out=20, scale_from=0.7)
                delay += 9
        return root

    def button(self, label, start, end, y=-260.0):
        """The menu's chunky orange button, a darker edge under it."""
        root = self.group("button", 0, y * PX)
        obj, w = self.text(root, label, "nunito_extrabold", 46, WHITE, 0, -16, align="CENTER", name="button_text")
        width, height = w + 150, 104
        self.rect(root, width, height, 30, (*BLACK[:3], 0.3), 0, -14, name="button_shadow")
        self.rect(root, width, height, 30, ORANGE_DARK, 0, -7, name="button_edge")
        self.rect(root, width, height, 30, ORANGE, 0, 0, name="button_face")
        obj.location.z = self._z()
        self.pop(root, start, end, rise=30, inn=20, out=20, scale_from=0.6)
        return root

    def vignette(self, keys, strength=0.65):
        """Darkens the frame's edges and middle band so white words read over
        a busy picture. keys: (frame, amount 0..1)."""
        mat = bpy.data.materials.new("vignette")
        mat.surface_render_method = "BLENDED"
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        coords = nodes.new("ShaderNodeTexCoord")
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Location"].default_value = (-0.5, -0.5, 0)
        mapping.inputs["Scale"].default_value = (1.0, 1.6, 1)
        links.new(coords.outputs["UV"], mapping.inputs["Vector"])
        length = nodes.new("ShaderNodeVectorMath")
        length.operation = "LENGTH"
        links.new(mapping.outputs["Vector"], length.inputs[0])
        ramp = nodes.new("ShaderNodeMapRange")
        ramp.inputs["From Min"].default_value = 0.0
        ramp.inputs["From Max"].default_value = 0.95
        ramp.inputs["To Min"].default_value = 0.55
        ramp.inputs["To Max"].default_value = 1.0
        links.new(length.outputs["Value"], ramp.inputs["Value"])
        info = nodes.new("ShaderNodeObjectInfo")
        times = nodes.new("ShaderNodeMath")
        times.operation = "MULTIPLY"
        links.new(ramp.outputs["Result"], times.inputs[0])
        links.new(info.outputs["Alpha"], times.inputs[1])
        times2 = nodes.new("ShaderNodeMath")
        times2.operation = "MULTIPLY"
        times2.inputs[1].default_value = strength
        links.new(times.outputs[0], times2.inputs[0])
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = (*hex_colour("1E2A30")[:3], 1)
        clear = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        links.new(times2.outputs[0], mix.inputs["Fac"])
        links.new(clear.outputs[0], mix.inputs[1])
        links.new(emit.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs["Surface"])
        root = self.group("vignette", 0, 0)
        root.location.z = -1.0
        r = self.rect(root, self.width + 40, self.height + 40, 0, mat)
        for frame, amount in keys:
            self.fade([r], frame, amount)
        return root
