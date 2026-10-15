"""Render settings and lighting for the trailer: warm sun, soft shadows and
screen-space GI, after the game's own look (DayNight, the scenes' Sun and
WorldEnvironment). Runs inside Blender's Python."""

import math

import bpy

from world import godot_view, srgb_to_linear

# The scenes' sun (scenes/*/*.tscn "Sun").
SUN_TRANSFORM = [0.848, -0.3999, 0.3477, 0, 0.6561, 0.7547, -0.5299, -0.64, 0.5564, 0, 6, 0]


def lin(rgb):
    return tuple(srgb_to_linear(c) for c in rgb)


def setup_render(scene, width=1920, height=1080, fps=60, samples=32):
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.render.fps = fps
    scene.render.fps_base = 1.0
    e = scene.eevee
    e.taa_render_samples = samples
    e.use_shadows = True
    e.shadow_pool_size = "1024"
    e.shadow_ray_count = 2
    e.shadow_step_count = 8
    e.shadow_resolution_scale = 1.0
    e.use_raytracing = True
    e.ray_tracing_method = "SCREEN"
    e.use_fast_gi = True
    e.fast_gi_method = "GLOBAL_ILLUMINATION"
    e.fast_gi_distance = 1.5
    e.fast_gi_quality = 0.5
    e.motion_blur_steps = 1
    e.bokeh_max_size = 60.0
    scene.render.use_motion_blur = True
    scene.render.motion_blur_shutter = 0.5
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    scene.render.film_transparent = False
    scene.render.filter_size = 1.5


def add_sun(scene, name="sun"):
    sun = bpy.data.lights.new(name, "SUN")
    sun.energy = 4.2
    sun.color = lin((1.0, 0.92, 0.8))
    sun.angle = math.radians(3.0)
    obj = bpy.data.objects.new(name, sun)
    scene.collection.objects.link(obj)
    obj.matrix_world = godot_view(SUN_TRANSFORM)
    return obj


def add_sky(scene, colour=(1.0, 0.88, 0.78), strength=0.75):
    world = bpy.data.worlds.new("sky")
    scene.world = world
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*lin(colour), 1.0)
    bg.inputs[1].default_value = strength
    return world
