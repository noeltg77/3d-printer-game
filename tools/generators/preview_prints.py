"""Renders a contact sheet of printed items, to check a batch before importing.
Items are laid out in rows like text (first at the back left), seen from the
front and from above. Also prints the triangle count and size of each one.
Writes tools/previews/prints_sheet_front.png and prints_sheet_top.png. Exports nothing.

blender --background --factory-startup --python tools/generators/preview_prints.py -- --generator prints_home
blender --background --factory-startup --python tools/generators/preview_prints.py -- --only mail_sorter,pen_pot_hex
blender --background --factory-startup --python tools/generators/preview_prints.py -- --module prints_mc_toys --sheet toys

--module shows every variant a generator file has, whether or not the manifest
lists them yet. --sheet names the output (prints_sheet_<name>_front.png), so
two people checking batches at once don't overwrite each other.
"""

import argparse
import importlib
import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parent))
import common

VIEWS = {"front": (0.0, -1.0, 0.8), "top": (0.15, -0.5, 1.0)}
PITCH = 0.34
# Printed items are tinted in game; a mid colour shows their shape better than white.
TINT = (0.1, 0.45, 0.42, 1.0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generator", default="", help="only items built by this generator module")
    parser.add_argument("--only", default="", help="comma separated product ids")
    parser.add_argument("--module", default="", help="every variant in this generator module, manifest or not")
    parser.add_argument("--sheet", default="", help="name for the output files")
    parser.add_argument("--columns", type=int, default=4)
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    manifest = json.loads((Path(__file__).resolve().parent / "manifest.json").read_text())
    wanted = [name for name in options.only.split(",") if name]
    entries = [
        entry for entry in manifest["assets"]
        if entry["generator"].startswith("prints")
        and (not options.generator or entry["generator"] == options.generator)
        and (not wanted or entry["args"]["variant"] in wanted)
    ]
    if options.module:
        entries = [
            {"generator": options.module, "args": {"variant": variant}}
            for variant in importlib.import_module(options.module).VARIANTS
            if not wanted or variant in wanted
        ]
    common.reset_scene()
    common.tint_material().node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = TINT
    for index, entry in enumerate(entries):
        variant = entry["args"]["variant"]
        module = importlib.import_module(entry["generator"])
        if hasattr(module, "build_item"):
            # Items in several colours come as a main mesh with a child for each further colour.
            obj = module.build_item(variant, variant, preview=True)
        else:
            builder = common.MeshBuilder(material=common.TINT_MATERIAL_NAME)
            module.VARIANTS[variant](builder)
            obj = builder.finish(variant)
        obj.location = ((index % options.columns) * PITCH, -(index // options.columns) * PITCH, 0.0)
        meshes = [obj, *obj.children]
        triangles = sum(len(polygon.vertices) - 2 for mesh in meshes for polygon in mesh.data.polygons)
        corners = [vertex.co for mesh in meshes for vertex in mesh.data.vertices]
        low = min(corner.z for corner in corners)
        size = " x ".join(f"{max(corner[axis] for corner in corners) - min(corner[axis] for corner in corners):.3f}" for axis in range(3))
        print(f"{index + 1:3} {variant:40} {triangles:4} tris  {size} m  base z {low:.3f}  {len(meshes)} colours")
    sheet = f"prints_sheet_{options.sheet}_" if options.sheet else "prints_sheet_"
    for name, direction in VIEWS.items():
        common.render_preview(common.PREVIEW_DIR / f"{sheet}{name}.png", resolution=1536, direction=direction, margin=0.85)


main()
